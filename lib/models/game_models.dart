import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../i18n/i18n.dart';
import 'package:flutter/material.dart';

/// Clave de una casilla del mapa ("x_y").
String cellKey(int x, int y) => '${x}_$y';

/// Colores que se asignan a los usuarios de una partida (valores ARGB).
class GameColors {
  static const List<int> palette = [
    0xFF1E88E5, // azul
    0xFFE53935, // rojo
    0xFF43A047, // verde
    0xFFFB8C00, // naranja
    0xFF8E24AA, // morado
    0xFF00ACC1, // cian
    0xFFFDD835, // amarillo
    0xFFD81B60, // rosa
    0xFF6D4C41, // marrón
    0xFF546E7A, // gris azulado
    0xFF7CB342, // lima
    0xFF3949AB, // índigo
  ];

  /// Primer color de la paleta que todavía no está en uso.
  static int nextFree(Iterable<int> used) {
    final taken = used.toSet();
    for (final c in palette) {
      if (!taken.contains(c)) return c;
    }
    return palette[taken.length % palette.length];
  }
}

/// Regla de movimiento de una casilla.
enum MoveRule {
  /// Se camina con normalidad (5 pies por casilla)
  normal,

  /// Terreno difícil: cada casilla cuesta el doble
  difficult,

  /// No se puede cruzar ni colocar fichas (muros, pilares...)
  blocked,
}

/// Aspecto con el que se dibuja un terreno.
enum TerrainPattern {
  plain,
  grass,
  dirt,
  sand,
  snow,
  ice,
  mud,
  planks,
  tiles,
  cobble,
  carpet,
  rocks,
  waves,
  deepWaves,
  stoneWall,
  woodWall,
  pillar,
  trees,
  door,
  furniture,
  lava,
  fire,
  marble,
  checker,
  royalCarpet,
  palaceWall,
  column,
  throne,
  fountain,
  statue,
  hedge,
  flowers,
  bars,
  stairsUp,
  stairsDown,
  stairsBoth,
  ladder,
  teleport,
  chest,
}

/// Tipo de terreno que el Master puede pintar en el mapa.
class TerrainType {
  final String id;
  final String name;

  /// Grupo en el selector (suelos, naturaleza...)
  final String group;
  final int color;
  final IconData icon;
  final TerrainPattern pattern;

  /// Regla que trae por defecto (se puede cambiar casilla a casilla)
  final MoveRule move;

  const TerrainType(
    this.id,
    this.name,
    this.group,
    this.color,
    this.icon,
    this.pattern, [
    this.move = MoveRule.normal,
  ]);
}

/// Una casilla ya interpretada: terreno + regla de movimiento.
class CellInfo {
  final TerrainType? type;
  final MoveRule rule;
  const CellInfo(this.type, this.rule);

  /// La regla es distinta de la que trae el terreno (se marca en el mapa)
  bool get overridden => type != null && rule != type!.move;
}

class Terrains {
  static const String gSuelos = 'Suelos';
  static const String gNaturaleza = 'Naturaleza';
  static const String gConstruccion = 'Construcción';
  static const String gPalacio = 'Palacio';
  static const String gEscaleras = 'Escaleras y portales';
  static const String gPeligros = 'Peligros';

  static const List<String> groups = [
    gSuelos,
    gNaturaleza,
    gConstruccion,
    gPalacio,
    gEscaleras,
    gPeligros,
  ];

