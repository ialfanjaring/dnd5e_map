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

  /// Terreno del primer piso: casilla ("x_y") -> id de terreno
  final Map<String, String> cells;

  /// Pisos superiores o inferiores (del segundo en adelante)
  final List<Map<String, String>> extraFloors;

  /// Nombre de cada escena (la primera incluida). Puede estar vacío.
  final List<String> floorNames;

  /// Tamaño de cada escena (columnas, filas). Si falta, [cols] × [rows].
  final List<({int cols, int rows})> floorSizes;
  final bool builtIn;

  ({int cols, int rows}) sizeOf(int i) =>
      i >= 0 && i < floorSizes.length ? floorSizes[i] : (cols: cols, rows: rows);

  /// Número de pisos (hojas) del mapa.
  int get floorCount => 1 + extraFloors.length;

  Map<String, String> floorCells(int i) => i == 0 ? cells : extraFloors[i - 1];

  String floorName(int i) =>
      i < floorNames.length && floorNames[i].trim().isNotEmpty
          ? floorNames[i]
          : 'Escena ${i + 1}';

  const MapTemplate({
    this.id,
    required this.name,
    this.description = '',
    required this.cols,
    required this.rows,
    required this.cells,
    this.extraFloors = const [],
    this.floorNames = const [],
    this.floorSizes = const [],
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
    List<Map<String, String>>? extraFloors,
    List<String>? floorNames,
    List<({int cols, int rows})>? floorSizes,
    bool? builtIn,
  }) =>
      MapTemplate(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        cols: cols ?? this.cols,
        rows: rows ?? this.rows,
        cells: cells ?? this.cells,
        extraFloors: extraFloors ?? this.extraFloors,
        floorNames: floorNames ?? this.floorNames,
        floorSizes: floorSizes ?? this.floorSizes,
        builtIn: builtIn ?? this.builtIn,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'cols': cols,
        'rows': rows,
        'cells': cells,
        'floorNames': floorNames,
        'floorSizes': [
          for (var i = 0; i < floorCount; i++)
            {'c': sizeOf(i).cols, 'r': sizeOf(i).rows},
        ],
        'upper': [
          for (final f in extraFloors) {'cells': f},
        ],
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
      floorNames: ((d['floorNames'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      floorSizes: [
        for (final f in ((d['floorSizes'] as List?) ?? const []).whereType<Map>())
          (
            cols: ((f['c'] ?? d['cols'] ?? 20) as num).toInt(),
            rows: ((f['r'] ?? d['rows'] ?? 14) as num).toInt(),
          ),
      ],
      extraFloors: [
        for (final f in ((d['upper'] as List?) ?? const []).whereType<Map>())
          {
            for (final e in ((f['cells'] as Map?) ?? const {}).entries)
              e.key.toString(): e.value.toString(),
          },
      ],
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

  MapTemplate build(
    String name,
    String description, {
    List<_Builder> upper = const [],
    List<String> floorNames = const [],
  }) =>
      MapTemplate(
        name: name,
        description: description,
        cols: cols,
        rows: rows,
        cells: Map.of(cells),
        extraFloors: [for (final u in upper) Map.of(u.cells)],
        floorNames: floorNames,
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
    _throneRoom(),
    _palaceGarden(),
    _palace(),
    _barn(),
  ];

  static MapTemplate _open() {
    final b = _Builder(20, 14);
    b.fill(0, 0, 20, 14, 'grass');
    // Algún camino de tierra y unas rocas para dar vida
    b.fill(0, 6, 20, 2, 'dirt');
    b.fill(9, 0, 2, 6, 'dirt');
    b.fill(9, 8, 2, 6, 'dirt');
    for (final p in [(3, 2), (15, 3), (5, 10), (16, 11)]) {
      b.put(p.$1, p.$2, 'rough');
    }
    return b.build('Llanura abierta', 'Campo de hierba con un cruce de caminos.');
  }

  static MapTemplate _dungeon() {
    final b = _Builder(24, 16);
    b.fill(0, 0, 24, 16, 'stone');
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
    // Puertas (en los huecos de los muros)
    b.put(8, 4, 'door');
    b.put(8, 12, 'door');
    b.put(16, 10, 'door');
    b.put(16, 3, 'door');
    b.put(4, 8, 'door');
    b.put(20, 6, 'door');
    // Sala noroeste: alfombra y pilares
    b.fill(2, 2, 5, 4, 'carpet');
    b.put(2, 1, 'pillar');
    b.put(6, 1, 'pillar');
    // Sala central: escombros
    b.fill(11, 6, 2, 3, 'rough');
    // Sala suroeste: escombros
    b.fill(2, 11, 3, 2, 'rough');
    // Sala sureste: estanque; sala noreste: brasero
    b.fill(19, 10, 3, 3, 'water');
    b.fill(19, 2, 2, 2, 'lava');
    // Pilares de la sala central
    b.put(11, 3, 'pillar');
    b.put(13, 3, 'pillar');
    b.put(11, 12, 'pillar');
    b.put(13, 12, 'pillar');
    return b.build('Mazmorra', 'Tres salas conectadas por puertas.');
  }

  static MapTemplate _tavern() {
    final b = _Builder(20, 14);
    // Hierba alrededor, edificio con suelo de madera
    b.fill(0, 0, 20, 14, 'grass');
    b.fill(2, 1, 16, 12, 'wood');
    b.box(2, 1, 16, 12, 'woodwall');
    b.put(10, 12, 'door'); // entrada
    b.put(2, 6, 'door'); // puerta lateral
    // Camino de tierra a la entrada
    b.fill(9, 13, 3, 1, 'dirt');
    // Barra
    b.fill(4, 2, 8, 1, 'furniture');
    // Alfombra central
    b.fill(7, 6, 6, 5, 'carpet');
    // Mesas (2x2): se camina alrededor
    for (final p in [(4, 5), (14, 5), (4, 9), (14, 9)]) {
      b.fill(p.$1, p.$2, 2, 2, 'furniture');
    }
    // Chimenea en la pared norte
    b.fill(15, 2, 2, 1, 'fire');
    b.put(14, 2, 'stone');
    b.put(17, 2, 'stone');
    return b.build('Taberna', 'Sala común con barra, mesas y chimenea.');
  }

  static MapTemplate _forestRiver() {
    final b = _Builder(28, 18);
    b.fill(0, 0, 28, 18, 'grass');
    // Bosque en las esquinas
    b.fill(0, 0, 8, 6, 'forest');
    b.fill(20, 0, 8, 5, 'forest');
    b.fill(0, 12, 7, 6, 'forest');
    b.fill(21, 13, 7, 5, 'forest');
    b.fill(15, 1, 3, 3, 'forest');
    // Río que baja en diagonal suave (3 casillas de ancho)
    for (var y = 0; y < 18; y++) {
      final x = 11 + (y ~/ 4);
      b.fill(x, y, 3, 1, 'water');
      // orillas de arena
      b.put(x - 1, y, 'sand');
      b.put(x + 3, y, 'sand');
    }
    // Puente de madera sobre el río (filas 8 y 9)
    for (var y = 8; y < 10; y++) {
      for (var x = 9; x < 19; x++) {
        final cur = b.cells[cellKey(x, y)];
        if (cur == 'water' || cur == 'sand') b.put(x, y, 'wood');
      }
    }
    // Camino de tierra a ambos lados del puente
    b.fill(3, 8, 6, 2, 'dirt');
    b.fill(19, 8, 6, 2, 'dirt');
    // Unas rocas y un vado de barro
    b.fill(24, 11, 2, 1, 'mud');
    b.put(5, 6, 'rough');
    return b.build('Bosque con río', 'Un río con un puente de madera y bosque alrededor.');
  }

  static MapTemplate _lavaCave() {
    final b = _Builder(24, 16);
    // Roca maciza alrededor
    b.fill(0, 0, 24, 16, 'wall');
    // Caverna: suelo de piedra con borde de escombros
    b.fill(2, 2, 20, 12, 'rough');
    b.fill(3, 3, 18, 10, 'stone');
    // Pilares
    for (final p in [(6, 5), (6, 10), (17, 5), (17, 10)]) {
      b.put(p.$1, p.$2, 'pillar');
    }
    // Lago de lava central con un pilar de roca
    b.fill(9, 8, 6, 3, 'lava');
    b.fill(10, 6, 4, 2, 'lava');
    b.put(11, 7, 'pillar');
    // Pozas de agua en un lateral
    b.fill(3, 3, 3, 2, 'water');
    // Entradas: túnel norte y sur
    b.fill(11, 0, 2, 3, 'stone');
    b.fill(11, 13, 2, 3, 'stone');
    return b.build('Cueva de lava', 'Caverna con lago de lava y pilares.');
  }

  static MapTemplate _ambush() {
    final b = _Builder(30, 12);
    b.fill(0, 0, 30, 12, 'grass');
    // Bosque a ambos lados del camino
    b.fill(0, 0, 30, 4, 'forest');
    b.fill(0, 8, 30, 4, 'forest');
    // Camino de tierra
    b.fill(0, 4, 30, 4, 'dirt');
    // Claros
    b.fill(6, 3, 3, 1, 'grass');
    b.fill(20, 8, 4, 1, 'grass');
    // Piedras en el camino
    for (final p in [(4, 5), (11, 7), (24, 4)]) {
      b.put(p.$1, p.$2, 'rough');
    }
    // Barricada de madera con un hueco de paso
    b.fill(14, 4, 1, 4, 'furniture');
    b.put(14, 5, 'dirt');
    b.put(14, 6, 'dirt');
    return b.build('Emboscada en el camino', 'Camino entre árboles con barricada.');
  }

  // ---------------------------------------------------------------
  // PALACIO Y PISOS
  // ---------------------------------------------------------------

  static MapTemplate _throneRoom() {
    final b = _Builder(30, 16);
    b.fill(0, 0, 30, 16, 'marble');
    b.box(0, 0, 30, 16, 'palacewall');
    // Alfombra real desde la entrada hasta el estrado
    b.fill(14, 4, 3, 11, 'royalcarpet');
    // Estrado con el trono
    b.fill(11, 1, 9, 3, 'carpet');
    b.put(15, 2, 'throne');
    b.put(11, 1, 'fire');
    b.put(19, 1, 'fire');
    // Columnas a ambos lados de la alfombra
    for (final y in [5, 8, 11]) {
      for (final x in [8, 22]) {
        b.put(x, y, 'column');
      }
    }
    // Estatuas junto a las paredes
    for (final y in [3, 7, 11]) {
      b.put(2, y, 'statue');
      b.put(27, y, 'statue');
    }
    // Puertas: entrada principal al sur y salidas laterales
    b.put(14, 15, 'door');
    b.put(15, 15, 'door');
    b.put(16, 15, 'door');
    b.put(0, 8, 'door');
    b.put(29, 8, 'door');
    return b.build('Sala del trono', 'Gran salón de mármol con estrado, columnas y alfombra real.');
  }

  static MapTemplate _palaceGarden() {
    final b = _Builder(28, 18);
    b.fill(0, 0, 28, 18, 'grass');
    // Seto exterior con puerta de reja al sur
    b.box(0, 0, 28, 18, 'hedge');
    b.put(13, 17, 'bars');
    b.put(14, 17, 'bars');
    b.put(13, 16, 'cobble');
    b.put(14, 16, 'cobble');
    // Caminos de adoquines en cruz y plaza central
    b.fill(13, 1, 2, 16, 'cobble');
    b.fill(1, 8, 26, 2, 'cobble');
    b.fill(10, 5, 8, 8, 'cobble');
    // Fuente central (2x2)
    b.fill(13, 8, 2, 2, 'fountain');
    // Estatuas en las esquinas de la plaza
    for (final p in [(10, 5), (17, 5), (10, 12), (17, 12)]) {
      b.put(p.$1, p.$2, 'statue');
    }
    // Parterres de flores en los cuadrantes
    b.fill(3, 3, 6, 3, 'flowers');
    b.fill(19, 3, 6, 3, 'flowers');
    b.fill(3, 12, 6, 3, 'flowers');
    b.fill(19, 12, 6, 3, 'flowers');
    // Setos del laberinto pequeño
    b.fill(3, 7, 1, 4, 'hedge');
    b.fill(24, 7, 1, 4, 'hedge');
    // Árboles
    for (final p in [(2, 2), (25, 2), (2, 15), (25, 15), (8, 9), (19, 9)]) {
      b.put(p.$1, p.$2, 'forest');
    }
    // Templete de mármol (noreste, fuera de los parterres)
    b.fill(21, 6, 5, 1, 'marble');
    return b.build('Jardín del palacio', 'Jardín con fuente, setos, parterres y estatuas.');
  }

  static MapTemplate _palace() {
    // Las escaleras están en las mismas casillas de cada piso para que
    // al usarlas la ficha aparezca justo en la escalera del otro piso.
    final basement = _Builder(30, 20);
    final ground = _Builder(30, 20);
    final upper = _Builder(30, 20);

    // ---------------- Sótano: mazmorra ----------------
    basement.fill(0, 0, 30, 20, 'stone');
    basement.box(0, 0, 30, 20, 'wall');
    // Celdas con rejas
    for (final x in [3, 9, 15]) {
      basement.box(x, 12, 5, 7, 'wall');
      basement.put(x + 2, 12, 'bars');
    }
    basement.fill(20, 12, 9, 7, 'water');
    basement.box(19, 11, 11, 9, 'wall');
    basement.put(19, 14, 'door');
    basement.fill(21, 13, 4, 3, 'water');
    basement.fill(26, 13, 2, 4, 'rough');
    basement.put(1, 1, 'fire');
    basement.put(28, 1, 'fire');
    basement.put(2, 2, 'stairsup'); // sube a la planta baja
    basement.put(27, 2, 'ladder'); // escalera de mano a las cocinas

    // ---------------- Planta baja: vestíbulo y salones ----------------
    ground.fill(0, 0, 30, 20, 'marble');
    ground.box(0, 0, 30, 20, 'palacewall');
    // Vestíbulo central con alfombra real
    ground.fill(14, 8, 3, 11, 'royalcarpet');
    // Ala de piedra: solo losas, sin adornos
    for (final x in [5, 9, 20, 24]) {
      ground.put(x, 8, 'column');
      ground.put(x, 11, 'column');
    }
    ground.put(14, 19, 'door');
    ground.put(15, 19, 'door');
    ground.put(16, 19, 'door');
    // Comedor (oeste): suelo de madera
    ground.fill(1, 1, 8, 5, 'wood');
    ground.box(0, 0, 10, 7, 'palacewall');
    ground.fill(3, 3, 4, 2, 'furniture');
    ground.put(5, 6, 'door');
    ground.put(2, 2, 'stairsboth'); // baja al sótano o sube a la planta noble
    // Cocinas (este)
    ground.fill(21, 1, 8, 5, 'stone');
    ground.box(20, 0, 10, 7, 'palacewall');
    ground.fill(22, 3, 4, 1, 'furniture');
    ground.put(24, 6, 'door');
    ground.put(28, 1, 'fire');
    ground.put(27, 2, 'stairsup'); // sube a la biblioteca
    // Patio con fuente (sur oeste)
    ground.fill(2, 13, 9, 5, 'cobble');
    ground.fill(5, 14, 2, 2, 'fountain');
    ground.put(11, 13, 'door');
    ground.put(2, 17, 'statue');
    ground.put(10, 17, 'statue');

    // ---------------- Planta noble: dormitorios y galería ----------------
    upper.fill(0, 0, 30, 20, 'marble');
    upper.box(0, 0, 30, 20, 'palacewall');
    // Galería central con barandilla
    upper.fill(11, 6, 8, 8, 'checker');
    upper.box(11, 6, 8, 8, 'bars');
    upper.put(14, 13, 'door');
    upper.put(15, 13, 'door');
    // Alcoba real (oeste)
    upper.fill(1, 1, 8, 5, 'wood');
    upper.box(0, 0, 10, 7, 'palacewall');
    upper.fill(3, 2, 2, 2, 'furniture'); // cama
    upper.put(5, 6, 'door');
    upper.put(2, 2, 'stairsdown'); // escalera principal: baja a la planta baja
    // Biblioteca (este)
    upper.fill(21, 1, 8, 5, 'wood');
    upper.box(20, 0, 10, 7, 'palacewall');
    upper.fill(22, 1, 6, 1, 'furniture');
    upper.put(24, 6, 'door');
    upper.put(27, 2, 'stairsdown');
    // Pasillo con alfombra
    for (final x in [4, 8, 12, 18, 22, 26]) {
      upper.put(x, 8, 'column');
    }
    // Balcón sur con vistas
    upper.fill(8, 16, 14, 3, 'marble');
    upper.fill(8, 16, 14, 1, 'bars');
    upper.put(14, 15, 'door');
    upper.put(15, 15, 'door');

    return ground.build(
      'Palacio (3 plantas)',
      'Sótano, planta baja y planta noble unidas por escaleras.',
      upper: [upper, basement],
      floorNames: ['Planta baja', 'Planta noble', 'Sótano'],
    );
  }

  static MapTemplate _barn() {
    final ground = _Builder(20, 14);
    final loft = _Builder(20, 14);

    // Planta baja: campo exterior y granero
    ground.fill(0, 0, 20, 14, 'grass');
    ground.fill(8, 12, 4, 2, 'dirt');
    ground.fill(3, 2, 14, 9, 'dirt');
    ground.box(3, 2, 14, 9, 'woodwall');
    ground.put(9, 10, 'door');
    ground.put(10, 10, 'door');
    ground.fill(5, 4, 2, 2, 'furniture'); // cajas
    ground.fill(12, 6, 3, 2, 'furniture'); // carro
    ground.put(5, 8, 'sand'); // paja
    ground.put(6, 8, 'sand');
    ground.put(14, 3, 'ladder'); // escalera de mano al altillo
    ground.put(4, 3, 'stairsup'); // escalera de madera al altillo
    ground.put(16, 12, 'forest');

    // Altillo: solo se ve la mitad norte del granero
    loft.fill(3, 2, 14, 5, 'wood');
    loft.box(3, 2, 14, 5, 'woodwall');
    loft.fill(4, 3, 3, 2, 'sand'); // heno
    loft.fill(11, 3, 3, 2, 'furniture');
    loft.fill(3, 6, 14, 1, 'bars'); // barandilla hacia el vacío
    loft.put(4, 3, 'stairsdown');
    loft.put(14, 3, 'ladder');
    return ground.build(
      'Granero con altillo',
      'Dos pisos unidos por una escalera de madera y una escalera de mano.',
      upper: [loft],
      floorNames: ['Planta baja', 'Altillo'],
    );
  }
}
