import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';

Color _shade(Color c, double amount) {
  // amount > 0 aclara, < 0 oscurece
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(l).toColor();
}

/// Dibuja una casilla de terreno con su textura.
///
/// [detail] false: solo el color (miniaturas pequeñas).
void paintTerrainCell(
  Canvas canvas,
  Rect r,
  CellInfo info,
  int x,
  int y, {
  bool detail = true,
}) {
  final t = info.type;
  if (t == null) return;

  final base = Color(t.color);
  canvas.drawRect(r, Paint()..color = base);

  if (detail) {
    canvas.save();
    canvas.clipRect(r);
    _texture(canvas, r, t, base, Random((x * 73856093) ^ (y * 19349663)));
    canvas.restore();
  }

  // Marca de la regla cuando no es la habitual del terreno
  if (detail && info.overridden) {
    _ruleMark(canvas, r, info.rule);
  }
}

void _ruleMark(Canvas canvas, Rect r, MoveRule rule) {
  final p = Paint()
    ..color = const Color(0xCC000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  switch (rule) {
    case MoveRule.blocked:
      final d = r.deflate(r.width * 0.2);
      canvas.drawLine(d.topLeft, d.bottomRight, p);
      canvas.drawLine(d.topRight, d.bottomLeft, p);
    case MoveRule.difficult:
      final step = r.width / 4;
      for (var i = 1; i < 4; i++) {
        canvas.drawLine(
          Offset(r.left + i * step, r.top + r.height * 0.15),
          Offset(r.left + i * step - step * 0.6, r.bottom - r.height * 0.15),
          p..strokeWidth = 1.6,
        );
      }
    case MoveRule.normal:
      final c = r.center;
      canvas.drawCircle(c, r.width * 0.08, Paint()..color = const Color(0xAA000000));
  }
}

void _texture(
    Canvas canvas, Rect r, TerrainType t, Color base, Random rnd) {
  final w = r.width;
  final dark = Paint()..color = _shade(base, -0.12);
  final light = Paint()..color = _shade(base, 0.10);
  final line = Paint()
    ..color = _shade(base, -0.18)
    ..style = PaintingStyle.stroke
    ..strokeWidth = max(1.0, w / 40);

  void specks(Paint a, Paint b, int n, double size) {
    for (var i = 0; i < n; i++) {
      final p = Offset(r.left + rnd.nextDouble() * w, r.top + rnd.nextDouble() * w);
      canvas.drawCircle(p, size * (0.5 + rnd.nextDouble()), rnd.nextBool() ? a : b);
    }
  }

  switch (t.pattern) {
    case TerrainPattern.plain:
      break;

    case TerrainPattern.grass:
      specks(dark, light, 10, w / 40);
      final blade = Paint()
        ..color = _shade(base, -0.10)
        ..strokeWidth = max(1.0, w / 36)
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 7; i++) {
        final p = Offset(r.left + rnd.nextDouble() * w, r.top + rnd.nextDouble() * w);
        canvas.drawLine(p, p + Offset(w * 0.02, -w * 0.09), blade);
        canvas.drawLine(p, p + Offset(-w * 0.04, -w * 0.07), blade);
      }

    case TerrainPattern.dirt:
      specks(dark, light, 18, w / 38);

    case TerrainPattern.sand:
      specks(light, Paint()..color = _shade(base, -0.07), 20, w / 55);

    case TerrainPattern.mud:
      specks(dark, light, 8, w / 30);
      final puddle = Paint()..color = _shade(base, -0.10);
      canvas.drawOval(
        Rect.fromCenter(
            center: r.center + Offset(rnd.nextDouble() * w * 0.2 - w * 0.1, 0),
            width: w * 0.5,
            height: w * 0.25),
        puddle,
      );

    case TerrainPattern.snow:
      specks(Paint()..color = Colors.white, Paint()..color = const Color(0xFFD3E3EC), 14, w / 40);

    case TerrainPattern.ice:
      final g = Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, w / 30);
      canvas.drawLine(r.topLeft + Offset(w * 0.15, w * 0.45),
          r.topLeft + Offset(w * 0.55, w * 0.05), g);
      canvas.drawLine(r.topLeft + Offset(w * 0.45, w * 0.95),
          r.topLeft + Offset(w * 0.95, w * 0.45), g);
      canvas.drawLine(r.topLeft + Offset(w * 0.3, w * 0.6),
          r.topLeft + Offset(w * 0.5, w * 0.4), line..color = const Color(0x55558FAA));

    case TerrainPattern.planks:
      final n = 4;
      final h = w / n;
      for (var i = 0; i < n; i++) {
        final y = r.top + i * h;
        if (i > 0) canvas.drawLine(Offset(r.left, y), Offset(r.right, y), line);
        // junta entre tablas, desplazada al azar
        final jx = r.left + (0.2 + rnd.nextDouble() * 0.6) * w;
        canvas.drawLine(Offset(jx, y), Offset(jx, y + h), line);
        // veta
        canvas.drawLine(
          Offset(r.left + w * 0.1, y + h * 0.5),
          Offset(r.left + w * (0.3 + rnd.nextDouble() * 0.4), y + h * 0.5),
          Paint()
            ..color = _shade(base, -0.07)
            ..strokeWidth = max(1.0, w / 50),
        );
      }

    case TerrainPattern.tiles:
      final h = w / 2;
      canvas.drawLine(Offset(r.left, r.top + h), Offset(r.right, r.top + h), line);
      canvas.drawLine(Offset(r.left + h, r.top), Offset(r.left + h, r.bottom), line);
      specks(dark, light, 5, w / 45);

    case TerrainPattern.cobble:
      final stone = Paint()..color = _shade(base, 0.07);
      final gap = w / 3;
      for (var j = 0; j < 3; j++) {
        for (var i = 0; i < 3; i++) {
          final off = j.isOdd ? gap / 2 : 0;
          final rr = RRect.fromRectAndRadius(
            Rect.fromLTWH(r.left + i * gap - off + 1.5, r.top + j * gap + 1.5,
                gap - 3, gap - 3),
            Radius.circular(w / 12),
          );
          canvas.drawRRect(rr, stone);
        }
      }

    case TerrainPattern.carpet:
      final border = Paint()
        ..color = const Color(0xFFD9B04A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, w / 16);
      canvas.drawRect(r.deflate(w * 0.12), border);
      canvas.drawRect(
        r.deflate(w * 0.32),
        Paint()..color = _shade(base, -0.08),
      );

    case TerrainPattern.rocks:
      final rock = Paint()..color = _shade(base, -0.18);
      final rock2 = Paint()..color = _shade(base, 0.10);
      for (var i = 0; i < 5; i++) {
        final c = Offset(r.left + (0.15 + rnd.nextDouble() * 0.7) * w,
            r.top + (0.15 + rnd.nextDouble() * 0.7) * w);
        final rad = w * (0.07 + rnd.nextDouble() * 0.07);
        canvas.drawCircle(c + Offset(1, 1), rad, rock);
        canvas.drawCircle(c, rad * 0.85, rock2);
      }

    case TerrainPattern.waves:
    case TerrainPattern.deepWaves:
      final deep = t.pattern == TerrainPattern.deepWaves;
      final wave = Paint()
        ..color = (deep ? Colors.white.withOpacity(0.28) : Colors.white.withOpacity(0.5))
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, w / 28)
        ..strokeCap = StrokeCap.round;
      final rows = deep ? 3 : 2;
      for (var i = 0; i < rows; i++) {
        final y = r.top + w * (i + 0.7) / (rows + 0.4);
        final path = Path()..moveTo(r.left + w * 0.05, y);
        path.quadraticBezierTo(r.left + w * 0.27, y - w * 0.09, r.left + w * 0.5, y);
        path.quadraticBezierTo(r.left + w * 0.73, y + w * 0.09, r.left + w * 0.95, y);
        canvas.drawPath(path, wave);
      }

    case TerrainPattern.stoneWall:
      const rowsN = 3;
      final h = w / rowsN;
      for (var j = 0; j < rowsN; j++) {
        final y = r.top + j * h;
        if (j > 0) canvas.drawLine(Offset(r.left, y), Offset(r.right, y), line);
        final off = j.isOdd ? w * 0.25 : w * 0.55;
        canvas.drawLine(Offset(r.left + off, y), Offset(r.left + off, y + h), line);
      }
      canvas.drawRect(
        r,
        Paint()
          ..color = Colors.black.withOpacity(0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 14),
      );

    case TerrainPattern.woodWall:
      const n = 3;
      final wd = w / n;
      for (var i = 0; i < n; i++) {
        final x = r.left + i * wd;
        if (i > 0) canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), line);
        canvas.drawLine(
          Offset(x + wd * 0.5, r.top + w * 0.1),
          Offset(x + wd * 0.5, r.bottom - w * 0.1),
          Paint()
            ..color = _shade(base, 0.07)
            ..strokeWidth = max(1.0, w / 40),
        );
      }
      canvas.drawRect(
        r,
        Paint()
          ..color = Colors.black.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 14),
      );

    case TerrainPattern.pillar:
      canvas.drawRect(r, Paint()..color = const Color(0xFF9E9E9E));
      canvas.drawCircle(r.center, w * 0.38, Paint()..color = _shade(base, -0.10));
      canvas.drawCircle(r.center, w * 0.30, Paint()..color = _shade(base, 0.10));

    case TerrainPattern.trees:
      canvas.drawRect(r, Paint()..color = const Color(0xFF6DAA57));
      final crown = Paint()..color = _shade(base, -0.05);
      final crown2 = Paint()..color = _shade(base, 0.08);
      for (final o in [
        Offset(0.3, 0.32),
        Offset(0.7, 0.4),
        Offset(0.45, 0.72),
      ]) {
        final c = r.topLeft + Offset(o.dx * w, o.dy * w);
        canvas.drawCircle(c + Offset(1, 2), w * 0.24, Paint()..color = Colors.black26);
        canvas.drawCircle(c, w * 0.24, crown);
        canvas.drawCircle(c + Offset(-w * 0.05, -w * 0.05), w * 0.12, crown2);
      }

    case TerrainPattern.door:
      canvas.drawRect(r.deflate(w * 0.08), Paint()..color = _shade(base, -0.12));
      final frame = Paint()
        ..color = _shade(base, -0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, w / 12);
      canvas.drawRect(r.deflate(w * 0.08), frame);
      canvas.drawLine(r.centerLeft + Offset(w * 0.08, 0),
          r.centerRight - Offset(w * 0.08, 0), line);
      canvas.drawCircle(r.center + Offset(w * 0.25, 0), w * 0.05,
          Paint()..color = const Color(0xFFE0B84A));

    case TerrainPattern.furniture:
      canvas.drawRect(r.deflate(w * 0.06), Paint()..color = _shade(base, -0.08));
      canvas.drawRect(r.deflate(w * 0.16), Paint()..color = _shade(base, 0.08));
      canvas.drawRect(
        r.deflate(w * 0.06),
        Paint()
          ..color = Colors.black87
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 16),
      );

    case TerrainPattern.lava:
      final glow = Paint()..color = const Color(0xFFFFB300);
      final crust = Paint()..color = const Color(0xFF8E2A0C);
      for (var i = 0; i < 3; i++) {
        final c = Offset(r.left + (0.2 + rnd.nextDouble() * 0.6) * w,
            r.top + (0.2 + rnd.nextDouble() * 0.6) * w);
        canvas.drawOval(
            Rect.fromCenter(center: c, width: w * 0.32, height: w * 0.18), glow);
      }
      for (var i = 0; i < 2; i++) {
        final c = Offset(r.left + (0.2 + rnd.nextDouble() * 0.6) * w,
            r.top + (0.2 + rnd.nextDouble() * 0.6) * w);
        canvas.drawCircle(c, w * 0.07, crust);
      }

    case TerrainPattern.marble:
      // Losa de piedra clara, sencilla: solo una junta fina
      canvas.drawRect(
          r,
          Paint()
            ..color = const Color(0x40706C70)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.0, w / 40));

    case TerrainPattern.checker:
      final h = w / 2;
      final dk = Paint()..color = const Color(0xFF2B2B30);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, h, h), dk);
      canvas.drawRect(Rect.fromLTWH(r.left + h, r.top + h, h, h), dk);

    case TerrainPattern.royalCarpet:
      // Alfombra granate lisa con un ribete oscuro
      canvas.drawRect(
        r.deflate(w * 0.08),
        Paint()
          ..color = const Color(0xFF4A0F18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 18),
      );

    case TerrainPattern.palaceWall:
      // Sillares de piedra gris: dos hiladas
      final h = w / 2;
      canvas.drawLine(Offset(r.left, r.top + h), Offset(r.right, r.top + h), line);
      canvas.drawLine(Offset(r.left + w * 0.5, r.top), Offset(r.left + w * 0.5, r.top + h), line);
      canvas.drawLine(Offset(r.left + w * 0.25, r.top + h), Offset(r.left + w * 0.25, r.bottom), line);
      canvas.drawLine(Offset(r.left + w * 0.75, r.top + h), Offset(r.left + w * 0.75, r.bottom), line);

    case TerrainPattern.column:
      final cc = r.center;
      canvas.drawCircle(cc + Offset(w * 0.04, w * 0.06), w * 0.40, Paint()..color = Colors.black38);
      canvas.drawCircle(cc, w * 0.40, Paint()..color = const Color(0xFF4F4F57));
      canvas.drawCircle(cc, w * 0.30, Paint()..color = const Color(0xFF8E8E98));
      canvas.drawCircle(cc - Offset(w * 0.06, w * 0.06), w * 0.12, Paint()..color = const Color(0xFFD6D6DC));
      canvas.drawCircle(
        cc,
        w * 0.40,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 18),
      );

    case TerrainPattern.throne:
      // Sitial de piedra con respaldo apuntado (gótico) y asiento granate
      final back = Path()
        ..moveTo(r.left + w * 0.2, r.top + w * 0.5)
        ..lineTo(r.left + w * 0.2, r.top + w * 0.25)
        ..lineTo(r.center.dx, r.top + w * 0.05)
        ..lineTo(r.right - w * 0.2, r.top + w * 0.25)
        ..lineTo(r.right - w * 0.2, r.top + w * 0.5)
        ..close();
      canvas.drawPath(back, Paint()..color = const Color(0xFF55555D));
      canvas.drawPath(
        back,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 20),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + w * 0.18, r.top + w * 0.5, w * 0.64, w * 0.36),
          Radius.circular(w * 0.06),
        ),
        Paint()..color = const Color(0xFF7A1F2B),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left + w * 0.18, r.top + w * 0.5, w * 0.64, w * 0.36),
          Radius.circular(w * 0.06),
        ),
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 20),
      );

    case TerrainPattern.fountain:
      canvas.drawCircle(r.center, w * 0.44, Paint()..color = const Color(0xFF4F4F57));
      canvas.drawCircle(r.center, w * 0.34, Paint()..color = const Color(0xFF4FA3D9));
      canvas.drawCircle(r.center, w * 0.08, Paint()..color = Colors.white);
      canvas.drawCircle(
        r.center,
        w * 0.44,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 18),
      );

    case TerrainPattern.statue:
      final plinth = r.deflate(w * 0.16);
      canvas.drawRect(plinth.shift(Offset(w * 0.03, w * 0.05)), Paint()..color = Colors.black38);
      canvas.drawRect(plinth, Paint()..color = const Color(0xFF4F4F57));
      canvas.drawRect(
        plinth,
        Paint()
          ..color = Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 18),
      );
      canvas.drawCircle(r.center, w * 0.16, Paint()..color = const Color(0xFFD6D6DC));

    case TerrainPattern.hedge:
      canvas.drawRect(r, Paint()..color = const Color(0xFF6DAA57));
      final leaf = Paint()..color = _shade(base, -0.05);
      final leaf2 = Paint()..color = _shade(base, 0.10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(r.deflate(w * 0.05), Radius.circular(w * 0.2)),
        leaf,
      );
      for (var i = 0; i < 9; i++) {
        final c = Offset(r.left + (0.15 + rnd.nextDouble() * 0.7) * w,
            r.top + (0.15 + rnd.nextDouble() * 0.7) * w);
        canvas.drawCircle(c, w * 0.08, leaf2);
      }

    case TerrainPattern.flowers:
      specks(dark, light, 6, w / 40);
      const cols = [Color(0xFFE5547A), Color(0xFFF2D13C), Color(0xFFFFFFFF), Color(0xFF8E6BD6)];
      for (var i = 0; i < 6; i++) {
        final c = Offset(r.left + (0.12 + rnd.nextDouble() * 0.76) * w,
            r.top + (0.12 + rnd.nextDouble() * 0.76) * w);
        canvas.drawCircle(c, w * 0.07, Paint()..color = cols[rnd.nextInt(cols.length)]);
        canvas.drawCircle(c, w * 0.025, Paint()..color = const Color(0xFFF2B01E));
      }

    case TerrainPattern.bars:
      canvas.drawRect(r, Paint()..color = const Color(0xFF2A2A2E));
      final bar = Paint()
        ..color = const Color(0xFF8A8A90)
        ..strokeWidth = max(2.0, w / 12);
      for (var i = 0; i < 4; i++) {
        final x = r.left + w * (0.14 + i * 0.24);
        canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), bar);
      }
      canvas.drawLine(Offset(r.left, r.top + w * 0.3), Offset(r.right, r.top + w * 0.3), bar);
      canvas.drawLine(Offset(r.left, r.top + w * 0.7), Offset(r.right, r.top + w * 0.7), bar);

    case TerrainPattern.stairsUp:
    case TerrainPattern.stairsDown:
    case TerrainPattern.stairsBoth:
      const steps = 5;
      final sh = w / steps;
      for (var i = 0; i < steps; i++) {
        final y = r.top + i * sh;
        canvas.drawRect(
          Rect.fromLTWH(r.left, y, w, sh),
          Paint()..color = _shade(base, -0.10 + i * 0.045),
        );
        canvas.drawLine(Offset(r.left, y), Offset(r.right, y), line);
      }
      canvas.drawLine(Offset(r.left + w * 0.04, r.top), Offset(r.left + w * 0.04, r.bottom),
          line..strokeWidth = max(1.5, w / 20));
      canvas.drawLine(Offset(r.right - w * 0.04, r.top), Offset(r.right - w * 0.04, r.bottom), line);
      // Flechas: arriba = sube, abajo = baja
      final arrow = Paint()..color = const Color(0xCC2B2B2B);
      void tri(bool up, double cy) {
        final d = up ? -1.0 : 1.0;
        final cx = r.center.dx;
        canvas.drawPath(
          Path()
            ..moveTo(cx, cy + d * w * 0.14)
            ..lineTo(cx - w * 0.15, cy - d * w * 0.08)
            ..lineTo(cx + w * 0.15, cy - d * w * 0.08)
            ..close(),
          arrow,
        );
      }
      if (t.pattern == TerrainPattern.stairsUp) {
        tri(true, r.center.dy);
      } else if (t.pattern == TerrainPattern.stairsDown) {
        tri(false, r.center.dy);
      } else {
        tri(true, r.top + w * 0.3);
        tri(false, r.bottom - w * 0.3);
      }

    case TerrainPattern.ladder:
      canvas.drawRect(r, Paint()..color = _shade(base, -0.18));
      final rail = Paint()
        ..color = const Color(0xFFC49A62)
        ..strokeWidth = max(2.0, w / 11)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(r.left + w * 0.3, r.top + w * 0.04),
          Offset(r.left + w * 0.3, r.bottom - w * 0.04), rail);
      canvas.drawLine(Offset(r.right - w * 0.3, r.top + w * 0.04),
          Offset(r.right - w * 0.3, r.bottom - w * 0.04), rail);
      for (var i = 0; i < 5; i++) {
        final y = r.top + w * (0.12 + i * 0.19);
        canvas.drawLine(Offset(r.left + w * 0.3, y), Offset(r.right - w * 0.3, y),
            rail..strokeWidth = max(1.5, w / 16));
      }

    case TerrainPattern.fire:
      // brasas + llama
      canvas.drawCircle(r.center + Offset(0, w * 0.18), w * 0.32,
          Paint()..color = const Color(0xFF2E2420));
      final flame = Path()
        ..moveTo(r.center.dx, r.top + w * 0.1)
        ..quadraticBezierTo(r.right - w * 0.1, r.center.dy, r.center.dx + w * 0.18,
            r.bottom - w * 0.18)
        ..quadraticBezierTo(r.center.dx, r.bottom - w * 0.05,
            r.center.dx - w * 0.18, r.bottom - w * 0.18)
        ..quadraticBezierTo(r.left + w * 0.1, r.center.dy, r.center.dx, r.top + w * 0.1);
      canvas.drawPath(flame, Paint()..color = const Color(0xFFFF7A1A));
      canvas.save();
      canvas.translate(r.center.dx * 0.0, 0);
      canvas.drawOval(
        Rect.fromCenter(
            center: r.center + Offset(0, w * 0.16), width: w * 0.28, height: w * 0.4),
        Paint()..color = const Color(0xFFFFD54F),
      );
      canvas.restore();
  }
}