  static const List<TerrainType> all = [
    // Suelos
    TerrainType('stone', 'Suelo de piedra', gSuelos, 0xFF9E9E9E,
        Icons.grid_view, TerrainPattern.tiles),
    TerrainType('wood', 'Suelo de madera', gSuelos, 0xFFA1763F,
        Icons.view_headline, TerrainPattern.planks),
    TerrainType('cobble', 'Adoquines', gSuelos, 0xFF8D8D8D,
        Icons.blur_on, TerrainPattern.cobble),
    TerrainType('carpet', 'Alfombra', gSuelos, 0xFF9C2F3A,
        Icons.crop_square, TerrainPattern.carpet),
    TerrainType('dirt', 'Tierra', gSuelos, 0xFF8B6B47,
        Icons.grain, TerrainPattern.dirt),
    TerrainType('sand', 'Arena', gSuelos, 0xFFE6D08F,
        Icons.beach_access, TerrainPattern.sand),
    // Naturaleza
    TerrainType('grass', 'Hierba', gNaturaleza, 0xFF6DAA57,
        Icons.grass, TerrainPattern.grass),
    TerrainType('forest', 'Bosque', gNaturaleza, 0xFF3F7F3F,
        Icons.park, TerrainPattern.trees, MoveRule.difficult),
    TerrainType('snow', 'Nieve', gNaturaleza, 0xFFEAF3F8,
        Icons.ac_unit, TerrainPattern.snow, MoveRule.difficult),
    TerrainType('ice', 'Hielo', gNaturaleza, 0xFFBFE6F2,
        Icons.severe_cold, TerrainPattern.ice),
    TerrainType('mud', 'Barro', gNaturaleza, 0xFF6B5237,
        Icons.water_damage, TerrainPattern.mud, MoveRule.difficult),
    TerrainType('rough', 'Escombros', gNaturaleza, 0xFFA89F91,
        Icons.terrain, TerrainPattern.rocks, MoveRule.difficult),
    TerrainType('water', 'Agua', gNaturaleza, 0xFF4FA8D8,
        Icons.water_drop, TerrainPattern.waves, MoveRule.difficult),
    TerrainType('deepwater', 'Agua profunda', gNaturaleza, 0xFF1F5F9C,
        Icons.waves, TerrainPattern.deepWaves, MoveRule.blocked),
    // Construcción
    TerrainType('wall', 'Muro de piedra', gConstruccion, 0xFF566268,
        Icons.view_module, TerrainPattern.stoneWall, MoveRule.blocked),
    TerrainType('woodwall', 'Muro de madera', gConstruccion, 0xFF6B4A2B,
        Icons.fence, TerrainPattern.woodWall, MoveRule.blocked),
    TerrainType('pillar', 'Pilar', gConstruccion, 0xFF7A8084,
        Icons.circle, TerrainPattern.pillar, MoveRule.blocked),
    TerrainType('furniture', 'Mueble', gConstruccion, 0xFF7B5532,
        Icons.table_restaurant, TerrainPattern.furniture, MoveRule.blocked),
    TerrainType('door', 'Puerta', gConstruccion, 0xFF8D6E63,
        Icons.door_front_door, TerrainPattern.door),
    // Palacio
    TerrainType('marble', 'Losa de piedra', gPalacio, 0xFFC9C8CC,
        Icons.diamond_outlined, TerrainPattern.marble),
    TerrainType('checker', 'Suelo ajedrezado', gPalacio, 0xFFD9D9DD,
        Icons.grid_on, TerrainPattern.checker),
    TerrainType('royalcarpet', 'Alfombra granate', gPalacio, 0xFF7A1F2B,
        Icons.workspace_premium, TerrainPattern.royalCarpet),
    TerrainType('palacewall', 'Muro de palacio', gPalacio, 0xFF8F8F97,
        Icons.account_balance, TerrainPattern.palaceWall, MoveRule.blocked),
    TerrainType('column', 'Columna', gPalacio, 0xFFC9C8CC,
        Icons.view_column, TerrainPattern.column, MoveRule.blocked),
    TerrainType('throne', 'Trono', gPalacio, 0xFFC9C8CC,
        Icons.chair, TerrainPattern.throne, MoveRule.blocked),
    TerrainType('fountain', 'Fuente', gPalacio, 0xFFB4B4BA,
        Icons.water, TerrainPattern.fountain, MoveRule.blocked),
    TerrainType('statue', 'Estatua', gPalacio, 0xFFC9C8CC,
        Icons.emoji_events, TerrainPattern.statue, MoveRule.blocked),
    TerrainType('hedge', 'Seto', gPalacio, 0xFF2F6B35,
        Icons.grass, TerrainPattern.hedge, MoveRule.blocked),
    TerrainType('flowers', 'Parterre de flores', gPalacio, 0xFF7DB45F,
        Icons.local_florist, TerrainPattern.flowers, MoveRule.difficult),
    TerrainType('bars', 'Reja', gPalacio, 0xFF3A3A3F,
        Icons.border_vertical, TerrainPattern.bars, MoveRule.blocked),
    // Escaleras: al pisarlas se puede cambiar de piso
    TerrainType('stairsup', 'Escalera (sube)', gEscaleras, 0xFFB59A78,
        Icons.arrow_upward, TerrainPattern.stairsUp),
    TerrainType('stairsdown', 'Escalera (baja)', gEscaleras, 0xFFB59A78,
        Icons.arrow_downward, TerrainPattern.stairsDown),
    TerrainType('stairsboth', 'Escalera (sube y baja)', gEscaleras, 0xFFB59A78,
        Icons.swap_vert, TerrainPattern.stairsBoth),
    TerrainType('ladder', 'Escalera de mano', gEscaleras, 0xFF8D6E4C,
        Icons.format_line_spacing, TerrainPattern.ladder, MoveRule.difficult),
    TerrainType('teleport', 'Teletransportador', gEscaleras, 0xFF3D2C6B,
        Icons.blur_circular, TerrainPattern.teleport),
    // Objetos
    TerrainType('chest', 'Cofre / tesoro', gConstruccion, 0xFFB08D57,
        Icons.inventory_2, TerrainPattern.chest, MoveRule.blocked),
    // Peligros
    TerrainType('lava', 'Lava', gPeligros, 0xFFE8561C,
        Icons.local_fire_department, TerrainPattern.lava, MoveRule.difficult),
    TerrainType('fire', 'Fuego', gPeligros, 0xFF4A3B32,
        Icons.whatshot, TerrainPattern.fire, MoveRule.blocked),
  ];

