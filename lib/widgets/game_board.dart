import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';

/// Mapa de cuadrículas con terreno y fichas. Siempre está encajado y centrado:
/// no admite zoom ni desplazamiento.
class GameBoard extends StatefulWidget {
  final int cols;
  final int rows;
  final Map<String, String> terrain;
  final List<GameToken> tokens;
  final String? selectedId;
  final Color Function(GameToken token) colorOf;
  final String Function(GameToken token) nameOf;

  /// Imagen por defecto de la ficha (según clase, NPC o tipo de monstruo)
  final IconData Function(GameToken token)? iconOf;

  /// true: arrastrar pinta casillas (sin zoom ni desplazamiento)
  final bool paintMode;

  /// Al cambiar este número, el mapa se encaja en pantalla.
  final int fitSignal;

  final void Function(int x, int y) onCellTap;
  final void Function(int x, int y) onCellPaint;

  const GameBoard({
    super.key,
    required this.cols,
    required this.rows,
    required this.terrain,
    required this.tokens,
    required this.selectedId,
    required this.colorOf,
    required this.nameOf,
    this.iconOf,
    required this.paintMode,
    required this.fitSignal,
    required this.onCellTap,
    required this.onCellPaint,
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
                              name: widget.nameOf(t),
              icon: widget.iconOf?.call(t),
                              selected: widget.selectedId == t.id,
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
  final double cell;

  _GridPainter({
    required this.cols,
    required this.rows,
    required this.terrain,
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

      final t = Terrains.byId(type);
      if (t == null) return;

      canvas.drawRect(
        Rect.fromLTWH(x * cell, y * cell, cell, cell),
        Paint()..color = Color(t.color),
      );
    });

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
      old.cols != cols || old.rows != rows || old.terrain != terrain;
}

class _TokenView extends StatelessWidget {
  final GameToken token;
  final Color color;
  final String name;
  final IconData? icon;
  final bool selected;

  const _TokenView({
    required this.token,
    required this.color,
    required this.name,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initials = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();

    final textColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : Colors.black;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: token.hidden ? 0.5 : 1,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: token.isPlayer ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: token.isPlayer ? null : BorderRadius.circular(8),
                  border: Border.all(
                    color: selected ? Colors.amber : Colors.white,
                    width: selected ? 4 : 2,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 3),
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
