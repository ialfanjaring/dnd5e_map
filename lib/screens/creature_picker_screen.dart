import 'package:flutter/material.dart';
import '../services/translation_service.dart';

import '../models/creature.dart';
import '../services/creature_service.dart';
import '../services/monster_api_service.dart';
import '../widgets/creature_sheet_view.dart';
import '../widgets/avatars.dart';
import '../i18n/i18n.dart';

/// Lo que el Master elige añadir a la partida.
class CreaturePickerResult {
  /// Criaturas del bestiario del usuario -> cantidad
  final Map<Creature, int> custom;

  /// Monstruos de la API (índice) -> cantidad. Solo se guarda el índice.
  final Map<String, int> api;

  const CreaturePickerResult({required this.custom, required this.api});

  bool get isEmpty => custom.isEmpty && api.isEmpty;
}

/// Pantalla del Master para añadir criaturas a la partida:
/// - "Mi bestiario": las que ha creado el usuario (se guardan en la base de datos).
/// - "API (SRD)": monstruos generales, consultados al momento y sin guardarse.
class CreaturePickerScreen extends StatefulWidget {
  const CreaturePickerScreen({super.key});

  @override
  State<CreaturePickerScreen> createState() => _CreaturePickerScreenState();
}

class _CreaturePickerScreenState extends State<CreaturePickerScreen>
    with SingleTickerProviderStateMixin {
  final _creatureService = CreatureService();
  final _monsterApi = MonsterApiService();
  final _searchCtrl = TextEditingController();
  late final TabController _tabController;

  // Filtro de FP de la API: clave visible -> valor numérico
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

  String _query = '';
  String? _kind; // filtro del bestiario: null = todas
  String? _crKey; // filtro de FP de la API
  late Future<List<ApiMonsterRef>> _apiFuture;
  String? _previewing; // índice de API que se está descargando

  final Map<String, int> _customQty = {}; // id de criatura -> cantidad
  final Map<String, int> _apiQty = {}; // índice de API -> cantidad

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _apiFuture = _monsterApi.fetchList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _total =>
      _customQty.values.fold(0, (a, b) => a + b) +
      _apiQty.values.fold(0, (a, b) => a + b);

  void _reloadApi() {
    setState(() {
      _apiFuture = _monsterApi.fetchList(
        crValue: _crKey == null ? null : _crFilters[_crKey],
      );
    });
  }

  void _change(Map<String, int> map, String key, int delta) {
    final next = ((map[key] ?? 0) + delta).clamp(0, 20).toInt();
    setState(() {
      if (next == 0) {
        map.remove(key);
      } else {
        map[key] = next;
      }
    });
  }

  Future<void> _previewApi(ApiMonsterRef m) async {
    setState(() => _previewing = m.index);
    try {
      final creature = await _monsterApi.fetchMonster(m.index);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreatureSheetScreen(creature: creature),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('No se pudo cargar')} "${m.name}": $e')),
      );
    } finally {
      if (mounted) setState(() => _previewing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onApiTab = _tabController.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: const Tx(
          'Añadir NPC y monstruos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tr('Mi bestiario')),
            Tab(text: 'API (SRD)'),
          ],
        ),
      ),
      body: SafeArea(top: false, child: StreamBuilder<List<Creature>>(
        stream: _creatureService.myCreatures(),
        builder: (context, mineSnap) {
          final mine = mineSnap.data ?? const <Creature>[];

          return Column(
            children: [
              // BÚSQUEDA Y FILTROS
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: onApiTab
                                      ? tr('Buscar por nombre...')
                                      : tr('Buscar por nombre o tipo...'),
                                  prefixIcon: const Icon(Icons.search),
                                  border: const OutlineInputBorder(),
                                  isDense: true,
                                ),
                                onChanged: (v) => setState(
                                  () => _query = v.trim().toLowerCase(),
                                ),
                              ),
                            ),
                            if (onApiTab) ...[
                              const SizedBox(width: 12),
                              DropdownButton<String?>(
                                value: _crKey,
                                hint: const Tx('FP'),
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Tx('Todos'),
                                  ),
                                  for (final k in _crFilters.keys)
                                    DropdownMenuItem<String?>(
                                      value: k,
                                      child: Text('FP $k'),
                                    ),
                                ],
                                onChanged: (v) {
                                  _crKey = v;
                                  _reloadApi();
                                },
                              ),
                            ],
                          ],
                        ),
                        if (!onApiTab) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              ChoiceChip(
                                label: const Tx('Todos'),
                                selected: _kind == null,
                                onSelected: (_) => setState(() => _kind = null),
                              ),
                              ChoiceChip(
                                label: const Tx('Monstruos'),
                                selected: _kind == 'monster',
                                onSelected: (_) =>
                                    setState(() => _kind = 'monster'),
                              ),
                              ChoiceChip(
                                label: const Tx('NPC'),
                                selected: _kind == 'npc',
                                onSelected: (_) =>
                                    setState(() => _kind = 'npc'),
                              ),
                            ],
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Tx(
                              'Los monstruos de la API no se guardan: se '
                              'consultan cuando los necesitas.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // LISTAS
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCustomList(mine),
                    _buildApiList(),
                  ],
                ),
              ),

              // CONFIRMAR
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _total == 0
                          ? null
                          : () {
                              final byId = {
                                for (final c in mine)
                                  if (c.id != null) c.id!: c,
                              };
                              Navigator.pop(
                                context,
                                CreaturePickerResult(
                                  custom: {
                                    for (final e in _customQty.entries)
                                      if (byId[e.key] != null)
                                        byId[e.key]!: e.value,
                                  },
                                  api: Map<String, int>.from(_apiQty),
                                ),
                              );
                            },
                      icon: const Icon(Icons.check),
                      label: Text('${tr('Añadir a la partida')} ($_total)'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      )),
    );
  }

  // ---------------------------------------------------------------
  // MI BESTIARIO
  // ---------------------------------------------------------------

  Widget _buildCustomList(List<Creature> mine) {
    final list = mine.where((c) {
      if (_kind != null && c.kind != _kind) return false;
      if (_query.isEmpty) return true;
      return c.name.toLowerCase().contains(_query) ||
          c.creatureType.toLowerCase().contains(_query);
    }).toList();

    if (mine.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Tx(
            'Tu bestiario está vacío. Crea tus criaturas desde '
            '«NPC y Monstruos» o usa los monstruos de la pestaña API.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return Center(
        child: Tx(
          'No hay criaturas que mostrar.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final c = list[i];
            final qty = _customQty[c.id] ?? 0;

            return Card(
              elevation: qty > 0 ? 4 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: qty > 0 ? Colors.deepPurple : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatureSheetScreen(creature: c),
                  ),
                ),
                leading: EntityAvatar.creature(
                  isNpc: !c.isMonster,
                  type: c.creatureType,
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${c.subtitle}\nCA ${c.armorClass} · PG ${c.maxHp}',
                ),
                isThreeLine: true,
                trailing: _qtyControls(
                  qty,
                  onMinus: () => _change(_customQty, c.id!, -1),
                  onPlus: () => _change(_customQty, c.id!, 1),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // API (SRD)
  // ---------------------------------------------------------------

  Widget _buildApiList() {
    return FutureBuilder<List<ApiMonsterRef>>(
      future: _apiFuture,
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
                    'No se pudo conectar con la API.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _reloadApi,
                    icon: const Icon(Icons.refresh),
                    label: const Tx('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        final list = snapshot.data!
            .where((m) => _query.isEmpty || _monsterMatches(m.name, _query))
            .toList();

        if (list.isEmpty) {
          return Center(
            child: Tx(
              'No hay monstruos que mostrar.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final m = list[i];
                final qty = _apiQty[m.index] ?? 0;

                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  elevation: qty > 0 ? 4 : 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: qty > 0 ? Colors.deepPurple : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      SrdEs.monsterName(m.name) ?? m.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    leading: _previewing == m.index
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            tooltip: tr('Ver ficha'),
                            icon: const Icon(Icons.description_outlined),
                            onPressed:
                                _previewing == null ? () => _previewApi(m) : null,
                          ),
                    trailing: _qtyControls(
                      qty,
                      onMinus: () => _change(_apiQty, m.index, -1),
                      onPlus: () => _change(_apiQty, m.index, 1),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _qtyControls(
    int qty, {
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: qty > 0 ? onMinus : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 22,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: onPlus,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}


/// Busca por nombre en inglés y también en español (sin acentos).
bool _monsterMatches(String enName, String query) {
  String f(String x) => x
      .toLowerCase()
      .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
      .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ü', 'u');
  final q = f(query);
  return f(enName).contains(q) || f(SrdEs.monsterName(enName) ?? '').contains(q);
}
