import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/character.dart';
import '../models/creature.dart';
import '../settings/app_settings.dart';

/// Lanzamiento de conjuros de un monstruo de la API: espacios por nivel e
/// índices de sus hechizos. Se consulta al momento (no se guarda).
class MonsterSpellcasting {
  final Map<int, int> slots;
  final List<String> spells;

  const MonsterSpellcasting({this.slots = const {}, this.spells = const []});

  bool get isEmpty => slots.isEmpty && spells.isEmpty;
}

/// Monstruo de la lista de la API (solo índice y nombre).
class ApiMonsterRef {
  final String index;
  final String name;

  const ApiMonsterRef({required this.index, required this.name});
}

/// Cliente de la D&D 5e SRD API (https://www.dnd5eapi.co/).
///
/// Los monstruos de la API NO se guardan en la base de datos: se consultan
/// cuando se necesitan y solo se conservan en memoria mientras la app está
/// abierta. En las partidas solo se guarda el índice del monstruo.
///
/// La API solo tiene los textos en inglés (soporta fr-FR y pt-BR, pero no
/// español), así que traducimos tamaño, tipo, alineamiento y etiquetas, y
/// dejamos en inglés los nombres y las descripciones.
class MonsterApiService {

  static const String _base = 'https://www.dnd5eapi.co/api/2014';

  // Caché en memoria de las listas ya descargadas (clave: filtro de FP)
  static final Map<String, List<ApiMonsterRef>> _listCache = {};

  // Caché en memoria de los monstruos ya consultados (clave: índice)
  static final Map<String, Creature> _monsterCache = {};

  /// Filtro de FP para la lista de la API: texto visible -> valor numérico.
  static const Map<String, num> crFilters = {
    '0': 0,
    '1/8': 0.125,
    '1/4': 0.25,
    '1/2': 0.5,
    '1': 1,
    '2': 2,
    '3': 3,
    '4': 4,
    '5': 5,
    '6': 6,
    '7': 7,
    '8': 8,
    '9': 9,
    '10': 10,
    '11': 11,
    '12': 12,
    '13': 13,
    '14': 14,
    '15': 15,
    '16': 16,
    '17': 17,
    '18': 18,
    '19': 19,
    '20': 20,
    '21': 21,
    '22': 22,
    '23': 23,
    '24': 24,
    '30': 30,
  };

  static final Map<String, MonsterSpellcasting> _spellcastingCache = {};

  /// Hechizos y espacios de conjuro de un monstruo de la API.
  Future<MonsterSpellcasting> fetchSpellcasting(String index) async {
    final cached = _spellcastingCache[index];
    if (cached != null) return cached;

    final m = await _getJson('/monsters/$index') as Map<String, dynamic>;
    final slots = <int, int>{};
    final spells = <String>[];

    for (final ab in (m['special_abilities'] as List? ?? const [])) {
      if (ab is! Map) continue;
      final sc = ab['spellcasting'];
      if (sc is! Map) continue;

      final rawSlots = sc['slots'];
      if (rawSlots is Map) {
        rawSlots.forEach((k, v) {
          final lvl = int.tryParse(k.toString());
          final n = v is num ? v.toInt() : int.tryParse(v.toString());
          if (lvl != null && n != null && n > 0) slots[lvl] = n;
        });
      }
      for (final sp in (sc['spells'] as List? ?? const [])) {
        if (sp is! Map) continue;
        final url = (sp['url'] ?? '').toString();
        final idx = url.isEmpty ? '' : url.split('/').last;
        if (idx.isNotEmpty && !spells.contains(idx)) spells.add(idx);
      }
    }

    return _spellcastingCache[index] =
        MonsterSpellcasting(slots: slots, spells: spells);
  }

  /// Monstruo ya consultado en esta sesión (null si aún no se ha descargado).
  Creature? cachedMonster(String index) =>
      _monsterCache['${AppSettings.instance.lang}|$index'];

  // ---------------- Consultas ----------------

