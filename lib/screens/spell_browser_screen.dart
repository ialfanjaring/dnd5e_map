import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/character.dart';
import '../services/class_api_service.dart';
import '../services/translation_service.dart';
import '../widgets/spell_widgets.dart';

/// Texto sin mayúsculas ni tildes, para buscar sin preocuparse de ellas.
String foldText(String s) {
  const a = 'áàäâéèëêíìïîóòöôúùüûñç';
  const b = 'aaaaeeeeiiiioooouuuunc';
  var o = s.toLowerCase();
  for (var i = 0; i < a.length; i++) {
    o = o.replaceAll(a[i], b[i]);
  }
  return o;
}

/// Nombre de un hechizo en el idioma de la app (español si está en el SRD).
String spellName(String enName) => SrdEs.get('spells', enName, 'n') ?? enName;

/// Pantalla para consultar todos los hechizos (también desde la partida).
class SpellBrowserScreen extends StatelessWidget {
  const SpellBrowserScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Tx('Hechizos', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: const SpellBrowserView(),
    );
  }
}

/// Buscador de hechizos: nombre (español o inglés), nivel y clase.
class SpellBrowserView extends StatefulWidget {
  const SpellBrowserView({super.key});

  @override
  State<SpellBrowserView> createState() => _SpellBrowserViewState();
}

class _SpellBrowserViewState extends State<SpellBrowserView> {
  final _api = ClassApiService();
  final _search = TextEditingController();
  late Future<List<ApiSpellRef>> _future;

  String _query = '';
  int? _level; // null = todos
  String? _class; // índice de clase
  Set<String>? _classSpells;
  bool _showFilters = false;
  bool _loadingClass = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
    SrdEs.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<List<ApiSpellRef>> _load() async {
    final all = await _api.fetchAllSpells();
    return all.values.toList()
      ..sort((a, b) {
        final c = (a.level ?? 99).compareTo(b.level ?? 99);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
  }

  Future<void> _pickClass(String? idx) async {
    if (idx == null) {
      setState(() {
        _class = null;
        _classSpells = null;
      });
      return;
    }
    setState(() {
      _class = idx;
      _loadingClass = true;
    });
    try {
      final l = await _api.fetchClassSpells(idx);
      if (!mounted) return;
      setState(() => _classSpells = l.map((e) => e.index).toSet());
    } catch (_) {
      if (mounted) setState(() => _classSpells = null);
    } finally {
      if (mounted) setState(() => _loadingClass = false);
    }
  }

  int get _activeFilters => (_level != null ? 1 : 0) + (_class != null ? 1 : 0);

  String _levelText(int? l) =>
      l == null ? '' : (l == 0 ? tr('Truco') : '${tr('Nivel')} $l');

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = foldText(v.trim())),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixIcon: const Icon(Icons.search),
                        hintText: tr('Buscar hechizo…'),
                        border: const OutlineInputBorder(),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(() {
                                  _search.clear();
                                  _query = '';
                                }),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: _activeFilters > 0,
                    label: Text('$_activeFilters'),
                    child: IconButton.filledTonal(
                      tooltip: tr('Filtros'),
                      icon: Icon(_showFilters ? Icons.expand_less : Icons.tune),
                      onPressed: () => setState(() => _showFilters = !_showFilters),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: !_showFilters
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 0,
                            children: [
                              ChoiceChip(
                                label: Text(tr('Todos')),
                                selected: _level == null,
                                onSelected: (_) => setState(() => _level = null),
                              ),
                              for (var l = 0; l <= 9; l++)
                                ChoiceChip(
                                  label: Text(l == 0 ? tr('Truco') : '$l'),
                                  selected: _level == l,
                                  onSelected: (_) => setState(() => _level = l),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String?>(
                            value: _class,
                            isDense: true,
                            decoration: InputDecoration(
                              labelText: tr('Clase'),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(tr('Todas')),
                              ),
                              for (final c in DndData.spellcastingClasses)
                                DropdownMenuItem<String?>(
                                  value: c,
                                  child: Text(DndData.className(c)),
                                ),
                            ],
                            onChanged: _pickClass,
                          ),
                        ],
                      ),
                    ),
            ),
            if (_loadingClass) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: FutureBuilder<List<ApiSpellRef>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${snap.error}', textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: () => setState(() => _future = _load()),
                              child: Text(tr('Reintentar')),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final list = snap.data!.where((s) {
                    if (_level != null && s.level != _level) return false;
                    if (_classSpells != null && !_classSpells!.contains(s.index)) {
                      return false;
                    }
                    if (_query.isEmpty) return true;
                    return foldText(s.name).contains(_query) ||
                        foldText(spellName(s.name)).contains(_query);
                  }).toList();
                  if (list.isEmpty) {
                    return Center(child: Text(tr('Sin resultados')));
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final s = list[i];
                      final es = spellName(s.name);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          dense: true,
                          onTap: () => showSpellDetail(context, s.index, s.name),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              s.level == null ? '?' : (s.level == 0 ? 'T' : '${s.level}'),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          ),
                          title: Text(
                            es,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            es == s.name
                                ? _levelText(s.level)
                                : '${s.name} · ${_levelText(s.level)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
