import 'package:flutter/material.dart';

/// Ficha de ejemplo en un tablero de tutorial.
class DemoToken {
  const DemoToken(this.x, this.y, this.color, this.label, {this.turn = false});
  final int x;
  final int y;
  final Color color;
  final String label;

  /// Borde dorado: es su turno
  final bool turn;
}

/// Escena de ejemplo para los tutoriales: un tablero pequeño dibujado (no es
/// la partida real) con fichas, alcance, recorrido, marcas y zonas.
class DemoScene {
  const DemoScene({
    this.cols = 10,
    this.rows = 7,
    this.walls = const {},
    this.water = const {},
    this.stairs = const {},
    this.chest = const {},
    this.zone = const {},
    this.fog = const {},
    this.tokens = const [],
    this.reach = const {},
    this.path = const [],
    this.pathLabel = '',
    this.pathOver = false,
    this.ping,
    this.brush,
    this.finger,
  });

  final int cols;
  final int rows;

  /// Casillas "x_y"
  final Set<String> walls;
  final Set<String> water;
  final Set<String> stairs;
  final Set<String> chest;

  /// Casillas de una zona pintada (tinte) y las que tapa la niebla
  final Set<String> zone;
  final Set<String> fog;

  final List<DemoToken> tokens;
  final Set<String> reach;
  final List<(int, int)> path;
  final String pathLabel;
  final bool pathOver;

  /// Casilla marcada (pulsación larga)
  final (int, int)? ping;

  /// Casillas que se están pintando con el pincel
  final Set<String>? brush;

  /// Dónde se dibuja el dedo (indica qué tocar)
  final (int, int)? finger;
}

/// Dibuja una [DemoScene] con el tamaño disponible.
class DemoBoard extends StatelessWidget {
  const DemoBoard({super.key, required this.scene});
  final DemoScene scene;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: scene.cols / scene.rows,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: CustomPaint(
          painter: _DemoPainter(scene, Theme.of(context).brightness == Brightness.dark),
        ),
      ),
    );
  }
}

class _DemoPainter extends CustomPainter {
  _DemoPainter(this.s, this.dark);
  final DemoScene s;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / s.cols;
    final ch = size.height / s.rows;
    Rect cell(int x, int y) => Rect.fromLTWH(x * cw, y * ch, cw, ch);
    Offset center(int x, int y) => Offset((x + 0.5) * cw, (y + 0.5) * ch);

    // Suelo
    canvas.drawRect(Offset.zero & size,
        Paint()..color = dark ? const Color(0xFF3E3A33) : const Color(0xFFE9DFC8));

    void fill(Set<String> keys, Color c) {
      final p = Paint()..color = c;
      for (final k in keys) {
        final parts = k.split('_');
        canvas.drawRect(cell(int.parse(parts[0]), int.parse(parts[1])), p);
      }
    }

    fill(s.water, const Color(0xFF64B5F6));
    fill(s.walls, const Color(0xFF5D4037));
    fill(s.zone, Colors.purple.withOpacity(0.25));
    if (s.brush != null) fill(s.brush!, Colors.deepOrange.withOpacity(0.45));

    // Alcance
    fill(s.reach, Colors.green.withOpacity(0.28));

    // Escaleras y cofres
    for (final k in s.stairs) {
      final p = k.split('_');
      final r = cell(int.parse(p[0]), int.parse(p[1])).deflate(cw * 0.15);
      final line = Paint()
        ..color = Colors.brown.shade800
        ..strokeWidth = 2;
      for (var i = 1; i < 4; i++) {
        final y = r.top + r.height * i / 4;
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), line);
      }
      _text(canvas, '1', r.topRight.translate(-6, 0), 10, Colors.black);
    }
    for (final k in s.chest) {
      final p = k.split('_');
      final r = cell(int.parse(p[0]), int.parse(p[1])).deflate(cw * 0.2);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(3)),
          Paint()..color = const Color(0xFFFFB300));
      canvas.drawRect(Rect.fromLTWH(r.left, r.center.dy - 1, r.width, 2),
          Paint()..color = Colors.brown);
    }

    // Rejilla
    final grid = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..strokeWidth = 1;
    for (var x = 0; x <= s.cols; x++) {
      canvas.drawLine(Offset(x * cw, 0), Offset(x * cw, size.height), grid);
    }
    for (var y = 0; y <= s.rows; y++) {
      canvas.drawLine(Offset(0, y * ch), Offset(size.width, y * ch), grid);
    }

    // Recorrido
    if (s.path.length > 1) {
      final color = s.pathOver ? Colors.orange : Colors.blue;
      final p = Path()..moveTo(center(s.path.first.$1, s.path.first.$2).dx,
          center(s.path.first.$1, s.path.first.$2).dy);
      for (final c in s.path.skip(1)) {
        final o = center(c.$1, c.$2);
        p.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
          p,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = cw * 0.15
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round);
      final end = center(s.path.last.$1, s.path.last.$2);
      canvas.drawCircle(end, cw * 0.18, Paint()..color = color);
      if (s.pathLabel.isNotEmpty) {
        _label(canvas, s.pathLabel, end.translate(0, -ch * 0.7), color);
      }
    }

    // Fichas
    for (final t in s.tokens) {
      final o = center(t.x, t.y);
      final r = cw * 0.4;
      if (t.turn) {
        canvas.drawCircle(o, r + 3, Paint()..color = const Color(0xFFFFC107));
      }
      canvas.drawCircle(o, r, Paint()..color = t.color);
      canvas.drawCircle(
          o,
          r,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
      _text(canvas, t.label, o, r * 0.9, Colors.white, centered: true);
    }

    // Marca
    final ping = s.ping;
    if (ping != null) {
      final o = center(ping.$1, ping.$2);
      canvas.drawCircle(
          o,
          cw * 0.42,
          Paint()
            ..color = Colors.redAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      _text(canvas, '!', o, cw * 0.4, Colors.redAccent, centered: true);
    }

    // Niebla
    fill(s.fog, (dark ? Colors.black : Colors.blueGrey.shade900).withOpacity(0.85));

    // Dedo
    final f = s.finger;
    if (f != null) {
      final o = center(f.$1, f.$2).translate(cw * 0.25, ch * 0.25);
      canvas.drawCircle(o, cw * 0.22, Paint()..color = Colors.black.withOpacity(0.35));
      _text(canvas, '👆', o.translate(0, ch * 0.1), cw * 0.45, Colors.black, centered: true);
    }
  }

  void _text(Canvas canvas, String t, Offset at, double size, Color color,
      {bool centered = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centered ? at - Offset(tp.width / 2, tp.height / 2) : at);
  }

  void _label(Canvas canvas, String t, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: t,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final r = Rect.fromCenter(center: at, width: tp.width + 10, height: tp.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), Paint()..color = color);
    tp.paint(canvas, r.topLeft + const Offset(5, 2));
  }

  @override
  bool shouldRepaint(covariant _DemoPainter old) => old.s != s || old.dark != dark;
}

/// Ayuda para escribir conjuntos de casillas: demoCells([(1,2),(3,4)]).
Set<String> demoCells(List<(int, int)> list) => {for (final c in list) '${c.$1}_${c.$2}'};

/// Rectángulo de casillas, de (x0, y0) a (x1, y1) incluidos.
Set<String> demoRect(int x0, int y0, int x1, int y1) => {
      for (var x = x0; x <= x1; x++)
        for (var y = y0; y <= y1; y++) '${x}_$y',
    };
