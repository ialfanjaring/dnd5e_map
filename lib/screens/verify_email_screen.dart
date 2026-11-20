import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../i18n/i18n.dart';

/// Pantalla que se muestra hasta que el usuario confirma su correo.
/// Sin correo verificado no se puede entrar en la app (y las reglas de
/// Firestore tampoco dejan leer ni escribir datos).
class VerifyEmailScreen extends StatefulWidget {
  /// Se llama cuando el correo ya está verificado.
  final VoidCallback onVerified;

  const VerifyEmailScreen({super.key, required this.onVerified});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _auth = AuthService();

  Timer? _poll;
  Timer? _tick;
  int _cooldown = 0;
  bool _checking = false;
  bool _sending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _cooldown = _auth.resendCooldownSeconds;

    // Comprueba cada pocos segundos si ya has confirmado el correo
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(auto: true));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = _auth.resendCooldownSeconds;
      if (mounted && left != _cooldown) setState(() => _cooldown = left);
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _check({bool auto = false}) async {
    if (_checking) return;
    _checking = true;
    if (!auto && mounted) setState(() => _message = null);

    try {
      final verified = await _auth.refreshVerification();

      if (!mounted) return;
      if (verified) {
        widget.onVerified();
      } else if (!auto) {
        setState(() => _message = 'Todavía no está verificado. Abre el enlace '
            'del correo y vuelve a intentarlo.');
      }
    } catch (_) {
      if (!auto && mounted) {
        setState(() => _message = 'No se pudo comprobar. Revisa tu conexión.');
      }
    } finally {
      _checking = false;
    }
  }

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _message = null;
    });

    try {
      await _auth.resendVerification();
      if (mounted) {
        setState(() {
          _message = 'Te hemos enviado un nuevo correo de verificación.';
          _cooldown = _auth.resendCooldownSeconds;
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? '';

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.mark_email_unread_outlined,
                  size: 80,
                  color: Colors.deepPurple,
                ),
                const SizedBox(height: 16),
                const Tx(
                  'Verifica tu correo',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hemos enviado un enlace de verificación a\n$email\n'
                  'Ábrelo para activar tu cuenta. Mira también la carpeta de '
                  'spam.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _checking ? null : () => _check(),
                    icon: const Icon(Icons.refresh),
                    label: const Tx('Ya lo he verificado'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: (_sending || _cooldown > 0) ? null : _resend,
                    icon: const Icon(Icons.send_outlined),
                    label: Text(
                      _cooldown > 0
                          ? 'Reenviar correo ($_cooldown s)'
                          : 'Reenviar correo',
                    ),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _auth.logout(),
                  child: const Tx('Usar otra cuenta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
