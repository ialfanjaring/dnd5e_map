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

  /// Carga el mapa en la partida: tamaño y terreno (sustituye al anterior).
  /// Las fichas que quedan fuera de la cuadrícula se acercan al borde.
  Future<void> applyToGame(String code, MapTemplate m) async {
    final game = _db.collection('games').doc(code);
    final batch = _db.batch();

    batch.update(game, {
      'cols': m.cols,
      'rows': m.rows,
      'mapName': m.name,
    });
    batch.set(game.collection('map').doc('terrain'), {'cells': m.cells});

    final tokens = await game.collection('tokens').get();
    for (final t in tokens.docs) {
      final d = t.data();
      final x = ((d['x'] ?? 0) as num).toInt();
      final y = ((d['y'] ?? 0) as num).toInt();
      final nx = x >= m.cols ? m.cols - 1 : x;
      final ny = y >= m.rows ? m.rows - 1 : y;
      if (nx != x || ny != y) batch.update(t.reference, {'x': nx, 'y': ny});
    }

    await batch.commit();
  }
}
