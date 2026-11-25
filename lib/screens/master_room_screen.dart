import 'package:flutter/material.dart';

import '../widgets/blocking_progress.dart';
import 'package:flutter/services.dart';

import '../services/game_service.dart';
import '../widgets/character_sheet_view.dart';
import '../widgets/spell_widgets.dart';
import '../widgets/game_creatures_section.dart';
import 'game_screen.dart';
import 'map_picker_screen.dart';
import '../widgets/avatars.dart';
import '../widgets/resolved_character.dart';
import '../i18n/i18n.dart';
import '../widgets/app_icon.dart';

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
        title: const Tx(
          'Sala del Master',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: tr('Terminar la sesión (borra la partida)'),
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: () => _endSession(context),
          ),
        ],
      ),
      body: SafeArea(top: false, child: Center(
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
                      Tx(
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
                            tooltip: tr('Copiar código'),
                            icon: const Icon(Icons.copy),
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await Clipboard.setData(
                                ClipboardData(text: gameCode),
                              );
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Tx('Código copiado.'),
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

              const SizedBox(height: 12),

              // MAPA DE LA PARTIDA
              StreamBuilder<Map<String, dynamic>?>(
                stream: service.gameStream(gameCode),
                builder: (context, snap) {
                  final g = snap.data ?? const <String, dynamic>{};
                  final name = (g['mapName'] ?? tr('Cuadrícula vacía')) as String;
                  final cols = (g['cols'] ?? 20) as num;
                  final rows = (g['rows'] ?? 14) as num;

                  return Card(
                    child: ListTile(
                      leading: const AppIcon('mapa', size: 36),
                      title: Text('${tr('Mapa')}: ${tr(name)}'),
                      subtitle: Text('$cols × $rows ${tr('casillas')}'),
                      // Con la partida en juego no se puede cambiar el mapa
                      // (para ello hay que reiniciar la sala desde el mapa)
                      trailing: ElevatedButton(
                        onPressed: g['status'] == 'playing'
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        MapPickerScreen(gameCode: gameCode),
                                  ),
                                ),
                        child: Text(
                          g['status'] == 'playing' ? tr('En juego') : tr('Elegir mapa'),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // LISTA DE JUGADORES
              StreamBuilder<List<GamePlayer>>(
                stream: service.players(gameCode),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text(
                      '${tr('No se pudieron cargar los jugadores')}: ${snapshot.error}',
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
                        '${tr('Jugadores')} (${players.length})',
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
                                Tx(
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
                            leading: EntityAvatar.character(
                              p.character.characterClass,
                            ),
                            title: Text(
                              p.character.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CharacterQuickStats(
                                  character: p.character,
                                  prefix: '${p.character.summary}\n',
                                  suffix: p.nickname.isEmpty ? '' : ' · ${p.nickname}',
                                ),
                                SpellSummaryText(indexes: p.character.spells),
                              ],
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              tooltip: tr('Expulsar jugador'),
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
                      StreamBuilder<Map<String, dynamic>?>(
                        stream: service.gameStream(gameCode),
                        builder: (context, gameSnap) {
                          // Si la partida ya está en juego, se vuelve a entrar
                          final playing =
                              gameSnap.data?['status'] == 'playing';

                          return SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () => _startGame(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.deepPurple,
                                foregroundColor: Colors.white,
                              ),
                              icon: Icon(
                                playing ? Icons.login : Icons.play_arrow,
                              ),
                              label: Text(
                                playing ? tr('Unirme de nuevo') : tr('Iniciar partida'),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),

              // NPC Y MONSTRUOS DE LA PARTIDA
              GameCreaturesSection(gameCode: gameCode),

              const SizedBox(height: 24),
            ],
          ),
        ),
      )),
    );
  }

  /// Termina la sesión y borra la partida.
  Future<void> _endSession(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Terminar la sesión'),
        content: const Tx(
          'Se avisará a los jugadores y la partida se borrará por completo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Terminar sesión'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await runBlocking(
        context,
        tr('Terminando la sesión…'),
        () => GameService().endGame(gameCode),
      );
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Tx('Sesión terminada y partida borrada.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${tr('No se pudo terminar la sesión')}: $e')),
      );
    }
  }

  /// Pasa la partida a "en juego" y abre el mapa. Los jugadores que están en
  /// la sala entran solos. Se puede volver a pulsar para volver al mapa.
  Future<void> _startGame(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await GameService().startGame(gameCode);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => GameScreen(gameCode: gameCode, isMaster: true),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${tr('No se pudo iniciar la partida')}: $e')),
      );
    }
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
        title: const Tx('Expulsar jugador'),
        content: Text(tr('¿Quitar a "{n}" de la sala?').replaceAll('{n}', p.character.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Tx('Expulsar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await service.removePlayer(gameCode, p.uid);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${tr('No se pudo expulsar al jugador')}: $e')),
      );
    }
  }
}
