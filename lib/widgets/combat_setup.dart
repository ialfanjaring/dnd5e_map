import 'package:flutter/material.dart';

import '../i18n/i18n.dart';

/// Ficha que se puede incluir en el combate.
class CombatCandidate {
  final String id;
  final String name;
  final bool isPlayer;

  /// Ficha oculta (fuera del mapa, solo la ve el Master)
  final bool hidden;

  /// Misma clave = mismo tipo de criatura (para agrupar a los iguales)
  final String baseKey;

  const CombatCandidate({
    required this.id,
    required this.name,
    required this.isPlayer,
    required this.hidden,
    required this.baseKey,
  });
}

/// Ficha elegida para el combate y su grupo (null = va sola).
typedef CombatPick = ({String id, String? group});

const List<String> _groupLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

/// Preparación del combate: qué fichas entran y cuáles se agrupan para
/// actuar a la vez (una sola iniciativa y un solo turno).
Future<List<CombatPick>?> showCombatSetup(
  BuildContext context,
  List<CombatCandidate> candidates,
) {
  return showDialog<List<CombatPick>>(
    context: context,
    builder: (_) => _CombatSetupDialog(candidates: candidates),
  );
}

class _CombatSetupDialog extends StatefulWidget {
  final List<CombatCandidate> candidates;
  const _CombatSetupDialog({required this.candidates});

  @override
  State<_CombatSetupDialog> createState() => _CombatSetupDialogState();
}

class _CombatSetupDialogState extends State<_CombatSetupDialog> {
  late final Set<String> _included;
  final Map<String, String> _group = {};

  @override
  void initState() {
    super.initState();
    // Por defecto entran las fichas que están en el mapa
    _included = {
      for (final c in widget.candidates)
        if (!c.hidden) c.id,
    };
  }

  /// Agrupa automáticamente las criaturas incluidas que son del mismo tipo.
  void _groupSame() {
    final byBase = <String, List<CombatCandidate>>{};
    for (final c in widget.candidates) {
      if (c.isPlayer || !_included.contains(c.id)) continue;
      byBase.putIfAbsent(c.baseKey, () => []).add(c);
    }
    setState(() {
      _group.clear();
      var i = 0;
      for (final list in byBase.values) {
        if (list.length < 2 || i >= _groupLetters.length) continue;
        for (final c in list) {
          _group[c.id] = _groupLetters[i];
        }
        i++;
      }
    });
  }

  void _confirm() {
    final picks = <CombatPick>[
      for (final c in widget.candidates)
        if (_included.contains(c.id))
          (id: c.id, group: c.isPlayer ? null : _group[c.id]),
    ];
    Navigator.pop(context, picks);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final players = widget.candidates.where((c) => c.isPlayer).toList();
    final creatures = widget.candidates.where((c) => !c.isPlayer).toList();
    final count = _included.length;

    Widget row(CombatCandidate c) {
      final on = _included.contains(c.id);
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Checkbox(
          value: on,
          onChanged: (v) => setState(() {
            if (v == true) {
              _included.add(c.id);
            } else {
              _included.remove(c.id);
              _group.remove(c.id);
            }
          }),
        ),
        onTap: () => setState(() {
          if (on) {
            _included.remove(c.id);
            _group.remove(c.id);
          } else {
            _included.add(c.id);
          }
        }),
        title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: c.hidden ? Text(tr('Fuera del mapa')) : null,
        trailing: c.isPlayer
            ? null
            : DropdownButton<String?>(
                value: on ? _group[c.id] : null,
                hint: Text(tr('Sin grupo')),
                underline: const SizedBox.shrink(),
                onChanged: on
                    ? (v) => setState(() {
                          if (v == null) {
                            _group.remove(c.id);
                          } else {
                            _group[c.id] = v;
                          }
                        })
                    : null,
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text(tr('Sin grupo')),
                  ),
                  for (final g in _groupLetters)
                    DropdownMenuItem<String?>(
                      value: g,
                      child: Text('${tr('Grupo')} $g'),
                    ),
                ],
              ),
      );
    }

    Widget header(String text, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Row(
            children: [
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (trailing != null) trailing,
            ],
          ),
        );

    return AlertDialog(
      title: const Tx('Preparar combate'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Tx(
                'Elige qué fichas entran en el combate. Las criaturas del '
                'mismo grupo tiran una sola iniciativa y actúan a la vez en '
                'el mismo turno. Después, cada jugador tirará su iniciativa.',
                style: TextStyle(fontSize: 12),
              ),
              if (players.isNotEmpty) header(tr('Jugadores')),
              for (final c in players) row(c),
              if (creatures.isNotEmpty)
                header(
                  tr('Criaturas'),
                  trailing: TextButton.icon(
                    onPressed: _groupSame,
                    icon: const Icon(Icons.group_work_outlined, size: 18),
                    label: const Tx('Agrupar iguales'),
                  ),
                ),
              for (final c in creatures) row(c),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Tx('Cancelar'),
        ),
        FilledButton(
          onPressed: count == 0 ? null : _confirm,
          child: Text('${tr('Empezar')} ($count)'),
        ),
      ],
    );
  }
}
