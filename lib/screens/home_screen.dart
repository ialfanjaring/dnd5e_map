import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import '../widgets/blocking_progress.dart';

import '../services/auth_service.dart';
import '../services/game_service.dart';
import 'characters_screen.dart';
import 'create_game_screen.dart';
import 'creatures_screen.dart';
import 'items_screen.dart';
import 'join_game_screen.dart';
import 'map_picker_screen.dart';
import 'reference_screen.dart';
import 'game_screen.dart';
import 'master_room_screen.dart';
import '../i18n/i18n.dart';
import '../services/translation_service.dart';
import '../settings/app_settings.dart';
import 'settings_screen.dart';
import '../widgets/app_icon.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Idioma y tema guardados del usuario
    AppSettings.instance.load();
    SrdEs.ensureLoaded();
  }

  int _tab = 0;
  final Set<int> _visited = {0};

  /// Apartados de la barra inferior: (título, icono).
  static const List<(String, String)> _tabs = [
    ('Partidas', 'castillo'),
    ('Personajes', 'yelmo'),
    ('Bestiario', 'calavera'),
    ('Objetos', 'cofre'),
    ('Mapas', 'mapa'),
    ('Libro', 'libro_hechizos'),
  ];

  void _open(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  /// Contenido centrado y con scroll de cada apartado.
  Widget _scrollPage(List<Widget> children) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }


  Widget _gamesPage(User? user) {
    return _scrollPage([
      Image.asset('assets/icons/logo_app.png', width: 96, height: 96),
      const SizedBox(height: 10),
      const Tx(
        'Bienvenido a D&D 5e',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      Text(
        user?.email ?? tr('Usuario autenticado'),
        style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
      ),
      const SizedBox(height: 16),

      // Todas mis partidas como Master (para reconectarse)
      const _ActiveGameBanner(),

      const SizedBox(height: 12),
      _MenuCard(
        asset: 'castillo',
        title: tr('Crear partida'),
        description: 'Crea una nueva campaña, prepara el mapa '
            'y administra tu aventura como Master.',
        buttonText: tr('Crear partida'),
        color: Colors.deepPurple,
        onTap: () => _open(const CreateGameScreen()),
      ),
      const SizedBox(height: 12),
      _MenuCard(
        asset: 'llave',
        title: tr('Unirse a partida'),
        description: 'Introduce el código de una campaña '
            'para unirte a la aventura como jugador.',
        buttonText: tr('Unirse a partida'),
        color: Colors.teal,
        onTap: () => _open(const JoinGameScreen()),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final User? user = authService.currentUser;

    // Los apartados se crean al visitarlos por primera vez
    Widget lazy(int i, Widget Function() build) =>
        _visited.contains(i) ? build() : const SizedBox.shrink();

    final pages = <Widget>[
      _gamesPage(user),
      lazy(1, () => const CharactersScreen(embedded: true)),
      lazy(2, () => const CreaturesScreen(embedded: true)),
      lazy(3, () => const ItemsScreen(embedded: true)),
      lazy(4, () => const MapPickerScreen(embedded: true)),
      lazy(5, () => const ReferenceScreen()),
    ];

    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => Scaffold(
        // Los demás apartados llevan su propia barra superior
        appBar: _tab != 0
            ? null
            : AppBar(
          title: const Tx(
            'D&D 5e',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: () => _open(const SettingsScreen()),
              icon: const AppIcon('opciones', size: 28),
              tooltip: tr('Opciones'),
            ),
          ],
        ),
        body: IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: NavigationBar(
          height: 66,
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() {
            _tab = i;
            _visited.add(i);
          }),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final (title, asset) in _tabs)
              NavigationDestination(
                icon: Opacity(opacity: 0.7, child: AppIcon(asset, size: 30)),
                selectedIcon: AppIcon(asset, size: 34),
                label: tr(title),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TARJETA REUTILIZABLE DEL MENÚ
// ==========================================

class _MenuCard extends StatelessWidget {
  final String asset;
  final String title;
  final String description;
  final String buttonText;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.asset,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: color.withOpacity(0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withOpacity(0.45), width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AppIcon(asset, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(title),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(description),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: color, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}


/// Si el Master tiene una partida activa en la base de datos, permite
/// reconectarse (por ejemplo, tras salirse sin querer). De paso borra sus
/// partidas inactivas de más de 24 horas.
typedef _MyGame = ({String code, String name, String status});

/// Lista de todas las partidas que tengo creadas como Master, para
/// reanudarlas o terminarlas desde la pantalla principal.
class _ActiveGameBanner extends StatefulWidget {
  const _ActiveGameBanner();

  @override
  State<_ActiveGameBanner> createState() => _ActiveGameBannerState();
}

class _ActiveGameBannerState extends State<_ActiveGameBanner> {
  late Future<List<_MyGame>> _future;

  /// Partidas que el Master acaba de terminar: no se vuelven a mostrar.
  final Set<String> _dismissed = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<_MyGame>> _load() => GameService()
      .cleanupAndFindMyGames()
      .catchError((_) => <_MyGame>[]);

  void _refresh() {
    final next = _load();
    setState(() {
      _future = next;
    });
  }

  Future<void> _resume(_MyGame g) async {
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

  Future<void> _end(_MyGame g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Terminar la sesión'),
        content: Text(tr('Se borrará la partida «{n}» por completo.').replaceAll('{n}', g.name)),
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
    if (ok != true) return;

    // El aviso desaparece al instante; la partida se borra en segundo plano
    setState(() => _dismissed.add(g.code));
    try {
      await runBlocking(
        context,
        tr('Terminando la sesión…'),
        () => GameService().endGame(g.code),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _dismissed.remove(g.code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('No se pudo terminar la sesión')}: $e')),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_MyGame>>(
      future: _future,
      builder: (context, snap) {
        final games = (snap.data ?? const <_MyGame>[])
            .where((g) => !_dismissed.contains(g.code))
            .toList();
        final loading = snap.connectionState != ConnectionState.done;

        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        games.isEmpty
                            ? tr('No tienes partidas creadas.')
                            : tr('Tus partidas'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: tr('Actualizar partidas'),
                          icon: const Icon(Icons.refresh),
                          onPressed: _refresh,
                        ),
                ],
              ),
              for (final g in games)
                Card(
                  color: Colors.deepPurple.withOpacity(0.16),
                  child: ListTile(
                    leading: const AppIcon('castillo', size: 40),
                    title: Text(
                      g.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${tr('Código')} ${g.code} · '
                      '${g.status == 'playing' ? tr('en juego') : tr('en la sala')}',
                    ),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        TextButton(
                          onPressed: () => _end(g),
                          child: const Tx('Terminar'),
                        ),
                        ElevatedButton(
                          onPressed: () => _resume(g),
                          child: const Tx('Reanudar'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
