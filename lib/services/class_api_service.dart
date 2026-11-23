import 'dart:convert';

import 'package:http/http.dart' as http;

import '../i18n/srd_terms.dart';
import '../settings/app_settings.dart';
import 'translation_service.dart';

int? _int(dynamic v) => v is num ? v.toInt() : null;

List<String> _names(dynamic list) {
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) => (e['name'] ?? '').toString())
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Nombre en español de un elemento del SRD (sección de srd_es.json) o el
/// original si no hay traducción o la app no está en español.
/// La API y el módulo en español no siempre llaman igual a un elemento
/// (p. ej. «Land» frente a «Circle of the Land»). Nombres alternativos con los
/// que buscar la traducción, por nombre de la API en minúsculas.
const Map<String, List<String>> _nameAliases = {
  'berserker': ['Path of the Berserker'],
  'totem warrior': ['Path of the Totem Warrior'],
  'lore': ['College of Lore'],
  'life': ['Life Domain'],
  'land': ['Circle of the Land'],
  'open hand': ['Way of the Open Hand'],
  'devotion': ['Oath of Devotion'],
  'draconic': ['Draconic Bloodline', 'Draconic Sorcery'],
  'fiend': ['The Fiend'],
  'evocation': ['School of Evocation'],
  'lightfoot halfling': ['Lightfoot'],
  'rock gnome': ['Rock'],
  'hill dwarf': ['Hill'],
  'high elf': ['High'],
};

List<String> _candidates(String en) {
  final l = <String>[en];
  final a = _nameAliases[en.trim().toLowerCase()];
  if (a != null) l.addAll(a);
  return l;
}

String? _trNameCore(String section, String en) {
  if (section == 'traits') {
    final t = traitEs(en);
    if (t != null) return t.n;
  }
  // Los rasgos raciales y las subrazas vienen dentro del archivo de razas.
  final secs = switch (section) {
    'traits' => const ['traits', 'features', 'races'],
    'features' => const ['features', 'traits', 'races'],
    'subraces' => const ['subraces', 'races'],
    _ => [section],
  };
  for (final cand in _candidates(en)) {
    for (final sec in secs) {
      final t = SrdEs.get(sec, cand, 'n');
      if (t != null) return t;
    }
  }
  return null;
}

String _trName(String section, String en) {
  if (en.isEmpty) return en;
  final direct = _trNameCore(section, en);
  if (direct != null) return direct;

  // «Bardic Inspiration (d6)» -> «Inspiración bárdica (d6)»
  final pm = RegExp(r'^(.*?)(\s*\([^)]*\))$').firstMatch(en);
  if (pm != null) {
    final base = _trNameCore(section, pm[1]!);
    if (base != null) return '$base${pm[2]}';
  }

  // «Spellcasting: Bard» -> «Lanzamiento de conjuros: Bardo»
  final ci = en.indexOf(':');
  if (ci > 0) {
    final left = _trNameCore(section, en.substring(0, ci).trim());
    if (left != null) {
      final right = en.substring(ci + 1).trim();
      return '$left: ${_trName('classes', right)}';
    }
  }
  return en;
}

/// Rasgos que se llaman igual en varias clases pero con texto distinto: su
/// descripción no se sustituye para no mostrar la de otra clase.
const Set<String> _ambiguousFeatures = {
  'spellcasting',
  'fightingstyle',
  'channeldivinity',
  'unarmoreddefense',
  'extraattack',
  'expertise',
  'primalpath',
  'divinedomain',
};

/// Texto en español (separado en párrafos) o null si no hay traducción.
List<String>? _trParas(List<String> sections, String enName) {
  final k = enName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  if (_ambiguousFeatures.contains(k)) return null;
  if (sections.contains('traits')) {
    final t = traitEs(enName);
    if (t != null) return [t.d];
  }
  // «Bardic Inspiration (d6)»: prueba también sin el paréntesis
  final noParen = enName.replaceAll(RegExp(r'\s*\([^)]*\)'), '').trim();
  if (noParen != enName) {
    final r = _trParas(sections, noParen);
    if (r != null) return r;
  }
  for (final cand in _candidates(enName)) {
    for (final sec in sections) {
      final t = SrdEs.get(sec, cand, 'd');
      if (t != null) {
        return t.split('\n').where((e) => e.trim().isNotEmpty).toList();
      }
    }
  }
  return null;
}

