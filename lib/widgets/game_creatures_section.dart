import 'package:flutter/material.dart';

import '../models/creature.dart';
import '../models/game_models.dart';
import '../screens/creature_picker_screen.dart';
import '../services/game_service.dart';
import '../services/monster_api_service.dart';
import 'creature_sheet_view.dart';
import 'avatars.dart';
import '../i18n/i18n.dart';

// ==========================================
// SECCIÓN: NPC Y MONSTRUOS DE LA PARTIDA
// ==========================================

class GameCreaturesSection extends StatelessWidget {
  final String gameCode;

  /// Fichas del mapa (si se indican, cada criatura muestra si está en el
  /// mapa o fuera de él y permite colocarla, sacarla o seleccionarla).
  final List<GameToken> tokens;
  final String? selectedId;

  /// Selecciona la ficha de la criatura en el mapa.
  final void Function(String tokenId)? onLocate;

  /// Piso en el que se colocan las criaturas al sacarlas al mapa
  final int floor;

  /// Borde de color de las criaturas con hermanas iguales (id -> color)
  final Color? Function(String creatureId)? ringOf;

  const GameCreaturesSection({
    super.key,
    this.ringOf,
    required this.gameCode,
    this.tokens = const [],
    this.selectedId,
    this.onLocate,
    this.floor = 0,
  });

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
        SnackBar(content: Text('${tr('No se pudieron añadir las criaturas')}: $e')),
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
          return Text('${tr('No se pudieron cargar las criaturas')}: ${snapshot.error}');
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
                    '${tr('NPC y monstruos')} (${creatures.length})',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _addCreatures(context),
                  icon: const Icon(Icons.add),
                  label: const Tx('Añadir'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (creatures.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Tx(
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
                token: tokens.where((t) => t.id == gc.id).firstOrNull,
                selected: selectedId == gc.id,
                onLocate: onLocate,
                floor: floor,
                ring: ringOf?.call(gc.id),
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
  final GameToken? token;
  final bool selected;
  final void Function(String tokenId)? onLocate;
  final int floor;
  final Color? ring;

  const _GameCreatureTile({
    this.ring,
    required this.gameCode,
    required this.gc,
    required this.numbered,
    this.token,
    this.selected = false,
    this.onLocate,
    this.floor = 0,
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
          tooltip: tr('Quitar de la partida'),
          onPressed: () => service.removeCreature(gameCode, gc.id).catchError(
            (Object e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(trMsg(e.toString().replaceFirst('Exception: ', ''))),
                ));
              }
            },
          ),
          icon: const Icon(Icons.delete_outline),
        );

        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              title: Text(gc.apiIndex ?? tr('Criatura')),
              subtitle: const Tx('No se pudo cargar de la API.'),
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
              title: Tx('Cargando de la API...'),
            ),
          );
        }

        final base = gc.label ?? c.name;
        final label = numbered ? '$base ${gc.number}' : base;

        final lost = gc.damage > c.maxHp ? c.maxHp : gc.damage;
        final current = c.maxHp - lost;

        final t = token;
        final hp = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: tr('Quitar 1 PG'),
              onPressed: current > 0
                  ? () => service.updateCreatureDamage(gameCode, gc.id, lost + 1, maxHp: c.maxHp)
                  : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$current/${c.maxHp} PG',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: tr('Sumar 1 PG'),
              onPressed: lost > 0
                  ? () => service.updateCreatureDamage(gameCode, gc.id, lost - 1, maxHp: c.maxHp)
                  : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        );

        return Card(
          shape: ring == null
              ? null
              : RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: ring!, width: 3),
                ),
          color: selected ? Colors.amber.withOpacity(0.28) : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cabecera: toca para abrir la ficha
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CreatureSheetScreen(creature: c, title: label),
                    ),
                  ),
                  child: Row(
                    children: [
                      EntityAvatar.creature(
                        isNpc: !c.isMonster,
                        type: c.creatureType,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                decoration: current == 0
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            Text(
                              '${tr('CA')} ${c.armorClass} · '
                              '${current == 0 ? tr('Derrotado') : '${tr('FP')} ${c.challengeRating}'}'
                              '${t == null ? '' : (t.hidden ? ' · ${tr('Fuera del mapa')}' : ' · ${tr('En el mapa')}')}',
                              style: TextStyle(
                                fontSize: 12,
                                color: t != null && t.hidden
                                    ? Colors.deepOrange
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.description_outlined, size: 20),
                    ],
                  ),
                ),
                // Acciones
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    hp,
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (t != null) ...[
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: t.hidden
                                ? tr('Colocar en el mapa')
                                : tr('Sacar del mapa (oculta a los jugadores)'),
                            icon: Icon(t.hidden ? Icons.login : Icons.logout),
                            onPressed: () => (t.hidden
                                ? service.placeTokenOnMap(gameCode, t.id, floor: floor)
                                : service.setTokenHidden(gameCode, t.id, true)),
                          ),
                          if (onLocate != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: tr('Seleccionar en el mapa'),
                              icon: const Icon(Icons.my_location),
                              onPressed: () => onLocate!(t.id),
                            ),
                        ],
                        removeButton,
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
