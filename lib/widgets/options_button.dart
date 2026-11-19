import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../screens/settings_screen.dart';
import 'app_icon.dart';

/// Botón de Opciones (idioma, tema, cerrar sesión) para las barras de los
/// apartados de la pantalla principal.
class OptionsButton extends StatelessWidget {
  const OptionsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr('Opciones'),
      icon: const AppIcon('opciones', size: 28),
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      ),
    );
  }
}