bool get _isEs => AppSettings.instance.lang == 'es';

List<ApiRef> _refs(dynamic list, [String? section]) {
  if (list is! List) return const [];
  return list
      .whereType<Map>()
      .map((e) {
        final n = (e['name'] ?? '').toString();
        return ApiRef(
          index: (e['index'] ?? '').toString(),
          name: section == null ? n : _trName(section, n),
        );
      })
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
      name: _trName('classes', (m['name'] ?? '') as String),
      hitDie: _int(m['hit_die']) ?? 8,
      savingThrows: srdTerms(_names(m['saving_throws'])),
      proficiencies: srdTerms(_names(m['proficiencies'])),
      startingEquipment: ((m['starting_equipment'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) {
        final q = _int(e['quantity']) ?? 1;
        final en = ((e['equipment'] as Map?)?['name'] ?? '').toString();
        final n = SrdEs.item(en, 'n') ?? en;
        return q > 1 ? '$q× $n' : n;
      }).where((s) => s.isNotEmpty).toList(),
      subclasses: _refs(m['subclasses'], 'subclasses'),
      spellcastingLevel: sc is Map ? _int(sc['level']) : null,
      spellcastingAbility: sc is Map
          ? srdTerm(
              ((sc['spellcasting_ability'] as Map?)?['name'] ?? '').toString())
          : null,
      spellcastingInfo: sc is Map
          ? ((sc['info'] as List?) ?? const [])
              .whereType<Map>()
              .map((e) {
                final en = (e['name'] ?? '').toString();
                final es = spellcastingInfoEs((m['index'] ?? '').toString(), en);
                return (
                  name: es?.n ?? en,
                  text: es?.d ??
                      ((e['desc'] as List?) ?? const []).join('\n\n'),
                );
              })
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
    final idx = (m['index'] ?? '').toString();
    return ApiRace(
      index: (m['index'] ?? '') as String,
      name: _trName('races', (m['name'] ?? '') as String),
      speed: _int(m['speed']),
      size: srdTerm((m['size'] ?? '').toString()),
      sizeDescription: raceText(idx, 'size_description') ??
          (m['size_description'] ?? '').toString(),
      age: raceText(idx, 'age') ?? (m['age'] ?? '').toString(),
      alignment:
          raceText(idx, 'alignment') ?? (m['alignment'] ?? '').toString(),
      languageDescription: raceText(idx, 'language_desc') ??
          (m['language_desc'] ?? '').toString(),
      languages: srdTerms(_names(m['languages'])),
      proficiencies: srdTerms(_names(m['starting_proficiencies'])),
      abilityBonuses: ((m['ability_bonuses'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (
                ability:
                    ((e['ability_score'] as Map?)?['index'] ?? '').toString(),
                bonus: _int(e['bonus']) ?? 0,
              ))
          .where((b) => b.ability.isNotEmpty)
          .toList(),
      traits: _refs(m['traits'], 'traits'),
      subraces: _refs(m['subraces'], 'subraces'),
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
      name: _trName('subraces', (m['name'] ?? '') as String),
      description: subraceText((m['index'] ?? '').toString()) ??
          (_trParas(['subraces', 'races'], (m['name'] ?? '').toString())
              ?.join('\n')) ??
          (m['desc'] ?? '').toString(),
      abilityBonuses: ((m['ability_bonuses'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (
                ability:
                    ((e['ability_score'] as Map?)?['index'] ?? '').toString(),
                bonus: _int(e['bonus']) ?? 0,
              ))
          .where((b) => b.ability.isNotEmpty)
          .toList(),
      traits: _refs(m['racial_traits'], 'traits'),
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
      features: _refs(m['features'], 'features'),
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
      final label = classSpecificLabel(key.toString());
      if (value is num || value is String) {
        out.add('$label: $value');
      } else if (value is bool) {
        out.add('$label: ${value ? (_isEs ? 'sí' : 'yes') : 'no'}');
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
/// La API solo ofrece los textos en inglés. En español se sustituyen por las
/// traducciones empaquetadas en assets/data/srd_es.json y por los términos de
/// lib/i18n/srd_terms.dart; lo que no tenga traducción se muestra en inglés.
class ClassApiService {

  static const String _base = 'https://www.dnd5eapi.co/api/2014';

  static final Map<String, ApiClass> _classCache = {};
  static final Map<String, List<ApiClassLevel>> _levelsCache = {};
  static final Map<String, List<ApiSpellRef>> _spellListCache = {};
  static final Map<String, ApiSpell> _spellCache = {};
  static final Map<String, List<String>> _textCache = {};

  static String get _lang => AppSettings.instance.lang;

  Future<dynamic> _getJson(String path) async {
    // El diccionario en español debe estar cargado antes de construir modelos.
    await SrdEs.ensureLoaded();
    final res = await http
        .get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('La API respondió con el código ${res.statusCode}.');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<ApiClass> fetchClass(String index) async {
    final k = '$_lang|$index';
    final cached = _classCache[k];
    if (cached != null) return cached;

    final data = await _getJson('/classes/$index') as Map<String, dynamic>;
    return _classCache[k] = ApiClass.fromJson(data);
  }

  /// Los 20 niveles de la clase.
  Future<List<ApiClassLevel>> fetchLevels(String index) async {
    final k = '$_lang|$index';
    final cached = _levelsCache[k];
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

    return _levelsCache[k] = levels;
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
    final key = 'feature:$_lang:$index';
    final cached = _textCache[key];
    if (cached != null) return cached;

    final data = await _getJson('/features/$index') as Map<String, dynamic>;
    final desc = _trParas(['features'], (data['name'] ?? '').toString()) ??
        ((data['desc'] ?? const []) as List).map((e) => e.toString()).toList();

    return _textCache[key] = desc;
  }

  /// Descripción de una subclase.
  Future<List<String>> fetchSubclassText(String index) async {
    final key = 'subclass:$_lang:$index';
    final cached = _textCache[key];
    if (cached != null) return cached;

    final data = await _getJson('/subclasses/$index') as Map<String, dynamic>;
    final flavor = (data['subclass_flavor'] ?? '').toString();
    final desc = ((data['desc'] ?? const []) as List)
        .map((e) => e.toString())
        .toList();

    final es = _trParas(['subclasses'], (data['name'] ?? '').toString());
    if (es != null) return _textCache[key] = es;

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
    final k = '$_lang|$index';
    final cached = _raceCache[k];
    if (cached != null) return cached;

    final data = await _getJson('/races/$index') as Map<String, dynamic>;
    return _raceCache[k] = ApiRace.fromJson(data);
  }

  /// Descripción de un rasgo racial.
  Future<List<String>> fetchTraitText(String index) async {
    final key = 'trait:$_lang:$index';
    final cached = _textCache[key];
    if (cached != null) return cached;

    final data = await _getJson('/traits/$index') as Map<String, dynamic>;
    final desc =
        _trParas(['traits', 'features', 'races'], (data['name'] ?? '').toString()) ??
            ((data['desc'] ?? const []) as List)
                .map((e) => e.toString())
                .toList();

    return _textCache[key] = desc;
  }

  static final Map<String, ApiSubrace> _subraceCache = {};

  Future<ApiSubrace> fetchSubrace(String index) async {
    final k = '$_lang|$index';
    final cached = _subraceCache[k];
    if (cached != null) return cached;

    final data = await _getJson('/subraces/$index') as Map<String, dynamic>;
    return _subraceCache[k] = ApiSubrace.fromJson(data);
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
      if (bonuses.isNotEmpty)
        '${_isEs ? 'Bonificadores' : 'Bonuses'}: ${bonuses.join(', ')}',
      if (sub.traits.isNotEmpty)
        '${_isEs ? 'Rasgos' : 'Traits'}: ${sub.traits.map((t) => t.name).join(', ')}',
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
