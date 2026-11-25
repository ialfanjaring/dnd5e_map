import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../screens/spell_browser_screen.dart';
import '../services/class_api_service.dart';
import 'spell_widgets.dart';

/// Espacios de conjuro (gastados / disponibles) y hechizos de un
/// personaje, NPC o monstruo. Se usa en la ficha del jugador y en la
/// ventana de combate.
///
/// Los espacios gastados se guardan en la partida; el nombre y el nivel de
/// cada hechizo se consultan a la API.
class SpellcastingPanel extends StatefulWidget {
  final Map<int, int> maxSlots;
  final Map<int, int> used;

  /// Índices de la API de los hechizos disponibles
  final List<String> spells;

  /// Puede gastar y recuperar espacios, y lanzar hechizos
  final bool canEdit;
  final ValueChanged<Map<int, int>> onUsedChanged;

  /// Si se indica, se pueden configurar los máximos (NPC sin datos de la API)
  final ValueChanged<Map<int, int>>? onMaxChanged;

  /// false: solo los espacios de conjuro (la lista va aparte)
  final bool showSpellList;

  const SpellcastingPanel({
    super.key,
    required this.maxSlots,
    required this.used,
    required this.spells,
    required this.canEdit,
    required this.onUsedChanged,
    this.onMaxChanged,
    this.showSpellList = true,
  });

  @override
  State<SpellcastingPanel> createState() => _SpellcastingPanelState();
}

class _SpellcastingPanelState extends State<SpellcastingPanel> {
  late Map<int, int> _used;
  Future<List<ApiSpell>>? _spellsFuture;
  String _spellsKey = '';

  @override
  void initState() {
    super.initState();
    _used = {...widget.used};
    _loadSpells();
  }

  @override
  void didUpdateWidget(covariant SpellcastingPanel old) {
    super.didUpdateWidget(old);
    _used = {...widget.used};
    _loadSpells();
  }

  void _loadSpells() {
    final key = widget.spells.join(',');
    if (key == _spellsKey && _spellsFuture != null) return;
    _spellsKey = key;
    final api = ClassApiService();
    _spellsFuture = Future.wait(widget.spells.map((i) async {
      try {
        return await api.fetchSpell(i);
      } catch (_) {
        return null;
      }
    })).then((l) => l.whereType<ApiSpell>().toList());
  }

  int _max(int level) => widget.maxSlots[level] ?? 0;
  int _usedAt(int level) => (_used[level] ?? 0).clamp(0, _max(level)).toInt();
  int _free(int level) => _max(level) - _usedAt(level);

  void _setUsed(int level, int value) {
    setState(() {
      if (value <= 0) {
        _used.remove(level);
      } else {
        _used[level] = value;
      }
    });
    widget.onUsedChanged({..._used});
  }

  void _longRest() {
    setState(() => _used = {});
    widget.onUsedChanged({});
  }

