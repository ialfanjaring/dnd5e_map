import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
final FirebaseAuth _auth = FirebaseAuth.instance;

// Usuario actualmente autenticado.
User? get currentUser => _auth.currentUser;

// Escucha los cambios en la sesión.
Stream<User?> get authStateChanges =>
_auth.authStateChanges();

// Iniciar sesión.
Future<UserCredential> login({
required String email,
required String password,
}) async {
return await _auth.signInWithEmailAndPassword(
email: email.trim(),
password: password,
);
}

// Registrar usuario.
Future<UserCredential> register({
required String email,
required String password,
}) async {
return await _auth.createUserWithEmailAndPassword(
email: email.trim(),
password: password,
);
}

// Cerrar sesión.
Future<void> logout() async {
await _auth.signOut();
}
}
