import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/character.dart';
import '../models/combat.dart';
import '../models/creature.dart';
import '../models/game_models.dart';
import '../widgets/avatars.dart';

/// Jugador dentro de una partida, con una copia de su personaje.
class GamePlayer {
  final String uid;
  final String email;
  final Character character;

  /// Color asignado al jugador (ARGB); null hasta que el Master lo asigna.
  final int? color;

  /// Puntos de golpe actuales
  final int currentHp;

  /// Espacios de conjuro gastados por nivel
  final Map<int, int> slotsUsed;

  /// Avatar elegido por el jugador (vacío = el de su clase) y segundo color
  final String avatar;
  final int? color2;

  /// Salvaciones de muerte (0-3 cada una) y personaje muerto
  final int deathSuccess;
  final int deathFail;
  final bool dead;

  const GamePlayer({
    required this.uid,
    required this.email,
    required this.character,
    this.color,
    required this.currentHp,
    this.slotsUsed = const {},
    this.avatar = '',
    this.color2,
    this.deathSuccess = 0,
    this.deathFail = 0,
    this.dead = false,
  });
}

/// Lee un mapa de espacios de conjuro guardado como {"1": 2, "3": 1}.
Map<int, int> parseSlotMap(dynamic raw) {
  final out = <int, int>{};
  if (raw is Map) {
    raw.forEach((k, v) {
      final l = int.tryParse(k.toString());
      final n = v is num ? v.toInt() : null;
      if (l != null && n != null && n > 0) out[l] = n;
    });
  }
  return out;
}

class GameService {
  final CollectionReference<Map<String, dynamic>> _games =
      FirebaseFirestore.instance.collection('games');

  User get _user => FirebaseAuth.instance.currentUser!;

  String get myUid => _user.uid;

  CollectionReference<Map<String, dynamic>> _playersCol(String code) =>
      _games.doc(code).collection('players');

  CollectionReference<Map<String, dynamic>> _creaturesCol(String code) =>
      _games.doc(code).collection('creatures');

  CollectionReference<Map<String, dynamic>> _tokensCol(String code) =>
      _games.doc(code).collection('tokens');

  CollectionReference<Map<String, dynamic>> _rollsCol(String code) =>
      _games.doc(code).collection('rolls');

  DocumentReference<Map<String, dynamic>> _terrainDoc(String code,
          [int floor = 0]) =>
      _games.doc(code).collection('map').doc(floor == 0 ? 'terrain' : 'terrain$floor');

  CollectionReference<Map<String, dynamic>> _hiddenRollsCol(String code) =>
      _games.doc(code).collection('hiddenRolls');

  DocumentReference<Map<String, dynamic>> _combatDoc(String code) =>
      _games.doc(code).collection('combat').doc('state');

  // Sin 0/O/1/I para evitar confusiones al dictar el código
  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  String _randomCode() {
    final rnd = Random.secure();
    return List.generate(
      6,
      (_) => _alphabet[rnd.nextInt(_alphabet.length)],
    ).join();
  }

  // ==========================================
  // PARTIDA Y SALA
  // ==========================================

  /// Crea la partida y devuelve el código de invitación.
  Future<String> createGame(String name) async {
    try {
      return await _createGame(name);
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // Token con «email_verified» desactualizado: se renueva y se reintenta.
      await FirebaseAuth.instance.currentUser?.reload();
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      return _createGame(name);
    }
  }

