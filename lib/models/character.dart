import 'package:cloud_firestore/cloud_firestore.dart';

/// Datos de reglas básicas de D&D 5e (SRD) en español.
class DndData {
  static const List<String> abilityKeys = [
    'str',
    'dex',
    'con',
    'int',
    'wis',
    'cha',
  ];

  static const Map<String, String> abilityNames = {
    'str': 'Fuerza',
    'dex': 'Destreza',
    'con': 'Constitución',
    'int': 'Inteligencia',
    'wis': 'Sabiduría',
    'cha': 'Carisma',
  };

  static const Map<String, String> abilityShort = {
    'str': 'FUE',
    'dex': 'DES',
    'con': 'CON',
    'int': 'INT',
    'wis': 'SAB',
    'cha': 'CAR',
  };

  /// Habilidad -> característica asociada
  static const Map<String, String> skills = {
    'Acrobacias': 'dex',
    'Arcanos': 'int',
    'Atletismo': 'str',
    'Engaño': 'cha',
    'Historia': 'int',
    'Interpretación': 'cha',
    'Intimidación': 'cha',
    'Investigación': 'int',
    'Juego de manos': 'dex',
    'Medicina': 'wis',
    'Naturaleza': 'int',
    'Percepción': 'wis',
    'Perspicacia': 'wis',
    'Persuasión': 'cha',
    'Religión': 'int',
    'Sigilo': 'dex',
    'Supervivencia': 'wis',
    'Trato con animales': 'wis',
  };

  static const List<String> races = [
    'Humano',
    'Elfo',
    'Enano',
    'Mediano',
    'Draconato',
    'Gnomo',
    'Semielfo',
    'Semiorco',
    'Tiefling',
  ];

  /// Clase -> dado de golpe
  static const Map<String, int> classes = {
    'Bárbaro': 12,
    'Bardo': 8,
    'Clérigo': 8,
    'Druida': 8,
    'Guerrero': 10,
    'Monje': 8,
    'Paladín': 10,
    'Explorador': 10,
    'Pícaro': 8,
    'Hechicero': 6,
    'Brujo': 8,
    'Mago': 6,
  };

  /// Clase -> competencias en tiradas de salvación
  static const Map<String, List<String>> classSaves = {
    'Bárbaro': ['str', 'con'],
    'Bardo': ['dex', 'cha'],
    'Clérigo': ['wis', 'cha'],
    'Druida': ['int', 'wis'],
    'Guerrero': ['str', 'con'],
    'Monje': ['str', 'dex'],
    'Paladín': ['wis', 'cha'],
    'Explorador': ['str', 'dex'],
    'Pícaro': ['dex', 'int'],
    'Hechicero': ['con', 'cha'],
    'Brujo': ['wis', 'cha'],
    'Mago': ['int', 'wis'],
  };

  static const List<String> alignments = [
    'Legal bueno',
    'Neutral bueno',
    'Caótico bueno',
    'Legal neutral',
    'Neutral',
    'Caótico neutral',
    'Legal malvado',
    'Neutral malvado',
    'Caótico malvado',
  ];

  static const List<int> standardArray = [15, 14, 13, 12, 10, 8];

  /// Clase -> índice en la D&D 5e SRD API
  static const Map<String, String> classApiIndex = {
    'Bárbaro': 'barbarian',
    'Bardo': 'bard',
    'Clérigo': 'cleric',
    'Druida': 'druid',
    'Guerrero': 'fighter',
    'Monje': 'monk',
    'Paladín': 'paladin',
    'Explorador': 'ranger',
    'Pícaro': 'rogue',
    'Hechicero': 'sorcerer',
    'Brujo': 'warlock',
    'Mago': 'wizard',
  };

  /// Clases que lanzan conjuros en el SRD.
  static const Set<String> spellcastingClasses = {
    'Bardo',
    'Clérigo',
    'Druida',
    'Paladín',
    'Explorador',
    'Hechicero',
    'Brujo',
    'Mago',
  };
}

