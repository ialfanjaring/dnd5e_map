import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../models/game_models.dart';
import '../services/game_service.dart';

/// Salvaciones de muerte de un personaje a 0 PG.
///
/// - d20: 10 o más = éxito; menos de 10 = fallo; 1 = dos fallos;
///   20 = se levanta con 1 PG.
/// - 3 fallos: muere. 3 éxitos: queda estable.
/// - Los contadores se pueden modificar a mano y el Master (o el propio
///   jugador) puede marcar al personaje como muerto o devolverle 1 PG.
class DeathSavesCard extends StatelessWidget {
  final String gameCode;
  final GamePlayer player;

  /// El dueño del personaje o el Master
  final bool canEdit;

  /// Es su turno en el combate: se muestra el aviso destacado
  final bool myTurn;

  const DeathSavesCard({
    super.key,
    required this.gameCode,
    required this.player,
    required this.canEdit,
    this.myTurn = false,
  });

  static bool needsSaves(GamePlayer p) =>
      p.currentHp <= 0 && !p.dead && p.deathFail < 3 && p.deathSuccess < 3;

  Future<void> _roll(BuildContext context) async {
    final service = GameService();
    final messenger = ScaffoldMessenger.of(context);
    final roll = Random().nextInt(20) + 1;

    var success = player.deathSuccess;
    var fail = player.deathFail;
    String msg;

    try {
      final user = FirebaseAuth.instance.currentUser;
      await service.postRoll(
        gameCode,
        DiceRoll(
          uid: user?.uid ?? '',
          name: '${player.character.name} · ${tr('Salvación de muerte')}',
          color: player.color ?? GameColors.palette.first,
          die: 'd20',
          values: [roll],
        ),
      );

      if (roll == 20) {
        // Éxito crítico: se levanta con 1 PG (se reinician los contadores)
        await service.updatePlayerHp(gameCode, player.uid, 1);
        messenger.showSnackBar(SnackBar(
          content: Text('20 · ${player.character.name} ${tr('se levanta con 1 PG')}'),
        ));
        return;
      }
      if (roll == 1) {
        fail += 2;
        msg = '1 · ${tr('Fallo crítico: dos fallos')}';
      } else if (roll >= 10) {
        success += 1;
        msg = '$roll · ${tr('Éxito')}';
      } else {
        fail += 1;
        msg = '$roll · ${tr('Fallo')}';
      }

      final dead = fail >= 3;
      await service.updateDeathSaves(
        gameCode,
        player.uid,
        success: success.clamp(0, 3).toInt(),
        fail: fail.clamp(0, 3).toInt(),
        dead: dead ? true : null,
      );
      if (dead) {
        msg += ' · ${player.character.name} ${tr('ha muerto')}';
      } else if (success >= 3) {
        msg += ' · ${tr('Queda estable')}';
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Widget _pips(
    BuildContext context, {
    required int count,
    required Color color,
    required void Function(int) onSet,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 3; i++)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: canEdit ? () => onSet(count == i ? i - 1 : i) : null,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= count ? color : Colors.transparent,
                  border: Border.all(color: color, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = GameService();
    final dead = player.dead;
    final stable = !dead && player.deathSuccess >= 3;
    final cs = Theme.of(context).colorScheme;

    final title = dead
        ? '${player.character.name} ${tr('ha muerto')}'
        : stable
            ? '${player.character.name}: ${tr('inconsciente y estable')}'
            : '${player.character.name}: ${tr('inconsciente')}';

    return Card(
      color: dead
          ? Colors.black.withAlpha(80)
          : (myTurn ? Colors.red.withAlpha(50) : null),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: dead ? Colors.grey : Colors.red,
          width: myTurn ? 3 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CustomPaint(
                  size: const Size(22, 28),
                  painter: CrossPainter(dead ? Colors.grey : Colors.white,
                      outline: Colors.black),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (myTurn && !dead && !stable) ...[
              const SizedBox(height: 6),
              Tx(
                '¡Es su turno! Hay que hacer una tirada de salvación de muerte '
                '(d20): 10 o más es éxito, menos de 10 es fallo, un 1 cuenta '
                'como dos fallos y un 20 lo levanta con 1 PG. Tres fallos y '
                'muere.',
                style: TextStyle(fontSize: 12, color: cs.onSurface),
              ),
            ],
            if (!dead) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(child: Tx('Éxitos')),
                  _pips(context,
                      count: player.deathSuccess,
                      color: Colors.green,
                      onSet: (n) => service.updateDeathSaves(
                          gameCode, player.uid,
                          success: n)),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Tx('Fallos')),
                  _pips(context,
                      count: player.deathFail,
                      color: Colors.red,
                      onSet: (n) => service.updateDeathSaves(
                          gameCode, player.uid,
                          fail: n, dead: n >= 3 ? true : null)),
                ],
              ),
            ],
            if (canEdit) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (!dead && !stable)
                    FilledButton.icon(
                      onPressed: () => _roll(context),
                      icon: const Icon(Icons.casino),
                      label: const Tx('Tirar salvación'),
                    ),
                  if (!dead)
                    OutlinedButton(
                      onPressed: () => service.updateDeathSaves(
                          gameCode, player.uid,
                          dead: true),
                      child: const Tx('Marcar como muerto'),
                    ),
                  OutlinedButton(
                    onPressed: () =>
                        service.updatePlayerHp(gameCode, player.uid, 1),
                    child: Tx(dead ? 'Revivir con 1 PG' : 'Levantar con 1 PG'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Cruz latina (para los personajes inconscientes o muertos).
class CrossPainter extends CustomPainter {
  final Color color;
  final Color? outline;

  CrossPainter(this.color, {this.outline});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final t = min(w, h) * 0.3;
    final path = Path()
      ..addRect(Rect.fromLTWH((w - t) / 2, 0, t, h))
      ..addRect(Rect.fromLTWH(0, h * 0.28, w, t));
    if (outline != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = outline!
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(1.5, w / 8)
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CrossPainter old) =>
      old.color != color || old.outline != outline;
}