  static TerrainType? byId(String id) {
    // Terrenos antiguos que ya no existen
    if (id == 'stairs' || id == 'spiral' || id == 'trapdoor') id = 'stairsboth';
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Valores de una casilla: "id" (regla por defecto del terreno) o
  /// "id+n" (libre), "id+d" (difícil), "id+b" (sin paso ni fichas).
  static CellInfo parse(String? value) {
    if (value == null || value.isEmpty) {
      return const CellInfo(null, MoveRule.normal);
    }
    final parts = _core(value).split('#').first.split('+');
    final t = byId(parts.first);
    var rule = t?.move ?? MoveRule.normal;
    if (parts.length > 1) {
      switch (parts[1]) {
        case 'n':
          rule = MoveRule.normal;
        case 'd':
          rule = MoveRule.difficult;
        case 'b':
          rule = MoveRule.blocked;
      }
    }
    return CellInfo(t, rule);
  }

  /// Casillas que llevan a otro punto: escaleras, escalera de mano,
  /// portales y puertas con número de conexión.
  static bool isLink(String? value) =>
      linkDirection(value) != null || _isNumberedDoor(value);

  /// Puerta con número de conexión: al entrar lleva a las otras puertas (o
  /// escaleras y portales) con el mismo número. Sin número es una puerta
  /// normal.
  static bool _isNumberedDoor(String? value) =>
      value != null &&
      value.isNotEmpty &&
      byId(idOf(value))?.pattern == TerrainPattern.door &&
      groupOf(value) != null;

  /// Hacia dónde se puede cambiar de piso: 1 = solo arriba, -1 = solo abajo,
  /// 0 = ambos; null si no es una escalera.
  static int? linkDirection(String? value) {
    if (value == null || value.isEmpty) return null;
    switch (byId(idOf(value))?.pattern) {
      case TerrainPattern.stairsUp:
        return 1;
      case TerrainPattern.stairsDown:
        return -1;
      case TerrainPattern.stairsBoth:
      case TerrainPattern.ladder:
      case TerrainPattern.teleport:
        return 0;
      default:
        return null;
    }
  }

  /// ¿Se puede ir de [from] a [to] desde esta casilla?
  static bool canChangeFloor(String? value, int from, int to) {
    final d = linkDirection(value);
    if (d == null || from == to) return false;
    return d == 0 || (d > 0 ? to > from : to < from);
  }

  /// Valor sin la zona ("stone+d#2@3" -> "stone+d#2").
  static String _core(String value) => value.split('@').first;

  static String idOf(String value) =>
      _core(value).split('#').first.split('+').first;

  /// Sufijo de la regla elegida: null = la del terreno.
  static String? flagOf(String value) {
    final p = _core(value).split('#').first.split('+');
    return p.length > 1 && p[1].isNotEmpty ? p[1] : null;
  }

  /// Número de grupo de una escalera o teletransportador ("id#3"): todas las
  /// casillas con el mismo número están conectadas. null = sin número.
  static int? groupOf(String? value) {
    if (value == null) return null;
    final v = _core(value);
    final i = v.indexOf('#');
    return i < 0 ? null : int.tryParse(v.substring(i + 1));
  }

  // ---- Zonas ----
  // Una casilla puede pertenecer a una zona (1-8), que el Master puede ocultar
  // a todos o a algunos jugadores. Se guarda al final del valor: "stone@3".
  // Una casilla sin terreno pero con zona es "@3". El pincel de zona es
  // "@3" (pintar la zona 3) o "@0" (quitar la zona).

  static const int zoneCount = 8;

  static const List<int> zoneColors = [
    0xFFE53935, 0xFF1E88E5, 0xFF43A047, 0xFFFDD835,
    0xFF8E24AA, 0xFFFB8C00, 0xFF00ACC1, 0xFF6D4C41,
  ];

  static int? zoneOf(String? value) {
    if (value == null) return null;
    final i = value.indexOf('@');
    if (i < 0) return null;
    final z = int.tryParse(value.substring(i + 1));
    return z == null || z <= 0 ? null : z;
  }

  static bool isZoneBrush(String? brush) => brush != null && brush.startsWith('@');

  /// Valor con la zona [zone] (null = sin zona). Devuelve null si no queda nada.
  static String? withZone(String? value, int? zone) {
    final core = value == null ? '' : _core(value);
    if (zone == null || zone <= 0) return core.isEmpty ? null : core;
    return '$core@$zone';
  }

  /// Resultado de pintar [brush] sobre una casilla con valor [current]:
  /// el terreno conserva la zona y la zona conserva el terreno.
  static String? applyBrush(String? current, String? brush) {
    if (brush == null) return null;
    if (isZoneBrush(brush)) {
      return withZone(current, int.tryParse(brush.substring(1)));
    }
    return withZone(brush, zoneOf(current));
  }

  /// true si el terreno admite número de grupo (escaleras, portales y
  /// puertas)
  static bool isLinkId(String id) =>
      linkDirection(id) != null || byId(id)?.pattern == TerrainPattern.door;

  static String encode(String id, String? flag, [int? group]) {
    final base = flag == null ? id : '$id+$flag';
    return group == null ? base : '$base#$group';
  }
}

/// Ficha colocada en el mapa: de un jugador o de una criatura del Master.
///
/// De las criaturas de la API solo se guarda el índice: el nombre se consulta
/// a la API cuando hace falta.
class GameToken {
  final String id;

