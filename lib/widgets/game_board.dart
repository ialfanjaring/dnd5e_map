import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import 'terrain_painter.dart';
import 'death_saves_card.dart';

/// Mapa de cuadrículas con terreno y fichas. Siempre está encajado y centrado:
/// no admite zoom ni desplazamiento.
class GameBoard extends StatefulWidget {
  final int cols;
  final int rows;
  final Map<String, String> terrain;
  final List<GameToken> tokens;
  final String? selectedId;
  final Color Function(GameToken token) colorOf;

  /// Segundo color (dibujo y borde); null = automático
  final Color? Function(GameToken token)? color2Of;

  /// Borde de color que distingue a criaturas iguales
  final Color? Function(GameToken token)? ringOf;

  /// Estado vital: 0 normal, 1 inconsciente (0 PG), 2 muerto
  final int Function(GameToken token)? vitalOf;
  final String Function(GameToken token) nameOf;

  /// Imagen por defecto de la ficha (según clase, NPC o tipo de monstruo)
  final IconData Function(GameToken token)? iconOf;

  /// true: arrastrar pinta casillas (sin zoom ni desplazamiento)
  final bool paintMode;

  /// Al cambiar este número, el mapa se encaja en pantalla.
  final int fitSignal;

  final void Function(int x, int y) onCellTap;
  final void Function(int x, int y) onCellPaint;

  /// Casillas ("x_y") a las que puede llegar la ficha seleccionada (sombreadas)
  final Set<String> reachable;

  /// Fichas que tienen el turno de iniciativa (se resaltan; varias si es un grupo)
  final Set<String> turnIds;

  /// Casilla elegida como destino mientras se confirma el movimiento
  /// (x, y y tamaño de la ficha); se dibuja como un punto.
  final ({int x, int y, int span})? marker;

  /// Movimiento dibujado: arrastrar desde la ficha traza el recorrido casilla
  /// a casilla. null = desactivado.
  final void Function(int x, int y)? onPathStart;
  final void Function(int x, int y)? onPathExtend;
  final VoidCallback? onPathEnd;

  /// Recorrido que se está dibujando (casillas) y su texto ("15/30 pies")
  final List<({int x, int y})> path;
  final String pathLabel;

  /// true: el recorrido supera el movimiento que queda (se pinta en rojo)
  final bool pathOver;

  /// Recorridos que están dibujando los demás (en directo)
  final List<({List<({int x, int y})> cells, String label, bool over})> otherPaths;

  /// Marcas de los jugadores en casillas (atacar, mover…)
  final List<CellPing> pings;

  /// Mantener pulsada una casilla (para marcarla)
  final void Function(int x, int y)? onCellLongPress;

  /// Se dibujan las zonas (Master y editor de mapas)
  final bool showZones;

  /// Casillas ocultas por niebla (zonas que el jugador no ve)
  final Set<String> fogged;

  /// Parte del mapa que se encaja en pantalla (null = todo)
  final ({int x0, int y0, int x1, int y1})? viewRect;

  const GameBoard({
    super.key,
    required this.cols,
    required this.rows,
    required this.terrain,
    required this.tokens,
    required this.selectedId,
    required this.colorOf,
    this.color2Of,
    this.ringOf,
    this.vitalOf,
    required this.nameOf,
    this.iconOf,
    required this.paintMode,
    required this.fitSignal,
    required this.onCellTap,
    required this.onCellPaint,
    this.reachable = const {},
    this.turnIds = const {},
    this.marker,
    this.onPathStart,
    this.onPathExtend,
    this.onPathEnd,
    this.path = const [],
    this.pathLabel = '',
    this.pathOver = false,
    this.otherPaths = const [],
    this.pings = const [],
    this.onCellLongPress,
    this.showZones = false,
    this.fogged = const {},
    this.viewRect,
  });

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  static const double cell = 48;

