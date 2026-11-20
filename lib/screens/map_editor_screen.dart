import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../models/map_template.dart';
import '../services/map_service.dart';
import '../widgets/game_board.dart';
import '../widgets/terrain_painter.dart';
import '../widgets/terrain_picker.dart';
import '../i18n/i18n.dart';
import '../utils/orientation.dart';

/// Editor de mapas del Master: nombre, tamaño y terreno.
class MapEditorScreen extends StatefulWidget {
  /// Mapa de partida (para editar uno propio o duplicar uno predeterminado).
  final MapTemplate? initial;

  const MapEditorScreen({super.key, this.initial});

  @override
  State<MapEditorScreen> createState() => _MapEditorScreenState();
}

class _MapEditorScreenState extends State<MapEditorScreen> {
  final _service = MapService();
  late final TextEditingController _nameCtrl;

  late int _cols;
  late int _rows;
  late List<Map<String, String>> _floors;
  late List<String> _names;
  int _cur = 0;

  Map<String, String> get _cells => _floors[_cur];

  /// null = goma de borrar
  String? _brush = 'stone';
  int _fit = 0;
  bool _saving = false;

  bool get _isNew => widget.initial?.id == null;

  @override
  void initState() {
    super.initState();
    AppOrientation.landscape();
    final m = widget.initial;
    _nameCtrl = TextEditingController(
      text: m == null
          ? ''
          : (m.builtIn ? '${m.name} (copia)' : m.name),
    );
    _cols = m?.cols ?? 20;
    _rows = m?.rows ?? 14;
    _floors = [
      for (var i = 0; i < (m?.floorCount ?? 1); i++) {...?m?.floorCells(i)},
    ];
    _names = [
      for (var i = 0; i < _floors.length; i++)
        m == null ? 'Piso ${i + 1}' : m.floorName(i),
    ];
  }

  @override
  void dispose() {
    AppOrientation.portrait();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _paint(int x, int y) {
    setState(() {
      final key = cellKey(x, y);
      if (_brush == null) {
        _cells.remove(key);
      } else {
        _cells[key] = _brush!;
      }
    });
  }

  void _resize(int cols, int rows) {
    setState(() {
      _cols = cols.clamp(MapTemplate.minSize, MapTemplate.maxCols).toInt();
      _rows = rows.clamp(MapTemplate.minSize, MapTemplate.maxRows).toInt();
      // Se descartan las casillas que quedan fuera (en todos los pisos)
      for (final f in _floors) {
        f.removeWhere((k, _) {
          final p = k.split('_');
          final x = int.tryParse(p[0]) ?? 0;
          final y = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
          return x >= _cols || y >= _rows;
        });
      }
      _fit++;
    });
  }

  void _addFloor() {
    if (_floors.length >= 6) return;
    setState(() {
      _floors.add({});
      _names.add('Piso ${_floors.length}');
      _cur = _floors.length - 1;
    });
  }

  Future<void> _removeFloor() async {
    if (_floors.length < 2) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Quitar piso'),
        content: Text('${tr('Se borrará el terreno de')} «${_names[_cur]}».'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _floors.removeAt(_cur);
      _names.removeAt(_cur);
      _cur = _cur.clamp(0, _floors.length - 1).toInt();
    });
  }

  Future<void> _renameFloor() async {
    final ctrl = TextEditingController(text: _names[_cur]);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Nombre del piso'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Tx('Guardar'),
          ),
        ],
      ),
    );
    if (v != null && v.isNotEmpty && mounted) {
      setState(() => _names[_cur] = v);
    }
  }

  /// Selector de pisos (hojas del mapa).
  Widget _floorBar() {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Icon(Icons.layers_outlined, size: 18),
        for (var i = 0; i < _floors.length; i++)
          ChoiceChip(
            selected: _cur == i,
            visualDensity: VisualDensity.compact,
            label: Text(tr(_names[i])),
            onSelected: (_) => setState(() => _cur = i),
          ),
        IconButton(
          tooltip: tr('Añadir piso'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _floors.length >= 6 ? null : _addFloor,
        ),
        IconButton(
          tooltip: tr('Renombrar piso'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.edit_outlined),
          onPressed: _renameFloor,
        ),
        IconButton(
          tooltip: tr('Quitar piso'),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: _floors.length < 2 ? null : _removeFloor,
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Tx('Ponle un nombre al mapa.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.save(MapTemplate(
        id: widget.initial?.builtIn == true ? null : widget.initial?.id,
        name: name,
        cols: _cols,
        rows: _rows,
        cells: _floors.first,
        extraFloors: _floors.sublist(1),
        floorNames: _names,
      ));
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(_isNew ? 'Nuevo mapa' : 'Editar mapa')),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Tx('Guardar'),
          ),
        ],
      ),
      body: OrientationBuilder(
        builder: (context, orientation) {
          final board = GameBoard(
            cols: _cols,
            rows: _rows,
            terrain: Map.of(_cells),
            tokens: const [],
            selectedId: null,
            colorOf: (_) => Colors.grey,
            nameOf: (_) => '',
            paintMode: true,
            fitSignal: _fit,
            onCellTap: (_, __) {},
            onCellPaint: _paint,
          );

          final nameField = TextField(
            controller: _nameCtrl,
            maxLength: 40,
            decoration: InputDecoration(
              labelText: tr('Nombre del mapa'),
              border: const OutlineInputBorder(),
              counterText: '',
              isDense: true,
            ),
          );
          final steppers = [
            _stepper('Columnas', _cols, MapTemplate.minSize,
                MapTemplate.maxCols, (v) => _resize(v, _rows)),
            _stepper('Filas', _rows, MapTemplate.minSize,
                MapTemplate.maxRows, (v) => _resize(_cols, v)),
          ];
          final erase = ChoiceChip(
            selected: _brush == null,
            avatar: const Icon(Icons.cleaning_services, size: 16),
            label: const Tx('Borrar'),
            onSelected: (_) => setState(() => _brush = null),
          );
          final picker = Opacity(
            opacity: _brush == null ? 0.45 : 1,
            child: TerrainPicker(
              brush: _brush ?? 'stone',
              onChanged: (v) => setState(() => _brush = v),
            ),
          );
          final clear = TextButton.icon(
            onPressed: () => setState(() => _cells.clear()),
            icon: const Icon(Icons.layers_clear),
            label: const Tx('Vaciar'),
          );

          // Horizontal: herramientas en un panel a la izquierda
          if (orientation == Orientation.landscape) {
            return Row(
              children: [
                SizedBox(
                  width: 280,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        nameField,
                        const SizedBox(height: 8),
                        ...steppers,
                        const Divider(),
                        _floorBar(),
                        const Divider(),
                        Wrap(spacing: 6, children: [erase, clear]),
                        picker,
                      ],
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: board),
              ],
            );
          }

          // Vertical: herramientas arriba
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(width: 260, child: nameField),
                    ...steppers,
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _floorBar(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final v = await showTerrainDialog(
                            context, _brush ?? 'stone');
                        if (v != null) setState(() => _brush = v);
                      },
                      icon: _brush == null
                          ? const Icon(Icons.brush)
                          : TerrainSwatch(
                              type: Terrains.parse(_brush).type!, size: 22),
                      label: const Tx('Terreno'),
                    ),
                    erase,
                    clear,
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(child: board),
            ],
          );
        },
      ),
    );
  }

  Widget _stepper(
    String label,
    int value,
    int min,
    int max,
    void Function(int) onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${tr(label)}: '),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
