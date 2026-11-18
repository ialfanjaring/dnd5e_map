import 'dart:convert';

import 'package:http/http.dart' as http;

int? _int(dynamic v) => v is num ? v.toInt() : null;

List<String> _names(dynamic list) {
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => (e['name'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toList();
}

List<ApiRef> _refs(dynamic list) {
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => ApiRef(
            index: (e['index'] ?? '').toString(),
            name: (e['name'] ?? '').toString(),
          ))
      .where((r) => r.index.isNotEmpty)
      .toList();
}

/// Referencia mínima a un recurso de la API (índice + nombre).
class ApiRef {
  final String index;
  final String name;

  const ApiRef({required this.index, required this.name});
}

/// Datos generales de una clase.
class ApiClass {
  final String index;
  final String name;
  final int hitDie;
  final List<String> savingThrows;
  final List<String> proficiencies;
  final List<String> startingEquipment;
  final List<ApiRef> subclasses;
  final int? spellcastingLevel;
  final String? spellcastingAbility;
  final List<({String name, String text})> spellcastingInfo;

  const ApiClass({
    required this.index,
    required this.name,
    required this.hitDie,
    required this.savingThrows,
    required this.proficiencies,
    required this.startingEquipment,
    required this.subclasses,
    this.spellcastingLevel,
    this.spellcastingAbility,
    this.spellcastingInfo = const [],
  });

  factory ApiClass.fromJson(Map<String, dynamic> m) {
    final sc = m['spellcasting'];

    return ApiClass(
      index: (m['index'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      hitDie: _int(m['hit_die']) ?? 8,
      savingThrows: _names(m['saving_throws']),
      proficiencies: _names(m['proficiencies']),
      startingEquipment: ((m['starting_equipment'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) {
        final q = _int(e['quantity']) ?? 1;
        final n = ((e['equipment'] as Map?)?['name'] ?? '').toString();
        return q > 1 ? '$q× $n' : n;
      }).where((s) => s.isNotEmpty).toList(),
      subclasses: _refs(m['subclasses']),
      spellcastingLevel: sc is Map ? _int(sc['level']) : null,
      spellcastingAbility: sc is Map
          ? ((sc['spellcasting_ability'] as Map?)?['name'])?.toString()
          : null,
      spellcastingInfo: sc is Map
          ? ((sc['info'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) => (
                    name: (e['name'] ?? '').toString(),
                    text: ((e['desc'] as List?) ?? const []).join('\n\n'),
                  ))
              .toList()
          : const [],
    );
  }
}

/// Datos de una raza.
class ApiRace {
  final String index;
  final String name;
  final int? speed;
  final String size;
  final String sizeDescription;
  final String age;
  final String alignment;
  final String languageDescription;
  final List<String> languages;
  final List<String> proficiencies;

  /// Bonificadores raciales: característica (str, dex...) y valor
  final List<({String ability, int bonus})> abilityBonuses;
  final List<ApiRef> traits;
  final List<ApiRef> subraces;

  const ApiRace({
    required this.index,
    required this.name,
    required this.speed,
    required this.size,
    required this.sizeDescription,
    required this.age,
    required this.alignment,
    required this.languageDescription,
    required this.languages,
    required this.proficiencies,
    required this.abilityBonuses,
    required this.traits,
    required this.subraces,
  });

  factory ApiRace.fromJson(Map<String, dynamic> m) {
    return ApiRace(
      index: (m['index'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      speed: _int(m['speed']),
      size: (m['size'] ?? '').toString(),
      sizeDescription: (m['size_description'] ?? '').toString(),
      age: (m['age'] ?? '').toString(),
      alignment: (m['alignment'] ?? '').toString(),
      languageDescription: (m['language_desc'] ?? '').toString(),
      languages: _names(m['languages']),
      proficiencies: _names(m['starting_proficiencies']),
      abilityBonuses: ((m['ability_bonuses'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (
                ability:
                    ((e['ability_score'] as Map?)?['index'] ?? '').toString(),
                bonus: _int(e['bonus']) ?? 0,
              ))
          .where((b) => b.ability.isNotEmpty)
          .toList(),
      traits: _refs(m['traits']),
      subraces: _refs(m['subraces']),
    );
  }
}

/// Datos de una subraza.
class ApiSubrace {
  final String index;
  final String name;
  final String description;

  /// Bonificadores de la subraza: característica (str, dex...) y valor
  final List<({String ability, int bonus})> abilityBonuses;
  final List<ApiRef> traits;

  const ApiSubrace({
    required this.index,
    required this.name,
    required this.description,
    required this.abilityBonuses,
    required this.traits,
  });

  factory ApiSubrace.fromJson(Map<String, dynamic> m) {
    return ApiSubrace(
      index: (m['index'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      description: (m['desc'] ?? '').toString(),
      abilityBonuses: ((m['ability_bonuses'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (
                ability:
                    ((e['ability_score'] as Map?)?['index'] ?? '').toString(),
                bonus: _int(e['bonus']) ?? 0,
              ))
          .where((b) => b.ability.isNotEmpty)
          .toList(),
      traits: _refs(m['racial_traits']),
    );
  }
}

/// Qué obtiene la clase en un nivel concreto.
class ApiClassLevel {
  final int level;
  final int profBonus;
  final bool abilityScoreImprovement;
  final List<ApiRef> features;
  final int? cantripsKnown;
  final int? spellsKnown;

  /// nivel de conjuro -> espacios disponibles
  final Map<int, int> slots;

  /// Datos propios de la clase (furias, dados de artes marciales, etc.)
  final List<String> classSpecific;

  const ApiClassLevel({
    required this.level,
    required this.profBonus,
    required this.abilityScoreImprovement,
    required this.features,
    this.cantripsKnown,
    this.spellsKnown,
    this.slots = const {},
    this.classSpecific = const [],
  });

  factory ApiClassLevel.fromJson(Map<String, dynamic> m) {
    final sc = m['spellcasting'];
    final slots = <int, int>{};

    if (sc is Map) {
      for (var i = 1; i <= 9; i++) {
        final n = _int(sc['spell_slots_level_$i']) ?? 0;
        if (n > 0) slots[i] = n;
      }
    }

    return ApiClassLevel(
      level: _int(m['level']) ?? 0,
      profBonus: _int(m['prof_bonus']) ?? 2,
      abilityScoreImprovement: (_int(m['ability_score_bonuses']) ?? 0) > 0,
      features: _refs(m['features']),
      cantripsKnown: sc is Map ? _int(sc['cantrips_known']) : null,
      spellsKnown: sc is Map ? _int(sc['spells_known']) : null,
      slots: slots,
      classSpecific: _formatSpecific(m['class_specific']),
    );
  }

  static List<String> _formatSpecific(dynamic v) {
    if (v is! Map) return const [];

    final out = <String>[];
    v.forEach((key, value) {
      final label = key.toString().replaceAll('_', ' ');
      if (value is num || value is String) {
        out.add('$label: $value');
      } else if (value is bool) {
        out.add('$label: ${value ? 'sí' : 'no'}');
      } else if (value is Map &&
          value['dice_count'] != null &&
          value['dice_value'] != null) {
        out.add('$label: ${value['dice_count']}d${value['dice_value']}');
      }
    });
    return out;
  }
}

/// Hechizo en la lista de una clase.
class ApiSpellRef {
  final String index;
  final String name;

  /// 0 = truco; null si la API no indica el nivel
  final int? level;

  const ApiSpellRef({required this.index, required this.name, this.level});
}

/// Detalle de un hechizo.
class ApiSpell {
  final String index;
  final String name;
  final int level;
  final String school;
  final String castingTime;
  final String range;
  final String duration;
  final String components;
  final bool ritual;
  final bool concentration;
  final List<String> desc;
  final List<String> higherLevel;

  const ApiSpell({
    required this.index,
    required this.name,
    required this.level,
    required this.school,
    required this.castingTime,
    required this.range,
    required this.duration,
    required this.components,
    required this.ritual,
    required this.concentration,
    required this.desc,
    required this.higherLevel,
  });

  static const Map<String, String> _schools = {
    'Abjuration': 'Abjuración',
    'Conjuration': 'Conjuración',
    'Divination': 'Adivinación',
    'Enchantment': 'Encantamiento',
    'Evocation': 'Evocación',
    'Illusion': 'Ilusión',
    'Necromancy': 'Nigromancia',
    'Transmutation': 'Transmutación',
  };

  factory ApiSpell.fromJson(Map<String, dynamic> m) {
    final schoolName = ((m['school'] as Map?)?['name'] ?? '').toString();
    final comps = ((m['components'] as List?) ?? const []).join(', ');
    final material = (m['material'] ?? '').toString();

    List<String> strings(dynamic v) =>
        v is List ? v.map((e) => e.toString()).toList() : const [];

    return ApiSpell(
      index: (m['index'] ?? '') as String,
      name: (m['name'] ?? '') as String,
      level: _int(m['level']) ?? 0,
      school: _schools[schoolName] ?? schoolName,
      castingTime: (m['casting_time'] ?? '').toString(),
      range: (m['range'] ?? '').toString(),
      duration: (m['duration'] ?? '').toString(),
      components: material.isEmpty ? comps : '$comps ($material)',
      ritual: m['ritual'] == true,
      concentration: m['concentration'] == true,
      desc: strings(m['desc']),
      higherLevel: strings(m['higher_level']),
    );
  }
}

/// Cliente de la D&D 5e SRD API para clases, niveles, rasgos y hechizos.
///
/// La API solo ofrece los textos en inglés (también fr-FR y pt-BR), así que
/// el contenido se muestra en inglés y las etiquetas de la app en español.
class ClassApiService {
  static const String _base = 'https://www.dnd5eapi.co/api/2014';

  static final Map<String, ApiClass> _classCache = {};
  static final Map<String, List<ApiClassLevel>> _levelsCache = {};
  static final Map<String, List<ApiSpellRef>> _spellListCache = {};
  static final Map<String, ApiSpell> _spellCache = {};
  static final Map<String, List<String>> _textCache = {};

  Future<dynamic> _getJson(String path) async {
    final res = await http
        .get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('La API respondió con el código ${res.statusCode}.');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<ApiClass> fetchClass(String index) async {
    final cached = _classCache[index];
    if (cached != null) return cached;

    final data = await _getJson('/classes/$index') as Map<String, dynamic>;
    return _classCache[index] = ApiClass.fromJson(data);
  }

  /// Los 20 niveles de la clase.
  Future<List<ApiClassLevel>> fetchLevels(String index) async {
    final cached = _levelsCache[index];
    if (cached != null) return cached;

    final data = await _getJson('/classes/$index/levels');
    final raw = data is List
        ? data
        : (data is Map ? (data['results'] ?? const []) : const []) as List;

    final levels = raw
        .whereType<Map>()
        .map((e) => ApiClassLevel.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.level.compareTo(b.level));

    return _levelsCache[index] = levels;
  }

  static Map<String, ApiSpellRef>? _allSpellsCache;

  static List<ApiSpellRef> _spellRefs(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => ApiSpellRef(
              index: (e['index'] ?? '').toString(),
              name: (e['name'] ?? '').toString(),
              level: _int(e['level']),
            ))
        .where((s) => s.index.isNotEmpty)
        .toList();
  }

  /// Todos los hechizos del SRD (índice -> nombre y nivel).
  /// Se descarga una vez y se guarda solo en memoria mientras la app está abierta.
  Future<Map<String, ApiSpellRef>> fetchAllSpells() async {
    final cached = _allSpellsCache;
    if (cached != null) return cached;

    final data = await _getJson('/spells') as Map<String, dynamic>;
    var list = _spellRefs(data['results']);

    // Si la lista no trae el nivel, se consulta nivel a nivel (0 = trucos)
    if (list.isNotEmpty && list.every((s) => s.level == null)) {
      final responses = await Future.wait([
        for (var l = 0; l <= 9; l++) _getJson('/spells?level=$l'),
      ]);

      final levels = <String, int>{};
      for (var l = 0; l <= 9; l++) {
        final results = (responses[l] as Map)['results'];
        for (final s in _spellRefs(results)) {
          levels[s.index] = l;
        }
      }

      list = [
        for (final s in list)
          ApiSpellRef(index: s.index, name: s.name, level: levels[s.index]),
      ];
    }

    return _allSpellsCache = {for (final s in list) s.index: s};
  }

  /// Hechizos disponibles para una clase.
  Future<List<ApiSpellRef>> fetchClassSpells(String classIndex) async {
    final cached = _spellListCache[classIndex];
    if (cached != null) return cached;

    final data =
        await _getJson('/classes/$classIndex/spells') as Map<String, dynamic>;
    final refs = _spellRefs(data['results']);

    // Completa el nivel con la lista general si la de la clase no lo trae
    Map<String, ApiSpellRef> all = const {};
    if (refs.any((s) => s.level == null)) {
      try {
        all = await fetchAllSpells();
      } catch (_) {}
    }

    final list = [
      for (final s in refs)
        ApiSpellRef(
          index: s.index,
          name: s.name,
          level: s.level ?? all[s.index]?.level,
        ),
    ]..sort((a, b) {
        final byLevel = (a.level ?? 99).compareTo(b.level ?? 99);
        return byLevel != 0 ? byLevel : a.name.compareTo(b.name);
      });

    return _spellListCache[classIndex] = list;
  }

  Future<ApiSpell> fetchSpell(String index) async {
    final cached = _spellCache[index];
    if (cached != null) return cached;

    final data = await _getJson('/spells/$index') as Map<String, dynamic>;
    return _spellCache[index] = ApiSpell.fromJson(data);
  }

  /// Descripción de un rasgo de clase.
  Future<List<String>> fetchFeatureText(String index) async {
    final key = 'feature:$index';
    final cached = _textCache[key];
    if (cached != null) return cached;

    final data = await _getJson('/features/$index') as Map<String, dynamic>;
    final desc = ((data['desc'] ?? const []) as List)
        .map((e) => e.toString())
        .toList();

    return _textCache[key] = desc;
  }

  /// Descripción de una subclase.
  Future<List<String>> fetchSubclassText(String index) async {
    final key = 'subclass:$index';
    final cached = _textCache[key];
    if (cached != null) return cached;

    final data = await _getJson('/subclasses/$index') as Map<String, dynamic>;
    final flavor = (data['subclass_flavor'] ?? '').toString();
    final desc = ((data['desc'] ?? const []) as List)
        .map((e) => e.toString())
        .toList();

    return _textCache[key] = [
      if (flavor.isNotEmpty) flavor,
      ...desc,
    ];
  }

  // ---------------- Razas y lista de clases ----------------

  static final Map<String, ApiRace> _raceCache = {};

  /// Razas disponibles en la API (índice + nombre en inglés).
  Future<List<ApiRef>> fetchRaceList() async {
    final data = await _getJson('/races') as Map<String, dynamic>;
    return _refs(data['results']);
  }

  /// Clases disponibles en la API (índice + nombre en inglés).
  Future<List<ApiRef>> fetchClassList() async {
    final data = await _getJson('/classes') as Map<String, dynamic>;
    return _refs(data['results']);
  }

  Future<ApiRace> fetchRace(String index) async {
    final cached = _raceCache[index];
    if (cached != null) return cached;

    final data = await _getJson('/races/$index') as Map<String, dynamic>;
    return _raceCache[index] = ApiRace.fromJson(data);
  }

  /// Descripción de un rasgo racial.
  Future<List<String>> fetchTraitText(String index) async {
    final key = 'trait:$index';
    final cached = _textCache[key];
    if (cached != null) return cached;

    final data = await _getJson('/traits/$index') as Map<String, dynamic>;
    final desc = ((data['desc'] ?? const []) as List)
        .map((e) => e.toString())
        .toList();

    return _textCache[key] = desc;
  }

  static final Map<String, ApiSubrace> _subraceCache = {};

  Future<ApiSubrace> fetchSubrace(String index) async {
    final cached = _subraceCache[index];
    if (cached != null) return cached;

    final data = await _getJson('/subraces/$index') as Map<String, dynamic>;
    return _subraceCache[index] = ApiSubrace.fromJson(data);
  }

  /// Descripción, bonificadores y rasgos de una subraza, como texto.
  Future<List<String>> fetchSubraceText(String index) async {
    final sub = await fetchSubrace(index);

    final bonuses = sub.abilityBonuses
        .map((b) =>
            '${b.ability.toUpperCase()} ${b.bonus >= 0 ? '+${b.bonus}' : '${b.bonus}'}')
        .toList();

    return [
      sub.description,
      if (bonuses.isNotEmpty) 'Bonificadores: ${bonuses.join(', ')}',
      if (sub.traits.isNotEmpty)
        'Rasgos: ${sub.traits.map((t) => t.name).join(', ')}',
    ].where((t) => t.isNotEmpty).toList();
  }

  /// Bonificadores totales (raza + subraza) por característica.
  Future<Map<String, int>> fetchRacialBonuses(
    String race,
    String subrace,
  ) async {
    final totals = <String, int>{};
    if (race.isNotEmpty) {
      for (final b in (await fetchRace(race)).abilityBonuses) {
        totals[b.ability] = (totals[b.ability] ?? 0) + b.bonus;
      }
    }
    if (subrace.isNotEmpty) {
      for (final b in (await fetchSubrace(subrace)).abilityBonuses) {
        totals[b.ability] = (totals[b.ability] ?? 0) + b.bonus;
      }
    }
    return totals;
  }
}
