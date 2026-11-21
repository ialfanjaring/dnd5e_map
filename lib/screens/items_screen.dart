import 'package:flutter/material.dart';

import '../services/custom_item_service.dart';
import '../services/equipment_api_service.dart';
import '../services/game_service.dart';
import '../services/translation_service.dart';
import '../widgets/item_widgets.dart';
import 'item_form_screen.dart';
import 'spell_browser_screen.dart';
import '../i18n/i18n.dart';
import '../widgets/options_button.dart';

/// Lista de objetos predeterminados (API de D&D 5e).
///
/// - Consulta: se ven los objetos y, si se abre desde una partida
///   ([gameCode]), el Master puede asignarlos a un jugador.
/// - Selección ([pick] = true): se eligen objetos y se devuelven sus
///   índices con `Navigator.pop`.
class ItemsScreen extends StatefulWidget {
  final String? gameCode;
  final bool pick;

  /// true cuando se muestra como apartado de la pantalla principal
  final bool embedded;

  /// true cuando va dentro del panel de la partida (sin barra superior)
  final bool inPanel;

  const ItemsScreen({
    super.key,
    this.gameCode,
    this.pick = false,
    this.embedded = false,
    this.inPanel = false,
  });

  @override
  State<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends State<ItemsScreen> {
  final _api = EquipmentApiService();
  final _search = TextEditingController();

  String _category = 'weapon';
  late Future<List<ApiItemRef>> _future;
  final Map<String, int> _picked = {};

  // Filtros y orden
  String _sub = ''; // subtipo ('' = todos)
  Set<String>? _subSet; // objetos del subtipo (null = todavía cargando)
  String _rarity = ''; // clave de rareza ('' = todas)
  String _sort = 'group'; // 'group' (agrupado) o 'name'
  bool _showFilters = false; // panel de categorías y filtros (oculto por defecto)

  /// Cuántos filtros hay activos (para el distintivo del botón).
  int get _activeFilters =>
      (_sub.isNotEmpty ? 1 : 0) +
      (_rarity.isNotEmpty ? 1 : 0) +
      (_sort != 'group' ? 1 : 0);

  // Carga de los detalles (rareza, descripción...) en segundo plano
  int _loadToken = 0;
  int _loaded = 0;
  int _loadTotal = 0;

  /// Rarezas: clave (en minúsculas, inglés) -> (nombre, nivel orientativo, orden, color)
  static const Map<String, ({String name, int level, int order, Color color})>
      _rarities = {
    '': (name: 'Mundano', level: 1, order: 0, color: Color(0xFF78909C)),
    'common': (name: 'Común', level: 1, order: 1, color: Color(0xFF9E9E9E)),
    'uncommon': (name: 'Poco común', level: 3, order: 2, color: Color(0xFF43A047)),
    'rare': (name: 'Raro', level: 5, order: 3, color: Color(0xFF1E88E5)),
    'very rare': (name: 'Muy raro', level: 11, order: 4, color: Color(0xFF8E24AA)),
    'legendary': (name: 'Legendario', level: 17, order: 5, color: Color(0xFFFB8C00)),
    'artifact': (name: 'Artefacto', level: 17, order: 6, color: Color(0xFFD32F2F)),
    'varies': (name: 'Variable', level: 1, order: 7, color: Color(0xFF00897B)),
  };

  /// Subtipos por categoría: (clave de la API, nombre). Las claves de la API
  /// se descargan como listas de índices (rápido, sin abrir cada objeto).
  static const Map<String, List<(String, String)>> _subs = {
    'weapon': [
      ('simple-weapons', 'Simples'),
      ('martial-weapons', 'Marciales'),
      ('melee-weapons', 'Cuerpo a cuerpo'),
      ('ranged-weapons', 'A distancia'),
    ],
    'armor': [
      ('light-armor', 'Ligeras'),
      ('medium-armor', 'Medias'),
      ('heavy-armor', 'Pesadas'),
      ('shields', 'Escudos'),
    ],
    'adventuring-gear': [
      ('ammunition', 'Munición'),
      ('arcane-foci', 'Focos arcanos'),
      ('druidic-foci', 'Focos druídicos'),
      ('holy-symbols', 'Símbolos sagrados'),
      ('equipment-packs', 'Paquetes'),
      ('standard-gear', 'Equipo común'),
    ],
    'tools': [
      ('artisans-tools', 'De artesano'),
      ('musical-instruments', 'Instrumentos'),
      ('gaming-sets', 'Juegos'),
    ],
  };

  /// Tipos de objeto mágico (categoría de la API) -> nombre
  static const Map<String, String> _magicTypes = {
    'Armor': 'Armadura',
    'Weapon': 'Arma',
    'Potion': 'Poción',
    'Ring': 'Anillo',
    'Rod': 'Vara',
    'Staff': 'Bastón',
    'Wand': 'Varita',
    'Scroll': 'Pergamino',
    'Wondrous Items': 'Objeto maravilloso',
  };

  Future<void> _setSub(String key) async {
    setState(() {
      _sub = key;
      _subSet = null;
    });
    if (key.isEmpty || _category == 'magic') {
      setState(() => _subSet = const {});
      return;
    }
    final set = await _api.fetchIndexSet(key);
    if (mounted && _sub == key) setState(() => _subSet = set);
  }

  String _rarityKey(ApiItem? it) {
    final r = (it?.rarity ?? '').trim().toLowerCase();
    return _rarities.containsKey(r) ? r : (r.isEmpty ? '' : 'varies');
  }

  @override
  void initState() {
    super.initState();
    _future = _api.fetchCategory(_category);
    _startLoading(_future);
    SrdEs.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Descarga en segundo plano los detalles de la lista (con 8 peticiones a
  /// la vez) para poder filtrar por rareza y buscar en las descripciones.
  void _startLoading(Future<List<ApiItemRef>> future) {
    final token = ++_loadToken;
    future.then((refs) async {
      if (!mounted || token != _loadToken) return;
      final pending =
          refs.where((r) => _api.cachedItem(r.index) == null).toList();
      var done = refs.length - pending.length;
      setState(() {
        _loadTotal = refs.length;
        _loaded = done;
      });
      var next = 0;
      Future<void> worker() async {
        while (next < pending.length) {
          if (!mounted || token != _loadToken) return;
          final r = pending[next++];
          try {
            await _api.fetchItem(r.index);
          } catch (_) {}
          done++;
          if (done % 10 == 0 && mounted && token == _loadToken) {
            setState(() => _loaded = done);
          }
        }
      }

      await Future.wait(List.generate(8, (_) => worker()));
      if (mounted && token == _loadToken) setState(() => _loaded = refs.length);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setCategory(String c) {
    setState(() {
      _category = c;
      _rarity = '';
      _sub = '';
      _subSet = null;
      if (c != 'custom') {
        _future = _api.fetchCategory(c);
        _startLoading(_future);
      } else {
        _loadToken++;
        _loaded = _loadTotal = 0;
      }
    });
  }

  int get _pickedTotal => _picked.values.fold(0, (a, b) => a + b);

  Future<void> _assign(BuildContext dialogContext, String itemIndex) async {
    final code = widget.gameCode!;
    final service = GameService();
    final messenger = ScaffoldMessenger.of(context);

    final players = await service.players(code).first;
    if (!dialogContext.mounted) return;
    if (players.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Tx('No hay jugadores en la partida.')),
      );
      return;
    }

    final uid = await showDialog<String>(
      context: dialogContext,
      builder: (ctx) => SimpleDialog(
        title: const Tx('Asignar a…'),
        children: [
          for (final p in players)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p.uid),
              child: Text(p.character.name),
            ),
        ],
      ),
    );
    if (uid == null) return;

    try {
      await service.addItemsToPlayer(
        code,
        uid,
        [itemIndex],
        custom: EquipmentApiService.customData([itemIndex]),
      );
      final name = players.firstWhere((p) => p.uid == uid).character.name;
      messenger.showSnackBar(
        SnackBar(content: Text('Objeto asignado a $name.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('No se pudo asignar: $e')),
      );
    }
  }

  late final Stream<List<ApiItem>> _customStream =
      CustomItemService().myItems().asBroadcastStream();

  Future<void> _deleteCustom(String index, String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Tx('Eliminar objeto'),
        content: Text(
          '¿Eliminar «$name»? Los jugadores que ya lo tienen lo conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Tx('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await CustomItemService().delete(index);
  }

  /// Texto en el que busca el buscador (nombre, categoría, rareza,
  /// descripción, daño y propiedades).
  String _haystack(ApiItemRef r) {
    final it = _api.cachedItem(r.index);
    final es = r.index.startsWith(ApiItem.customPrefix)
        ? ''
        : '${SrdEs.item(r.name, 'n') ?? ''} ${SrdEs.item(r.name, 'd') ?? ''}';
    if (it == null) return foldText('${r.name} $es');
    return foldText([
      es,
      it.name,
      it.category,
      it.rarity,
      _rarities[_rarityKey(it)]?.name ?? '',
      it.weaponCategory,
      it.weaponRange,
      it.damageType,
      it.armorCategory,
      ...it.properties,
      ...it.desc,
    ].join(' '));
  }

  IconData _iconFor(ApiItem? it, bool custom) {
    if (custom) return Icons.auto_fix_high;
    final c = (it?.category ?? '').toLowerCase();
    if (_category == 'weapon' || c.contains('weapon')) return Icons.gavel;
    if (it?.armorCategory == 'Shield') return Icons.shield;
    if (_category == 'armor' || c.contains('armor')) return Icons.security;
    if (c.contains('potion')) return Icons.science;
    if (c.contains('ring')) return Icons.circle_outlined;
    if (c.contains('wand') || c.contains('rod') || c.contains('staff')) {
      return Icons.auto_fix_high;
    }
    if (c.contains('scroll')) return Icons.description;
    if (_category == 'tools') return Icons.handyman;
    if (_category == 'magic') return Icons.auto_awesome;
    return Icons.backpack;
  }

  String _summary(ApiItem? it) {
    if (it == null) return '';
    final parts = <String>[];
    if (it.damageDice.isNotEmpty) {
      parts.add('${it.damageDice} ${it.damageType}'.trim());
    }
    if (it.acBase != null) parts.add('CA ${it.acBase}');
    if (it.weaponCategory.isNotEmpty) parts.add(it.weaponCategory);
    if (it.armorCategory.isNotEmpty) parts.add(it.armorCategory);
    if (it.cost.isNotEmpty) parts.add(it.cost);
    if (parts.isEmpty && it.category.isNotEmpty) parts.add(it.category);
    return parts.join(' · ');
  }

  Widget _subChips() {
    final List<(String, String)> options;
    if (_category == 'magic') {
      final present = <String>{
        for (final r in _currentRefs) _api.cachedItem(r.index)?.category ?? '',
      };
      options = [
        for (final e in _magicTypes.entries)
          if (present.contains(e.key)) (e.key, e.value),
      ];
    } else {
      options = _subs[_category] ?? const [];
    }
    if (options.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: const Tx('Todos'),
              selected: _sub.isEmpty,
              onSelected: (_) => _setSub(''),
            ),
          ),
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(tr(o.$2)),
                selected: _sub == o.$1,
                onSelected: (_) => _setSub(o.$1),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filters() {
    // Solo las rarezas que existen en la lista cargada
    final present = <String>{};
    for (final r in _currentRefs) {
      present.add(_rarityKey(_api.cachedItem(r.index)));
    }
    final keys = _rarities.keys.where(present.contains).toList()
      ..sort((a, b) => _rarities[a]!.order.compareTo(_rarities[b]!.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _subChips(),
        if (keys.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Tx('Todas'),
                    selected: _rarity == '',
                    onSelected: (_) => setState(() => _rarity = ''),
                  ),
                ),
                for (final k in keys)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: CircleAvatar(
                        radius: 6,
                        backgroundColor: _rarities[k]!.color,
                      ),
                      label: Text(
                        '${tr(_rarities[k]!.name)} · ${tr('nivel')} ${_rarities[k]!.level}+',
                      ),
                      selected: _rarity == (k.isEmpty ? '_none' : k),
                      onSelected: (_) =>
                          setState(() => _rarity = k.isEmpty ? '_none' : k),
                    ),
                  ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: Row(
            children: [
              if (_loadTotal > 0 && _loaded < _loadTotal) ...[
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: _loadTotal == 0 ? null : _loaded / _loadTotal,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${tr('Cargando detalles')} $_loaded/$_loadTotal',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ] else
                const Spacer(),
              const Tx('Orden:', style: TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              DropdownButton<String>(
                value: _sort,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  DropdownMenuItem(value: 'group', child: Text(tr('Agrupado'))),
                  DropdownMenuItem(value: 'name', child: Text(tr('Nombre'))),
                  DropdownMenuItem(value: 'level', child: Text(tr('Nivel'))),
                ],
                onChanged: (v) => setState(() => _sort = v ?? 'group'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<ApiItemRef> _currentRefs = const [];

  Widget _buildList(List<ApiItemRef> all, {required bool custom}) {
    _currentRefs = all;

    // Palabras clave: todas deben aparecer
    final words = foldText(_search.text)
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    var items = all.where((r) {
      if (words.isNotEmpty) {
        final h = _haystack(r);
        if (!words.every(h.contains)) return false;
      }
      if (_sub.isNotEmpty) {
        if (_category == 'magic') {
          if (_api.cachedItem(r.index)?.category != _sub) return false;
        } else if (_subSet != null && !_subSet!.contains(r.index)) {
          return false;
        }
      }
      if (_rarity.isNotEmpty) {
        final key = _rarityKey(_api.cachedItem(r.index));
        if ((_rarity == '_none' ? '' : _rarity) != key) return false;
      }
      return true;
    }).toList();

    int order(ApiItemRef r) =>
        _rarities[_rarityKey(_api.cachedItem(r.index))]?.order ?? 0;

    if (_sort == 'level') {
      items.sort((a, b) {
        final c = order(a).compareTo(order(b));
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    } else {
      items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    // Agrupado: por rareza (con su nivel) en objetos mágicos y propios; por
    // categoría de arma o armadura en el resto
    String groupOf(ApiItemRef r) {
      final it = _api.cachedItem(r.index);
      if (_category == 'magic' || custom) {
        final k = _rarities[_rarityKey(it)]!;
        return it == null ? '…' : '${tr(k.name)} · ${tr('nivel')} ${k.level}+';
      }
      if (it == null) return '…';
      if (it.weaponCategory.isNotEmpty) {
        return '${it.weaponCategory} · ${it.weaponRange}';
      }
      if (it.armorCategory.isNotEmpty) return it.armorCategory;
      return it.category.isEmpty ? '' : it.category;
    }

    if (_sort == 'group') {
      final g = {for (final r in items) r.index: groupOf(r)};
      int gOrder(ApiItemRef r) => (_category == 'magic' || custom) ? order(r) : 0;
      items.sort((a, b) {
        final c = gOrder(a).compareTo(gOrder(b));
        if (c != 0) return c;
        final d = g[a.index]!.compareTo(g[b.index]!);
        return d != 0 ? d : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    }

    if (items.isEmpty) return const Center(child: Tx('Sin resultados.'));

    String? lastGroup;

    return ListView.builder(
      padding: EdgeInsets.only(bottom: custom ? 88 : 8),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final r = items[i];
        final count = _picked[r.index] ?? 0;
        final it = _api.cachedItem(r.index);
        final rk = _rarities[_rarityKey(it)]!;

        Widget? header;
        if (_sort == 'group') {
          final g = groupOf(r);
          if (g != lastGroup && g.isNotEmpty) {
            header = Container(
              width: double.infinity,
              color: rk.color.withAlpha(40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                g,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: (_category == 'magic' || custom) ? rk.color : null,
                ),
              ),
            );
          }
          lastGroup = g;
        }

        final tile = ListTile(
          dense: true,
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: rk.color.withAlpha(60),
            child: Icon(_iconFor(it, custom), size: 18, color: rk.color),
          ),
          title: Text(
            (custom ? null : SrdEs.item(r.name, 'n')) ?? r.name,
          ),
          subtitle: it == null
              ? null
              : Row(
                  children: [
                    if (it.rarity.isNotEmpty || custom || _category == 'magic')
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: rk.color.withAlpha(60),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: rk.color),
                        ),
                        child: Text(
                          tr(rk.name),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _summary(it),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
          onTap: () => showItemDetail(
            context,
            r.index,
            extraActions: (dialogContext, item) => [
              if (custom && !widget.pick)
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemFormScreen(item: item),
                      ),
                    );
                  },
                  child: const Tx('Editar'),
                ),
              if (widget.pick)
                TextButton(
                  onPressed: () {
                    setState(() => _picked[r.index] = count + 1);
                    Navigator.pop(dialogContext);
                  },
                  child: const Tx('Añadir'),
                )
              else if (widget.gameCode != null)
                ElevatedButton.icon(
                  onPressed: () => _assign(dialogContext, r.index),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Tx('Asignar a jugador'),
                ),
            ],
          ),
          trailing: widget.pick
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (count > 0) ...[
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() {
                          if (count <= 1) {
                            _picked.remove(r.index);
                          } else {
                            _picked[r.index] = count - 1;
                          }
                        }),
                      ),
                      Text('$count'),
                    ],
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          setState(() => _picked[r.index] = count + 1),
                    ),
                  ],
                )
              : (custom
                  ? IconButton(
                      tooltip: tr('Eliminar'),
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _deleteCustom(r.index, r.name),
                    )
                  : const Icon(Icons.chevron_right)),
        );
        return header == null ? tile : Column(children: [header, tile]);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.inPanel
          ? null
          : AppBar(
        title: Text(widget.pick ? 'Elegir objetos' : 'Objetos'),
        actions: [
          if (widget.embedded) const OptionsButton(),
          if (widget.pick)
            TextButton.icon(
              onPressed: () => Navigator.pop(context, [
                for (final e in _picked.entries)
                  for (var i = 0; i < e.value; i++) e.key,
              ]),
              icon: const Icon(Icons.check),
              label: Text('Listo ($_pickedTotal)'),
            ),
        ],
      ),
      floatingActionButton: _category == 'custom'
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ItemFormScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Tx('Crear objeto'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: tr('Buscar por palabras clave (nombre, efecto, daño…)'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Badge(
                  isLabelVisible: _activeFilters > 0,
                  label: Text('$_activeFilters'),
                  child: IconButton.filledTonal(
                    tooltip: tr('Categorías y filtros'),
                    isSelected: _showFilters,
                    onPressed: () => setState(() => _showFilters = !_showFilters),
                    icon: const Icon(Icons.tune),
                    selectedIcon: const Icon(Icons.expand_less),
                  ),
                ),
              ],
            ),
          ),
          if (!_showFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  tr(EquipmentApiService.categories[_category] ?? ''),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: !_showFilters
                ? const SizedBox(width: double.infinity)
                : ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.42,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                for (final e in EquipmentApiService.categories.entries)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ChoiceChip(
                                      label: Text(tr(e.value)),
                                      selected: _category == e.key,
                                      onSelected: (_) => _setCategory(e.key),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _filters(),
                          const Divider(height: 8),
                        ],
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: _category == 'custom'
                ? StreamBuilder<List<ApiItem>>(
                    stream: _customStream,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: Text('No se pudieron cargar tus objetos.\n${snap.error}',
                              textAlign: TextAlign.center),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.data!.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Tx(
                              'Todavía no has creado ningún objeto.\n'
                              'Pulsa «Crear objeto».',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      return _buildList(
                        [
                          for (final it in snap.data!)
                            ApiItemRef(index: it.index, name: it.name),
                        ],
                        custom: true,
                      );
                    },
                  )
                : FutureBuilder<List<ApiItemRef>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('No se pudo cargar la lista.\n${snap.error}',
                                    textAlign: TextAlign.center),
                                TextButton(
                                  onPressed: () => _setCategory(_category),
                                  child: const Tx('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return _buildList(snap.data!, custom: false);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
