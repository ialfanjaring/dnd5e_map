import 'package:flutter/material.dart';

import '../models/creature.dart';
import '../services/creature_service.dart';
import '../widgets/creature_sheet_view.dart';
import 'creature_form_screen.dart';

/// Apartado "NPC y Monstruos": bestiario del usuario con datos
/// predeterminados ya cargados en la base de datos.
class CreaturesScreen extends StatefulWidget {
  const CreaturesScreen({super.key});

  @override
  State<CreaturesScreen> createState() => _CreaturesScreenState();
}

class _CreaturesScreenState extends State<CreaturesScreen>
    with SingleTickerProviderStateMixin {
  final _service = CreatureService();
  final _searchCtrl = TextEditingController();
  late final TabController _tabController;
  late final Future<void> _seedFuture;

  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));
    // Carga el bestiario predeterminado la primera vez
    _seedFuture = _service.seedPresetsIfNeeded();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  String? get _currentKind {
    switch (_tabController.index) {
      case 1:
        return 'monster';
      case 2:
        return 'npc';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'NPC y Monstruos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todos'),
            Tab(text: 'Monstruos'),
            Tab(text: 'NPC'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreatureFormScreen(
                initialKind: _currentKind ?? 'monster',
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(_currentKind == 'npc' ? 'Nuevo NPC' : 'Nueva criatura'),
      ),
      body: FutureBuilder<void>(
        future: _seedFuture,
        builder: (context, seedSnap) {
          if (seedSnap.connectionState != ConnectionState.done) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Preparando el bestiario...'),
                ],
              ),
            );
          }

          return Column(
            children: [
              if (seedSnap.hasError)
                MaterialBanner(
                  content: Text(
                    'No se pudieron cargar los datos predeterminados: '
                    '${seedSnap.error}',
                  ),
                  actions: const [SizedBox.shrink()],
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o tipo...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (v) =>
                          setState(() => _query = v.trim().toLowerCase()),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildList()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList() {
    return StreamBuilder<List<Creature>>(
      stream: _service.myCreatures(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'No se pudieron cargar las criaturas.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final kind = _currentKind;
        final list = snapshot.data!.where((c) {
          if (kind != null && c.kind != kind) return false;
          if (_query.isEmpty) return true;
          return c.name.toLowerCase().contains(_query) ||
              c.creatureType.toLowerCase().contains(_query);
        }).toList();

        if (list.isEmpty) {
          return Center(
            child: Text(
              'No hay criaturas que mostrar.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _CreatureTile(
                creature: list[i],
                onView: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatureSheetScreen(creature: list[i]),
                  ),
                ),
                onEdit: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreatureFormScreen(creature: list[i]),
                  ),
                ),
                onDelete: () => _confirmDelete(list[i]),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(Creature c) async {
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar criatura'),
        content: Text('¿Seguro que quieres eliminar "${c.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true || c.id == null) return;

    try {
      await _service.delete(c.id!);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo eliminar: $e')),
      );
    }
  }
}

class _CreatureTile extends StatelessWidget {
  final Creature creature;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CreatureTile({
    required this.creature,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = creature;

    return Card(
      elevation: 2,
      child: ListTile(
        onTap: onView,
        leading: CircleAvatar(
          backgroundColor:
              c.isMonster ? Colors.red.shade100 : Colors.blueGrey.shade100,
          child: Icon(
            c.isMonster ? Icons.pets : Icons.person,
            color: c.isMonster ? Colors.red.shade800 : Colors.blueGrey.shade700,
          ),
        ),
        title: Text(
          c.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${c.subtitle}\nCA ${c.armorClass} · PG ${c.maxHp}'
          '${c.isPreset ? ' · SRD' : ''}',
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'view':
                onView();
                break;
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: Text('Ver ficha')),
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Eliminar')),
          ],
        ),
      ),
    );
  }
}
