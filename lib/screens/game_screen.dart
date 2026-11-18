import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/creature.dart';
import '../models/game_models.dart';
import '../services/game_service.dart';
import 'items_screen.dart';
import '../services/monster_api_service.dart';
import '../widgets/avatars.dart';
import '../widgets/creature_sheet_view.dart';
import '../widgets/dice_panel.dart';
import '../widgets/game_board.dart';
import '../widgets/game_creatures_section.dart';
import '../widgets/game_sheet_widgets.dart';

enum _Tool { move, paint, erase }

/// Pantalla de la partida: mapa de cuadrículas con las fichas, dados y
/// ficha del jugador. El Master además tiene herramientas de mapa y puede
/// añadir NPC y monstruos.
class GameScreen extends StatefulWidget {
  final String gameCode;
  final bool isMaster;

  const GameScreen({super.key, required this.gameCode, required this.isMaster});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _service = GameService();
  final _monsterApi = MonsterApiService();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _heartbeat;
  bool _ended = false;

  Map<String, dynamic> _game = {};
  List<GamePlayer> _players = [];
  List<GameToken> _tokens = [];
  Map<String, String> _terrain = {};
  List<DiceRoll> _rolls = [];
  final ValueNotifier<List<DiceRoll>> _hiddenRolls =
      ValueNotifier<List<DiceRoll>>([]);
  Object? _error;

  _Tool _tool = _Tool.move;
  String _brush = 'wall';
  String? _selectedId;
  int _fitSignal = 0;

  // Casillas pintadas pendientes de guardar (null = borrar)
  final Map<String, String?> _paintBuffer = {};
  Timer? _flushTimer;
  bool _assigningColors = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _code => widget.gameCode;

  int get _cols => ((_game['cols'] ?? 20) as num).toInt();
  int get _rows => ((_game['rows'] ?? 14) as num).toInt();
  int get _masterColor =>
      ((_game['masterColor'] ?? GameColors.palette.first) as num).toInt();

  GamePlayer? _playerOf(String uid) {
    for (final p in _players) {
      if (p.uid == uid) return p;
    }
    return null;
  }

  int get _myColor => widget.isMaster
      ? _masterColor
      : (_playerOf(_uid)?.color ?? GameColors.palette.first);

  String get _myName => widget.isMaster
      ? 'Master'
      : (_playerOf(_uid)?.character.name ?? 'Jugador');

  GameToken? get _selected {
    for (final t in _tokens) {
      if (t.id == _selectedId) return t;
    }
    return null;
  }

  Map<String, String> get _displayTerrain {
    final m = Map<String, String>.from(_terrain);
    _paintBuffer.forEach((key, value) {
      if (value == null) {
        m.remove(key);
      } else {
        m[key] = value;
      }
    });
    return m;
  }

  @override
  void initState() {
    super.initState();
    _listen();

    // Marca la partida como activa mientras el mapa está abierto
    _service.touch(_code).catchError((_) {});
    _heartbeat = Timer.periodic(const Duration(minutes: 5), (_) {
      _service.touch(_code).catchError((_) {});
    });

    if (widget.isMaster) {
      _service.ensureCreatureTokens(_code).catchError(_onError);
    } else {
      _service.ensurePlayerToken(_code).catchError(_onError);
    }
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _flushTimer?.cancel();
    if (_paintBuffer.isNotEmpty) {
      _service.paintCells(_code, Map<String, String?>.from(_paintBuffer));
    }
    _hiddenRolls.dispose();
    super.dispose();
  }

  void _onError(Object e, [StackTrace? st]) {
    // Al terminar la sesión se borra la partida y los permisos fallan: es normal
    if (!mounted || _ended) return;
    setState(() => _error = e);
  }

  void _listen() {
    _subs.add(_service.gameStream(_code).listen((g) {
      if (!mounted) return;
      if ((g == null || g['status'] == 'ended') && !_ended) {
        _onSessionEnded();
        return;
      }
      setState(() => _game = g ?? {});
      _assignColorsIfNeeded();
    }, onError: _onError));

    _subs.add(_service.players(_code).listen((p) {
      if (!mounted) return;
      setState(() => _players = p);
      _assignColorsIfNeeded();
    }, onError: _onError));

    _subs.add(_service.tokens(_code, isMaster: widget.isMaster).listen((t) {
      if (!mounted) return;
      setState(() {
        _tokens = t;
        if (_selectedId != null && _selected == null) _selectedId = null;
      });
      _prefetchNames();
    }, onError: _onError));

    _subs.add(_service.terrain(_code).listen((t) {
      if (!mounted) return;
      setState(() => _terrain = t);
    }, onError: _onError));

    _subs.add(_service.rolls(_code).listen((r) {
      if (!mounted) return;
      setState(() => _rolls = r);
    }, onError: _onError));
  }

