import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/game_service.dart';
import 'characters_screen.dart';
import 'creatures_screen.dart';
import 'join_game_screen.dart';
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

                  const SizedBox(height: 40),

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
                              'Crea monstruos y NPC, o usa el bestiario ya '
                              'cargado, para añadirlos a tus partidas.',
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
