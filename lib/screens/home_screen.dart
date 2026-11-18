import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/game_service.dart';
import 'characters_screen.dart';
import 'creatures_screen.dart';
import 'items_screen.dart';
import 'join_game_screen.dart';
import 'map_picker_screen.dart';
import 'game_screen.dart';
import 'master_room_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final User? user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'D&D 5e',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () async {
              await authService.logout();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxWidth = constraints.maxWidth;

              // 1 tarjeta por fila en móvil, 2 en tablet, 3 en escritorio
              final double cardWidth = maxWidth > 900
                  ? (maxWidth > 1200 ? 360 : (maxWidth - 40) / 3)
                  : (maxWidth > 600 ? (maxWidth - 20) / 2 : maxWidth);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ICONO PRINCIPAL
                  const Icon(
                    Icons.castle,
                    size: 85,
                    color: Colors.deepPurple,
                  ),

                  const SizedBox(height: 16),

                  // BIENVENIDA
                  const Text(
                    'Bienvenido a D&D 5e',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // USUARIO CONECTADO
                  Text(
                    user?.email ?? 'Usuario autenticado',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // PARTIDA ACTIVA COMO MASTER (para reconectarse)
                  const _ActiveGameBanner(),

                  const SizedBox(height: 16),

                  const Text(
                    '¿Qué quieres hacer?',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // TARJETAS DEL MENÚ
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      // CREAR PARTIDA
                      SizedBox(
                        width: cardWidth,
                        child: _MenuCard(
                          icon: Icons.add_circle_outline,
                          title: 'Crear partida',
                          description:
                              'Crea una nueva campaña, prepara el mapa '
                              'y administra tu aventura como Master.',
                          buttonText: 'Crear partida',
                          color: Colors.deepPurple,
                          onTap: () {
                            _showCreateGameDialog(context);
                          },
                        ),
                      ),

                      // UNIRSE A PARTIDA
                      SizedBox(
                        width: cardWidth,
                        child: _MenuCard(
                          icon: Icons.group_add_outlined,
                          title: 'Unirse a partida',
                          description:
                              'Introduce el código de una campaña '
                              'para unirte a la aventura como jugador.',
                          buttonText: 'Unirse a partida',
                          color: Colors.teal,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const JoinGameScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      // PERSONAJES
                      SizedBox(
                        width: cardWidth,
                        child: _MenuCard(
                          icon: Icons.person_outline,
                          title: 'Personajes',
                          description:
                              'Crea y gestiona tus fichas de personaje '
                              'de D&D 5e para usarlas en tus partidas.',
                          buttonText: 'Mis personajes',
                          color: Colors.orange.shade800,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CharactersScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      // NPC Y MONSTRUOS
                      SizedBox(
                        width: cardWidth,
                        child: _MenuCard(
                          icon: Icons.pets,
                          title: 'NPC y Monstruos',
                          description:
                              'Crea tus propios monstruos y NPC para usarlos '
                              'en tus partidas. Los de la API de D&D 5e los '
                              'añade el Master desde su sala.',
                          buttonText: 'Bestiario',
                          color: Colors.red.shade800,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CreaturesScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      // OBJETOS
                      SizedBox(
                        width: cardWidth,
                        child: _MenuCard(
                          icon: Icons.inventory_2_outlined,
                          title: 'Objetos',
                          description:
                              'Consulta armas, armaduras, escudos y objetos '
                              'mágicos de D&D 5e.',
                          buttonText: 'Ver objetos',
                          color: Colors.brown.shade700,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ItemsScreen(),
                              ),
                            );
                          },
                        ),
                      ),

                      // MAPAS
                      SizedBox(
                        width: cardWidth,
                        child: _MenuCard(
                          icon: Icons.map_outlined,
                          title: 'Mapas',
                          description:
                              'Mapas predeterminados y editor para crear '
                              'los tuyos. Los eliges al preparar la partida.',
                          buttonText: 'Mis mapas',
                          color: Colors.green.shade800,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MapPickerScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  Text(
                    'Prepara tus dados y comienza tu aventura.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FORMULARIO PARA CREAR PARTIDA
  // ==========================================

  void _showCreateGameDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    bool creating = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (innerContext, setState) {
            return AlertDialog(
              title: const Text('Crear nueva partida'),

              content: TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la partida',
                  hintText: 'Ej. La mina perdida',
                  prefixIcon: Icon(Icons.edit),
                  border: OutlineInputBorder(),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: creating
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancelar'),
                ),

                ElevatedButton.icon(
                  onPressed: creating
                      ? null
                      : () async {
                          final String name = nameController.text.trim();

                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Introduce un nombre para la partida.',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() => creating = true);

                          try {
                            final String code =
                                await GameService().createGame(name);

                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext);

                            if (!context.mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MasterRoomScreen(
                                  gameCode: code,
                                  gameName: name,
                                ),
                              ),
                            );
                          } catch (e) {
                            if (!dialogContext.mounted) return;
                            setState(() => creating = false);

                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No se pudo crear la partida: $e',
                                ),
                              ),
                            );
                          }
                        },
                  icon: creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add),
                  label: const Text('Crear sala'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ==========================================
// TARJETA REUTILIZABLE DEL MENÚ
// ==========================================

class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String buttonText;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),

      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 65,
              color: color,
            ),

            const SizedBox(height: 18),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onTap,

                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                icon: Icon(icon),
                label: Text(buttonText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Si el Master tiene una partida activa en la base de datos, permite
/// reconectarse (por ejemplo, tras salirse sin querer). De paso borra sus
/// partidas inactivas de más de 24 horas.
class _ActiveGameBanner extends StatefulWidget {
  const _ActiveGameBanner();

  @override
  State<_ActiveGameBanner> createState() => _ActiveGameBannerState();
}

class _ActiveGameBannerState extends State<_ActiveGameBanner> {
  late Future<({String code, String name, String status})?> _future;

  /// Partidas que el Master acaba de terminar: no se vuelven a mostrar.
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<({String code, String name, String status})?> _load() =>
      GameService().cleanupAndFindMyGame().catchError((_) => null);

  void _refresh() => setState(() => _future = _load());

  Future<void> _resume(({String code, String name, String status}) g) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => g.status == 'playing'
            ? GameScreen(gameCode: g.code, isMaster: true)
            : MasterRoomScreen(gameCode: g.code, gameName: g.name),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _end(({String code, String name, String status}) g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar la sesión'),
        content: Text('Se borrará la partida «${g.name}» por completo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminar sesión'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    // El aviso desaparece al instante; la partida se borra en segundo plano
    setState(() => _dismissed.add(g.code));
    try {
      await GameService().endGame(g.code);
    } catch (e) {
      if (!mounted) return;
      setState(() => _dismissed.remove(g.code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo terminar la sesión: $e')),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({String code, String name, String status})?>(
      future: _future,
      builder: (context, snap) {
        final g = snap.data;
        if (g == null || _dismissed.contains(g.code)) {
          return const SizedBox.shrink();
        }

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Card(
            color: Colors.deepPurple.shade50,
            child: ListTile(
              leading: const Icon(Icons.play_circle_outline, size: 34),
              title: Text('Tienes una partida activa: ${g.name}'),
              subtitle: Text(
                'Código ${g.code} · '
                '${g.status == 'playing' ? 'en juego' : 'en la sala'}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  TextButton(
                    onPressed: () => _end(g),
                    child: const Text('Terminar'),
                  ),
                  ElevatedButton(
                    onPressed: () => _resume(g),
                    child: const Text('Reanudar'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
