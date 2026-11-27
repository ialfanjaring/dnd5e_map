import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/character.dart';
import '../models/equipment_effects.dart';
import '../models/game_models.dart';
import '../services/class_api_service.dart';
import '../services/equipment_api_service.dart';
import '../services/game_service.dart';
import '../screens/spell_browser_screen.dart' show spellName;
import 'resolved_character.dart';
import 'rules_help.dart';
import 'spell_widgets.dart';
import 'spellcasting_panel.dart';

// ===========================================================================
// TIRADAS DE ATAQUE Y DAÑO
// ===========================================================================

/// Tipo de daño de la API (inglés) -> tipo de grupo de dados (colores).
const Map<String, String> _damageKind = {
  'slashing': 'Cortante',
  'piercing': 'Perforante',
  'bludgeoning': 'Contundente',
  'fire': 'Fuego',
  'cold': 'Hielo',
  'lightning': 'Rayo',
  'thunder': 'Trueno',
  'acid': 'Ácido',
  'poison': 'Veneno',
  'necrotic': 'Necrótico',
  'radiant': 'Radiante',
  'psychic': 'Psíquico',
  'force': 'Fuerza',
};

String damageKindOf(String en) => _damageKind[en.toLowerCase()] ?? 'Otro';

/// Fórmula de dados de la API: "2d6", "1d8 + 3", "1d8 + MOD".
/// Devuelve null si no se entiende.
({int count, String die, int flat})? parseDice(String f, {int mod = 0}) {
  final m = RegExp(r'(\d+)\s*d\s*(\d+)\s*(?:([+-])\s*(\d+|MOD))?',
          caseSensitive: false)
      .firstMatch(f);
  if (m == null) return null;
  var flat = 0;
  if (m[3] != null) {
    final v = m[4]!.toUpperCase() == 'MOD' ? mod : int.parse(m[4]!);
    flat = m[3] == '-' ? -v : v;
  }
  return (count: int.parse(m[1]!), die: 'd${m[2]}', flat: flat);
}

/// Publica tiradas de ataque y daño en el registro de la partida.
class CombatRoller {
  CombatRoller({
    required this.gameCode,
    required this.nameProvider,
    required this.colorProvider,
  });

  final String gameCode;
  final String Function() nameProvider;
  final int Function() colorProvider;

  final _rnd = Random.secure();
  final _service = GameService();

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<DiceRoll> _post(List<DiceGroup> groups, String title) async {
    final roll = DiceRoll(
      uid: _uid,
      name: nameProvider(),
      color: colorProvider(),
      die: 'mix',
      values: [for (final g in groups) ...g.values],
      at: DateTime.now(),
      groups: groups,
      title: title,
    );
    await _service.postRoll(gameCode, roll);
    return roll;
  }

  /// Tira el d20 de ataque (con ventaja o desventaja) y, si el jugador dice
  /// que acierta, el daño. Con un 20 natural es crítico: el doble de dados.
  Future<void> attack(
    BuildContext context, {
    required String title,
    required int attackBonus,
    required String mode,
    required String damageDice,
    required int damageMod,
    required String damageType,
  }) async {
    final vals = DiceRoll.roll('d20', mode == 'normal' ? 1 : 2, _rnd);
    final chosen = DiceRoll.pickIndex(mode, vals);
    final atk = DiceGroup(
      die: 'd20',
      values: vals,
      label: 'Ataque',
      mod: attackBonus,
      mode: mode,
      chosen: chosen,
    );
    try {
      await _post([atk], '$title · ${tr('ataque')}');
    } catch (e) {
      _snack(context, '${tr('No se pudo publicar la tirada')}: $e');
      return;
    }
    if (!context.mounted) return;

    final nat = vals[vals.length == 2 ? chosen : 0];
    final crit = nat == 20;
    final fumble = nat == 1;
    final hit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(crit
            ? tr('¡Crítico!')
            : (fumble ? tr('Pifia') : '${tr('Ataque')}: ${atk.subtotal}')),
        content: Text(
          crit
              ? tr('20 natural: impacta seguro y se tira el doble de dados de daño.')
              : fumble
                  ? tr('1 natural: el ataque falla.')
                  : tr('¿El resultado iguala o supera la CA del objetivo?'),
        ),
        actions: [
          if (fumble)
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Tx('Cerrar'),
            )
          else ...[
            if (!crit)
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Tx('Falla'),
              ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.casino_outlined),
              label: const Tx('Tirar daño'),
            ),
          ],
        ],
      ),
    );
    if (hit != true || !context.mounted) return;
    await damage(
      context,
      title: title,
      dice: damageDice,
      mod: damageMod,
      type: damageType,
      crit: crit,
    );
  }

  /// Tira el daño (o la curación). [crit] dobla los dados.
  Future<void> damage(
    BuildContext context, {
    required String title,
    required String dice,
    int mod = 0,
    String type = '',
    bool crit = false,
    bool heal = false,
    bool modOnlyInFormula = false,
  }) async {
    final p = parseDice(dice, mod: mod);
    if (p == null) {
      _snack(context, tr('Este ataque no tiene dados de daño.'));
      return;
    }
    final n = crit ? p.count * 2 : p.count;
    // Los conjuros solo suman el modificador si su fórmula lo dice ("+ MOD")
    final flat = dice.toUpperCase().contains('MOD') || modOnlyInFormula
        ? p.flat
        : p.flat + mod;
    final g = DiceGroup(
      die: p.die,
      values: DiceRoll.roll(p.die, n, _rnd),
      label: heal ? 'Otro' : damageKindOf(type),
      mod: flat,
    );
    final what = heal
        ? tr('curación')
        : (crit ? tr('daño crítico') : tr('daño'));
    try {
      final r = await _post([g], '$title · $what');
      if (context.mounted) {
        _snack(context, '$title · $what: ${r.total}');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, '${tr('No se pudo publicar la tirada')}: $e');
      }
    }
  }

  static void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }
}

