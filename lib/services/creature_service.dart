import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../data/preset_creatures.dart';
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

  /// Carga en la base de datos el bestiario predeterminado del usuario.
  ///
  /// Se ejecuta una sola vez por versión de datos (kPresetsVersion), así que
  /// si el usuario borra o edita una criatura predeterminada no se
  /// sobrescribe ni se vuelve a crear.
  Future<void> seedPresetsIfNeeded() async {
    final userRef = _db.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final seeded = ((userSnap.data()?['presetsVersion'] ?? 0) as num).toInt();

    if (seeded >= kPresetsVersion) return;

    final existing = await _col
        .where('ownerUid', isEqualTo: uid)
        .where('isPreset', isEqualTo: true)
        .get();
    final existingIds = existing.docs.map((d) => d.id).toSet();

    final batch = _db.batch();

    for (final preset in buildPresetCreatures(uid)) {
      if (existingIds.contains(preset.id)) continue;
      batch.set(_col.doc(preset.id), preset.toMap());
    }

    batch.set(
      userRef,
      {'presetsVersion': kPresetsVersion},
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