  final TransformationController _controller = TransformationController();
  Size? _viewport;
  bool _fitted = false;
  String? _lastPaintedCell;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GameBoard old) {
    super.didUpdateWidget(old);
    if (old.fitSignal != widget.fitSignal ||
        old.cols != widget.cols ||
        old.rows != widget.rows ||
        old.viewRect != widget.viewRect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
  }

  void _fit() {
    final vp = _viewport;
    if (vp == null || vp.width <= 0 || vp.height <= 0) return;

    final vr = widget.viewRect;
    final ox = (vr?.x0 ?? 0) * cell;
    final oy = (vr?.y0 ?? 0) * cell;
    final w = vr == null ? widget.cols * cell : (vr.x1 - vr.x0 + 1) * cell;
    final h = vr == null ? widget.rows * cell : (vr.y1 - vr.y0 + 1) * cell;

    // Margen alrededor para que el mapa no quede pegado a los bordes
    const margin = 16.0;
    final availW = max(1.0, vp.width - margin * 2);
    final availH = max(1.0, vp.height - margin * 2);
    final scale = min(availW / w, availH / h).clamp(0.1, 2.0).toDouble();

    // Centrado en el visor
    final dx = (vp.width - w * scale) / 2 - ox * scale;
    final dy = (vp.height - h * scale) / 2 - oy * scale;

    _controller.value = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(scale, scale, 1.0);
  }

  ({int x, int y})? _cellAt(Offset p) {
    final x = (p.dx / cell).floor();
    final y = (p.dy / cell).floor();
    if (x < 0 || y < 0 || x >= widget.cols || y >= widget.rows) return null;
    return (x: x, y: y);
  }

  void _tap(Offset p) {
    final c = _cellAt(p);
    if (c == null) return;

    if (widget.paintMode) {
      widget.onCellPaint(c.x, c.y);
    } else {
      widget.onCellTap(c.x, c.y);
    }
  }

  ({int x, int y})? _lastPathCell;

  void _pathStart(Offset p) {
    final c = _cellAt(p);
    if (c == null) return;
    _lastPathCell = c;
    widget.onPathStart?.call(c.x, c.y);
  }

  void _pathUpdate(Offset p) {
    final c = _cellAt(p);
    if (c == null || c == _lastPathCell) return;
    _lastPathCell = c;
    widget.onPathExtend?.call(c.x, c.y);
  }

  void _paint(Offset p) {
    final c = _cellAt(p);
    if (c == null) return;

    final key = cellKey(c.x, c.y);
    if (key == _lastPaintedCell) return;
    _lastPaintedCell = key;

    widget.onCellPaint(c.x, c.y);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.cols * cell;
    final h = widget.rows * cell;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vp = Size(constraints.maxWidth, constraints.maxHeight);

        // El mapa se encaja siempre que cambia el espacio disponible
        if (_viewport != vp) {
          _viewport = vp;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _fit();
          });
        }

        return ClipRect(
          child: Container(
            color: const Color(0xFF37474F),
            child: InteractiveViewer(
              transformationController: _controller,
              constrained: false,
              minScale: 0.25,
              maxScale: 3,
              boundaryMargin: const EdgeInsets.all(200),
              // Mapa fijo: sin desplazamiento ni zoom
              panEnabled: false,
              scaleEnabled: false,
              child: SizedBox(
                width: w,
                height: h,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _tap(d.localPosition),
                  onLongPressStart: widget.onCellLongPress == null
                      ? null
                      : (d) {
                          final c = _cellAt(d.localPosition);
                          if (c != null) widget.onCellLongPress!(c.x, c.y);
                        },
                  onPanStart: widget.paintMode
                      ? (d) => _paint(d.localPosition)
                      : (widget.onPathStart != null
                          ? (d) => _pathStart(d.localPosition)
                          : null),
                  onPanUpdate: widget.paintMode
                      ? (d) => _paint(d.localPosition)
                      : (widget.onPathExtend != null
                          ? (d) => _pathUpdate(d.localPosition)
                          : null),
                  onPanEnd: widget.paintMode
                      ? (_) => _lastPaintedCell = null
                      : (widget.onPathEnd != null
                          ? (_) {
                              _lastPathCell = null;
                              widget.onPathEnd!();
                            }
                          : null),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(w, h),
                        painter: _GridPainter(
                          cols: widget.cols,
                          rows: widget.rows,
                          terrain: widget.terrain,
                          reachable: widget.reachable,
                          cell: cell,
                          showZones: widget.showZones,
                          fogged: widget.fogged,
                        ),
                      ),
                      for (final t in widget.tokens)
                        Positioned(
                          left: t.x * cell,
                          top: t.y * cell,
                          width: t.span * cell,
                          height: t.span * cell,
                          // Los toques los resuelve el mapa, no la ficha
                          child: IgnorePointer(
                            child: _TokenView(
                              token: t,
                              color: widget.colorOf(t),
                              color2: widget.color2Of?.call(t),
                              ring: widget.ringOf?.call(t),
                              vital: widget.vitalOf?.call(t) ?? 0,
                              name: widget.nameOf(t),
              icon: widget.iconOf?.call(t),
                              selected: widget.selectedId == t.id,
                              turn: widget.turnIds.contains(t.id),
                            ),
                          ),
                        ),
                      // Marcas de los jugadores en casillas
                      for (final pg in widget.pings)
                        Positioned(
                          left: pg.x * cell,
                          top: pg.y * cell,
                          width: cell,
                          height: cell,
                          child: IgnorePointer(child: _PingView(ping: pg)),
                        ),
                      // Recorridos de los demás jugadores
                      for (final op in widget.otherPaths) ...[
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PathPainter(
                                path: op.cells,
                                cell: cell,
                                over: op.over,
                                faded: true,
                              ),
                            ),
                          ),
                        ),
                        if (op.label.isNotEmpty)
                          Positioned(
                            left: op.cells.last.x * cell - cell * 0.5,
                            top: op.cells.last.y * cell - cell * 0.55,
                            width: cell * 2,
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (op.over
                                            ? Colors.red.shade700
                                            : Colors.black87)
                                        .withOpacity(0.75),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    op.label,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                      // Recorrido dibujado
                      if (widget.path.length > 1)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PathPainter(
                                path: widget.path,
                                cell: cell,
                                over: widget.pathOver,
                              ),
                            ),
                          ),
                        ),
                      if (widget.path.length > 1 && widget.pathLabel.isNotEmpty)
                        Positioned(
                          left: widget.path.last.x * cell - cell * 0.5,
                          top: widget.path.last.y * cell - cell * 0.55,
                          width: cell * 2,
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: widget.pathOver
                                      ? Colors.red.shade700
                                      : Colors.black87,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  widget.pathLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (widget.marker != null)
                        Positioned(
                          left: widget.marker!.x * cell,
                          top: widget.marker!.y * cell,
                          width: widget.marker!.span * cell,
                          height: widget.marker!.span * cell,
                          child: IgnorePointer(
                            child: Center(
                              child: Container(
                                width: cell * 0.34,
                                height: cell * 0.34,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFFE91E63),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: max(2.0, cell * 0.05),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(color: Colors.black54, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GridPainter extends CustomPainter {
  final int cols;
  final int rows;
  final Map<String, String> terrain;
  final Set<String> reachable;
  final double cell;
  final bool showZones;
  final Set<String> fogged;

  _GridPainter({
    required this.cols,
    required this.rows,
    required this.terrain,
    required this.reachable,
    required this.cell,
    this.showZones = false,
    this.fogged = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF5F0E6));

    // Terreno
    terrain.forEach((key, type) {
      final parts = key.split('_');
      if (parts.length != 2) return;

      final x = int.tryParse(parts[0]);
      final y = int.tryParse(parts[1]);
      if (x == null || y == null || x >= cols || y >= rows) return;

      final info = Terrains.parse(type);
      if (info.type == null) return;

      paintTerrainCell(
        canvas,
        Rect.fromLTWH(x * cell, y * cell, cell, cell),
        info,
        x,
        y,
      );

      // Número de grupo de escaleras y teletransportadores
      final g = Terrains.groupOf(type);
      if (g != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: '$g',
            style: TextStyle(
              color: Colors.white,
              fontSize: cell * 0.3,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Colors.black, blurRadius: 3)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x * cell + cell * 0.06, y * cell + cell * 0.02));
      }
    });

    // Zonas (solo para quien diseña el mapa): tinte y número
    if (showZones) {
      terrain.forEach((key, v) {
        final z = Terrains.zoneOf(v);
        if (z == null) return;
        final p = key.split('_');
        final x = int.tryParse(p[0]);
        final y = int.tryParse(p.length > 1 ? p[1] : '');
        if (x == null || y == null || x >= cols || y >= rows) return;
        final color = Color(Terrains.zoneColors[(z - 1) % Terrains.zoneColors.length]);
        final r = Rect.fromLTWH(x * cell, y * cell, cell, cell);
        canvas.drawRect(r, Paint()..color = color.withOpacity(0.22));
        canvas.drawRect(
          r.deflate(1),
          Paint()
            ..color = color.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: 'Z$z',
            style: TextStyle(
              color: color,
              fontSize: cell * 0.22,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Colors.white, blurRadius: 2)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(r.right - tp.width - 3, r.bottom - tp.height - 1));
      });
    }

    paintWallOutlines(canvas, terrain, cols, rows, cell, cell);
    paintDoorGroups(canvas, terrain, cols, rows, cell, cell);

    // Casillas a las que puede llegar la ficha seleccionada
    if (reachable.isNotEmpty) {
      final fill = Paint()..color = const Color(0x6600C853);
      final edge = Paint()
        ..color = const Color(0xCC00A040)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final key in reachable) {
        final parts = key.split('_');
        if (parts.length != 2) continue;
        final x = int.tryParse(parts[0]);
        final y = int.tryParse(parts[1]);
        if (x == null || y == null) continue;
        final r = Rect.fromLTWH(x * cell, y * cell, cell, cell).deflate(1);
        canvas.drawRect(r, fill);
        canvas.drawRect(r, edge);
      }
    }

    // Cuadrícula
    final line = Paint()
      ..color = const Color(0x33000000)
      ..strokeWidth = 1;

    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(Offset(c * cell, 0), Offset(c * cell, rows * cell), line);
    }
    for (var r = 0; r <= rows; r++) {
      canvas.drawLine(Offset(0, r * cell), Offset(cols * cell, r * cell), line);
    }
    // Niebla: zonas ocultas para este jugador
    if (fogged.isNotEmpty) {
      final fog = Paint()..color = const Color(0xFF15181C);
      for (final key in fogged) {
        final p = key.split('_');
        final x = int.tryParse(p[0]);
        final y = int.tryParse(p.length > 1 ? p[1] : '');
        if (x == null || y == null) continue;
        canvas.drawRect(Rect.fromLTWH(x * cell, y * cell, cell, cell), fog);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cols != cols ||
      old.rows != rows ||
      old.terrain != terrain ||
      old.reachable != reachable ||
      old.showZones != showZones ||
      old.fogged != fogged;
}

class _TokenView extends StatelessWidget {
  final GameToken token;
  final Color color;
  final Color? color2;
  final Color? ring;
  final int vital;
  final String name;
  final IconData? icon;
  final bool selected;
  final bool turn;

  const _TokenView({
    required this.token,
    required this.color,
    this.color2,
    this.ring,
    this.vital = 0,
    required this.name,
    required this.icon,
    required this.selected,
    required this.turn,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();

    final textColor = color2 ??
        (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black);
    final edge = ring ?? color2 ?? Colors.white;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: token.hidden ? 0.5 : (vital == 2 ? 0.55 : 1),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: token.isPlayer ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: token.isPlayer ? null : BorderRadius.circular(8),
                  border: Border.all(
                    color: selected && ring == null ? Colors.amber : edge,
                    width: selected || ring != null ? 4 : 2,
                  ),
                  boxShadow: [
                    const BoxShadow(color: Colors.black38, blurRadius: 3),
                    if (selected && ring != null)
                      const BoxShadow(color: Colors.amber, blurRadius: 6, spreadRadius: 3),
                    if (turn)
                      const BoxShadow(
                        color: Color(0xFF00E676),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                  ],
                ),
                child: icon != null
                    ? Icon(
                        icon,
                        color: textColor,
                        size: 22.0 + (token.span - 1) * 10,
                      )
                    : Text(
                        initials,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.0 + (token.span - 1) * 5,
                        ),
                      ),
              ),
            ),
          ),
          if (vital > 0)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(vital == 2 ? 150 : 110),
                    shape: token.isPlayer ? BoxShape.circle : BoxShape.rectangle,
                  ),
                  alignment: Alignment.center,
                  child: FittedBox(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: CustomPaint(
                        size: const Size(20, 26),
                        painter: CrossPainter(
                          vital == 2 ? const Color(0xFFB0B0B0) : Colors.white,
                          outline: vital == 2 ? Colors.red.shade900 : Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (token.hidden)
            const Positioned(
              right: 0,
              top: 0,
              child: Icon(Icons.visibility_off, size: 14, color: Colors.black87),
            ),
        ],
      ),
    );
  }
}


