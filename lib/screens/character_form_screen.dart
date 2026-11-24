import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character.dart';
import '../services/character_service.dart';
import '../services/class_api_service.dart';
import '../services/equipment_api_service.dart';
import '../widgets/spell_widgets.dart';
import 'class_info_screen.dart';
import 'items_screen.dart';
import 'race_info_screen.dart';
import 'spell_picker_screen.dart';
import '../models/equipment_effects.dart';
import '../widgets/ability_grid.dart';
import '../widgets/item_widgets.dart';
import '../i18n/i18n.dart';

/// Crear o editar un personaje con ficha de D&D 5e.
class CharacterFormScreen extends StatefulWidget {
  final Character? character;

  /// Si se indica, se llama a esto al guardar en lugar de guardar el personaje
  /// en tu colección. Se usa para editar la copia de la ficha dentro de una
  /// partida.
  final Future<void> Function(Character character)? onSave;

  const CharacterFormScreen({super.key, this.character, this.onSave});

  @override
  State<CharacterFormScreen> createState() => _CharacterFormScreenState();
}

class _CharacterFormScreenState extends State<CharacterFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CharacterService();
  final _random = Random();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _backgroundCtrl;
  late final TextEditingController _hpCtrl;
  late final TextEditingController _acCtrl;
  late final TextEditingController _speedCtrl;
  late final TextEditingController _equipmentCtrl;
  late final TextEditingController _notesCtrl;

  String? _race;
  String? _class;
  String? _alignment;
  int _level = 1;
  late Map<String, int> _abilities;
  late Set<String> _saves;
  late Set<String> _skills;
  late List<String> _spells; // índices de la API
  late List<String> _items; // objetos de la API (índices)
  late List<String> _equipped; // objetos equipados
  late Map<String, Map<String, dynamic>> _customItems; // datos de objetos propios
  Map<String, ApiItem> _itemData = {}; // objetos leídos de la API

  final _api = ClassApiService();
  late final Future<List<ApiRef>> _racesFuture;
  late final Future<List<ApiRef>> _classesFuture;
  ApiClass? _classInfo; // datos de la clase elegida (leídos de la API)
  ApiRace? _raceInfo; // datos de la raza elegida (leídos de la API)
  String? _subrace; // índice de la subraza elegida (opcional)
  ApiSubrace? _subraceInfo; // datos de la subraza (leídos de la API)
  late bool _isCaster;
  bool _saving = false;

  bool get _isEditing => widget.character != null;

  @override
  void initState() {
    super.initState();
    final c = widget.character;

    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _backgroundCtrl = TextEditingController(text: c?.background ?? '');
    _hpCtrl = TextEditingController(text: '${c?.maxHp ?? 10}');
    _acCtrl = TextEditingController(text: '${c?.armorClass ?? 10}');
    _speedCtrl = TextEditingController(text: '${c?.speed ?? 30}');
    _equipmentCtrl = TextEditingController(text: c?.equipment ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');

    _race = (c?.race.isNotEmpty ?? false) ? c!.race : null;
    _class = (c?.characterClass.isNotEmpty ?? false) ? c!.characterClass : null;
    _subrace = (c?.subrace.isNotEmpty ?? false) ? c!.subrace : null;
    _alignment = (c?.alignment.isNotEmpty ?? false) ? c!.alignment : null;
    _level = c?.level ?? 1;
    _abilities = {
      for (final k in DndData.abilityKeys) k: c?.abilities[k] ?? 10,
    };
    _saves = {...?c?.savingThrows};
    _skills = {...?c?.skills};
    _spells = [...?c?.spells];
    _items = [...?c?.items];
    _equipped = [...?c?.equipped];
    _customItems = {...?c?.customItems};
    EquipmentApiService.registerCustomMap(_customItems);
    _loadItemData();

    _isCaster = DndData.spellcastingClasses.contains(_class);
    _racesFuture = _loadRaces();
    _classesFuture = _loadClasses();
    if (_class != null) _refreshClass(_class!, applySaves: false);
    if (_race != null) _refreshRace(_race!);
    if (_subrace != null) _refreshSubrace(_subrace!);
  }

  /// Razas de la API. Sin conexión se usan las básicas del SRD.
  Future<List<ApiRef>> _loadRaces() async {
    try {
      return await _api.fetchRaceList();
    } catch (_) {
      return [
        for (final e in DndData.raceNames.entries)
          ApiRef(index: e.key, name: e.value),
      ];
    }
  }

  /// Clases de la API. Sin conexión se usan las básicas del SRD.
  Future<List<ApiRef>> _loadClasses() async {
    try {
      return await _api.fetchClassList();
    } catch (_) {
      return [
        for (final e in DndData.classNames.entries)
          ApiRef(index: e.key, name: e.value),
      ];
    }
  }

  /// Lee la clase de la API: dado de golpe, salvaciones y si lanza conjuros.
  Future<void> _refreshClass(String index, {required bool applySaves}) async {
    try {
      final info = await _api.fetchClass(index);
      if (!mounted || _class != index) return;

      final saves = {
        for (final n in info.savingThrows)
          if (DndData.abilityKeys.contains(n.toLowerCase())) n.toLowerCase(),
      };

      setState(() {
        _classInfo = info;
        _isCaster = info.spellcastingLevel != null;
        if (applySaves && saves.isNotEmpty) _saves = saves;
      });
    } catch (_) {
      // Sin conexión: se mantienen los datos de respaldo
    }
  }

  /// Bonificadores de raza + subraza por característica.
  Map<String, int> get _racial {
    final t = <String, int>{};
    for (final b in [
      ...?_raceInfo?.abilityBonuses,
      ...?_subraceInfo?.abilityBonuses,
    ]) {
      t[b.ability] = (t[b.ability] ?? 0) + b.bonus;
    }
    return t;
  }

  /// Puntuación total (base + raza).
  int _total(String key) => _abilities[key]! + (_racial[key] ?? 0);

  /// Lee la subraza de la API: bonificadores y rasgos.
  Future<void> _refreshSubrace(String index) async {
    try {
      final info = await _api.fetchSubrace(index);
      if (!mounted || _subrace != index) return;
      setState(() => _subraceInfo = info);
    } catch (_) {
      // Sin conexión: simplemente no se muestran los datos de la subraza
    }
  }

  /// Lee la raza de la API: velocidad y bonificadores.
  Future<void> _refreshRace(String index, {bool applySpeed = false}) async {
    try {
      final info = await _api.fetchRace(index);
      if (!mounted || _race != index) return;
      setState(() {
        _raceInfo = info;
        if (applySpeed && info.speed != null) {
          _speedCtrl.text = '${info.speed}';
        }
      });
    } catch (_) {
      // Sin conexión: simplemente no se muestran los datos de la raza
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _backgroundCtrl.dispose();
    _hpCtrl.dispose();
    _acCtrl.dispose();
    _speedCtrl.dispose();
    _equipmentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int get _profBonus => 2 + ((_level - 1) ~/ 4);

  /// Lee de la API los objetos del personaje para calcular el equipo activo.
  Future<void> _loadItemData() async {
    EquipmentApiService.registerCustomMap(_customItems);
    final data = await EquipmentApiService().fetchItems(_items);
    if (mounted) setState(() => _itemData = data);
  }

  /// Personaje con lo que hay ahora en el formulario, con raza y equipo
  /// ya aplicados (CA, velocidad, ataques).
  ({Character character, EquipmentEffects effects}) _derived() {
    final base = Character(
      ownerUid: '',
      name: _nameCtrl.text,
      race: _race ?? '',
      subrace: _subrace ?? '',
      characterClass: _class ?? '',
      level: _level,
      abilities: Map<String, int>.from(_abilities),
      maxHp: int.tryParse(_hpCtrl.text) ?? 1,
      armorClass: int.tryParse(_acCtrl.text) ?? 10,
      speed: int.tryParse(_speedCtrl.text) ?? 30,
      items: _items,
      equipped: _equipped,
      customItems: _customItems,
    ).withRacial(_racial);

    final effects = EquipmentEffects.compute(base, _itemData);
    return (
      character: base.withDerived(
        ac: effects.armorClass,
        speedPenalty: effects.speedPenalty,
      ),
      effects: effects,
    );
  }

  // ---------- Acciones ----------

  void _rollAbilities() {
    setState(() {
      for (final k in DndData.abilityKeys) {
        // 4d6 descartando el dado más bajo
        final dice = List.generate(4, (_) => _random.nextInt(6) + 1)..sort();
        _abilities[k] = dice.skip(1).reduce((a, b) => a + b);
      }
    });
  }

  void _applyStandardArray() {
    setState(() {
      for (var i = 0; i < DndData.abilityKeys.length; i++) {
        _abilities[DndData.abilityKeys[i]] = DndData.standardArray[i];
      }
    });
  }

  void _suggestHp() {
    final die = _classInfo?.hitDie ?? DndData.classHitDie[_class];
    if (die == null) {
      _snack(tr('Elige primero una clase para calcular los puntos de golpe.'));
      return;
    }
    final conMod = Character.modifier(_total('con'));
    // Nivel 1: dado máximo. Siguientes niveles: media del dado.
    final hp = die + conMod + (_level - 1) * (die ~/ 2 + 1 + conMod);
    _hpCtrl.text = '${max(1, hp)}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final character = Character(
      id: widget.character?.id,
      ownerUid: _service.uid,
      name: _nameCtrl.text.trim(),
      race: _race!,
      subrace: _subrace ?? '',
      characterClass: _class!,
      background: _backgroundCtrl.text.trim(),
      alignment: _alignment ?? '',
      level: _level,
      abilities: Map<String, int>.from(_abilities),
      maxHp: max(1, int.tryParse(_hpCtrl.text) ?? 1),
      armorClass: int.tryParse(_acCtrl.text) ?? 10,
      speed: int.tryParse(_speedCtrl.text) ?? 30,
      savingThrows: _saves.toList(),
      skills: _skills.toList(),
      equipment: _equipmentCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      spells: _isCaster ? _spells : const [],
      items: _items,
      equipped: _equipped.where(_items.contains).toList(),
      customItems: {
        for (final e in _customItems.entries)
          if (_items.contains('c:${e.key}')) e.key: e.value,
      },
    );

    try {
      if (widget.onSave != null) {
        await widget.onSave!(character);
      } else {
        await _service.save(character);
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('${tr('No se pudo guardar el personaje')}: $e');
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? tr('Editar personaje') : tr('Nuevo personaje')),
      ),
      body: SafeArea(top: false, child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section(tr('Identidad'), _buildIdentity()),
                _section(tr('Características'), _buildAbilities()),
                _section(tr('Combate'), _buildCombat()),
                _section(tr('Tiradas de salvación'), _buildSaves()),
                _section(tr('Habilidades'), _buildSkills()),
                if (_isCaster) _section(tr('Hechizos'), _buildSpells()),
                _section(tr('Equipo'), _buildEquipment()),
                const SizedBox(height: 8),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isEditing ? tr('Guardar cambios') : tr('Crear personaje'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      )),
    );
  }

  Widget _section(String title, Widget child) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildIdentity() {
    return Column(
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: tr('Nombre del personaje'),
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? tr('Introduce un nombre') : null,
        ),
        const SizedBox(height: 12),
        _apiDropdown(
          label: tr('Raza'),
          future: _racesFuture,
          value: _race,
          nameOf: DndData.raceName,
          errorText: tr('Elige una raza'),
          onChanged: (v) {
            setState(() {
              _race = v;
              _raceInfo = null;
              // La subraza elegida pertenece a la raza anterior
              _subrace = null;
              _subraceInfo = null;
            });
            if (v != null) _refreshRace(v, applySpeed: true);
          },
        ),
        _raceExtras(),
        const SizedBox(height: 12),
        _apiDropdown(
          label: tr('Clase'),
          future: _classesFuture,
          value: _class,
          nameOf: DndData.className,
          errorText: tr('Elige una clase'),
          onChanged: (v) {
            setState(() {
              // Los hechizos elegidos pertenecen a la clase anterior
              if (v != _class) _spells = [];
              _class = v;
              _classInfo = null;
              _isCaster = DndData.spellcastingClasses.contains(v);
              // Salvaciones de respaldo; se ajustan con los datos de la API
              _saves = {...?DndData.classSaves[v]};
            });
            if (v != null) _refreshClass(v, applySaves: true);
          },
        ),
        _classExtras(),
        const SizedBox(height: 12),
        Row(
          children: [
            const Tx('Nivel', style: TextStyle(fontSize: 16)),
            const Spacer(),
            IconButton(
              onPressed: _level > 1 ? () => setState(() => _level--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text(
              '$_level',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            IconButton(
              onPressed: _level < 20 ? () => setState(() => _level++) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _backgroundCtrl,
          decoration: InputDecoration(
            labelText: tr('Trasfondo'),
            hintText: tr('Ej. Soldado, Acólito, Criminal...'),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _alignment,
          decoration: InputDecoration(
            labelText: tr('Alineamiento'),
            border: OutlineInputBorder(),
          ),
          items: [
            for (final a in DndData.alignments)
              DropdownMenuItem(value: a, child: Text(DndData.alignmentLabel(a))),
          ],
          onChanged: (v) => setState(() => _alignment = v),
        ),
      ],
    );
  }

  Widget _buildAbilities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _rollAbilities,
              icon: const Icon(Icons.casino),
              label: const Tx('Tirar 4d6'),
            ),
            OutlinedButton.icon(
              onPressed: _applyStandardArray,
              icon: const Icon(Icons.format_list_numbered),
              label: const Tx('Array estándar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AbilityGrid(
          abilities: _abilities,
          racial: _racial,
          onChanged: (k, v) => setState(() => _abilities[k] = v),
        ),
      ],
    );
  }

  Widget _buildCombat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _numberField(_acCtrl, tr('Clase de armadura'))),
            const SizedBox(width: 12),
            Expanded(child: _numberField(_speedCtrl, tr('Velocidad (pies)'))),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _numberField(_hpCtrl, tr('Puntos de golpe máx.'))),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton(
                onPressed: _suggestHp,
                child: const Tx('Calcular PG'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Bonificador de competencia: ${Character.signed(_profBonus)}   ·   '
          'Iniciativa: ${Character.signed(Character.modifier(_total('dex')))}',
          style: TextStyle(color: Colors.grey.shade600),
        ),
        const SizedBox(height: 4),
        Builder(builder: (context) {
          final d = _derived().character;
          return Text(
            'CA total (con raza y equipo activo): ${d.effectiveAc}   ·   '
            'Velocidad: ${d.effectiveSpeed} pies',
            style: const TextStyle(fontWeight: FontWeight.w600),
          );
        }),
      ],
    );
  }

  Widget _numberField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      // Solo cifras (sin símbolos) y como máximo 4 dígitos
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) =>
          int.tryParse(v ?? '') == null ? tr('Número no válido') : null,
    );
  }

  Widget _buildSaves() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final k in DndData.abilityKeys)
          FilterChip(
            label: Text(
              '${DndData.abilityNames[k]} '
              '${Character.signed(Character.modifier(_total(k)) + (_saves.contains(k) ? _profBonus : 0))}',
            ),
            selected: _saves.contains(k),
            onSelected: (sel) => setState(() {
              sel ? _saves.add(k) : _saves.remove(k);
            }),
          ),
      ],
    );
  }

  Widget _buildSkills() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final entry in DndData.skills.entries)
          FilterChip(
            label: Text(
              '${DndData.skillLabel(entry.key)} (${DndData.abilityShort[entry.value]}) '
              '${Character.signed(Character.modifier(_total(entry.value)) + (_skills.contains(entry.key) ? _profBonus : 0))}',
            ),
            selected: _skills.contains(entry.key),
            onSelected: (sel) => setState(() {
              sel ? _skills.add(entry.key) : _skills.remove(entry.key);
            }),
          ),
      ],
    );
  }

  /// Desplegable cuyas opciones se leen de la API. Se guarda solo el índice.
  Widget _apiDropdown({
    required String label,
    required Future<List<ApiRef>> future,
    required String? value,
    required String Function(String index) nameOf,
    required String errorText,
    required ValueChanged<String?> onChanged,
  }) {
    return FutureBuilder<List<ApiRef>>(
      future: future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final options = [...(snapshot.data ?? const <ApiRef>[])];

        // Si el valor guardado no está en la lista, se añade para no romper el desplegable
        if (value != null && !options.any((o) => o.index == value)) {
          options.insert(0, ApiRef(index: value, name: value));
        }

        return DropdownButtonFormField<String>(
          value: value,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          items: [
            for (final o in options)
              DropdownMenuItem(value: o.index, child: Text(nameOf(o.index))),
          ],
          onChanged: loading ? null : onChanged,
          validator: (v) => v == null ? errorText : null,
        );
      },
    );
  }

  Widget _raceExtras() {
    final race = _race;
    if (race == null) return const SizedBox.shrink();

    final info = _raceInfo;

    // Bonificadores de la raza y de la subraza, sumados por característica
    final totals = <String, int>{};
    for (final b in [
      ...?info?.abilityBonuses,
      ...?_subraceInfo?.abilityBonuses,
    ]) {
      totals[b.ability] = (totals[b.ability] ?? 0) + b.bonus;
    }
    final bonuses = totals.entries
        .map((e) =>
            '${DndData.abilityShort[e.key] ?? e.key.toUpperCase()} '
            '${Character.signed(e.value)}')
        .join(', ');

    final hint = [
      if (info?.speed != null) 'Velocidad ${info!.speed} pies',
      if (bonuses.isNotEmpty) 'Bonificadores: $bonuses',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SUBRAZA (solo si la raza tiene)
        if (info != null && info.subraces.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: info.subraces.any((r) => r.index == _subrace)
                ? _subrace
                : null,
            decoration: InputDecoration(
              labelText: tr('Subraza (opcional)'),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Tx('Sin subraza'),
              ),
              for (final r in info.subraces)
                DropdownMenuItem<String?>(
                  value: r.index,
                  child: Text(DndData.subraceName(r.index)),
                ),
            ],
            onChanged: (v) {
              setState(() {
                _subrace = v;
                _subraceInfo = null;
              });
              if (v != null) _refreshSubrace(v);
            },
          ),
        ],
        if (hint.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              hint,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RaceInfoScreen(
                  raceIndex: race,
                  subraceIndex: _subrace,
                ),
              ),
            ),
            icon: const Icon(Icons.menu_book_outlined),
            label: Text('${tr('Ver raza')}: ${DndData.raceName(race)}'),
          ),
        ),
      ],
    );
  }

  Widget _classExtras() {
    final cls = _class;
    if (cls == null) return const SizedBox.shrink();

    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClassInfoScreen(
              classIndex: cls,
              currentLevel: _level,
            ),
          ),
        ),
        icon: const Icon(Icons.menu_book_outlined),
        label: Text('${tr('Ver clase')}: ${DndData.className(cls)}'),
      ),
    );
  }

  Future<void> _pickSpells() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => SpellPickerScreen(
          title: '${tr('Hechizos de')} ${DndData.className(_class!)}',
          classIndex: _class!,
          characterLevel: _level,
          initial: _spells,
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() => _spells = result);
    }
  }

  Widget _buildSpells() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_spells.isEmpty)
          Tx(
            'Aún no has elegido hechizos.',
            style: TextStyle(color: Colors.grey.shade600),
          )
        else
          SpellChips(
            indexes: _spells,
            onDelete: (index) => setState(() => _spells.remove(index)),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickSpells,
          icon: const Icon(Icons.auto_fix_high),
          label: Text(
            _spells.isEmpty ? tr('Elegir hechizos') : tr('Editar hechizos'),
          ),
        ),
        const SizedBox(height: 6),
        Tx(
          'Solo se guarda la lista; el texto de cada hechizo se consulta en '
          'la API.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Future<void> _pickItems() async {
    final picked = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => const ItemsScreen(pick: true)),
    );
    if (picked != null && picked.isNotEmpty) {
      setState(() {
        _items = [..._items, ...picked];
        _customItems.addAll(EquipmentApiService.customData(picked));
      });
      _loadItemData();
    }
  }

  Widget _buildEquipment() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // OBJETOS DE LA API (afectan a CA, velocidad y ataques)
        Row(
          children: [
            const Expanded(
              child: Tx(
                'Objetos de la API',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            OutlinedButton.icon(
              onPressed: _pickItems,
              icon: const Icon(Icons.add),
              label: const Tx('Añadir objetos'),
            ),
          ],
        ),
        if (_items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Tx(
              'Sin objetos. Armaduras, escudos y armas se equipan en la ficha '
              'y cambian la CA y los ataques automáticamente.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          )
        else
          Wrap(
            spacing: 6,
            children: [
              for (var i = 0; i < _items.length; i++)
                InputChip(
                  label: Text(
                    EquipmentApiService().cachedItem(_items[i])?.displayName ??
                        _items[i].replaceFirst(RegExp(r'^[mc]:'), ''),
                  ),
                  onDeleted: () => setState(() {
                    final removed = _items.removeAt(i);
                    if (!_items.contains(removed)) _equipped.remove(removed);
                  }),
                ),
            ],
          ),
        if (_items.isNotEmpty)
          Builder(builder: (context) {
            final d = _derived();
            return CharacterItemsCard(
              character: d.character,
              data: _itemData,
              effects: d.effects,
              showList: false,
              onEquippedChanged: (list) => setState(() => _equipped = list),
            );
          }),
        const SizedBox(height: 12),
        TextFormField(
          controller: _equipmentCtrl,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: tr('Equipo y objetos'),
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: tr('Notas, rasgos e historia'),
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
