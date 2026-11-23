import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../settings/app_settings.dart';

/// Diccionario SRD 5.1 en español incluido en la app (assets/data/srd_es.json).
/// Es un recurso estático que se genera UNA vez (ver tool/build_translations.dart):
/// la app nunca traduce en línea ni escribe nada en Firestore.
/// Secciones: 'items' (objetos), 'spells' (hechizos) y 'monsters'
/// (tool/build_monsters.dart). Cada entrada:
/// {n: nombre, d: descripción, h: niveles superiores}.
class SrdEs {
  static Map<String, dynamic> _data = {};
  static Future<void>? _loadFuture;

  static String _norm(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Carga el diccionario una sola vez. Si varias pantallas lo piden a la vez,
  /// todas esperan a la misma carga (antes, la segunda seguía sin datos).
  static Future<void> ensureLoaded() => _loadFuture ??= _load();

  static Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/srd_es.json');
      final m = jsonDecode(raw);
      if (m is Map) _data = Map<String, dynamic>.from(m);
      int n(String k) => (_data[k] as Map?)?.length ?? 0;
      debugPrint('SRD ES cargado: ${n('items')} objetos, ${n('spells')} '
          'hechizos, ${n('monsters')} monstruos, ${n('classes')} clases, '
          '${n('subclasses')} subclases, ${n('features')} rasgos, '
          '${n('races')} razas');
    } catch (e) {
      debugPrint('SRD ES NO cargado (¿falta assets/data/ en pubspec.yaml?): $e');
      _data = {}; // sin asset: se muestra el texto original
    }
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

  /// Nombre en español de un monstruo (null si no hay traducción).
  static String? monsterName(String enName) => get('monsters', enName, 'n');

  /// Traducción de un rasgo/acción de un monstruo. [field]: 'n' nombre, 'd' texto.
  static String? monsterItem(String monster, String item, String field) {
    if (AppSettings.instance.lang != 'es') return null;
    final mon = (_data['monsters'] as Map?)?[_norm(monster)];
    final items = mon is Map ? mon['i'] : null;
    if (items is! Map) return null;
    var e = items[_norm(item)];
    // «Lightning Breath (Recharge 5-6)» -> prueba sin el paréntesis
    e ??= items[_norm(item.replaceAll(RegExp(r'\s*\(.*\)'), ''))];
    if (e is! Map) return null;
    final v = e[field]?.toString() ?? '';
    return v.isEmpty ? null : v;
  }
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