/// Marca de un jugador en una casilla (atacar aquí, ir aquí…).
class CellPing {
  final String id;
  final String uid;
  final int x;
  final int y;
  final int floor;

  /// 'attack', 'move', 'look', 'danger', 'help'
  final String kind;
  final String author;
  final int color;

  const CellPing({
    this.id = '',
    this.uid = '',
    required this.x,
    required this.y,
    this.floor = 0,
    required this.kind,
    required this.author,
    required this.color,
  });

  static const List<String> kinds = ['attack', 'move', 'look', 'danger', 'help'];

  static IconData iconOf(String kind) => switch (kind) {
        'attack' => Icons.gps_fixed,
        'move' => Icons.directions_walk,
        'look' => Icons.visibility,
        'danger' => Icons.warning_amber_rounded,
        'help' => Icons.pan_tool_alt,
        _ => Icons.location_on,
      };

  /// Clave de traducción (español) del tipo de marca
  static String labelOf(String kind) => switch (kind) {
        'attack' => 'Atacar aquí',
        'move' => 'Ir aquí',
        'look' => 'Mirar aquí',
        'danger' => 'Peligro',
        'help' => 'Ayuda',
        _ => 'Marca',
      };
}

class _PingView extends StatelessWidget {
  final CellPing ping;
  const _PingView({required this.ping});