  /// La sesión terminó (el Master la cerró o la partida ya no existe).
  Future<void> _onSessionEnded() async {
    _ended = true;
    _heartbeat?.cancel();
    if (widget.isMaster) {
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Sesión terminada'),
        content: const Text('El Master ha terminado la sesión.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// Solo el Master: termina la sesión y borra la partida.
  Future<void> _endSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terminar la sesión'),
        content: const Text(
          'Se avisará a los jugadores y la partida se borrará por completo '
          '(mapa, fichas y criaturas). Tus personajes, bestiario y mapas '
          'guardados no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Terminar sesión'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    _ended = true;
    _heartbeat?.cancel();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.endGame(_code);
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('Sesión terminada y partida borrada.')),
      );
    } catch (e) {
      _ended = false;
      _snack('No se pudo terminar la sesión: $e');
    }
  }

  /// El Master asigna color a los jugadores que entran con la partida empezada.
  void _assignColorsIfNeeded() {
    if (!widget.isMaster || _assigningColors) return;
    if (_game['masterColor'] == null) return;
    if (!_players.any((p) => p.color == null)) return;

    _assigningColors = true;
    _service
        .assignMissingColors(_code, _players, _masterColor)
        .catchError(_onError)
        .whenComplete(() => _assigningColors = false);
  }

  /// Los nombres de los monstruos de la API no se guardan: se consultan.
  void _prefetchNames() {
    for (final t in _tokens) {
      final api = t.apiIndex;
      if (api == null ||
          t.label.isNotEmpty ||
          _monsterApi.cachedMonster(api) != null) {
        continue;
      }
      _monsterApi.fetchMonster(api).then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    }
  }

  String _nameOf(GameToken t) {
    if (t.isPlayer) return _playerOf(t.refId)?.character.name ?? '?';
    if (t.label.isNotEmpty) return t.label;

    final api = t.apiIndex;
    if (api != null) {
      final c = _monsterApi.cachedMonster(api);
      if (c != null) return t.number > 1 ? '${c.name} ${t.number}' : c.name;
    }
    return '…';
  }

  /// Imagen por defecto de la ficha según clase, NPC o tipo de monstruo.
  IconData _iconOf(GameToken t) {
    if (t.isPlayer) {
      final cls = _playerOf(t.refId)?.character.characterClass ?? '';
      return Avatars.classIcon(cls);
    }
    if (t.icon.isNotEmpty) return Avatars.iconForTokenKey(t.icon);

    final api = t.apiIndex;
    final c = api == null ? null : _monsterApi.cachedMonster(api);
    if (c != null) {
      return Avatars.creatureIcon(isNpc: !c.isMonster, type: c.creatureType);
    }
    return Avatars.defaultIcon;
  }

  Color _colorOf(GameToken t) {
    if (t.isPlayer) {
      final c = _playerOf(t.refId)?.color;
      return c == null ? Colors.grey : Color(c);
    }
    return Color(_masterColor);
  }

  bool _canMove(GameToken t) =>
      widget.isMaster || (t.isPlayer && t.refId == _uid);

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------
  // INTERACCIÓN CON EL MAPA
  // ---------------------------------------------------------------

  /// Fichas que están en el mapa (las ocultas esperan fuera de él).
  List<GameToken> get _onMap => _tokens.where((t) => !t.hidden).toList();

  /// Fichas ocultas: solo las ve el Master, en la zona "fuera del mapa".
  List<GameToken> get _offMap => _tokens.where((t) => t.hidden).toList();

  GameToken? _tokenAt(int x, int y) {
    GameToken? hit;
    for (final t in _onMap) {
      if (t.covers(x, y)) {
        hit = t;
        if (t.id == _selectedId) return t;
      }
    }
    return hit;
  }

