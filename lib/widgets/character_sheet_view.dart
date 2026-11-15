import 'package:flutter/material.dart';

import '../models/character.dart';

/// Pantalla completa con la ficha de un personaje (solo lectura).
class CharacterSheetScreen extends StatelessWidget {
  final Character character;

  const CharacterSheetScreen({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(character.name)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CharacterSheetView(character: character),
          ),
        ),
      ),
    );
  }
}

class CharacterSheetView extends StatelessWidget {
  final Character character;

  const CharacterSheetView({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    final c = character;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CABECERA
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  c.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.summary,
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                if (c.background.isNotEmpty || c.alignment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [c.background, c.alignment]
                          .where((e) => e.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // COMBATE
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatBox(label: 'CA', value: '${c.armorClass}'),
            _StatBox(label: 'PG', value: '${c.maxHp}'),
            _StatBox(label: 'Velocidad', value: '${c.speed} pies'),
            _StatBox(label: 'Iniciativa', value: Character.signed(c.initiative)),
            _StatBox(
              label: 'Competencia',
              value: Character.signed(c.proficiencyBonus),
            ),
            _StatBox(
              label: 'Percepción pasiva',
              value: '${c.passivePerception}',
            ),
          ],
        ),

        const SizedBox(height: 12),

        // CARACTERÍSTICAS
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in DndData.abilityKeys)
              _StatBox(
                label: DndData.abilityNames[k]!,
                value: Character.signed(c.mod(k)),
                caption: '${c.abilities[k]}',
                width: 110,
              ),
          ],
        ),

        const SizedBox(height: 12),

        // SALVACIONES
        _SectionCard(
          title: 'Tiradas de salvación',
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final k in DndData.abilityKeys)
                _ProfRow(
                  proficient: c.savingThrows.contains(k),
                  label: DndData.abilityNames[k]!,
                  bonus: c.saveBonus(k),
                ),
            ],
          ),
        ),

        // HABILIDADES
        _SectionCard(
          title: 'Habilidades',
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in DndData.skills.keys)
                _ProfRow(
                  proficient: c.skills.contains(s),
                  label: '$s (${DndData.abilityShort[DndData.skills[s]]})',
                  bonus: c.skillBonus(s),
                ),
            ],
          ),
        ),

        if (c.equipment.isNotEmpty)
          _SectionCard(title: 'Equipo', child: Text(c.equipment)),

        if (c.notes.isNotEmpty)
          _SectionCard(
            title: 'Notas e historia',
            child: Text(c.notes),
          ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final double width;

  const _StatBox({
    required this.label,
    required this.value,
    this.caption,
    this.width = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfRow extends StatelessWidget {
  final bool proficient;
  final String label;
  final int bonus;

  const _ProfRow({
    required this.proficient,
    required this.label,
    required this.bonus,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Row(
        children: [
          Icon(
            proficient ? Icons.circle : Icons.circle_outlined,
            size: 12,
            color: Colors.deepPurple,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              Character.signed(bonus),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
