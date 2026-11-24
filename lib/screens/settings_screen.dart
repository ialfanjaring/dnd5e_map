import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../services/auth_service.dart';
import '../settings/app_settings.dart';

/// Opciones: idioma, tema y cerrar sesión.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppSettings.instance;

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Tx('Opciones')),
          body: SafeArea(top: false, child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(context, tr('Idioma')),
              Card(
                child: Column(
                  children: [
                    for (final c in uiLanguages.keys)
                      RadioListTile<String>(
                        value: c,
                        groupValue: s.lang,
                        onChanged: (v) => s.setLang(v!),
                        title: Text(uiLanguages[c]!),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _header(context, tr('Tema')),
              Card(
                child: Column(
                    children: [
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.system,
                        groupValue: s.themeMode,
                        onChanged: (v) => s.setThemeMode(v!),
                        title: const Tx('Según el sistema'),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.light,
                        groupValue: s.themeMode,
                        onChanged: (v) => s.setThemeMode(v!),
                        title: const Tx('Claro'),
                      ),
                      RadioListTile<ThemeMode>(
                        value: ThemeMode.dark,
                        groupValue: s.themeMode,
                        onChanged: (v) => s.setThemeMode(v!),
                        title: const Tx('Oscuro'),
                      ),
                    ],
                ),
              ),
              const SizedBox(height: 16),
              _header(context, tr('Cuenta')),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Tx('Cerrar sesión'),
                  onTap: () async {
                    Navigator.of(context).popUntil((r) => r.isFirst);
                    await AuthService().logout();
                  },
                ),
              ),
            ],
          )),
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
