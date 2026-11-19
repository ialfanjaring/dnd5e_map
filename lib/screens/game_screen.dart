import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character.dart';
import '../models/combat.dart';
import '../models/creature.dart';
import '../models/equipment_effects.dart';
import '../models/movement.dart';
import '../services/class_api_service.dart';
import '../services/equipment_api_service.dart';
import '../models/game_models.dart';
import '../services/game_service.dart';
import 'items_screen.dart';
import 'player_room_screen.dart';
import '../services/monster_api_service.dart';
import '../widgets/avatars.dart';
import '../widgets/blocking_progress.dart';
import '../widgets/creature_sheet_view.dart';
import '../widgets/dice_panel.dart';
import '../widgets/game_board.dart';
import '../widgets/game_creatures_section.dart';
import '../widgets/game_sheet_widgets.dart';
import '../widgets/initiative_panel.dart';

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

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  final _service = GameService();
  final _monsterApi = MonsterApiService();
  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _heartbeat;
  bool _ended = false;
  bool _leavingToRoom = false;

  Map<String, dynamic> _game = {};
  List<GamePlayer> _players = [];
  List<GameToken> _tokens = [];
  Map<String, String> _terrain = {};
  List<DiceRoll> _rolls = [];
  String? _dismissedRollId;
  bool _rollsLoaded = false;
  Timer? _rollTimer;
  final ValueNotifier<List<DiceRoll>> _hiddenRolls =
      ValueNotifier<List<DiceRoll>>([]);
  Object? _error;

  // Paneles desplegables que se superponen al mapa
  late final TabController _tabs;
  bool _panelOpen = false;
  bool _bottomOpen = false;
  static const int _tabInitiative = 1;

  // Iniciativa y turnos
  CombatState? _combat;
  final ValueNotifier<Set<String>> _visibleIds =
      ValueNotifier<Set<String>>(<String>{});

  // Criaturas de la partida (solo el Master las lee): velocidad y características
  Map<String, GameCreature> _gameCreatures = {};

  // Personajes con raza y equipo aplicados (velocidad e iniciativa reales)
  final Map<String, Character> _resolvedChars = {};
  final Map<String, String> _resolvedKeys = {};

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
    // Master: Dados, Iniciativa, Jugadores, Criaturas
    // Jugador: Dados, Iniciativa, Mi ficha
    _tabs = TabController(length: widget.isMaster ? 4 : 3, vsync: this);
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
    _rollTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _flushTimer?.cancel();
    if (_paintBuffer.isNotEmpty) {
      _service.paintCells(_code, Map<String, String?>.from(_paintBuffer));
    }
    _tabs.dispose();
    _hiddenRolls.dispose();
    _visibleIds.dispose();
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
      // El Master reinició la sala: todos vuelven a la sala de espera
      if (g != null && g['status'] == 'lobby' && !_leavingToRoom) {
        _backToRoom();
        return;
      }
      setState(() => _game = g ?? {});
      _assignColorsIfNeeded();
    }, onError: _onError));

    _subs.add(_service.players(_code).listen((p) {
      if (!mounted) return;
      setState(() => _players = p);
      _assignColorsIfNeeded();
      _resolvePlayers();
    }, onError: _onError));

    _subs.add(_service.combat(_code).listen((c) {
      if (!mounted) return;
      setState(() => _combat = c);
    }, onError: _onError));

    if (widget.isMaster) {
      _subs.add(_service.creatures(_code).listen((list) {
        if (!mounted) return;
        setState(() => _gameCreatures = {for (final c in list) c.id: c});
      }, onError: _onError));
    }

    _subs.add(_service.tokens(_code, isMaster: widget.isMaster).listen((t) {
      if (!mounted) return;
      setState(() {
        _tokens = t;
        _visibleIds.value = {for (final x in t) x.id};
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
      final firstLoad = !_rollsLoaded;
      _rollsLoaded = true;
      setState(() {
        _rolls = r;
        if (r.isNotEmpty) {
          if (firstLoad) {
            // Tirada anterior a la entrada: no se muestra.
            _dismissedRollId = r.first.id;
          } else if (r.first.id != _dismissedRollId) {
            _rollTimer?.cancel();
            final id = r.first.id;
            _rollTimer = Timer(const Duration(seconds: 3), () {
              if (mounted) setState(() => _dismissedRollId = id);
            });
          }
        }
      });
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

  /// Vuelve a la sala de espera (Master: sala del Master; jugador: su sala).
  void _backToRoom() {
    if (_leavingToRoom || _ended) return;
    _leavingToRoom = true;
    _heartbeat?.cancel();

    if (widget.isMaster) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PlayerRoomScreen(gameCode: _code),
      ),
    );
  }

  /// Solo el Master: la partida vuelve a la sala de espera.
  Future<void> _resetRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reiniciar la sala'),
        content: const Text(
          'Todos volverán a la sala de espera. Se quitarán las fichas del '
          'mapa, el combate y el registro de dados. Se conservan los '
          'jugadores, las criaturas y el mapa. Podrás cambiar de mapa e '
          'iniciar de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await runBlocking(
        context,
        'Reiniciando la sala…',
        () => _service.resetRoom(_code),
      );
      // La propia suscripción al estado nos devuelve a la sala
    } catch (e) {
      _snack('No se pudo reiniciar la sala: $e');
    }
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
      await runBlocking(
        context,
        'Terminando la sesión…',
        () => _service.endGame(_code),
      );
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

  // ---------------------------------------------------------------
  // MOVIMIENTO E INICIATIVA
  // ---------------------------------------------------------------

  /// Calcula (y guarda) los personajes con raza y equipo aplicados.
  Future<Character> _resolvePlayer(GamePlayer p) async {
    final c = p.character;
    final key = [
      c.race,
      c.subrace,
      c.items.join(','),
      c.equipped.join(','),
      c.abilities.entries.map((e) => '${e.key}${e.value}').join(),
      c.speed,
      c.armorClass,
    ].join('|');

    final cached = _resolvedChars[p.uid];
    if (cached != null && _resolvedKeys[p.uid] == key) return cached;

    try {
      EquipmentApiService.registerCustomMap(c.customItems);
      final racial =
          await ClassApiService().fetchRacialBonuses(c.race, c.subrace);
      final items = await EquipmentApiService().fetchItems(c.items);
      final base = c.withRacial(racial);
      final effects = EquipmentEffects.compute(base, items);
      final resolved = base.withDerived(
        ac: effects.armorClass,
        speedPenalty: effects.speedPenalty,
      );
      _resolvedChars[p.uid] = resolved;
      _resolvedKeys[p.uid] = key;
      return resolved;
    } catch (_) {
      return c;
    }
  }

  void _resolvePlayers() {
    for (final p in _players) {
      final before = _resolvedChars[p.uid];
      _resolvePlayer(p).then((c) {
        if (mounted && !identical(before, c)) setState(() {});
      });
    }
  }

  Creature? _creatureOf(GameToken t) {
    if (t.isPlayer) return null;
    final api = t.apiIndex;
    if (api != null) return _monsterApi.cachedMonster(api);
    return _gameCreatures[t.id]?.snapshot;
  }

  /// Velocidad en pies de la ficha.
  int _speedOf(GameToken t) {
    if (t.isPlayer) {
      final p = _playerOf(t.refId);
      if (p == null) return 30;
      return (_resolvedChars[p.uid] ?? p.character).effectiveSpeed;
    }
    final c = _creatureOf(t);
    return c == null ? 30 : Movement.feetFromText(c.speed);
  }

  /// Casillas a las que puede llegar la ficha seleccionada.
  Set<String> get _reach {
    final t = _selected;
    if (t == null || t.hidden || !_canMove(t)) return const {};

    final occupied = <String>{};
    for (final o in _onMap) {
      if (o.id == t.id) continue;
      for (var dx = 0; dx < o.span; dx++) {
        for (var dy = 0; dy < o.span; dy++) {
          occupied.add(cellKey(o.x + dx, o.y + dy));
        }
      }
    }

    return Movement.reachable(
      cols: _cols,
      rows: _rows,
      terrain: _displayTerrain,
      x: t.x,
      y: t.y,
      span: t.span,
      speedFeet: _speedOf(t),
      occupied: occupied,
    );
  }

  /// Modificador de iniciativa de una ficha.
  Future<int> _initMod(GameToken t) async {
    try {
      if (t.isPlayer) {
        final p = _playerOf(t.refId);
        if (p == null) return 0;
        return (await _resolvePlayer(p)).initiative;
      }
      var c = _creatureOf(t);
      if (c == null && t.apiIndex != null) {
        c = await _monsterApi.fetchMonster(t.apiIndex!);
      }
      return c?.mod('dex') ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<InitEntry> _rollEntry(GameToken t, Random rnd) async {
    final mod = await _initMod(t);
    final roll = rnd.nextInt(20) + 1;
    return InitEntry(
      id: t.id,
      name: _nameOf(t),
      kind: t.kind,
      // ignore: deprecated_member_use
      color: _colorOf(t).value,
      mod: mod,
      roll: roll,
      total: roll + mod,
    );
  }

  /// Master: todas las fichas (jugadores, NPC y monstruos) tiran un d20.
  Future<void> _rollInitiative() async {
    final rnd = Random();
    final entries = <InitEntry>[];
    for (final t in _tokens) {
      entries.add(await _rollEntry(t, rnd));
    }
    await _service.startCombat(_code, CombatState.sorted(entries));
  }

  Future<void> _addToCombat(String tokenId, CombatState st) async {
    final t = _tokens.where((x) => x.id == tokenId).firstOrNull;
    if (t == null) return;

    final e = await _rollEntry(t, Random());
    final list = List<InitEntry>.from(st.entries);
    var at = list.indexWhere((x) => x.total < e.total);
    if (at < 0) at = list.length;
    list.insert(at, e);
    await _service.saveCombatEntries(_code, list);
  }

  List<({String id, String name})> _missingInCombat(CombatState st) {
    final inList = st.entries.map((e) => e.id).toSet();
    return [
      for (final t in _tokens)
        if (!inList.contains(t.id)) (id: t.id, name: _nameOf(t)),
    ];
  }

  /// Abre el panel de la derecha en la pestaña de iniciativa.
  void _openInitiative() {
    setState(() => _panelOpen = true);
    _tabs.animateTo(_tabInitiative);
  }

  Future<void> _endTurn(CombatState st) async {
    final n = st.next();
    try {
      await _service.setTurn(_code, n.id, n.round);
    } catch (e) {
      _snack('No se pudo pasar el turno: $e');
    }
  }

  /// Indicador del turno actual (se superpone al mapa; toca para abrir la
  /// lista de iniciativa en el panel de la derecha).
  Widget _buildTurnBar() {
    final st = _combat;
    if (st == null || !st.active) return const SizedBox.shrink();

    final cur = st.currentEntry;
    final mine = st.current == 'p_$_uid';
    final visible = widget.isMaster || _visibleIds.value.contains(st.current);
    final name = cur == null ? '—' : (visible ? cur.name : 'Algo en las sombras…');

    return Material(
      color: mine ? Colors.green.shade200 : Colors.white.withAlpha(235),
      borderRadius: BorderRadius.circular(10),
      elevation: 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _openInitiative,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flag, size: 18, color: Color(0xFF00A040)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  mine
                      ? '¡Tu turno!'
                      : 'Turno: $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCode() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código de la sala'),
        content: SelectableText(
          _code,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _code));
              Navigator.pop(ctx);
              _snack('Código copiado');
            },
            child: const Text('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

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

    // Tocar una ficha la selecciona (o la deselecciona). Los jugadores
    // solo pueden seleccionar la suya; el Master, cualquiera.
    if (hit != null) {
      if (!_canMove(hit)) return;
      setState(() {
        _selectedId = hit.id == _selectedId ? null : hit.id;
        if (_selectedId != null) _bottomOpen = true;
      });
      return;
    }

    // Tocar una casilla vacía mueve la ficha seleccionada (pide confirmación).
    // Si estaba fuera del mapa, la coloca en esa casilla.
    final sel = _selected;
    if (sel != null && _canMove(sel)) {
      final nx = x > _cols - sel.span ? _cols - sel.span : x;
      final ny = y > _rows - sel.span ? _rows - sel.span : y;
      _confirmAndMove(sel, nx, ny);
    }
  }

  Future<void> _confirmAndMove(GameToken sel, int nx, int ny) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sel.hidden ? 'Colocar ficha' : 'Mover ficha'),
        content: Text(
          sel.hidden
              ? '¿Colocar a ${_nameOf(sel)} en la casilla (${nx + 1}, ${ny + 1})?'
              : '¿Mover a ${_nameOf(sel)} de (${sel.x + 1}, ${sel.y + 1}) '
                  'a (${nx + 1}, ${ny + 1})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    if (sel.hidden) {
      _service
          .placeTokenOnMap(_code, sel.id, x: nx, y: ny)
          .catchError(_onError);
    } else {
      _service.moveToken(_code, sel.id, nx, ny).catchError(_onError);
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
        scrollable: true,
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
    final result = await showDialog<(int, int)>(
      context: context,
      builder: (ctx) => _GridSizeDialog(cols: _cols, rows: _rows),
    );
    if (result == null) return;
    _service.setGridSize(_code, result.$1, result.$2).catchError(_onError);
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
          IconButton(
            tooltip: 'Ver código de la sala',
            icon: const Icon(Icons.vpn_key_outlined),
            onPressed: _showCode,
          ),
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
              tooltip: 'Reiniciar la sala (volver a la sala de espera)',
              icon: const Icon(Icons.restart_alt),
              onPressed: _resetRoom,
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
      // El mapa ocupa todo el espacio; los paneles se superponen
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // En horizontal el móvil puede tener barras de sistema a los lados
          final pad = MediaQuery.of(context).padding;
          final panelW = min(380.0, w * 0.9);
          const anim = Duration(milliseconds: 220);

          final myTurn =
              (_combat?.active ?? false) && _combat!.current == 'p_$_uid';

          return Stack(
            children: [
              Positioned.fill(child: _buildBoard()),

              // Arriba a la izquierda: avisos, turno y última tirada
              Positioned(
                left: 8 + pad.left,
                top: 8,
                width: min(300.0, w - 64 - pad.left - pad.right),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Problema con la partida: $_error\n'
                                  'Si es un error de permisos, publica las '
                                  'reglas de Firestore más recientes.',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => setState(() => _error = null),
                              ),
                            ],
                          ),
                        ),
                      ),
                    _buildTurnBar(),
                    const SizedBox(height: 6),
                    _buildLastRoll(),
                  ],
                ),
              ),

              // Abajo: herramientas y ficha seleccionada (desplegable)
              AnimatedPositioned(
                duration: anim,
                curve: Curves.easeOut,
                left: pad.left,
                bottom: pad.bottom,
                right: _panelOpen ? panelW + pad.right : pad.right,
                child: _buildBottomOverlay(h),
              ),

              // Derecha: panel con pestañas (desplegable)
              AnimatedPositioned(
                duration: anim,
                curve: Curves.easeOut,
                top: 0,
                bottom: 0,
                width: panelW + pad.right,
                right: _panelOpen ? 0 : -(panelW + pad.right),
                child: Material(
                  elevation: 10,
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: pad.right,
                      bottom: pad.bottom,
                    ),
                    child: _buildRightPanel(),
                  ),
                ),
              ),

              // Pestaña para abrir/cerrar el panel de la derecha
              AnimatedPositioned(
                duration: anim,
                curve: Curves.easeOut,
                top: 0,
                bottom: 0,
                right: _panelOpen ? panelW + pad.right : pad.right,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: myTurn && !_panelOpen
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                    elevation: 4,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      onTap: () => setState(() => _panelOpen = !_panelOpen),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 18,
                        ),
                        child: Icon(
                          _panelOpen
                              ? Icons.chevron_right
                              : (myTurn ? Icons.flag : Icons.chevron_left),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoard() {
    return GameBoard(
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
      reachable: _reach,
      turnId: (_combat?.active ?? false) ? _combat!.current : null,
    );
  }

  /// Barra inferior desplegable: herramientas del Master y ficha seleccionada.
  Widget _buildBottomOverlay(double maxHeight) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Theme.of(context).colorScheme.primary,
          elevation: 4,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _bottomOpen = !_bottomOpen),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _bottomOpen
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.isMaster ? 'Herramientas' : 'Mi ficha en el mapa',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_bottomOpen)
          Material(
            elevation: 6,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight * 0.5),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildToolbar(),
                    _buildSelectedBar(),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Última tirada: se oculta sola a los 3 s o al tocarla.
  Widget _buildLastRoll() {
    if (_rolls.isEmpty || _rolls.first.id == _dismissedRollId) {
      return const SizedBox.shrink();
    }

    final r = _rolls.first;
    return GestureDetector(
      onTap: () {
        _rollTimer?.cancel();
        setState(() => _dismissedRollId = r.id);
      },
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(235),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Color(r.color), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 8, backgroundColor: Color(r.color)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${r.name} · ${r.label}: ${r.resultText}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            r.headline,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
                    : '${_nameOf(t)} · (${t.x + 1}, ${t.y + 1}) · '
                        'Mov. ${_speedOf(t)} pies',
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

  /// Criaturas de la partida: lista única con las que están en el mapa y
  /// las que esperan fuera de él, y el botón para añadir nuevas.
  Widget _creaturesPanel() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          GameCreaturesSection(
            gameCode: _code,
            tokens: _tokens,
            selectedId: _selectedId,
            onLocate: (id) => setState(() {
              // Se cierra el panel para poder tocar el mapa
              _selectedId = id;
              _panelOpen = false;
              _bottomOpen = true;
            }),
          ),
        ],
      );

  Widget _initiativePanel() => InitiativePanel(
        gameCode: _code,
        isMaster: widget.isMaster,
        myUid: _uid,
        service: _service,
        visibleIds: _visibleIds,
        onRollAll: _rollInitiative,
        missing: _missingInCombat,
        onAdd: _addToCombat,
      );

  /// Panel de la derecha, con pestañas: dados, iniciativa, jugadores y,
  /// para el Master, criaturas y fichas fuera del mapa.
  Widget _buildRightPanel() {
    final tabs = <Tab>[
      const Tab(text: 'Dados'),
      const Tab(text: 'Iniciativa'),
      Tab(text: widget.isMaster ? 'Jugadores' : 'Mi ficha'),
      if (widget.isMaster) const Tab(text: 'Criaturas'),
    ];

    return Column(
      children: [
        TabBar(controller: _tabs, isScrollable: true, tabs: tabs),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _dicePanel(),
              _initiativePanel(),
              _sheetPanel(),
              if (widget.isMaster) _creaturesPanel(),
            ],
          ),
        ),
      ],
    );
  }
}


