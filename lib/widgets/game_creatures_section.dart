import 'package:flutter/material.dart';

import '../models/creature.dart';
import '../screens/creature_picker_screen.dart';
import '../services/game_service.dart';
import '../services/monster_api_service.dart';
import 'creature_sheet_view.dart';
import 'avatars.dart';

// ==========================================
// SECCIÓN: NPC Y MONSTRUOS DE LA PARTIDA
// ==========================================

class GameCreaturesSection extends StatelessWidget {
  final String gameCode;

  const GameCreaturesSection({super.key, required this.gameCode});

  Future<void> _addCreatures(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final result = await Navigator.push<CreaturePickerResult>(
      context,
      MaterialPageRoute(builder: (_) => const CreaturePickerScreen()),
    );

    if (result == null || result.isEmpty) return;

    try {
      await GameService().addCreatures(
        gameCode,
        custom: result.custom,
        api: result.api,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudieron añadir las criaturas: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = GameService();

    return StreamBuilder<List<GameCreature>>(
      stream: service.creatures(gameCode),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('No se pudieron cargar las criaturas: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final creatures = snapshot.data!;

        // Cuántos ejemplares hay de cada monstruo de la API (para numerarlos)
        final apiCounts = <String, int>{};
        for (final gc in creatures) {
          final index = gc.apiIndex;
          if (index != null) apiCounts[index] = (apiCounts[index] ?? 0) + 1;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'NPC y monstruos (${creatures.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addCreatures(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (creatures.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Aún no has añadido criaturas. Elige monstruos de la API '
                    'o de tu bestiario para tener la partida preparada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            for (final gc in creatures)
              _GameCreatureTile(
                gameCode: gameCode,
                gc: gc,
                numbered: gc.isApi && (apiCounts[gc.apiIndex] ?? 0) > 1,
              ),
          ],
        );
      },
    );
  }
}

/// Una criatura de la partida. Si es de la API, sus estadísticas se consultan
/// al momento (no están guardadas en la base de datos).
class _GameCreatureTile extends StatelessWidget {
  final String gameCode;
  final GameCreature gc;
  final bool numbered;

  const _GameCreatureTile({
    required this.gameCode,
    required this.gc,
    required this.numbered,
  });

  @override
  Widget build(BuildContext context) {
    final service = GameService();
    final api = MonsterApiService();

    final Creature? initial =
        gc.snapshot ?? (gc.isApi ? api.cachedMonster(gc.apiIndex!) : null);

    final Future<Creature> future = gc.snapshot != null
        ? Future.value(gc.snapshot!)
        : api.fetchMonster(gc.apiIndex!);

    return FutureBuilder<Creature>(
      future: future,
      initialData: initial,
      builder: (context, snapshot) {
        final removeButton = IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Quitar de la partida',
          onPressed: () => service.removeCreature(gameCode, gc.id),
          icon: const Icon(Icons.delete_outline),
        );

        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              title: Text(gc.apiIndex ?? 'Criatura'),
              subtitle: const Text('No se pudo cargar de la API.'),
              trailing: removeButton,
            ),
          );
        }

        final c = snapshot.data;
        if (c == null) {
          return const Card(
            child: ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Cargando de la API...'),
            ),
          );
        }

        final base = gc.label ?? c.name;
        final label = numbered ? '$base ${gc.number}' : base;

        final lost = gc.damage > c.maxHp ? c.maxHp : gc.damage;
        final current = c.maxHp - lost;

        return Card(
          child: ListTile(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CreatureSheetScreen(creature: c, title: label),
              ),
            ),
            leading: EntityAvatar.creature(
              isNpc: !c.isMonster,
              type: c.creatureType,
            ),
            title: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: current == 0 ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              'CA ${c.armorClass} · '
              '${current == 0 ? 'Derrotado' : 'FP ${c.challengeRating}'}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Quitar 1 PG',
                  onPressed: current > 0
                      ? () => service.updateCreatureDamage(
                            gameCode,
                            gc.id,
                            lost + 1,
                          )
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$current/${c.maxHp}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Sumar 1 PG',
                  onPressed: lost > 0
                      ? () => service.updateCreatureDamage(
                            gameCode,
                            gc.id,
                            lost - 1,
                          )
                      : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
                removeButton,
              ],
            ),
          ),
        );
      },
    );
  }
}
