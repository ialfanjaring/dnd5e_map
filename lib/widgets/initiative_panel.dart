import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character.dart';
import '../models/combat.dart';
import '../services/game_service.dart';
import '../i18n/i18n.dart';
import 'app_icon.dart';

/// Lista de iniciativa. El Master puede editarla; los jugadores solo la leen
/// y pueden finalizar su turno cuando les toca.
class InitiativePanel extends StatelessWidget {
  final String gameCode;
  final bool isMaster;
  final String myUid;
  final GameService service;

  /// Fichas que puede ver quien mira la lista (los jugadores no ven las ocultas).
  final ValueListenable<Set<String>> visibleIds;

  /// Master: abre la preparación del combate (fichas y grupos).
  final Future<void> Function() onPrepare;

  /// Tirar la iniciativa propia (jugador) y la de cualquier entrada (Master).
  final Future<void> Function() onRollMine;
  final Future<void> Function(InitEntry entry) onRollEntry;

  /// Master: tira por todas las entradas que faltan (solo criaturas si
  /// [onlyCreatures]).
  final Future<void> Function({required bool onlyCreatures}) onRollPending;

  /// Master: ordena por iniciativa y empieza los turnos.
  final Future<void> Function(CombatState state) onStartTurns;

  /// Master: fichas del mapa que todavía no están en la lista.
  final List<({String id, String name})> Function(CombatState state) missing;

  /// Master: añade una ficha a la lista (tirando su iniciativa).
  final Future<void> Function(String tokenId, CombatState state) onAdd;

  /// Abre la ventana del combatiente (PG y conjuros). Master: cualquiera;
  /// jugador: solo el suyo.
  final void Function(InitEntry entry) onOpenEntry;

  const InitiativePanel({
    super.key,
    required this.gameCode,
    required this.isMaster,
    required this.myUid,
    required this.service,
    required this.visibleIds,
    required this.onPrepare,
    required this.onRollMine,
    required this.onRollEntry,
    required this.onRollPending,
    required this.onStartTurns,
    required this.missing,
    required this.onAdd,
    required this.onOpenEntry,
  });

