import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Orientación de la pantalla en móviles (en Windows/web no hace nada).
/// La app va en vertical; la partida y el editor de mapas giran a horizontal.
class AppOrientation {
  AppOrientation._();

  static bool get _isPhone =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Vertical (el resto de la app).
  static Future<void> portrait() async {
    if (!_isPhone) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  /// Horizontal (partida y editor de mapas).
  static Future<void> landscape() async {
    if (!_isPhone) return;
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}
