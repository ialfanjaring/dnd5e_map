import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
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

/// Tipo de terreno que el Master puede pintar en el mapa.
class TerrainType {
  final String id;
  final String name;
  final int color;
  final IconData icon;

  const TerrainType(this.id, this.name, this.color, this.icon);
}

class Terrains {
  static const List<TerrainType> all = [
    TerrainType('wall', 'Muro', 0xFF455A64, Icons.square),
    TerrainType('water', 'Agua', 0xFF4FC3F7, Icons.water_drop),
    TerrainType('forest', 'Bosque', 0xFF66BB6A, Icons.park),
    TerrainType('rough', 'Terreno difícil', 0xFFBCAAA4, Icons.terrain),
    TerrainType('door', 'Puerta', 0xFF8D6E63, Icons.door_front_door),
    TerrainType('lava', 'Lava', 0xFFFF7043, Icons.local_fire_department),
  ];

  static TerrainType? byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
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

  /// Imagen por defecto: 'npc' o el tipo de criatura (vacío = se deduce)
  final String icon;

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
    this.icon = '',
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
      icon: (d['icon'] ?? '') as String,
    );
  }
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

  const DiceRoll({
    this.id = '',
    required this.uid,
    required this.name,
    required this.color,
    required this.die,
    required this.values,
    this.hidden = false,
    this.at,
  });

  static int sides(String die) => die == 'coin' ? 2 : int.parse(die.substring(1));

  static String dieName(String die) => die == 'coin' ? 'Moneda' : die.toUpperCase();

  static List<int> roll(String die, int count, Random rnd) {
    final s = sides(die);
    return List.generate(count, (_) => rnd.nextInt(s) + 1);
  }

  int get total => values.fold(0, (a, b) => a + b);

  /// "d20", "3d6", "Moneda", "2 monedas"
  String get label {
    if (die == 'coin') {
      return values.length > 1 ? '${values.length} monedas' : 'Moneda';
    }
    return values.length > 1 ? '${values.length}$die' : die;
  }

  /// Resultado en texto: "17", "4 + 2 + 6 = 12" o "Cara".
  String get resultText {
    if (die == 'coin') {
      return values.map((v) => v == 1 ? 'Cara' : 'Cruz').join(', ');
    }
    if (values.length == 1) return '${values.first}';
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
    );
  }
}
