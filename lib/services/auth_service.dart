import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as mobile_google;
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
as desktop_google;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Google Sign-In para Windows.
  // static: se crea una sola vez para toda la app (el paquete no admite
  // inicializarse dos veces, aunque haya varias instancias de AuthService).
  static final desktop_google.GoogleSignIn _desktopGoogleSignIn =
  desktop_google.GoogleSignIn(
    params: const desktop_google.GoogleSignInParams(
      clientId:
      '553630619928-fqihdnidjdv6vmdcl1s9qvbn5m5sjkun.apps.googleusercontent.com',
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

      // Diagnóstico temporal: se puede quitar cuando el acceso funcione.
      debugPrint('Google idToken nulo: ${credentials.idToken == null}');
      _debugJwt(credentials.idToken);

      try {
        return await _auth.signInWithCredential(firebaseCredential);
      } on FirebaseAuthException catch (e) {
        debugPrint('Firebase: ${e.code} - ${e.message}');
        rethrow;
      }
    }

    // ANDROID / IOS / MACOS
    final mobile_google.GoogleSignInAccount googleUser =
    await mobile_google.GoogleSignIn.instance.authenticate();

    final mobile_google.GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    final OAuthCredential firebaseCredential = GoogleAuthProvider.credential(
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

  // Diagnóstico temporal: muestra de qué cliente es el token y cuándo caduca.
  // No imprime el token en sí.
  void _debugJwt(String? token) {
    if (token == null) return;

    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        debugPrint('idToken con formato raro');
        return;
      }

      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      ) as Map<String, dynamic>;

      final exp = DateTime.fromMillisecondsSinceEpoch(
        (payload['exp'] as num).toInt() * 1000,
      );

      debugPrint('aud: ${payload['aud']}');
      debugPrint('iss: ${payload['iss']}');
      debugPrint('expira: $exp   ahora: ${DateTime.now()}');
    } catch (e) {
      debugPrint('No se pudo leer el idToken: $e');
    }
  }
}