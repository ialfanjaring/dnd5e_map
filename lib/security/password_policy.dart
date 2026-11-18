import 'dart:math';

enum PasswordStrength { weak, fair, good, strong }

/// Un requisito de la contraseña, con su texto para mostrar al usuario.
class PasswordRequirement {
  final String label;

  /// false: se comprueba pero no aparece en la lista de requisitos
  final bool visible;
  final bool Function(String password, String? email) test;

  const PasswordRequirement(this.label, this.test, {this.visible = true});
}

/// Política de contraseñas de la aplicación.
///
/// Importante: esta comprobación mejora la experiencia, pero no es una
/// barrera de seguridad por sí sola (un atacante puede saltarse la app).
/// Activa también la política de contraseñas de Firebase Authentication para
/// que se aplique en el servidor (ver SECURITY.md).
class PasswordPolicy {
  static const int minLength = 12;
  static const int maxLength = 128;

  /// Contraseñas muy comunes (y términos de este juego) que no se admiten.
  static const List<String> _common = [
    'password',
    'contrasena',
    'contraseña',
    'qwerty',
    'abc123',
    'letmein',
    'welcome',
    'bienvenido',
    'iloveyou',
    'tequiero',
    'admin',
    'login',
    'monkey',
    'dragon',
    'master',
    'football',
    'futbol',
    'princess',
    'sunshine',
    'shadow',
    'superman',
    'dungeon',
    'dnd5e',
    'dungeonsanddragons',
    'mazmorra',
    '123456',
    '12345678',
    '111111',
    '000000',
  ];

  static final RegExp _upper = RegExp(r'\p{Lu}', unicode: true);
  static final RegExp _lower = RegExp(r'\p{Ll}', unicode: true);
  static final RegExp _digit = RegExp(r'\d');
  static final RegExp _symbol = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  static final List<PasswordRequirement> requirements = [
    PasswordRequirement(
      'Al menos $minLength caracteres',
      (p, e) => p.length >= minLength,
    ),
    PasswordRequirement(
      'Como máximo $maxLength caracteres',
      (p, e) => p.length <= maxLength,
      visible: false,
    ),
    PasswordRequirement(
      'Una letra mayúscula',
      (p, e) => _upper.hasMatch(p),
    ),
    PasswordRequirement(
      'Una letra minúscula',
      (p, e) => _lower.hasMatch(p),
    ),
    PasswordRequirement(
      'Un número',
      (p, e) => _digit.hasMatch(p),
    ),
    PasswordRequirement(
      'Un símbolo (por ejemplo ! ? # \$ %)',
      (p, e) => _symbol.hasMatch(p),
    ),
    PasswordRequirement(
      'Sin espacios al principio ni al final',
      (p, e) => p == p.trim(),
      visible: false,
    ),
    PasswordRequirement(
      'Que no contenga tu correo',
      (p, e) => !_containsEmailPart(p, e),
    ),
    PasswordRequirement(
      'Que no sea una contraseña común',
      (p, e) => !_isCommon(p),
    ),
    PasswordRequirement(
      'Sin repeticiones ni secuencias evidentes (aaaa, 1234)',
      (p, e) => !_hasRunOrSequence(p),
    ),
  ];

  /// Requisitos que NO cumple la contraseña (lista vacía = válida).
  static List<String> validate(String password, {String? email}) => [
        for (final r in requirements)
          if (!r.test(password, email)) r.label,
      ];

  static bool isValid(String password, {String? email}) =>
      validate(password, email: email).isEmpty;

  // ---------------- Comprobaciones ----------------

  static bool _containsEmailPart(String password, String? email) {
    if (email == null) return false;

    final local = email.split('@').first.toLowerCase().trim();
    if (local.length < 3) return false;

    return password.toLowerCase().contains(local);
  }

  static bool _isCommon(String password) {
    final p = password.toLowerCase();
    final simple = p.replaceAll(RegExp(r'[^a-z0-9ñáéíóúü]'), '');

    for (final c in _common) {
      if (simple == c || p == c) return true;
      // Una contraseña común con pocos añadidos (ej. "password2024!")
      if (c.length >= 6 && simple.contains(c) && simple.length <= c.length + 4) {
        return true;
      }
    }
    return false;
  }

  /// 4 o más caracteres iguales seguidos, o 4 consecutivos en orden
  /// ascendente o descendente (abcd, 4321...).
  static bool _hasRunOrSequence(String password) {
    final p = password.toLowerCase();
    final codes = p.runes.toList();

    for (var i = 0; i + 3 < codes.length; i++) {
      final a = codes[i];
      final b = codes[i + 1];
      final c = codes[i + 2];
      final d = codes[i + 3];

      final same = a == b && b == c && c == d;
      final up = b == a + 1 && c == b + 1 && d == c + 1;
      final down = b == a - 1 && c == b - 1 && d == c - 1;

      if (same || up || down) return true;
    }
    return false;
  }

  // ---------------- Fortaleza ----------------

  /// Estimación de fortaleza a partir del tamaño del alfabeto y la longitud.
  /// Si no cumple la política, nunca pasa de "aceptable".
  static PasswordStrength strength(String password, {String? email}) {
    if (password.isEmpty) return PasswordStrength.weak;

    var pool = 0;
    if (_lower.hasMatch(password)) pool += 26;
    if (_upper.hasMatch(password)) pool += 26;
    if (_digit.hasMatch(password)) pool += 10;
    if (_symbol.hasMatch(password)) pool += 33;
    if (pool == 0) pool = 10;

    final entropy = password.length * (log(pool) / ln2);

    var result = entropy < 45
        ? PasswordStrength.weak
        : entropy < 65
            ? PasswordStrength.fair
            : entropy < 85
                ? PasswordStrength.good
                : PasswordStrength.strong;

    if (!isValid(password, email: email) &&
        result.index > PasswordStrength.fair.index) {
      result = PasswordStrength.fair;
    }
    return result;
  }

  static String strengthLabel(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.weak:
        return 'Débil';
      case PasswordStrength.fair:
        return 'Aceptable';
      case PasswordStrength.good:
        return 'Buena';
      case PasswordStrength.strong:
        return 'Muy buena';
    }
  }
}
