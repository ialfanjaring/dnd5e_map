import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as mobile_google;

import 'google_desktop_auth.dart';

/// Excepción con mensajes legibles para la UI.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Servicio de autenticación (versión sencilla).
class AuthService {
  AuthService._();

  static final AuthService _instance = AuthService._();

  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cooldown de 60 s para reenviar el correo de verificación.
  static DateTime? _lastVerificationSent;
  static const int _cooldownDuration = 60;

  // Credenciales OAuth de escritorio (Windows), escritas directamente aquí.
  // Rellena los dos valores con los de tu cliente OAuth de tipo "Escritorio".
  // El ID tiene la forma 1234567890-abc123.apps.googleusercontent.com
  static const String _desktopClientId = '553630619928-iegivq87k1tb8gc5orekd25lirvtr50g.apps.googleusercontent.com';
  static const String _desktopClientSecret = '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';
  static const int _redirectPort = 61797;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Stream<User?> get userChanges => _auth.userChanges();

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  int get resendCooldownSeconds {
    if (_lastVerificationSent == null) return 0;
    final elapsed =
        DateTime
            .now()
            .difference(_lastVerificationSent!)
            .inSeconds;
    final left = _cooldownDuration - elapsed;
    return left > 0 ? left : 0;
  }

  Future<void> initializeGoogleSignIn() async {
    if (_isWindows || kIsWeb) return;
    await mobile_google.GoogleSignIn.instance.initialize();
  }

  /// Inicio de sesión con correo y contraseña.
  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'too-many-requests':
          throw const AuthException(
              'Demasiados intentos. Inténtalo más tarde.');
        case 'network-request-failed':
          throw const AuthException('Sin conexión con el servidor.');
        case 'user-disabled':
          throw const AuthException('Esta cuenta está deshabilitada.');
        default:
        // Mensaje genérico: no revela si el correo existe.
          throw const AuthException('Correo o contraseña incorrectos.');
      }
    }
  }

  /// Registro y envío del correo de verificación.
  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (cred.user != null && !cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification();
        _lastVerificationSent = DateTime.now();
      }
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' => 'No se pudo crear la cuenta con ese correo.',
        'invalid-email' => 'El formato del correo no es válido.',
        'weak-password' => 'La contraseña es demasiado débil.',
        'network-request-failed' => 'Sin conexión con el servidor.',
        _ => 'No se pudo crear la cuenta (${e.code}).',
      };
      throw AuthException(msg);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'invalid-email' => 'El formato del correo electrónico no es válido.',
        'too-many-requests' => 'Demasiados intentos. Inténtalo más tarde.',
        'network-request-failed' => 'Sin conexión con el servidor.',
        _ => 'No se pudo enviar el correo.',
      };
      throw AuthException(msg);
    }
  }

  Future<bool> refreshVerification() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthException('No hay ninguna sesión activa.');
    }
    if (resendCooldownSeconds > 0) {
      throw AuthException(
          'Espera $resendCooldownSeconds segundos antes de reenviar.');
    }
    try {
      await user.sendEmailVerification();
      _lastVerificationSent = DateTime.now();
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'too-many-requests' =>
        'Has solicitado demasiados correos. Espera unos minutos.',
        'network-request-failed' => 'Revisa tu conexión a internet.',
        _ => 'Error al reenviar el correo.',
      };
      throw AuthException(msg);
    }
  }

  /// Inicio de sesión con Google.
  Future<UserCredential> loginWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _auth.signInWithPopup(GoogleAuthProvider());
      }

      if (_isWindows) {
        debugPrint('GOOGLE client_id en uso: $_desktopClientId');

        if (_desktopClientId.startsWith('PEGA_AQUI') ||
            _desktopClientSecret.startsWith('PEGA_AQUI'))
        {

          throw const AuthException(
              'Faltan el Client ID y el Client Secret de Google en '
                  'auth_service.dart.');
        }
        // Flujo propio: navegador + localhost, sin librerías de terceros.
        final tokens = await GoogleDesktopAuth.signIn(
          clientId: _desktopClientId,
          clientSecret: _desktopClientSecret,
          port: _redirectPort,
        );
        return await _auth.signInWithCredential(
          GoogleAuthProvider.credential(
            idToken: tokens.idToken,
            accessToken: tokens.accessToken,
          ),
        );
      }

      final googleUser =
      await mobile_google.GoogleSignIn.instance.authenticate();
      return await _auth.signInWithCredential(
        GoogleAuthProvider.credential(
            idToken: googleUser.authentication.idToken),
      );
    } on AuthException {
      rethrow;
    } on FirebaseAuthException catch (e) {
      debugPrint('GOOGLE LOGIN FIREBASE ERROR: ${e.code} ${e.message}');
      final msg = switch (e.code) {
        'account-exists-with-different-credential' =>
        'Esta cuenta ya está registrada con otro método de acceso.',
        'operation-not-allowed' =>
        'El acceso con Google no está habilitado en Firebase.',
        'network-request-failed' => 'No se pudo conectar con Firebase.',
        'invalid-credential' => 'Las credenciales de Google no son válidas.',
        'user-disabled' => 'Esta cuenta está deshabilitada.',
        _ => 'No se pudo iniciar sesión con Google.',
      };
      throw AuthException(msg);
    } catch (e, st) {
      debugPrint('GOOGLE LOGIN ERROR (${e.runtimeType}): $e\n$st');
      if (e.toString().toLowerCase().contains('cancel')) {
        throw const AuthException('Inicio de sesión cancelado.');
      }
      throw const AuthException('No se pudo iniciar sesión con Google.');
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
    if (kIsWeb) return;
    try {
      if (!_isWindows) {
        await mobile_google.GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
  }
}