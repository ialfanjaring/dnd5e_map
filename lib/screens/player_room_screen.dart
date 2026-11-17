import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/character_service.dart';
import '../services/game_service.dart';
import '../widgets/character_sheet_view.dart';
import '../widgets/spell_widgets.dart';
import 'character_form_screen.dart';

/// Sala de selección de personaje para el jugador que se une con código.
class PlayerRoomScreen extends StatefulWidget {
  final String gameCode;

  const PlayerRoomScreen({super.key, required this.gameCode});

  @override
  State<PlayerRoomScreen> createState() => _PlayerRoomScreenState();
}

class _PlayerRoomScreenState extends State<PlayerRoomScreen> {
  final _gameService = GameService();
  final _characterService = CharacterService();

  String? _selectedId;
  bool _saving = false;

  String get _myUid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> _confirm(List<Character> characters) async {
    final selected = characters.where((c) => c.id == _selectedId).toList();
    if (selected.isEmpty) return;

    setState(() => _saving = true);

    try {
      await _gameService.joinWithCharacter(widget.gameCode, selected.first);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Entras como ${selected.first.name}.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo entrar a la sala: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    try {
      await _gameService.leave(widget.gameCode);
    } catch (_) {
      // Si falla, simplemente salimos de la pantalla
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sala de partida',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _leave,
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Salir de la sala',
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _gameService.gameStream(widget.gameCode),
        builder: (context, gameSnap) {
          if (gameSnap.hasError) {
            return Center(child: Text('Error: ${gameSnap.error}'));
          }
          if (gameSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final game = gameSnap.data;
          if (game == null) {
            return const Center(child: Text('La partida ya no existe.'));
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(game),
                  const SizedBox(height: 20),
                  _buildCharacterPicker(),
                  const SizedBox(height: 20),
                  _buildPlayersList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> game) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              (game['name'] ?? 'Partida') as String,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Master: ${game['masterEmail'] ?? ''}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'Código: ${widget.gameCode}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterPicker() {
    return StreamBuilder<List<Character>>(
      stream: _characterService.myCharacters(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('No se pudieron cargar tus personajes: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final characters = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Elige tu personaje',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (characters.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Todavía no tienes personajes. Crea uno para poder '
                        'entrar a la partida.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CharacterFormScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear personaje'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              for (final c in characters)
                Card(
                  elevation: _selectedId == c.id ? 6 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectedId == c.id
                          ? Colors.teal
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: ListTile(
                    onTap: () => setState(() => _selectedId = c.id),
                    leading: Icon(
                      _selectedId == c.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: Colors.teal,
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c.summary}\nCA ${c.armorClass} · PG ${c.maxHp}',
                        ),
                        SpellSummaryText(indexes: c.spells),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Ver ficha',
                      icon: const Icon(Icons.description_outlined),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CharacterSheetScreen(character: c),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_selectedId == null || _saving)
                      ? null
                      : () => _confirm(characters),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Confirmar personaje'),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPlayersList() {
    return StreamBuilder<List<GamePlayer>>(
      stream: _gameService.players(widget.gameCode),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('No se pudieron cargar los jugadores: ${snapshot.error}');
        }

        final players = snapshot.data ?? [];

        // Si ya estoy en la sala, preselecciona mi personaje una sola vez
        final mine = players.where((p) => p.uid == _myUid).toList();
        if (_selectedId == null && mine.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedId == null) {
              setState(() => _selectedId = mine.first.character.id);
            }
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Jugadores en la sala (${players.length})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            if (players.isEmpty)
              Text(
                'Todavía no hay nadie. Confirma tu personaje para entrar.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            for (final p in players)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person)),
                  title: Text(
                    p.character.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${p.character.summary}\n${p.email}'),
                      SpellSummaryText(indexes: p.character.spells),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: p.uid == _myUid
                      ? const Chip(label: Text('Tú'))
                      : null,
                ),
              ),
          ],
        );
      },
    );
  }
}
