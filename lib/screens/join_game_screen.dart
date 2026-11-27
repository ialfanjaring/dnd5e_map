import 'package:flutter/material.dart';

import '../services/game_service.dart';
import 'player_room_screen.dart';
import '../i18n/i18n.dart';
import '../widgets/app_icon.dart';

/// Pantalla para unirse a una partida con un código de invitación.
class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final _codeCtrl = TextEditingController();
  final _service = GameService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _codeCtrl.text.trim().toUpperCase();

    if (code.isEmpty) {
      setState(() => _error = 'Introduce el código de la partida.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final game = await _service.findGame(code);

      if (!mounted) return;

      if (game == null) {
        setState(() {
          _loading = false;
          _error = tr('No existe ninguna partida con ese código.');
        });
        return;
      }

      setState(() => _loading = false);

      // Entra a la sala de selección de personaje
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PlayerRoomScreen(gameCode: code)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${tr('Error al buscar la partida')}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Tx(
          'Unirse a partida',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(top: false, child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const AppIcon('llave', size: 90),
                const SizedBox(height: 16),
                const Tx(
                  'Introduce el código de invitación',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Tx(
                  'Te lo da el Master de la partida. Después podrás elegir '
                  'con qué personaje quieres jugar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _codeCtrl,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 6,
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 6,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: tr('ABC123'),
                    errorText: _error,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _search,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Tx('Entrar a la sala'),
                  ),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }
}
