import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Preferencias de la app: idioma y tema. Se guardan en
/// users/{uid}/prefs/app (son datos del usuario, no de la API).
class AppSettings extends ChangeNotifier {
  AppSettings._() {
    final sys = PlatformDispatcher.instance.locale.languageCode;
    _lang = switch (sys) {
      'en' => 'en',
      'fr' => 'fr',
      'de' => 'de',
      'it' => 'it',
      'pt' => 'pt-BR',
      _ => 'es',
    };
  }

  static final AppSettings instance = AppSettings._();


  String _lang = 'es';
  ThemeMode _themeMode = ThemeMode.system;

  /// Código de idioma: 'es', 'en' o uno de los que ofrece la API (de, fr...)
  String get lang => _lang;
  bool get isSpanish => _lang == 'es';
  bool get isEnglishUi => _lang != 'es';
  ThemeMode get themeMode => _themeMode;

  DocumentReference<Map<String, dynamic>>? get _doc {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(u.uid)
        .collection('prefs')
        .doc('app');
  }

  /// Carga las preferencias guardadas del usuario (si las hay).
  Future<void> load() async {
    try {
      final snap = await _doc?.get();
      final d = snap?.data();
      if (d == null) return;
      final l = d['lang'];
      final m = d['theme'];
      var changed = false;
      if (l is String && RegExp(r'^[a-z]{2,3}(-[A-Za-z]{2,4})?$').hasMatch(l)) {
        if (l != _lang) changed = true;
        _lang = l;
      }
      final mode = switch (m) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => _themeMode,
      };
      if (mode != _themeMode) changed = true;
      _themeMode = mode;
      if (changed) notifyListeners();
    } catch (_) {
      // Sin conexión o sin permisos: se mantienen los valores actuales.
    }
  }

  Future<void> setLang(String lang) async {
    if (lang == _lang) return;
    _lang = lang;
    notifyListeners();
    await _save();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      await _doc?.set({
        'lang': _lang,
        'theme': switch (_themeMode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