  Future<String> _createGame(String name) async {
    for (var i = 0; i < 10; i++) {
      final code = _randomCode();
      final ref = _games.doc(code);

      if (!(await ref.get()).exists) {
        await ref.set({
          'name': name,
          'masterUid': _user.uid,
          'masterEmail': _user.email ?? '',
          'status': 'lobby',
          'cols': 20,
          'rows': 14,
          'createdAt': FieldValue.serverTimestamp(),
          'lastActivity': FieldValue.serverTimestamp(),
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
  /// Se hace merge para no perder el color que ya tuviera asignado.
  Future<void> joinWithCharacter(
    String code,
    Character c, {
    String? avatar,
    int? color,
    int? color2,
  }) {
    return _playersCol(code).doc(_user.uid).set({
      if (avatar != null) 'avatar': avatar,
      if (color != null) 'color': color,
      if (color2 != null) 'color2': color2,
      'playerUid': _user.uid,
      'playerEmail': _user.email ?? '',
      'characterId': c.id,
      'character': c.toMap(),
      'currentHp': c.maxHp,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// true si el usuario actual ya ha entrado en la partida con un personaje.
  Stream<bool> amIInGame(String code) =>
      _playersCol(code).doc(_user.uid).snapshots().map((snap) => snap.exists);

  Future<void> leave(String code) => _playersCol(code).doc(_user.uid).delete();

  /// Solo el Master puede expulsar a un jugador (y su ficha del mapa).
  Future<void> removePlayer(String code, String playerUid) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_playersCol(code).doc(playerUid));
    batch.delete(_tokensCol(code).doc('p_$playerUid'));
    await batch.commit();
  }

  Stream<List<GamePlayer>> players(String code) {
    return _playersCol(code).snapshots().map((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        final character = Character.fromMap(
          Map<String, dynamic>.from(data['character'] ?? {}),
          id: data['characterId'] as String?,
        );
        return GamePlayer(
          uid: d.id,
          email: (data['playerEmail'] ?? '') as String,
          character: character,
          color: (data['color'] as num?)?.toInt(),
          currentHp: ((data['currentHp'] ?? character.maxHp) as num).toInt(),
          slotsUsed: parseSlotMap(data['slotsUsed']),
          avatar: (data['avatar'] ?? '') as String,
          color2: (data['color2'] as num?)?.toInt(),
          deathSuccess: ((data['deathSuccess'] ?? 0) as num).toInt(),
          deathFail: ((data['deathFail'] ?? 0) as num).toInt(),
          dead: data['dead'] == true,
        );
      }).toList();
      list.sort((a, b) => a.character.name.compareTo(b.character.name));
      return list;
    });
  }

  // ==========================================
  // INICIO DE LA PARTIDA (SOLO EL MASTER)
  // ==========================================

  /// Casilla libre más cercana al origen.
  ({int x, int y}) _freeCell(Set<String> occupied, int cols, int rows) {
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        if (!occupied.contains(cellKey(x, y))) return (x: x, y: y);
      }
    }
    return (x: 0, y: 0);
  }

  /// Pasa la partida a "en juego": asigna colores, crea las fichas de los
  /// jugadores y deja preparado el mapa. Se puede repetir sin perder nada.
  Future<void> startGame(String code) async {
    final gameRef = _games.doc(code);
    final gameData = (await gameRef.get()).data() ?? {};
    final cols = ((gameData['cols'] ?? 20) as num).toInt();
    final rows = ((gameData['rows'] ?? 14) as num).toInt();

    final playersSnap = await _playersCol(code).get();
    final tokensSnap = await _tokensCol(code).get();

    final masterColor =
        (gameData['masterColor'] as num?)?.toInt() ?? GameColors.palette.first;

    final used = <int>[masterColor];
    for (final d in playersSnap.docs) {
      final c = (d.data()['color'] as num?)?.toInt();
      if (c != null) used.add(c);
    }

    final occupied = <String>{
      for (final t in tokensSnap.docs)
        cellKey(((t.data()['x'] ?? 0) as num).toInt(),
            ((t.data()['y'] ?? 0) as num).toInt()),
    };
    final tokenIds = tokensSnap.docs.map((d) => d.id).toSet();

    final batch = FirebaseFirestore.instance.batch();

    for (final d in playersSnap.docs) {
      if ((d.data()['color'] as num?) == null) {
        final color = GameColors.nextFree(used);
        used.add(color);
        batch.update(d.reference, {'color': color});
      }

      final tokenId = 'p_${d.id}';
      if (!tokenIds.contains(tokenId)) {
        final cell = _freeCell(occupied, cols, rows);
        occupied.add(cellKey(cell.x, cell.y));
        batch.set(_tokensCol(code).doc(tokenId), {
          'kind': 'player',
          'refId': d.id,
          'number': 1,
          'label': '',
          'x': cell.x,
          'y': cell.y,
          'hidden': false,
          'span': 1,
        });
      }
    }

    batch.update(gameRef, {
      'lastActivity': FieldValue.serverTimestamp(),
      'status': 'playing',
      'masterColor': masterColor,
      'cols': cols,
      'rows': rows,
    });
    // Solo se crea el terreno si no existe: así no se borra el mapa elegido.
    final terrainSnap = await _terrainDoc(code).get();
    if (!terrainSnap.exists) {
      batch.set(_terrainDoc(code), {'cells': <String, dynamic>{}});
    }

    await batch.commit();
  }

  /// Asigna color a los jugadores que todavía no lo tienen (los que entran
  /// con la partida ya empezada).
  Future<void> assignMissingColors(
    String code,
    List<GamePlayer> players,
    int masterColor,
  ) async {
    final used = <int>[
      masterColor,
      for (final p in players)
        if (p.color != null) p.color!,
    ];

    final batch = FirebaseFirestore.instance.batch();
    var changed = false;

    for (final p in players) {
      if (p.color == null) {
        final color = GameColors.nextFree(used);
        used.add(color);
        batch.update(_playersCol(code).doc(p.uid), {'color': color});
        changed = true;
      }
    }

    if (changed) await batch.commit();
  }

  // ==========================================
  // FICHA DEL JUGADOR EN TIEMPO REAL
  // ==========================================

  Future<void> updatePlayerHp(String code, String uid, int hp) =>
      _playersCol(code).doc(uid).update({
        'currentHp': hp < 0 ? 0 : hp,
        // Al recuperar PG se reinician las salvaciones y deja de estar muerto
        if (hp > 0) ...{'deathSuccess': 0, 'deathFail': 0, 'dead': false},
      });

  /// Salvaciones de muerte y estado de muerto (modificables a mano).
  Future<void> updateDeathSaves(
    String code,
    String uid, {
    int? success,
    int? fail,
    bool? dead,
  }) =>
      _playersCol(code).doc(uid).update({
        if (success != null) 'deathSuccess': success,
        if (fail != null) 'deathFail': fail,
        if (dead != null) 'dead': dead,
      });

  /// Aspecto de la ficha del jugador en el mapa: avatar y dos colores.
  Future<void> updatePlayerLook(
    String code,
    String uid, {
    String? avatar,
    int? color,
    int? color2,
  }) =>
      _playersCol(code).doc(uid).update({
        if (avatar != null) 'avatar': avatar,
        if (color != null) 'color': color,
        if (color2 != null) 'color2': color2,
      });

  /// El Master permite o no que los jugadores seleccionen criaturas.
  Future<void> setPlayersSelectCreatures(String code, bool value) =>
      _games.doc(code).update({'playersSelectCreatures': value});

  /// Espacios de conjuro gastados por un jugador (él mismo o el Master).
  Future<void> updatePlayerSlots(String code, String uid, Map<int, int> used) =>
      _playersCol(code).doc(uid).update({
        'slotsUsed': {for (final e in used.entries) '${e.key}': e.value},
      });

  /// El jugador modifica la copia de su ficha que está en la partida.
  Future<void> updatePlayerCharacter(String code, Character c) async {
    final ref = _playersCol(code).doc(_user.uid);
    final snap = await ref.get();
    final hp = ((snap.data()?['currentHp'] ?? c.maxHp) as num).toInt();

    await ref.update({
      'character': c.toMap(),
      'currentHp': hp > c.maxHp ? c.maxHp : hp,
    });
  }

  // ==========================================
  // FICHAS DEL MAPA
  // ==========================================

  /// El Master ve todas las fichas; los jugadores solo las no ocultas.
  Stream<List<GameToken>> tokens(String code, {required bool isMaster}) {
    final Query<Map<String, dynamic>> query = isMaster
        ? _tokensCol(code)
        : _tokensCol(code).where('hidden', isEqualTo: false);

    return query
        .snapshots()
        .map((snap) => snap.docs.map(GameToken.fromDoc).toList());
  }

  /// El jugador crea su propia ficha si todavía no la tiene
  /// (por ejemplo, si entra con la partida ya empezada).
  Future<void> ensurePlayerToken(String code) async {
    final ref = _tokensCol(code).doc('p_${_user.uid}');
    if ((await ref.get()).exists) return;

    await ref.set({
      'kind': 'player',
      'refId': _user.uid,
      'number': 1,
      'label': '',
      'x': 0,
      'y': 0,
      'hidden': false,
      'span': 1,
    });
  }

  Future<void> moveToken(String code, String tokenId, int x, int y) =>
      _tokensCol(code).doc(tokenId).update({'x': x, 'y': y});

  Future<void> setTokenHidden(String code, String tokenId, bool hidden) =>
      _tokensCol(code).doc(tokenId).update({'hidden': hidden});

  /// Saca una ficha de la zona "fuera del mapa" y la coloca en el mapa:
  /// en la casilla indicada o, si no se indica, en la primera libre.
  Future<void> placeTokenOnMap(
    String code,
    String tokenId, {
    int? x,
    int? y,
    int? floor,
  }) async {
    var px = x;
    var py = y;

    if (px == null || py == null) {
      final gameData = (await _games.doc(code).get()).data() ?? {};
      final cols = ((gameData['cols'] ?? 20) as num).toInt();
      final rows = ((gameData['rows'] ?? 14) as num).toInt();
      final tokens = await _tokensCol(code).get();
      final occupied = <String>{
        for (final t in tokens.docs)
          if (t.id != tokenId && t.data()['hidden'] != true)
            cellKey(((t.data()['x'] ?? 0) as num).toInt(),
                ((t.data()['y'] ?? 0) as num).toInt()),
      };
      final cell = _freeCell(occupied, cols, rows);
      px = cell.x;
      py = cell.y;
    }

    await _tokensCol(code)
        .doc(tokenId)
        .update({'x': px, 'y': py, 'hidden': false, if (floor != null) 'floor': floor});
  }

  Future<void> setTokenSpan(String code, String tokenId, int span) =>
      _tokensCol(code).doc(tokenId).update({'span': span});

  Future<void> setTokenLabel(String code, String tokenId, String label) =>
      _tokensCol(code).doc(tokenId).update({'label': label});

  /// Quita solo la ficha del mapa (la criatura sigue en la partida).
  Future<void> removeToken(String code, String tokenId) =>
      _tokensCol(code).doc(tokenId).delete();

  Map<String, dynamic> _creatureTokenData(
    String id,
    Map<String, dynamic> creatureDoc,
    int x,
    int y,
  ) {
    final apiIndex = creatureDoc['apiIndex'] as String?;
    return {
      'kind': 'creature',
      'refId': id,
      if (apiIndex != null) 'apiIndex': apiIndex,
      'number': ((creatureDoc['number'] ?? 1) as num).toInt(),
      // Solo las criaturas del bestiario llevan nombre; el de las de la API
      // se consulta a la API.
      'label': apiIndex == null ? (creatureDoc['label'] ?? '') : '',
      'x': x,
      'y': y,
      // Empiezan ocultas: el Master las coloca y las muestra cuando quiere
      'hidden': true,
      'span': 1,
      'hpPct': 100,
      if (apiIndex == null && creatureDoc['creature'] is Map)
        'icon': Avatars.tokenKey(
          isNpc: creatureDoc['creature']['kind'] == 'npc',
          type: (creatureDoc['creature']['creatureType'] ?? '').toString(),
        ),
    };
  }

  /// Crea la ficha de las criaturas de la partida que aún no tienen una.
  Future<void> ensureCreatureTokens(String code) async {
    final creatures = await _creaturesCol(code).get();
    if (creatures.docs.isEmpty) return;

    final tokens = await _tokensCol(code).get();
    final tokenIds = tokens.docs.map((d) => d.id).toSet();
    final missing =
        creatures.docs.where((d) => !tokenIds.contains(d.id)).toList();
    if (missing.isEmpty) return;

    final gameData = (await _games.doc(code).get()).data() ?? {};
    final cols = ((gameData['cols'] ?? 20) as num).toInt();
    final rows = ((gameData['rows'] ?? 14) as num).toInt();

    final occupied = <String>{
      for (final t in tokens.docs)
        cellKey(((t.data()['x'] ?? 0) as num).toInt(),
            ((t.data()['y'] ?? 0) as num).toInt()),
    };

    final batch = FirebaseFirestore.instance.batch();
    for (final d in missing) {
      final cell = _freeCell(occupied, cols, rows);
      occupied.add(cellKey(cell.x, cell.y));
      batch.set(
        _tokensCol(code).doc(d.id),
        _creatureTokenData(d.id, d.data(), cell.x, cell.y),
      );
    }
    await batch.commit();
  }

  /// Al cambiar el tamaño del mapa, las fichas que quedan fuera se acercan.
  Future<void> setGridSize(String code, int cols, int rows) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_games.doc(code), {'cols': cols, 'rows': rows});

    final tokens = await _tokensCol(code).get();
    for (final t in tokens.docs) {
      final data = t.data();
      final x = ((data['x'] ?? 0) as num).toInt();
      final y = ((data['y'] ?? 0) as num).toInt();
      final nx = x >= cols ? cols - 1 : x;
      final ny = y >= rows ? rows - 1 : y;
      if (nx != x || ny != y) batch.update(t.reference, {'x': nx, 'y': ny});
    }

    await batch.commit();
  }

