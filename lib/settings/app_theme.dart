import 'package:flutter/material.dart';

/// Temas de la app. Los dos tienen la misma estructura; el oscuro usa el
/// morado de siempre y el claro grises azulados con índigo y dorado.
class AppTheme {
  AppTheme._();

  static const Color purple = Color(0xFF5B3A8E);
  static const Color gold = Color(0xFFB8860B);
  static const Color wine = Color(0xFF8E2C3C);

  // ---------------------------------------------------------------
  // CLARO: misma estructura que el oscuro (barra superior del color del
  // fondo, tarjetas en tonos de contenedor, sin bordes), con otra gama:
  // grises azulados fríos, índigo como color principal y dorado de acento.
  // ---------------------------------------------------------------
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4A4FB8),
      brightness: Brightness.light,
    );
    final scheme = base.copyWith(
      primary: const Color(0xFF4347A8),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDFE0FF),
      onPrimaryContainer: const Color(0xFF14175E),
      secondary: const Color(0xFF8A6418),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFBE7B8),
      onSecondaryContainer: const Color(0xFF3A2A00),
      tertiary: const Color(0xFF00796B),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFFE2B8),
      onTertiaryContainer: const Color(0xFF452B00),
      surface: const Color(0xFFF3F4F9),
      onSurface: const Color(0xFF1A1C24),
      onSurfaceVariant: const Color(0xFF4A4D5C),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFFBFBFE),
      surfaceContainer: const Color(0xFFFFFFFF),
      surfaceContainerHigh: const Color(0xFFE9EBF3),
      surfaceContainerHighest: const Color(0xFFE1E3EE),
      outline: const Color(0xFF7A7E90),
      outlineVariant: const Color(0xFFD3D6E2),
    );
    return _build(scheme);
  }

  // ---------------------------------------------------------------
  // OSCURO
  // ---------------------------------------------------------------
  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6750A4),
      brightness: Brightness.dark,
    );
    final scheme = base.copyWith(
      tertiaryContainer: const Color(0xFF5C3B00),
      onTertiaryContainer: const Color(0xFFFFDDB0),
      secondaryContainer: const Color(0xFF4A3B12),
      onSecondaryContainer: const Color(0xFFF6E2B0),
    );
    return _build(scheme);
  }

  // ---------------------------------------------------------------
  // COMÚN
  // ---------------------------------------------------------------
  static ThemeData _build(ColorScheme scheme) {
    final light = scheme.brightness == Brightness.light;
    final radius = BorderRadius.circular(14);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: light ? scheme.surfaceContainer : scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: light ? 1 : 0,
        shadowColor: light ? const Color(0x331A1C40) : null,
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: null,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      checkboxTheme: CheckboxThemeData(
        side: BorderSide(color: scheme.outline, width: 1.5),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        dividerColor: scheme.outlineVariant,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light ? Colors.white : scheme.surfaceContainerHigh,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.secondaryContainer,
          selectedForegroundColor: scheme.onSecondaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: light ? Colors.white : null,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: light ? Colors.white : null,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: light ? Colors.white : null,
        indicatorColor: scheme.secondaryContainer,
      ),
    );
  }
}
