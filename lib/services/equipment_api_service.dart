import 'dart:convert';

import 'package:http/http.dart' as http;

/// Referencia mínima a un objeto de la API (índice + nombre).
/// Los objetos mágicos llevan el prefijo "m:" en su índice (ver [ApiItem.magicPrefix]).
class ApiItemRef {
  final String index;
  final String name;

  const ApiItemRef({required this.index, required this.name});
}

/// Datos de un objeto: arma, armadura, escudo, equipo u objeto mágico.
class ApiItem {
  static const String magicPrefix = 'm:';

  final String index; // con prefijo "m:" si es mágico
  final String name;
  final String category; // categoría original en inglés
  final bool isMagic;
  final String rarity;
  final List<String> desc;
  final String cost;
  final double? weight;

  // Armas
  final String weaponCategory; // Simple / Martial
  final String weaponRange; // Melee / Ranged
  final String damageDice;
  final String damageType;
  final int? rangeNormal;
  final List<String> properties; // nombres en inglés

  // Armaduras y escudos
  final String armorCategory; // Light / Medium / Heavy / Shield
  final int? acBase;
  final bool acDexBonus;
  final int? acMaxBonus;
  final int strMinimum;
  final bool stealthDisadvantage;

  const ApiItem({
    required this.index,
    required this.name,
    this.category = '',
    this.isMagic = false,
    this.rarity = '',
    this.desc = const [],
    this.cost = '',
    this.weight,
    this.weaponCategory = '',
    this.weaponRange = '',
    this.damageDice = '',
    this.damageType = '',
    this.rangeNormal,
    this.properties = const [],
    this.armorCategory = '',
    this.acBase,
    this.acDexBonus = false,
    this.acMaxBonus,
    this.strMinimum = 0,
    this.stealthDisadvantage = false,
  });

  bool get isWeapon => damageDice.isNotEmpty;
  bool get isShield => armorCategory == 'Shield';
  bool get isArmor => acBase != null && !isShield;
  bool get isEquippable => isWeapon || isArmor || isShield;
  bool get isFinesse => properties.contains('Finesse');
  bool get isRanged => weaponRange == 'Ranged';

  static int? _int(dynamic v) => v is num ? v.toInt() : null;