/// Normal / ventaja / desventaja.
class RollModePicker extends StatelessWidget {
  const RollModePicker({super.key, required this.mode, required this.onChanged});

  final String mode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        ButtonSegment(value: 'normal', label: Text(tr('Normal'))),
        ButtonSegment(
          value: 'adv',
          icon: const Icon(Icons.keyboard_double_arrow_up,
              size: 16, color: Colors.green),
          label: Text(tr('Ventaja')),
        ),
        ButtonSegment(
          value: 'dis',
          icon: const Icon(Icons.keyboard_double_arrow_down,
              size: 16, color: Colors.red),
          label: Text(tr('Desventaja')),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (v) => onChanged(v.first),
    );
  }
}

/// Carga la ficha del jugador en directo.
class _PlayerStream extends StatefulWidget {
  const _PlayerStream({
    required this.gameCode,
    required this.uid,
    required this.builder,
  });

  final String gameCode;
  final String uid;
  final Widget Function(BuildContext, GamePlayer) builder;

  @override
  State<_PlayerStream> createState() => _PlayerStreamState();
}

class _PlayerStreamState extends State<_PlayerStream> {
  late final Stream<List<GamePlayer>> _stream =
      GameService().players(widget.gameCode);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<GamePlayer>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${tr('No se pudo cargar la ficha')}: ${snap.error}'),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        for (final p in snap.data!) {
          if (p.uid == widget.uid) return widget.builder(context, p);
        }
        return const Center(child: Tx('Esta ficha ya no está en la partida.'));
      },
    );
  }
}

// ===========================================================================
// ACCIONES DEL TURNO
// ===========================================================================

/// Checklist de lo que has gastado en tu turno. Se reinicia al empezar tu
/// turno en combate.
class ActionsPanel extends StatelessWidget {
  const ActionsPanel({
    super.key,
    required this.used,
    this.inCombat = false,
    this.pending,
    this.onRequestUndo,
    this.moveInfo,
  });

  /// 'action', 'bonus', 'move', 'reaction' -> gastada
  final ValueNotifier<Map<String, bool>> used;

  /// En combate, desmarcar una acción gastada lo tiene que aprobar el Master.
  final bool inCombat;

  /// Acciones cuya recuperación está esperando la respuesta del Master.
  final ValueNotifier<Set<String>>? pending;

  /// Pide al Master desmarcar [key]. Si es null, se desmarca directamente.
  final Future<void> Function(String key, String title)? onRequestUndo;

  /// Texto del contador de movimiento (por ejemplo «Te quedan 15 de 30 pies»).
  final String? moveInfo;

  void _toggle(RuleEntry r, bool checked) {
    final u = used.value;
    if (checked) {
      used.value = {...u, r.key: true};
      return;
    }
    if (!(u[r.key] ?? false)) return;
    if (inCombat && onRequestUndo != null) {
      onRequestUndo!(r.key, r.title);
      return;
    }
    used.value = {...u, r.key: false};
  }

