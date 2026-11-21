import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import 'en.dart';
import 'langs.dart';

/// Idiomas de la interfaz incluidos en la app (código -> nombre propio).
const Map<String, String> uiLanguages = {
  'es': 'Español',
  'en': 'English',
  'fr': 'Français',
  'de': 'Deutsch',
  'pt-BR': 'Português (Brasil)',
  'it': 'Italiano',
};

/// Traduce un texto escrito en español al idioma de la app. Todas las
/// traducciones viajan dentro de la app; si falta alguna se usa el inglés
/// y, en último caso, el original.
String tr(String es) {
  final lang = AppSettings.instance.lang;
  if (lang == 'es') return es;
  if (lang == 'en') return enStrings[es] ?? es;
  return bundledStrings[lang]?[es] ?? enStrings[es] ?? es;
}

/// Como [Text] pero traduce el texto según el idioma. Se puede usar con
/// `const`, así que sustituye a `const Text('...')` sin más cambios.
class Tx extends StatelessWidget {
  const Tx(
    this.es, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String es;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    // Se reconstruye al cambiar el idioma aunque el widget sea const
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => Text(
        tr(es),
        style: style,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      ),
    );
  }
}
