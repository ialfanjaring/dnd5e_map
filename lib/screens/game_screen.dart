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
import '../models/map_template.dart';
import '../services/game_service.dart';
import '../services/map_service.dart';
import '../services/profile_service.dart';
import 'items_screen.dart';
import 'player_room_screen.dart';
import '../services/monster_api_service.dart';
import '../widgets/avatars.dart';
import '../widgets/blocking_progress.dart';
import '../widgets/creature_sheet_view.dart';
import '../widgets/dice_panel.dart';
import '../widgets/game_board.dart';
import '../widgets/game_creatures_section.dart';
import '../widgets/combatant_dialog.dart';
import '../widgets/death_saves_card.dart';
import '../widgets/game_sheet_widgets.dart';
import '../widgets/initiative_panel.dart';
import '../widgets/player_panels.dart';
import '../widgets/chat_panel.dart';
import '../i18n/i18n.dart';
import '../widgets/app_icon.dart';
import '../utils/orientation.dart';
import '../widgets/terrain_painter.dart';
import '../widgets/terrain_picker.dart';
import '../widgets/combat_setup.dart';
import 'reference_screen.dart';
import 'tutorial_screen.dart';

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
    with TickerProviderStateMixin {
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

  // Pisos (hojas del mapa)
  int _viewFloor = 0; // el Master elige qué piso ve
  int _terrainFloor = 0; // piso cuyo terreno estamos recibiendo
  StreamSubscription<Map<String, String>>? _terrainSub;
  List<DiceRoll> _rolls = [];
  String? _dismissedRollId;
  bool _rollsLoaded = false;
  Timer? _rollTimer;
  final ValueNotifier<List<DiceRoll>> _hiddenRolls =
      ValueNotifier<List<DiceRoll>>([]);
  Object? _error;

  // Paneles desplegables que se superponen al mapa
  late final TabController _tabs;
  bool _fullMap = false; // mapa a pantalla completa (sin barra ni paneles)
  bool _panelOpen = false;

  /// Pestañas del panel izquierdo del jugador: Ficha, Acciones, Armas, Hechizos
  late TabController _leftTabs;

  /// Ficha que muestra la pestaña Ficha del jugador: la de la última ficha
  /// tocada en el mapa (null = la suya).
  String? _sheetTarget;
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
  ({int x, int y, int span})? _marker;
  String _brush = 'stone';
  String? _selectedId;
  int _fitSignal = 0;

  // Casillas pintadas pendientes de guardar (null = borrar)
  final Map<String, String?> _paintBuffer = {};
  Timer? _flushTimer;
  bool _assigningColors = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;
  String get _code => widget.gameCode;

  /// Tamaño de la escena que se ve (cada escena puede medir distinto)
  int get _cols => Scenes.sizeOf(_game, _floor).cols;
  int get _rows => Scenes.sizeOf(_game, _floor).rows;

  /// Escenas ocultas a los jugadores
  Set<int> get _hiddenScenes => Scenes.hiddenOf(_game);
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

  // ---- Movimiento dibujado ----
  /// Ficha que se está moviendo y recorrido (casillas, empezando en la ficha)
  String? _pathToken;
  List<({int x, int y})> _path = const [];

  /// Pies ya movidos en el turno actual, por ficha (se reinicia en su turno)
  final Map<String, int> _movedFeet = {};
  String _lastTurnId = '';

  /// Fichas que han usado Correr este turno (doblan su movimiento)
  final Set<String> _dashed = {};

  /// El recorrido actual se eligió tocando una casilla (falta confirmarlo)
  bool _tapPath = false;

  /// Peticiones al Master: las que espera el jugador y las que ve el Master
  final ValueNotifier<Set<String>> _undoPending = ValueNotifier({});

  // ---- Chat ----
  List<ChatMessage> _chat = const [];
  final Set<String> _chatSeen = {};
  bool _chatPrimed = false;

  int get _chatTabIndex => _tabs.length - 1;
  bool get _chatVisible => _panelOpen && _tabs.index == _chatTabIndex;

  /// Mensajes de otros que aún no se han visto
  int get _chatUnread =>
      _chat.where((m) => m.uid != _uid && !_chatSeen.contains(m.id)).length;

  void _markChatSeen() {
    if (!_chatVisible) return;
    final before = _chatSeen.length;
    _chatSeen.addAll(_chat.map((m) => m.id));
    if (_chatSeen.length != before && mounted) setState(() {});
  }
  List<UndoRequest> _requests = const [];

  // ---- Zonas ----
  /// Zonas que el jugador ha ocultado en su pantalla (para ver el mapa más grande)
  final Set<int> _localHiddenZones = {};

  /// Visibilidad de cada zona (del documento de la partida)
  Object? _zoneVisOf(int z) => (_game['zoneVis'] as Map?)?['$z'];

  /// ¿Ve este usuario la zona [z]? El Master las ve todas.
  bool _zoneVisibleToMe(int z) {
    if (widget.isMaster) return true;
    final v = _zoneVisOf(z);
    if (v == null || v == 'all') return true;
    if (v == 'none') return false;
    if (v is List) return v.contains(_uid);
    return true;
  }

  /// Zonas presentes en el piso actual
  List<int> get _zonesHere {
    final out = <int>{};
    for (final v in _displayTerrain.values) {
      final z = Terrains.zoneOf(v);
      if (z != null) out.add(z);
    }
    return out.toList()..sort();
  }

  /// Casillas tapadas por la niebla para este jugador
  Set<String> get _fogged {
    if (widget.isMaster) return const {};
    final out = <String>{};
    _displayTerrain.forEach((k, v) {
      final z = Terrains.zoneOf(v);
      if (z == null) return;
      if (!_zoneVisibleToMe(z) || _localHiddenZones.contains(z)) out.add(k);
    });
    return out;
  }

  /// Si hay zonas ocultas, el mapa se encaja en lo que queda visible.
  ({int x0, int y0, int x1, int y1})? _viewRectFor(Set<String> fog) {
    if (fog.isEmpty) return null;
    int? x0, y0, x1, y1;
    for (var y = 0; y < _rows; y++) {
      for (var x = 0; x < _cols; x++) {
        if (fog.contains(cellKey(x, y))) continue;
        x0 = x0 == null ? x : min(x0, x);
        y0 = y0 == null ? y : min(y0, y);
        x1 = x1 == null ? x : max(x1, x);
        y1 = y1 == null ? y : max(y1, y);
      }
    }
    if (x0 == null) return null;
    return (x0: x0, y0: y0!, x1: x1!, y1: y1!);
  }

  String _zoneVisLabel(int z) {
    final v = _zoneVisOf(z);
    if (v == null || v == 'all') return tr('Visible para todos');
    if (v == 'none') return tr('Oculta para todos');
    if (v is List) {
      final names = [
        for (final p in _players)
          if (v.contains(p.uid)) p.character.name,
      ];
      return names.isEmpty ? tr('Oculta para todos') : '${tr('La ven')}: ${names.join(', ')}';
    }
    return '';
  }

  Future<void> _pickZonePlayers(int z) async {
    final v = _zoneVisOf(z);
    final chosen = <String>{
      if (v is List) ...v.map((e) => e.toString()),
      if (v == null || v == 'all') ..._players.map((p) => p.uid),
    };
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('${tr('Zona')} $z: ${tr('quién la ve')}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in _players)
                CheckboxListTile(
                  value: chosen.contains(p.uid),
                  title: Text(p.character.name),
                  subtitle: p.nickname.isEmpty ? null : Text(p.nickname),
                  onChanged: (on) => setS(() =>
                      on == true ? chosen.add(p.uid) : chosen.remove(p.uid)),
                ),
              if (_players.isEmpty) Tx('Todavía no hay jugadores.'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Tx('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, chosen),
              child: const Tx('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    await _service
        .setZoneVisibility(_code, z, result.toList())
        .catchError(_onError);
  }

  /// Panel de zonas: el Master decide quién las ve; el jugador puede
  /// ocultar las que ve para que el mapa se vea más grande.
  Widget _zonesSection() {
    final zones = _zonesHere;
    if (zones.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Tx('Zonas', style: const TextStyle(fontWeight: FontWeight.bold)),
          for (final z in zones)
            if (widget.isMaster)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 10,
                  backgroundColor: Color(Terrains.zoneColors[(z - 1) % Terrains.zoneColors.length]),
                ),
                title: Text('${tr('Zona')} $z'),
                subtitle: Text(_zoneVisLabel(z), maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: PopupMenuButton<String>(
                  icon: Icon(
                    _zoneVisOf(z) == 'none' ? Icons.visibility_off : Icons.visibility,
                  ),
                  onSelected: (v) {
                    if (v == 'pick') {
                      _pickZonePlayers(z);
                    } else {
                      _service.setZoneVisibility(_code, z, v).catchError(_onError);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'all', child: Tx('Visible para todos')),
                    PopupMenuItem(value: 'none', child: Tx('Oculta para todos')),
                    PopupMenuItem(value: 'pick', child: Tx('Elegir jugadores…')),
                  ],
                ),
              )
            else if (_zoneVisibleToMe(z))
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('${tr('Zona')} $z'),
                subtitle: Tx('Ocúltala para ver el resto del mapa más grande.'),
                value: !_localHiddenZones.contains(z),
                onChanged: (on) => setState(() {
                  on ? _localHiddenZones.remove(z) : _localHiddenZones.add(z);
                  _fitSignal++;
                }),
              ),
        ],
      ),
    );
  }

  // ---- Marcas en casillas ----
  List<CellPing> _pings = const [];

  // ---- Recorridos de los demás (en directo) ----
  List<SharedPath> _otherPaths = const [];
  Timer? _pathTimer;
  bool _pathDirty = false;

  /// Publica el recorrido que se está dibujando (como mucho cada 150 ms).
  void _sharePath() {
    _pathDirty = true;
    if (_pathTimer?.isActive ?? false) return;
    _pathTimer = Timer(const Duration(milliseconds: 150), () {
      if (!_pathDirty || !mounted) return;
      _pathDirty = false;
      if (_path.length < 2) return;
      _service
          .setPath(_code,
              floor: _floor, cells: _path, label: _pathLabel, over: _pathOver)
          .catchError((_) {});
    });
  }

  void _unsharePath() {
    _pathTimer?.cancel();
    _pathDirty = false;
    _service.clearPath(_code).catchError((_) {});
  }

  /// Acciones gastadas en el turno del jugador (se reinicia en su turno).
  final ValueNotifier<Map<String, bool>> _turnUsed = ValueNotifier({});
  bool _wasMyTurn = false;

  late final CombatRoller _roller = CombatRoller(
    gameCode: _code,
    nameProvider: () => _myName,
    colorProvider: () => _myColor,
  );

  void _markUsed(String key) =>
      _turnUsed.value = {..._turnUsed.value, key: true};

  /// Jugador: pide al Master desmarcar una acción gastada (en combate).
  Future<void> _requestUndo(String key, String title) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Desmarcar acción'),
        content: Text(tr('En combate, para recuperar «{a}» el Master tiene que aprobarlo. ¿Se lo pides?')
            .replaceAll('{a}', title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Pedir al Master'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _undoPending.value = {..._undoPending.value, key};
    try {
      await _service.requestUndo(_code,
          key: key, title: title, nick: ProfileService.instance.nickname);
    } catch (e) {
      _undoPending.value = {..._undoPending.value}..remove(key);
      _onError(e);
    }
  }

  /// Jugador: respuesta del Master a sus peticiones.
  void _onMyRequests(List<UndoRequest> list) {
    if (!mounted) return;
    for (final r in list) {
      if (r.status == 'pending') {
        if (!_undoPending.value.contains(r.key)) {
          _undoPending.value = {..._undoPending.value, r.key};
        }
        continue;
      }
      _undoPending.value = {..._undoPending.value}..remove(r.key);
      if (r.status == 'ok') {
        _turnUsed.value = {..._turnUsed.value, r.key: false};
        // Recuperar el movimiento devuelve todos los pies del turno
        if (r.key == 'move') {
          _movedFeet.remove('p_$_uid');
          _dashed.remove('p_$_uid');
          setState(() {});
        }
        _snack(tr('El Master ha aprobado recuperar «{a}».').replaceAll('{a}', r.title));
      } else {
        _snack(tr('El Master ha rechazado recuperar «{a}».').replaceAll('{a}', r.title));
      }
      _service.deleteRequest(_code, r.id).catchError((_) {});
    }
  }

  /// Master: avisos con las peticiones de los jugadores.
  Widget _requestsBanner() {
    if (!widget.isMaster || _requests.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onTertiaryContainer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in _requests)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: scheme.tertiaryContainer,
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                child: Row(
                  children: [
                    Icon(Icons.undo, size: 18, color: fg),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: r.nick.isEmpty ? tr('Un jugador') : r.nick,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: ' ${tr('quiere recuperar')} «${r.title}»',
                          ),
                        ]),
                        style: TextStyle(fontSize: 12, color: fg),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      tooltip: tr('Rechazar'),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _service
                          .answerRequest(_code, r.id, false)
                          .catchError(_onError),
                    ),
                    IconButton.filled(
                      tooltip: tr('Aceptar'),
                      visualDensity: VisualDensity.compact,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check, size: 18),
                      onPressed: () => _service
                          .answerRequest(_code, r.id, true)
                          .catchError(_onError),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Texto del contador de movimiento de una ficha en combate.
  String _moveInfoFor(GameToken t) {
    final speed = _speedOf(t);
    final left = _feetLeft(t);
    final budget = _dashed.contains(t.id) ? speed * 2 : speed;
    final base = tr('Te quedan {a} de {b} pies')
        .replaceAll('{a}', '$left')
        .replaceAll('{b}', '$budget');
    return _dashed.contains(t.id) ? '$base · ${tr('corriendo')}' : base;
  }

  /// Contador de movimiento sobre el mapa (en combate).
  Widget _moveCounter() {
    if (!_limitMove) return const SizedBox.shrink();
    final cur = _combat?.currentTokenIds ?? const <String>{};
    GameToken? t;
    if (widget.isMaster) {
      final sel = _selected;
      if (sel != null && cur.contains(sel.id)) t = sel;
    } else {
      t = _tokens.where((e) => e.id == 'p_$_uid').firstOrNull;
      if (t != null && !cur.contains(t.id)) t = null;
    }
    if (t == null) return const SizedBox.shrink();
    final left = _feetLeft(t);
    final color = left > 0 ? Colors.green : Colors.orange;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_dashed.contains(t.id) ? Icons.directions_run : Icons.directions_walk,
                  size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${_moveInfoFor(t)} · ${left ~/ 5} ${tr('casillas')}',
                  style: const TextStyle(color: Colors.white, fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Barra para confirmar un movimiento elegido tocando una casilla.
  Widget _tapMoveBar() {
    if (!_tapPath || _path.length < 2) return const SizedBox.shrink();
    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route, color: _pathOver ? Colors.orange : null),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$_pathLabel\n${tr('Toca casillas para seguir el recorrido; la anterior lo deshace.')}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            TextButton(
              onPressed: _cancelTapPath,
              child: const Tx('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: _onPathEnd,
              icon: const Icon(Icons.check, size: 18),
              label: const Tx('Mover'),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelTapPath() {
    _unsharePath();
    setState(() {
      _tapPath = false;
      _path = const [];
      _pathToken = null;
    });
  }

  /// Toque en una casilla con la ficha propia seleccionada: el jugador traza
  /// el recorrido a toques (cada toque añade un tramo recto hasta la casilla;
  /// tocar la anterior deshace y tocar otra vez el final lo confirma).
  void _tapTrace(GameToken t, int x, int y) {
    if (_pathToken != t.id || _path.isEmpty) {
      setState(() {
        _pathToken = t.id;
        _path = [(x: t.x, y: t.y)];
        _tapPath = true;
      });
    }
    final last = _path.last;
    if (_path.length > 1 && last.x == x && last.y == y) {
      _onPathEnd();
      return;
    }
    _onPathExtend(x, y);
    if (_path.length < 2) _snack(tr('No se puede trazar hacia esa casilla.'));
  }

  String get _myName => widget.isMaster
      ? tr('Master')
      : (_playerOf(_uid)?.character.name ?? tr('Jugador'));

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
    // La partida se juega en horizontal
    AppOrientation.landscape();
    // Master: Dados, Iniciativa, Jugadores, Criaturas
    // Jugador: Dados, Iniciativa, Mi ficha
    // + Chat al final
    // Derecha (general): Dados, Iniciativa, Libro y Chat. Las opciones del
    // Master (mapa, jugadores, criaturas, objetos) van a la izquierda.
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(_markChatSeen);
    _leftTabs = TabController(length: 4, vsync: this);
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
    _pathTimer?.cancel();
    if (_path.length > 1) _service.clearPath(_code).catchError((_) {});
    // Al salir de la partida, la app vuelve a vertical
    AppOrientation.portrait();
    _heartbeat?.cancel();
    _rollTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _terrainSub?.cancel();
    _flushTimer?.cancel();
    if (_paintBuffer.isNotEmpty) {
      _service.paintCells(
          _code, Map<String, String?>.from(_paintBuffer), _terrainFloor);
    }
    _tabs.dispose();
    _leftTabs.dispose();
    _hiddenRolls.dispose();
    _visibleIds.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------
  // ESCENAS (antes «pisos»)
  // ---------------------------------------------------------------

  List<String> get _floorNames {
    final raw = _game['floorNames'];
    if (raw is List && raw.isNotEmpty) {
      return raw.map((e) => e.toString()).toList();
    }
    return ['Escena 1'];
  }

  int get _floorCount => _floorNames.length;

  String _floorName(int i) =>
      Scenes.label(_floorNames[i.clamp(0, _floorCount - 1).toInt()]);

  /// Piso que se está viendo: el Master elige; el jugador ve el de su ficha.
  int get _floor {
    final n = _floorCount;
    if (widget.isMaster) return _viewFloor.clamp(0, n - 1).toInt();
    final mine = _tokens.where((t) => t.id == 'p_$_uid').firstOrNull;
    return (mine?.floor ?? 0).clamp(0, n - 1).toInt();
  }

  void _subscribeTerrain() {
    _terrainSub?.cancel();
    _terrainFloor = _floor;
    _terrainSub = _service.terrain(_code, _terrainFloor).listen((t) {
      if (!mounted) return;
      setState(() => _terrain = t);
    }, onError: _onError);
  }

  /// Si cambió el piso que se ve, se carga su terreno.
  void _syncFloor() {
    if (_floor != _terrainFloor) {
      _flushPaint();
      _paintBuffer.clear();
      _terrain = {};
      _subscribeTerrain();
    }
  }

  void _setViewFloor(int i) {
    setState(() {
      _viewFloor = i;
      _selectedId = null;
    });
    _syncFloor();
  }

  /// Fichas en el mapa del piso que se ve.
  List<GameToken> get _onFloor =>
      _tokens.where((t) => !t.hidden && t.floor == _floor).toList();

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
      _syncFloor();
      _assignColorsIfNeeded();
    }, onError: _onError));

    _subs.add(_service.players(_code).listen((p) {
      if (!mounted) return;
      setState(() => _players = p);
      _assignColorsIfNeeded();
      _resolvePlayers();
    }, onError: _onError));

    _subs.add(_service.paths(_code).listen((list) {
      if (mounted) setState(() => _otherPaths = list);
    }, onError: (_) {}));

    _subs.add(_service.pings(_code).listen((list) {
      if (mounted) setState(() => _pings = list);
    }, onError: (_) {}));

    _subs.add(_service.chat(_code, isMaster: widget.isMaster).listen((list) {
      if (!mounted) return;
      // Al entrar, los mensajes antiguos cuentan como leídos
      if (!_chatPrimed) {
        _chatPrimed = true;
        _chatSeen.addAll(list.map((m) => m.id));
      }
      final fresh = list.where((m) =>
          m.uid != _uid && !_chatSeen.contains(m.id)).toList();
      setState(() => _chat = list);
      _markChatSeen();
      if (fresh.isNotEmpty && !_chatVisible) {
        final m = fresh.last;
        _snack('💬 ${m.nick.isEmpty ? '?' : m.nick}: ${m.text.length > 60 ? '${m.text.substring(0, 60)}…' : m.text}');
      }
    }, onError: (_) {}));

    if (widget.isMaster) {
      _subs.add(_service.pendingRequests(_code).listen((list) {
        if (mounted) setState(() => _requests = list);
      }, onError: (_) {}));
    } else {
      _subs.add(_service.myRequests(_code).listen(_onMyRequests,
          onError: (_) {}));
    }

    _subs.add(_service.combat(_code).listen((c) {
      if (!mounted) return;
      setState(() => _combat = c);
      // Al empezar el turno de alguien se reinicia su movimiento
      final turnId = (c?.inTurns ?? false) ? '${c!.round}|${c.current}' : '';
      final turnChanged = turnId != _lastTurnId;
      if (turnChanged) {
        _lastTurnId = turnId;
        for (final id in c?.currentTokenIds ?? const <String>{}) {
          _movedFeet.remove(id);
          _dashed.remove(id);
        }
        if (turnId.isEmpty) {
          _movedFeet.clear();
          _dashed.clear();
        }
      }
      // Empieza tu turno (cada vez que cambia el turno y te toca, también
      // si eres el único en el combate o vas en un grupo): se reinician las
      // acciones, incluida la reacción.
      final mine = (c?.currentTokenIds ?? const <String>{}).contains('p_$_uid');
      if (mine && (turnChanged || !_wasMyTurn)) {
        _turnUsed.value = {};
        _undoPending.value = {};
      }
      _wasMyTurn = mine;
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
      _syncFloor();
    }, onError: _onError));

    _subscribeTerrain();

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
        title: const Tx('Sesión terminada'),
        content: const Tx('El Master ha terminado la sesión.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Aceptar'),
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
        title: const Tx('Reiniciar la sala'),
        content: const Tx(
          'Todos volverán a la sala de espera. Se quitarán las fichas del '
          'mapa, el combate y el registro de dados. Se conservan los '
          'jugadores, las criaturas y el mapa. Podrás cambiar de mapa e '
          'iniciar de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Reiniciar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    try {
      await runBlocking(
        context,
        tr('Reiniciando la sala…'),
        () => _service.resetRoom(_code),
      );
      // La propia suscripción al estado nos devuelve a la sala
    } catch (e) {
      _snack('${tr('No se pudo reiniciar la sala')}: $e');
    }
  }

  /// Solo el Master: termina la sesión y borra la partida.
  Future<void> _endSession() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Terminar la sesión'),
        content: const Tx(
          'Se avisará a los jugadores y la partida se borrará por completo '
          '(mapa, fichas y criaturas). Tus personajes, bestiario y mapas '
          'guardados no se tocan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Terminar sesión'),
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
        tr('Terminando la sesión…'),
        () => _service.endGame(_code),
      );
      navigator.popUntil((r) => r.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Tx('Sesión terminada y partida borrada.')),
      );
    } catch (e) {
      _ended = false;
      _snack('${tr('No se pudo terminar la sesión')}: $e');
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

  String _tokenName(String id) {
    for (final t in _tokens) {
      if (t.id == id) return _nameOf(t);
    }
    return id;
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
      final p = _playerOf(t.refId);
      final chosen = p == null ? null : Avatars.avatarIcon(p.avatar);
      if (chosen != null) return chosen;
      return Avatars.classIcon(p?.character.characterClass ?? '');
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
    // NPC: verde azulado; monstruos: siempre rojo
    return _isNpc(t) ? Avatars.npcColor : Avatars.monsterColor;
  }

  /// 0 normal, 1 inconsciente (0 PG), 2 muerto (solo personajes)
  int _vitalOf(GameToken t) {
    if (!t.isPlayer) return 0;
    final p = _playerOf(t.refId);
    if (p == null) return 0;
    if (p.dead) return 2;
    return p.currentHp <= 0 ? 1 : 0;
  }

  /// En combate, si es el turno de un personaje a 0 PG: tarjeta con la
  /// salvación de muerte (la ve el Master y el propio jugador).
  Widget _deathPrompt() {
    final st = _combat;
    if (st == null || !st.inTurns) return const SizedBox.shrink();
    final cur = st.current;
    if (cur == null || !cur.startsWith('p_')) return const SizedBox.shrink();
    final p = _playerOf(cur.substring(2));
    if (p == null || !DeathSavesCard.needsSaves(p)) {
      return const SizedBox.shrink();
    }
    final mine = p.uid == _uid;
    if (!widget.isMaster && !mine) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: DeathSavesCard(
        gameCode: _code,
        player: p,
        canEdit: true,
        myTurn: true,
        compact: true,
        // Tirar la salvación termina el turno, salvo con un 20: se levanta
        // con 1 PG y aún puede actuar en este turno.
        onRolled: (roll) {
          final now = _combat;
          if (roll == 20 || now == null || !now.inTurns) return;
          if (now.current != cur) return;
          _endTurn(now);
        },
      ),
    );
  }

  /// Segundo color de la ficha (dibujo y borde)
  Color? _color2Of(GameToken t) {
    if (t.isPlayer) {
      final c = _playerOf(t.refId)?.color2;
      return c == null ? null : Color(c);
    }
    return _isNpc(t) ? Colors.white : Avatars.monsterColor2;
  }

  bool _isNpc(GameToken t) {
    if (t.icon == 'npc') return true;
    final api = t.apiIndex;
    final c = api == null ? null : _monsterApi.cachedMonster(api);
    return c != null && !c.isMonster;
  }

  String _groupKey(GameToken t) =>
      t.apiIndex ??
      t.label.replaceAll(RegExp(r'\s*\d+$'), '').trim().toLowerCase();

  static const List<int> _ringPalette = [
    0xFFFFEB3B, 0xFF00E5FF, 0xFF76FF03, 0xFFE040FB, 0xFFFF9100,
    0xFF2979FF, 0xFFFFFFFF, 0xFFFF80AB, 0xFF1DE9B6, 0xFFB388FF,
  ];

  /// Borde de color de cada criatura que tiene hermanas iguales
  /// (id de ficha -> color). Coincide con el borde de su tarjeta.
  Map<String, Color> get _rings {
    final groups = <String, List<GameToken>>{};
    for (final t in _tokens) {
      if (t.isPlayer) continue;
      groups.putIfAbsent(_groupKey(t), () => []).add(t);
    }
    final out = <String, Color>{};
    for (final g in groups.values) {
      if (g.length < 2) continue;
      g.sort((a, b) {
        final c = a.number.compareTo(b.number);
        return c != 0 ? c : a.id.compareTo(b.id);
      });
      for (var i = 0; i < g.length; i++) {
        out[g[i].id] = Color(_ringPalette[i % _ringPalette.length]);
      }
    }
    return out;
  }

  /// Nombre sin número (lo que ven los jugadores)
  String _plainNameOf(GameToken t) =>
      _nameOf(t).replaceAll(RegExp(r'\s*\d+$'), '').trim();

  bool get _playersSelectCreatures =>
      (_game['playersSelectCreatures'] ?? false) == true;

  bool _canSelect(GameToken t) =>
      _canMove(t) ||
      (!widget.isMaster && !t.isPlayer && !t.hidden && _playersSelectCreatures);

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
      c.acBonus,
      c.initiativeBonus,
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
    if (t == null || t.hidden || !_canMove(t) || t.floor != _floor) {
      return const {};
    }

    final occupied = <String>{};
    for (final o in _onFloor) {
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
      speedFeet: _reachFeet(t),
      occupied: occupied,
    );
  }

  /// Pies para pintar el alcance: en combate, lo que queda del turno (si ya
  /// no queda nada y aún no ha corrido, lo que tendría corriendo).
  int _reachFeet(GameToken t) {
    if (!_limitMove) return _speedOf(t);
    final left = _feetLeft(t);
    if (left > 0) return left;
    return _dashed.contains(t.id) ? 0 : _speedOf(t);
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

  /// Master: elige qué fichas entran en el combate y cuáles van en grupo;
  /// después cada jugador tira su iniciativa.
  Future<void> _prepareCombat() async {
    final candidates = [
      for (final t in _tokens)
        CombatCandidate(
          id: t.id,
          name: _nameOf(t),
          isPlayer: t.isPlayer,
          hidden: t.hidden,
          baseKey: t.apiIndex ??
              _nameOf(t).replaceAll(RegExp(r'\s*\d+$'), '').toLowerCase(),
        ),
    ];
    if (candidates.isEmpty) {
      _snack(tr('Todavía no hay fichas en la partida.'));
      return;
    }

    final picks = await showCombatSetup(context, candidates);
    if (picks == null || !mounted) return;

    final entries = <InitEntry>[];
    final groups = <String, List<GameToken>>{};
    for (final pk in picks) {
      final t = _tokens.where((x) => x.id == pk.id).firstOrNull;
      if (t == null) continue;
      if (pk.group != null) {
        groups.putIfAbsent(pk.group!, () => []).add(t);
        continue;
      }
      entries.add(InitEntry(
        id: t.id,
        name: _nameOf(t),
        kind: t.kind,
        // ignore: deprecated_member_use
        color: _colorOf(t).value,
        mod: 0,
        roll: 0,
        total: 0,
        rolled: false,
      ));
    }

    groups.forEach((letter, list) {
      if (list.length == 1) {
        final t = list.first;
        entries.add(InitEntry(
          id: t.id,
          name: _nameOf(t),
          kind: t.kind,
          // ignore: deprecated_member_use
          color: _colorOf(t).value,
          mod: 0,
          roll: 0,
          total: 0,
          rolled: false,
        ));
        return;
      }
      final bases = {
        for (final t in list)
          _nameOf(t).replaceAll(RegExp(r'\s*\d+$'), '').trim(),
      };
      final name = bases.length == 1
          ? '${bases.first} ×${list.length}'
          : '${tr('Grupo')} $letter (${list.length})';
      entries.add(InitEntry(
        id: 'g_$letter',
        name: name,
        kind: 'creature',
        // ignore: deprecated_member_use
        color: _colorOf(list.first).value,
        mod: 0,
        roll: 0,
        total: 0,
        rolled: false,
        members: [for (final t in list) t.id],
      ));
    });

    // Jugadores primero, luego criaturas
    entries.sort((a, b) =>
        (a.isPlayer ? 0 : 1).compareTo(b.isPlayer ? 0 : 1));

    try {
      await _service.startInitiativePhase(_code, entries);
      _openInitiative();
    } catch (e) {
      _snack('${tr('No se pudo preparar el combate')}: $e');
    }
  }

  /// Modificador de una entrada (en un grupo, el mejor de sus miembros).
  Future<int> _entryMod(InitEntry e) async {
    final ids = e.isGroup ? e.members : [e.id];
    var best = -100;
    for (final id in ids) {
      final t = _tokens.where((x) => x.id == id).firstOrNull;
      if (t == null) continue;
      final m = await _initMod(t);
      if (m > best) best = m;
    }
    return best == -100 ? 0 : best;
  }

  /// Un jugador tira su propia iniciativa.
  Future<void> _rollMyInitiative() async {
    final t = _tokens.where((x) => x.id == 'p_$_uid').firstOrNull;
    if (t == null) return;
    final mod = await _initMod(t);
    await _service.postInitiativeRoll(
      _code,
      t.id,
      roll: Random().nextInt(20) + 1,
      mod: mod,
    );
  }

  /// El Master tira por una entrada.
  Future<void> _rollEntryFor(InitEntry e) async {
    await _service.postInitiativeRoll(
      _code,
      e.id,
      roll: Random().nextInt(20) + 1,
      mod: await _entryMod(e),
    );
  }

  /// El Master tira por las entradas que faltan.
  Future<void> _rollPending({required bool onlyCreatures}) async {
    final st = _combat;
    if (st == null) return;
    for (final e in st.pending) {
      if (onlyCreatures && e.isPlayer) continue;
      await _rollEntryFor(e);
    }
  }

  /// El Master cierra las tiradas: se ordena y empiezan los turnos.
  Future<void> _startTurns(CombatState st) async {
    // Se vuelve a leer el estado: puede haber tiradas nuevas
    final fresh = await _service.combat(_code).first ?? st;
    await _service.startTurns(_code, CombatState.sorted(fresh.entries));
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
    return [
      for (final t in _tokens)
        if (!st.entries.any((e) => e.covers(t.id)))
          (id: t.id, name: _nameOf(t)),
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
      _snack('${tr('No se pudo pasar el turno')}: $e');
    }
  }

  /// Franja con el turno actual: va solo en la parte superior del panel de
  /// la derecha (no se superpone al mapa).
  Widget _turnBanner() {
    final st = _combat;
    if (st == null || !st.active) return const SizedBox.shrink();

    final Color bg;
    final String text;
    if (st.rolling) {
      final iRoll = st.entries.any((e) => e.id == 'p_$_uid' && !e.rolled);
      bg = iRoll ? Colors.amber.shade300 : Colors.blueGrey.shade100;
      text = iRoll ? tr('¡Tira tu iniciativa!') : tr('Tiradas de iniciativa');
    } else {
      final cur = st.currentEntry;
      final mine = st.current == 'p_$_uid';
      final visible = widget.isMaster ||
          (cur != null &&
              (_visibleIds.value.contains(cur.id) ||
                  cur.members.any(_visibleIds.value.contains)));
      bg = mine ? Colors.amber.shade300 : Colors.blueGrey.shade100;
      text = mine
          ? tr('¡Tu turno!')
          : '${tr('Turno')}: ${cur == null ? '—' : (visible ? cur.name : tr('Algo en las sombras…'))}';
    }

    return Material(
      color: bg,
      textStyle: const TextStyle(color: Colors.black87),
      child: InkWell(
        onTap: () => _tabs.animateTo(_tabInitiative),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.flag, size: 18, color: Color(0xFF00A040)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (!st.rolling)
                Text(
                  '${tr('Ronda')} ${st.round}',
                  style: const TextStyle(fontSize: 12),
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
        title: Text((_game['name'] ?? tr('Partida')).toString()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tx('Código de la sala',
                style: TextStyle(color: Colors.grey.shade500)),
            const SizedBox(height: 6),
            SelectableText(
              _code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _code));
              Navigator.pop(ctx);
              _snack(tr('Código copiado'));
            },
            child: const Tx('Copiar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _askYesNo(String title, String text, String yes) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Tx('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(yes),
            ),
          ],
        ),
      );

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
    for (final t in _onFloor) {
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
    // Con un recorrido pendiente, tocar una ficha lo cancela
    if (hit != null && _tapPath) _cancelTapPath();

    if (hit != null) {
      // Jugador: tocar cualquier ficha la muestra en la pestaña Ficha
      if (!widget.isMaster) {
        setState(() => _sheetTarget = hit.id == 'p_$_uid' ? null : hit.id);
        // Tocar otra ficha abre el panel izquierdo en la pestaña Ficha
        if (hit.id != 'p_$_uid') {
          setState(() => _bottomOpen = true);
          _leftTabs.animateTo(0);
        }
      }
      if (!_canSelect(hit)) return;
      setState(() {
        _selectedId = hit.id == _selectedId ? null : hit.id;
        // El panel de herramientas se abre a mano (no tapa el mapa al elegir)
      });
      return;
    }

    // Tocar una casilla vacía: el Master teletransporta la ficha seleccionada
    // (pide confirmación). Los jugadores mueven dibujando el recorrido.
    final sel = _selected;
    if (sel != null && _canMove(sel) && !widget.isMaster && !sel.hidden) {
      _tapTrace(sel, x, y);
      return;
    }
    if (sel != null && _canMove(sel)) {
      final nx = x > _cols - sel.span ? _cols - sel.span : x;
      final ny = y > _rows - sel.span ? _rows - sel.span : y;

      // No se puede colocar una ficha en casillas bloqueadas (muros...)
      final map = _displayTerrain;
      for (var i = 0; i < sel.span; i++) {
        for (var j = 0; j < sel.span; j++) {
          if (Terrains.parse(map[cellKey(nx + i, ny + j)]).rule ==
              MoveRule.blocked) {
            ScaffoldMessenger.of(context)
              ..clearSnackBars()
              ..showSnackBar(SnackBar(
                content: Text(tr('Esa casilla está bloqueada: no se pueden colocar fichas.')),
                duration: const Duration(seconds: 2),
              ));
            return;
          }
        }
      }
      _confirmAndMove(sel, nx, ny);
    }
  }

  /// Casillas conectadas con el grupo [group] (escaleras o portales con el
  /// mismo número), en todos los pisos, salvo la casilla de origen.
  Future<List<({int floor, int x, int y})>> _linkTargets(
      int group, int fromFloor, int fx, int fy) async {
    final out = <({int floor, int x, int y})>[];
    for (var f = 0; f < _floorCount; f++) {
      // Los jugadores no pueden ir a escenas ocultas
      if (!widget.isMaster && f != fromFloor && _hiddenScenes.contains(f)) continue;
      final cells = f == _floor
          ? _displayTerrain
          : await _service.terrainOnce(_code, f).catchError((_) => <String, String>{});
      cells.forEach((k, v) {
        if (Terrains.groupOf(v) != group || !Terrains.isLink(v)) return;
        final p = k.split('_');
        final x = int.tryParse(p[0]);
        final y = int.tryParse(p.length > 1 ? p[1] : '');
        if (x == null || y == null) return;
        if (f == fromFloor && x == fx && y == fy) return;
        out.add((floor: f, x: x, y: y));
      });
    }
    out.sort((a, b) => a.floor != b.floor
        ? a.floor.compareTo(b.floor)
        : (a.y != b.y ? a.y.compareTo(b.y) : a.x.compareTo(b.x)));
    return out;
  }

  /// Escalera o portal con número: elegir a cuál de las conectadas ir.
  Future<bool> _useNumberedLink(GameToken sel, int nx, int ny, int group) async {
    final targets = await _linkTargets(group, _floor, nx, ny);
    if (!mounted) return false;
    final picked = await showDialog<({int floor, int x, int y})?>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('${tr('Conexión')} #$group'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, (floor: _floor, x: nx, y: ny)),
            child: Row(children: [
              const Icon(Icons.place_outlined, size: 18),
              const SizedBox(width: 8),
              Tx('Quedarse aquí'),
            ]),
          ),
          for (final t in targets)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t),
              child: Row(children: [
                Icon(
                  t.floor == _floor
                      ? Icons.blur_circular
                      : (t.floor > _floor ? Icons.arrow_upward : Icons.arrow_downward),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${_floorName(t.floor)} · (${t.x + 1}, ${t.y + 1})'),
                ),
              ]),
            ),
          if (targets.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Tx('No hay otras casillas con este número.'),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return false;
    setState(() => _selectedId = null);
    if (picked.floor == sel.floor) {
      await _service.moveToken(_code, sel.id, picked.x, picked.y).catchError(_onError);
    } else {
      await _service
          .moveTokenToFloor(_code, sel.id, picked.x, picked.y, picked.floor)
          .catchError(_onError);
    }
    return true;
  }

  Future<void> _confirmAndMove(GameToken sel, int nx, int ny) async {
    final here = _floor;
    final cellValue = _displayTerrain[cellKey(nx, ny)];
    final group = Terrains.groupOf(cellValue);
    if (!sel.hidden && group != null && Terrains.isLink(cellValue)) {
      await _useNumberedLink(sel, nx, ny, group);
      return;
    }
    final dests = <int>[
      if (!sel.hidden && _floorCount > 1)
        for (var i = 0; i < _floorCount; i++)
          if (Terrains.canChangeFloor(cellValue, here, i)) i,
    ];
    final onLink = dests.isNotEmpty;

    final text = sel.hidden
        ? tr('¿Colocar a {n} en la casilla ({x}, {y})?')
            .replaceAll('{n}', _nameOf(sel))
            .replaceAll('{x}', '${nx + 1}')
            .replaceAll('{y}', '${ny + 1}')
        : tr('¿Mover a {n} de ({a}, {b}) a ({x}, {y})?')
            .replaceAll('{n}', _nameOf(sel))
            .replaceAll('{a}', '${sel.x + 1}')
            .replaceAll('{b}', '${sel.y + 1}')
            .replaceAll('{x}', '${nx + 1}')
            .replaceAll('{y}', '${ny + 1}');

    // Punto en la casilla elegida mientras se confirma
    setState(() => _marker = (x: nx, y: ny, span: sel.span));

    // Resultado: piso de destino (el actual = solo mover); null = cancelar
    final target = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(sel.hidden ? tr('Colocar ficha') : tr('Mover ficha')),
        content: Text(
          onLink
              ? '$text\n\n${tr('Hay una escalera: puedes cambiar de escena.')}'
              : text,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Cancelar'),
          ),
          if (onLink)
            for (final i in dests)
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(ctx, i),
                icon: Icon(i > here ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18),
                label: Text('${tr('Ir a')} ${_floorName(i)}'),
              ),
          ElevatedButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, here),
            child: Text(tr(onLink ? 'Solo mover' : 'Confirmar')),
          ),
        ],
      ),
    );
    if (mounted) setState(() => _marker = null);
    if (target == null || !mounted) return;
    // Tras mover, la ficha se deselecciona (se acaba el resaltado del alcance)
    setState(() => _selectedId = null);

    if (sel.hidden) {
      _service
          .placeTokenOnMap(_code, sel.id, x: nx, y: ny, floor: here)
          .catchError(_onError);
    } else if (target != sel.floor) {
      _service
          .moveTokenToFloor(_code, sel.id, nx, ny, target)
          .catchError(_onError);
    } else {
      _service.moveToken(_code, sel.id, nx, ny).catchError(_onError);
    }
  }

  // ---------------------------------------------------------------
  // MOVIMIENTO DIBUJADO
  // ---------------------------------------------------------------

  /// Coste en casillas de entrar en (x, y) con la ficha; -1 si no se puede.
  int _stepCost(GameToken t, int x, int y) {
    if (x < 0 || y < 0 || x + t.span > _cols || y + t.span > _rows) return -1;
    var worst = 1;
    for (var dx = 0; dx < t.span; dx++) {
      for (var dy = 0; dy < t.span; dy++) {
        final rule = Terrains.parse(_displayTerrain[cellKey(x + dx, y + dy)]).rule;
        if (rule == MoveRule.blocked) return -1;
        if (rule == MoveRule.difficult) worst = 2;
      }
    }
    return worst;
  }

  /// Pies que cuesta el recorrido dibujado.
  int get _pathFeet {
    final t = _tokens.where((e) => e.id == _pathToken).firstOrNull;
    if (t == null) return 0;
    var cost = 0;
    for (final c in _path.skip(1)) {
      final s = _stepCost(t, c.x, c.y);
      cost += s < 0 ? 1 : s;
    }
    return cost * 5;
  }

  /// En combate el movimiento está limitado a la velocidad del turno.
  bool get _limitMove => _combat?.inTurns ?? false;

  int _feetLeft(GameToken t) {
    final speed = _speedOf(t);
    final budget = _dashed.contains(t.id) ? speed * 2 : speed;
    return max(0, budget - (_movedFeet[t.id] ?? 0));
  }

  String get _pathLabel {
    final t = _tokens.where((e) => e.id == _pathToken).firstOrNull;
    if (t == null || _path.length < 2) return '';
    return _limitMove
        ? '$_pathFeet / ${_feetLeft(t)} ${tr('pies')}'
        : '$_pathFeet ${tr('pies')}';
  }

  bool get _pathOver {
    final t = _tokens.where((e) => e.id == _pathToken).firstOrNull;
    return t != null && _limitMove && _pathFeet > _feetLeft(t);
  }

  void _onPathStart(int x, int y) {
    final hit = _tokenAt(x, y);
    if (hit == null || !_canMove(hit) || hit.hidden) return;
    setState(() {
      _tapPath = false;
      _selectedId = hit.id;
      _pathToken = hit.id;
      _path = [(x: hit.x, y: hit.y)];
    });
  }

  void _onPathExtend(int x, int y) {
    final t = _tokens.where((e) => e.id == _pathToken).firstOrNull;
    if (t == null || _path.isEmpty) return;
    // La casilla del dedo es la esquina superior izquierda de la ficha
    final last = _path.last;
    // Volver atrás borra el último paso
    if (_path.length > 1 &&
        _path[_path.length - 2].x == x &&
        _path[_path.length - 2].y == y) {
      setState(() => _path = _path.sublist(0, _path.length - 1));
      _sharePath();
      return;
    }
    // Solo casillas contiguas (también en diagonal); si el dedo salta varias,
    // se rellena el camino en línea recta
    var cx = last.x;
    var cy = last.y;
    final next = [..._path];
    var guard = 0;
    while ((cx != x || cy != y) && guard++ < 60) {
      final nx = cx + (x - cx).sign;
      final ny = cy + (y - cy).sign;
      if (_stepCost(t, nx, ny) < 0) break; // muro: el recorrido se detiene
      cx = nx;
      cy = ny;
      next.add((x: cx, y: cy));
    }
    if (next.length != _path.length) {
      setState(() => _path = next);
      _sharePath();
    }
  }

  Future<void> _onPathEnd() async {
    final t = _tokens.where((e) => e.id == _pathToken).firstOrNull;
    final path = _path;
    void clear() {
      _unsharePath();
      if (mounted) {
        setState(() {
          _path = const [];
          _pathToken = null;
          _tapPath = false;
        });
      }
    }

    if (t == null || path.length < 2) {
      clear();
      return;
    }
    final end = path.last;

    // No se puede terminar encima de otra ficha
    for (final o in _onFloor) {
      if (o.id == t.id) continue;
      final overlap = end.x < o.x + o.span &&
          o.x < end.x + t.span &&
          end.y < o.y + o.span &&
          o.y < end.y + t.span;
      if (overlap) {
        _snack(tr('No puedes terminar el movimiento encima de otra ficha.'));
        clear();
        return;
      }
    }

    final feet = _pathFeet;
    var dash = false;
    if (_limitMove) {
      final left = _feetLeft(t);
      final speed = _speedOf(t);
      final cur = _combat?.currentTokenIds ?? const <String>{};
      final notMyTurn = !widget.isMaster && !cur.contains(t.id);
      final canDash = !_dashed.contains(t.id) && feet <= left + speed;

      if (notMyTurn) {
        final go = await _askYesNo(
          tr('No es tu turno'),
          tr('¿Mover igualmente fuera de tu turno?'),
          tr('Mover igualmente'),
        );
        if (go != true) {
          clear();
          return;
        }
      } else if (feet > left && canDash) {
        // Correr: da otra vez la velocidad. La acción que gasta (principal o
        // adicional, según los rasgos) la marca el jugador en Acciones.
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(children: [
              const Icon(Icons.directions_run),
              const SizedBox(width: 8),
              Expanded(child: Tx('Vas a correr')),
            ]),
            content: Text(
              '${tr('El recorrido cuesta {a} pies y te quedan {b}.').replaceAll('{a}', '$feet').replaceAll('{b}', '$left')}\n\n'
              '${tr('Para moverte más tienes que Correr y ganas {s} pies más este turno. Correr gasta tu acción principal, o la adicional si un rasgo te lo permite: márcala tú en Acciones.').replaceAll('{s}', '$speed')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Tx('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Tx('Correr'),
              ),
            ],
          ),
        );
        if (go != true) {
          clear();
          return;
        }
        dash = true;
      } else if (feet > left) {
        // Ni corriendo llega (o ya ha corrido)
        final msg = tr('El recorrido cuesta {a} pies y te quedan {b}.')
            .replaceAll('{a}', '$feet')
            .replaceAll('{b}', '$left');
        if (widget.isMaster) {
          final go = await _askYesNo(
              tr('Te pasas de tu movimiento'), '$msg ${tr('¿Mover igualmente?')}',
              tr('Mover igualmente'));
          if (go != true) {
            clear();
            return;
          }
        } else {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Tx('Te pasas de tu movimiento'),
              content: Text(_dashed.contains(t.id)
                  ? '$msg ${tr('Ya has corrido este turno.')}'
                  : '$msg ${tr('Ni corriendo llegas tan lejos.')}'),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Tx('Entendido'),
                ),
              ],
            ),
          );
          clear();
          return;
        }
      }
    }

    clear();
    if (!mounted) return;

    // Escaleras y teletransportes: se pregunta a qué piso ir
    final cellValue = _displayTerrain[cellKey(end.x, end.y)];
    final onLink = (Terrains.groupOf(cellValue) != null &&
            Terrains.isLink(cellValue)) ||
        (_floorCount > 1 &&
            List.generate(_floorCount, (i) => i)
                .any((i) => Terrains.canChangeFloor(cellValue, _floor, i)));
    if (onLink) {
      await _confirmAndMove(t, end.x, end.y);
    } else {
      setState(() => _selectedId = null);
      await _service.moveToken(_code, t.id, end.x, end.y).catchError(_onError);
    }

    if (_limitMove) {
      if (dash) _dashed.add(t.id);
      _movedFeet[t.id] = (_movedFeet[t.id] ?? 0) + feet;
      if (t.id == 'p_$_uid') {
        _markUsed('move');
        final left = _feetLeft(t);
        _snack(left > 0
            ? tr('Te quedan {n} pies de movimiento.').replaceAll('{n}', '$left')
            : tr('Has gastado todo tu movimiento.'));
      }
      if (mounted) setState(() {});
    }
  }

  // ---------------------------------------------------------------
  // MARCAS EN CASILLAS
  // ---------------------------------------------------------------

  Future<void> _onCellLongPress(int x, int y) async {
    final kind = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              title: Text(
                '${tr('Marcar la casilla')} (${x + 1}, ${y + 1})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final k in CellPing.kinds)
              ListTile(
                leading: Icon(CellPing.iconOf(k)),
                title: Text(tr(CellPing.labelOf(k))),
                onTap: () => Navigator.pop(ctx, k),
              ),
            ListTile(
              leading: const Icon(Icons.layers_clear_outlined),
              title: Tx(widget.isMaster
                  ? 'Quitar todas las marcas'
                  : 'Quitar mis marcas'),
              onTap: () => Navigator.pop(ctx, '-'),
            ),
          ],
        ),
      ),
    );
    if (kind == null) return;
    try {
      if (kind == '-') {
        await _service.clearMyPings(_code, all: widget.isMaster);
      } else {
        await _service.addPing(
          _code,
          x: x,
          y: y,
          floor: _floor,
          kind: kind,
          author: _myName,
          color: _myColor,
        );
      }
    } catch (e) {
      _snack('${tr('No se pudo guardar')}: $e');
    }
  }

  void _onCellPaint(int x, int y) {
    if (!widget.isMaster || _tool == _Tool.move) return;

    final key = cellKey(x, y);
    final value = _tool == _Tool.erase
        ? null
        : Terrains.applyBrush(_displayTerrain[key], _brush);

    if (_paintBuffer.containsKey(key) && _paintBuffer[key] == value) return;

    setState(() => _paintBuffer[key] = value);

    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 400), _flushPaint);
  }

  Future<void> _flushPaint() async {
    if (_paintBuffer.isEmpty) return;

    final batch = Map<String, String?>.from(_paintBuffer);
    final floor = _terrainFloor;
    try {
      await _service.paintCells(_code, batch, floor);
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
        _snack(tr('Esa criatura ya no está en la partida.'));
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
      _snack('${tr('No se pudo abrir la ficha')}: $e');
    }
  }

  Future<void> _renameToken(GameToken t) async {
    final ctrl = TextEditingController(text: t.label);

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Tx('Nombre de la ficha'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: tr('Vacío = nombre original'),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Tx('Guardar'),
          ),
        ],
      ),
    );

    if (value == null) return;
    _service.setTokenLabel(_code, t.id, value).catchError(_onError);
  }

  Future<void> _removeCreature(GameToken t) async {
    if (_combat?.active ?? false) {
      if (_combat!.entries.any((e) => e.covers(t.id))) {
        _snack(tr('No se puede quitar una criatura que está en el combate.'));
        return;
      }
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Quitar de la partida'),
        content: Text(tr('¿Quitar "{n}" de la partida y del mapa?').replaceAll('{n}', _nameOf(t))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Quitar'),
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
    _service
        .setSceneSize(_code, _floor, result.$1, result.$2)
        .catchError(_onError);
  }

  Future<void> _confirmClearTerrain() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Limpiar terreno'),
        content: const Tx('Se borrará todo lo pintado en el mapa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Limpiar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    setState(_paintBuffer.clear);
    _service.clearTerrain(_code, _terrainFloor).catchError(_onError);
  }

  // ---------------------------------------------------------------
  // INTERFAZ
  // ---------------------------------------------------------------

  /// Franja bajo la barra superior que indica el modo activo del Master
  /// (no se superpone al mapa).
  PreferredSizeWidget _modeBar() {
    final (label, icon, color) = switch (_tool) {
      _Tool.move => (tr('Modo: Mover fichas'), Icons.pan_tool_alt_outlined, Colors.blue),
      _Tool.paint => (tr('Modo: Pintar terreno'), Icons.brush, Colors.deepOrange),
      _Tool.erase => (tr('Modo: Borrar terreno'), Icons.cleaning_services_outlined, Colors.red),
    };
    return PreferredSize(
      preferredSize: const Size.fromHeight(30),
      child: GestureDetector(
        onTap: _tool == _Tool.move
            ? () => setState(() => _bottomOpen = true)
            : () => setState(() => _tool = _Tool.move),
        child: Container(
          height: 30,
          width: double.infinity,
          color: color,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              if (_tool != _Tool.move) ...[
                const SizedBox(width: 8),
                Text(
                  '· ${tr('toca para volver a Mover')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Ficha de un jugador: nombre del personaje y nickname de quien lo lleva.
  void _showPlayerInfo(String uid) {
    final p = _playerOf(uid);
    if (p == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(p.character.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(p.character.summary),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 18),
                const SizedBox(width: 6),
                Text(p.nickname.isEmpty ? '—' : p.nickname,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// Texto principal de la barra: de quién es el turno en combate o, fuera
  /// de combate, el nombre de tu personaje (el Master ve su nickname).
  String _titleText() {
    final st = _combat;
    if (st != null && st.rolling) {
      final iRoll = st.entries.any((e) => e.id == 'p_$_uid' && !e.rolled);
      return iRoll ? tr('¡Tira tu iniciativa!') : tr('Tiradas de iniciativa');
    }
    if (st != null && st.inTurns) {
      if (st.current == 'p_$_uid') return tr('¡Tu turno!');
      final cur = st.currentEntry;
      if (cur == null) return '${tr('Turno')}: —';
      final visible = widget.isMaster ||
          _visibleIds.value.contains(cur.id) ||
          cur.members.any(_visibleIds.value.contains);
      return '${tr('Turno')}: ${visible ? cur.name : tr('Algo en las sombras…')}';
    }
    if (widget.isMaster) {
      final nick = ProfileService.instance.nickname;
      return nick.isEmpty ? tr('Master') : '${tr('Master')} · $nick';
    }
    return _playerOf(_uid)?.character.name ?? tr('Jugador');
  }

  bool _leaving = false;

  /// Un jugador confirma antes de salir de la sala.
  Future<void> _confirmLeave() async {
    if (widget.isMaster) {
      Navigator.pop(context);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Salir de la partida'),
        content: const Tx(
          '¿Seguro que quieres salir? Podrás volver a entrar con el código de la sala.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Salir'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _leaving = true);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inCombat = _combat?.active ?? false;
    final cur = _combat?.current ?? '';
    final turnNow = (_combat?.inTurns ?? false) &&
        (widget.isMaster ? !cur.startsWith('p_') : cur == 'p_$_uid');
    // Combate: fondo rojo. Tu turno: marco dorado alrededor de la pantalla.
    // Sin filtro de color en combate (el turno se marca con el borde dorado)
    const Color? tint = null;
    const gold = Color(0xFFFFC107);
    return PopScope(
      canPop: widget.isMaster || _leaving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Container(
      foregroundDecoration: turnNow
          ? BoxDecoration(border: Border.all(color: gold, width: 5))
          : null,
      child: Scaffold(
      backgroundColor: tint == null
          ? null
          : Color.alphaBlend(tint.withOpacity(0.28),
              Theme.of(context).scaffoldBackgroundColor),
      appBar: _fullMap
          ? null
          : AppBar(
        backgroundColor: tint?.withOpacity(0.55),
        title: Text(
          _titleText(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: turnNow ? gold : null,
          ),
        ),
        centerTitle: true,
        bottom: widget.isMaster ? _modeBar() : null,
        actions: [
          IconButton(
            tooltip: tr('Mapa completo'),
            icon: const Icon(Icons.fullscreen),
            onPressed: () => setState(() => _fullMap = true),
          ),
          IconButton(
            tooltip: tr('Ver código de la sala'),
            icon: const AppIcon('llave'),
            onPressed: _showCode,
          ),
          if (widget.isMaster)
            IconButton(
              tooltip: tr('Reiniciar la sala (volver a la sala de espera)'),
              icon: const Icon(Icons.restart_alt),
              onPressed: _resetRoom,
            ),
          if (widget.isMaster)
            IconButton(
              tooltip: tr('Terminar la sesión (borra la partida)'),
              icon: const Icon(Icons.stop_circle_outlined),
              onPressed: _endSession,
            ),
          IconButton(
            tooltip: tr('Tutorial'),
            icon: const Icon(Icons.help_outline),
            onPressed: () => openGameTutorial(context, master: widget.isMaster),
          ),
          IconButton(
            tooltip: tr('Salir del mapa'),
            icon: const Icon(Icons.exit_to_app),
            onPressed: _confirmLeave,
          ),
        ],
      ),
      // El mapa ocupa todo el espacio; los paneles se superponen
      body: SafeArea(top: false, child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          // En horizontal el móvil puede tener barras de sistema a los lados
          final pad = MediaQuery.of(context).padding;
          final panelW = min(380.0, w * 0.9);
          final toolsW = min(widget.isMaster ? 380.0 : 340.0, w * 0.85);
          const anim = Duration(milliseconds: 220);

          final myTurn = (_combat?.inTurns ?? false) &&
              _combat!.current == 'p_$_uid';
          final myRoll = (_combat?.rolling ?? false) &&
              _combat!.entries.any((e) => e.id == 'p_$_uid' && !e.rolled);

          return Stack(
            children: [
              Positioned.fill(child: _buildBoard()),

              // Tinte de combate (rojo) / tu turno (verde) sobre el mapa
              if (tint != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      color: tint.withOpacity(0.18),
                    ),
                  ),
                ),

              // Confirmar el movimiento elegido tocando una casilla
              if (_tapPath && _path.length > 1)
                Positioned(
                  left: 8,
                  right: 8,
                  bottom: 12 + pad.bottom,
                  child: Center(child: _tapMoveBar()),
                ),

              // Salir del modo mapa completo
              if (_fullMap)
                Positioned(
                  top: 8 + pad.top,
                  right: 8 + pad.right,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: tr('Salir del mapa completo'),
                      icon: const Icon(Icons.fullscreen_exit,
                          color: Colors.white),
                      onPressed: () => setState(() => _fullMap = false),
                    ),
                  ),
                ),

              // Arriba a la izquierda: avisos, turno y última tirada
              Positioned(
                left: 8 + pad.left + 28 + (_bottomOpen ? toolsW : 0),
                top: 8,
                width: min(300.0, w - 64 - pad.left - pad.right - (_bottomOpen ? toolsW : 0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Card(
                        color: Colors.red.withOpacity(0.14),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${tr('Problema con la partida')}: $_error\n'
                                  '${tr('Si es un error de permisos, publica las reglas de Firestore más recientes.')}',
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
                    _floorChip(),
                    _moveCounter(),
                    _requestsBanner(),
                    const SizedBox(height: 6),
                    _buildLastRoll(),
                  ],
                ),
              ),

              // En pantalla completa se quita la barra de arriba, pero los
              // paneles laterales se pueden seguir abriendo
              ...[
              // Izquierda: herramientas y ficha seleccionada (desplegable)
              AnimatedPositioned(
                duration: anim,
                curve: Curves.easeOut,
                top: 0,
                bottom: 0,
                width: toolsW + pad.left,
                left: _bottomOpen ? 0 : -(toolsW + pad.left),
                child: Material(
                  elevation: 10,
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: pad.left,
                      bottom: pad.bottom,
                      top: _fullMap ? pad.top : 0,
                    ),
                    child: _buildToolsPanel(),
                  ),
                ),
              ),

              // Pestaña para abrir/cerrar el panel de la izquierda
              AnimatedPositioned(
                duration: anim,
                curve: Curves.easeOut,
                top: 0,
                bottom: 0,
                left: _bottomOpen ? toolsW + pad.left : pad.left,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Material(
                    color: !widget.isMaster || _tool == _Tool.move
                        ? Theme.of(context).colorScheme.primary
                        : (_tool == _Tool.paint ? Colors.deepOrange : Colors.red),
                    elevation: 4,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(12),
                      ),
                      onTap: () => setState(() => _bottomOpen = !_bottomOpen),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 18,
                        ),
                        child: Icon(
                          _bottomOpen ? Icons.chevron_left : Icons.chevron_right,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
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
                      top: _fullMap ? pad.top : 0,
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
                    color: (myTurn || myRoll) && !_panelOpen
                        ? gold
                        : Theme.of(context).colorScheme.primary,
                    elevation: 4,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                      onTap: () {
                        setState(() => _panelOpen = !_panelOpen);
                        _markChatSeen();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 18,
                        ),
                        child: Badge(
                          isLabelVisible: !_panelOpen && _chatUnread > 0,
                          label: Text('$_chatUnread'),
                          child: Icon(
                            _panelOpen
                                ? Icons.chevron_right
                                : ((myTurn || myRoll) ? Icons.flag : Icons.chevron_left),
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              ],
            ],
          );
        },
      )),
    ),
    ),
    );
  }

  Widget _buildBoard() {
    final fog = _fogged;
    return GameBoard(
      cols: _cols,
      rows: _rows,
      terrain: _displayTerrain,
      // Fichas dentro de zonas ocultas: el jugador no las ve (salvo la suya)
      tokens: fog.isEmpty
          ? _onFloor
          : _onFloor
              .where((t) => t.id == 'p_$_uid' || !fog.contains(cellKey(t.x, t.y)))
              .toList(),
      fogged: fog,
      viewRect: _viewRectFor(fog),
      showZones: widget.isMaster,
      selectedId: _selectedId,
      colorOf: _colorOf,
      color2Of: _color2Of,
      ringOf: (t) => _rings[t.id],
      vitalOf: _vitalOf,
      nameOf: _nameOf,
      iconOf: _iconOf,
      paintMode: widget.isMaster && _tool != _Tool.move,
      fitSignal: _fitSignal,
      onCellTap: _onCellTap,
      onCellPaint: _onCellPaint,
      reachable: _path.length > 1 ? const {} : _reach,
      marker: _marker,
      onPathStart: _onPathStart,
      onPathExtend: _onPathExtend,
      onPathEnd: _onPathEnd,
      path: _path,
      pathLabel: _pathLabel,
      pathOver: _pathOver,
      otherPaths: [
        for (final op in _otherPaths)
          if (op.floor == _floor)
            (cells: op.cells, label: op.label, over: op.over),
      ],
      pings: [
        for (final p in _pings)
          if (p.floor == _floor) p,
      ],
      onCellLongPress: _onCellLongPress,
      turnIds: _combat?.currentTokenIds ?? const {},
    );
  }

  /// Panel izquierdo del jugador: su ficha en el mapa, zonas y las pestañas
  /// Ficha, Acciones, Armas y Hechizos.
  Widget _buildPlayerPanel() {
    final zones = _zonesHere.where(_zoneVisibleToMe).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(),
        _buildSelectedBar(),
        if (zones.isNotEmpty)
          ExpansionTile(
            dense: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 10),
            title: Text('${tr('Zonas')} (${zones.length})'),
            children: [_zonesSection()],
          ),
        TabBar(
          controller: _leftTabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: tr('Ficha')),
            Tab(text: tr('Acciones')),
            Tab(text: tr('Armas')),
            Tab(text: tr('Hechizos')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _leftTabs,
            children: [
              _sheetPanel(),
              ActionsPanel(
                used: _turnUsed,
                inCombat: _limitMove,
                pending: _undoPending,
                onRequestUndo: _requestUndo,
                moveInfo: () {
                  if (!_limitMove) return null;
                  final me = _tokens.where((e) => e.id == 'p_$_uid').firstOrNull;
                  return me == null ? null : _moveInfoFor(me);
                }(),
              ),
              WeaponsPanel(
                gameCode: _code,
                uid: _uid,
                roller: _roller,
                onAction: () => _markUsed('action'),
              ),
              SpellsPanel(
                gameCode: _code,
                uid: _uid,
                roller: _roller,
                onAction: () => _markUsed('action'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Panel izquierdo del Master: sus opciones en pestañas (Mapa, Jugadores,
  /// Criaturas y Objetos). Lo general (dados, iniciativa, libro, chat) va a
  /// la derecha, igual que para los jugadores.
  Widget _buildToolsPanel() {
    if (!widget.isMaster) return _buildPlayerPanel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSelectedBar(),
        TabBar(
          controller: _leftTabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: tr('Mapa')),
            Tab(text: tr('Jugadores')),
            Tab(text: tr('Criaturas')),
            Tab(text: tr('Objetos')),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _leftTabs,
            children: [
              // Herramientas del mapa: mover/pintar, pisos, zonas y pincel
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildToolbar(),
                    _floorsSection(),
                    _zonesSection(),
                    if (_tool == _Tool.paint)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                        child: TerrainPicker(
                          brush: _brush,
                          onChanged: (v) => setState(() => _brush = v),
                        ),
                      ),
                  ],
                ),
              ),
              _sheetPanel(),
              _creaturesPanel(),
              ItemsScreen(gameCode: _code, inPanel: true),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Escenas: selector, alta, nombre, ocultar y baja (Master) ----

  /// Añade una escena: vacía (del tamaño de la actual) o copiada de un mapa
  /// guardado (todas sus escenas, cada una con su tamaño).
  Future<void> _addFloor() async {
    if (_floorCount >= Scenes.maxScenes) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Wrap(children: [
          ListTile(
            leading: const Icon(Icons.crop_square),
            title: const Tx('Escena vacía'),
            subtitle: Text('$_cols × $_rows'),
            onTap: () => Navigator.pop(ctx, 'empty'),
          ),
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Tx('Desde un mapa guardado'),
            subtitle: const Tx('Añade sus escenas a la partida, cada una con su tamaño.'),
            onTap: () => Navigator.pop(ctx, 'map'),
          ),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    final before = _floorCount;
    if (choice == 'empty') {
      await _service.addScenes(_code, [
        (
          name: 'Escena ${_floorCount + 1}',
          cols: _cols,
          rows: _rows,
          cells: const <String, String>{},
        ),
      ]).catchError(_onError);
    } else {
      final m = await _pickSavedMap();
      if (m == null || !mounted) return;
      final room = Scenes.maxScenes - _floorCount;
      await _service.addScenes(_code, [
        for (var i = 0; i < m.floorCount && i < room; i++)
          (
            name: m.floorCount == 1 ? m.name : '${m.name} · ${m.floorName(i)}',
            cols: m.sizeOf(i).cols,
            rows: m.sizeOf(i).rows,
            cells: m.floorCells(i),
          ),
      ]).catchError(_onError);
    }
    if (mounted) _setViewFloor(before);
  }

  /// Elegir uno de los mapas guardados (o de ejemplo).
  Future<MapTemplate?> _pickSavedMap() {
    return showDialog<MapTemplate>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Elegir mapa'),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: 420,
          height: 420,
          child: StreamBuilder<List<MapTemplate>>(
            stream: MapService().myMaps(),
            builder: (context, snap) {
              final mine = snap.data ?? const <MapTemplate>[];
              final all = [...mine, ...DefaultMaps.all];
              return ListView(
                children: [
                  for (final m in all)
                    ListTile(
                      leading: Icon(m.builtIn ? Icons.map_outlined : Icons.edit_location_alt_outlined),
                      title: Text(tr(m.name)),
                      subtitle: Text(
                        '${m.cols} × ${m.rows}'
                        '${m.floorCount > 1 ? ' · ${m.floorCount} ${tr('escenas')}' : ''}',
                      ),
                      onTap: () => Navigator.pop(ctx, m),
                    ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Cancelar'),
          ),
        ],
      ),
    );
  }

  /// Ocultar o mostrar a los jugadores la escena que se ve.
  void _toggleSceneHidden() {
    final hidden = _hiddenScenes.contains(_floor);
    _service.setSceneHidden(_code, _floor, !hidden).catchError(_onError);
  }

  Future<void> _renameFloor() async {
    final i = _floor;
    final ctrl = TextEditingController(text: _floorNames[i]);
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Nombre de la escena'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 24,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Tx('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Tx('Guardar'),
          ),
        ],
      ),
    );
    if (v == null || v.isEmpty) return;
    final names = [..._floorNames];
    names[i] = v;
    _service.setFloorNames(_code, names).catchError(_onError);
  }

  Future<void> _removeLastFloor() async {
    if (_floorCount < 2) return;
    final last = _floorCount - 1;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Quitar la última escena'),
        content: Text(
          '${tr('Se borrará el terreno de')} «${_floorName(last)}» '
          '${tr('y sus fichas pasarán a la escena anterior.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_viewFloor >= last) _setViewFloor(last - 1);
    _service.removeLastFloor(_code, _floorNames).catchError(_onError);
  }

  Widget _floorsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Icon(Icons.layers_outlined, size: 18),
          for (var i = 0; i < _floorCount; i++)
            ChoiceChip(
              selected: _floor == i,
              visualDensity: VisualDensity.compact,
              avatar: _hiddenScenes.contains(i)
                  ? const Icon(Icons.visibility_off, size: 16)
                  : null,
              label: Text(_floorName(i)),
              onSelected: (_) => _setViewFloor(i),
            ),
          IconButton(
            tooltip: tr('Añadir escena'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _floorCount >= Scenes.maxScenes ? null : _addFloor,
          ),
          IconButton(
            tooltip: _hiddenScenes.contains(_floor)
                ? tr('Mostrar esta escena a los jugadores')
                : tr('Ocultar esta escena a los jugadores'),
            visualDensity: VisualDensity.compact,
            icon: Icon(_hiddenScenes.contains(_floor)
                ? Icons.visibility_off
                : Icons.visibility_outlined),
            onPressed: _toggleSceneHidden,
          ),
          IconButton(
            tooltip: tr('Renombrar escena'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.edit_outlined),
            onPressed: _renameFloor,
          ),
          IconButton(
            tooltip: tr('Quitar la última escena'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: _floorCount < 2 ? null : _removeLastFloor,
          ),
        ],
      ),
    );
  }

  /// Etiqueta del piso actual (arriba a la izquierda). El Master puede
  /// cambiar de piso desde aquí.
  Widget _floorChip() {
    if (_floorCount < 2) return const SizedBox.shrink();
    final chip = Material(
      color: Theme.of(context).colorScheme.surface.withAlpha(235),
      elevation: 3,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.layers_outlined, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _floorName(_floor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (widget.isMaster) const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
    if (!widget.isMaster) return chip;
    return PopupMenuButton<int>(
      tooltip: tr('Cambiar de escena'),
      padding: EdgeInsets.zero,
      onSelected: _setViewFloor,
      itemBuilder: (_) => [
        for (var i = 0; i < _floorCount; i++)
          PopupMenuItem(
            value: i,
            child: Row(children: [
              if (_hiddenScenes.contains(i)) ...[
                const Icon(Icons.visibility_off, size: 16),
                const SizedBox(width: 6),
              ],
              Text(_floorName(i)),
            ]),
          ),
      ],
      child: chip,
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            r.headline,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildToolbar() {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (widget.isMaster) ...[
              SegmentedButton<_Tool>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: _Tool.move,
                    icon: Icon(Icons.pan_tool_alt_outlined),
                    label: Tx('Mover'),
                  ),
                  ButtonSegment(
                    value: _Tool.paint,
                    icon: Icon(Icons.brush),
                    label: Tx('Pintar'),
                  ),
                  ButtonSegment(
                    value: _Tool.erase,
                    icon: Icon(Icons.cleaning_services_outlined),
                    label: Tx('Borrar'),
                  ),
                ],
                selected: {_tool},
                onSelectionChanged: (s) => setState(() => _tool = s.first),
              ),
              IconButton(
                tooltip: tr('Tamaño de la escena'),
                icon: const Icon(Icons.grid_on),
                onPressed: _gridSizeDialog,
              ),
              IconButton(
                tooltip: tr('Limpiar terreno'),
                icon: const Icon(Icons.layers_clear),
                onPressed: _confirmClearTerrain,
              ),
            ],
            if (!widget.isMaster)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Tx(
                  'Toca tu ficha y traza el recorrido tocando casillas (o arrastrando desde tu ficha). Mantén pulsada una casilla para marcarla.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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

    // Un jugador que mira una criatura: solo ve su nombre (sin número) y la
    // barra de salud, sin cifras.
    if (!_canMove(t)) {
      final ratio = t.hpPct / 100.0;
      final bar = ratio > 0.5
          ? Colors.green
          : (ratio > 0.25 ? Colors.orange : Colors.red);
      return Material(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: _colorOf(t),
                child: Icon(_iconOf(t), size: 14, color: _color2Of(t)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _plainNameOf(t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0).toDouble(),
                      minHeight: 10,
                      color: bar,
                      backgroundColor: Colors.grey.withAlpha(90),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, backgroundColor: _colorOf(t)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t.hidden
                        ? '${_nameOf(t)} · ${tr('fuera del mapa')}'
                        : '${_nameOf(t)} · (${t.x + 1}, ${t.y + 1}) · '
                            'Mov. ${_speedOf(t)} pies',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Wrap(
              children: [
            if (_floorCount > 1 &&
                !t.hidden &&
                (widget.isMaster ||
                    Terrains.isLink(_terrain[cellKey(t.x, t.y)])))
              PopupMenuButton<int>(
                tooltip: tr('Cambiar de escena'),
                icon: const Icon(Icons.swap_vert),
                onSelected: (i) => _service
                    .moveTokenToFloor(_code, t.id, t.x, t.y, i)
                    .catchError(_onError),
                itemBuilder: (_) => [
                  for (var i = 0; i < _floorCount; i++)
                    if (i != t.floor &&
                        (widget.isMaster ||
                            Terrains.canChangeFloor(
                                _terrain[cellKey(t.x, t.y)], t.floor, i)))
                      PopupMenuItem(value: i, child: Text(_floorName(i))),
                ],
              ),
            if (canOpenSheet && widget.isMaster)
              IconButton(
                tooltip: tr('Ver ficha'),
                icon: const Icon(Icons.description_outlined),
                onPressed: () => _openTokenSheet(t),
              ),
            if (widget.isMaster && !t.isPlayer) ...[
              IconButton(
                tooltip: t.hidden
                    ? tr('Colocar en el mapa')
                    : tr('Sacar del mapa (oculta a los jugadores)'),
                icon: Icon(t.hidden ? Icons.login : Icons.logout),
                onPressed: () => (t.hidden
                        ? _service.placeTokenOnMap(_code, t.id, floor: _floor)
                        : _service.setTokenHidden(_code, t.id, true))
                    .catchError(_onError),
              ),
              PopupMenuButton<int>(
                tooltip: tr('Tamaño de la ficha'),
                icon: const Icon(Icons.open_in_full),
                onSelected: (v) =>
                    _service.setTokenSpan(_code, t.id, v).catchError(_onError),
                itemBuilder: (_) => [
                  for (final v in const [1, 2, 3, 4])
                    PopupMenuItem(
                      value: v,
                      child: Text(v == 1 ? tr('Normal (1×1)') : '$v×$v ${tr('casillas')}'),
                    ),
                ],
              ),
              IconButton(
                tooltip: tr('Cambiar nombre'),
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _renameToken(t),
              ),
              IconButton(
                tooltip: tr('Quitar de la partida'),
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _removeCreature(t),
              ),
            ],
              ],
            ),
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
        isMaster: widget.isMaster,
        hiddenRolls: _hiddenRolls,
        nameProvider: () => _myName,
        colorProvider: () => _myColor,
      );

  Widget _sheetPanel() {
    if (widget.isMaster) return PlayersPanel(gameCode: _code);
    final target = _tokens.where((t) => t.id == _sheetTarget).firstOrNull;
    // Sin nada tocado (o tocando la suya): su ficha
    if (target == null || target.id == 'p_$_uid') {
      return PlayerLiveSheet(
          gameCode: _code, uid: _uid, canEdit: true, compact: true);
    }
    Widget header(String title, String sub) => Material(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: _colorOf(target),
              child: Icon(_iconOf(target), size: 16, color: _color2Of(target)),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: sub.isEmpty ? null : Text(sub),
            trailing: TextButton(
              onPressed: () => setState(() => _sheetTarget = null),
              child: const Tx('Mi ficha'),
            ),
          ),
        );
    // Otro jugador: su ficha completa (solo lectura) con su nickname
    if (target.isPlayer) {
      final p = _playerOf(target.refId);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header(p?.character.name ?? _plainNameOf(target), p?.nickname ?? ''),
          Expanded(
            child: PlayerLiveSheet(
              gameCode: _code,
              uid: target.refId,
              canEdit: false,
              compact: true,
            ),
          ),
        ],
      );
    }
    // Criatura: solo el nombre y la barra de salud
    final ratio = (target.hpPct / 100.0).clamp(0.0, 1.0).toDouble();
    final bar = ratio > 0.5
        ? Colors.green
        : (ratio > 0.25 ? Colors.orange : Colors.red);
    return ListView(
      children: [
        header(_plainNameOf(target), ''),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Tx('Salud', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 14,
                  color: bar,
                  backgroundColor: Colors.grey.withAlpha(90),
                ),
              ),
              const SizedBox(height: 8),
              Tx(
                ratio <= 0
                    ? 'Fuera de combate'
                    : (ratio > 0.5
                        ? 'En buen estado'
                        : (ratio > 0.25 ? 'Herido' : 'Malherido')),
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Criaturas de la partida: lista única con las que están en el mapa y
  /// las que esperan fuera de él, y el botón para añadir nuevas.
  Widget _creaturesPanel() => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Tx('Los jugadores pueden seleccionar criaturas'),
            subtitle: const Tx('Verán su nombre y su barra de salud.'),
            value: _playersSelectCreatures,
            onChanged: (v) => _service
                .setPlayersSelectCreatures(_code, v)
                .catchError(_onError),
          ),
          const Divider(),
          GameCreaturesSection(
            gameCode: _code,
            ringOf: (id) => _rings[id],
            tokens: _tokens,
            selectedId: _selectedId,
            floor: _floor,
            onLocate: (id) => setState(() {
              // Se cierra el panel para poder tocar el mapa
              // Si está en el mapa, se va a su escena. Si está fuera del
              // mapa, se queda en la escena que se ve para colocarla aquí.
              final tk = _tokens.where((x) => x.id == id).firstOrNull;
              if (tk != null && !tk.hidden) _viewFloor = tk.floor;
              _selectedId = id;
              _panelOpen = false;
              _bottomOpen = false;
              WidgetsBinding.instance.addPostFrameCallback((_) => _syncFloor());
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
        onPrepare: _prepareCombat,
        onRollMine: _rollMyInitiative,
        onRollEntry: _rollEntryFor,
        onRollPending: _rollPending,
        onStartTurns: _startTurns,
        missing: _missingInCombat,
        onAdd: _addToCombat,
        onOpenEntry: _openCombatant,
      );

  /// Ventana de PG y conjuros de un combatiente (toque en la iniciativa).
  Future<void> _openCombatant(InitEntry e) async {
    var id = e.id;
    if (e.isGroup) {
      final picked = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: Text(e.name),
          children: [
            for (final m in e.members)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, m),
                child: Text(_tokenName(m)),
              ),
          ],
        ),
      );
      if (picked == null || !mounted) return;
      id = picked;
    }
    await showCombatantDialog(
      context,
      service: _service,
      gameCode: _code,
      tokenId: id,
      isMaster: widget.isMaster,
      myUid: _uid,
    );
  }

  /// Panel de la derecha, con pestañas: dados, iniciativa, jugadores y,
  /// para el Master, criaturas y fichas fuera del mapa.
  Widget _buildRightPanel() {
    final tabs = <Tab>[
      Tab(text: tr('Dados')),
      Tab(text: tr('Iniciativa')),
      Tab(text: tr('Libro')),
      Tab(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('Chat')),
          if (_chatUnread > 0) ...[
            const SizedBox(width: 4),
            Badge(label: Text('$_chatUnread')),
          ],
        ]),
      ),
    ];

    return Column(
      children: [
        _turnBanner(),
        _deathPrompt(),
        TabBar(controller: _tabs, isScrollable: true, tabs: tabs),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _dicePanel(),
              _initiativePanel(),
              const ReferenceScreen(inPanel: true),
              ChatPanel(
                gameCode: _code,
                isMaster: widget.isMaster,
                messages: _chat,
                myUid: _uid,
                nick: widget.isMaster
                    ? (ProfileService.instance.nickname.isEmpty
                        ? tr('Master')
                        : '${ProfileService.instance.nickname} (${tr('Master')})')
                    : (ProfileService.instance.nickname.isEmpty
                        ? _myName
                        : ProfileService.instance.nickname),
                color: _myColor,
                players: [
                  for (final p in _players)
                    (p.uid, p.nickname.isNotEmpty ? p.nickname : p.character.name),
                ],
              ),
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
      title: const Tx('Tamaño de la escena'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(tr('Columnas'), _colsCtrl),
            const SizedBox(height: 12),
            _field(tr('Filas'), _rowsCtrl),
            const SizedBox(height: 8),
            Text(
              tr('Entre {a} y {b}. Las fichas que queden fuera se acercarán al borde.')
                  .replaceAll('{a}', '$_min')
                  .replaceAll('{b}', '$_max'),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Tx('Cancelar'),
        ),
        ElevatedButton(onPressed: _apply, child: const Tx('Aplicar')),
      ],
    );
  }
}
