import 'package:flutter/material.dart';

import '../screens/character_form_screen.dart';
import '../screens/items_screen.dart';
import '../services/equipment_api_service.dart';
import '../services/game_service.dart';
import 'character_sheet_view.dart';
import 'spellcasting_panel.dart';
import '../services/class_api_service.dart';
import 'avatars.dart';
import 'resolved_character.dart';
import '../models/character.dart';
import '../i18n/i18n.dart';

/// Ficha de un jugador en tiempo real: puntos de golpe y ficha completa.
/// El jugador puede editar la suya; el Master puede ajustar los PG de cualquiera.
class PlayerLiveSheet extends StatefulWidget {
  final String gameCode;
  final String uid;

  /// true: aparece el botón para editar la ficha (solo para el propio jugador)
  final bool canEdit;

  /// true: el Master puede asignar y quitar objetos a este jugador
  final bool isMaster;

  const PlayerLiveSheet({
    super.key,
    required this.gameCode,
    required this.uid,
    required this.canEdit,
    this.isMaster = false,
  });

  @override
  State<PlayerLiveSheet> createState() => _PlayerLiveSheetState();
}

class _PlayerLiveSheetState extends State<PlayerLiveSheet> {
  final _service = GameService();
  late final Stream<List<GamePlayer>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _service.players(widget.gameCode);
  }

  Future<void> _changeHp(GamePlayer p, int delta) async {
    final max = p.character.maxHp;
    final next = (p.currentHp + delta).clamp(0, max).toInt();
    try {
      await _service.updatePlayerHp(widget.gameCode, p.uid, next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo cambiar los PG: $e')),
      );
    }
  }

  Future<Map<int, int>> _classSlots(GamePlayer p) async {
    try {
      final levels =
          await ClassApiService().fetchLevels(p.character.characterClass);
      for (final l in levels) {
        if (l.level == p.character.level) return l.slots;
      }
    } catch (_) {}
    return const {};
  }

  Future<void> _addItems() async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const ItemsScreen(pick: true)),
    );
    if (picked == null || picked.isEmpty) return;
    try {
      await _service.addItemsToPlayer(
        widget.gameCode,
        widget.uid,
        picked,
        custom: EquipmentApiService.customData(picked),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron añadir los objetos: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canManage = widget.canEdit || widget.isMaster;

    return StreamBuilder<List<GamePlayer>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No se pudo cargar la ficha.\n${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        GamePlayer? player;
        for (final p in snapshot.data!) {
          if (p.uid == widget.uid) player = p;
        }

        if (player == null) {
          return const Center(child: Tx('Esta ficha ya no está en la partida.'));
        }

        final p = player;
        final max = p.character.maxHp;
        final ratio = max == 0 ? 0.0 : (p.currentHp / max).clamp(0.0, 1.0).toDouble();
        final barColor = ratio > 0.5
            ? Colors.green
            : (ratio > 0.25 ? Colors.orange : Colors.red);

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // PUNTOS DE GOLPE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor:
                              p.color == null ? Colors.grey : Color(p.color!),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            p.character.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          '${p.currentHp} / $max PG',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: ratio,
                      minHeight: 10,
                      color: barColor,
                      backgroundColor: Colors.grey.withOpacity(0.35),
                    ),
                    const SizedBox(height: 10),
                    ResolvedCharacterBuilder(
                      character: p.character,
                      builder: (context, r) {
                        final c = r.character;
                        Widget stat(String label, String value) => Column(
                              children: [
                                Text(
                                  value,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            );

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            stat('CA', '${c.effectiveAc}'),
                            stat('Iniciativa', Character.signed(c.initiative)),
                            stat('Velocidad', '${c.effectiveSpeed} pies'),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        for (final d in const [-5, -1, 1, 5])
                          OutlinedButton(
                            onPressed: () => _changeHp(p, d),
                            child: Text(d > 0 ? '+$d' : '$d'),
                          ),
                      ],
                    ),
                    if (widget.canEdit) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CharacterFormScreen(
                              character: p.character,
                              onSave: (c) => _service.updatePlayerCharacter(
                                widget.gameCode,
                                c,
                              ),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Tx('Editar ficha'),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Tx(
                          'Los cambios se ven al instante en la partida y no '
                          'modifican tu personaje guardado.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ESPACIOS DE CONJURO Y HECHIZOS
            FutureBuilder<Map<int, int>>(
              future: _classSlots(p),
              builder: (context, s) {
                final slots = s.data ?? const <int, int>{};
                if (slots.isEmpty && p.character.spells.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SpellcastingPanel(
                      maxSlots: slots,
                      used: p.slotsUsed,
                      spells: p.character.spells,
                      canEdit: canManage,
                      onUsedChanged: (u) =>
                          _service.updatePlayerSlots(widget.gameCode, p.uid, u),
                    ),
                  ),
                );
              },
            ),

            // FICHA COMPLETA
            CharacterSheetView(
              character: p.character,
              onEquippedChanged: canManage
                  ? (list) => _service
                      .setPlayerEquipped(widget.gameCode, widget.uid, list)
                  : null,
              onAddItems: widget.isMaster ? _addItems : null,
              onRemoveItem: widget.isMaster
                  ? (i) => _service.removeItemFromPlayer(
                        widget.gameCode,
                        widget.uid,
                        i,
                      )
                  : null,
            ),
          ],
        );
      },
    );
  }
}

/// Ficha de un jugador a pantalla completa (la consulta el Master).
class PlayerSheetScreen extends StatelessWidget {
  final String gameCode;
  final String uid;
  final String title;
  final bool canEdit;
  final bool isMaster;

  const PlayerSheetScreen({
    super.key,
    required this.gameCode,
    required this.uid,
    required this.title,
    this.canEdit = false,
    this.isMaster = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: PlayerLiveSheet(
            gameCode: gameCode,
            uid: uid,
            canEdit: canEdit,
            isMaster: isMaster,
          ),
        ),
      ),
    );
  }
}

/// Lista de jugadores para el Master: color, PG en directo y acceso a la ficha.
class PlayersPanel extends StatefulWidget {
  final String gameCode;

  const PlayersPanel({super.key, required this.gameCode});

  @override
  State<PlayersPanel> createState() => _PlayersPanelState();
}

class _PlayersPanelState extends State<PlayersPanel> {
  final _service = GameService();
  late final Stream<List<GamePlayer>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _service.players(widget.gameCode);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GamePlayer>>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No se pudieron cargar los jugadores.\n${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final players = snapshot.data!;

        if (players.isEmpty) {
          return Center(
            child: Tx(
              'Todavía no hay jugadores.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final p in players)
              Card(
                child: ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlayerSheetScreen(
                        gameCode: widget.gameCode,
                        uid: p.uid,
                        title: p.character.name,
                        isMaster: true,
                      ),
                    ),
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                        p.color == null ? Colors.grey : Color(p.color!),
                    child: Icon(
                      Avatars.classIcon(p.character.characterClass),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    p.character.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: CharacterQuickStats(
                    character: p.character,
                    prefix: '${p.character.summary}\n',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: tr('Quitar 1 PG'),
                        onPressed: p.currentHp > 0
                            ? () => _service.updatePlayerHp(
                                  widget.gameCode,
                                  p.uid,
                                  p.currentHp - 1,
                                )
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        '${p.currentHp}/${p.character.maxHp}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: tr('Sumar 1 PG'),
                        onPressed: p.currentHp < p.character.maxHp
                            ? () => _service.updatePlayerHp(
                                  widget.gameCode,
                                  p.uid,
                                  p.currentHp + 1,
                                )
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
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
