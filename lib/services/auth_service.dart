import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Inicialización de Google Sign-In para plataformas nativas.
  Future<void> initializeGoogleSignIn() async {
    if (!kIsWeb) {
      await GoogleSignIn.instance.initialize();
    }
  }

  // Inicio de sesión con correo y contraseña.
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Registro con correo y contraseña.
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  // Inicio de sesión con Google.
  // En web se utiliza Firebase Auth.
  // En Android se mantiene Google Sign-In.
  Future<UserCredential> loginWithGoogle() async {
    if (kIsWeb) {
      final GoogleAuthProvider provider = GoogleAuthProvider();

      return _auth.signInWithPopup(provider);
    }

    final GoogleSignInAccount googleUser =
    await GoogleSignIn.instance.authenticate();

    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  // Cierre de sesión.
  Future<void> logout() async {
    await _auth.signOut();

    // La instancia de Google Sign-In solo se utiliza
    // para las plataformas nativas.
    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
  }
}