  /// 'player' o 'creature'
  final String kind;

  /// uid del jugador, o id de la criatura de la partida
  final String refId;

  /// Índice del monstruo en la API (solo fichas de monstruos de la API)
  final String? apiIndex;

  /// Número de ejemplar (1, 2, 3...)
  final int number;

  /// Nombre personalizado (opcional)
  final String label;

  final int x;
  final int y;

  /// Las fichas ocultas solo las ve el Master.
  final bool hidden;

  /// Casillas que ocupa por lado (1 = normal, 2 = grande...)
  final int span;

  /// Piso en el que está la ficha (0 = el primero)
  final int floor;

  /// Imagen por defecto: 'npc' o el tipo de criatura (vacío = se deduce)
  final String icon;

  /// Salud restante de una criatura (0-100). Los jugadores solo ven la barra.
  final int hpPct;

  const GameToken({
    required this.id,
    required this.kind,
    required this.refId,
    this.apiIndex,
    this.number = 1,
    this.label = '',
    required this.x,
    required this.y,
    this.hidden = false,
    this.span = 1,
    this.floor = 0,
    this.icon = '',
    this.hpPct = 100,
  });

  bool get isPlayer => kind == 'player';

  bool covers(int cx, int cy) =>
      cx >= x && cx < x + span && cy >= y && cy < y + span;