  void _onCellTap(int x, int y) {
    final hit = _tokenAt(x, y);

    // Tocar una ficha la selecciona (o la deselecciona)
    if (hit != null) {
      setState(() => _selectedId = hit.id == _selectedId ? null : hit.id);
      return;
    }

    // Tocar una casilla vacía mueve la ficha seleccionada. Si estaba fuera
    // del mapa, la coloca en esa casilla.
    final sel = _selected;
    if (sel != null && _canMove(sel)) {
      final nx = x > _cols - sel.span ? _cols - sel.span : x;
      final ny = y > _rows - sel.span ? _rows - sel.span : y;
      if (sel.hidden) {
        _service
            .placeTokenOnMap(_code, sel.id, x: nx, y: ny)
            .catchError(_onError);
      } else {
        _service.moveToken(_code, sel.id, nx, ny).catchError(_onError);
      }
    }
  }

  void _onCellPaint(int x, int y) {
    if (!widget.isMaster || _tool == _Tool.move) return;

    final key = cellKey(x, y);
    final value = _tool == _Tool.erase ? null : _brush;

    if (_paintBuffer.containsKey(key) && _paintBuffer[key] == value) return;

    setState(() => _paintBuffer[key] = value);

    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 400), _flushPaint);
  }

  Future<void> _flushPaint() async {
    if (_paintBuffer.isEmpty) return;

    final batch = Map<String, String?>.from(_paintBuffer);
    try {
      await _service.paintCells(_code, batch);
    } catch (e) {
      _onError(e);
    }

    if (!mounted) return;
    setState(() {
      batch.forEach((key, value) {
        if (_paintBuffer[key] == value) _paintBuffer.remove(key);
      });
    });
  }

  // ---------------------------------------------------------------
  // ACCIONES DEL MASTER
  // ---------------------------------------------------------------

  Future<void> _openTokenSheet(GameToken t) async {
    if (t.isPlayer) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerSheetScreen(
            gameCode: _code,
            uid: t.refId,
            title: _nameOf(t),
            isMaster: widget.isMaster,
          ),
        ),
      );
      return;
    }

    if (!widget.isMaster) return;

    try {
      final gc = await _service.getGameCreature(_code, t.id);
      if (gc == null) {
        _snack('Esa criatura ya no está en la partida.');
        return;
      }

      final Creature creature =
          gc.snapshot ?? await _monsterApi.fetchMonster(gc.apiIndex!);
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CreatureSheetScreen(creature: creature, title: _nameOf(t)),
        ),
      );
    } catch (e) {
      _snack('No se pudo abrir la ficha: $e');
    }
  }

  Future<void> _renameToken(GameToken t) async {
    final ctrl = TextEditingController(text: t.label);

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nombre de la ficha'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Vacío = nombre original',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (value == null) return;
    _service.setTokenLabel(_code, t.id, value).catchError(_onError);
  }

  Future<void> _removeCreature(GameToken t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar de la partida'),
        content: Text('¿Quitar "${_nameOf(t)}" de la partida y del mapa?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(() => _selectedId = null);
    _service.removeCreature(_code, t.id).catchError(_onError);
  }

  Future<void> _gridSizeDialog() async {
    var cols = _cols;
    var rows = _rows;

    final result = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Tamaño del mapa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepper('Columnas', cols, (v) => setLocal(() => cols = v)),
              _stepper('Filas', rows, (v) => setLocal(() => rows = v)),
              const SizedBox(height: 8),
              const Text(
                'Las fichas que queden fuera se acercarán al borde.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, (cols, rows)),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;
    _service.setGridSize(_code, result.$1, result.$2).catchError(_onError);
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          onPressed: value > 5 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: value < 60 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }

  Future<void> _confirmClearTerrain() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpiar terreno'),
        content: const Text('Se borrará todo lo pintado en el mapa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(_paintBuffer.clear);
    _service.clearTerrain(_code).catchError(_onError);
  }

  // ---------------------------------------------------------------
  // INTERFAZ
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          (_game['name'] ?? 'Partida').toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (widget.isMaster)
            IconButton(
              tooltip: 'Objetos (armas, armaduras...) para asignar',
              icon: const Icon(Icons.inventory_2_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ItemsScreen(gameCode: _code),
                ),
              ),
            ),
          if (widget.isMaster)
            IconButton(
              tooltip: 'Terminar la sesión (borra la partida)',
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _endSession,
            ),
          IconButton(
            tooltip: 'Salir del mapa',
            icon: const Icon(Icons.exit_to_app),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          final board = _buildBoardArea();

          if (wide) {
            return Row(
              children: [
                Expanded(child: board),
                const VerticalDivider(width: 1),
                SizedBox(width: 380, child: _buildSidePanel()),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: board),
              _buildBottomBar(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoardArea() {
    return Column(
      children: [
        if (_error != null)
          MaterialBanner(
            content: Text(
              'Problema con la partida: $_error\n'
              'Si es un error de permisos, publica las reglas de Firestore '
              'más recientes.',
            ),
            actions: [
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        _buildLastRoll(),
        _buildToolbar(),
        Expanded(
          child: GameBoard(
            cols: _cols,
            rows: _rows,
            terrain: _displayTerrain,
            tokens: _onMap,
            selectedId: _selectedId,
            colorOf: _colorOf,
            nameOf: _nameOf,
            iconOf: _iconOf,
            paintMode: widget.isMaster && _tool != _Tool.move,
            fitSignal: _fitSignal,
            onCellTap: _onCellTap,
            onCellPaint: _onCellPaint,
          ),
        ),
        _buildOffMapTray(),
        _buildSelectedBar(),
      ],
    );
  }

  /// Zona fuera del mapa (solo Master): fichas ocultas que los jugadores
  /// no ven. Desde aquí se colocan en el mapa o se quitan de la partida.
  Widget _buildOffMapTray() {
    if (!widget.isMaster) return const SizedBox.shrink();
    final off = _offMap;
    if (off.isEmpty) return const SizedBox.shrink();

    return Material(
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.visibility_off, size: 16),
                const SizedBox(width: 6),
                Text(
                  'Fuera del mapa (${off.length}) · los jugadores no lo ven',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: off.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = off[i];
                  final selected = t.id == _selectedId;

                  return Material(
                    color: selected ? Colors.amber.shade100 : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: selected ? Colors.amber : Colors.grey.shade400,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(
                        () => _selectedId = selected ? null : t.id,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: _colorOf(t),
                              child: Icon(
                                _iconOf(t),
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 130),
                              child: Text(
                                _nameOf(t),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Colocar en el mapa',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.login, size: 20),
                              onPressed: () => _service
                                  .placeTokenOnMap(_code, t.id)
                                  .catchError(_onError),
                            ),
                            IconButton(
                              tooltip: 'Quitar de la partida',
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _removeCreature(t),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_selected?.hidden == true)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Toca una casilla del mapa para colocar la ficha elegida.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Última tirada descubierta, siempre visible.
  Widget _buildLastRoll() {
    if (_rolls.isEmpty) return const SizedBox.shrink();

    final r = _rolls.first;
    return Container(
      width: double.infinity,
      color: Color(r.color).withAlpha(40),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          CircleAvatar(radius: 8, backgroundColor: Color(r.color)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${r.name} · ${r.label}: ${r.resultText}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            r.headline,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Material(
      color: Colors.grey.shade200,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            if (widget.isMaster) ...[
              SegmentedButton<_Tool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _Tool.move,
                    icon: Icon(Icons.pan_tool_alt_outlined),
                    label: Text('Mover'),
                  ),
                  ButtonSegment(
                    value: _Tool.paint,
                    icon: Icon(Icons.brush),
                    label: Text('Pintar'),
                  ),
                  ButtonSegment(
                    value: _Tool.erase,
                    icon: Icon(Icons.cleaning_services_outlined),
                    label: Text('Borrar'),
                  ),
                ],
                selected: {_tool},
                onSelectionChanged: (s) => setState(() => _tool = s.first),
              ),
              const SizedBox(width: 8),
              if (_tool == _Tool.paint)
                for (final t in Terrains.all)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      avatar: Icon(t.icon, size: 16, color: Color(t.color)),
                      label: Text(t.name),
                      selected: _brush == t.id,
                      onSelected: (_) => setState(() => _brush = t.id),
                    ),
                  ),
              IconButton(
                tooltip: 'Tamaño del mapa',
                icon: const Icon(Icons.grid_on),
                onPressed: _gridSizeDialog,
              ),
              IconButton(
                tooltip: 'Limpiar terreno',
                icon: const Icon(Icons.layers_clear),
                onPressed: _confirmClearTerrain,
              ),
            ],
            if (!widget.isMaster)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  'Toca tu ficha y luego una casilla para moverla',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedBar() {
    final t = _selected;
    if (t == null) return const SizedBox.shrink();

    final canOpenSheet = widget.isMaster || (t.isPlayer && t.refId == _uid);

    return Material(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            CircleAvatar(radius: 12, backgroundColor: _colorOf(t)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t.hidden
                    ? '${_nameOf(t)} · fuera del mapa'
                    : '${_nameOf(t)} · (${t.x + 1}, ${t.y + 1})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (canOpenSheet)
              IconButton(
                tooltip: 'Ver ficha',
                icon: const Icon(Icons.description_outlined),
                onPressed: () => _openTokenSheet(t),
              ),
            if (widget.isMaster && !t.isPlayer) ...[
              IconButton(
                tooltip: t.hidden
                    ? 'Colocar en el mapa'
                    : 'Sacar del mapa (oculta a los jugadores)',
                icon: Icon(t.hidden ? Icons.login : Icons.logout),
                onPressed: () => (t.hidden
                        ? _service.placeTokenOnMap(_code, t.id)
                        : _service.setTokenHidden(_code, t.id, true))
                    .catchError(_onError),
              ),
              PopupMenuButton<int>(
                tooltip: 'Tamaño de la ficha',
                icon: const Icon(Icons.open_in_full),
                onSelected: (v) =>
                    _service.setTokenSpan(_code, t.id, v).catchError(_onError),
                itemBuilder: (_) => [
                  for (final v in const [1, 2, 3, 4])
                    PopupMenuItem(
                      value: v,
                      child: Text(v == 1 ? 'Normal (1×1)' : '$v×$v casillas'),
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Cambiar nombre',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _renameToken(t),
              ),
              IconButton(
                tooltip: 'Quitar de la partida',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeCreature(t),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------
  // PANELES (DADOS, FICHA, JUGADORES, CRIATURAS)
  // ---------------------------------------------------------------

  Widget _dicePanel() => DicePanel(
        gameCode: _code,
        hiddenRolls: _hiddenRolls,
        nameProvider: () => _myName,
        colorProvider: () => _myColor,
      );

  Widget _sheetPanel() => widget.isMaster
      ? PlayersPanel(gameCode: _code)
      : PlayerLiveSheet(gameCode: _code, uid: _uid, canEdit: true);

  Widget _creaturesPanel() => ListView(
        padding: const EdgeInsets.all(12),
        children: [GameCreaturesSection(gameCode: _code)],
      );

  /// Panel lateral (pantallas anchas).
  Widget _buildSidePanel() {
    final tabs = <Tab>[
      const Tab(text: 'Dados'),
      Tab(text: widget.isMaster ? 'Jugadores' : 'Mi ficha'),
      if (widget.isMaster) const Tab(text: 'Criaturas'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          TabBar(tabs: tabs),
          Expanded(
            child: TabBarView(
              children: [
                _dicePanel(),
                _sheetPanel(),
                if (widget.isMaster) _creaturesPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Barra inferior (pantallas estrechas): abre los paneles como hojas.
  Widget _buildBottomBar() {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            TextButton.icon(
              onPressed: () => _openSheet('Dados y registro', _dicePanel()),
              icon: const Icon(Icons.casino),
              label: const Text('Dados'),
            ),
            TextButton.icon(
              onPressed: () => _openSheet(
                widget.isMaster ? 'Jugadores' : 'Mi ficha',
                _sheetPanel(),
              ),
              icon: Icon(widget.isMaster ? Icons.groups : Icons.badge_outlined),
              label: Text(widget.isMaster ? 'Jugadores' : 'Mi ficha'),
            ),
            if (widget.isMaster)
              TextButton.icon(
                onPressed: () => _openSheet('Criaturas', _creaturesPanel()),
                icon: const Icon(Icons.pets),
                label: const Text('Criaturas'),
              ),
          ],
        ),
      ),
    );
  }

  void _openSheet(String title, Widget child) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.85,
        child: Column(
          children: [
            ListTile(
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            const Divider(height: 1),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
