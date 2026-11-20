import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/game_models.dart';
import 'avatars.dart';

/// Selector del aspecto de la ficha en el mapa: avatar y una combinación de
/// dos colores (fondo y dibujo/borde). No guarda nada: avisa de los cambios.
class TokenLookPicker extends StatelessWidget {
  final String avatar;
  final int? color;
  final int? color2;
  final String characterClass;
  final void Function({String? avatar, int? color, int? color2}) onChanged;

  const TokenLookPicker({
    super.key,
    required this.avatar,
    required this.color,
    required this.color2,
    required this.characterClass,
    required this.onChanged,
  });

  static const List<int> _colors = [
    ...GameColors.palette,
    0xFF212121, // negro
    0xFFFFFFFF, // blanco
    0xFFFFC107, // ámbar
    0xFFBDBDBD, // gris claro
  ];

  @override
  Widget build(BuildContext context) {
    final bg = Color(color ?? GameColors.palette.first);
    final fg = color2 == null
        ? (ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
            ? Colors.white
            : Colors.black)
        : Color(color2!);
    final current = Avatars.avatarIcon(avatar);
    final cs = Theme.of(context).colorScheme;

    Widget swatch(int c, bool selected, VoidCallback onTap) => InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? cs.primary : Colors.grey,
                width: selected ? 3 : 1,
              ),
            ),
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: fg, width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                  ),
                  child: current == null
                      ? Icon(Icons.help_outline, color: fg.withAlpha(150), size: 28)
                      : Icon(current, color: fg, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Tx(
                        'Tu ficha en el mapa',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      if (current == null)
                        Tx(
                          'Elige un avatar para continuar.',
                          style: TextStyle(fontSize: 12, color: cs.error),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Tx('Avatar', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              children: [
                for (final e in Avatars.tokenAvatars.entries)
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => onChanged(avatar: e.key),
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: avatar == e.key
                            ? cs.primaryContainer
                            : Colors.transparent,
                        border: Border.all(
                          color: avatar == e.key ? cs.primary : Colors.grey,
                          width: avatar == e.key ? 2.5 : 1,
                        ),
                      ),
                      child: Icon(e.value, size: 22),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Tx('Color de fondo', style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              children: [
                for (final c in _colors)
                  swatch(c, color == c, () => onChanged(color: c)),
              ],
            ),
            const SizedBox(height: 8),
            const Tx('Color del dibujo y el borde',
                style: TextStyle(fontWeight: FontWeight.w600)),
            Wrap(
              children: [
                for (final c in _colors)
                  swatch(c, color2 == c, () => onChanged(color2: c)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
