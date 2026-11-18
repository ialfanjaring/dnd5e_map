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

  @override
  Widget build(BuildContext context) {
    // userChanges también emite al recargar (verificación del correo).
    return StreamBuilder<User?>(
      stream: _auth.userChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        if (!user.emailVerified) {
          return VerifyEmailScreen(onVerified: () {
            if (mounted) setState(() {});
          });
        }

        return const HomeScreen();
      },
    );
  }
}
