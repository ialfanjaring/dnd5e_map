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
        old.rows != widget.rows) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fit();
      });
    }
  }

  void _fit() {
    final vp = _viewport;
    if (vp == null || vp.width <= 0 || vp.height <= 0) return;

    final w = widget.cols * cell;
    final h = widget.rows * cell;

    // Margen alrededor para que el mapa no quede pegado a los bordes
    const margin = 16.0;
    final availW = max(1.0, vp.width - margin * 2);
    final availH = max(1.0, vp.height - margin * 2);
    final scale = min(availW / w, availH / h).clamp(0.1, 2.0).toDouble();

    // Centrado en el visor
    final dx = (vp.width - w * scale) / 2;
    final dy = (vp.height - h * scale) / 2;

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
                  onPanStart:
                      widget.paintMode ? (d) => _paint(d.localPosition) : null,
                  onPanUpdate:
                      widget.paintMode ? (d) => _paint(d.localPosition) : null,
                  onPanEnd: widget.paintMode
                      ? (_) => _lastPaintedCell = null
                      : null,
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

  _GridPainter({
    required this.cols,
    required this.rows,
    required this.terrain,
    required this.reachable,
    required this.cell,
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
    });

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
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) =>
      old.cols != cols ||
      old.rows != rows ||
      old.terrain != terrain ||
      old.reachable != reachable;
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
