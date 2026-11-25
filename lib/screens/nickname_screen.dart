import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';

/// Elegir o cambiar el nickname. Es obligatorio para entrar en la app: es el
/// nombre que verán los demás en las partidas.
class NicknameScreen extends StatefulWidget {
  /// Se llama al guardar. Si es null, la pantalla se cierra con Navigator.pop
  /// (modo «cambiar nickname» desde ajustes).
  final VoidCallback? onDone;
  final String initial;

  const NicknameScreen({super.key, this.onDone, this.initial = ''});

  @override
  State<NicknameScreen> createState() => _NicknameScreenState();
}

class _NicknameScreenState extends State<NicknameScreen> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  String? _error;
  bool _saving = false;

  bool get _mandatory => widget.onDone != null;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = ProfileService.validate(_ctrl.text);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ProfileService.instance.setNickname(_ctrl.text);
      if (!mounted) return;
      if (widget.onDone != null) {
        widget.onDone!();
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '${tr('No se pudo guardar')}: '
            '${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: _mandatory ? null : AppBar(title: Tx('Cambiar nickname')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_outlined, size: 64, color: cs.primary),
                  const SizedBox(height: 16),
                  Tx(
                    _mandatory ? 'Elige tu nickname' : 'Cambiar nickname',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Tx(
                    'Es el nombre que verán los demás jugadores en las partidas. '
                    'Tu correo no se muestra a nadie.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _ctrl,
                    autofocus: true,
                    maxLength: ProfileService.maxLength,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _saving ? null : _save(),
                    decoration: InputDecoration(
                      labelText: tr('Nickname'),
                      prefixIcon: const Icon(Icons.person_outline),
                      border: const OutlineInputBorder(),
                      errorText: _error == null ? null : trMsg(_error!),
                      errorMaxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Tx('Guardar'),
                    ),
                  ),
                  if (_mandatory) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _saving ? null : () => AuthService().logout(),
                      child: Tx('Usar otra cuenta'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
