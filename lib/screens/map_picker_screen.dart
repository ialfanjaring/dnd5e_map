import 'package:flutter/material.dart';

import '../models/map_template.dart';
import '../services/map_service.dart';
import '../widgets/map_preview.dart';
import 'map_editor_screen.dart';
import '../i18n/i18n.dart';
import '../widgets/options_button.dart';

/// Biblioteca de mapas: predeterminados y creados por el Master.
///
/// Con [gameCode] permite cargar un mapa en la partida; sin él solo sirve
/// para gestionar los mapas propios.
class MapPickerScreen extends StatelessWidget {
  final String? gameCode;

  /// true cuando se muestra como apartado de la pantalla principal
  final bool embedded;

  const MapPickerScreen({super.key, this.gameCode, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(gameCode == null ? tr('Mapas') : tr('Elegir mapa')),
          actions: [if (embedded) const OptionsButton()],
          bottom: TabBar(
            tabs: [
              Tab(text: tr('Predeterminados')),
              Tab(text: tr('Mis mapas')),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MapEditorScreen()),
          ),
          icon: const Icon(Icons.add),
          label: const Tx('Crear mapa'),
        ),
        body: SafeArea(top: false, child: TabBarView(
          children: [
            _MapGrid(
              maps: DefaultMaps.all,
              gameCode: gameCode,
              owned: false,
            ),
            StreamBuilder<List<MapTemplate>>(
              stream: MapService().myMaps(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Text('No se pudieron cargar tus mapas.\n${snap.error}',
                        textAlign: TextAlign.center),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.data!.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Tx(
                        'Todavía no has creado ningún mapa.\n'
                        'Pulsa «Crear mapa» o duplica uno predeterminado.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return _MapGrid(
                  maps: snap.data!,
                  gameCode: gameCode,
                  owned: true,
                );
              },
            ),
          ],
        )),
      ),
    );
  }
}

class _MapGrid extends StatelessWidget {
  final List<MapTemplate> maps;
  final String? gameCode;
  final bool owned;

  const _MapGrid({
    required this.maps,
    required this.gameCode,
    required this.owned,
  });

  Future<void> _use(BuildContext context, MapTemplate m) async {
    final code = gameCode;
    if (code == null) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Usar «{n}»').replaceAll('{n}', m.name)),
        content: const Tx(
          'Sustituye el mapa actual de la partida. Las fichas se mantienen '
          'y, si quedan fuera, se acercan al borde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Usar mapa'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await MapService().applyToGame(code, m);
      navigator.pop(true);
      messenger.showSnackBar(SnackBar(content: Text(tr('Mapa «{n}» cargado.').replaceAll('{n}', m.name))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${tr('No se pudo cargar')}: $e')));
    }
  }

  Future<void> _delete(BuildContext context, MapTemplate m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Eliminar mapa'),
        content: Text(tr('¿Eliminar «{n}»? No afecta a partidas ya creadas.').replaceAll('{n}', m.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true && m.id != null) await MapService().delete(m.id!);
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 250,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: maps.length,
      itemBuilder: (context, i) {
        final m = maps[i];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: gameCode == null
                ? (owned
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MapEditorScreen(initial: m),
                          ),
                        )
                    : null)
                : () => _use(context, m),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Center(child: MapPreview(map: m))),
                  const SizedBox(height: 8),
                  Text(
                    m.builtIn ? tr(m.name) : m.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${m.cols} × ${m.rows}${m.floorCount > 1 ? ' · ${m.floorCount} ${tr('pisos')}' : ''}'
                    '${m.description.isEmpty ? '' : ' · ${m.builtIn ? tr(m.description) : m.description}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!owned)
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapEditorScreen(initial: m),
                            ),
                          ),
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Tx('Duplicar'),
                        ),
                      if (owned) ...[
                        IconButton(
                          tooltip: tr('Editar'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MapEditorScreen(initial: m),
                            ),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 20),
                        ),
                        IconButton(
                          tooltip: tr('Eliminar'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _delete(context, m),
                          icon: const Icon(Icons.delete_outline, size: 20),
                        ),
                      ],
                    ],
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
