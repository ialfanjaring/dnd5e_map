import 'package:flutter/material.dart';

import '../models/creature.dart';
import '../services/creature_service.dart';
import '../widgets/creature_sheet_view.dart';

/// Elige criaturas (y cuántas de cada una) para añadirlas a la partida.
/// Devuelve un Map<Creature, int> con la cantidad de cada una.
class CreaturePickerScreen extends StatefulWidget {
  const CreaturePickerScreen({super.key});

  @override
  State<CreaturePickerScreen> createState() => _CreaturePickerScreenState();
}

class _CreaturePickerScreenState extends State<CreaturePickerScreen> {
  final _service = CreatureService();
  final _searchCtrl = TextEditingController();

  /// id de criatura -> cantidad
  final Map<String, int> _qty = {};
  String _query = '';
  String? _kind; // null = todas

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int get _total => _qty.values.fold(0, (a, b) => a + b);

  void _change(Creature c, int delta) {
    final id = c.id!;
    final next = ((_qty[id] ?? 0) + delta).clamp(0, 20);
    setState(() {
      if (next == 0) {
        _qty.remove(id);
      } else {
        _qty[id] = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Añadir NPC y monstruos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<Creature>>(
        stream: _service.myCreatures(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;
          final list = all.where((c) {
            if (_kind != null && c.kind != _kind) return false;
            if (_query.isEmpty) return true;
            return c.name.toLowerCase().contains(_query) ||
                c.creatureType.toLowerCase().contains(_query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Column(
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Buscar por nombre o tipo...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (v) =>
                              setState(() => _query = v.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ChoiceChip(
                              label: const Text('Todos'),
                              selected: _kind == null,
                              onSelected: (_) => setState(() => _kind = null),
                            ),
                            ChoiceChip(
                              label: const Text('Monstruos'),
                              selected: _kind == 'monster',
                              onSelected: (_) =>
                                  setState(() => _kind = 'monster'),
                            ),
                            ChoiceChip(
                              label: const Text('NPC'),
                              selected: _kind == 'npc',
                              onSelected: (_) => setState(() => _kind = 'npc'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          'No hay criaturas que mostrar.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, i) =>
                                _buildTile(list[i]),
                          ),
                        ),
                      ),
              ),
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
                              final byId = {for (final c in all) c.id!: c};
                              final result = <Creature, int>{
                                for (final e in _qty.entries)
                                  if (byId[e.key] != null) byId[e.key]!: e.value,
                              };
                              Navigator.pop(context, result);
                            },
                      icon: const Icon(Icons.check),
                      label: Text('Añadir a la partida ($_total)'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTile(Creature c) {
    final qty = _qty[c.id] ?? 0;

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
          MaterialPageRoute(builder: (_) => CreatureSheetScreen(creature: c)),
        ),
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
        subtitle: Text('${c.subtitle}\nCA ${c.armorClass} · PG ${c.maxHp}'),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: qty > 0 ? () => _change(c, -1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 22,
              child: Text(
                '$qty',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _change(c, 1),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}
