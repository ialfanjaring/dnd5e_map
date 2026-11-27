import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../services/game_service.dart';

/// Chat de la partida: mensajes a todos o privados (jugador → Master y
/// Master → un jugador).
class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.gameCode,
    required this.isMaster,
    required this.messages,
    required this.myUid,
    required this.nick,
    required this.color,
    this.players = const [],
  });

  final String gameCode;
  final bool isMaster;
  final List<ChatMessage> messages;
  final String myUid;
  final String nick;
  final int color;

  /// Jugadores de la partida (uid, nombre): el Master les puede escribir
  final List<(String, String)> players;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _ctrl = TextEditingController();
  final _service = GameService();
  String _to = 'all';
  bool _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _nameOf(String uid) {
    for (final p in widget.players) {
      if (p.$1 == uid) return p.$2;
    }
    return tr('un jugador');
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _service.sendChat(
        widget.gameCode,
        text: text.length > 500 ? text.substring(0, 500) : text,
        to: _to,
        nick: widget.nick,
        color: widget.color,
      );
      _ctrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${tr('No se pudo enviar')}: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// A quién va un mensaje, visto por el usuario actual.
  String? _privateLabel(ChatMessage m) {
    if (!m.isPrivate) return null;
    if (m.to == 'master') {
      return m.uid == widget.myUid ? tr('Solo al Master') : tr('Privado para el Master');
    }
    if (m.uid == widget.myUid) {
      return '${tr('Privado para')} ${_nameOf(m.to)}';
    }
    return tr('Privado del Master');
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final msgs = widget.messages;
    final scheme = Theme.of(context).colorScheme;

    // Destinatarios posibles
    final options = <(String, String)>[
      ('all', tr('Todos')),
      if (!widget.isMaster) ('master', tr('Solo al Master')),
      if (widget.isMaster)
        for (final p in widget.players) (p.$1, '${tr('Solo a')} ${p.$2}'),
    ];
    if (!options.any((o) => o.$1 == _to)) _to = 'all';

    return Column(
      children: [
        Expanded(
          child: msgs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Tx(
                      'Todavía no hay mensajes. Escribe a todos o en privado.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(10),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[msgs.length - 1 - i];
                    final mine = m.uid == widget.myUid;
                    final priv = _privateLabel(m);
                    final color = Color(m.color);
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Card(
                          color: priv != null
                              ? scheme.tertiaryContainer
                              : (mine
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(radius: 5, backgroundColor: color),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        mine ? tr('Tú') : (m.nick.isEmpty ? '?' : m.nick),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: color,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(_time(m.at),
                                        style: TextStyle(
                                            fontSize: 10, color: Colors.grey.shade600)),
                                  ],
                                ),
                                if (priv != null)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_outline, size: 12, color: scheme.onTertiaryContainer),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(priv,
                                            style: TextStyle(
                                                fontSize: 10,
                                                fontStyle: FontStyle.italic,
                                                color: scheme.onTertiaryContainer)),
                                      ),
                                    ],
                                  ),
                                const SizedBox(height: 2),
                                SelectableText(
                                  m.text,
                                  style: TextStyle(
                                    color: priv != null
                                        ? scheme.onTertiaryContainer
                                        : (mine
                                            ? scheme.onPrimaryContainer
                                            : scheme.onSurface),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButton<String>(
                value: _to,
                isExpanded: true,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final o in options)
                    DropdownMenuItem(
                      value: o.$1,
                      child: Row(children: [
                        Icon(o.$1 == 'all' ? Icons.groups_outlined : Icons.lock_outline,
                            size: 16),
                        const SizedBox(width: 6),
                        Flexible(child: Text(o.$2, overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                ],
                onChanged: (v) => setState(() => _to = v ?? 'all'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      maxLength: 500,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: tr('Escribe un mensaje'),
                        counterText: '',
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    tooltip: tr('Enviar'),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
