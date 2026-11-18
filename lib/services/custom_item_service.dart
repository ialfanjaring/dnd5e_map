import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'equipment_api_service.dart';

/// Objetos creados por el Master. Solo los ve su autor; al asignarlos a un
/// jugador se copia el objeto en la ficha del jugador dentro de la partida.
class CustomItemService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('users').doc(_uid).collection('items');

  Stream<List<ApiItem>> myItems() {
    return _col.snapshots().map((snap) {
      final list = snap.docs
          .map((d) => ApiItem.fromMap('${ApiItem.customPrefix}${d.id}', d.data()))
          .toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      for (final it in list) {
        EquipmentApiService.registerCustom(it);
      }
      return list;
    });
  }

  /// [index] null = objeto nuevo.
  Future<void> save(ApiItem item, {String? index}) async {
    final data = {...item.toMap(), 'updatedAt': FieldValue.serverTimestamp()};
    if (index == null) {
      await _col.add(data);
    } else {
      await _col.doc(index.substring(ApiItem.customPrefix.length)).set(data);
    }
  }

  Future<void> delete(String index) =>
      _col.doc(index.substring(ApiItem.customPrefix.length)).delete();
}
