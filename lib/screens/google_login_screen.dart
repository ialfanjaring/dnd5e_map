import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class GoogleLoginScreen extends StatefulWidget {
  const GoogleLoginScreen({super.key});

  @override
  State<GoogleLoginScreen> createState() =>
      _GoogleLoginScreenState();
}

class _GoogleLoginScreenState extends State<GoogleLoginScreen> {
  final AuthService _authService = AuthService();

  bool _loading = false;

  Future<void> _loginWithGoogle() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      await _authService.loginWithGoogle();

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      final message = switch (e.code) {
        'account-exists-with-different-credential' =>
        'Esta cuenta ya está registrada con otro método de acceso.',
        'operation-not-allowed' =>
        'El acceso con Google no está habilitado en Firebase.',
        'network-request-failed' =>
        'No se ha podido conectar con Firebase.',
        'invalid-credential' =>
        'Las credenciales de Google no son válidas.',
        'user-disabled' =>
        'Esta cuenta de usuario está deshabilitada.',
        _ => 'No se ha podido iniciar sesión con Google (${e.code}).',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;

      final error = e.toString().toLowerCase();

      if (error.contains('cancel')) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se ha podido iniciar sesión con Google: $e',
          ),
        ),
      );

      debugPrint('Error de Google Sign-In: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acceso con Google'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_circle_outlined,
                  size: 100,
                ),

                const SizedBox(height: 24),

                const Text(
                  'Inicia sesión con Google',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Utiliza tu cuenta de Google para acceder '
                      'a tu partida y a tus personajes.',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _loginWithGoogle,
                    icon: const Icon(
                      Icons.g_mobiledata,
                      size: 32,
                    ),
                    label: _loading
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Continuar con Google'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}