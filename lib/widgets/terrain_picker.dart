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
    final zoneBrush = Terrains.isZoneBrush(brush);
    final zoneSel = zoneBrush ? int.tryParse(brush.substring(1)) ?? 0 : -1;
    final id = zoneBrush ? '' : Terrains.idOf(brush);
    final flag = zoneBrush ? null : Terrains.flagOf(brush);
    final group = Terrains.groupOf(brush);
    final linkable = Terrains.isLinkId(id);
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
                    onTap: () => onChanged(Terrains.encode(
                        t.id, flag, Terrains.isLinkId(t.id) ? group : null)),
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
        // ZONAS: áreas que el Master puede ocultar en la partida
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(
            tr('Zonas'),
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
            for (var z = 1; z <= Terrains.zoneCount; z++)
              ChoiceChip(
                selected: zoneSel == z,
                visualDensity: VisualDensity.compact,
                avatar: CircleAvatar(
                    backgroundColor: Color(Terrains.zoneColors[z - 1]),
                    radius: 7),
                label: Text('$z'),
                onSelected: (_) => onChanged('@$z'),
              ),
            ChoiceChip(
              selected: zoneSel == 0,
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.layers_clear, size: 16),
              label: Text(tr('Quitar zona')),
              onSelected: (_) => onChanged('@0'),
            ),
          ],
        ),
        Text(
          tr('Pinta zonas (habitaciones, pasillos…) para poder ocultarlas a los jugadores durante la partida. No cambian el terreno.'),
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        if (!zoneBrush) ...[
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
                onSelected: (_) => onChanged(Terrains.encode(id, f.$1, group)),
              ),
          ],
        ),
        if (linkable) ...[
          const SizedBox(height: 10),
          Text(
            tr('Conexión'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ChoiceChip(
                selected: group == null,
                label: Text(tr('Sin número')),
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onChanged(Terrains.encode(id, flag)),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: (group ?? 1) > 1
                    ? () => onChanged(Terrains.encode(id, flag, (group ?? 1) - 1))
                    : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                group == null ? '—' : '#$group',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: (group ?? 0) < 99
                    ? () => onChanged(Terrains.encode(id, flag, (group ?? 0) + 1))
                    : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          Text(
            tr('Todas las casillas con el mismo número están conectadas: al pisar una puedes ir a cualquiera de las otras, en este piso o en otro. Sin número, la escalera lleva a la misma casilla del piso de arriba o de abajo.'),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          tr(_help(Terrains.parse(brush).rule, flag == null)),
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
        ],
      ],
    );
  }

  static String _help(MoveRule r, bool auto) {
    final what = switch (r) {
      MoveRule.normal => tr('Se camina con normalidad.'),
      MoveRule.difficult => tr('Terreno difícil: cuesta el doble moverse.'),
      MoveRule.blocked => tr('No se puede cruzar ni colocar fichas.'),
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
