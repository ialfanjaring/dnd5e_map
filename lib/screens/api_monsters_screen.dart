import 'package:flutter/material.dart';

import '../models/creature.dart';
import '../services/creature_service.dart';
import '../services/monster_api_service.dart';
import '../widgets/creature_sheet_view.dart';

/// Monstruos generales de la D&D 5e SRD API (dnd5eapi.co): busca, mira la
/// ficha e impórtalos a tu bestiario para usarlos en las partidas.
class ApiMonstersScreen extends StatefulWidget {
  const ApiMonstersScreen({super.key});

  @override
  State<ApiMonstersScreen> createState() => _ApiMonstersScreenState();
}

class _ApiMonstersScreenState extends State<ApiMonstersScreen> {
  final _api = MonsterApiService();
  final _creatureService = CreatureService();
  final _searchCtrl = TextEditingController();

  late Future<List<ApiMonsterRef>> _future;

  /// Filtro de FP: null = todos. Clave visible -> valor numérico para la API.
  static const Map<String, num> _crFilters = {
    '0': 0,
    '1/8': 0.125,
    '1/4': 0.25,
    '1/2': 0.5,
    '1': 1,
    '2': 2,
    '3': 3,
    '4': 4,
    '5': 5,
    '6': 6,
    '7': 7,
    '8': 8,
    '9': 9,
    '10': 10,
    '11': 11,
    '12': 12,
    '13': 13,
    '14': 14,
    '15': 15,
    '16': 16,
    '17': 17,
    '18': 18,
    '19': 19,
    '20': 20,
    '21': 21,
    '22': 22,
    '23': 23,
    '24': 24,
    '30': 30,
  };

  String? _crKey;
  String _query = '';
  final Set<String> _selected = {};
  String? _previewing; // índice que se está descargando para la vista previa
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchList();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _api.fetchList(crValue: _crKey == null ? null : _crFilters[_crKey]);
    });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _preview(ApiMonsterRef m) async {
    setState(() => _previewing = m.index);
    try {
      final creature = await _api.fetchMonster(m.index);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatureSheetScreen(creature: creature),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudo cargar "${m.name}": $e');
    } finally {
      if (mounted) setState(() => _previewing = null);
    }
  }

  Future<void> _import() async {
    if (_selected.isEmpty) return;

    setState(() => _importing = true);
    try {
      final count = await _api.importMonsters(_selected.toList());
      if (!mounted) return;
      setState(() => _selected.clear());
      _snack(
        count == 1
            ? 'Monstruo añadido a tu bestiario.'
            : '$count monstruos añadidos a tu bestiario.',
      );
    } catch (e) {
      if (!mounted) return;
      _snack('No se pudieron importar los monstruos: $e');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Monstruos de la API',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Buscar por nombre (en inglés)...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) =>
                            setState(() => _query = v.trim().toLowerCase()),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String?>(
                      value: _crKey,
                      hint: const Text('FP'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todos'),
                        ),
                        for (final k in _crFilters.keys)
                          DropdownMenuItem<String?>(
                            value: k,
                            child: Text('FP $k'),
                          ),
                      ],
                      onChanged: (v) {
                        _crKey = v;
                        _reload();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<ApiMonsterRef>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No se pudo conectar con la API.\n'
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final list = snapshot.data!
                    .where((m) =>
                        _query.isEmpty || m.name.toLowerCase().contains(_query))
                    .toList();

                // Ids de los monstruos que ya están en tu bestiario
                return StreamBuilder<List<Creature>>(
                  stream: _creatureService.myCreatures(),
                  builder: (context, mineSnap) {
                    final ownedIds = {
                      for (final c in mineSnap.data ?? const <Creature>[])
                        if (c.id != null) c.id!,
                    };

                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          'No hay monstruos que mostrar.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      );
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final m = list[i];
                            final owned =
                                ownedIds.contains(_api.docIdFor(m.index));
                            final selected = _selected.contains(m.index);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                onTap: owned
                                    ? null
                                    : () => setState(() {
                                          selected
                                              ? _selected.remove(m.index)
                                              : _selected.add(m.index);
                                        }),
                                leading: owned
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      )
                                    : Icon(
                                        selected
                                            ? Icons.check_box
                                            : Icons.check_box_outline_blank,
                                        color: Colors.red.shade800,
                                      ),
                                title: Text(
                                  m.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle:
                                    owned ? const Text('Ya en tu bestiario') : null,
                                trailing: _previewing == m.index
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : IconButton(
                                        tooltip: 'Ver ficha',
                                        icon: const Icon(
                                          Icons.description_outlined,
                                        ),
                                        onPressed: _previewing == null
                                            ? () => _preview(m)
                                            : null,
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_selected.isEmpty || _importing) ? null : _import,
                      icon: _importing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download),
                      label: Text(
                        _selected.isEmpty
                            ? 'Selecciona monstruos para importar'
                            : 'Importar al bestiario (${_selected.length})',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
