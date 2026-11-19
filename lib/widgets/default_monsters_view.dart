import 'package:flutter/material.dart';

import '../services/monster_api_service.dart';
import 'creature_sheet_view.dart';
import '../i18n/i18n.dart';

/// Monstruos predeterminados (D&D 5e SRD API). Solo se pueden consultar:
/// no se guardan ni se pueden editar. Para usarlos en una partida, el Master
/// los añade desde su sala.
class DefaultMonstersView extends StatefulWidget {
  const DefaultMonstersView({super.key});

  @override
  State<DefaultMonstersView> createState() => _DefaultMonstersViewState();
}

class _DefaultMonstersViewState extends State<DefaultMonstersView> {
  final _api = MonsterApiService();
  final _searchCtrl = TextEditingController();

  late Future<List<ApiMonsterRef>> _future;
  String _query = '';
  String? _crKey; // null = todos
  String? _loadingIndex; // monstruo que se está descargando

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
      _future = _api.fetchList(
        crValue: _crKey == null ? null : MonsterApiService.crFilters[_crKey],
      );
    });
  }

  Future<void> _open(ApiMonsterRef m) async {
    setState(() => _loadingIndex = m.index);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cargar "${m.name}": $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingIndex = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          children: [
            // TÍTULO
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Card(
                margin: EdgeInsets.zero,
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, color: Colors.red.shade800),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Tx(
                              'Monstruos predeterminados',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2),
                            Tx(
                              'De la API de D&D 5e (SRD, en inglés). Solo se '
                              'pueden consultar; para usarlos en una partida, '
                              'añádelos desde la sala del Master.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // BÚSQUEDA Y FILTRO
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
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
                    hint: const Tx('FP'),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Tx('Todos'),
                      ),
                      for (final k in MonsterApiService.crFilters.keys)
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

            // LISTA
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
                              label: const Tx('Reintentar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final list = snapshot.data!
                      .where((m) =>
                          _query.isEmpty ||
                          m.name.toLowerCase().contains(_query))
                      .toList();

                  if (list.isEmpty) {
                    return Center(
                      child: Tx(
                        'No hay monstruos que mostrar.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final m = list[i];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          enabled: _loadingIndex == null,
                          onTap: () => _open(m),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.red.shade100,
                            child: Icon(
                              Icons.pets,
                              size: 16,
                              color: Colors.red.shade800,
                            ),
                          ),
                          title: Text(
                            m.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: _loadingIndex == m.index
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
