import 'package:flutter/material.dart';

import '../services/class_api_service.dart';

String spellLevelLabel(int level) => level == 0 ? 'Truco' : 'Nivel $level';

/// Diálogo que carga un texto de la API (rasgo, subclase...) y lo muestra.
Future<void> showTextDialog(
  BuildContext context, {
  required String title,
  required Future<List<String>> loader,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: FutureBuilder<List<String>>(
          future: loader,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('No se pudo cargar: ${snapshot.error}');
            }
            final text = (snapshot.data ?? const <String>[]).join('\n\n');
            return SingleChildScrollView(
              child: Text(
                text.isEmpty ? 'Sin descripción.' : text,
                style: const TextStyle(height: 1.4),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

/// Diálogo con el detalle completo de un hechizo.
Future<void> showSpellDetail(
  BuildContext context,
  String index,
  String name,
) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(name),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: FutureBuilder<ApiSpell>(
          future: ClassApiService().fetchSpell(index),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('No se pudo cargar el hechizo: ${snapshot.error}');
            }

            final s = snapshot.data!;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${spellLevelLabel(s.level)} · ${s.school}'
                    '${s.ritual ? ' (ritual)' : ''}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _line('Tiempo de lanzamiento', s.castingTime),
                  _line('Alcance', s.range),
                  _line('Componentes', s.components),
                  _line(
                    'Duración',
                    s.concentration
                        ? '${s.duration} (concentración)'
                        : s.duration,
                  ),
                  const SizedBox(height: 12),
                  Text(s.desc.join('\n\n'), style: const TextStyle(height: 1.4)),
                  if (s.higherLevel.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'A niveles superiores',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      s.higherLevel.join('\n\n'),
                      style: const TextStyle(height: 1.4),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}

Widget _line(String label, String value) {
  if (value.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
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

/// Chips con los hechizos de una lista de índices, agrupados por nivel.
/// El nombre y el nivel se leen de la API (solo se guardan los índices).
class SpellChips extends StatelessWidget {
  final List<String> indexes;

  /// Si se indica, cada chip se puede quitar.
  final ValueChanged<String>? onDelete;

  const SpellChips({super.key, required this.indexes, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, ApiSpellRef>>(
      future: ClassApiService().fetchAllSpells(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        // Si la API no responde, se muestran los índices tal cual
        final all = snapshot.data ?? const <String, ApiSpellRef>{};

        final byLevel = <int, List<ApiSpellRef>>{};
        for (final index in indexes) {
          final ref = all[index] ?? ApiSpellRef(index: index, name: index);
          byLevel.putIfAbsent(ref.level ?? -1, () => []).add(ref);
        }
        final levels = byLevel.keys.toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final level in levels) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  level < 0
                      ? 'Nivel sin indicar'
                      : (level == 0 ? 'Trucos' : 'Nivel $level'),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.deepPurple.shade700,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in byLevel[level]!
                    ..sort((a, b) => a.name.compareTo(b.name)))
                    onDelete == null
                        ? ActionChip(
                            label: Text(s.name),
                            onPressed: () =>
                                showSpellDetail(context, s.index, s.name),
                          )
                        : InputChip(
                            label: Text(s.name),
                            onPressed: () =>
                                showSpellDetail(context, s.index, s.name),
                            onDeleted: () => onDelete!(s.index),
                          ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Tarjeta con los hechizos de un personaje (lista de índices de la API).
class CharacterSpellsCard extends StatelessWidget {
  final List<String> spells;

  const CharacterSpellsCard({super.key, required this.spells});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hechizos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SpellChips(indexes: spells),
          ],
        ),
      ),
    );
  }
}