  Future<dynamic> _getJson(String path) async {
    final res = await http
        .get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('La API respondió con el código ${res.statusCode}.');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Lista de monstruos. [crValue] filtra por valor de desafío (ej. 0.25).
  Future<List<ApiMonsterRef>> fetchList({num? crValue}) async {
    final key = crValue?.toString() ?? 'all';
    final cached = _listCache[key];
    if (cached != null) return cached;

    final path = crValue == null
        ? '/monsters'
        : '/monsters?challenge_rating=$crValue';
    final data = await _getJson(path) as Map<String, dynamic>;

    final list = ((data['results'] ?? []) as List)
        .map(
          (e) => ApiMonsterRef(
            index: (e['index'] ?? '') as String,
            name: (e['name'] ?? '') as String,
          ),
        )
        .where((m) => m.index.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _listCache[key] = list;
    return list;
  }

  /// Descarga un monstruo y lo convierte a nuestro modelo (solo en memoria).
  Future<Creature> fetchMonster(String index) async {
    final ck = '${AppSettings.instance.lang}|$index';
    final cached = _monsterCache[ck];
    if (cached != null) return cached;

    final data = await _getJson('/monsters/$index') as Map<String, dynamic>;
    return _monsterCache[ck] = creatureFromApi(data);
  }

  // ---------------- Conversión API -> Creature ----------------

  static const Map<String, String> _sizes = {
    'Tiny': 'Diminuta',
    'Small': 'Pequeña',
    'Medium': 'Mediana',
    'Large': 'Grande',
    'Huge': 'Enorme',
    'Gargantuan': 'Gargantuesca',
  };

  static const Map<String, String> _types = {
    'aberration': 'Aberración',
    'beast': 'Bestia',
    'celestial': 'Celestial',
    'construct': 'Constructo',
    'dragon': 'Dragón',
    'elemental': 'Elemental',
    'fey': 'Feérico',
    'fiend': 'Infernal',
    'giant': 'Gigante',
    'humanoid': 'Humanoide',
    'monstrosity': 'Monstruosidad',
    'ooze': 'Cieno',
    'plant': 'Planta',
    'undead': 'No-muerto',
  };

  static const Map<String, String> _alignments = {
    'lawful good': 'Legal bueno',
    'neutral good': 'Neutral bueno',
    'chaotic good': 'Caótico bueno',
    'lawful neutral': 'Legal neutral',
    'neutral': 'Neutral',
    'chaotic neutral': 'Caótico neutral',
    'lawful evil': 'Legal malvado',
    'neutral evil': 'Neutral malvado',
    'chaotic evil': 'Caótico malvado',
    'unaligned': 'Sin alineamiento',
    'any alignment': 'Cualquier alineamiento',
    'any non-lawful alignment': 'Cualquiera no legal',
    'any non-good alignment': 'Cualquiera no bueno',
    'any chaotic alignment': 'Cualquiera caótico',
    'any evil alignment': 'Cualquiera malvado',
  };


  // ---- Traducción de las partes fijas de la ficha (solo en español) ----
  static bool get _es => AppSettings.instance.lang == 'es';

  static const Map<String, String> _abil = {
    'STR': 'FUE', 'DEX': 'DES', 'CON': 'CON', 'INT': 'INT', 'WIS': 'SAB', 'CHA': 'CAR',
    'Strength': 'Fuerza', 'Dexterity': 'Destreza', 'Constitution': 'Constitución',
    'Intelligence': 'Inteligencia', 'Wisdom': 'Sabiduría', 'Charisma': 'Carisma',
  };

  static const Map<String, String> _skillsEs = {
    'Acrobatics': 'Acrobacias', 'Animal Handling': 'Trato con animales',
    'Arcana': 'Arcanos', 'Athletics': 'Atletismo', 'Deception': 'Engaño',
    'History': 'Historia', 'Insight': 'Perspicacia', 'Intimidation': 'Intimidación',
    'Investigation': 'Investigación', 'Medicine': 'Medicina', 'Nature': 'Naturaleza',
    'Perception': 'Percepción', 'Performance': 'Interpretación',
    'Persuasion': 'Persuasión', 'Religion': 'Religión',
    'Sleight of Hand': 'Juego de manos', 'Stealth': 'Sigilo', 'Survival': 'Supervivencia',
  };

  static const Map<String, String> _words = {
    // tipos de daño
    'acid': 'ácido', 'bludgeoning': 'contundente', 'cold': 'frío', 'fire': 'fuego',
    'force': 'fuerza', 'lightning': 'relámpago', 'necrotic': 'necrótico',
    'piercing': 'perforante', 'poison': 'veneno', 'psychic': 'psíquico',
    'radiant': 'radiante', 'slashing': 'cortante', 'thunder': 'trueno',
    'nonmagical attacks': 'ataques no mágicos',
    'nonmagical weapons': 'armas no mágicas',
    "that aren't silvered": 'que no sean de plata',
    "that aren't adamantine": 'que no sean de adamantina',
    'from nonmagical attacks': 'de ataques no mágicos',
    'magic weapons': 'armas mágicas',
    // condiciones
    'Blinded': 'Cegado', 'Charmed': 'Hechizado', 'Deafened': 'Ensordecido',
    'Exhaustion': 'Agotamiento', 'Frightened': 'Asustado', 'Grappled': 'Agarrado',
    'Incapacitated': 'Incapacitado', 'Paralyzed': 'Paralizado',
    'Petrified': 'Petrificado', 'Poisoned': 'Envenenado', 'Prone': 'Derribado',
    'Restrained': 'Apresado', 'Stunned': 'Aturdido', 'Unconscious': 'Inconsciente',
    // idiomas
    'Common': 'Común', 'Draconic': 'Dracónico', 'Elvish': 'Élfico',
    'Dwarvish': 'Enano', 'Giant': 'Gigante', 'Gnomish': 'Gnomo',
    'Halfling': 'Mediano', 'Orc': 'Orco', 'Infernal': 'Infernal',
    'Abyssal': 'Abisal', 'Celestial': 'Celestial', 'Sylvan': 'Silvano',
    'Undercommon': 'Subcomún', 'Deep Speech': 'Habla profunda',
    'Primordial': 'Primigenio', 'Aquan': 'Acuano', 'Auran': 'Auran',
    'Ignan': 'Ígneo', 'Terran': 'Terrano', 'Telepathy': 'Telepatía',
    'telepathy': 'telepatía', 'understands': 'entiende',
    "but can't speak": 'pero no puede hablar',
    'the languages it knew in life': 'los idiomas que conocía en vida',
    'all': 'todos', 'any one language': 'un idioma cualquiera',
    '(usually Common)': '(normalmente Común)',
    '(Common)': '(Común)',
    'plus': 'más', 'and': 'y', 'or': 'o',
  };

  /// Sustituye los términos conocidos (palabras completas) por su traducción.
  static String _trWords(String t) {
    if (!_es || t.isEmpty) return t;
    final keys = _words.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      t = t.replaceAllMapped(
        RegExp('(?<![A-Za-zÁ-úñ])${RegExp.escape(k)}(?![A-Za-zÁ-úñ])',
            caseSensitive: k[0] != k[0].toLowerCase() ? true : false),
        (_) => _words[k]!,
      );
    }
    return t;
  }

  static String _abilityEs(String a) => _es ? (_abil[a] ?? a) : a;
  static String _skillEs(String a) => _es ? (_skillsEs[a] ?? a) : a;

  static String _feet(String s) =>
      _es ? s.replaceAll('ft.', 'pies').trim() : s.trim();

  static String _crToString(num cr) {
    if (cr == 0.125) return '1/8';
    if (cr == 0.25) return '1/4';
    if (cr == 0.5) return '1/2';
    return cr.toInt().toString();
  }

  static String _namedBlocks(dynamic list) {
    if (list is! List) return '';
    return list
        .whereType<Map>()
        .map((e) => '${e['name'] ?? ''}. ${e['desc'] ?? ''}'.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  static String _stringList(dynamic v) =>
      v is List ? v.map((e) => _trWords(e.toString())).join('; ') : '';

  /// Convierte el JSON de la API en una criatura de nuestro modelo.
  Creature creatureFromApi(Map<String, dynamic> m) {
    final index = (m['index'] ?? '') as String;

    // Clase de armadura: lista de objetos {type, value} (o número en versiones antiguas)
    var ac = 10;
    final rawAc = m['armor_class'];
    if (rawAc is num) {
      ac = rawAc.toInt();
    } else if (rawAc is List && rawAc.isNotEmpty && rawAc.first is Map) {
      ac = (((rawAc.first as Map)['value'] ?? 10) as num).toInt();
    }

    // Velocidad
    final speedParts = <String>[];
    final speed = m['speed'];
    if (speed is Map) {
      final labels = _es
          ? const {
              'walk': '',
              'burrow': 'excavar ',
              'climb': 'trepar ',
              'fly': 'volar ',
              'swim': 'nadar ',
            }
          : const {
              'walk': '',
              'burrow': 'burrow ',
              'climb': 'climb ',
              'fly': 'fly ',
              'swim': 'swim ',
            };
      labels.forEach((key, label) {
        final v = speed[key];
        if (v is String && v.isNotEmpty) {
          speedParts.add('$label${_feet(v)}');
        }
      });
    }

    // Salvaciones y habilidades con competencia
    final saves = <String>[];
    final skills = <String>[];
    for (final p in (m['proficiencies'] as List? ?? const [])) {
      if (p is! Map) continue;
      final name = ((p['proficiency'] as Map?)?['name'] ?? '') as String;
      final value = Character.signed(((p['value'] ?? 0) as num).toInt());
      if (name.startsWith('Saving Throw: ')) {
        saves.add('${_abilityEs(name.substring(14))} $value');
      } else if (name.startsWith('Skill: ')) {
        skills.add('${_skillEs(name.substring(7))} $value');
      }
    }
    final skillsText = [
      if (saves.isNotEmpty)
        '${_es ? 'Salvaciones' : 'Saving Throws'}: ${saves.join(', ')}',
      if (skills.isNotEmpty)
        '${_es ? 'Habilidades' : 'Skills'}: ${skills.join(', ')}',
    ].join('. ');

    // Sentidos
    final sensesParts = <String>[];
    final senses = m['senses'];
    if (senses is Map) {
      final labels = _es
          ? const {
              'blindsight': 'Vista ciega',
              'darkvision': 'Visión en la oscuridad',
              'tremorsense': 'Sentido sísmico',
              'truesight': 'Visión verdadera',
            }
          : const {
              'blindsight': 'Blindsight',
              'darkvision': 'Darkvision',
              'tremorsense': 'Tremorsense',
              'truesight': 'Truesight',
            };
      labels.forEach((key, label) {
        final v = senses[key];
        if (v is String && v.isNotEmpty) sensesParts.add('$label ${_feet(v)}');
      });
      final pp = senses['passive_perception'];
      if (pp is num) sensesParts.add(
          '${_es ? 'Percepción pasiva' : 'Passive Perception'} ${pp.toInt()}');
    }

    // Resistencias e inmunidades -> primeras líneas de los rasgos
    final conditionImmunities = (m['condition_immunities'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => _trWords((e['name'] ?? '').toString()))
        .where((s) => s.isNotEmpty)
        .join(', ');

    final traitLines = <String>[
      if (_stringList(m['damage_vulnerabilities']).isNotEmpty)
        '${_es ? 'Vulnerabilidades al daño' : 'Damage Vulnerabilities'}: ${_stringList(m['damage_vulnerabilities'])}',
      if (_stringList(m['damage_resistances']).isNotEmpty)
        '${_es ? 'Resistencias al daño' : 'Damage Resistances'}: ${_stringList(m['damage_resistances'])}',
      if (_stringList(m['damage_immunities']).isNotEmpty)
        '${_es ? 'Inmunidades al daño' : 'Damage Immunities'}: ${_stringList(m['damage_immunities'])}',
      if (conditionImmunities.isNotEmpty)
        '${_es ? 'Inmunidades a condiciones' : 'Condition Immunities'}: $conditionImmunities',
      _namedBlocks(m['special_abilities']),
    ].where((s) => s.isNotEmpty).join('\n');

    // Acciones, reacciones y acciones legendarias
    final reactions = _namedBlocks(m['reactions']);
    final legendary = _namedBlocks(m['legendary_actions']);
    final actionsText = [
      _namedBlocks(m['actions']),
      if (reactions.isNotEmpty) '${_es ? 'Reacciones' : 'Reactions'}:\n$reactions',
      if (legendary.isNotEmpty) '${_es ? 'Acciones legendarias' : 'Legendary Actions'}:\n$legendary',
    ].where((s) => s.isNotEmpty).join('\n\n');

    final subtype = (m['subtype'] ?? '') as String;
    final typeEs = _types[(m['type'] ?? '').toString().toLowerCase()] ??
        (m['type'] ?? 'Monstruosidad').toString();
    final alignmentRaw = (m['alignment'] ?? 'unaligned').toString();

    final hitRoll = (m['hit_points_roll'] ?? m['hit_dice'] ?? '').toString();

    return Creature(
      ownerUid: '',
      kind: 'monster',
      name: (m['name'] ?? index) as String,
      size: _sizes[m['size']] ?? (m['size'] ?? 'Mediana') as String,
      creatureType: subtype.isEmpty ? typeEs : '$typeEs ($subtype)',
      alignment: _alignments[alignmentRaw.toLowerCase()] ?? alignmentRaw,
      challengeRating: _crToString((m['challenge_rating'] ?? 0) as num),
      armorClass: ac,
      maxHp: ((m['hit_points'] ?? 1) as num).toInt(),
      hitDice: hitRoll,
      speed: speedParts.isEmpty ? '30 pies' : speedParts.join(', '),
      abilities: {
        'str': ((m['strength'] ?? 10) as num).toInt(),
        'dex': ((m['dexterity'] ?? 10) as num).toInt(),
        'con': ((m['constitution'] ?? 10) as num).toInt(),
        'int': ((m['intelligence'] ?? 10) as num).toInt(),
        'wis': ((m['wisdom'] ?? 10) as num).toInt(),
        'cha': ((m['charisma'] ?? 10) as num).toInt(),
      },
      skills: skillsText,
      senses: sensesParts.join('; '),
      languages: _trWords((m['languages'] ?? '') as String),
      traits: traitLines,
      actions: actionsText,
    );
  }
}
