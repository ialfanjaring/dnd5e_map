import 'package:flutter/material.dart';

import '../models/character.dart';

/// Casillas de características (Fuerza, Destreza...) grandes y que ocupan
/// todo el ancho disponible. Se usa en personajes y en el bestiario.
class AbilityGrid extends StatelessWidget {
  final Map<String, int> abilities;

  /// Bonificadores de raza (solo personajes)
  final Map<String, int> racial;

  final void Function(String key, int value) onChanged;

  const AbilityGrid({
    super.key,
    required this.abilities,
    this.racial = const {},
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 12.0;
        final cols = c.maxWidth >= 900 ? 6 : (c.maxWidth >= 480 ? 3 : 2);
        final w = (c.maxWidth - spacing * (cols - 1)) / cols;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final k in DndData.abilityKeys)
              SizedBox(width: w, child: _box(context, k)),
          ],
        );
      },
    );
  }

  Widget _box(BuildContext context, String key) {
    final score = abilities[key] ?? 10;
    final bonus = racial[key] ?? 0;
    final mod = Character.modifier(score + bonus);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            DndData.abilityNames[key]!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            Character.signed(mod),
            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                iconSize: 26,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed:
                    score > 1 ? () => onChanged(key, score - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    bonus == 0
                        ? '$score'
                        : '$score ${Character.signed(bonus)} = ${score + bonus}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                iconSize: 26,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed:
                    score < 30 ? () => onChanged(key, score + 1) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
