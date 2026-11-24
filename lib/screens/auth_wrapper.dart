import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

/// Puerta de acceso: solo deja pasar a usuarios con sesión Y correo verificado.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _auth = AuthService();

  // Comprobación del token por usuario (se guarda para no repetirla en cada
  // reconstrucción).
  String? _checkedUid;
  Future<bool>? _tokenCheck;

  /// Lo que cuenta para Firestore es el token, no el dato local del usuario:
  /// solo se entra si el token dice que el correo está verificado. Si el
  /// usuario ya figura como verificado pero el token es antiguo, se renueva.
  Future<bool> _tokenVerified(User user) async {
    try {
      // Recarga el usuario: si la cuenta guardada ya no existe, está
      // deshabilitada o su sesión caducó, esto falla y se cierra la sesión.
      await user.reload();
      final t = await user.getIdTokenResult(true);
      final claim = t.claims?['email_verified'];
      // En Windows el SDK de escritorio no siempre rellena las «claims» del
      // token. Si no viene el dato, vale el del usuario ya recargado (el
      // token se acaba de renovar, así que Firestore verá lo mismo).
      if (claim is bool) return claim;
      return FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    } on FirebaseAuthException catch (e) {
      // Sesión guardada que ya no vale: se descarta y se vuelve al login.
      if (e.code != 'network-request-failed') {
        await _auth.logout();
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // userChanges también emite al recargar (verificación del correo).
    return StreamBuilder<User?>(
      stream: _auth.userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: SafeArea(top: false, child: Center(child: CircularProgressIndicator())),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        // Sesión rota guardada en el dispositivo (sin correo): se descarta.
        if ((user.email ?? '').isEmpty) {
          _auth.logout();
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!user.emailVerified) {
          _checkedUid = null;
          return VerifyEmailScreen(onVerified: () {
            if (mounted) setState(() {});
          });
        }

        if (_checkedUid != user.uid || _tokenCheck == null) {
          _checkedUid = user.uid;
          _tokenCheck = _tokenVerified(user);
        }
        return FutureBuilder<bool>(
          future: _tokenCheck,
          builder: (context, t) {
            if (t.connectionState != ConnectionState.done) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            if (t.data != true) {
              // Sin token verificado no se entra: vuelve a la pantalla de
              // verificación, que reintenta cada pocos segundos.
              return VerifyEmailScreen(onVerified: () {
                if (mounted) setState(() => _tokenCheck = null);
              });
            }
            return const HomeScreen();
          },
        );
      },
    );
  }
}
