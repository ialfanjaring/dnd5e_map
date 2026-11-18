import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/equipment_effects.dart';
import '../services/class_api_service.dart';
import '../services/equipment_api_service.dart';

/// Personaje con todo lo que se calcula a partir de la API: bonificadores de
/// raza, equipo activo (CA, velocidad, ataques).
class ResolvedCharacter {
  final Character character;
  final EquipmentEffects effects;

  const ResolvedCharacter(this.character, this.effects);

  /// Sin datos de la API todavía: se usan los valores de la ficha.
  factory ResolvedCharacter.plain(Character c) =>
      ResolvedCharacter(c, EquipmentEffects.compute(c, const {}));
}

/// Calcula el personaje resuelto y lo vuelve a calcular cuando cambian la
/// raza, el equipo o las características.
class ResolvedCharacterBuilder extends StatefulWidget {
  final Character character;
  final Widget Function(BuildContext context, ResolvedCharacter resolved) builder;

  const ResolvedCharacterBuilder({
    super.key,
    required this.character,
    required this.builder,
  });

  @override
  State<ResolvedCharacterBuilder> createState() =>
      _ResolvedCharacterBuilderState();
}

class _ResolvedCharacterBuilderState extends State<ResolvedCharacterBuilder> {
  late ResolvedCharacter _resolved;
  String _key = '';

  @override
  void initState() {
    super.initState();
    _resolved = ResolvedCharacter.plain(widget.character);
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ResolvedCharacterBuilder old) {
    super.didUpdateWidget(old);
    _resolve();
  }

  String _keyOf(Character c) => [
        c.race,
        c.subrace,
        c.items.join(','),
        c.equipped.join(','),
        c.abilities.entries.map((e) => '${e.key}${e.value}').join(),
        c.level,
        c.maxHp,
        c.armorClass,
        c.speed,
      ].join('|');

  Future<void> _resolve() async {
    final c = widget.character;
    final key = _keyOf(c);
    if (key == _key) return;
    _key = key;

    // Mientras se carga, se muestra la ficha sin datos de la API
    _resolved = ResolvedCharacter.plain(c);

    try {
      EquipmentApiService.registerCustomMap(c.customItems);
      final racial =
          await ClassApiService().fetchRacialBonuses(c.race, c.subrace);
      final items = await EquipmentApiService().fetchItems(c.items);

      final base = c.withRacial(racial);
      final effects = EquipmentEffects.compute(base, items);
      final resolved = ResolvedCharacter(
        base.withDerived(
          ac: effects.armorClass,
          speedPenalty: effects.speedPenalty,
        ),
        effects,
      );

      if (mounted && _key == key) setState(() => _resolved = resolved);
    } catch (_) {
      // Sin conexión: se mantienen los valores de la ficha
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _resolved);
}

/// "CA 17 · Iniciativa +2 · PG 12" con el equipo ya aplicado.
class CharacterQuickStats extends StatelessWidget {
  final Character character;
  final String prefix;
  final String suffix;
  final TextStyle? style;

  const CharacterQuickStats({
    super.key,
    required this.character,
    this.prefix = '',
    this.suffix = '',
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return ResolvedCharacterBuilder(
      character: character,
      builder: (context, r) {
        final c = r.character;
        return Text(
          '$prefix'
          'CA ${c.effectiveAc} · Iniciativa ${Character.signed(c.initiative)} · '
          'PG ${c.maxHp}$suffix',
          style: style,
        );
      },
    );
  }
}
