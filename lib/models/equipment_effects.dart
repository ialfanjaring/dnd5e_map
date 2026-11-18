import 'dart:math';

import '../services/equipment_api_service.dart';
import 'character.dart';

/// Ataque de un arma equipada.
class WeaponAttack {
  final ApiItem weapon;
  final int attackBonus;
  final String damage; // "1d8+3 cortante"

  const WeaponAttack({
    required this.weapon,
    required this.attackBonus,
    required this.damage,
  });
}

/// Efecto del equipo en las estadísticas del personaje.
class EquipmentEffects {
  /// CA con armadura/escudo; null si no lleva ninguno equipado.
  final int? armorClass;
  final int speedPenalty;
  final bool stealthDisadvantage;
  final List<WeaponAttack> attacks;

  /// Avisos (por ejemplo, fuerza insuficiente para la armadura).
  final List<String> notes;

  const EquipmentEffects({
    this.armorClass,
    this.speedPenalty = 0,
    this.stealthDisadvantage = false,
    this.attacks = const [],
    this.notes = const [],
  });

  /// [c] debe llevar ya los bonificadores de raza, para usar las
  /// puntuaciones totales.
  static EquipmentEffects compute(Character c, Map<String, ApiItem> data) {
    ApiItem? armor;
    ApiItem? shield;
    final weapons = <ApiItem>[];

    // Objetos mágicos sin estadísticas (solo suman su bono a la CA)
    var extraAcBonus = 0;

    for (final index in c.equipped) {
      final it = data[index];
      if (it == null) continue;
      if (it.isShield) {
        shield ??= it;
      } else if (it.isArmor) {
        armor ??= it;
      } else if (it.isWeapon) {
        weapons.add(it);
      } else if (it.slot == 'armor' || it.slot == 'shield') {
        extraAcBonus += it.magicBonus;
      }
    }

    final dex = c.mod('dex');
    final notes = <String>[];

    int? ac;
    if (armor != null || shield != null) {
      var base = 10 + dex;
      if (armor != null) {
        var dexPart = 0;
        if (armor.acDexBonus) {
          dexPart = armor.acMaxBonus == null ? dex : min(dex, armor.acMaxBonus!);
        }
        base = armor.acBase! + dexPart;
      }
      ac = base + (shield?.acBase ?? 0) + (armor?.magicBonus ?? 0) + (shield?.magicBonus ?? 0);
    }
    if (extraAcBonus != 0) {
      // Sin armadura con estadísticas: se parte de la CA de la ficha
      ac = (ac ?? c.armorClass) + extraAcBonus;
    }

    var penalty = 0;
    if (armor != null && armor.strMinimum > 0 && c.score('str') < armor.strMinimum) {
      penalty = 10;
      notes.add(
        '${armor.name}: requiere Fuerza ${armor.strMinimum}; '
        'la velocidad baja 10 pies.',
      );
    }

    final attacks = <WeaponAttack>[];
    for (final w in weapons) {
      final str = c.mod('str');
      final ability = w.isRanged
          ? dex
          : (w.isFinesse ? max(str, dex) : str);
      final type = EquipmentApiService.damageTypes[w.damageType] ??
          w.damageType.toLowerCase();
      final dmgMod = ability + w.magicBonus;
      final modText = dmgMod == 0 ? '' : Character.signed(dmgMod);
      attacks.add(WeaponAttack(
        weapon: w,
        // Se asume competencia con el arma
        attackBonus: ability + c.proficiencyBonus + w.magicBonus,
        damage: '${w.damageDice}$modText $type',
      ));
    }

    return EquipmentEffects(
      armorClass: ac,
      speedPenalty: penalty,
      stealthDisadvantage: armor?.stealthDisadvantage ?? false,
      attacks: attacks,
      notes: notes,
    );
  }
}
