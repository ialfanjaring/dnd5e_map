import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/game_service.dart';
import '../models/creature.dart';
import '../widgets/character_sheet_view.dart';
import '../widgets/creature_sheet_view.dart';
import 'creature_picker_screen.dart';

/// Sala de selección para el Master: comparte el código y ve a los
/// jugadores con los personajes que han elegido.
class MasterRoomScreen extends StatelessWidget {
  final String gameCode;
  final String gameName;

  const MasterRoomScreen({
    super.key,
    required this.gameCode,
    required this.gameName,
  });

  @override
  Widget build(BuildContext context) {
    final service = GameService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sala del Master',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // CABECERA CON CÓDIGO DE INVITACIÓN
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        gameName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Código de invitación',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SelectableText(
                            gameCode,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                              color: Colors.deepPurple,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Copiar código',
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await Clipboard.setData(
                                ClipboardData(text: gameCode),
                              );
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Código copiado.'),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // LISTA DE JUGADORES
              StreamBuilder<List<GamePlayer>>(
                stream: service.players(gameCode),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      'No se pudieron cargar los jugadores: ${snapshot.error}',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final players = snapshot.data!;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Jugadores (${players.length})',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (players.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.hourglass_empty,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Esperando jugadores...\n'
                                  'Comparte el código para que se unan '
                                  'con sus personajes.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      for (final p in players)
                        Card(
                          child: ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CharacterSheetScreen(
                                  character: p.character,
                                ),
                              ),
                            ),
                            leading: CircleAvatar(
                              backgroundColor: Colors.deepPurple.shade100,
                              child: Text(
                                p.character.name.isNotEmpty
                                    ? p.character.name[0].toUpperCase()
                                    : '?',
                              ),
                            ),
                            title: Text(
                              p.character.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${p.character.summary}\n'
                              'CA ${p.character.armorClass} · '
                              'PG ${p.character.maxHp} · ${p.email}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: 'Expulsar jugador',
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () => _confirmKick(
                                context,
                                service,
                                p,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: players.isEmpty
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Iniciar partida: pendiente de '
                                        'conectar con el mapa.',
                                      ),
                                    ),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Iniciar partida'),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // NPC Y MONSTRUOS DE LA PARTIDA
              _CreaturesSection(gameCode: gameCode),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmKick(
    BuildContext context,
    GameService service,
    GamePlayer p,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Expulsar jugador'),
        content: Text('¿Quitar a "${p.character.name}" de la sala?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Expulsar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await service.removePlayer(gameCode, p.uid);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo expulsar al jugador: $e')),
      );
    }
  }
}

// ==========================================
// SECCIÓN: NPC Y MONSTRUOS DE LA PARTIDA
// ==========================================

class _CreaturesSection extends StatelessWidget {
  final String gameCode;

  const _CreaturesSection({required this.gameCode});

  Future<void> _addCreatures(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final selection = await Navigator.push<Map<Creature, int>>(
      context,
      MaterialPageRoute(builder: (_) => const CreaturePickerScreen()),
    );

    if (selection == null || selection.isEmpty) return;

    try {
      await GameService().addCreatures(gameCode, selection);
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
                    'Aún no has añadido criaturas. Elige monstruos y NPC de '
                    'tu bestiario para tener la partida preparada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            for (final gc in creatures)
              Card(
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatureSheetScreen(
                        creature: gc.creature,
                        title: gc.label,
                      ),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor: gc.creature.isMonster
                        ? Colors.red.shade100
                        : Colors.blueGrey.shade100,
                    child: Icon(
                      gc.creature.isMonster ? Icons.pets : Icons.person,
                      color: gc.creature.isMonster
                          ? Colors.red.shade800
                          : Colors.blueGrey.shade700,
                    ),
                  ),
                  title: Text(
                    gc.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: gc.currentHp == 0
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  subtitle: Text(
                    'CA ${gc.creature.armorClass} · '
                    '${gc.currentHp == 0 ? 'Derrotado' : 'FP ${gc.creature.challengeRating}'}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Quitar 1 PG',
                        onPressed: gc.currentHp > 0
                            ? () => service.updateCreatureHp(
                                  gameCode,
                                  gc.id,
                                  gc.currentHp - 1,
                                )
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${gc.currentHp}/${gc.creature.maxHp}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Sumar 1 PG',
                        onPressed: gc.currentHp < gc.creature.maxHp
                            ? () => service.updateCreatureHp(
                                  gameCode,
                                  gc.id,
                                  gc.currentHp + 1,
                                )
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Quitar de la partida',
                        onPressed: () =>
                            service.removeCreature(gameCode, gc.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
