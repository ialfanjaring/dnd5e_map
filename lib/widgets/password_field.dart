import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../security/password_policy.dart';

/// Campo de contraseña.
///
/// - Oculta el texto, con botón para mostrarlo.
/// - Sin sugerencias ni autocorrección (no se filtra a teclados predictivos).
/// - Con [showRequirements] muestra la fortaleza y los requisitos en vivo.
/// - Con [enforcePolicy] el formulario solo valida si se cumple la política.
class PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool showRequirements;
  final bool enforcePolicy;

  /// Correo del usuario, para impedir contraseñas que lo contengan.
  final String? Function()? emailProvider;

  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String>? autofillHints;

  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Contraseña',
    this.showRequirements = false,
    this.enforcePolicy = false,
    this.emailProvider,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  String? _validate(String? value) {
    final v = value ?? '';

    if (v.isEmpty) return 'Introduce la contraseña';

    if (widget.enforcePolicy &&
        !PasswordPolicy.isValid(v, email: widget.emailProvider?.call())) {
      return 'La contraseña no cumple todos los requisitos';
    }
    return null;
  }

  Color _strengthColor(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.weak:
        return Colors.red;
      case PasswordStrength.fair:
        return Colors.orange;
      case PasswordStrength.good:
        return Colors.lightGreen;
      case PasswordStrength.strong:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: widget.controller,
          obscureText: _obscure,
          enableSuggestions: false,
          autocorrect: false,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onSubmitted,
          autofillHints: widget.autofillHints,
          maxLength: PasswordPolicy.maxLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: const Icon(Icons.lock_outline),
            border: const OutlineInputBorder(),
            counterText: '',
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          validator: _validate,
        ),
        if (widget.showRequirements)
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) {
              final password = value.text;
              final email = widget.emailProvider?.call();
              final strength =
                  PasswordPolicy.strength(password, email: email);

              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: password.isEmpty
                                ? 0
                                : (strength.index + 1) / 4,
                            minHeight: 6,
                            color: _strengthColor(strength),
                            backgroundColor: Colors.grey.withOpacity(0.35),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          password.isEmpty
                              ? ''
                              : PasswordPolicy.strengthLabel(strength),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _strengthColor(strength),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final r in PasswordPolicy.requirements)
                      if (r.visible)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(
                            children: [
                              Icon(
                                r.test(password, email)
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 14,
                                color: r.test(password, email)
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  r.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: r.test(password, email)
                                        ? Colors.green.shade700
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
