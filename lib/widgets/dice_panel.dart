import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../services/game_service.dart';
import '../i18n/i18n.dart';
import 'app_icon.dart';
import 'dice_roll_animation.dart';

/// Tirada de dados y registro de la partida.
///
/// - Descubierta: se publica y la ven todos en el registro.
/// - Oculta: la ve quien la hace y el Master.
class DicePanel extends StatefulWidget {
  final String gameCode;

  /// El Master ve las tiradas ocultas de todos
  final bool isMaster;

  /// Tiradas ocultas visibles para este usuario (las suyas; todas si es Master)
  final ValueNotifier<List<DiceRoll>> hiddenRolls;

  /// Nombre y color de quien tira, consultados en el momento de la tirada
  final String Function() nameProvider;
  final int Function() colorProvider;

  const DicePanel({
    super.key,
    required this.gameCode,
    required this.isMaster,
    required this.hiddenRolls,
    required this.nameProvider,
    required this.colorProvider,
  });

  @override
  State<DicePanel> createState() => _DicePanelState();
}

class _DicePanelState extends State<DicePanel> {
  final _service = GameService();
  final _rnd = Random.secure();
  late final Stream<List<DiceRoll>> _rollsStream;
  StreamSubscription<List<DiceRoll>>? _hiddenSub;

  /// Dados elegidos para la próxima tirada. Se pueden mezclar dados
  /// distintos y cada grupo puede ir con ventaja o desventaja.
  final List<_PoolDie> _pool = [_PoolDie('d20')];
  int _mod = 0;
  bool _hidden = false;
  bool _rolling = false;

