import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/character.dart';

class CharacterService {
  final CollectionReference<Map<String, dynamic>> _col =
      FirebaseFirestore.instance.collection('characters');

  String get uid => FirebaseAuth.instance.currentUser!.uid;

  /// Personajes del usuario actual (ordenados por nombre).
  Stream<List<Character>> myCharacters() {
    return _col.where('ownerUid', isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs.map(Character.fromDoc).toList();
      list.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return list;
    });
  }

  Future<void> save(Character c) async {
    if (c.id == null) {
      await _col.add(c.toMap());
    } else {
      await _col.doc(c.id).set(c.toMap());
    }
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}
