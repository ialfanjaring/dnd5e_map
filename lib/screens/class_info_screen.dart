import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/class_api_service.dart';
import '../services/translation_service.dart';
import '../widgets/spell_widgets.dart';
import '../i18n/i18n.dart';

/// Listado de clases de la API para consultar cualquiera de ellas.
class ClassesScreen extends StatefulWidget {
  const ClassesScreen({super.key});

  @override
  State<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends State<ClassesScreen> {
  late Future<List<ApiRef>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Si la API no responde se usan las clases básicas del SRD.
  Future<List<ApiRef>> _load() async {
    try {
      return await ClassApiService().fetchClassList();
    } catch (_) {
      return [
        for (final e in DndData.classNames.entries)
          ApiRef(index: e.key, name: e.value),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Tx(
          'Clases',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<List<ApiRef>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final classes = snapshot.data ?? const <ApiRef>[];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: classes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = classes[i];
                  final caster = DndData.spellcastingClasses.contains(c.index);

                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClassInfoScreen(classIndex: c.index),
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.deepPurple.withOpacity(0.28),
                        child: Text(DndData.className(c.index)[0]),
                      ),
                      title: Text(
                        DndData.className(c.index),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${c.name}${caster ? ' · Lanza conjuros' : ''}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Información de una clase: resumen, subidas de nivel, hechizos y subclases.
/// Los datos vienen de la D&D 5e SRD API (en español donde hay traducción).
class ClassInfoScreen extends StatefulWidget {
  /// Índice de la clase en la API (ej. wizard)
  final String classIndex;

  /// Si se indica, se resalta ese nivel en la tabla de niveles.
  final int? currentLevel;

  const ClassInfoScreen({
    super.key,
    required this.classIndex,
    this.currentLevel,
  });

  @override
  State<ClassInfoScreen> createState() => _ClassInfoScreenState();
}

class _ClassInfoScreenState extends State<ClassInfoScreen> {
  final _api = ClassApiService();

  late Future<ApiClass> _classFuture;
  late Future<List<ApiClassLevel>> _levelsFuture;
  late Future<List<ApiSpellRef>> _spellsFuture;

  String get _className => DndData.className(widget.classIndex);

  bool get _isCaster => DndData.spellcastingClasses.contains(widget.classIndex);

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final index = widget.classIndex;

    _classFuture = _api.fetchClass(index);
    _levelsFuture = _api.fetchLevels(index);
    _spellsFuture = _isCaster
        ? _api.fetchClassSpells(index)
        : Future.value(const <ApiSpellRef>[]);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'Resumen'),
      const Tab(text: 'Niveles'),
      if (_isCaster) const Tab(text: 'Hechizos'),
      const Tab(text: 'Subclases'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Clase: $_className',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          bottom: TabBar(tabs: tabs),
        ),
        body: TabBarView(
          children: [
            _async<ApiClass>(_classFuture, _summaryTab),
            _async<List<ApiClassLevel>>(_levelsFuture, _levelsTab),
            if (_isCaster)
              _async<List<ApiSpellRef>>(_spellsFuture, _spellsTab),
            _async<ApiClass>(_classFuture, _subclassesTab),
          ],
        ),
      ),
    );
  }

  /// Muestra carga / error con reintento / contenido centrado.
  Widget _async<T>(Future<T> future, Widget Function(T data) builder) {
    return FutureBuilder<T>(
      future: future,
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
                    'No se pudo conectar con la API.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => setState(_load),
                    icon: const Icon(Icons.refresh),
                    label: const Tx('Reintentar'),
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: builder(snapshot.data as T),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // RESUMEN
  // ---------------------------------------------------------------

  Widget _summaryTab(ApiClass c) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv('Dado de golpe', 'd${c.hitDie}'),
                _kv('Salvaciones', c.savingThrows.join(', ')),
                if (_isCaster && c.spellcastingAbility != null)
                  _kv('Característica de conjuros', c.spellcastingAbility!),
                if (_isCaster && c.spellcastingLevel != null)
                  _kv('Conjuros desde el nivel', '${c.spellcastingLevel}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _section(
          'Competencias',
          c.proficiencies.isEmpty
              ? const Tx('—')
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in c.proficiencies) Chip(label: Text(p)),
                  ],
                ),
        ),
        if (c.startingEquipment.isNotEmpty)
          _section(
            'Equipo inicial',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in c.startingEquipment) Text('• $e'),
              ],
            ),
          ),
        if (_isCaster && c.spellcastingInfo.isNotEmpty)
          _section(
            'Lanzamiento de conjuros',
            Column(
              children: [
                for (final info in c.spellcastingInfo)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(info.name),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          info.text,
                          style: const TextStyle(height: 1.4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Tx(
          'Datos de la D&D 5e SRD API (en español donde hay traducción).',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // NIVELES
  // ---------------------------------------------------------------

  Widget _levelsTab(List<ApiClassLevel> levels) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: levels.length,
      itemBuilder: (context, i) {
        final l = levels[i];
        final isCurrent = widget.currentLevel == l.level;

        final featureNames = l.features.map((f) => f.name).join(', ');

        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isCurrent ? Colors.deepPurple : Colors.transparent,
              width: 2,
            ),
          ),
          child: ExpansionTile(
            initiallyExpanded: isCurrent,
            leading: isCurrent
                ? const Icon(Icons.star, color: Colors.deepPurple)
                : CircleAvatar(
                    radius: 14,
                    child: Text(
                      '${l.level}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
            title: Text(
              'Nivel ${l.level}'
              '${isCurrent ? ' (tu nivel)' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              featureNames.isEmpty ? 'Sin rasgos nuevos' : featureNames,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kv('Bonificador de competencia', '+${l.profBonus}'),
              if (l.abilityScoreImprovement)
                _kv(
                  'Mejora de características',
                  '+2 a repartir (o dote, si tu Master lo permite)',
                ),
              if (l.cantripsKnown != null)
                _kv('Trucos conocidos', '${l.cantripsKnown}'),
              if (l.spellsKnown != null)
                _kv('Conjuros conocidos', '${l.spellsKnown}'),
              if (l.slots.isNotEmpty)
                _kv(
                  'Espacios de conjuro',
                  l.slots.entries.map((e) => '${e.key}º ×${e.value}').join(', '),
                ),
              if (l.classSpecific.isNotEmpty)
                _kv('Datos de la clase', l.classSpecific.join(' · ')),
              if (l.features.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Tx(
                  'Rasgos (toca para leerlos)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final f in l.features)
                      ActionChip(
                        label: Text(f.name),
                        onPressed: () => showTextDialog(
                          context,
                          title: f.name,
                          loader: _api.fetchFeatureText(f.index),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------
  // HECHIZOS
  // ---------------------------------------------------------------

  Widget _spellsTab(List<ApiSpellRef> spells) {
    if (spells.isEmpty) {
      return const Center(child: Tx('Esta clase no tiene hechizos.'));
    }

    final byLevel = <int, List<ApiSpellRef>>{};
    for (final s in spells) {
      byLevel.putIfAbsent(s.level ?? -1, () => []).add(s);
    }
    final levels = byLevel.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '${spells.length} hechizos disponibles para $_className.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 8),
        for (final level in levels)
          Card(
            child: ExpansionTile(
              title: Text(
                level < 0
                    ? 'Nivel sin indicar'
                    : (level == 0 ? 'Trucos' : 'Nivel $level'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('${byLevel[level]!.length} hechizos'),
              children: [
                for (final s in byLevel[level]!)
                  ListTile(
                    dense: true,
                    title: Text(SrdEs.get('spells', s.name, 'n') ?? s.name),
                    trailing: const Icon(Icons.info_outline, size: 20),
                    onTap: () => showSpellDetail(context, s.index, s.name),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // SUBCLASES
  // ---------------------------------------------------------------

  Widget _subclassesTab(ApiClass c) {
    if (c.subclasses.isEmpty) {
      return const Center(child: Tx('Sin subclases en el SRD.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final s in c.subclasses)
          Card(
            child: ListTile(
              title: Text(
                s.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showTextDialog(
                context,
                title: s.name,
                loader: _api.fetchSubclassText(s.index),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