/// Muestra un terreno en pequeño (selector).
class TerrainSwatch extends StatelessWidget {
  final TerrainType type;
  final MoveRule? rule;
  final double size;

  const TerrainSwatch({super.key, required this.type, this.rule, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: CustomPaint(
        size: Size.square(size),
        painter: _SwatchPainter(type, rule ?? type.move),
      ),
    );
  }
}

class _SwatchPainter extends CustomPainter {
  final TerrainType type;
  final MoveRule rule;
  _SwatchPainter(this.type, this.rule);

  @override
  void paint(Canvas canvas, Size size) {
    paintTerrainCell(
      canvas,
      Offset.zero & size,
      CellInfo(type, rule),
      1,
      1,
    );
  }

  @override
  bool shouldRepaint(covariant _SwatchPainter old) =>
      old.type != type || old.rule != rule;
}


bool _isWallValue(String? v) {
  if (v == null || v.isEmpty) return false;
  final id = v.split('+').first;
  return id == 'wall' || id == 'woodwall' || id == 'palacewall';
}

/// Dibuja un reborde negro alrededor de las zonas de muro (solo en los
/// lados que dan a algo que no es muro) para destacarlas.
void paintWallOutlines(
  Canvas canvas,
  Map<String, String> terrain,
  int cols,
  int rows,
  double cw,
  double ch,
) {
  final stroke = max(1.5, min(cw, ch) / 12);
  final paint = Paint()
    ..color = Colors.black
    ..strokeWidth = stroke
    ..strokeCap = StrokeCap.square;

  bool wall(int x, int y) => _isWallValue(terrain['${x}_$y']);

  terrain.forEach((key, value) {
    if (!_isWallValue(value)) return;
    final p = key.split('_');
    if (p.length != 2) return;
    final x = int.tryParse(p[0]);
    final y = int.tryParse(p[1]);
    if (x == null || y == null || x >= cols || y >= rows) return;

    final l = x * cw, t = y * ch, r = l + cw, b = t + ch;
    if (!wall(x, y - 1)) canvas.drawLine(Offset(l, t), Offset(r, t), paint);
    if (!wall(x, y + 1)) canvas.drawLine(Offset(l, b), Offset(r, b), paint);
    if (!wall(x - 1, y)) canvas.drawLine(Offset(l, t), Offset(l, b), paint);
    if (!wall(x + 1, y)) canvas.drawLine(Offset(r, t), Offset(r, b), paint);
  });
}


