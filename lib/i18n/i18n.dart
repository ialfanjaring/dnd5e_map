import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import 'en.dart';
import 'langs.dart';

/// Idiomas de la interfaz incluidos en la app (código -> nombre propio).
const Map<String, String> uiLanguages = {
  'es': 'Español',
  'en': 'English',
};

/// Traduce un texto escrito en español al idioma de la app. Todas las
/// traducciones viajan dentro de la app; si falta alguna se usa el inglés
/// y, en último caso, el original.
String tr(String es) {
  final lang = AppSettings.instance.lang;
  if (lang == 'es') return es;
  if (lang == 'en') return enStrings[es] ?? es;
  return enStrings[es] ?? es;
}

/// Traduce un mensaje de error/aviso (con o sin números dentro).
String trMsg(String es) {
  final w = RegExp(r'^Espera (\d+) segundos antes de reenviar\.$').firstMatch(es);
  if (w != null) {
    return tr('Espera {n} segundos antes de reenviar.').replaceAll('{n}', w.group(1)!);
  }
  final c = RegExp(r'^No se pudo crear la cuenta \((.+)\)\.$').firstMatch(es);
  if (c != null) return '${tr('No se pudo crear la cuenta')} (${c.group(1)}).';
  return tr(es);
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
