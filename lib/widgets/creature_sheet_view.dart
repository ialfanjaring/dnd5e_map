import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/creature.dart';
import 'spell_widgets.dart';
import '../i18n/i18n.dart';

/// Pantalla completa con el bloque de estadísticas de una criatura.
class CreatureSheetScreen extends StatelessWidget {
  final Creature creature;
  final String? title;

  const CreatureSheetScreen({super.key, required this.creature, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? creature.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CreatureSheetView(creature: creature),
          ),
        ),
      ),
    );
  }
}

class CreatureSheetView extends StatelessWidget {
  final Creature creature;

  const CreatureSheetView({super.key, required this.creature});

  @override
  Widget build(BuildContext context) {
    final c = creature;
    final accent = c.isMonster ? Colors.red.shade400 : Colors.blueGrey.shade300;

    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // CABECERA
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.name,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
                Chip(
                  label: Text(CreatureData.kinds[c.kind] ?? 'Monstruo'),
                ),
              ],
            ),
            Text(
              '${c.size} ${c.creatureType.toLowerCase()}, '
              '${c.alignment.toLowerCase()}',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
            _divider(accent),

            // COMBATE
            _line('Clase de armadura', '${c.armorClass}'),
            _line(
              'Puntos de golpe',
              c.hitDice.isEmpty ? '${c.maxHp}' : '${c.maxHp} (${c.hitDice})',
            ),
            _line('Velocidad', c.speed),
            _divider(accent),

            // CARACTERÍSTICAS
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final k in DndData.abilityKeys)
                  Column(
                    children: [
                      Text(
                        DndData.abilityShort[k]!,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                      Text('${c.abilities[k]} (${Character.signed(c.mod(k))})'),
                    ],
                  ),
              ],
            ),
            _divider(accent),

            if (c.skills.isNotEmpty) _line('Habilidades', c.skills),
            if (c.senses.isNotEmpty) _line('Sentidos', c.senses),
            if (c.languages.isNotEmpty) _line('Idiomas', c.languages),
            _line(
              'Desafío',
              '${c.challengeRating} (${c.xp} PX)',
            ),

            if (c.traits.isNotEmpty) ...[
              _divider(accent),
              Text(c.traits, style: const TextStyle(height: 1.4)),
            ],

            if (c.actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Tx(
                'Acciones',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              Divider(color: accent),
              Text(c.actions, style: const TextStyle(height: 1.4)),
            ],

            if (c.spells.isNotEmpty) ...[
              const SizedBox(height: 16),
              Tx(
                'Hechizos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              Divider(color: accent),
              SpellChips(indexes: c.spells),
            ],

            if (c.notes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Tx(
                'Notas',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: accent,
                ),
              ),
              Divider(color: accent),
              Text(c.notes, style: const TextStyle(height: 1.4)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _divider(Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Divider(height: 1, thickness: 2, color: color),
      );

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
