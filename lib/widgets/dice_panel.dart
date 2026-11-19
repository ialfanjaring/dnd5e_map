import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/game_models.dart';
import '../services/game_service.dart';
import '../i18n/i18n.dart';
import 'app_icon.dart';

/// Tirada de dados y registro de la partida.
///
/// - Descubierta: se publica y la ven todos en el registro.
/// - Oculta: solo la ve quien la hace (queda en su lista privada).
class DicePanel extends StatefulWidget {
  final String gameCode;

  /// Tiradas ocultas de esta sesión (solo locales)
  final ValueNotifier<List<DiceRoll>> hiddenRolls;

  /// Nombre y color de quien tira, consultados en el momento de la tirada
  final String Function() nameProvider;
  final int Function() colorProvider;

  const DicePanel({
    super.key,
    required this.gameCode,
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

  String _die = 'd20';
  int _count = 1;
  bool _hidden = false;
  bool _rolling = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _rollsStream = _service.rolls(widget.gameCode);
  }

  Future<void> _roll() async {
    final roll = DiceRoll(
      uid: _uid,
      name: widget.nameProvider(),
      color: widget.colorProvider(),
      die: _die,
      values: DiceRoll.roll(_die, _count, _rnd),
      hidden: _hidden,
      at: DateTime.now(),
    );

    if (_hidden) {
      // Solo la ve quien la hace
      widget.hiddenRolls.value = [roll, ...widget.hiddenRolls.value];
      _snack('Tirada oculta · ${roll.label}: ${roll.resultText}');
      return;
    }

    setState(() => _rolling = true);
    try {
      await _service.postRoll(widget.gameCode, roll);
    } catch (e) {
      _snack('No se pudo publicar la tirada: $e');
    } finally {
      if (mounted) setState(() => _rolling = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _controls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

        // BOTÓN TIRAR
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 4),
          child: SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: _rolling ? null : _roll,
              icon: AppIcon(_hidden ? 'ojo' : 'd20_vacio', size: 22),
              label: Text(
                'Tirar ${_count > 1 ? '$_count × ' : ''}'
                '${DiceRoll.dieName(_die)}'
                '${_hidden ? ' (oculta)' : ''}',
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          child: Text(
            _hidden
                ? 'Solo verás tú el resultado.'
                : 'El resultado se publica en el registro para todos.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
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
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 8, 12, 2),
                    child: Tx(
                      'Mis tiradas ocultas (solo tú)',
                      style: TextStyle(
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
        roll.values.length > 1 || roll.die == 'coin'
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