  Future<void> _run(BuildContext context, Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${tr('No se pudo guardar')}: $e')));
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
        title: Text('${tr('Iniciativa de')} ${e.name}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
            LengthLimitingTextInputFormatter(4),
          ],
          decoration: InputDecoration(
            labelText: tr('Resultado final'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
            child: const Tx('Guardar'),
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

  Future<void> _confirmRestart(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Preparar un nuevo combate'),
        content: const Tx(
          'Se perderá el orden de iniciativa actual y se volverá a elegir '
          'quién entra en el combate.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Continuar'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _run(context, onPrepare);
    }
  }

  Future<void> _confirmStart(BuildContext context, CombatState st) async {
    final pending = st.pending;
    if (pending.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Tx('Faltan tiradas'),
          content: Text(
            '${tr('Todavía no han tirado')}: '
            '${pending.map((e) => e.name).join(', ')}.\n'
            '${tr('Se tirará su iniciativa automáticamente.')}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Tx('Esperar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Tx('Tirar y empezar'),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
      await _run(context, () => onRollPending(onlyCreatures: false));
    }
    if (!context.mounted) return;
    await _run(context, () => onStartTurns(st));
  }

  bool _canSee(InitEntry e, Set<String> visible) =>
      visible.contains(e.id) || e.members.any(visible.contains);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CombatState?>(
      stream: service.combat(gameCode),
      builder: (context, snap) {
        final st = snap.data;
        final active = st != null && st.active;
        final rolling = st != null && st.rolling;

        return ValueListenableBuilder<Set<String>>(
          valueListenable: visibleIds,
          builder: (context, visible, _) {
            var entries = !active
                ? <InitEntry>[]
                : (isMaster
                    ? st.entries
                    : st.entries.where((e) => _canSee(e, visible)).toList());

            // Durante las tiradas: primero los que ya tiraron, por resultado
            if (rolling) {
              final done = CombatState.sorted(
                  entries.where((e) => e.rolled).toList());
              entries = [...done, ...entries.where((e) => !e.rolled)];
            }

            final myTurn = active && st.inTurns && st.current == 'p_$myUid';

            return Column(
              children: [
                if (isMaster)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        if (!active)
                          FilledButton.icon(
                            onPressed: () => _run(context, onPrepare),
                            icon: const AppIcon('d20_vacio', size: 22),
                            label: const Tx('Preparar combate'),
                          ),
                        if (rolling) ...[
                          FilledButton.icon(
                            onPressed: () => _confirmStart(context, st),
                            icon: const Icon(Icons.play_arrow),
                            label: Text(
                              st.pending.isEmpty
                                  ? tr('Empezar combate')
                                  : '${tr('Empezar combate')} '
                                      '(${st.pending.length} ${tr('sin tirar')})',
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: st.pending.any((e) => !e.isPlayer)
                                ? () => _run(
                                      context,
                                      () => onRollPending(onlyCreatures: true),
                                    )
                                : null,
                            icon: const AppIcon('d20_vacio', size: 20),
                            label: const Tx('Tirar por las criaturas'),
                          ),
                        ],
                        if (st != null && st.inTurns)
                          PopupMenuButton<String>(
                            tooltip: tr('Añadir ficha a la lista'),
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
                                    ? tr('No faltan fichas')
                                    : '${tr('Añadir ficha')} (${missing(st).length})',
                              ),
                            ),
                          ),
                        if (active)
                          OutlinedButton.icon(
                            onPressed: () => _confirmRestart(context),
                            icon: const Icon(Icons.replay),
                            label: const Tx('Nuevo combate'),
                          ),
                        if (active)
                          OutlinedButton.icon(
                            onPressed: () =>
                                _run(context, () => service.endCombat(gameCode)),
                            icon: const Icon(Icons.flag_outlined),
                            label: const Tx('Terminar combate'),
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
                              ? tr('No hay combate. Pulsa «Preparar combate» '
                                  'para elegir qué criaturas entran y si van '
                                  'en grupo. Después, cada jugador tira su '
                                  'iniciativa.')
                              : tr('No hay combate en curso.'),
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
                          rolling
                              ? tr('Tiradas de iniciativa')
                              : '${tr('Ronda')} ${st.round}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        if (!rolling && (isMaster || myTurn))
                          FilledButton.icon(
                            onPressed: () => _endTurn(context, st),
                            icon: const AppIcon('reloj_arena', size: 22),
                            label: const Tx('Finalizar turno'),
                          ),
                      ],
                    ),
                  ),
                  if (rolling && !isMaster)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Tx(
                        'Pulsa «Tirar» en tu ficha para lanzar tu iniciativa.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  if (isMaster && !rolling)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Tx(
                        'Arrastra para cambiar el orden · toca el resultado '
                        'para editarlo.',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  Expanded(
                    child: isMaster && !rolling
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
    final isCurrent = st.inTurns && st.current == e.id;
    final rolling = st.rolling;
    final mine = e.id == 'p_$myUid';
    final color = Color(e.color);

    return Container(
      key: key,
      color: isCurrent ? Colors.green.withAlpha(40) : null,
      child: ListTile(
        dense: true,
        onTap: (isMaster || mine) ? () => onOpenEntry(e) : null,
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
          !e.rolled
              ? tr('Pendiente de tirar')
              : 'd20: ${e.roll} ${Character.signed(e.mod)}'
                  '${e.isGroup ? ' · ${e.members.length} ${tr('criaturas')}' : ''}'
                  '${isCurrent ? ' · ${tr('tiene el turno')}' : ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rolling && !e.rolled)
              if (mine)
                FilledButton.icon(
                  onPressed: () => _run(context, onRollMine),
                  icon: const AppIcon('d20_vacio', size: 20),
                  label: const Tx('Tirar'),
                )
              else if (isMaster)
                IconButton(
                  tooltip: tr('Tirar su iniciativa'),
                  icon: const AppIcon('d20_vacio', size: 24),
                  onPressed: () => _run(context, () => onRollEntry(e)),
                )
              else
                const Icon(Icons.hourglass_empty, size: 18)
            else if (isMaster && !rolling)
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
            if (isMaster && !rolling) ...[
              IconButton(
                tooltip: tr('Dar el turno a esta ficha'),
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
                tooltip: tr('Quitar de la lista'),
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
