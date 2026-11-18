import 'package:cloud_firestore/cloud_firestore.dart';

import 'game_models.dart';

/// Plantilla de mapa: tamaño y terreno. Los predeterminados se generan en
/// código (no se guardan en la base de datos); los del Master sí se guardan,
/// solo en su cuenta.
class MapTemplate {
  /// null en los mapas predeterminados y en los todavía no guardados
  final String? id;
  final String name;
  final String description;
  final int cols;
  final int rows;

  /// casilla ("x_y") -> id de terreno
  final Map<String, String> cells;
  final bool builtIn;

  const MapTemplate({
    this.id,
    required this.name,
    this.description = '',
    required this.cols,
    required this.rows,
    required this.cells,
    this.builtIn = false,
  });

  static const int minSize = 5;
  static const int maxCols = 40;
  static const int maxRows = 30;

  MapTemplate copyWith({
    String? id,
    String? name,
    String? description,
    int? cols,
    int? rows,
    Map<String, String>? cells,
    bool? builtIn,
  }) =>
      MapTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        cols: cols ?? this.cols,
        rows: rows ?? this.rows,
        cells: cells ?? this.cells,
        builtIn: builtIn ?? this.builtIn,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'cols': cols,
        'rows': rows,
        'cells': cells,
      };

  factory MapTemplate.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final raw = (d['cells'] as Map?) ?? {};
    return MapTemplate(
      id: doc.id,
      name: (d['name'] ?? 'Mapa') as String,
      description: (d['description'] ?? '') as String,
      cols: ((d['cols'] ?? 20) as num).toInt(),
      rows: ((d['rows'] ?? 14) as num).toInt(),
      cells: {
        for (final e in raw.entries) e.key.toString(): e.value.toString(),
      },
    );
  }
}

/// Constructor sencillo para dibujar los mapas predeterminados.
class _Builder {
  final int cols;
  final int rows;
  final Map<String, String> cells = {};

  _Builder(this.cols, this.rows);

  void put(int x, int y, String type) {
    if (x < 0 || y < 0 || x >= cols || y >= rows) return;
    cells[cellKey(x, y)] = type;
  }

  void clear(int x, int y) => cells.remove(cellKey(x, y));

  void fill(int x, int y, int w, int h, String type) {
    for (var j = y; j < y + h; j++) {
      for (var i = x; i < x + w; i++) {
        put(i, j, type);
      }
    }
  }

  /// Contorno de un rectángulo.
  void box(int x, int y, int w, int h, String type) {
    for (var i = x; i < x + w; i++) {
      put(i, y, type);
      put(i, y + h - 1, type);
    }
    for (var j = y; j < y + h; j++) {
      put(x, j, type);
      put(x + w - 1, j, type);
    }
  }

  MapTemplate build(String name, String description) => MapTemplate(
        name: name,
        description: description,
        cols: cols,
        rows: rows,
        cells: Map.of(cells),
        builtIn: true,
      );
}

/// Mapas predeterminados.
class DefaultMaps {
  static final List<MapTemplate> all = [
    _open(),
    _dungeon(),
    _tavern(),
    _forestRiver(),
    _lavaCave(),
    _ambush(),
  ];

  static MapTemplate _open() => _Builder(20, 14)
      .build('Llanura abierta', 'Cuadrícula vacía para improvisar.');

  static MapTemplate _dungeon() {
    final b = _Builder(24, 16);
    b.box(0, 0, 24, 16, 'wall');
    // Muros interiores
    for (var y = 1; y < 15; y++) {
      b.put(8, y, 'wall');
      b.put(16, y, 'wall');
    }
    for (var x = 1; x < 8; x++) {
      b.put(x, 8, 'wall');
    }
    for (var x = 17; x < 23; x++) {
      b.put(x, 6, 'wall');
    }
    // Puertas
    b.put(8, 4, 'door');
    b.put(8, 12, 'door');
    b.put(16, 10, 'door');
    b.put(16, 3, 'door');
    b.put(4, 8, 'door');
    b.put(20, 6, 'door');
    // Escombros y trampa
    b.fill(11, 6, 2, 3, 'rough');
    b.fill(2, 11, 3, 2, 'rough');
    b.fill(19, 11, 3, 3, 'water');
    b.fill(19, 2, 2, 2, 'lava');
    return b.build('Mazmorra', 'Tres salas conectadas por puertas.');
  }

  static MapTemplate _tavern() {
    final b = _Builder(20, 14);
    b.box(2, 1, 16, 12, 'wall');
    b.put(10, 12, 'door'); // entrada
    b.put(2, 6, 'door'); // puerta lateral
    // Barra
    b.fill(4, 2, 8, 1, 'rough');
    // Mesas
    for (final p in [(5, 5), (9, 5), (13, 5), (5, 9), (9, 9), (14, 9)]) {
      b.fill(p.$1, p.$2, 2, 2, 'rough');
    }
    // Chimenea
    b.fill(15, 2, 2, 1, 'lava');
    return b.build('Taberna', 'Sala común con barra, mesas y chimenea.');
  }

  static MapTemplate _forestRiver() {
    final b = _Builder(28, 18);
    // Bosque
    b.fill(0, 0, 8, 6, 'forest');
    b.fill(20, 0, 8, 5, 'forest');
    b.fill(0, 12, 7, 6, 'forest');
    b.fill(21, 13, 7, 5, 'forest');
    b.fill(12, 1, 3, 3, 'forest');
    // Río en diagonal suave
    for (var y = 0; y < 18; y++) {
      final x = 11 + (y ~/ 4);
      b.fill(x, y, 3, 1, 'water');
    }
    // Puente: casillas sin agua
    for (var x = 9; x < 19; x++) {
      for (var y = 8; y < 10; y++) {
        b.clear(x, y);
      }
    }
    b.fill(8, 8, 1, 2, 'rough');
    b.fill(19, 8, 1, 2, 'rough');
    return b.build('Bosque con río', 'Un río con un puente y bosque alrededor.');
  }

  static MapTemplate _lavaCave() {
    final b = _Builder(24, 16);
    b.fill(0, 0, 24, 16, 'wall');
    // Caverna vaciada
    b.fill(2, 2, 20, 12, 'rough');
    b.fill(3, 3, 18, 10, 'wall');
    for (var y = 3; y < 13; y++) {
      for (var x = 3; x < 21; x++) {
        b.clear(x, y);
      }
    }
    // Pilares
    for (final p in [(6, 5), (6, 10), (17, 5), (17, 10), (11, 7)]) {
      b.put(p.$1, p.$2, 'wall');
    }
    // Lago de lava central
    b.fill(9, 8, 6, 3, 'lava');
    b.fill(10, 6, 4, 2, 'lava');
    // Agua en un lateral
    b.fill(3, 3, 3, 2, 'water');
    b.clear(11, 7);
    b.put(11, 7, 'wall');
    return b.build('Cueva de lava', 'Caverna con lago de lava y pilares.');
  }

  static MapTemplate _ambush() {
    final b = _Builder(30, 12);
    // Camino libre en el centro, bosque a los lados
    b.fill(0, 0, 30, 4, 'forest');
    b.fill(0, 8, 30, 4, 'forest');
    // Claros
    b.fill(6, 2, 3, 2, 'rough');
    b.fill(20, 8, 4, 2, 'rough');
    b.fill(13, 3, 2, 1, 'rough');
    // Barricada
    b.fill(14, 4, 1, 4, 'wall');
    b.clear(14, 5);
    b.clear(14, 6);
    b.put(14, 5, 'door');
    return b.build('Emboscada en el camino', 'Camino entre árboles con barricada.');
  }
}
