import 'package:flutter/material.dart';

import '../services/class_api_service.dart';
import '../widgets/spell_widgets.dart';
import 'spell_browser_screen.dart';
import '../i18n/i18n.dart';

class _PickerData {
  /// Hechizos entre los que se puede elegir
  final List<ApiSpellRef> spells;

  /// Todos los hechizos del SRD (para conocer el nivel de los ya elegidos)
  final Map<String, ApiSpellRef> all;

  /// Datos de la clase en el nivel del personaje (solo en modo clase)
  final ApiClassLevel? levelInfo;

  const _PickerData({
    required this.spells,
    required this.all,
    required this.levelInfo,
  });

  /// Nivel de conjuro más alto que puede lanzar a este nivel (null si no hay datos).
  int? get maxSpellLevel {
    final slots = levelInfo?.slots;
    if (slots == null || slots.isEmpty) return null;
    return slots.keys.reduce((a, b) => a > b ? a : b);
  }

  int levelOf(String index) => all[index]?.level ?? 0;
}

/// Elige hechizos de la D&D 5e SRD API y devuelve solo sus índices.
///
/// - Con [classIndex]: solo los hechizos de esa clase (personajes).
/// - Sin [classIndex]: todos los hechizos del SRD (NPC).
/// Los datos de los hechizos nunca se guardan; solo se guarda la lista elegida.
class SpellPickerScreen extends StatefulWidget {
  final String title;
  /// Índice de la clase en la API (ej. wizard)
  final String? classIndex;
  final int? characterLevel;
  final List<String> initial;

  const SpellPickerScreen({
    super.key,
    required this.title,
    this.classIndex,
    this.characterLevel,
    required this.initial,
  });

  @override
  State<SpellPickerScreen> createState() => _SpellPickerScreenState();
}

class _SpellPickerScreenState extends State<SpellPickerScreen> {
  final _api = ClassApiService();
  final _searchCtrl = TextEditingController();

  late Future<_PickerData> _future;
  final Set<String> _selected = {};

