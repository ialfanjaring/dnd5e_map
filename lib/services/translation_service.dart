import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../settings/app_settings.dart';

/// Diccionario SRD 5.1 en español incluido en la app (assets/data/srd_es.json).
/// Es un recurso estático que se genera UNA vez (ver tool/build_translations.dart):
/// la app nunca traduce en línea ni escribe nada en Firestore.
/// Secciones: 'items' (objetos) y 'spells' (hechizos). Cada entrada:
/// {n: nombre, d: descripción, h: niveles superiores}.
class SrdEs {
  static Map<String, dynamic> _data = {};
  static bool _loaded = false;
  static bool _loading = false;

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static Future<void> ensureLoaded() async {
    if (_loaded || _loading) return;
    _loading = true;
    try {
      final raw = await rootBundle.loadString('assets/data/srd_es.json');
      final m = jsonDecode(raw);
      if (m is Map) _data = Map<String, dynamic>.from(m);
      debugPrint('SRD ES cargado: ${(_data['items'] as Map?)?.length ?? 0} '
          'objetos, ${(_data['spells'] as Map?)?.length ?? 0} hechizos');
    } catch (e) {
      debugPrint('SRD ES NO cargado (¿falta assets/data/ en pubspec.yaml?): $e');
      _data = {}; // sin asset: se muestra el texto original
    }
    _loaded = true;
    _loading = false;
  }

  /// Texto en español ('n' nombre, 'd' descripción, 'h' niveles superiores)
  /// de un elemento del SRD, o null si no existe o la app no está en español.
  static String? get(String section, String enName, String field) {
    if (AppSettings.instance.lang != 'es') return null;
    final sec = _data[section];
    if (sec is! Map) return null;
    final e = sec[_norm(enName)];
    if (e is! Map) return null;
    final v = e[field]?.toString() ?? '';
    return v.isEmpty ? null : v;
  }

  static String? item(String enName, String field) =>
      get('items', enName, field);
}

/// Muestra [en] y, si el SRD en español tiene ese elemento, lo sustituye por
/// el texto en español. Sin red y sin traducción automática.
class TrText extends StatefulWidget {
  const TrText(
    this.en, {
    super.key,
    this.style,
    this.translate = true,
    this.srdName,
    this.srdField = 'd',
    this.srdSection = 'items',
    this.maxLines,
    this.overflow,
  });

  final String en;
  final TextStyle? style;

  /// false para contenido creado por el usuario.
  final bool translate;

  /// Nombre en inglés del elemento a buscar en el diccionario.
  final String? srdName;
  final String srdField; // 'n', 'd' o 'h'
  final String srdSection; // 'items' o 'spells'
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  State<TrText> createState() => _TrTextState();
}

class _TrTextState extends State<TrText> {
  String? _text;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(TrText old) {
    super.didUpdateWidget(old);
    if (old.en != widget.en || old.srdName != widget.srdName) _run();
  }

  Future<void> _run() async {
    if (!widget.translate || widget.srdName == null) {
      _text = null;
      return;
    }
    await SrdEs.ensureLoaded();
    final h = SrdEs.get(widget.srdSection, widget.srdName!, widget.srdField);
    if (mounted) setState(() => _text = h);
  }

  @override
  Widget build(BuildContext context) => Text(
        _text ?? widget.en,
        style: widget.style,
        maxLines: widget.maxLines,
        overflow: widget.overflow,
      );
}