  /// Última tirada hecha aquí, para animarla.
  DiceRoll? _last;
  int _seq = 0;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _rollsStream = _service.rolls(widget.gameCode);
    _hiddenSub = _service
        .hiddenRolls(widget.gameCode, isMaster: widget.isMaster, uid: _uid)
        .listen((list) => widget.hiddenRolls.value = list, onError: (_) {});
  }

  @override
  void dispose() {
    _hiddenSub?.cancel();
    super.dispose();
  }

  /// Toca un dado: lo añade a la tirada (o suma uno si ya estaba).
  /// La moneda no se mezcla con otros dados.
  void _addDie(String die) {
    setState(() {
      if (die == 'coin') {
        _pool
          ..clear()
          ..add(_PoolDie('coin'));
        return;
      }
      _pool.removeWhere((p) => p.die == 'coin');
      for (final p in _pool) {
        if (p.die == die && p.mode == 'normal') {
          if (p.count < 10) p.count++;
          return;
        }
      }
      if (_pool.length < 6) _pool.add(_PoolDie(die));
    });
  }

  String get _formula {
    final parts = [
      for (final p in _pool)
        '${p.count > 1 ? '${p.count}×' : ''}${DiceRoll.dieName(p.die)}'
            '${p.mode == 'adv' ? ' ▲' : (p.mode == 'dis' ? ' ▼' : '')}',
    ];
    final m = _mod == 0 ? '' : (_mod > 0 ? ' +$_mod' : ' $_mod');
    return '${parts.join(' + ')}$m';
  }

  Future<void> _roll() async {
    if (_pool.isEmpty) return;
    final DiceRoll roll;
    final single = _pool.length == 1 &&
        _mod == 0 &&
        (_pool.first.mode == 'normal' || _pool.first.count == 1);
    if (single) {
      final p = _pool.first;
      final values =
          DiceRoll.roll(p.die, p.mode == 'normal' ? p.count : 2, _rnd);
      roll = DiceRoll(
        uid: _uid,
        name: widget.nameProvider(),
        color: widget.colorProvider(),
        die: p.die,
        values: values,
        hidden: _hidden,
        at: DateTime.now(),
        mode: p.mode,
        chosen: DiceRoll.pickIndex(p.mode, values),
      );
    } else {
      // Con ventaja/desventaja cada dado se tira dos veces por separado.
      final groups = <DiceGroup>[];
      for (final p in _pool) {
        if (p.mode == 'normal') {
          groups.add(DiceGroup(die: p.die, values: DiceRoll.roll(p.die, p.count, _rnd)));
        } else {
          for (var i = 0; i < p.count; i++) {
            final v = DiceRoll.roll(p.die, 2, _rnd);
            groups.add(DiceGroup(
              die: p.die,
              values: v,
              mode: p.mode,
              chosen: DiceRoll.pickIndex(p.mode, v),
            ));
          }
        }
      }
      if (_mod != 0 && groups.isNotEmpty) {
        final g = groups.last;
        groups[groups.length - 1] = DiceGroup(
          die: g.die,
          values: g.values,
          mode: g.mode,
          chosen: g.chosen,
          mod: _mod,
        );
      }
      roll = DiceRoll(
        uid: _uid,
        name: widget.nameProvider(),
        color: widget.colorProvider(),
        die: 'mix',
        values: [for (final g in groups) ...g.values],
        hidden: _hidden,
        at: DateTime.now(),
        groups: groups,
        title: _formula,
      );
    }
    setState(() {
      _last = roll;
      _seq++;
    });

    if (_hidden) {
      try {
        await _service.postHiddenRoll(widget.gameCode, roll);
        _snack('${tr('Tirada oculta')} · ${roll.label}: ${roll.resultText}');
      } catch (e) {
        _snack('${tr('No se pudo guardar la tirada oculta')}: $e');
      }
      return;
    }

    setState(() => _rolling = true);
    try {
      await _service.postRoll(widget.gameCode, roll);
    } catch (e) {
      _snack('${tr('No se pudo publicar la tirada')}: $e');
    } finally {
      if (mounted) setState(() => _rolling = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _stepper(int v, void Function(int) set, int min, int max,
      {String Function(int)? fmt}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: v > min ? () => setState(() => set(v - 1)) : null,
          child: Icon(Icons.remove_circle_outline,
              size: 20, color: v > min ? null : Colors.grey.shade700),
        ),
        SizedBox(
          width: 30,
          child: Text(
            fmt != null ? fmt(v) : '$v',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        InkWell(
          onTap: v < max ? () => setState(() => set(v + 1)) : null,
          child: Icon(Icons.add_circle_outline,
              size: 20, color: v < max ? null : Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _poolRow(int i) {
    final p = _pool[i];
    final isCoin = p.die == 'coin';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 4, 2),
      child: Row(
        children: [
          _stepper(p.count, (v) => p.count = v, 1, 10),
          const SizedBox(width: 4),
          SizedBox(
            width: 62,
            child: Text(DiceRoll.dieName(p.die),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (!isCoin)
            for (final (m, icon, color, tip) in [
              ('normal', Icons.casino_outlined, Colors.grey, tr('Normal')),
              ('adv', Icons.keyboard_double_arrow_up, Colors.green, tr('Ventaja')),
              ('dis', Icons.keyboard_double_arrow_down, Colors.red, tr('Desventaja')),
            ])
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: tip,
                isSelected: p.mode == m,
                style: IconButton.styleFrom(
                  backgroundColor: p.mode == m ? color.withOpacity(0.2) : null,
                ),
                onPressed: () => setState(() => p.mode = m),
                icon: Icon(icon, size: 18, color: color),
              ),
          const Spacer(),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: tr('Quitar'),
            onPressed: () => setState(() => _pool.removeAt(i)),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dados: tocar uno lo añade a la tirada
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
          child: Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              for (final d in DiceRoll.dice)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(DiceRoll.dieName(d)),
                  onPressed: () => _addDie(d),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Tx(
            'Toca los dados para añadirlos. ▲ ventaja · ▼ desventaja (se tira dos veces y cuenta el mayor o el menor).',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        if (_pool.isEmpty)
          Padding(
            padding: const EdgeInsets.all(10),
            child: Tx('Elige al menos un dado.',
                style: TextStyle(color: Colors.grey.shade600)),
          ),
        for (var i = 0; i < _pool.length; i++) _poolRow(i),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          child: Row(
            children: [
              const Tx('Modificador'),
              const SizedBox(width: 6),
              _stepper(_mod, (v) => _mod = v, -20, 30,
                  fmt: (v) => v > 0 ? '+$v' : '$v'),
              const Spacer(),
              const Tx('Oculta'),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  value: _hidden,
                  onChanged: (v) => setState(() => _hidden = v),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _rolling || _pool.isEmpty ? null : _roll,
              icon: AppIcon(_hidden ? 'ojo' : 'd20_vacio', size: 22),
              label: Text(
                '${tr('Tirar')} $_formula'
                '${_hidden ? ' (${tr('oculta')})' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Text(
            _hidden
                ? tr('La verás tú y el Master.')
                : tr('El resultado se publica en el registro para todos.'),
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ),
        if (_last != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DiceRollAnimation(key: ValueKey(_seq), roll: _last!),
          ),
        const Divider(height: 1),
      ],
    );
  }

  Future<void> _deleteHidden(List<DiceRoll> rolls) async {
    try {
      await _service.deleteHiddenRolls(
          widget.gameCode, [for (final r in rolls) r.id]);
    } catch (e) {
      _snack('${tr('No se pudo borrar')}: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Controles y registro en una sola lista: en horizontal también se
    // puede desplazar para ver todas las tiradas.
    return ValueListenableBuilder<List<DiceRoll>>(
      valueListenable: widget.hiddenRolls,
      builder: (context, hidden, _) {
        return StreamBuilder<List<DiceRoll>>(
          stream: _rollsStream,
          builder: (context, snapshot) {
            final shared = snapshot.data ?? const <DiceRoll>[];

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                _controls(),
                if (snapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No se pudo cargar el registro.\n${snapshot.error}',
                    ),
                  )
                else if (hidden.isEmpty && shared.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Tx(
                        'Todavía no hay tiradas.',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                if (hidden.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Tx(
                            widget.isMaster
                                ? 'Tiradas ocultas (todos los jugadores)'
                                : 'Mis tiradas ocultas (tú y el Master)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (widget.isMaster)
                          TextButton.icon(
                            onPressed: () => _deleteHidden(hidden),
                            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                            label: const Tx('Borrar todas'),
                          ),
                      ],
                    ),
                  ),
                  for (final r in hidden)
                    _RollTile(
                      roll: r,
                      isHidden: true,
                      onDelete: widget.isMaster ? () => _deleteHidden([r]) : null,
                    ),
                  const Divider(),
                ],
                for (final r in shared) _RollTile(roll: r),
              ],
            );
          },
        );
      },
    );
  }
}

class _RollTile extends StatelessWidget {
  final DiceRoll roll;
  final bool isHidden;
  final VoidCallback? onDelete;

  const _RollTile({required this.roll, this.isHidden = false, this.onDelete});

  String _time(DateTime? t) {
    if (t == null) return 'ahora';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: Color(roll.color),
        child: isHidden
            ? const Icon(Icons.visibility_off, size: 14, color: Colors.white)
            : null,
      ),
      title: Text(
        '${roll.name} · ${roll.label}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        roll.values.length > 1 || roll.die == 'coin' || roll.isMix
            ? '${roll.resultText} · ${_time(roll.at)}'
            : _time(roll.at),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            roll.headline,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          if (onDelete != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: tr('Borrar'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
            ),
        ],
      ),
    );
  }
}

/// Un dado (o varios iguales) en la próxima tirada.
class _PoolDie {
  final String die;
  int count = 1;
  String mode = 'normal'; // 'normal', 'adv', 'dis'

  _PoolDie(this.die);
}
