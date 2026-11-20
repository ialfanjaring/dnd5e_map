import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/map_template.dart';

/// Mapas creados por el Master (solo los suyos) y aplicación de un mapa a
/// una partida. Los mapas predeterminados no se guardan: viven en el código.
class MapService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('maps');

  Stream<List<MapTemplate>> myMaps() {
    return _col.snapshots().map((snap) {
      final list = snap.docs.map(MapTemplate.fromDoc).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    });
  }

  Future<void> save(MapTemplate m) async {
    final data = {
      ...m.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (m.id == null) {
      await _col.add(data);
    } else {
      await _col.doc(m.id).set(data);
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Carga el mapa en la partida: tamaño, pisos y terreno (sustituye al
  /// anterior). Las fichas vuelven al primer piso y las que quedan fuera de
  /// la cuadrícula se acercan al borde.
  Future<void> applyToGame(String code, MapTemplate m) async {
    final game = _db.collection('games').doc(code);
    final batch = _db.batch();

    final names = [for (var i = 0; i < m.floorCount; i++) m.floorName(i)];
    batch.update(game, {
      'cols': m.cols,
      'rows': m.rows,
      'mapName': m.name,
      'floorNames': names,
    });

    final mapCol = game.collection('map');
    for (var i = 0; i < m.floorCount; i++) {
      batch.set(
        mapCol.doc(i == 0 ? 'terrain' : 'terrain$i'),
        {'cells': m.floorCells(i)},
      );
    }
    // Pisos sobrantes de un mapa anterior
    final old = await mapCol.get();
    for (final d in old.docs) {
      if (!d.id.startsWith('terrain') || d.id == 'terrain') continue;
      final n = int.tryParse(d.id.substring(7));
      if (n != null && n >= m.floorCount) batch.delete(d.reference);
    }

    final tokens = await game.collection('tokens').get();
    for (final t in tokens.docs) {
      final d = t.data();
      final x = ((d['x'] ?? 0) as num).toInt();
      final y = ((d['y'] ?? 0) as num).toInt();
      final nx = x >= m.cols ? m.cols - 1 : x;
      final ny = y >= m.rows ? m.rows - 1 : y;
      final floor = ((d['floor'] ?? 0) as num).toInt();
      if (nx != x || ny != y || floor != 0) {
        batch.update(t.reference, {'x': nx, 'y': ny, 'floor': 0});
      }
    }

    await batch.commit();
  }
}
