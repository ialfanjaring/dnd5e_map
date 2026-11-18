import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/password_field.dart';
import 'login_screen.dart' show validateEmail;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _auth.register(email: _emailCtrl.text, password: _passCtrl.text);

      if (!mounted) return;
      // Vuelve al inicio: AuthWrapper mostrará la pantalla de verificación
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'No se pudo crear la cuenta. Inténtalo de nuevo.');
      }
    } finally {
      _passCtrl.clear();
      _confirmCtrl.clear();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newUsername],
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLength: 254,
                      decoration: const InputDecoration(
                        labelText: 'Correo electrónico',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: 12),
                    PasswordField(
                      controller: _passCtrl,
                      label: 'Contraseña',
                      showRequirements: true,
                      enforcePolicy: true,
                      emailProvider: () => _emailCtrl.text.trim(),
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.newPassword],
                    ),
                    const SizedBox(height: 12),
                    PasswordField(
                      controller: _confirmCtrl,
                      label: 'Repite la contraseña',
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _loading ? null : _register(),
                    ),
                    // La coincidencia se comprueba al enviar
                    FormField<String>(
                      validator: (_) => _passCtrl.text == _confirmCtrl.text
                          ? null
                          : 'Las contraseñas no coinciden',
                      builder: (state) => state.hasError
                          ? Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                state.errorText!,
                                style: TextStyle(color: Colors.red.shade700),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Crear cuenta'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Te enviaremos un correo para verificar tu dirección. '
                      'No podrás usar la app hasta confirmarlo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