/// Diálogo del tamaño del mapa. Es un widget propio para que los campos de
/// texto se liberen con el diálogo (no antes de que termine su animación) y
/// con scroll, para que quepa en horizontal con el teclado abierto.
class _GridSizeDialog extends StatefulWidget {
  final int cols;
  final int rows;

  const _GridSizeDialog({required this.cols, required this.rows});

  @override
  State<_GridSizeDialog> createState() => _GridSizeDialogState();
}

class _GridSizeDialogState extends State<_GridSizeDialog> {
  static const int _min = 5;
  static const int _max = 60;

  late final TextEditingController _colsCtrl =
      TextEditingController(text: '${widget.cols}');
  late final TextEditingController _rowsCtrl =
      TextEditingController(text: '${widget.rows}');

  @override
  void dispose() {
    _colsCtrl.dispose();
    _rowsCtrl.dispose();
    super.dispose();
  }

  void _apply() {
    final c = int.tryParse(_colsCtrl.text.trim()) ?? widget.cols;
    final r = int.tryParse(_rowsCtrl.text.trim()) ?? widget.rows;
    Navigator.pop(
      context,
      (c.clamp(_min, _max).toInt(), r.clamp(_min, _max).toInt()),
    );
  }

  Widget _field(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tamaño del mapa'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('Columnas', _colsCtrl),
            const SizedBox(height: 12),
            _field('Filas', _rowsCtrl),
            const SizedBox(height: 8),
            const Text(
              'Entre $_min y $_max. Las fichas que queden fuera se acercarán '
              'al borde.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(onPressed: _apply, child: const Text('Aplicar')),
      ],
    );
  }
}
