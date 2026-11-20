import 'game_models.dart';

/// Cálculo de las casillas a las que puede llegar una ficha.
///
/// Reglas (simples):
/// - Cada casilla cuesta 5 pies; se permite moverse en diagonal.
/// - Casillas bloqueadas (muros, mobiliario...): no se cruzan ni admiten fichas.
///   Terreno difícil (agua, bosque, barro...): cuesta el doble.
/// - Se puede pasar por casillas con otras fichas, pero no terminar en ellas.
class Movement {
  static int _cost(String? terrain) {
    switch (Terrains.parse(terrain).rule) {
      case MoveRule.blocked:
        return -1; // bloqueado
      case MoveRule.difficult:
        return 2;
      case MoveRule.normal:
        return 1;
    }
  }

  /// Velocidad en pies a partir de un texto como "30 pies, Nadar 30 pies".
  static int feetFromText(String text, {int fallback = 30}) {
    final m = RegExp(r'(\d+)').firstMatch(text);
    return m == null ? fallback : int.parse(m.group(1)!);
  }

  /// Claves "x_y" de las casillas (esquina superior izquierda de la ficha)
  /// a las que puede llegar con [speedFeet] pies de movimiento.
  static Set<String> reachable({
    required int cols,
    required int rows,
    required Map<String, String> terrain,
    required int x,
    required int y,
    required int span,
    required int speedFeet,
    required Set<String> occupied,
  }) {
    final budget = speedFeet ~/ 5;
    if (budget <= 0) return const {};

    const inf = 1 << 30;
    final dist = List<int>.filled(cols * rows, inf);

    // Coste de entrar con la ficha en (nx, ny); -1 si no cabe.
    int enterCost(int nx, int ny) {
      if (nx < 0 || ny < 0 || nx + span > cols || ny + span > rows) return -1;
      var worst = 1;
      for (var dx = 0; dx < span; dx++) {
        for (var dy = 0; dy < span; dy++) {
          final c = _cost(terrain[cellKey(nx + dx, ny + dy)]);
          if (c < 0) return -1;
          if (c > worst) worst = c;
        }
      }
      return worst;
    }

    final startIndex = y * cols + x;
    if (x < 0 || y < 0 || x >= cols || y >= rows) return const {};
    dist[startIndex] = 0;

    final queue = <int>[startIndex];
    var head = 0;
    while (head < queue.length) {
      final cur = queue[head++];
      final cx = cur % cols;
      final cy = cur ~/ cols;
      final d = dist[cur];

      for (var dx = -1; dx <= 1; dx++) {
        for (var dy = -1; dy <= 1; dy++) {
          if (dx == 0 && dy == 0) continue;
          final nx = cx + dx;
          final ny = cy + dy;
          final c = enterCost(nx, ny);
          if (c < 0) continue;

          final nd = d + c;
          if (nd > budget) continue;

          final ni = ny * cols + nx;
          if (nd < dist[ni]) {
            dist[ni] = nd;
            queue.add(ni);
          }
        }
      }
    }

    final out = <String>{};
    for (var i = 0; i < dist.length; i++) {
      if (i == startIndex || dist[i] > budget) continue;
      final cx = i % cols;
      final cy = i ~/ cols;

      // No se puede terminar encima de otra ficha
      var free = true;
      for (var dx = 0; dx < span && free; dx++) {
        for (var dy = 0; dy < span; dy++) {
          if (occupied.contains(cellKey(cx + dx, cy + dy))) {
            free = false;
            break;
          }
        }
      }
      if (free) out.add(cellKey(cx, cy));
    }
    return out;
  }
}