/// Las puertas contiguas se dibujan como una sola puerta grande (de varias
/// hojas) en lugar de varias puertas pequeñas.
void paintDoorGroups(
  Canvas canvas,
  Map<String, String> terrain,
  int cols,
  int rows,
  double cw,
  double ch,
) {
  bool door(int x, int y) {
    final v = terrain['${x}_$y'];
    return v != null && v.split('+').first == 'door';
  }

  final seen = <String>{};
  final base = const Color(0xFF8D6E63);

  void group(int x0, int y0, int n, bool horizontal) {
    final rect = horizontal
        ? Rect.fromLTWH(x0 * cw, y0 * ch, n * cw, ch)
        : Rect.fromLTWH(x0 * cw, y0 * ch, cw, n * ch);
    final inner = rect.deflate(min(cw, ch) * 0.07);
    canvas.drawRect(inner, Paint()..color = _shade(base, -0.10));

    // Tablones a lo largo de la hoja
    final plank = Paint()
      ..color = _shade(base, -0.28)
      ..strokeWidth = max(1.0, min(cw, ch) / 30);
    final k = (n * 3);
    for (var i = 1; i < k; i++) {
      final t = i / k;
      if (horizontal) {
        final x = inner.left + inner.width * t;
        canvas.drawLine(Offset(x, inner.top), Offset(x, inner.bottom), plank);
      } else {
        final y = inner.top + inner.height * t;
        canvas.drawLine(Offset(inner.left, y), Offset(inner.right, y), plank);
      }
    }

    // Dos hojas: raya central y dos tiradores
    final mid = inner.center;
    final seam = Paint()
      ..color = Colors.black87
      ..strokeWidth = max(1.5, min(cw, ch) / 16);
    final gold = Paint()..color = const Color(0xFFE0B84A);
    final hr = min(cw, ch) * 0.06;
    if (horizontal) {
      canvas.drawLine(Offset(mid.dx, inner.top), Offset(mid.dx, inner.bottom), seam);
      canvas.drawCircle(Offset(mid.dx - cw * 0.18, mid.dy), hr, gold);
      canvas.drawCircle(Offset(mid.dx + cw * 0.18, mid.dy), hr, gold);
    } else {
      canvas.drawLine(Offset(inner.left, mid.dy), Offset(inner.right, mid.dy), seam);
      canvas.drawCircle(Offset(mid.dx, mid.dy - ch * 0.18), hr, gold);
      canvas.drawCircle(Offset(mid.dx, mid.dy + ch * 0.18), hr, gold);
    }

    canvas.drawRect(
      inner,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.5, min(cw, ch) / 14),
    );
  }

  for (final key in terrain.keys.toList()) {
    if (seen.contains(key) || !door(
        int.tryParse(key.split('_').first) ?? -1,
        int.tryParse(key.split('_').last) ?? -1)) {
      continue;
    }
    final x = int.parse(key.split('_').first);
    final y = int.parse(key.split('_').last);
    if (x >= cols || y >= rows) continue;
    // Solo empezamos en el comienzo de una fila o columna de puertas
    final startH = !door(x - 1, y);
    final startV = !door(x, y - 1);

    var nh = 1;
    while (door(x + nh, y) && x + nh < cols) {
      nh++;
    }
    if (startH && nh >= 2) {
      for (var i = 0; i < nh; i++) {
        seen.add('${x + i}_$y');
      }
      group(x, y, nh, true);
      continue;
    }
    var nv = 1;
    while (door(x, y + nv) && y + nv < rows) {
      nv++;
    }
    if (startV && nv >= 2 && !door(x - 1, y) && !door(x + 1, y)) {
      for (var i = 0; i < nv; i++) {
        seen.add('${x}_${y + i}');
      }
      group(x, y, nv, false);
    }
  }
}
