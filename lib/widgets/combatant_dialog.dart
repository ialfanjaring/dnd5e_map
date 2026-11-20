import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/creature.dart';
import '../services/class_api_service.dart';
import '../services/game_service.dart';
import '../services/monster_api_service.dart';
import 'spellcasting_panel.dart';

/// Ventana emergente de un combatiente: puntos de golpe, espacios de
/// conjuro y hechizos.
///
/// Jugador: el Master y el propio jugador. Criatura: solo el Master.
Future<void> showCombatantDialog(
  BuildContext context, {
  required GameService service,
  required String gameCode,
  required String tokenId,
  required bool isMaster,
  required String myUid,
}) {
  final isPlayer = tokenId.startsWith('p_');
  if (isPlayer && !isMaster && tokenId != 'p_$myUid') return Future.value();
  if (!isPlayer && !isMaster) return Future.value();

  return showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
        child: isPlayer
            ? _PlayerBody(
                service: service,
                code: gameCode,
                uid: tokenId.substring(2),
                isMaster: isMaster,
              )
            : _CreatureBody(service: service, code: gameCode, id: tokenId),
      ),
    ),
  );
}

Widget _hpControls({
  required String name,
  required int current,
  required int max,
  required ValueChanged<int> onDelta,
  required BuildContext context,
}) {
  final ratio = max == 0 ? 0.0 : (current / max).clamp(0.0, 1.0).toDouble();
  final color = ratio > 0.5
      ? Colors.green
      : (ratio > 0.25 ? Colors.orange : Colors.red);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(name,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            tooltip: tr('Cerrar'),
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      Text('$current / $max ${tr('PG')}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: ratio,
        minHeight: 12,
        color: color,
        backgroundColor: Colors.grey.withAlpha(90),
      ),
      const SizedBox(height: 10),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final d in const [-5, -1, 1, 5])
            OutlinedButton(
              onPressed: () => onDelta(d),
              child: Text(d > 0 ? '+$d' : '$d'),
            ),
        ],
      ),
      const Divider(height: 24),
    ],
  );
}

// ------------------------------------------------------------ Jugador

class _PlayerBody extends StatelessWidget {
  final GameService service;
  final String code;
  final String uid;
  final bool isMaster;

  const _PlayerBody({
    required this.service,
    required this.code,
    required this.uid,
    required this.isMaster,
  });

  Future<Map<int, int>> _maxSlots(GamePlayer p) async {
    try {
      final levels = await ClassApiService().fetchLevels(p.character.characterClass);
      for (final l in levels) {
        if (l.level == p.character.level) return l.slots;
      }
    } catch (_) {}
    return const {};
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GamePlayer>>(
      stream: service.players(code),
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) {
          return const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()));
        }
        GamePlayer? p;
        for (final x in list) {
          if (x.uid == uid) p = x;
        }
        if (p == null) {
          return const Padding(
              padding: EdgeInsets.all(24), child: Tx('Ficha no disponible.'));
        }
        final player = p;
        final max = player.character.maxHp;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _hpControls(
                context: context,
                name: player.character.name,
                current: player.currentHp,
                max: max,
                onDelta: (d) => service.updatePlayerHp(
                  code,
                  uid,
                  (player.currentHp + d).clamp(0, max).toInt(),
                ),
              ),
              FutureBuilder<Map<int, int>>(
                future: _maxSlots(player),
                builder: (context, s) {
                  if (s.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final slots = s.data ?? const {};
                  if (slots.isEmpty && player.character.spells.isEmpty) {
                    return const Tx('Este personaje no lanza hechizos.');
                  }
                  return SpellcastingPanel(
                    maxSlots: slots,
                    used: player.slotsUsed,
                    spells: player.character.spells,
                    canEdit: true,
                    onUsedChanged: (u) => service.updatePlayerSlots(code, uid, u),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------ Criatura

class _CreatureBody extends StatelessWidget {
  final GameService service;
  final String code;
  final String id;

  const _CreatureBody({
    required this.service,
    required this.code,
    required this.id,
  });

  Future<({Creature creature, MonsterSpellcasting sc})> _load(
      GameCreature gc) async {
    final api = MonsterApiService();
    if (gc.isApi) {
      final c = await api.fetchMonster(gc.apiIndex!);
      MonsterSpellcasting sc = const MonsterSpellcasting();
      try {
        sc = await api.fetchSpellcasting(gc.apiIndex!);
      } catch (_) {}
      return (creature: c, sc: sc);
    }
    final c = gc.snapshot!;
    return (creature: c, sc: MonsterSpellcasting(spells: c.spells));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GameCreature>>(
      stream: service.creatures(code),
      builder: (context, snap) {
        final list = snap.data;
        if (list == null) {
          return const SizedBox(
              height: 120, child: Center(child: CircularProgressIndicator()));
        }
        GameCreature? gc;
        for (final x in list) {
          if (x.id == id) gc = x;
        }
        if (gc == null) {
          return const Padding(
              padding: EdgeInsets.all(24), child: Tx('Criatura no disponible.'));
        }
        final g = gc;

        return FutureBuilder<({Creature creature, MonsterSpellcasting sc})>(
          future: _load(g),
          builder: (context, s) {
            if (s.hasError) {
              return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('${s.error}'));
            }
            if (!s.hasData) {
              return const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()));
            }
            final c = s.data!.creature;
            final sc = s.data!.sc;
            final lost = g.damage > c.maxHp ? c.maxHp : g.damage;
            final current = c.maxHp - lost;
            final title = g.isApi ? '${c.name} ${g.number}' : '${g.label} ${g.number}';

            // El Master puede definir máximos propios (NPC sin datos)
            final maxSlots = g.slotsMax.isNotEmpty ? g.slotsMax : sc.slots;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _hpControls(
                    context: context,
                    name: title,
                    current: current,
                    max: c.maxHp,
                    // Botón + sube la vida: el daño baja
                    onDelta: (d) => service.updateCreatureDamage(
                      code,
                      g.id,
                      (lost - d).clamp(0, c.maxHp).toInt(),
                      maxHp: c.maxHp,
                    ),
                  ),
                  SpellcastingPanel(
                      maxSlots: maxSlots,
                      used: g.slotsUsed,
                      spells: sc.spells,
                      canEdit: true,
                      onUsedChanged: (u) =>
                          service.updateCreatureSlots(code, g.id, used: u),
                      onMaxChanged: (m) =>
                          service.updateCreatureSlots(code, g.id, max: m),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
