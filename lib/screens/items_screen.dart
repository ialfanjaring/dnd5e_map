import 'package:flutter/material.dart';

import '../services/custom_item_service.dart';
import '../services/equipment_api_service.dart';
import '../services/game_service.dart';
import '../widgets/item_widgets.dart';
import 'item_form_screen.dart';

/// Lista de objetos predeterminados (API de D&D 5e).
///
/// - Consulta: se ven los objetos y, si se abre desde una partida
///   ([gameCode]), el Master puede asignarlos a un jugador.
/// - Selección ([pick] = true): se eligen objetos y se devuelven sus
///   índices con `Navigator.pop`.
class ItemsScreen extends StatefulWidget {
  final String? gameCode;
  final bool pick;

  const ItemsScreen({super.key, this.gameCode, this.pick = false});

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _api = EquipmentApiService();
  final _search = TextEditingController();

  String _category = 'weapon';
  late Future<List<ApiItemRef>> _future;
  final Map<String, int> _picked = {};

  @override
  void initState() {
    super.initState();
    _future = _api.fetchCategory(_category);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setCategory(String c) {
    setState(() {
      _category = c;
      if (c != 'custom') _future = _api.fetchCategory(c);
    });
  }

  int get _pickedTotal => _picked.values.fold(0, (a, b) => a + b);

  Future<void> _assign(BuildContext dialogContext, String itemIndex) async {
    final code = widget.gameCode!;
    final service = GameService();
    final messenger = ScaffoldMessenger.of(context);

    final players = await service.players(code).first;
    if (!dialogContext.mounted) return;
    if (players.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No hay jugadores en la partida.')),
      );
      return;
    }

    final uid = await showDialog<String>(
      context: dialogContext,
      builder: (ctx) => SimpleDialog(
        title: const Text('Asignar a…'),
        children: [
          for (final p in players)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p.uid),
              child: Text(p.character.name),
            ),
        ],
      ),
    );
    if (uid == null) return;

    try {
      await service.addItemsToPlayer(
        code,
        uid,
        [itemIndex],
        custom: EquipmentApiService.customData([itemIndex]),
      );
      final name = players.firstWhere((p) => p.uid == uid).character.name;
      messenger.showSnackBar(
        SnackBar(content: Text('Objeto asignado a $name.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo asignar: $e')),
      );
    }
  }

  late final Stream<List<ApiItem>> _customStream =
      CustomItemService().myItems().asBroadcastStream();

  Future<void> _deleteCustom(String index, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar objeto'),
        content: Text(
          '¿Eliminar «$name»? Los jugadores que ya lo tienen lo conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await CustomItemService().delete(index);
  }

  Widget _buildList(List<ApiItemRef> all, {required bool custom}) {
    final q = _search.text.trim().toLowerCase();
    final items =
        all.where((r) => q.isEmpty || r.name.toLowerCase().contains(q)).toList();

    if (items.isEmpty) return const Center(child: Text('Sin resultados.'));

    return ListView.builder(
      padding: EdgeInsets.only(bottom: custom ? 88 : 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        final count = _picked[r.index] ?? 0;

        return ListTile(
          dense: true,
          leading: custom ? const Icon(Icons.auto_fix_high, size: 20) : null,
          title: Text(r.name),
          onTap: () => showItemDetail(
            context,
            r.index,
            extraActions: (dialogContext, item) => [
              if (custom && !widget.pick)
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemFormScreen(item: item),
                      ),
                    );
                  },
                  child: const Text('Editar'),
                ),
              if (widget.pick)
                TextButton(
                  onPressed: () {
                    setState(() => _picked[r.index] = count + 1);
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Añadir'),
                )
              else if (widget.gameCode != null)
                ElevatedButton.icon(
                  onPressed: () => _assign(dialogContext, r.index),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('Asignar a jugador'),
                ),
            ],
          ),
          trailing: widget.pick
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (count > 0) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                          if (count <= 1) {
                            _picked.remove(r.index);
                          } else {
                            _picked[r.index] = count - 1;
                          }
                        }),
                      ),
                      Text('$count'),
                    ],
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          setState(() => _picked[r.index] = count + 1),
                    ),
                  ],
                )
              : (custom
                  ? IconButton(
                      tooltip: 'Eliminar',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteCustom(r.index, r.name),
                    )
                  : const Icon(Icons.chevron_right)),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pick ? 'Elegir objetos' : 'Objetos'),
        actions: [
          if (widget.pick)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, [
                for (final e in _picked.entries)
                  for (var i = 0; i < e.value; i++) e.key,
              ]),
              icon: const Icon(Icons.check),
              label: Text('Listo ($_pickedTotal)'),
            ),
        ],
      ),
      floatingActionButton: _category == 'custom'
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ItemFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Crear objeto'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar por nombre (en inglés)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final e in EquipmentApiService.categories.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _category == e.key,
                      onSelected: (_) => _setCategory(e.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _category == 'custom'
                ? StreamBuilder<List<ApiItem>>(
                    stream: _customStream,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Text('No se pudieron cargar tus objetos.\n${snap.error}',
                              textAlign: TextAlign.center),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.data!.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Todavía no has creado ningún objeto.\n'
                              'Pulsa «Crear objeto».',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return _buildList(
                        [
                          for (final it in snap.data!)
                            ApiItemRef(index: it.index, name: it.name),
                        ],
                        custom: true,
                      );
                    },
                  )
                : FutureBuilder<List<ApiItemRef>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('No se pudo cargar la lista.\n${snap.error}',
                                    textAlign: TextAlign.center),
                                TextButton(
                                  onPressed: () => _setCategory(_category),
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return _buildList(snap.data!, custom: false);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