  @override
  Widget build(BuildContext context) {
    final c = Color(ping.color);
    return Center(
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c.withOpacity(0.85),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
        ),
        child: Icon(CellPing.iconOf(ping.kind), size: 18, color: Colors.white),
      ),
    );
  }
}

/// Línea del recorrido dibujado, con un punto en cada casilla.
class _PathPainter extends CustomPainter {
  final List<({int x, int y})> path;
  final double cell;
  final bool over;
  final bool faded;

  _PathPainter({
    required this.path,
    required this.cell,
    required this.over,
    this.faded = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final base = over ? const Color(0xFFD32F2F) : const Color(0xFF1E88E5);
    final color = faded ? base.withOpacity(0.55) : base;
    final line = Paint()
      ..color = color.withOpacity(0.85)
      ..strokeWidth = cell * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    Offset center(({int x, int y}) c) =>
        Offset((c.x + 0.5) * cell, (c.y + 0.5) * cell);
    final p = Path()..moveTo(center(path.first).dx, center(path.first).dy);
    for (final c in path.skip(1)) {
      final o = center(c);
      p.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(p, line);
    final dot = Paint()..color = color;
    for (final c in path.skip(1)) {
      canvas.drawCircle(center(c), cell * 0.12, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) =>
      old.path != path || old.over != over;
}
