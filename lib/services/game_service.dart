import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/character.dart';
import '../models/creature.dart';

/// Jugador dentro de una sala, con una copia de su personaje.
class GamePlayer {
  final String uid;
  final String email;
  final Character character;

  const GamePlayer({
    required this.uid,
    required this.email,
    required this.character,
  });
}

class GameService {
  final CollectionReference<Map<String, dynamic>> _games =
      FirebaseFirestore.instance.collection('games');

  User get _user => FirebaseAuth.instance.currentUser!;

  // Sin 0/O/1/I para evitar confusiones al dictar el código
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _randomCode() {
    final rnd = Random.secure();
    return List.generate(
      6,
      (_) => _alphabet[rnd.nextInt(_alphabet.length)],
    ).join();
  }

  /// Crea la partida y devuelve el código de invitación.
  Future<String> createGame(String name) async {
    for (var i = 0; i < 10; i++) {
      final code = _randomCode();
      final ref = _games.doc(code);

      if (!(await ref.get()).exists) {
        await ref.set({
          'name': name,
          'masterUid': _user.uid,
          'masterEmail': _user.email ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return code;
      }
    }
    throw Exception('No se pudo generar un código único. Inténtalo de nuevo.');
  }

  /// Devuelve los datos de la partida o null si no existe.
  Future<Map<String, dynamic>?> findGame(String code) async {
    final snap = await _games.doc(code.trim().toUpperCase()).get();
    return snap.exists ? snap.data() : null;
  }

  Stream<Map<String, dynamic>?> gameStream(String code) =>
      _games.doc(code).snapshots().map((s) => s.data());

  /// El jugador entra (o cambia de personaje) en la sala.
  Future<void> joinWithCharacter(String code, Character c) {
    return _games.doc(code).collection('players').doc(_user.uid).set({
      'playerUid': _user.uid,
      'playerEmail': _user.email ?? '',
      'characterId': c.id,
      'character': c.toMap(),
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> leave(String code) =>
      _games.doc(code).collection('players').doc(_user.uid).delete();

  /// Solo el Master puede expulsar a un jugador.
  Future<void> removePlayer(String code, String playerUid) =>
      _games.doc(code).collection('players').doc(playerUid).delete();

  Stream<List<GamePlayer>> players(String code) {
    return _games.doc(code).collection('players').snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        return GamePlayer(
          uid: d.id,
          email: (data['playerEmail'] ?? '') as String,
          character: Character.fromMap(
            Map<String, dynamic>.from(data['character'] ?? {}),
            id: data['characterId'] as String?,
          ),
        );
      }).toList();
      list.sort((a, b) => a.character.name.compareTo(b.character.name));
      return list;
    });
  }

  // ==========================================
  // CRIATURAS DE LA PARTIDA (NPC y monstruos)
  // ==========================================

  CollectionReference<Map<String, dynamic>> _creaturesCol(String code) =>
      _games.doc(code).collection('creatures');

  /// Añade criaturas a la partida (solo el Master).
  ///
  /// - [custom]: criaturas del bestiario del usuario (se guarda una copia).
  /// - [api]: monstruos de la API (índice -> cantidad). De estos solo se
  ///   guarda el índice y el número de ejemplar; las estadísticas no se
  ///   almacenan y se consultan a la API cuando hacen falta.
  Future<void> addCreatures(
    String code, {
    Map<Creature, int> custom = const {},
    Map<String, int> api = const {},
  }) async {
    final col = _creaturesCol(code);
    final existing = await col.get();

    // Cuántas hay ya de cada una, para seguir la numeración
    final customCounts = <String, int>{};
    final apiCounts = <String, int>{};
    for (final d in existing.docs) {
      final data = d.data();
      final apiIndex = data['apiIndex'] as String?;
      if (apiIndex != null) {
        apiCounts[apiIndex] = (apiCounts[apiIndex] ?? 0) + 1;
      } else {
        final name = (data['creature']?['name'] ?? '') as String;
        customCounts[name] = (customCounts[name] ?? 0) + 1;
      }
    }

    final batch = FirebaseFirestore.instance.batch();

    custom.forEach((c, qty) {
      final already = customCounts[c.name] ?? 0;
      for (var i = 1; i <= qty; i++) {
        final label = (already + qty > 1) ? '${c.name} ${already + i}' : c.name;
        batch.set(col.doc(), {
          'label': label,
          'damageTaken': 0,
          'creature': c.toMap(),
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    api.forEach((index, qty) {
      final already = apiCounts[index] ?? 0;
      for (var i = 1; i <= qty; i++) {
        batch.set(col.doc(), {
          'apiIndex': index,
          'number': already + i,
          'damageTaken': 0,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
    });

    await batch.commit();
  }

  Stream<List<GameCreature>> creatures(String code) {
    return _creaturesCol(code).snapshots().map((snap) {
      final list = snap.docs.map(GameCreature.fromDoc).toList();
      list.sort((a, b) => a.sortKey.compareTo(b.sortKey));
      return list;
    });
  }

  /// Guarda los puntos de golpe perdidos de una criatura.
  Future<void> updateCreatureDamage(String code, String creatureId, int damage) =>
      _creaturesCol(code).doc(creatureId).update({'damageTaken': damage});

  Future<void> removeCreature(String code, String creatureId) =>
      _creaturesCol(code).doc(creatureId).delete();
}
