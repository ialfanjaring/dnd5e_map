import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/class_api_service.dart';
import '../widgets/spell_widgets.dart';
import '../i18n/i18n.dart';

/// Listado de razas de la API para consultar cualquiera de ellas.
class RacesScreen extends StatefulWidget {
  const RacesScreen({super.key});

  @override
  State<RacesScreen> createState() => _RacesScreenState();
}

class _RacesScreenState extends State<RacesScreen> {
  late Future<List<ApiRef>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  /// Si la API no responde se usan las razas básicas del SRD.
  Future<List<ApiRef>> _load() async {
    try {
      return await ClassApiService().fetchRaceList();
    } catch (_) {
      return [
        for (final e in DndData.raceNames.entries)
          ApiRef(index: e.key, name: e.value),
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Tx(
          'Razas',
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

          final races = snapshot.data ?? const <ApiRef>[];

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: races.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = races[i];
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RaceInfoScreen(raceIndex: r.index),
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.withOpacity(0.25),
                        child: Text(DndData.raceName(r.index)[0]),
                      ),
                      title: Text(
                        DndData.raceName(r.index),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(r.name),
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

/// Información de una raza: bonificadores, rasgos y subrazas.
/// Los datos vienen de la D&D 5e SRD API (en español donde hay traducción).
class RaceInfoScreen extends StatefulWidget {
  /// Índice de la raza en la API (ej. elf)
  final String raceIndex;

  /// Subraza elegida (ej. high-elf): se muestra destacada si se indica.
  final String? subraceIndex;

  const RaceInfoScreen({super.key, required this.raceIndex, this.subraceIndex});

  @override
  State<RaceInfoScreen> createState() => _RaceInfoScreenState();
}

class _RaceInfoScreenState extends State<RaceInfoScreen> {
  final _api = ClassApiService();
  late Future<ApiRace> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.fetchRace(widget.raceIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${tr('Raza')}: ${DndData.raceName(widget.raceIndex)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<ApiRace>(
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
                      '${tr('No se pudo conectar con la API.')}\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(
                        () => _future = _api.fetchRace(widget.raceIndex),
                      ),
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
              child: _content(snapshot.data!),
            ),
          );
        },
      ),
    );
  }

  Widget _content(ApiRace r) {
    final bonuses = r.abilityBonuses
        .map((b) =>
            '${DndData.abilityShort[b.ability] ?? b.ability.toUpperCase()} '
            '${Character.signed(b.bonus)}')
        .join(', ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r.speed != null) _kv('Velocidad', '${r.speed} ${tr('pies')}'),
                if (r.size.isNotEmpty) _kv('Tamaño', r.size),
                _kv('Bonificadores', bonuses.isEmpty ? '—' : bonuses),
                if (r.languages.isNotEmpty)
                  _kv('Idiomas', r.languages.join(', ')),
                if (r.proficiencies.isNotEmpty)
                  _kv('Competencias', r.proficiencies.join(', ')),
              ],
            ),
          ),
        ),
        if (widget.subraceIndex != null && widget.subraceIndex!.isNotEmpty)
          _chosenSubrace(widget.subraceIndex!),
        if (r.age.isNotEmpty) _expandable('Edad', r.age),
        if (r.alignment.isNotEmpty) _expandable('Alineamiento', r.alignment),
        if (r.sizeDescription.isNotEmpty)
          _expandable('Tamaño', r.sizeDescription),
        if (r.languageDescription.isNotEmpty)
          _expandable('Idiomas', r.languageDescription),
        if (r.traits.isNotEmpty)
          _section(
            'Rasgos raciales (toca para leerlos)',
            Wrap(
              spacing: 6,
              children: [
                for (final t in r.traits)
                  ActionChip(
                    label: Text(t.name),
                    onPressed: () => showTextDialog(
                      context,
                      title: t.name,
                      loader: _api.fetchTraitText(t.index),
                    ),
                  ),
              ],
            ),
          ),
        if (r.subraces.isNotEmpty)
          _section(
            'Subrazas',
            Column(
              children: [
                for (final s in r.subraces)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => showTextDialog(
                      context,
                      title: s.name,
                      loader: _api.fetchSubraceText(s.index),
                    ),
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

  /// Subraza elegida por el personaje, con sus bonificadores y rasgos.
  Widget _chosenSubrace(String index) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.teal.withOpacity(0.14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<ApiSubrace>(
          future: _api.fetchSubrace(index),
          builder: (context, snapshot) {
            final title = 'Tu subraza: ${DndData.subraceName(index)}';

            if (snapshot.connectionState != ConnectionState.done) {
              return Row(
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(title),
                ],
              );
            }

            if (snapshot.hasError) {
              return Text('$title\nNo se pudo cargar de la API.');
            }

            final sub = snapshot.data!;
            final bonuses = sub.abilityBonuses
                .map((b) =>
                    '${DndData.abilityShort[b.ability] ?? b.ability.toUpperCase()} '
                    '${Character.signed(b.bonus)}')
                .join(', ');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (bonuses.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _kv('Bonificadores', bonuses),
                ],
                if (sub.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(sub.description, style: const TextStyle(height: 1.4)),
                ],
                if (sub.traits.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final t in sub.traits)
                        ActionChip(
                          label: Text(t.name),
                          onPressed: () => showTextDialog(
                            context,
                            title: t.name,
                            loader: _api.fetchTraitText(t.index),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _kv(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${tr(label)}: ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _expandable(String title, String text) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        title: Text(tr(title), style: const TextStyle(fontWeight: FontWeight.bold)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(text, style: const TextStyle(height: 1.4))],
      ),
    );
  }

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(title),
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