  String _query = '';
  int? _levelFilter; // null = todos
  bool _onlyCastable = true;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initial);
    _future = _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<_PickerData> _load() async {
    final classIndex = widget.classIndex;

    // MODO CLASE: hechizos de la clase + datos de su nivel
    if (classIndex != null) {
      final spells = await _api.fetchClassSpells(classIndex);

      // Los datos generales y los del nivel son un extra: si fallan se puede elegir igualmente
      Map<String, ApiSpellRef> all = const {};
      try {
        all = await _api.fetchAllSpells();
      } catch (_) {}

      ApiClassLevel? levelInfo;
      final level = widget.characterLevel;
      if (level != null) {
        try {
          for (final l in await _api.fetchLevels(classIndex)) {
            if (l.level == level) levelInfo = l;
          }
        } catch (_) {}
      }

      return _PickerData(spells: spells, all: all, levelInfo: levelInfo);
    }

    // MODO TODOS: cualquier hechizo del SRD
    final all = await _api.fetchAllSpells();
    final spells = all.values.toList()
      ..sort((a, b) {
        final byLevel = (a.level ?? 99).compareTo(b.level ?? 99);
        return byLevel != 0 ? byLevel : a.name.compareTo(b.name);
      });

    return _PickerData(spells: spells, all: all, levelInfo: null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(top: false, child: FutureBuilder<_PickerData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'No se pudieron cargar los hechizos.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _future = _load();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Tx('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          return _buildBody(snapshot.data!);
        },
      )),
    );
  }

  Widget _buildBody(_PickerData data) {
    final maxLevel = data.maxSpellLevel;
    final applyCastable = _onlyCastable && maxLevel != null;

    final presentLevels = data.spells
        .map((s) => s.level)
        .whereType<int>()
        .toSet()
        .toList()
      ..sort();

    final list = data.spells.where((s) {
      if (applyCastable && s.level != null && s.level! > maxLevel) {
        return false;
      }
      if (_levelFilter != null && s.level != _levelFilter) return false;
      if (_query.isNotEmpty && !s.name.toLowerCase().contains(_query)) {
        return false;
      }
      return true;
    }).toList();

    // Cabecera (información, búsqueda y filtros) dentro de la propia lista:
    // al desplazarse deja todo el espacio a los hechizos, también en horizontal.
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _infoLines(data),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            hintText: tr('Buscar hechizo...'),
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Tx('Todos'),
                  selected: _levelFilter == null,
                  onSelected: (_) => setState(() => _levelFilter = null),
                ),
              ),
              for (final level in presentLevels)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(level == 0 ? 'Trucos' : 'Nv. $level'),
                    selected: _levelFilter == level,
                    onSelected: (_) => setState(() => _levelFilter = level),
                  ),
                ),
            ],
          ),
        ),
        if (maxLevel != null)
          SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('Solo hasta nivel $maxLevel (los que puedes lanzar)'),
            value: _onlyCastable,
            onChanged: (v) => setState(() => _onlyCastable = v),
          ),
        const SizedBox(height: 4),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                // 0 = cabecera; si no hay resultados, un aviso
                itemCount: list.isEmpty ? 2 : list.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) return header;
                  if (list.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Tx(
                          'No hay hechizos que mostrar.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ),
                    );
                  }
                  return _tile(list[i - 1]);
                },
              ),
            ),
          ),
        ),

        // CONFIRMAR
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final result = _selected.toList()
                        ..sort((a, b) {
                          final byLevel =
                              data.levelOf(a).compareTo(data.levelOf(b));
                          return byLevel != 0 ? byLevel : a.compareTo(b);
                        });
                      Navigator.pop(context, result);
                    },
                    icon: const Icon(Icons.check),
                    label: Text('Guardar selección (${_selected.length})'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _infoLines(_PickerData data) {
    final cantrips = _selected.where((i) => data.levelOf(i) == 0).length;
    final spells = _selected.length - cantrips;

    // NPC: sin clase, solo se explica qué se guarda
    if (widget.classIndex == null) {
      return [
        const Tx(
          'Elige los hechizos que puede usar. Los datos de cada hechizo se '
          'consultan siempre en la API; solo se guarda la lista.',
        ),
        const SizedBox(height: 4),
        Text('Elegidos: $cantrips trucos, $spells conjuros'),
      ];
    }

    final l = data.levelInfo;
    final lines = <String>[];

    if (l?.cantripsKnown != null) {
      lines.add('Trucos conocidos: ${l!.cantripsKnown}  (elegidos: $cantrips)');
    }
    if (l?.spellsKnown != null) {
      lines.add('Conjuros conocidos: ${l!.spellsKnown}  (elegidos: $spells)');
    }
    if (l != null && l.slots.isNotEmpty) {
      lines.add(
        'Espacios de conjuro: '
        '${l.slots.entries.map((e) => '${e.key}º ×${e.value}').join(', ')}',
      );
    }

    if (lines.isEmpty) {
      lines.add(
        'No hay datos de conjuros para el nivel ${widget.characterLevel}; '
        'elige los que quieras (elegidos: $cantrips trucos, $spells conjuros).',
      );
    } else if (l?.spellsKnown == null) {
      lines.add(
        'Esta clase prepara conjuros: elige los que quieras llevar '
        '(elegidos: $spells).',
      );
    }

    return [
      Text(
        'Nivel ${widget.characterLevel}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      for (final line in lines) Text(line),
    ];
  }

  Widget _tile(ApiSpellRef s) {
    final selected = _selected.contains(s.index);

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: () => setState(() {
          if (selected) {
            _selected.remove(s.index);
          } else {
            _selected.add(s.index);
          }
        }),
        leading: Icon(
          selected ? Icons.check_box : Icons.check_box_outline_blank,
          color: Colors.deepPurple,
        ),
        title: Text(
          spellName(s.name),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(s.level == null ? '' : spellLevelLabel(s.level!)),
        trailing: IconButton(
          tooltip: tr('Ver hechizo'),
          icon: const Icon(Icons.info_outline),
          onPressed: () => showSpellDetail(context, s.index, s.name),
        ),
      ),
    );
  }
}