  factory GameToken.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return GameToken(
      id: doc.id,
      kind: (d['kind'] ?? 'creature') as String,
      refId: (d['refId'] ?? '') as String,
      apiIndex: d['apiIndex'] as String?,
      number: ((d['number'] ?? 1) as num).toInt(),
      label: (d['label'] ?? '') as String,
      x: ((d['x'] ?? 0) as num).toInt(),
      y: ((d['y'] ?? 0) as num).toInt(),
      hidden: (d['hidden'] ?? false) as bool,
      span: ((d['span'] ?? 1) as num).toInt().clamp(1, 4).toInt(),
      floor: ((d['floor'] ?? 0) as num).toInt(),
      icon: (d['icon'] ?? '') as String,
      hpPct: ((d['hpPct'] ?? 100) as num).toInt().clamp(0, 100).toInt(),
    );
  }
}

/// Un grupo de dados dentro de una tirada compuesta: por ejemplo el d20 de
/// ataque, los dados de daño cortante o los de daño de hielo, cada uno con
/// su propio modificador.
class DiceGroup {
  /// Tipos de grupo que se pueden elegir. 'Ataque' es la tirada para
  /// acertar y no cuenta en el daño total.
  static const List<String> kinds = [
    'Ataque',
    'Cortante',
    'Perforante',
    'Contundente',
    'Fuego',
    'Hielo',
    'Rayo',
    'Trueno',
    'Ácido',
    'Veneno',
    'Necrótico',
    'Radiante',
    'Psíquico',
    'Fuerza',
    'Otro',
  ];

  /// Color asociado a cada tipo (para teñir los dados).
  static int colorOf(String kind) => switch (kind) {
        'Ataque' => 0xFFE9C46A,
        'Cortante' => 0xFFB0B7C3,
        'Perforante' => 0xFF9AA5B1,
        'Contundente' => 0xFFA1887F,
        'Fuego' => 0xFFFF7043,
        'Hielo' => 0xFF4FC3F7,
        'Rayo' => 0xFFFFEE58,
        'Trueno' => 0xFF7986CB,
        'Ácido' => 0xFF9CCC65,
        'Veneno' => 0xFF43A047,
        'Necrótico' => 0xFF8E6BB5,
        'Radiante' => 0xFFFFD54F,
        'Psíquico' => 0xFFF06292,
        'Fuerza' => 0xFF78909C,
        _ => 0xFFE9C46A,
      };

  final String die;
  final String label;
  final int mod;
  final String mode; // 'normal', 'adv', 'dis'
  final int chosen;
  final List<int> values;

  const DiceGroup({
    required this.die,
    required this.values,
    this.label = '',
    this.mod = 0,
    this.mode = 'normal',
    this.chosen = 0,
  });

  bool get isAttack => label == 'Ataque';
  bool get hasMode => (mode == 'adv' || mode == 'dis') && values.length == 2;
  bool get isAdv => mode == 'adv' && values.length == 2;
  int get tint => colorOf(label);

  /// Suma de los dados (o el que cuenta con ventaja/desventaja) + modificador.
  int get subtotal =>
      (hasMode ? values[chosen == 1 ? 1 : 0] : values.fold(0, (a, b) => a + b)) +
      mod;

  /// "d20+5", "2d6+3", "d8"
  String get formula {
    final n = hasMode ? 1 : values.length;
    final m = mod == 0 ? '' : (mod > 0 ? '+$mod' : '$mod');
    return '${n > 1 ? n : ''}$die$m';
  }

