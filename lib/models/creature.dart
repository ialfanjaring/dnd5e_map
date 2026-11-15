import 'package:cloud_firestore/cloud_firestore.dart';

import 'character.dart';

class CreatureData {
  static const Map<String, String> kinds = {
    'monster': 'Monstruo',
    'npc': 'NPC',
  };

  static const List<String> sizes = [
    'Diminuta',
    'Pequeña',
    'Mediana',
    'Grande',
    'Enorme',
    'Gargantuesca',
  ];

  static const List<String> types = [
    'Aberración',
    'Bestia',
    'Celestial',
    'Constructo',
    'Dragón',
    'Elemental',
    'Feérico',
    'Infernal',
    'Gigante',
    'Humanoide',
    'Monstruosidad',
    'Cieno',
    'Planta',
    'No-muerto',
  ];

  static const List<String> alignments = [
    'Sin alineamiento',
    'Cualquier alineamiento',
    'Cualquiera no legal',
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

  /// Valor de desafío (FP) -> experiencia
  static const Map<String, int> challengeRatings = {
    '0': 10,
    '1/8': 25,
    '1/4': 50,
    '1/2': 100,
    '1': 200,
    '2': 450,
    '3': 700,
    '4': 1100,
    '5': 1800,
    '6': 2300,
    '7': 2900,
    '8': 3900,
    '9': 5000,
    '10': 5900,
    '11': 7200,
    '12': 8400,
    '13': 10000,
    '14': 11500,
    '15': 13000,
    '16': 15000,
    '17': 18000,
    '18': 20000,
    '19': 22000,
    '20': 25000,
  };
}

/// Monstruo o NPC (bloque de estadísticas de D&D 5e).
class Creature {
  final String? id;
  final String ownerUid;

  /// 'monster' o 'npc'
  final String kind;
  final String name;
  final String size;
  final String creatureType;
  final String alignment;
  final String challengeRating;
  final int armorClass;
  final int maxHp;
  final String hitDice;
  final String speed;
  final Map<String, int> abilities;
  final String skills;
  final String senses;
  final String languages;
  final String traits;
  final String actions;
  final String notes;

  /// true si viene de los datos predeterminados (SRD)
  final bool isPreset;

  const Creature({
    this.id,
    required this.ownerUid,
    this.kind = 'monster',
    required this.name,
    this.size = 'Mediana',
    this.creatureType = 'Humanoide',
    this.alignment = 'Sin alineamiento',
    this.challengeRating = '1',
    this.armorClass = 10,
    required this.maxHp,
    this.hitDice = '',
    this.speed = '30 pies',
    required this.abilities,
    this.skills = '',
    this.senses = '',
    this.languages = '',
    this.traits = '',
    this.actions = '',
    this.notes = '',
    this.isPreset = false,
  });

  bool get isMonster => kind == 'monster';

  int mod(String key) => Character.modifier(abilities[key] ?? 10);

  int get xp => CreatureData.challengeRatings[challengeRating] ?? 0;

  String get subtitle => '$size $creatureType · FP $challengeRating';

  Map<String, dynamic> toMap() => {
        'ownerUid': ownerUid,
        'kind': kind,
        'name': name,
        'size': size,
        'creatureType': creatureType,
        'alignment': alignment,
        'challengeRating': challengeRating,
        'armorClass': armorClass,
        'maxHp': maxHp,
        'hitDice': hitDice,
        'speed': speed,
        'abilities': abilities,
        'skills': skills,
        'senses': senses,
        'languages': languages,
        'traits': traits,
        'actions': actions,
        'notes': notes,
        'isPreset': isPreset,
      };

  factory Creature.fromMap(Map<String, dynamic> m, {String? id}) {
    final raw = (m['abilities'] as Map?) ?? {};

    return Creature(
      id: id,
      ownerUid: (m['ownerUid'] ?? '') as String,
      kind: (m['kind'] ?? 'monster') as String,
      name: (m['name'] ?? '') as String,
      size: (m['size'] ?? 'Mediana') as String,
      creatureType: (m['creatureType'] ?? 'Humanoide') as String,
      alignment: (m['alignment'] ?? 'Sin alineamiento') as String,
      challengeRating: (m['challengeRating'] ?? '1') as String,
      armorClass: ((m['armorClass'] ?? 10) as num).toInt(),
      maxHp: ((m['maxHp'] ?? 1) as num).toInt(),
      hitDice: (m['hitDice'] ?? '') as String,
      speed: (m['speed'] ?? '30 pies') as String,
      abilities: {
        for (final k in DndData.abilityKeys) k: ((raw[k] ?? 10) as num).toInt(),
      },
      skills: (m['skills'] ?? '') as String,
      senses: (m['senses'] ?? '') as String,
      languages: (m['languages'] ?? '') as String,
      traits: (m['traits'] ?? '') as String,
      actions: (m['actions'] ?? '') as String,
      notes: (m['notes'] ?? '') as String,
      isPreset: (m['isPreset'] ?? false) as bool,
    );
  }

  factory Creature.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Creature.fromMap(doc.data() ?? {}, id: doc.id);
}

/// Criatura añadida a una partida (copia + PG actuales).
class GameCreature {
  final String id;
  final String label;
  final int currentHp;
  final Creature creature;

  const GameCreature({
    required this.id,
    required this.label,
    required this.currentHp,
    required this.creature,
  });

  factory GameCreature.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final creature = Creature.fromMap(
      Map<String, dynamic>.from(data['creature'] ?? {}),
    );

    return GameCreature(
      id: doc.id,
      label: (data['label'] ?? creature.name) as String,
      currentHp: ((data['currentHp'] ?? creature.maxHp) as num).toInt(),
      creature: creature,
    );
  }
}
