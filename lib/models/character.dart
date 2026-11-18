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

  // -----------------------------------------------------------------
  // Razas y clases: las disponibles se leen de la D&D 5e SRD API y el
  // personaje solo guarda el índice elegido (por ejemplo "elf" o "wizard").
  // Lo que hay aquí son traducciones de la interfaz y datos de respaldo
  // para cuando no hay conexión con la API.
  // -----------------------------------------------------------------

  /// Raza (índice de la API) -> nombre en español
  static const Map<String, String> raceNames = {
    'dragonborn': 'Draconato',
    'dwarf': 'Enano',
    'elf': 'Elfo',
    'gnome': 'Gnomo',
    'half-elf': 'Semielfo',
    'half-orc': 'Semiorco',
    'halfling': 'Mediano',
    'human': 'Humano',
    'tiefling': 'Tiefling',
  };

  /// Subraza (índice de la API) -> nombre en español
  static const Map<String, String> subraceNames = {
    'hill-dwarf': 'Enano de las colinas',
    'high-elf': 'Alto elfo',
    'lightfoot-halfling': 'Mediano piesligeros',
    'rock-gnome': 'Gnomo de las rocas',
  };

  /// Clase (índice de la API) -> nombre en español
  static const Map<String, String> classNames = {
    'barbarian': 'Bárbaro',
    'bard': 'Bardo',
    'cleric': 'Clérigo',
    'druid': 'Druida',
    'fighter': 'Guerrero',
    'monk': 'Monje',
    'paladin': 'Paladín',
    'ranger': 'Explorador',
    'rogue': 'Pícaro',
    'sorcerer': 'Hechicero',
    'warlock': 'Brujo',
    'wizard': 'Mago',
  };

  /// Respaldo sin conexión: dado de golpe por clase
  static const Map<String, int> classHitDie = {
    'barbarian': 12,
    'bard': 8,
    'cleric': 8,
    'druid': 8,
    'fighter': 10,
    'monk': 8,
    'paladin': 10,
    'ranger': 10,
    'rogue': 8,
    'sorcerer': 6,
    'warlock': 8,
    'wizard': 6,
  };

  /// Respaldo sin conexión: salvaciones con competencia por clase
  static const Map<String, List<String>> classSaves = {
    'barbarian': ['str', 'con'],
    'bard': ['dex', 'cha'],
    'cleric': ['wis', 'cha'],
    'druid': ['int', 'wis'],
    'fighter': ['str', 'con'],
    'monk': ['str', 'dex'],
    'paladin': ['wis', 'cha'],
    'ranger': ['str', 'dex'],
    'rogue': ['dex', 'int'],
    'sorcerer': ['con', 'cha'],
    'warlock': ['wis', 'cha'],
    'wizard': ['int', 'wis'],
  };

  /// Clases que lanzan conjuros en el SRD (índices de la API).
  static const Set<String> spellcastingClasses = {
    'bard',
    'cleric',
    'druid',
    'paladin',
    'ranger',
    'sorcerer',
    'warlock',
    'wizard',
  };

  static String raceName(String index) => raceNames[index] ?? _pretty(index);

  static String className(String index) => classNames[index] ?? _pretty(index);

  static String subraceName(String index) =>
      subraceNames[index] ?? _pretty(index);

  static String _pretty(String index) => index
      .split('-')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// Lee la raza guardada. Acepta el formato antiguo (nombre en español).
  static String raceIndexFrom(dynamic raw) => _indexFrom(raw, raceNames);

  /// Lee la clase guardada. Acepta el formato antiguo (nombre en español).
  static String classIndexFrom(dynamic raw) => _indexFrom(raw, classNames);

  static String _indexFrom(dynamic raw, Map<String, String> names) {
    final value = (raw ?? '').toString();
    if (value.isEmpty || names.containsKey(value)) return value;

    for (final e in names.entries) {
      if (e.value == value) return e.key;
    }
    return value.toLowerCase().replaceAll(' ', '-');
  }
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
  /// Índice de la raza en la D&D 5e SRD API (por ejemplo "elf").
  /// Solo se guarda la elección: los datos de la raza se leen de la API.
  final String race;

  /// Índice de la subraza en la API (por ejemplo "high-elf"); vacío si no tiene.
  final String subrace;

  /// Índice de la clase en la API (por ejemplo "wizard").
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

  /// Objetos del personaje: solo índices de la API (los mágicos con "m:").
  /// Pueden repetirse (dos dagas).
  final List<String> items;

  /// Objetos equipados (subconjunto de [items]): armadura, escudo, armas.
  final List<String> equipped;

  /// Copia de los objetos creados por el Master que lleva el personaje
  /// (id -> datos). Son datos del usuario, no de la API.
  final Map<String, Map<String, dynamic>> customItems;

  /// Calculados al leer la API (no se guardan): CA con armadura y escudo
  /// y penalización de velocidad por armadura pesada.
  final int? acOverride;
  final int speedPenalty;

  /// Bonificadores de raza y subraza por característica. No se guardan en la
  /// base de datos: se calculan leyendo la API (ver [withRacial]).
  final Map<String, int> racialBonuses;

  const Character({
    this.id,
    required this.ownerUid,
    required this.name,
    required this.race,
    this.subrace = '',
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
    this.racialBonuses = const {},
    this.items = const [],
    this.equipped = const [],
    this.customItems = const {},
    this.acOverride,
    this.speedPenalty = 0,
  });

  /// Copia con los valores calculados a partir de la API (raza y equipo).
  Character withDerived({
    Map<String, int>? racial,
    int? ac,
    bool keepAc = true,
    int? speedPenalty,
  }) =>
      Character(
        id: id,
        ownerUid: ownerUid,
        name: name,
        race: race,
        subrace: subrace,
        characterClass: characterClass,
        background: background,
        alignment: alignment,
        level: level,
        abilities: abilities,
        maxHp: maxHp,
        armorClass: armorClass,
        speed: speed,
        savingThrows: savingThrows,
        skills: skills,
        equipment: equipment,
        notes: notes,
        spells: spells,
        racialBonuses: racial ?? racialBonuses,
        items: items,
        equipped: equipped,
        customItems: customItems,
        acOverride: keepAc ? (ac ?? acOverride) : ac,
        speedPenalty: speedPenalty ?? this.speedPenalty,
      );

  Character withRacial(Map<String, int> bonuses) => withDerived(racial: bonuses);

  /// CA que se muestra: la calculada con el equipo, o la de la ficha.
  int get effectiveAc => acOverride ?? armorClass;

  /// Velocidad real (con la penalización de la armadura).
  int get effectiveSpeed => (speed - speedPenalty).clamp(0, 999).toInt();

  /// Puntuación total: base + bonificador racial.
  int score(String key) => (abilities[key] ?? 10) + (racialBonuses[key] ?? 0);

  // ---------- Cálculos de la ficha ----------

  static int modifier(int score) => ((score - 10) / 2).floor();

  static String signed(int n) => n >= 0 ? '+$n' : '$n';

  int get proficiencyBonus => 2 + ((level - 1) ~/ 4);

  int mod(String key) => modifier(score(key));

  int get initiative => mod('dex');

  int saveBonus(String key) =>
      mod(key) + (savingThrows.contains(key) ? proficiencyBonus : 0);

  int skillBonus(String skill) =>
      mod(DndData.skills[skill] ?? 'str') +
      (skills.contains(skill) ? proficiencyBonus : 0);

  int get passivePerception => 10 + skillBonus('Percepción');

  /// Raza con su subraza entre paréntesis, si la tiene.
  String get raceLabel => subrace.isEmpty
      ? DndData.raceName(race)
      : '${DndData.raceName(race)} (${DndData.subraceName(subrace)})';

  String get summary =>
      '$raceLabel ${DndData.className(characterClass)} · Nivel $level';

  // ---------- Firestore ----------

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'name': name,
        'race': race,
        'subrace': subrace,
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
        'items': items,
        'equipped': equipped,
        'customItems': customItems,
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
      race: DndData.raceIndexFrom(m['race']),
      subrace: (m['subrace'] ?? '') as String,
      characterClass: DndData.classIndexFrom(m['characterClass']),
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
      items: List<String>.from(m['items'] ?? const []),
      equipped: List<String>.from(m['equipped'] ?? const []),
      customItems: {
        for (final e in ((m['customItems'] as Map?) ?? const {}).entries)
          e.key.toString(): Map<String, dynamic>.from(e.value as Map),
      },
    );
  }

  factory Character.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Character.fromMap(doc.data() ?? {}, id: doc.id);
}