/// Lee la lista de hechizos guardada: solo índices de la D&D 5e SRD API.
/// También acepta el formato antiguo (mapas con index/name/level).
List<String> spellIndexesFromData(dynamic raw) {
  if (raw is! List) return const [];

  final out = <String>[];
  for (final e in raw) {
    final index = e is Map ? (e['index'] ?? '').toString() : e.toString();
    if (index.isNotEmpty && !out.contains(index)) out.add(index);
  }
  return out;
}

class Character {
  final String? id;
  final String ownerUid;
  final String name;
  final String race;
  final String characterClass;
  final String background;
  final String alignment;
  final int level;
  final Map<String, int> abilities;
  final int maxHp;
  final int armorClass;
  final int speed;
  final List<String> savingThrows;
  final List<String> skills;
  final String equipment;
  final String notes;
  /// Hechizos que puede usar: solo los índices de la D&D 5e SRD API.
  /// El nombre, el nivel y el texto se consultan siempre en la API.
  final List<String> spells;

  const Character({
    this.id,
    required this.ownerUid,
    required this.name,
    required this.race,
    required this.characterClass,
    this.background = '',
    this.alignment = '',
    this.level = 1,
    required this.abilities,
    required this.maxHp,
    this.armorClass = 10,
    this.speed = 30,
    this.savingThrows = const [],
    this.skills = const [],
    this.equipment = '',
    this.notes = '',
    this.spells = const [],
  });

  // ---------- Cálculos de la ficha ----------

  static int modifier(int score) => ((score - 10) / 2).floor();

  static String signed(int n) => n >= 0 ? '+$n' : '$n';

  int get proficiencyBonus => 2 + ((level - 1) ~/ 4);

  int mod(String key) => modifier(abilities[key] ?? 10);

  int get initiative => mod('dex');

  int saveBonus(String key) =>
      mod(key) + (savingThrows.contains(key) ? proficiencyBonus : 0);

  int skillBonus(String skill) =>
      mod(DndData.skills[skill] ?? 'str') +
      (skills.contains(skill) ? proficiencyBonus : 0);

  int get passivePerception => 10 + skillBonus('Percepción');

  String get summary => '$race $characterClass · Nivel $level';

  // ---------- Firestore ----------

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'name': name,
        'race': race,
        'characterClass': characterClass,
        'background': background,
        'alignment': alignment,
        'level': level,
        'abilities': abilities,
        'maxHp': maxHp,
        'armorClass': armorClass,
        'speed': speed,
        'savingThrows': savingThrows,
        'skills': skills,
        'equipment': equipment,
        'notes': notes,
        'spells': spells,
      };

  factory Character.fromMap(Map<String, dynamic> m, {String? id}) {
    final rawAbilities = (m['abilities'] as Map?) ?? {};
    final abilities = <String, int>{
      for (final k in DndData.abilityKeys)
        k: ((rawAbilities[k] ?? 10) as num).toInt(),
    };

    return Character(
      id: id,
      ownerUid: (m['ownerUid'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      race: (m['race'] ?? '') as String,
      characterClass: (m['characterClass'] ?? '') as String,
      background: (m['background'] ?? '') as String,
      alignment: (m['alignment'] ?? '') as String,
      level: ((m['level'] ?? 1) as num).toInt(),
      abilities: abilities,
      maxHp: ((m['maxHp'] ?? 1) as num).toInt(),
      armorClass: ((m['armorClass'] ?? 10) as num).toInt(),
      speed: ((m['speed'] ?? 30) as num).toInt(),
      savingThrows: List<String>.from(m['savingThrows'] ?? const []),
      skills: List<String>.from(m['skills'] ?? const []),
      equipment: (m['equipment'] ?? '') as String,
      notes: (m['notes'] ?? '') as String,
      spells: spellIndexesFromData(m['spells']),
    );
  }

  factory Character.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Character.fromMap(doc.data() ?? {}, id: doc.id);
}
