import 'package:flutter/material.dart';

import '../services/class_api_service.dart';
import '../i18n/i18n.dart';
import '../services/translation_service.dart';
import '../settings/app_settings.dart';


/// Traduce al español los datos fijos de un hechizo (tiempo, alcance,
/// duración, componentes). Solo actúa con la app en español.
String spellTerm(String v, {String kind = ''}) {
  if (v.isEmpty || AppSettings.instance.lang != 'es') return v;
  var t = v;
  final fixed = <String, String>{
    '1 action': '1 acción',
    '1 bonus action': '1 acción adicional',
    '1 reaction': '1 reacción',
    'Self': 'Personal',
    'Touch': 'Toque',
    'Sight': 'Visión',
    'Unlimited': 'Ilimitado',
    'Special': 'Especial',
    'Instantaneous': 'Instantánea',
    'Until dispelled': 'Hasta que se disipe',
    'Until dispelled or triggered': 'Hasta que se disipe o se active',
  };
  if (fixed.containsKey(t)) return fixed[t]!;
  final units = <String, String>{
    'round': 'asalto', 'rounds': 'asaltos',
    'minute': 'minuto', 'minutes': 'minutos',
    'hour': 'hora', 'hours': 'horas',
    'day': 'día', 'days': 'días',
    'foot': 'pies', 'feet': 'pies',
    'mile': 'milla', 'miles': 'millas',
    'bonus action': 'acción adicional', 'action': 'acción',
    'reaction': 'reacción',
  };
  t = t.replaceAllMapped(
      RegExp(r'\b(\d+)[ -](rounds?|minutes?|hours?|days?|foot|feet|miles?|bonus action|action|reaction)\b'),
      (m) => '${m[1]} ${units[m[2]]}');
  t = t.replaceAll('Up to', 'Hasta');
  t = t.replaceAll('Self (', 'Personal (');
  t = t.replaceAll('hemisphere', 'hemisferio').replaceAll('radius', 'radio')
      .replaceAll('cone', 'cono').replaceAll('cube', 'cubo')
      .replaceAll('sphere', 'esfera').replaceAll('line', 'línea');
  t = t.replaceAll('Touch', 'Toque').replaceAll('Sight', 'Visión')
      .replaceAll('Instantaneous', 'Instantánea')
      .replaceAll('Until dispelled', 'Hasta que se disipe')
      .replaceAll('Special', 'Especial');
  // «, which has» ... en tiempo de lanzamiento (ej. "1 reaction, which you take when…")
  t = t.replaceAll(', which you take', ', que realizas');
  return t;
}

String spellLevelLabel(int level) =>
    level == 0 ? tr('Truco') : '${tr('Nivel')} $level';

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
              child: text.isEmpty
                  ? const Tx('Sin descripción.', style: TextStyle(height: 1.4))
                  : Text(text, style: const TextStyle(height: 1.4)),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Tx('Cerrar'),
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
      title: TrText(name, srdName: name, srdField: 'n', srdSection: 'spells'),
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
                    '${spellLevelLabel(s.level)} · ${tr(s.school)}'
                    '${s.ritual ? ' ${tr('(ritual)')}' : ''}',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _line(tr('Tiempo de lanzamiento'), spellTerm(s.castingTime)),
                  _line(tr('Alcance'), spellTerm(s.range)),
                  _line(tr('Componentes'), s.components),
                  _line(
                    tr('Duración'),
                    s.concentration
                        ? '${spellTerm(s.duration)} ${tr('(concentración)')}'
                        : spellTerm(s.duration),
                  ),
                  const SizedBox(height: 12),
                  TrText(
                    s.desc.join('\n\n'),
                    srdName: s.name,
                    srdSection: 'spells',
                    style: const TextStyle(height: 1.4),
                  ),
                  if (s.higherLevel.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Tx(
                      'A niveles superiores',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TrText(
                      s.higherLevel.join('\n\n'),
                      srdName: s.name,
                      srdField: 'h',
                      srdSection: 'spells',
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
          child: const Tx('Cerrar'),
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
/// Nombre del hechizo en español si está en el SRD (solo con la app en español).
String _loc(String enName) => SrdEs.get('spells', enName, 'n') ?? enName;

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
                      ? tr('Nivel sin indicar')
                      : (level == 0 ? tr('Trucos') : '${tr('Nivel')} $level'),
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
                    ..sort((a, b) => _loc(a.name).compareTo(_loc(b.name))))
                    onDelete == null
                        ? ActionChip(
                            label: Text(_loc(s.name)),
                            onPressed: () =>
                                showSpellDetail(context, s.index, s.name),
                          )
                        : InputChip(
                            label: Text(_loc(s.name)),
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
            const Tx(
              'Hechizos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (spells.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Tx(
                  'Aún no ha elegido hechizos.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              )
            else
              SpellChips(indexes: spells),
          ],
        ),
      ),
    );
  }
}

/// Una línea con los hechizos de un personaje o NPC, para las listas.
/// Muestra los primeros nombres (leídos de la API) y cuántos más hay.
class SpellSummaryText extends StatelessWidget {
  final List<String> indexes;
  final int maxNames;

  const SpellSummaryText({super.key, required this.indexes, this.maxNames = 3});

  @override
  Widget build(BuildContext context) {
    if (indexes.isEmpty) return const SizedBox.shrink();

    return FutureBuilder<Map<String, ApiSpellRef>>(
      future: ClassApiService().fetchAllSpells(),
      builder: (context, snapshot) {
        final all = snapshot.data;
        String text;

        if (all == null) {
          // Cargando o sin conexión: solo el número de hechizos
          text = 'Hechizos: ${indexes.length}';
        } else {
          final names = indexes.map((i) => all[i]?.name ?? i).toList()..sort();
          final shown = names.take(maxNames).join(', ');
          final rest = names.length - maxNames;
          text = 'Hechizos: $shown${rest > 0 ? ' +$rest más' : ''}';
        }

        return Text(text, maxLines: 2, overflow: TextOverflow.ellipsis);
      },
    );
  }
}