  // ==========================================
  // TERRENO DEL MAPA
  // ==========================================

  Stream<Map<String, String>> terrain(String code, [int floor = 0]) {
    return _terrainDoc(code, floor).snapshots().map((snap) {
      final raw = (snap.data()?['cells'] as Map?) ?? {};
      return {for (final e in raw.entries) e.key.toString(): e.value.toString()};
    });
  }

  /// Pinta (o borra, si el valor es null) varias casillas a la vez.
  Future<void> paintCells(String code, Map<String, String?> cells,
      [int floor = 0]) {
    return _terrainDoc(code, floor).set({
      'cells': {
        for (final e in cells.entries) e.key: e.value ?? FieldValue.delete(),
      },
    }, SetOptions(merge: true));
  }

  Future<void> clearTerrain(String code, [int floor = 0]) =>
      _terrainDoc(code, floor).set({'cells': <String, dynamic>{}});

  // ==========================================
  // PISOS (hojas del mapa)
  // ==========================================

  /// Cambia los nombres de los pisos (añadir o renombrar). La cantidad no
  /// puede bajar: para quitar un piso, usa [removeLastFloor].
  Future<void> setFloorNames(String code, List<String> names) =>
      _games.doc(code).update({'floorNames': names});

  /// Quita el último piso: borra su terreno y devuelve sus fichas al piso
  /// anterior.
  Future<void> removeLastFloor(String code, List<String> names) async {
    if (names.length < 2) return;
    final last = names.length - 1;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_games.doc(code), {
      'floorNames': names.sublist(0, last),
    });
    batch.delete(_terrainDoc(code, last));
    final toks = await _tokensCol(code).where('floor', isEqualTo: last).get();
    for (final t in toks.docs) {
      batch.update(t.reference, {'floor': last - 1});
    }
    await batch.commit();
  }

  /// Mueve una ficha a otra casilla y piso (escaleras, trampillas...).
  Future<void> moveTokenToFloor(
    String code,
    String tokenId,
    int x,
    int y,
    int floor,
  ) =>
      _tokensCol(code).doc(tokenId).update({'x': x, 'y': y, 'floor': floor});

  // ==========================================
  // DADOS
  // ==========================================

  Stream<List<DiceRoll>> rolls(String code) {
    return _rollsCol(code)
        .orderBy('at', descending: true)
        .limit(60)
        .snapshots()
        .map((snap) => snap.docs.map(DiceRoll.fromDoc).toList());
  }

  /// Publica una tirada descubierta: la ven todos en el registro.
  Future<void> postRoll(String code, DiceRoll roll) {
    return _rollsCol(code).add({
      'uid': roll.uid,
      'name': roll.name,
      'color': roll.color,
      'die': roll.die,
      'values': roll.values,
      'mode': roll.mode,
      'chosen': roll.chosen,
      'title': roll.title,
      'groups': roll.groups.map((g) => g.toMap()).toList(),
      'at': FieldValue.serverTimestamp(),
    });
  }

  /// Tiradas ocultas: el Master ve todas; un jugador solo las suyas.
  Stream<List<DiceRoll>> hiddenRolls(
    String code, {
    required bool isMaster,
    required String uid,
  }) {
    Query<Map<String, dynamic>> q = _hiddenRollsCol(code);
    if (!isMaster) q = q.where('uid', isEqualTo: uid);
    return q.limit(80).snapshots().map((snap) {
      final list = snap.docs.map(DiceRoll.fromDoc).toList();
      list.sort((a, b) => (b.at ?? DateTime.now())
          .compareTo(a.at ?? DateTime.now()));
      return list;
    });
  }

  /// Publica una tirada oculta (solo la ven quien la hace y el Master).
  Future<void> postHiddenRoll(String code, DiceRoll roll) {
    return _hiddenRollsCol(code).add({
      'uid': roll.uid,
      'name': roll.name,
      'color': roll.color,
      'die': roll.die,
      'values': roll.values,
      'mode': roll.mode,
      'chosen': roll.chosen,
      'title': roll.title,
      'groups': roll.groups.map((g) => g.toMap()).toList(),
      'at': FieldValue.serverTimestamp(),
    });
  }

  // ==========================================
  // INICIATIVA Y TURNOS
  // ==========================================

  /// Estado del combate (null si no hay combate).
  Stream<CombatState?> combat(String code) => _combatDoc(code).snapshots().map(
        (s) => s.exists && s.data() != null
            ? CombatState.fromMap(s.data()!)
            : null,
      );

  /// El Master empieza (o reinicia) el combate con las tiradas hechas.
  Future<void> startCombat(String code, List<InitEntry> entries) {
    return _combatDoc(code).set({
      'active': true,
      'round': 1,
      'current': entries.isEmpty ? '' : entries.first.id,
      'entries': entries.map((e) => e.toMap()).toList(),
    });
  }

  /// El Master prepara el combate: fase de tiradas de iniciativa.
  /// Cada jugador tira la suya; el Master tira por las criaturas.
  Future<void> startInitiativePhase(String code, List<InitEntry> entries) {
    return _combatDoc(code).set({
      'active': true,
      'phase': 'rolling',
      'round': 1,
      'current': '',
      'entries': entries.map((e) => e.toMap()).toList(),
      'rolls': <String, dynamic>{},
    });
  }

  /// Guarda una tirada de iniciativa (un jugador solo puede tirar por sí mismo).
  Future<void> postInitiativeRoll(
    String code,
    String entryId, {
    required int roll,
    required int mod,
  }) {
    return _combatDoc(code).update({
      'rolls.$entryId': {'roll': roll, 'mod': mod},
    });
  }

  /// El Master da por terminada la fase de tiradas y empieza los turnos.
  Future<void> startTurns(String code, List<InitEntry> sortedEntries) {
    return _combatDoc(code).update({
      'phase': 'turns',
      'round': 1,
      'current': sortedEntries.isEmpty ? '' : sortedEntries.first.id,
      'entries': sortedEntries.map((e) => e.toMap()).toList(),
      'rolls': <String, dynamic>{},
    });
  }

  /// El Master modifica la lista (orden, resultados, altas y bajas).
  Future<void> saveCombatEntries(
    String code,
    List<InitEntry> entries, {
    String? current,
  }) {
    return _combatDoc(code).update({
      'entries': entries.map((e) => e.toMap()).toList(),
      if (current != null) 'current': current,
    });
  }

  /// Pasa el turno (lo puede hacer el Master o el jugador al que le toca).
  Future<void> setTurn(String code, String current, int round) =>
      _combatDoc(code).update({'current': current, 'round': round});

  Future<void> endCombat(String code) => _combatDoc(code).delete();

  // ==========================================
  // CRIATURAS DE LA PARTIDA (NPC y monstruos)
  // ==========================================

  /// Añade criaturas a la partida (solo el Master) y crea su ficha oculta
  /// en el mapa.
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

    // Casillas libres para las fichas nuevas
    final gameData = (await _games.doc(code).get()).data() ?? {};
    final cols = ((gameData['cols'] ?? 20) as num).toInt();
    final rows = ((gameData['rows'] ?? 14) as num).toInt();
    final tokens = await _tokensCol(code).get();
    final occupied = <String>{
      for (final t in tokens.docs)
        cellKey(((t.data()['x'] ?? 0) as num).toInt(),
            ((t.data()['y'] ?? 0) as num).toInt()),
    };

    final batch = FirebaseFirestore.instance.batch();

    void addDoc(Map<String, dynamic> creatureData) {
      final ref = col.doc();
      final cell = _freeCell(occupied, cols, rows);
      occupied.add(cellKey(cell.x, cell.y));

      batch.set(ref, creatureData);
      batch.set(
        _tokensCol(code).doc(ref.id),
        _creatureTokenData(ref.id, creatureData, cell.x, cell.y),
      );
    }

    custom.forEach((c, qty) {
      final already = customCounts[c.name] ?? 0;
      for (var i = 1; i <= qty; i++) {
        final label = (already + qty > 1) ? '${c.name} ${already + i}' : c.name;
        addDoc({
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
        addDoc({
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

  /// Una criatura de la partida (para abrir su ficha desde el mapa).
  Future<GameCreature?> getGameCreature(String code, String id) async {
    final snap = await _creaturesCol(code).doc(id).get();
    return snap.exists ? GameCreature.fromDoc(snap) : null;
  }

  /// Guarda los puntos de golpe perdidos de una criatura.
  /// Espacios de conjuro de una criatura: gastados y (opcional) máximos
  /// propios, para NPC cuyo máximo no viene de la API.
  Future<void> updateCreatureSlots(
    String code,
    String creatureId, {
    Map<int, int>? used,
    Map<int, int>? max,
  }) =>
      _creaturesCol(code).doc(creatureId).update({
        if (used != null)
          'slotsUsed': {for (final e in used.entries) '${e.key}': e.value},
        if (max != null)
          'slotsMax': {for (final e in max.entries) '${e.key}': e.value},
      });

  /// Si se indica [maxHp], se actualiza también la barra de salud de la
  /// ficha del mapa (la que ven los jugadores).
  Future<void> updateCreatureDamage(
    String code,
    String creatureId,
    int damage, {
    int? maxHp,
  }) async {
    await _creaturesCol(code).doc(creatureId).update({'damageTaken': damage});
    if (maxHp != null && maxHp > 0) {
      final left = (maxHp - damage).clamp(0, maxHp).toInt();
      try {
        await _tokensCol(code)
            .doc(creatureId)
            .update({'hpPct': ((left * 100) / maxHp).round()});
      } catch (_) {}
    }
  }

  /// Quita la criatura de la partida y su ficha del mapa.
  Future<void> removeCreature(String code, String creatureId) async {
    final batch = FirebaseFirestore.instance.batch();
    batch.delete(_creaturesCol(code).doc(creatureId));
    batch.delete(_tokensCol(code).doc(creatureId));
    await batch.commit();
  }

  // ==========================================
  // ACTIVIDAD, LIMPIEZA Y FIN DE SESIÓN
  // ==========================================

  /// Una partida sin actividad durante este tiempo se borra.
  static const Duration inactivityLimit = Duration(hours: 24);

  /// Marca la partida como activa (se llama cada pocos minutos mientras
  /// alguien tiene el mapa abierto).
  Future<void> touch(String code) =>
      _games.doc(code).update({'lastActivity': FieldValue.serverTimestamp()});

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    final snap = await col.get();
    for (var i = 0; i < snap.docs.length; i += 400) {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in snap.docs.skip(i).take(400)) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  /// Borra la partida y todo lo que cuelga de ella (solo el Master).
  Future<void> deleteGameData(String code) async {
    final game = _games.doc(code);
    for (final name in ['players', 'creatures', 'tokens', 'rolls', 'map']) {
      await _deleteCollection(game.collection(name));
    }
    // El combate se añadió después: si las reglas de Firestore aún no lo
    // permiten, no debe impedir terminar la sesión.
    try {
      await _deleteCollection(game.collection('combat'));
    } catch (_) {}
    try {
      await _deleteCollection(game.collection('hiddenRolls'));
    } catch (_) {}
    await game.delete();
  }

  /// Reinicia la sala (solo el Master): la partida vuelve al estado de sala
  /// de espera. Se quitan las fichas del mapa, el combate y el registro de
  /// dados. Se conservan jugadores, criaturas, mapa y terreno.
  Future<void> resetRoom(String code) async {
    final game = _games.doc(code);
    // Primero el estado, para que los jugadores vuelvan a la sala
    await game.update({
      'status': 'lobby',
      'lastActivity': FieldValue.serverTimestamp(),
    });
    await _deleteCollection(game.collection('tokens'));
    try {
      await _deleteCollection(game.collection('combat'));
    } catch (_) {}
    await _deleteCollection(game.collection('rolls'));
    try {
      await _deleteCollection(game.collection('hiddenRolls'));
    } catch (_) {}
  }

  /// Termina la sesión: avisa a los jugadores y borra la partida.
  Future<void> endGame(String code) async {
    await _games.doc(code).update({'status': 'ended'});
    // Margen para que los jugadores reciban el aviso antes de borrar
    await Future<void>.delayed(const Duration(seconds: 3));
    await deleteGameData(code);
  }

  /// Borra mis partidas inactivas (más de 24 h) o terminadas y devuelve todas
  /// las que siguen activas (la más reciente primero), para poder
  /// reconectarse como Master a cualquiera de ellas.
  Future<List<({String code, String name, String status})>>
      cleanupAndFindMyGames() async {
    final snap =
        await _games.where('masterUid', isEqualTo: _user.uid).get();

    final now = DateTime.now();
    final alive =
        <({String code, String name, String status, DateTime? at})>[];

    for (final d in snap.docs) {
      final data = d.data();
      final at = ((data['lastActivity'] ?? data['createdAt']) as Timestamp?)
          ?.toDate();
      final stale = data['status'] == 'ended' ||
          (at != null && now.difference(at) > inactivityLimit);

      if (stale) {
        try {
          await deleteGameData(d.id);
        } catch (_) {}
        continue;
      }
      alive.add((
        code: d.id,
        name: (data['name'] ?? 'Partida') as String,
        status: (data['status'] ?? 'lobby') as String,
        at: at,
      ));
    }

    alive.sort((a, b) {
      final x = a.at, y = b.at;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return y.compareTo(x);
    });

    return [
      for (final g in alive) (code: g.code, name: g.name, status: g.status),
    ];
  }

  // ==========================================
  // OBJETOS DE LOS JUGADORES
  // ==========================================

  /// Quita los valores nulos de un mapa (anidados incluidos).
  static Map<String, dynamic> _withoutNulls(Map<String, dynamic> m) {
    final out = <String, dynamic>{};
    m.forEach((k, v) {
      if (v == null) return;
      out[k] = v is Map ? _withoutNulls(Map<String, dynamic>.from(v)) : v;
    });
    return out;
  }

  /// Añade objetos (índices de la API) a la copia del personaje en la partida.
  ///
  /// [custom] lleva los datos de los objetos creados por el Master (id -> datos),
  /// que se copian en la ficha del jugador.
  ///
  /// No usa transacciones: en Windows pueden cerrar la aplicación.
  Future<void> addItemsToPlayer(
    String code,
    String uid,
    List<String> items, {
    Map<String, Map<String, dynamic>> custom = const {},
  }) async {
    final ref = _playersCol(code).doc(uid);
    final snap = await ref.get();
    final char = (snap.data()?['character'] as Map?) ?? const {};

    final current = List<String>.from(char['items'] ?? const []);
    final customItems = <String, dynamic>{
      for (final e in ((char['customItems'] as Map?) ?? const {}).entries)
        e.key.toString(): e.value,
      for (final e in custom.entries) e.key: _withoutNulls(e.value),
    };

    await ref.update({
      'character.items': [...current, ...items],
      if (customItems.isNotEmpty) 'character.customItems': customItems,
    });
  }

  /// Quita un ejemplar del objeto (y lo desequipa si ya no queda ninguno).
  Future<void> removeItemFromPlayer(String code, String uid, String item) async {
    final ref = _playersCol(code).doc(uid);
    final snap = await ref.get();
    final char = (snap.data()?['character'] as Map?) ?? const {};

    final items = List<String>.from(char['items'] ?? const []);
    final equipped = List<String>.from(char['equipped'] ?? const []);

    items.remove(item);
    if (!items.contains(item)) equipped.remove(item);

    await ref.update({
      'character.items': items,
      'character.equipped': equipped,
    });
  }

  Future<void> setPlayerEquipped(String code, String uid, List<String> equipped) =>
      _playersCol(code).doc(uid).update({'character.equipped': equipped});
}
