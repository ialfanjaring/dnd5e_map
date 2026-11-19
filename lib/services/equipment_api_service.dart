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

  /// Prefijo de los objetos creados por el Master ("c:<id>").
  static const String customPrefix = 'c:';

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

  /// Bonificador mágico (solo objetos propios): suma al ataque y al daño de
  /// las armas, o a la CA de armaduras y escudos.
  final int magicBonus;

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
    this.magicBonus = 0,
  });

  bool get isCustom => index.startsWith(customPrefix);

  /// Para guardar un objeto propio (los de la API nunca se guardan).
  Map<String, dynamic> toMap() => {
        'name': name,
        'category': category,
        'isMagic': isMagic,
        'rarity': rarity,
        'desc': desc,
        'cost': cost,
        'weight': weight,
        'weaponCategory': weaponCategory,
        'weaponRange': weaponRange,
        'damageDice': damageDice,
        'damageType': damageType,
        'rangeNormal': rangeNormal,
        'properties': properties,
        'armorCategory': armorCategory,
        'acBase': acBase,
        'acDexBonus': acDexBonus,
        'acMaxBonus': acMaxBonus,
        'strMinimum': strMinimum,
        'stealthDisadvantage': stealthDisadvantage,
        'magicBonus': magicBonus,
      };

  factory ApiItem.fromMap(String index, Map<String, dynamic> m) => ApiItem(
        index: index,
        name: _str(m['name']),
        category: _str(m['category']),
        isMagic: m['isMagic'] == true,
        rarity: _str(m['rarity']),
        desc: _strings(m['desc']),
        cost: _str(m['cost']),
        weight: m['weight'] is num ? (m['weight'] as num).toDouble() : null,
        weaponCategory: _str(m['weaponCategory']),
        weaponRange: _str(m['weaponRange']),
        damageDice: _str(m['damageDice']),
        damageType: _str(m['damageType']),
        rangeNormal: _int(m['rangeNormal']),
        properties: _strings(m['properties']),
        armorCategory: _str(m['armorCategory']),
        acBase: _int(m['acBase']),
        acDexBonus: m['acDexBonus'] == true,
        acMaxBonus: _int(m['acMaxBonus']),
        strMinimum: _int(m['strMinimum']) ?? 0,
        stealthDisadvantage: m['stealthDisadvantage'] == true,
        magicBonus: _int(m['magicBonus']) ?? 0,
      );

  /// Ranura en la que se puede tener activo: 'weapon', 'armor', 'shield' o ''.
  /// Los objetos mágicos de la API entran por su categoría, aunque no traigan
  /// estadísticas.
  String get slot {
    if (isWeapon) return 'weapon';
    if (isShield) return 'shield';
    if (isArmor) return 'armor';
    if (isMagic && category == 'Weapon') return 'weapon';
    if (isMagic && category == 'Armor') {
      return name.toLowerCase().contains('shield') ? 'shield' : 'armor';
    }
    return '';
  }

  bool get isWeapon => damageDice.isNotEmpty;
  bool get isShield => armorCategory == 'Shield';
  bool get isArmor => acBase != null && !isShield;
  bool get isEquippable => slot.isNotEmpty;
  bool get isFinesse => properties.contains('Finesse');
  bool get isRanged => weaponRange == 'Ranged';

  static int? _int(dynamic v) {
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static Map<String, dynamic> _map(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : const {};

  static String _str(dynamic v) => v == null ? '' : v.toString();

  static List<String> _strings(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  /// Nombres de una lista de referencias ({index, name}).
  static List<String> _names(dynamic v) => v is List
      ? v.map((e) => e is Map ? _str(e['name']) : _str(e)).toList()
      : const [];

  factory ApiItem.fromEquipment(Map<String, dynamic> m) {
    final dmg = _map(m['damage']);
    final ac = _map(m['armor_class']);
    final cost = _map(m['cost']);

    return ApiItem(
      index: _str(m['index']),
      name: _str(m['name']),
      category: _str(_map(m['equipment_category'])['name']),
      desc: _strings(m['desc']),
      cost: cost.isEmpty ? '' : '${_str(cost['quantity'])} ${_str(cost['unit'])}',
      weight: m['weight'] is num ? (m['weight'] as num).toDouble() : null,
      weaponCategory: _str(m['weapon_category']),
      weaponRange: _str(m['weapon_range']),
      damageDice: _str(dmg['damage_dice']),
      damageType: _str(_map(dmg['damage_type'])['name']),
      rangeNormal: _int(_map(m['range'])['normal']),
      properties: _names(m['properties']),
      armorCategory: _str(m['armor_category']),
      acBase: ac.isEmpty ? null : _int(ac['base']),
      acDexBonus: ac['dex_bonus'] == true,
      acMaxBonus: ac.isEmpty ? null : _int(ac['max_bonus']),
      strMinimum: _int(m['str_minimum']) ?? 0,
      stealthDisadvantage: m['stealth_disadvantage'] == true,
    );
  }

  factory ApiItem.fromMagic(Map<String, dynamic> m, {String? index}) {
    final name = _str(m['name']);
    final category = _str(_map(m['equipment_category'])['name']);

    // "Armor, +1", "Shield, +2", "Weapon, +3": el bono está en el nombre
    var bonus = 0;
    if (category == 'Armor' || category == 'Weapon') {
      final match = RegExp(r'\+(\d)').firstMatch(name);
      if (match != null && !name.contains(' or ')) {
        bonus = int.parse(match.group(1)!);
      }
    }

    return ApiItem(
      index: index ?? '$magicPrefix${_str(m['index'])}',
      name: name,
      category: category,
      isMagic: true,
      rarity: _str(_map(m['rarity'])['name']),
      desc: _strings(m['desc']),
      magicBonus: bonus,
    );
  }
}

/// La API no tiene ese recurso (404).
class ApiNotFound implements Exception {
  final String path;
  const ApiNotFound(this.path);

  @override
  String toString() => 'La API no tiene el recurso $path.';
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
    'custom': 'Mis objetos',
  };

  static final Map<String, List<ApiItemRef>> _listCache = {};
  static final Map<String, ApiItem> _itemCache = {};

  Future<dynamic> _getJson(String path) async {
    final res = await http
        .get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 404) throw ApiNotFound(path);
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

  // ---------- Objetos creados por el Master ----------

  /// Deja un objeto propio disponible en memoria (para mostrarlo y calcular).
  static void registerCustom(ApiItem item) => _itemCache[item.index] = item;

  /// Registra los objetos propios que lleva un personaje (copias guardadas
  /// en su ficha de la partida).
  static void registerCustomMap(Map<String, Map<String, dynamic>> data) {
    data.forEach((id, m) {
      final index = '${ApiItem.customPrefix}$id';
      _itemCache[index] = ApiItem.fromMap(index, m);
    });
  }

  /// Copia de los datos de los objetos propios de [indexes], para guardarlos
  /// en la ficha de quien los recibe.
  static Map<String, Map<String, dynamic>> customData(Iterable<String> indexes) {
    final out = <String, Map<String, dynamic>>{};
    for (final i in indexes) {
      if (!i.startsWith(ApiItem.customPrefix)) continue;
      final it = _itemCache[i];
      if (it != null) out[i.substring(ApiItem.customPrefix.length)] = it.toMap();
    }
    return out;
  }

  Future<ApiItem> fetchItem(String index) async {
    final cached = _itemCache[index];
    if (cached != null) return cached;

    final ApiItem item;
    if (index.startsWith(ApiItem.magicPrefix)) {
      final id = index.substring(ApiItem.magicPrefix.length);
      item = ApiItem.fromMagic(ApiItem._map(await _getJson('/magic-items/$id')));
    } else {
      ApiItem? found;
      try {
        found = ApiItem.fromEquipment(
          ApiItem._map(await _getJson('/equipment/$index')),
        );
      } on ApiNotFound {
        // Algunas categorías (armaduras, armas) incluyen objetos mágicos que
        // solo existen en /magic-items
        try {
          found = ApiItem.fromMagic(
            ApiItem._map(await _getJson('/magic-items/$index')),
            index: index,
          );
        } on ApiNotFound {
          found = null;
        }
      }
      if (found == null) {
        throw Exception('El objeto «$index» no existe en la API.');
      }
      item = found;
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
