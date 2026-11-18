import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../models/map_template.dart';

/// Miniatura de un mapa.
class MapPreview extends StatelessWidget {
  final MapTemplate map;
  final double height;

  const MapPreview({super.key, required this.map, this.height = 110});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: map.cols / map.rows,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: CustomPaint(painter: _PreviewPainter(map)),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  final MapTemplate map;
  _PreviewPainter(this.map);

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width / map.cols;
    final ch = size.height / map.rows;

    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF5F0E6));

    map.cells.forEach((key, type) {
      final p = key.split('_');
      if (p.length != 2) return;
      final x = int.tryParse(p[0]);
      final y = int.tryParse(p[1]);
      final t = Terrains.byId(type);
      if (x == null || y == null || t == null) return;
      canvas.drawRect(
        Rect.fromLTWH(x * cw, y * ch, cw + 0.5, ch + 0.5),
        Paint()..color = Color(t.color),
      );
    });
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => old.map != map;
}