  @override
  Widget build(BuildContext context) {
    final empty = ValueNotifier<Set<String>>(const {});
    return ValueListenableBuilder<Set<String>>(
      valueListenable: pending ?? empty,
      builder: (context, waiting, _) => ValueListenableBuilder<Map<String, bool>>(
        valueListenable: used,
        builder: (context, u, _) {
          final grey = Colors.grey.shade600;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final r in kTurnActions)
                Card(
                  child: CheckboxListTile(
                    value: u[r.key] ?? false,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: waiting.contains(r.key)
                        ? null
                        : (v) => _toggle(r, v ?? false),
                    title: Row(children: [
                      Icon(r.icon, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          r.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: (u[r.key] ?? false)
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ]),
                    subtitle: waiting.contains(r.key)
                        ? Text(tr('Esperando al Master…'),
                            style: const TextStyle(fontSize: 12))
                        : (r.key == 'move' && moveInfo != null
                            ? Text(moveInfo!, style: const TextStyle(fontSize: 12))
                            : null),
                    secondary: IconButton(
                      tooltip: tr('Qué es'),
                      icon: const Icon(Icons.info_outline),
                      onPressed: () => showRuleDialog(
                        context,
                        r,
                        more: r.key == 'action' ? kActionOptions : const [],
                      ),
                    ),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: Icon(kFreeActions.icon),
                  title: Text(kFreeActions.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(
                    tooltip: tr('Qué es'),
                    icon: const Icon(Icons.info_outline),
                    onPressed: () => showRuleDialog(context, kFreeActions),
                  ),
                ),
              ),
              if (!inCombat) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => used.value = {},
                  icon: const Icon(Icons.restart_alt),
                  label: const Tx('Reiniciar el turno'),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Tx(
                  inCombat
                      ? 'Se reinicia al empezar tu turno. Para desmarcar una acción en combate, el Master tiene que aprobarlo.'
                      : 'Se reinicia solo al empezar tu turno en combate.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: grey),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ===========================================================================
// ARMAS
// ===========================================================================

class WeaponsPanel extends StatefulWidget {
  const WeaponsPanel({
    super.key,
    required this.gameCode,
    required this.uid,
    required this.roller,
    this.onAction,
  });

  final String gameCode;
  final String uid;
  final CombatRoller roller;

  /// Se llama al atacar (marca la acción principal como gastada)
  final VoidCallback? onAction;

  @override
  State<WeaponsPanel> createState() => _WeaponsPanelState();
}

class _WeaponsPanelState extends State<WeaponsPanel> {
  final _service = GameService();
  String _mode = 'normal';
  Map<String, ApiItem> _items = {};
  String _itemsKey = '';

  Future<void> _loadItems(Character c) async {
    final key = c.items.join(',');
    if (key == _itemsKey) return;
    _itemsKey = key;
    try {
      EquipmentApiService.registerCustomMap(c.customItems);
      final data = await EquipmentApiService().fetchItems(c.items);
      if (mounted && _itemsKey == key) setState(() => _items = data);
    } catch (_) {}
  }

  /// Cambia el arma equipada (solo una a la vez).
  Future<void> _equip(Character c, String index) async {
    final list = [
      for (final e in c.equipped)
        if (!(_items[e]?.isWeapon ?? false)) e,
      index,
    ];
    try {
      await _service.setPlayerEquipped(widget.gameCode, widget.uid, list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('No se pudo guardar')}: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PlayerStream(
      gameCode: widget.gameCode,
      uid: widget.uid,
      builder: (context, p) {
        final c = p.character;
        _loadItems(c);
        final weapons = <String>[
          for (final i in c.items)
            if (_items[i]?.isWeapon ?? false) i,
        ].toSet().toList();

        return ResolvedCharacterBuilder(
          character: c,
          builder: (context, r) {
            final attacks = r.effects.attacks;
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (weapons.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Tx(
                      'No tienes armas. El Master te las puede asignar desde '
                      'Objetos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                for (final i in weapons)
                  Card(
                    child: RadioListTile<String>(
                      value: i,
                      groupValue: weapons
                          .where((w) => c.equipped.contains(w))
                          .firstOrNull,
                      onChanged: (v) => v == null ? null : _equip(c, v),
                      title: Text(_items[i]!.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_weaponLine(_items[i]!)),
                      secondary: c.equipped.contains(i)
                          ? Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(tr('Equipada')),
                            )
                          : null,
                    ),
                  ),
                if (attacks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  RollModePicker(
                    mode: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                  const SizedBox(height: 8),
                  for (final a in attacks) _attackCard(a),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Tx(
                      'Se asume competencia con el arma. Con un 20 natural '
                      'es crítico y se tira el doble de dados de daño.',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ),
                ] else if (weapons.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Tx(
                      'Equipa un arma para poder atacar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  String _weaponLine(ApiItem w) {
    final type = EquipmentApiService.damageTypes[w.damageType] ?? w.damageType;
    final parts = [
      if (w.damageDice.isNotEmpty) '${w.damageDice} ${tr(type)}',
      if (w.weaponRange.isNotEmpty) EquipmentApiService.term(w.weaponRange),
      if (w.weaponCategory.isNotEmpty) EquipmentApiService.term(w.weaponCategory),
    ];
    return parts.join(' · ');
  }

  Widget _attackCard(WeaponAttack a) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              a.weapon.displayName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${tr('Ataque')}: ${Character.signed(a.attackBonus)} · '
              '${tr('Daño')}: ${a.damage}',
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () {
                widget.onAction?.call();
                widget.roller.attack(
                  context,
                  title: a.weapon.displayName,
                  attackBonus: a.attackBonus,
                  mode: _mode,
                  damageDice: a.damageDice,
                  damageMod: a.damageMod,
                  damageType: a.damageType,
                );
              },
              icon: const Icon(Icons.gps_fixed),
              label: Text(
                _mode == 'adv'
                    ? tr('Atacar con ventaja')
                    : (_mode == 'dis' ? tr('Atacar con desventaja') : tr('Atacar')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// HECHIZOS
// ===========================================================================

/// Característica para lanzar conjuros de cada clase.
const Map<String, String> spellAbilityOf = {
  'bard': 'cha',
  'cleric': 'wis',
  'druid': 'wis',
  'paladin': 'cha',
  'ranger': 'wis',
  'sorcerer': 'cha',
  'warlock': 'cha',
  'wizard': 'int',
};

/// Clases que preparan hechizos cada día (el resto los conoce).
const Set<String> preparedCasters = {'cleric', 'druid', 'paladin', 'wizard'};

class SpellsPanel extends StatefulWidget {
  const SpellsPanel({
    super.key,
    required this.gameCode,
    required this.uid,
    required this.roller,
    this.onAction,
  });

  final String gameCode;
  final String uid;
  final CombatRoller roller;
  final VoidCallback? onAction;

  @override
  State<SpellsPanel> createState() => _SpellsPanelState();
}

class _SpellsPanelState extends State<SpellsPanel> {
  final _service = GameService();
  final _api = ClassApiService();

  String _mode = 'normal';
  String _slotsKey = '';
  Map<int, int> _maxSlots = const {};
  String? _spellsKey;
  Future<List<ApiSpell>>? _spellsFuture;
  final List<String> _spellErrors = [];

  /// Nivel de espacio elegido para cada hechizo (por índice)
  final Map<String, int> _slotFor = {};

  /// Espacios de conjuro de la clase en su nivel (se lee una vez)
  Future<void> _loadSlots(Character c) async {
    final sk = '${c.characterClass}|${c.level}';
    if (sk == _slotsKey) return;
    _slotsKey = sk;
    try {
      final levels = await _api.fetchLevels(c.characterClass);
      for (final l in levels) {
        if (l.level == c.level && mounted) setState(() => _maxSlots = l.slots);
      }
    } catch (_) {}
  }

  /// Hechizos asignados (cada uno por separado: si uno falla, el resto sale)
  Future<List<ApiSpell>> _spellsOf(Character c) {
    final key = c.spells.join(',');
    if (key == _spellsKey && _spellsFuture != null) return _spellsFuture!;
    _spellsKey = key;
    _spellErrors.clear();
    return _spellsFuture = Future.wait(c.spells.map((i) async {
      try {
        return await _api.fetchSpell(i);
      } catch (e) {
        _spellErrors.add('$i: $e');
        return null;
      }
    })).then((l) {
      final out = l.whereType<ApiSpell>().toList()
        ..sort((a, b) => a.level != b.level
            ? a.level.compareTo(b.level)
            : a.name.compareTo(b.name));
      return out;
    });
  }

  int _maxPrepared(Character c, int mod) {
    final lvl = c.characterClass == 'paladin' ? c.level ~/ 2 : c.level;
    return max(1, mod + lvl);
  }

  Future<void> _togglePrepared(GamePlayer p, String index, bool on, int limit) async {
    final list = [...p.prepared];
    if (on) {
      if (list.length >= limit) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr('Ya tienes preparados todos los hechizos que puedes.')),
        ));
        return;
      }
      if (!list.contains(index)) list.add(index);
    } else {
      list.remove(index);
    }
    try {
      await _service.setPrepared(widget.gameCode, p.uid, list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('No se pudo guardar')}: $e')),
      );
    }
  }

  /// Gasta un espacio de conjuro del nivel [level].
  Future<bool> _spendSlot(GamePlayer p, int level) async {
    final max = _maxSlots[level] ?? 0;
    final used = p.slotsUsed[level] ?? 0;
    if (used >= max) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr('No te quedan espacios de ese nivel.')),
      ));
      return false;
    }
    final next = {...p.slotsUsed, level: used + 1};
    try {
      await _service.updatePlayerSlots(widget.gameCode, p.uid, next);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('No se pudo guardar')}: $e')),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PlayerStream(
      gameCode: widget.gameCode,
      uid: widget.uid,
      builder: (context, p) {
        _loadSlots(p.character);
        final spellsFuture = _spellsOf(p.character);
        return FutureBuilder<List<ApiSpell>>(
          future: spellsFuture,
          builder: (context, snap) {
            final spells = snap.data ?? const <ApiSpell>[];
            final loading = snap.connectionState != ConnectionState.done;
            return ResolvedCharacterBuilder(
          character: p.character,
          builder: (context, r) {
            final c = r.character;
            final ability = spellAbilityOf[c.characterClass];
            final abilityMod = ability == null ? 0 : c.mod(ability);
            final attackBonus = c.proficiencyBonus + abilityMod;
            final dc = 8 + c.proficiencyBonus + abilityMod;
            final prepares = preparedCasters.contains(c.characterClass);
            final limit = _maxPrepared(c, abilityMod);

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (ability != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        alignment: WrapAlignment.spaceEvenly,
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _stat(tr('Característica'),
                              DndData.abilityShort[ability] ?? ability),
                          _stat(tr('Ataque de conjuro'),
                              Character.signed(attackBonus)),
                          _stat(tr('CD de salvación'), '$dc'),
                          if (prepares)
                            _stat(tr('Preparados'),
                                '${p.prepared.length} / $limit'),
                        ],
                      ),
                    ),
                  ),
                if (_maxSlots.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SpellcastingPanel(
                        maxSlots: _maxSlots,
                        used: p.slotsUsed,
                        spells: const [],
                        showSpellList: false,
                        canEdit: true,
                        onUsedChanged: (u) => _service.updatePlayerSlots(
                            widget.gameCode, p.uid, u),
                      ),
                    ),
                  ),
                if (spells.any((s) => s.hasAttack)) ...[
                  const SizedBox(height: 4),
                  RollModePicker(
                    mode: _mode,
                    onChanged: (m) => setState(() => _mode = m),
                  ),
                ],
                const SizedBox(height: 4),
                if (loading && p.character.spells.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (p.character.spells.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Tx(
                      'No tienes hechizos asignados. Añádelos editando tu ficha.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                if (!loading && _spellErrors.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      '${tr('No se pudieron cargar algunos hechizos')}:\n${_spellErrors.join('\n')}',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                    ),
                  ),
                for (final s in spells)
                  _spellCard(p, c, s,
                      attackBonus: attackBonus,
                      dc: dc,
                      abilityMod: abilityMod,
                      prepares: prepares,
                      limit: limit),
              ],
            );
          },
        );
          },
        );
      },
    );
  }

  Widget _stat(String label, String value) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      );

  Widget _spellCard(
    GamePlayer p,
    Character c,
    ApiSpell s, {
    required int attackBonus,
    required int dc,
    required int abilityMod,
    required bool prepares,
    required int limit,
  }) {
    final isCantrip = s.level == 0;
    final prepared = !prepares || isCantrip || p.prepared.contains(s.index);

    // Niveles de espacio con los que se puede lanzar
    final slotLevels = [
      for (final l in _maxSlots.keys.toList()..sort())
        if (l >= s.level) l,
    ];
    var slot = _slotFor[s.index] ?? (slotLevels.isEmpty ? s.level : slotLevels.first);
    if (!isCantrip && slotLevels.isNotEmpty && !slotLevels.contains(slot)) {
      slot = slotLevels.first;
    }

    final dmg = s.hasDamage ? s.damageFor(slot: slot, charLevel: c.level) : '';
    final heal = s.heals ? s.healFor(slot) : '';
    final saveName = DndData.abilityShort[s.dcType] ?? s.dcType.toUpperCase();
    final typeEs = tr(EquipmentApiService.damageTypes[s.damageType] ?? s.damageType);

    Future<bool> cast() async {
      if (isCantrip) return true;
      return _spendSlot(p, slot);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => showSpellDetail(context, s.index, s.name),
                    child: Text(
                      spellName(s.name),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (prepares && !isCantrip)
                  FilterChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(tr('Preparado')),
                    selected: p.prepared.contains(s.index),
                    onSelected: (v) => _togglePrepared(p, s.index, v, limit),
                  ),
              ],
            ),
            Text(
              '${spellLevelLabel(s.level)} · ${tr('Alcance')}: ${spellTerm(s.range)}'
              ' · ${spellTerm(s.castingTime)}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            if (s.hasAttack || s.hasSave || dmg.isNotEmpty || heal.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    if (s.hasAttack)
                      '${tr('Ataque')} ${Character.signed(attackBonus)}',
                    if (s.hasSave)
                      '${tr('Salvación')} $saveName ${tr('CD')} $dc'
                          '${s.dcSuccess == 'half' ? ' (${tr('mitad si la supera')})' : ''}',
                    if (dmg.isNotEmpty) '${tr('Daño')} $dmg $typeEs',
                    if (heal.isNotEmpty) '${tr('Curación')} $heal',
                  ].join(' · '),
                ),
              ),
            if (!isCantrip && slotLevels.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Tx('Espacio de nivel', style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 8),
                    DropdownButton<int>(
                      isDense: true,
                      value: slot,
                      items: [
                        for (final l in slotLevels)
                          DropdownMenuItem(
                            value: l,
                            child: Text(
                                '$l (${(_maxSlots[l] ?? 0) - (p.slotsUsed[l] ?? 0)} ${tr('libres')})'),
                          ),
                      ],
                      onChanged: (v) => setState(() => _slotFor[s.index] = v ?? slot),
                    ),
                  ],
                ),
              ),
            if (!prepared)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Tx(
                  'Prepáralo para poder lanzarlo.',
                  style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
                ),
              ),
            if (prepared)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (s.hasAttack)
                      FilledButton.icon(
                        onPressed: () async {
                          if (!await cast() || !mounted) return;
                          widget.onAction?.call();
                          widget.roller.attack(
                            context,
                            title: spellName(s.name),
                            attackBonus: attackBonus,
                            mode: _mode,
                            damageDice: dmg,
                            damageMod: 0,
                            damageType: s.damageType,
                          );
                        },
                        icon: const Icon(Icons.gps_fixed, size: 18),
                        label: const Tx('Lanzar y atacar'),
                      )
                    else if (dmg.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () async {
                          if (!await cast() || !mounted) return;
                          widget.onAction?.call();
                          widget.roller.damage(
                            context,
                            title: spellName(s.name),
                            dice: dmg,
                            mod: abilityMod,
                            type: s.damageType,
                            modOnlyInFormula: true,
                          );
                        },
                        icon: const Icon(Icons.local_fire_department_outlined,
                            size: 18),
                        label: const Tx('Lanzar y tirar daño'),
                      ),
                    if (heal.isNotEmpty)
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          if (!await cast() || !mounted) return;
                          widget.onAction?.call();
                          widget.roller.damage(
                            context,
                            title: spellName(s.name),
                            dice: heal,
                            mod: abilityMod,
                            heal: true,
                            modOnlyInFormula: true,
                          );
                        },
                        icon: const Icon(Icons.healing, size: 18),
                        label: const Tx('Lanzar y curar'),
                      ),
                    if (!s.hasAttack && dmg.isEmpty && heal.isEmpty && !isCantrip)
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (!await cast() || !mounted) return;
                          widget.onAction?.call();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                '${spellName(s.name)}: ${tr('espacio de nivel')} $slot ${tr('gastado')}'),
                          ));
                        },
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Tx('Lanzar'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
