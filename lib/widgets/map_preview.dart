import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../models/map_template.dart';
import 'terrain_painter.dart';

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
      final info = Terrains.parse(type);
      if (x == null || y == null || info.type == null) return;
      paintTerrainCell(
        canvas,
        Rect.fromLTWH(x * cw, y * ch, cw + 0.5, ch + 0.5),
        info,
        x,
        y,
        detail: cw > 14,
      );
    });
    paintWallOutlines(canvas, map.cells, map.cols, map.rows, cw, ch);
    paintDoorGroups(canvas, map.cells, map.cols, map.rows, cw, ch);
  }

  @override
  bool shouldRepaint(covariant _PreviewPainter old) => old.map != map;
}
