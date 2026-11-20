import 'package:flutter/material.dart';

/// Imágenes por defecto (iconos y colores) según el tipo de personaje,
/// NPC o monstruo. No se guarda nada: se deduce del tipo.
class Avatars {
  static const Map<String, IconData> _classIcons = {
    'barbarian': Icons.fitness_center,
    'bard': Icons.music_note,
    'cleric': Icons.church,
    'druid': Icons.eco,
    'fighter': Icons.shield,
    'monk': Icons.self_improvement,
    'paladin': Icons.security,
    'ranger': Icons.my_location,
    'rogue': Icons.visibility_off,
    'sorcerer': Icons.auto_fix_high,
    'warlock': Icons.dark_mode,
    'wizard': Icons.auto_stories,
  };

  static const Map<String, Color> _classColors = {
    'barbarian': Color(0xFFBF360C),
    'bard': Color(0xFFAD1457),
    'cleric': Color(0xFFF9A825),
    'druid': Color(0xFF2E7D32),
    'fighter': Color(0xFF455A64),
    'monk': Color(0xFF00838F),
    'paladin': Color(0xFF1565C0),
    'ranger': Color(0xFF558B2F),
    'rogue': Color(0xFF424242),
    'sorcerer': Color(0xFFC62828),
    'warlock': Color(0xFF6A1B9A),
    'wizard': Color(0xFF283593),
  };

  // Tipos de criatura (en español y en inglés, por si acaso)
  static const List<({List<String> names, IconData icon, Color color})>
      _types = [
    (names: ['aberración', 'aberration'], icon: Icons.visibility, color: Color(0xFF6A1B9A)),
    (names: ['bestia', 'beast'], icon: Icons.pets, color: Color(0xFF8D6E63)),
    (names: ['celestial'], icon: Icons.auto_awesome, color: Color(0xFFF9A825)),
    (names: ['constructo', 'construct'], icon: Icons.precision_manufacturing, color: Color(0xFF607D8B)),
    (names: ['dragón', 'dragon'], icon: Icons.local_fire_department, color: Color(0xFFD84315)),
    (names: ['elemental'], icon: Icons.bolt, color: Color(0xFF0288D1)),
    (names: ['feérico', 'fey'], icon: Icons.spa, color: Color(0xFFEC407A)),
    (names: ['infernal', 'fiend'], icon: Icons.whatshot, color: Color(0xFFB71C1C)),
    (names: ['gigante', 'giant'], icon: Icons.landscape, color: Color(0xFF795548)),
    (names: ['humanoide', 'humanoid'], icon: Icons.person, color: Color(0xFF455A64)),
    (names: ['monstruosidad', 'monstrosity'], icon: Icons.bug_report, color: Color(0xFF4E342E)),
    (names: ['cieno', 'ooze'], icon: Icons.water_drop, color: Color(0xFF7CB342)),
    (names: ['planta', 'plant'], icon: Icons.park, color: Color(0xFF2E7D32)),
    (names: ['no-muerto', 'undead'], icon: Icons.dangerous, color: Color(0xFF37474F)),
  ];

  /// Avatares que puede elegir un jugador para su ficha en el mapa.
  static const Map<String, IconData> tokenAvatars = {
    'shield': Icons.shield,
    'security': Icons.security,
    'military': Icons.military_tech,
    'castle': Icons.castle,
    'wand': Icons.auto_fix_high,
    'book': Icons.auto_stories,
    'psychology': Icons.psychology,
    'fire': Icons.local_fire_department,
    'bolt': Icons.bolt,
    'water': Icons.water_drop,
    'sun': Icons.wb_sunny,
    'moon': Icons.dark_mode,
    'star': Icons.star,
    'heart': Icons.favorite,
    'diamond': Icons.diamond,
    'music': Icons.music_note,
    'church': Icons.church,
    'leaf': Icons.eco,
    'paw': Icons.pets,
    'bird': Icons.flutter_dash,
    'rabbit': Icons.cruelty_free,
    'hiking': Icons.hiking,
    'sail': Icons.sailing,
    'eye': Icons.visibility,
    'target': Icons.my_location,
    'fitness': Icons.fitness_center,
    'face': Icons.face,
    'skull': Icons.dangerous,
  };

  static IconData? avatarIcon(String key) => tokenAvatars[key];

  /// Colores monstruo: siempre rojo y negro.
  static const Color monsterColor = Color(0xFFD32F2F);
  static const Color monsterColor2 = Color(0xFF111111);

  static const IconData npcIcon = Icons.record_voice_over;
  static const Color npcColor = Color(0xFF00897B);
  static const IconData defaultIcon = Icons.help_outline;

  static IconData classIcon(String classIndex) =>
      _classIcons[classIndex] ?? Icons.person;

  static Color classColor(String classIndex) =>
      _classColors[classIndex] ?? Colors.deepPurple;

  static ({IconData icon, Color color}) _type(String type) {
    final t = type.toLowerCase();
    for (final e in _types) {
      if (e.names.any((n) => t.contains(n))) {
        return (icon: e.icon, color: e.color);
      }
    }
    return (icon: defaultIcon, color: Colors.grey.shade600);
  }

  /// Icono de una criatura: los NPC tienen el suyo; los monstruos, el de su tipo.
  static IconData creatureIcon({required bool isNpc, required String type}) =>
      isNpc ? npcIcon : _type(type).icon;

  static Color creatureColor({required bool isNpc, required String type}) =>
      isNpc ? npcColor : _type(type).color;

  /// Clave que se guarda en la ficha del mapa: 'npc' o el tipo de monstruo.
  static String tokenKey({required bool isNpc, required String type}) =>
      isNpc ? 'npc' : type;

  static IconData iconForTokenKey(String key) =>
      key == 'npc' ? npcIcon : _type(key).icon;
}

/// Avatar redondo con el icono por defecto.
class EntityAvatar extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double radius;

  const EntityAvatar({
    super.key,
    required this.icon,
    required this.color,
    this.radius = 20,
  });

  factory EntityAvatar.character(String classIndex, {double radius = 20}) =>
      EntityAvatar(
        icon: Avatars.classIcon(classIndex),
        color: Avatars.classColor(classIndex),
        radius: radius,
      );

  factory EntityAvatar.creature({
    required bool isNpc,
    required String type,
    double radius = 20,
  }) =>
      EntityAvatar(
        icon: Avatars.creatureIcon(isNpc: isNpc, type: type),
        color: Avatars.creatureColor(isNpc: isNpc, type: type),
        radius: radius,
      );

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color,
      child: Icon(icon, color: Colors.white, size: radius * 1.1),
    );
  }
}