  factory ApiItem.fromEquipment(Map<String, dynamic> m) {
    final dmg = m['damage'] as Map?;
    final ac = m['armor_class'] as Map?;
    final cost = m['cost'] as Map?;

    return ApiItem(
      index: (m['index'] ?? '').toString(),
      name: (m['name'] ?? '').toString(),
      category: ((m['equipment_category'] as Map?)?['name'] ?? '').toString(),
      desc: ((m['desc'] as List?) ?? const []).map((e) => e.toString()).toList(),
      cost: cost == null ? '' : '${cost['quantity']} ${cost['unit']}',
      weight: (m['weight'] as num?)?.toDouble(),
      weaponCategory: (m['weapon_category'] ?? '').toString(),
      weaponRange: (m['weapon_range'] ?? '').toString(),
      damageDice: (dmg?['damage_dice'] ?? '').toString(),
      damageType: ((dmg?['damage_type'] as Map?)?['name'] ?? '').toString(),
      rangeNormal: _int((m['range'] as Map?)?['normal']),
      properties: ((m['properties'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (e['name'] ?? '').toString())
          .toList(),
      armorCategory: (m['armor_category'] ?? '').toString(),
      acBase: ac == null ? null : _int(ac['base']),
      acDexBonus: ac?['dex_bonus'] == true,
      acMaxBonus: ac == null ? null : _int(ac['max_bonus']),
      strMinimum: _int(m['str_minimum']) ?? 0,
      stealthDisadvantage: m['stealth_disadvantage'] == true,
    );
  }

  factory ApiItem.fromMagic(Map<String, dynamic> m) => ApiItem(
        index: '$magicPrefix${m['index']}',
        name: (m['name'] ?? '').toString(),
        category: ((m['equipment_category'] as Map?)?['name'] ?? '').toString(),
        isMagic: true,
        rarity: ((m['rarity'] as Map?)?['name'] ?? '').toString(),
        desc: ((m['desc'] as List?) ?? const []).map((e) => e.toString()).toList(),
      );
}

/// Cliente de la D&D 5e SRD API para objetos y equipo. Nada se guarda en la
/// base de datos: solo los índices de los objetos que tiene cada personaje.
class EquipmentApiService {
  static const String _base = 'https://www.dnd5eapi.co/api/2014';

  /// Categorías que se pueden consultar: id -> nombre en español.
  static const Map<String, String> categories = {
    'weapon': 'Armas',
    'armor': 'Armaduras y escudos',
    'adventuring-gear': 'Equipo de aventurero',
    'tools': 'Herramientas',
    'magic': 'Objetos mágicos',
  };

  static final Map<String, List<ApiItemRef>> _listCache = {};
  static final Map<String, ApiItem> _itemCache = {};

  Future<dynamic> _getJson(String path) async {
    final res = await http
        .get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('La API respondió con el código ${res.statusCode}.');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Lista de objetos de una categoría (índice + nombre).
  Future<List<ApiItemRef>> fetchCategory(String category) async {
    final cached = _listCache[category];
    if (cached != null) return cached;

    final List<ApiItemRef> list;
    if (category == 'magic') {
      final data = await _getJson('/magic-items') as Map<String, dynamic>;
      list = ((data['results'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ApiItemRef(
                index: '${ApiItem.magicPrefix}${e['index']}',
                name: (e['name'] ?? '').toString(),
              ))
          .toList();
    } else {
      final data =
          await _getJson('/equipment-categories/$category') as Map<String, dynamic>;
      list = ((data['equipment'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ApiItemRef(
                index: (e['index'] ?? '').toString(),
                name: (e['name'] ?? '').toString(),
              ))
          .toList();
    }

    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return _listCache[category] = list;
  }

  ApiItem? cachedItem(String index) => _itemCache[index];

  Future<ApiItem> fetchItem(String index) async {
    final cached = _itemCache[index];
    if (cached != null) return cached;

    final ApiItem item;
    if (index.startsWith(ApiItem.magicPrefix)) {
      final id = index.substring(ApiItem.magicPrefix.length);
      final data = await _getJson('/magic-items/$id') as Map<String, dynamic>;
      item = ApiItem.fromMagic(data);
    } else {
      final data = await _getJson('/equipment/$index') as Map<String, dynamic>;
      item = ApiItem.fromEquipment(data);
    }
    return _itemCache[index] = item;
  }

  /// Carga varios objetos a la vez (los que fallen se omiten).
  Future<Map<String, ApiItem>> fetchItems(Iterable<String> indexes) async {
    final out = <String, ApiItem>{};
    await Future.wait(indexes.toSet().map((i) async {
      try {
        out[i] = await fetchItem(i);
      } catch (_) {}
    }));
    return out;
  }

  // ---------- Traducciones de términos frecuentes ----------

  static const Map<String, String> damageTypes = {
    'Slashing': 'cortante',
    'Piercing': 'perforante',
    'Bludgeoning': 'contundente',
    'Fire': 'fuego',
    'Cold': 'frío',
    'Lightning': 'rayo',
    'Poison': 'veneno',
    'Acid': 'ácido',
    'Necrotic': 'necrótico',
    'Radiant': 'radiante',
    'Force': 'fuerza',
    'Psychic': 'psíquico',
    'Thunder': 'trueno',
  };

  static const Map<String, String> properties = {
    'Ammunition': 'Munición',
    'Finesse': 'Sutil',
    'Heavy': 'Pesada',
    'Light': 'Ligera',
    'Loading': 'Carga',
    'Monk': 'Monje',
    'Range': 'Alcance',
    'Reach': 'Alcance largo',
    'Special': 'Especial',
    'Thrown': 'Arrojadiza',
    'Two-Handed': 'A dos manos',
    'Versatile': 'Versátil',
  };

  static const Map<String, String> armorCategories = {
    'Light': 'Ligera',
    'Medium': 'Media',
    'Heavy': 'Pesada',
    'Shield': 'Escudo',
  };

  static const Map<String, String> rarities = {
    'Common': 'Común',
    'Uncommon': 'Poco común',
    'Rare': 'Rara',
    'Very Rare': 'Muy rara',
    'Legendary': 'Legendaria',
    'Artifact': 'Artefacto',
    'Varies': 'Variable',
  };
}
