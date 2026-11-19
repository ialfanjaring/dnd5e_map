import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character.dart';
import '../models/combat.dart';
import '../services/game_service.dart';

/// Lista de iniciativa. El Master puede editarla; los jugadores solo la leen
/// y pueden finalizar su turno cuando les toca.
class InitiativePanel extends StatelessWidget {
  final String gameCode;
  final bool isMaster;
  final String myUid;
  final GameService service;

  /// Fichas que puede ver quien mira la lista (los jugadores no ven las ocultas).
  final ValueListenable<Set<String>> visibleIds;

  /// Master: tira la iniciativa de todas las fichas y empieza el combate.
  final Future<void> Function() onRollAll;

  /// Master: fichas del mapa que todavía no están en la lista.
  final List<({String id, String name})> Function(CombatState state) missing;

  /// Master: añade una ficha a la lista (tirando su iniciativa).
  final Future<void> Function(String tokenId, CombatState state) onAdd;

  const InitiativePanel({
    super.key,
    required this.gameCode,
    required this.isMaster,
    required this.myUid,
    required this.service,
    required this.visibleIds,
    required this.onRollAll,
    required this.missing,
    required this.onAdd,
  });

  Future<void> _run(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
      }
    }
  }

  Future<void> _editTotal(
    BuildContext context,
    CombatState st,
    InitEntry e,
  ) async {
    final ctrl = TextEditingController(text: '${e.total}');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: Text('Iniciativa de ${e.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: const InputDecoration(
            labelText: 'Resultado final',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (value == null || !context.mounted) return;

    final list = [
      for (final x in st.entries) x.id == e.id ? x.copyWith(total: value) : x,
    ];
    await _run(
      context,
      () => service.saveCombatEntries(gameCode, CombatState.sorted(list)),
    );
  }

  Future<void> _remove(BuildContext context, CombatState st, InitEntry e) {
    final list = st.entries.where((x) => x.id != e.id).toList();

    // Si quitan a quien tiene el turno, pasa al siguiente
    String? current;
    if (st.current == e.id && list.isNotEmpty) {
      final i = st.entries.indexWhere((x) => x.id == e.id);
      current = list[i >= list.length ? 0 : i].id;
    }
    return _run(
      context,
      () => service.saveCombatEntries(gameCode, list, current: current),
    );
  }

  Future<void> _reorder(
    BuildContext context,
    CombatState st,
    int oldIndex,
    int newIndex,
  ) {
    final list = List<InitEntry>.from(st.entries);
    if (newIndex > oldIndex) newIndex -= 1;
    list.insert(newIndex, list.removeAt(oldIndex));
    return _run(context, () => service.saveCombatEntries(gameCode, list));
  }

  Future<void> _endTurn(BuildContext context, CombatState st) {
    final n = st.next();
    return _run(context, () => service.setTurn(gameCode, n.id, n.round));
  }

  Future<void> _confirmReroll(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Volver a tirar iniciativa'),
        content: const Text(
          'Se tirará de nuevo para todas las fichas y se perderán los '
          'cambios hechos a mano en la lista.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Tirar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, onRollAll);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CombatState?>(
      stream: service.combat(gameCode),
      builder: (context, snap) {
        final st = snap.data;
        final active = st != null && st.active;

        return ValueListenableBuilder<Set<String>>(
          valueListenable: visibleIds,
          builder: (context, visible, _) {
            final entries = !active
                ? <InitEntry>[]
                : (isMaster
                    ? st.entries
                    : st.entries.where((e) => visible.contains(e.id)).toList());

            final myTurn = active && st.current == 'p_$myUid';

            return Column(
              children: [
                if (isMaster)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        FilledButton.icon(
                          onPressed: () => active
                              ? _confirmReroll(context)
                              : _run(context, onRollAll),
                          icon: const Icon(Icons.casino),
                          label: Text(
                            active ? 'Volver a tirar' : 'Tirar iniciativa (d20)',
                          ),
                        ),
                        if (active)
                          PopupMenuButton<String>(
                            tooltip: 'Añadir ficha a la lista',
                            enabled: missing(st).isNotEmpty,
                            onSelected: (id) =>
                                _run(context, () => onAdd(id, st)),
                            itemBuilder: (_) => [
                              for (final m in missing(st))
                                PopupMenuItem(value: m.id, child: Text(m.name)),
                            ],
                            child: Chip(
                              avatar: const Icon(Icons.person_add_alt, size: 18),
                              label: Text(
                                missing(st).isEmpty
                                    ? 'No faltan fichas'
                                    : 'Añadir ficha (${missing(st).length})',
                              ),
                            ),
                          ),
                        if (active)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _run(context, () => service.endCombat(gameCode)),
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Terminar combate'),
                          ),
                      ],
                    ),
                  ),
                if (!active)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isMaster
                              ? 'No hay combate. Pulsa «Tirar iniciativa» para '
                                  'que todas las fichas tiren un d20 con su '
                                  'modificador.'
                              : 'No hay combate en curso.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          'Ronda ${st.round}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (isMaster || myTurn)
                          FilledButton.icon(
                            onPressed: () => _endTurn(context, st),
                            icon: const Icon(Icons.skip_next),
                            label: const Text('Finalizar turno'),
                          ),
                      ],
                    ),
                  ),
                  if (isMaster)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Arrastra para cambiar el orden · toca el resultado '
                        'para editarlo.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  Expanded(
                    child: isMaster
                        ? ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: entries.length,
                            onReorder: (a, b) => _reorder(context, st, a, b),
                            itemBuilder: (context, i) => _tile(
                              context,
                              st,
                              entries[i],
                              i,
                              key: ValueKey(entries[i].id),
                            ),
                          )
                        : ListView.builder(
                            itemCount: entries.length,
                            itemBuilder: (context, i) =>
                                _tile(context, st, entries[i], i),
                          ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _tile(
    BuildContext context,
    CombatState st,
    InitEntry e,
    int index, {
    Key? key,
  }) {
    final isCurrent = st.current == e.id;
    final color = Color(e.color);

    return Container(
      key: key,
      color: isCurrent ? Colors.green.withAlpha(40) : null,
      child: ListTile(
        dense: true,
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: color,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color:
                      ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                ),
              ),
            ),
            if (isCurrent)
              const Positioned(
                right: -6,
                bottom: -6,
                child: Icon(Icons.play_circle_fill,
                    size: 18, color: Color(0xFF00A040)),
              ),
          ],
        ),
        title: Text(
          e.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          'd20: ${e.roll} ${Character.signed(e.mod)}'
          '${isCurrent ? ' · tiene el turno' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMaster)
              TextButton(
                onPressed: () => _editTotal(context, st, e),
                child: Text(
                  '${e.total}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              Text(
                '${e.total}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (isMaster) ...[
              IconButton(
                tooltip: 'Dar el turno a esta ficha',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.play_arrow),
                onPressed: isCurrent
                    ? null
                    : () => _run(
                          context,
                          () => service.setTurn(gameCode, e.id, st.round),
                        ),
              ),
              IconButton(
                tooltip: 'Quitar de la lista',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close),
                onPressed: () => _remove(context, st, e),
              ),
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.drag_handle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