  Map<String, dynamic> toMap() => {
        'die': die,
        'label': label,
        'mod': mod,
        'mode': mode,
        'chosen': chosen,
        'values': values,
      };

  factory DiceGroup.fromMap(Map<String, dynamic> m) => DiceGroup(
        die: (m['die'] ?? 'd20') as String,
        label: (m['label'] ?? '') as String,
        mod: ((m['mod'] ?? 0) as num).toInt(),
        mode: (m['mode'] ?? 'normal') as String,
        chosen: ((m['chosen'] ?? 0) as num).toInt(),
        values: ((m['values'] as List?) ?? const [])
            .map((e) => (e as num).toInt())
            .toList(),
      );
}

/// Tirada de dados o de moneda.
class DiceRoll {
  /// Dados disponibles, en el orden en que se muestran.
  static const List<String> dice = [
    'coin',
    'd4',
    'd6',
    'd8',
    'd10',
    'd12',
    'd20',
    'd100',
  ];

  final String id;
  final String uid;
  final String name;
  final int color;

  /// 'coin', 'd4', 'd6', 'd8', 'd10', 'd12', 'd20' o 'd100'
  final String die;

  /// Resultado de cada dado (en la moneda: 1 = cara, 2 = cruz)
  final List<int> values;

  /// true si es una tirada oculta (solo la ve quien la hace)
  final bool hidden;
  final DateTime? at;

  /// 'normal', 'adv' (ventaja) o 'dis' (desventaja). En ventaja y
  /// desventaja hay dos valores y [chosen] indica el que cuenta.
  final String mode;
  final int chosen;

  /// Tirada compuesta (die == 'mix'): varios grupos de dados, cada uno con
  /// su tipo y su modificador. Vacío en una tirada normal.
  final List<DiceGroup> groups;

  /// Nombre de la tirada compuesta ("Espada de hielo"), opcional.
  final String title;

  const DiceRoll({
    this.id = '',
    required this.uid,
    required this.name,
    required this.color,
    required this.die,
    required this.values,
    this.hidden = false,
    this.at,
    this.mode = 'normal',
    this.chosen = 0,
    this.groups = const [],
    this.title = '',
  });

  bool get isMix => groups.isNotEmpty;

  /// Los grupos de la tirada; una tirada simple cuenta como un solo grupo.
  List<DiceGroup> get asGroups => isMix
      ? groups
      : [DiceGroup(die: die, values: values, mode: mode, chosen: chosen)];

  /// Daño total: suma de todos los grupos que no son de ataque.
  int get damageTotal =>
      groups.where((g) => !g.isAttack).fold(0, (a, g) => a + g.subtotal);

  bool get isAdv => mode == 'adv' && values.length == 2;
  bool get isDis => mode == 'dis' && values.length == 2;
  bool get hasMode => isAdv || isDis;

  /// Índice del valor que cuenta en una tirada con ventaja o desventaja.
  static int pickIndex(String mode, List<int> v) {
    if (v.length != 2) return 0;
    if (mode == 'adv') return v[1] > v[0] ? 1 : 0;
    if (mode == 'dis') return v[1] < v[0] ? 1 : 0;
    return 0;
  }

  static int sides(String die) =>
      die == 'coin' ? 2 : (int.tryParse(die.substring(1)) ?? 20);

  static String dieName(String die) => die == 'coin' ? tr('Moneda') : die.toUpperCase();

  static List<int> roll(String die, int count, Random rnd) {
    final s = sides(die);
    return List.generate(count, (_) => rnd.nextInt(s) + 1);
  }

  int get total => isMix
      ? (groups.any((g) => !g.isAttack) ? damageTotal : groups.first.subtotal)
      : hasMode
      ? values[chosen == 1 ? 1 : 0]
      : values.fold(0, (a, b) => a + b);

