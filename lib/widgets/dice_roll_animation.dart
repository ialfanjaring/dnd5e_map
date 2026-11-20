import 'dart:math';

import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../i18n/i18n.dart';

/// Animación de una tirada: los dados giran con números que cambian, se
/// detienen en el resultado y, en ventaja o desventaja, brilla el dado que
/// cuenta mientras el otro se apaga.
///
/// Usa una `key` distinta para cada tirada para que la animación se repita.
class DiceRollAnimation extends StatefulWidget {
  final DiceRoll roll;
  const DiceRollAnimation({super.key, required this.roll});

  @override
  State<DiceRollAnimation> createState() => _DiceRollAnimationState();
}

class _DiceRollAnimationState extends State<DiceRollAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  // Pulso del brillo del dado elegido (empieza al acabar la tirada)
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );


  static const double _settle = 0.72; // a partir de aquí se muestra el resultado

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && widget.roll.hasMode && mounted) {
        _glow.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _glow.dispose();
    super.dispose();
  }

  /// Número que se enseña mientras el dado gira.
  int _tumble(String die, int index, double t) {
    final sides = DiceRoll.sides(die);
    final step = (t * 22).floor() + index * 7;
    return Random(step * 977 + index).nextInt(sides) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.roll;
    final groups = r.asGroups;
    final mix = r.isMix;

    return AnimatedBuilder(
      animation: Listenable.merge([_c, _glow]),
      builder: (context, _) {
        final t = _c.value;
        final rolling = t < _settle;
        final settle = ((t - _settle) / (1 - _settle)).clamp(0.0, 1.0);

        final rows = <Widget>[];
        var seed = 0;
        for (final g in groups) {
          final n = g.values.length;
          final shown = n > 6 ? 6 : n;
          final size = mix
              ? (g.hasMode ? 58.0 : (shown <= 2 ? 54.0 : 42.0))
              : (g.hasMode ? 74.0 : (shown == 1 ? 84.0 : (shown <= 3 ? 60.0 : 48.0)));
          final tint = mix && g.label.isNotEmpty ? Color(g.tint) : null;

          final dice = <Widget>[];
          for (var i = 0; i < shown; i++) {
            final isChosen = g.hasMode && i == g.chosen;
            final isLoser = g.hasMode && i != g.chosen;
            final k = seed + i;

            final spin = rolling
                ? (1 - t / _settle) * 3.2 * pi * (k.isEven ? 1 : -1)
                : 0.0;
            final bounce = rolling
                ? -sin(t / _settle * pi * 3 + k * 0.7).abs() * 10
                : -sin(settle * pi) * 6;
            final pop =
                rolling ? 1.0 : 1.0 + sin(settle * pi) * (isChosen ? 0.22 : 0.1);

            final value = rolling ? _tumble(g.die, k, t) : g.values[i];
            final glow = (isChosen && !rolling)
                ? settle * (0.55 + 0.45 * _glow.value)
                : 0.0;
            final dim = (isLoser && !rolling) ? 1 - 0.62 * settle : 1.0;

            dice.add(
              Padding(
                padding: EdgeInsets.symmetric(horizontal: mix ? 3 : 6, vertical: 4),
                child: Opacity(
                  opacity: dim,
                  child: Transform.translate(
                    offset: Offset(0, bounce),
                    child: Transform.scale(
                      scale: pop * (isLoser && !rolling ? 1 - 0.1 * settle : 1),
                      child: SizedBox(
                        width: size,
                        height: size,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Transform.rotate(
                              angle: spin,
                              child: CustomPaint(
                                size: Size.square(size),
                                painter: _DiePainter(
                                  die: g.die,
                                  glow: glow,
                                  gray: isLoser && !rolling ? settle : 0,
                                  value: value,
                                  tint: tint,
                                ),
                              ),
                            ),
                            _faceText(g, r, value, size, isChosen && !rolling, rolling),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }
          seed += shown;

          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (mix && g.label.isNotEmpty)
                    Text(
                      tr(g.label),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(g.tint),
                      ),
                    ),
                  Wrap(alignment: WrapAlignment.center, children: dice),
                  if (g.hasMode && !rolling)
                    Opacity(
                      opacity: settle,
                      child: Text(
                        g.isAdv ? '▲ ${tr('Ventaja')}' : '▼ ${tr('Desventaja')}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: g.isAdv ? Colors.greenAccent : Colors.redAccent,
                        ),
                      ),
                    ),
                  if (mix)
                    SizedBox(
                      height: 18,
                      child: Opacity(
                        opacity: rolling ? 0 : settle,
                        child: Text(
                          _groupLine(g),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }

        final label = _caption(r);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...rows,
            SizedBox(
              height: 26,
              child: Center(
                child: Opacity(
                  opacity: rolling ? 0 : settle,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// "5 + 3 = 8" o "17 / 9 → 17 +5 = 22"
  String _groupLine(DiceGroup g) {
    final m = g.mod == 0 ? '' : (g.mod > 0 ? ' +${g.mod}' : ' ${g.mod}');
    if (g.hasMode) {
      return '${g.values[0]} / ${g.values[1]} → ${g.values[g.chosen == 1 ? 1 : 0]}$m = ${g.subtotal}';
    }
    if (g.values.length == 1 && g.mod == 0) return '${g.subtotal}';
    return '${g.values.join(' + ')}$m = ${g.subtotal}';
  }

  Widget _faceText(
      DiceGroup g, DiceRoll r, int value, double size, bool bright, bool rolling) {
    String text = g.die == 'coin' ? (value == 1 ? 'C' : '✕') : '$value';
    Color color = const Color(0xFF2A1E05);
    if (g.die == 'd20' &&
        !rolling &&
        (g.hasMode ? bright : g.values.length == 1)) {
      final v = g.hasMode ? g.values[g.chosen == 1 ? 1 : 0] : g.values.first;
      if (v == 20) color = const Color(0xFF0B5D1E);
      if (v == 1) color = const Color(0xFF8E1B1B);
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: size * (text.length > 2 ? 0.30 : 0.38),
        fontWeight: FontWeight.w900,
        color: color,
      ),
    );
  }

  String _caption(DiceRoll r) {
    if (r.isMix) {
      final atk = r.groups.where((g) => g.isAttack).toList();
      final dmg = r.groups.any((g) => !g.isAttack);
      final parts = <String>[];
      if (atk.isNotEmpty) {
        final a = atk.first;
        final v = a.hasMode ? a.values[a.chosen == 1 ? 1 : 0] : a.values.first;
        final nat = a.die == 'd20' && v == 20
            ? ' ${tr('¡Crítico!')}'
            : (a.die == 'd20' && v == 1 ? ' ${tr('¡Pifia!')}' : '');
        parts.add('${tr('Ataque')} ${a.subtotal}$nat');
      }
      if (dmg) parts.add('${tr('Daño')} ${r.damageTotal}');
      return parts.join(' · ');
    }
    final g = r.asGroups.first;
    if (r.die == 'coin') {
      return r.values.length == 1
          ? tr(r.values.first == 1 ? 'Cara' : 'Cruz')
          : '${r.values.where((v) => v == 1).length} ${tr('caras')}';
    }
    if (g.hasMode) {
      final v = g.values[g.chosen == 1 ? 1 : 0];
      final extra = r.die == 'd20' && v == 20
          ? ' · ${tr('¡Crítico!')}'
          : (r.die == 'd20' && v == 1 ? ' · ${tr('¡Pifia!')}' : '');
      return '${g.values[0]} / ${g.values[1]} → $v$extra';
    }
    if (r.values.length == 1) {
      final v = r.values.first;
      if (r.die == 'd20' && v == 20) return '20 · ${tr('¡Crítico!')}';
      if (r.die == 'd20' && v == 1) return '1 · ${tr('¡Pifia!')}';
      return '$v';
    }
    return r.resultText;
  }
}

/// Dibuja la forma del dado: triángulo (d4), cuadrado (d6), rombo (d8),
/// pentágono (d10), decágono (d12), hexágono con aristas (d20), círculo
/// (d100) y moneda.
class _DiePainter extends CustomPainter {
  final String die;
  final double glow; // 0..1
  final double gray; // 0..1
  final int value;
  final Color? tint;

  _DiePainter({
    required this.die,
    required this.glow,
    required this.gray,
    required this.value,
    this.tint,
  });

  Path _poly(Offset c, double r, int n, double rot) {
    final p = Path();
    for (var i = 0; i < n; i++) {
      final a = rot + i * 2 * pi / n;
      final pt = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    return p..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.46;

    late Path path;
    switch (die) {
      case 'd4':
        path = _poly(c.translate(0, size.height * 0.04), r * 1.05, 3, -pi / 2);
      case 'd6':
        path = Path()
          ..addRRect(RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: r * 1.75, height: r * 1.75),
              Radius.circular(r * 0.28)));
      case 'd8':
        path = _poly(c, r * 1.05, 4, -pi / 2);
      case 'd10':
        path = _poly(c, r, 5, -pi / 2);
      case 'd12':
        path = _poly(c, r, 10, -pi / 2);
      case 'd20':
        path = _poly(c, r, 6, -pi / 2);
      default: // d100, moneda
        path = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    }

    final c1 = tint == null
        ? const Color(0xFFF2D27A)
        : Color.lerp(tint, Colors.white, 0.35)!;
    final c2 = tint == null
        ? const Color(0xFFC79A33)
        : Color.lerp(tint, Colors.black, 0.28)!;
    final base1 = Color.lerp(c1, const Color(0xFF9A9A9A), gray)!;
    final base2 = Color.lerp(c2, const Color(0xFF5E5E5E), gray)!;

    // Brillo del dado ganador
    if (glow > 0) {
      for (final k in [1.0, 0.55]) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFFFFE08A).withOpacity(0.55 * glow * k)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16 * glow * k + 2),
        );
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [base1, base2],
        ).createShader(Offset.zero & size),
    );

    // Aristas interiores del d20 y d12
    if (die == 'd20') {
      final inner = _poly(c, r * 0.52, 3, -pi / 2);
      canvas.drawPath(
        inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = const Color(0x665E4510),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = glow > 0 ? 2.6 : 2
        ..strokeJoin = StrokeJoin.round
        ..color = glow > 0
            ? Color.lerp(const Color(0xFF8A6418), Colors.white, glow * 0.8)!
            : const Color(0xFF8A6418),
    );
  }

  @override
  bool shouldRepaint(covariant _DiePainter o) =>
      o.glow != glow ||
      o.gray != gray ||
      o.value != value ||
      o.die != die ||
      o.tint != tint;
}
