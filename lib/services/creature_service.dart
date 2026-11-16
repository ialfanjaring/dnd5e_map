import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/creature.dart';

class CreatureService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('creatures');

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// Criaturas del usuario (monstruos y NPC), ordenadas por nombre.
  Stream<List<Creature>> myCreatures() {
    return _col.where('ownerUid', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs.map(Creature.fromDoc).toList();
      list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return list;
    });
  }

  Future<void> save(Creature c) async {
    if (c.id == null) {
      await _col.add(c.toMap());
    } else {
      await _col.doc(c.id).set(c.toMap());
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();

  /// Borra, una sola vez por usuario, los datos de la API que versiones
  /// anteriores de la app guardaron en la base de datos: las criaturas por
  /// defecto (ids "..._srd_...") y los monstruos importados (ids "..._api_...").
  /// Las criaturas creadas por el usuario no se tocan.
  Future<void> removeStoredApiDataIfNeeded() async {
    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();

    if (userSnap.data()?['apiDataRemoved'] == true) return;

    final stored = await _col
        .where('ownerUid', isEqualTo: uid)
        .where('isPreset', isEqualTo: true)
        .get();

    final batch = _db.batch();

    for (final doc in stored.docs) {
      if (doc.id.startsWith('${uid}_srd_') ||
          doc.id.startsWith('${uid}_api_')) {
        batch.delete(doc.reference);
      }
    }

    batch.set(
      userRef,
      {'apiDataRemoved': true},
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
