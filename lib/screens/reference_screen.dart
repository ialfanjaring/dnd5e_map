import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/character.dart';
import '../services/class_api_service.dart';
import '../widgets/app_icon.dart';
import '../widgets/options_button.dart';
import 'class_info_screen.dart';
import 'race_info_screen.dart';
import 'spell_browser_screen.dart';

/// Apartado «Libro»: clases y razas en tarjetas visuales y buscador de
/// hechizos.
class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key});

  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen> {
  int _section = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Tx('Libro', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: const [OptionsButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 0,
                  icon: const Icon(Icons.shield_outlined),
                  label: Text(tr('Clases')),
                ),
                ButtonSegment(
                  value: 1,
                  icon: const Icon(Icons.groups_outlined),
                  label: Text(tr('Razas')),
                ),
                ButtonSegment(
                  value: 2,
                  icon: const Icon(Icons.auto_fix_high),
                  label: Text(tr('Hechizos')),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (s) => setState(() => _section = s.first),
            ),
          ),
          Expanded(
            child: switch (_section) {
              0 => const _ClassGrid(),
              1 => const _RaceGrid(),
              _ => const SpellBrowserView(),
            },
          ),
        ],
      ),
    );
  }
}

/// Aspecto de cada clase: icono propio (o de Material), color y lema.
typedef _Look = ({String? asset, IconData? icon, Color color, String role});

const Map<String, _Look> _classLook = {
  'barbarian': (asset: 'clase_barbaro', icon: null, color: Color(0xFFB71C1C), role: 'Furia y resistencia'),
  'bard': (asset: 'clase_bardo', icon: null, color: Color(0xFFAD1457), role: 'Música y magia'),
  'cleric': (asset: 'clase_clerigo', icon: null, color: Color(0xFFB26A00), role: 'Sanador divino'),
  'druid': (asset: 'clase_druida', icon: null, color: Color(0xFF2E7D32), role: 'Magia de la naturaleza'),
  'fighter': (asset: 'espadas', icon: null, color: Color(0xFF455A64), role: 'Maestro del combate'),
  'monk': (asset: 'clase_monje', icon: null, color: Color(0xFF00796B), role: 'Artes marciales y ki'),
  'paladin': (asset: 'clase_paladin', icon: null, color: Color(0xFF283593), role: 'Guerrero sagrado'),
  'ranger': (asset: 'arco', icon: null, color: Color(0xFF558B2F), role: 'Explorador y cazador'),
  'rogue': (asset: 'daga', icon: null, color: Color(0xFF37474F), role: 'Sigilo y precisión'),
  'sorcerer': (asset: 'clase_hechicero', icon: null, color: Color(0xFFD84315), role: 'Magia innata'),
  'warlock': (asset: 'ojo', icon: null, color: Color(0xFF6A1B9A), role: 'Pacto con un patrón'),
  'wizard': (asset: 'varita', icon: null, color: Color(0xFF1565C0), role: 'Erudito arcano'),
};

const List<Color> _raceColors = [
  Color(0xFF00796B), Color(0xFF6D4C41), Color(0xFF5E35B1), Color(0xFFC62828),
  Color(0xFF1565C0), Color(0xFF558B2F), Color(0xFFEF6C00), Color(0xFFAD1457),
  Color(0xFF00838F),
];

/// Cuadrícula que reparte las tarjetas por todo el espacio disponible, sin
/// necesidad de desplazarse.
Widget _gridOf(List<Widget> cards) {
  return LayoutBuilder(
    builder: (context, c) {
      const pad = 12.0;
      const gap = 10.0;
      // Ancho útil limitado para que en pantallas grandes no se estiren
      final aw = (c.maxWidth < 960 ? c.maxWidth : 960.0) - pad * 2;
      final ah = c.maxHeight - pad * 2;
      final n = cards.length;
      var bestCols = 2;
      var bestScore = double.infinity;
      for (var cols = 2; cols <= 6; cols++) {
        final rows = (n / cols).ceil();
        final cw = (aw - gap * (cols - 1)) / cols;
        final ch = (ah - gap * (rows - 1)) / rows;
        if (cw <= 0 || ch <= 0) continue;
        final score = ((cw / ch) - 1.0).abs();
        if (score < bestScore) {
          bestScore = score;
          bestCols = cols;
        }
      }
      final rows = (n / bestCols).ceil();
      final cw = (aw - gap * (bestCols - 1)) / bestCols;
      var ch = (ah - gap * (rows - 1)) / rows;
      if (ch > cw * 1.2) ch = cw * 1.2; // tarjetas casi cuadradas
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: gap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var k = 0; k < bestCols; k++) ...[
                    if (k > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: cw,
                      height: ch,
                      child: r * bestCols + k < n
                          ? cards[r * bestCols + k]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _Tile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _Tile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, Color.lerp(color, Colors.black, 0.45)!],
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 130,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.22),
                        ),
                        child: leading,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      if (badge != null) ...[
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassGrid extends StatefulWidget {
  const _ClassGrid();

  @override
  State<_ClassGrid> createState() => _ClassGridState();
}

class _ClassGridState extends State<_ClassGrid> {
  late Future<List<ApiRef>> _future;

  @override
  void initState() {
    super.initState();
    _future = () async {
      try {
        return await ClassApiService().fetchClassList();
      } catch (_) {
        return [
          for (final e in DndData.classNames.entries)
            ApiRef(index: e.key, name: e.value),
        ];
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ApiRef>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return _gridOf([
          for (final c in snap.data ?? const <ApiRef>[])
            Builder(builder: (context) {
              final look = _classLook[c.index];
              final color = look?.color ?? Colors.deepPurple;
              return _Tile(
                color: color,
                title: DndData.className(c.index),
                subtitle: look == null ? c.name : tr(look.role),
                badge: DndData.spellcastingClasses.contains(c.index)
                    ? '✦ ${tr('Lanza conjuros')}'
                    : null,
                leading: look?.asset != null
                    ? AppIcon(look!.asset!, size: 52)
                    : Icon(look?.icon ?? Icons.shield, size: 44, color: Colors.white),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClassInfoScreen(classIndex: c.index),
                  ),
                ),
              );
            }),
        ]);
      },
    );
  }
}

class _RaceGrid extends StatefulWidget {
  const _RaceGrid();

  @override
  State<_RaceGrid> createState() => _RaceGridState();
}

class _RaceGridState extends State<_RaceGrid> {
  late Future<List<ApiRef>> _future;

  @override
  void initState() {
    super.initState();
    _future = () async {
      try {
        return await ClassApiService().fetchRaceList();
      } catch (_) {
        return [
          for (final e in DndData.raceNames.entries)
            ApiRef(index: e.key, name: e.value),
        ];
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ApiRef>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final races = snap.data ?? const <ApiRef>[];
        return _gridOf([
          for (var i = 0; i < races.length; i++)
            _Tile(
              color: _raceColors[i % _raceColors.length],
              title: DndData.raceName(races[i].index),
              subtitle: races[i].name,
              leading: AppIcon(
                'raza_${races[i].index.replaceAll('-', '_')}',
                size: 52,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RaceInfoScreen(raceIndex: races[i].index),
                ),
              ),
            ),
        ]);
      },
    );
  }
}
