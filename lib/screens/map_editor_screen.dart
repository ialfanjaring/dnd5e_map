import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../models/map_template.dart';
import '../services/map_service.dart';
import '../widgets/game_board.dart';
import '../i18n/i18n.dart';

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
  late Map<String, String> _cells;

  /// null = goma de borrar
  String? _brush = 'wall';
  int _fit = 0;
  bool _saving = false;

  bool get _isNew => widget.initial?.id == null;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _nameCtrl = TextEditingController(
      text: m == null
          ? ''
          : (m.builtIn ? '${m.name} (copia)' : m.name),
    );
    _cols = m?.cols ?? 20;
    _rows = m?.rows ?? 14;
    _cells = {...?m?.cells};
  }

  @override
  void dispose() {
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
      // Se descartan las casillas que quedan fuera
      _cells.removeWhere((k, _) {
        final p = k.split('_');
        final x = int.tryParse(p[0]) ?? 0;
        final y = int.tryParse(p.length > 1 ? p[1] : '0') ?? 0;
        return x >= _cols || y >= _rows;
      });
      _fit++;
    });
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
        cells: _cells,
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
        title: Text(_isNew ? 'Nuevo mapa' : 'Editar mapa'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Tx('Guardar'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _nameCtrl,
                    maxLength: 40,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del mapa',
                      border: OutlineInputBorder(),
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                _stepper('Columnas', _cols, MapTemplate.minSize,
                    MapTemplate.maxCols, (v) => _resize(v, _rows)),
                _stepper('Filas', _rows, MapTemplate.minSize,
                    MapTemplate.maxRows, (v) => _resize(_cols, v)),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final t in Terrains.all)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      selected: _brush == t.id,
                      avatar: Icon(t.icon, size: 16, color: Color(t.color)),
                      label: Text(t.name),
                      onSelected: (_) => setState(() => _brush = t.id),
                    ),
                  ),
                ChoiceChip(
                  selected: _brush == null,
                  avatar: const Icon(Icons.cleaning_services, size: 16),
                  label: const Tx('Borrar'),
                  onSelected: (_) => setState(() => _brush = null),
                ),
                const SizedBox(width: 6),
                TextButton.icon(
                  onPressed: () => setState(() => _cells.clear()),
                  icon: const Icon(Icons.layers_clear),
                  label: const Tx('Vaciar'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GameBoard(
              cols: _cols,
              rows: _rows,
              terrain: _cells,
              tokens: const [],
              selectedId: null,
              colorOf: (_) => Colors.grey,
              nameOf: (_) => '',
              paintMode: true,
              fitSignal: _fit,
              onCellTap: (_, __) {},
              onCellPaint: _paint,
            ),
          ),
        ],
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
        Text('$label: '),
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
