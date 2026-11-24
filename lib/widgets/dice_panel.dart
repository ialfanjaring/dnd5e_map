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

  String _die = 'd20';
  int _count = 1;
  bool _hidden = false;
  bool _rolling = false;

  /// 'normal', 'adv' o 'dis' (solo con un dado que no sea la moneda)
  String _mode = 'normal';

  /// Última tirada hecha aquí, para animarla.
  DiceRoll? _last;
  int _seq = 0;

  bool get _canMode => _count == 1 && _die != 'coin';

  /// Tirada compuesta: varios grupos de dados (ataque, daño cortante,
  /// daño de hielo…) con su modificador cada uno.
  bool _compose = false;
  final List<_GroupDraft> _drafts = [
    _GroupDraft(die: 'd20', label: tr('Ataque')),
    _GroupDraft(die: 'd8', label: tr('Cortante')),
  ];
  final _titleCtl = TextEditingController();

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
    _titleCtl.dispose();
    super.dispose();
  }

  Future<void> _roll() async {
    final DiceRoll roll;
    if (_compose) {
      final groups = <DiceGroup>[];
      for (final d in _drafts) {
        final m = d.count == 1 ? d.mode : 'normal';
        final vals = DiceRoll.roll(d.die, m == 'normal' ? d.count : 2, _rnd);
        groups.add(DiceGroup(
          die: d.die,
          values: vals,
          label: d.label,
          mod: d.mod,
          mode: m,
          chosen: DiceRoll.pickIndex(m, vals),
        ));
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
        title: _titleCtl.text.trim(),
      );
    } else {
      final mode = _canMode ? _mode : 'normal';
      final values = DiceRoll.roll(_die, mode == 'normal' ? _count : 2, _rnd);
      roll = DiceRoll(
        uid: _uid,
        name: widget.nameProvider(),
        color: widget.colorProvider(),
        die: _die,
        values: values,
        hidden: _hidden,
        at: DateTime.now(),
        mode: mode,
        chosen: DiceRoll.pickIndex(mode, values),
      );
    }
    setState(() {
      _last = roll;
      _seq++;
    });

    if (_hidden) {
      // La ven quien la hace y el Master
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

  List<Widget> _composer() {
    final dice = DiceRoll.dice.where((d) => d != 'coin').toList();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
        child: TextField(
          controller: _titleCtl,
          maxLength: 40,
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            border: const OutlineInputBorder(),
            labelText: tr('Nombre de la tirada (opcional)'),
            hintText: tr('Espada de hielo'),
          ),
        ),
      ),
      for (var i = 0; i < _drafts.length; i++) _groupEditor(i, dice),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: _drafts.length >= 6
                  ? null
                  : () => setState(
                      () => _drafts.add(_GroupDraft(die: 'd6', label: tr('Hielo')))),
              icon: const Icon(Icons.add, size: 18),
              label: Text(tr('Añadir grupo de dados')),
            ),
            const Spacer(),
            Text(tr('Oculta')),
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
    ];
  }

  Widget _groupEditor(int i, List<String> dice) {
    final d = _drafts[i];
    final tint = Color(DiceGroup.colorOf(d.label));
    Widget stepper(int v, void Function(int) set, int min, int max,
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

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      padding: const EdgeInsets.fromLTRB(8, 4, 4, 6),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: tint, width: 4)),
        color: tint.withOpacity(0.08),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isDense: true,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  value: d.label,
                  items: [
                    for (final k in DiceGroup.kinds)
                      DropdownMenuItem(
                        value: k,
                        child: Text(tr(k),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(DiceGroup.colorOf(k)))),
                      ),
                  ],
                  onChanged: (v) => setState(() => d.label = v ?? d.label),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: tr('Quitar grupo'),
                onPressed: _drafts.length > 1
                    ? () => setState(() => _drafts.removeAt(i))
                    : null,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              stepper(d.count, (v) => d.count = v, 1, 10),
              DropdownButton<String>(
                isDense: true,
                value: d.die,
                items: [
                  for (final x in dice)
                    DropdownMenuItem(value: x, child: Text(DiceRoll.dieName(x))),
                ],
                onChanged: (v) => setState(() => d.die = v ?? d.die),
              ),
              stepper(d.mod, (v) => d.mod = v, -20, 30,
                  fmt: (v) => v > 0 ? '+$v' : '$v'),
              if (d.count == 1)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  showCheckmark: false,
                  label: Text(
                    d.mode == 'adv'
                        ? '▲ ${tr('Ventaja')}'
                        : (d.mode == 'dis' ? '▼ ${tr('Desventaja')}' : tr('Normal')),
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: d.mode != 'normal',
                  onSelected: (_) => setState(() => d.mode =
                      d.mode == 'normal' ? 'adv' : (d.mode == 'adv' ? 'dis' : 'normal')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _controls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SIMPLE / COMPUESTA
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: SegmentedButton<bool>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              ButtonSegment(value: false, label: Text(tr('Simple'))),
              ButtonSegment(value: true, label: Text(tr('Combinada'))),
            ],
            selected: {_compose},
            onSelectionChanged: (v) => setState(() => _compose = v.first),
          ),
        ),
        if (!_compose) ...[
        // SELECCIÓN DE DADO
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
          child: Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              for (final d in DiceRoll.dice)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  label: Text(DiceRoll.dieName(d)),
                  selected: _die == d,
                  onSelected: (_) => setState(() => _die = d),
                ),
            ],
          ),
        ),

        // CANTIDAD Y OCULTA
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              const Tx('Cantidad'),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _count > 1 ? () => setState(() => _count--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$_count',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: _count < 10 ? () => setState(() => _count++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
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

        // NORMAL / VENTAJA / DESVENTAJA
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          child: Row(
            children: [
              for (final (m, label, icon, color) in [
                ('normal', tr('Normal'), Icons.casino_outlined, Colors.grey),
                ('adv', tr('Ventaja'), Icons.keyboard_double_arrow_up, Colors.green),
                ('dis', tr('Desventaja'), Icons.keyboard_double_arrow_down, Colors.red),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: EdgeInsets.zero,
                      showCheckmark: false,
                      avatar: Icon(icon, size: 14, color: color),
                      label: Text(tr(label), style: const TextStyle(fontSize: 11)),
                      selected: (_canMode ? _mode : 'normal') == m,
                      onSelected: _canMode || m == 'normal'
                          ? (_) => setState(() => _mode = m)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ),

        ] else
          ..._composer(),

        // BOTÓN TIRAR
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _rolling ? null : _roll,
              icon: AppIcon(_hidden ? 'ojo' : 'd20_vacio', size: 22),
              label: Text(
                _compose
                    ? '${tr('Tirar combinada')}${_hidden ? ' (${tr('oculta')})' : ''}'
                    : '${tr('Tirar')} ${_count > 1 ? '$_count × ' : ''}'
                '${DiceRoll.dieName(_die)}'
                '${!_compose && _canMode && _mode == 'adv' ? ' ${tr('con ventaja')}' : ''}'
                '${!_compose && _canMode && _mode == 'dis' ? ' ${tr('con desventaja')}' : ''}'
                '${!_compose && _hidden ? ' (${tr('oculta')})' : ''}',
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
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
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
                  for (final r in hidden) _RollTile(roll: r, isHidden: true),
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

  const _RollTile({required this.roll, this.isHidden = false});

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
      trailing: Text(
        roll.headline,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Un grupo de dados en edición dentro de la tirada combinada.
class _GroupDraft {
  String die;
  int count;
  String label;
  int mod;
  String mode; // 'normal', 'adv', 'dis'

  _GroupDraft({
    required this.die,
    required this.label,
    this.count = 1,
    this.mod = 0,
    this.mode = 'normal',
  });
}
