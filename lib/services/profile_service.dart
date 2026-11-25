import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Perfil público del usuario. Por ahora solo el nickname, que es lo único
/// que ven los demás en las partidas (nunca el correo).
///
/// Se guarda en users/{uid} (campo `nickname`), que solo puede leer su dueño.
/// Al crear o entrar en una partida se copia en la partida.
class ProfileService {
  ProfileService._();
  static final ProfileService instance = ProfileService._();

  static const int minLength = 3;
  static const int maxLength = 20;

  String? _uid;
  String? _nickname;

  /// Nickname del usuario actual (vacío si aún no se ha cargado o no tiene).
  String get nickname =>
      _uid == FirebaseAuth.instance.currentUser?.uid ? (_nickname ?? '') : '';

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// Lee el nickname del usuario actual. Devuelve '' si no tiene.
  Future<String> load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return '';
    final snap = await _doc(uid).get();
    _uid = uid;
    _nickname = (snap.data()?['nickname'] ?? '').toString().trim();
    return _nickname!;
  }

  /// Comprueba un nickname. Devuelve el texto del error o null si es válido.
  static String? validate(String value) {
    final v = value.trim();
    if (v.length < minLength) {
      return 'El nickname debe tener al menos 3 caracteres';
    }
    if (v.length > maxLength) {
      return 'El nickname no puede tener más de 20 caracteres';
    }
    if (!RegExp(r'^[A-Za-z0-9ÁÉÍÓÚÜÑáéíóúüñ _.\-]+$').hasMatch(v)) {
      return 'Solo letras, números, espacios y . _ -';
    }
    return null;
  }

  Future<void> setNickname(String value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('No hay sesión iniciada.');
    final v = value.trim();
    final err = validate(v);
    if (err != null) throw Exception(err);
    await _doc(uid).set({
      'nickname': v,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _uid = uid;
    _nickname = v;
  }
}
