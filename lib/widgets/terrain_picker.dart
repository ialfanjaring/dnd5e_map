import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/game_models.dart';
import 'terrain_painter.dart';

/// Selector de terreno: suelos y objetos agrupados + regla de movimiento.
///
/// El valor es el de una casilla: "id" o "id+d" (ver [Terrains]).
class TerrainPicker extends StatelessWidget {
  final String brush;
  final ValueChanged<String> onChanged;

  const TerrainPicker({super.key, required this.brush, required this.onChanged});

  static const _flags = <(String?, String, IconData)>[
    (null, 'Según terreno', Icons.auto_awesome),
    ('n', 'Libre', Icons.directions_walk),
    ('d', 'Difícil', Icons.terrain),
    ('b', 'Sin fichas', Icons.block),
  ];

  @override
  Widget build(BuildContext context) {
    final id = Terrains.idOf(brush);
    final flag = Terrains.flagOf(brush);
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final g in Terrains.groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 4),
            child: Text(
              tr(g),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in Terrains.all.where((t) => t.group == g))
                Tooltip(
                  message: tr(t.name),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onChanged(Terrains.encode(t.id, flag)),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: id == t.id ? cs.primary : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: TerrainSwatch(type: t, size: 38),
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        Text(
          tr('Movimiento'),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            for (final f in _flags)
              ChoiceChip(
                selected: flag == f.$1,
                avatar: Icon(f.$3, size: 16),
                label: Text(tr(f.$2)),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onChanged(Terrains.encode(id, f.$1)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          tr(_help(Terrains.parse(brush).rule, flag == null)),
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }

  static String _help(MoveRule r, bool auto) {
    final what = switch (r) {
      MoveRule.normal => 'Se camina con normalidad.',
      MoveRule.difficult => 'Terreno difícil: cuesta el doble moverse.',
      MoveRule.blocked => 'No se puede cruzar ni colocar fichas.',
    };
    return what;
  }
}

/// Diálogo con el selector (para la barra de la partida).
Future<String?> showTerrainDialog(BuildContext context, String brush) {
  var current = brush;
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: Tx('Terreno'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: TerrainPicker(
              brush: current,
              onChanged: (v) => setS(() => current = v),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Tx('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, current),
            child: Tx('Listo'),
          ),
        ],
      ),
    ),
  );
}