  /// "d20", "3d6", "Moneda", "2 monedas"
  String get label {
    if (isMix) {
      return title.isNotEmpty ? title : groups.map((g) => g.formula).join(' + ');
    }
    if (die == 'coin') {
      return values.length > 1 ? '${values.length} ${tr('monedas')}' : tr('Moneda');
    }
    if (hasMode) return '$die ${isAdv ? 'con ventaja' : 'con desventaja'}';
    return values.length > 1 ? '${values.length}$die' : die;
  }

  /// Resultado en texto: "17", "4 + 2 + 6 = 12" o "Cara".
  String get resultText {
    if (isMix) {
      final parts = groups
          .map((g) => '${g.label.isEmpty ? g.die : g.label} ${g.subtotal}')
          .join(' · ');
      return groups.any((g) => !g.isAttack) && groups.any((g) => g.isAttack)
          ? '$parts · daño $damageTotal'
          : parts;
    }
    if (die == 'coin') {
      return values.map((v) => v == 1 ? 'Cara' : 'Cruz').join(', ');
    }
    if (values.length == 1) return '${values.first}';
    if (hasMode) return '${values[0]} / ${values[1]} → $total';
    return '${values.join(' + ')} = $total';
  }

  /// Resultado corto para destacar: el total, o cara/cruz.
  String get headline {
    if (die == 'coin') {
      return values.length == 1
          ? (values.first == 1 ? 'Cara' : 'Cruz')
          : '${values.where((v) => v == 1).length} caras';
    }
    return '$total';
  }

  factory DiceRoll.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DiceRoll(
      id: doc.id,
      uid: (d['uid'] ?? '') as String,
      name: (d['name'] ?? '') as String,
      color: ((d['color'] ?? GameColors.palette.first) as num).toInt(),
      die: (d['die'] ?? 'd20') as String,
      values: ((d['values'] as List?) ?? const [])
          .map((e) => (e as num).toInt())
          .toList(),
      at: (d['at'] as Timestamp?)?.toDate(),
      mode: (d['mode'] ?? 'normal') as String,
      chosen: ((d['chosen'] ?? 0) as num).toInt(),
      title: (d['title'] ?? '') as String,
      groups: ((d['groups'] as List?) ?? const [])
          .map((e) => DiceGroup.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }
}

/// Escenas de una partida o de un mapa guardado (antes «pisos»): cada una es
/// un mapa distinto, con su propio tamaño, que se puede ocultar a los
/// jugadores. Se conectan con escaleras, portales o puertas con número.
class Scenes {
  Scenes._();

  static const int maxScenes = 8;

  /// Tamaño de la escena [i] de una partida. Si no tiene uno propio, el
  /// general de la partida ('cols' y 'rows').
  static ({int cols, int rows}) sizeOf(Map<String, dynamic> game, int i) {
    final cols = ((game['cols'] ?? 20) as num).toInt();
    final rows = ((game['rows'] ?? 14) as num).toInt();
    final raw = game['floorSizes'];
    if (raw is List && i >= 0 && i < raw.length && raw[i] is Map) {
      final m = raw[i] as Map;
      return (
        cols: ((m['c'] ?? cols) as num).toInt(),
        rows: ((m['r'] ?? rows) as num).toInt(),
      );
    }
    return (cols: cols, rows: rows);
  }

  /// Lista de tamaños para guardar en la partida ('floorSizes').
  static List<Map<String, int>> sizesOf(Map<String, dynamic> game, int count) => [
        for (var i = 0; i < count; i++)
          {'c': sizeOf(game, i).cols, 'r': sizeOf(game, i).rows},
      ];

  /// Escenas ocultas a los jugadores.
  static Set<int> hiddenOf(Map<String, dynamic> game) {
    final raw = game['hiddenFloors'];
    if (raw is! List) return const {};
    return {for (final e in raw) if (e is num) e.toInt()};
  }

  /// Nombre para mostrar: los antiguos «Piso N» se muestran como «Escena N».
  static String label(String name) {
    final m = RegExp(r'^(Piso|Escena) (\d+)$').firstMatch(name.trim());
    if (m != null) return '${tr('Escena')} ${m.group(2)}';
    return name;
  }
}