  Future<void> _cast(ApiSpell sp) async {
    final options = [
      for (final l in widget.maxSlots.keys)
        if (l >= sp.level && _free(l) > 0) l,
    ]..sort();

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('No quedan espacios de conjuro para este hechizo.'))),
      );
      return;
    }

    var level = options.first;
    if (options.length > 1) {
      final picked = await showDialog<int>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text('${tr('Lanzar')} ${spellName(sp.name)}'),
          children: [
            for (final l in options)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, l),
                child: Text(
                  '${tr('Espacio de nivel')} $l '
                  '(${_free(l)} ${tr('disponibles')})'
                  '${l > sp.level ? ' · ${tr('a nivel superior')}' : ''}',
                ),
              ),
          ],
        ),
      );
      if (picked == null || !mounted) return;
      level = picked;
    }
    _setUsed(level, _usedAt(level) + 1);
  }

  Future<void> _editMax() async {
    final edited = {...widget.maxSlots};
    final result = await showDialog<Map<int, int>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Tx('Espacios de conjuro'),
          content: SizedBox(
            width: 320,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var l = 1; l <= 9; l++)
                    Row(
                      children: [
                        Expanded(child: Text('${tr('Nivel')} $l')),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: (edited[l] ?? 0) > 0
                              ? () => setS(() {
                                    final n = (edited[l] ?? 0) - 1;
                                    if (n <= 0) {
                                      edited.remove(l);
                                    } else {
                                      edited[l] = n;
                                    }
                                  })
                              : null,
                        ),
                        SizedBox(
                          width: 24,
                          child: Text('${edited[l] ?? 0}',
                              textAlign: TextAlign.center),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: (edited[l] ?? 0) < 9
                              ? () => setS(() => edited[l] = (edited[l] ?? 0) + 1)
                              : null,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Tx('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, edited),
              child: const Tx('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result != null) widget.onMaxChanged?.call(result);
  }

  Widget _pip(int level, int index) {
    final cs = Theme.of(context).colorScheme;
    final free = _free(level);
    final available = index < free;
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: widget.canEdit
          ? () => _setUsed(
                level,
                available ? _usedAt(level) + 1 : _usedAt(level) - 1,
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: available ? cs.primary : Colors.transparent,
            border: Border.all(color: cs.primary, width: 2),
          ),
          child: available
              ? null
              : Icon(Icons.close, size: 14, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _slots() {
    final levels = widget.maxSlots.keys.toList()..sort();
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Tx(
                'Espacios de conjuro',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.onMaxChanged != null)
              IconButton(
                tooltip: tr('Configurar espacios'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.tune, size: 20),
                onPressed: _editMax,
              ),
            if (widget.canEdit && levels.isNotEmpty)
              TextButton(
                onPressed: _longRest,
                child: const Tx('Descanso largo'),
              ),
          ],
        ),
        if (levels.isEmpty)
          Tx(
            'Sin espacios de conjuro.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          )
        else
          for (final l in levels)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text('${tr('Nivel')} $l',
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Expanded(
                    child: Wrap(
                      children: [
                        for (var i = 0; i < _max(l); i++) _pip(l, i),
                      ],
                    ),
                  ),
                  Text(
                    '${_free(l)}/${_max(l)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        if (levels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Tx(
              'Círculo lleno = disponible · con cruz = gastado. '
              'Toca un círculo para gastarlo o recuperarlo.',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  Widget _spellList() {
    if (widget.spells.isEmpty) {
      return const Tx('Sin hechizos.', style: TextStyle(fontSize: 12));
    }
    return FutureBuilder<List<ApiSpell>>(
      future: _spellsFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = [...?snap.data]..sort((a, b) {
            final c = a.level.compareTo(b.level);
            return c != 0 ? c : a.name.compareTo(b.name);
          });
        if (list.isEmpty) {
          return const Tx('No se pudieron cargar los hechizos.');
        }

        final cs = Theme.of(context).colorScheme;
        final widgets = <Widget>[];
        int? last;
        for (final sp in list) {
          if (sp.level != last) {
            last = sp.level;
            widgets.add(Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Text(
                spellLevelLabel(sp.level),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ));
          }
          final canCast = widget.canEdit &&
              sp.level > 0 &&
              widget.maxSlots.keys.any((l) => l >= sp.level && _free(l) > 0);
          widgets.add(ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(spellName(sp.name)),
            subtitle: Text(tr(sp.school)),
            onTap: () => showSpellDetail(context, sp.index, sp.name),
            trailing: sp.level == 0
                ? null
                : FilledButton.tonal(
                    onPressed: canCast ? () => _cast(sp) : null,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Tx('Lanzar'),
                  ),
          ));
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _slots(),
        if (widget.showSpellList) ...[
          const Divider(height: 20),
          const Tx('Hechizos', style: TextStyle(fontWeight: FontWeight.bold)),
          _spellList(),
        ],
      ],
    );
  }
}
