import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as mobile_google;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
as desktop_google;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign-In para Windows.
  // Sustituye estos valores por tus credenciales OAuth de Google Cloud.
  late final desktop_google.GoogleSignIn _desktopGoogleSignIn =
  desktop_google.GoogleSignIn(
    params: const desktop_google.GoogleSignInParams(
      clientId: '553630619928-fqihdnidjdv6vmdcl1s9qvbn5m5sjkun.apps.googleusercontent.com',
      clientSecret: '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',
      redirectPort: 50000,
      scopes: [
        'openid',
        'profile',
        'email',
      ],
    ),
  );

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  // Inicialización de Google Sign-In.
  Future<void> initializeGoogleSignIn() async {
    // Windows utiliza google_sign_in_all_platforms.
    if (_isWindows || kIsWeb) return;

    // Android, iOS y macOS utilizan el paquete oficial.
    await mobile_google.GoogleSignIn.instance.initialize();
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
  Future<UserCredential> loginWithGoogle() async {
    // WEB
    if (kIsWeb) {
      final provider = GoogleAuthProvider();

      return _auth.signInWithPopup(provider);
    }

    // WINDOWS
    if (_isWindows) {
      final credentials = await _desktopGoogleSignIn.signIn();

      if (credentials == null) {
        throw Exception('El inicio de sesión con Google fue cancelado.');
      }

      final OAuthCredential firebaseCredential =
      GoogleAuthProvider.credential(
        idToken: credentials.idToken,
        accessToken: credentials.accessToken,
      );

      return _auth.signInWithCredential(firebaseCredential);
    }

    // ANDROID / IOS / MACOS
    final mobile_google.GoogleSignInAccount googleUser =
    await mobile_google.GoogleSignIn.instance.authenticate();

    final mobile_google.GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final OAuthCredential firebaseCredential =
    GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(firebaseCredential);
  }

  // Cierre de sesión.
  Future<void> logout() async {
    await _auth.signOut();

    if (kIsWeb) return;

    if (_isWindows) {
      await _desktopGoogleSignIn.signOut();
    } else {
      await mobile_google.GoogleSignIn.instance.signOut();
    }
  }
}