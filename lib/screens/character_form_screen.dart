import 'dart:math';

import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/character_service.dart';
import '../widgets/spell_widgets.dart';
import 'class_info_screen.dart';
import 'spell_picker_screen.dart';

/// Crear o editar un personaje con ficha de D&D 5e.
class CharacterFormScreen extends StatefulWidget {
  final Character? character;

  const CharacterFormScreen({super.key, this.character});

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

    _race = c?.race;
    _class = c?.characterClass;
    _alignment = (c?.alignment.isNotEmpty ?? false) ? c!.alignment : null;
    _level = c?.level ?? 1;
    _abilities = {
      for (final k in DndData.abilityKeys) k: c?.abilities[k] ?? 10,
    };
    _saves = {...?c?.savingThrows};
    _skills = {...?c?.skills};
    _spells = [...?c?.spells];
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
    final die = DndData.classes[_class];
    if (die == null) {
      _snack('Elige primero una clase para calcular los puntos de golpe.');
      return;
    }
    final conMod = Character.modifier(_abilities['con']!);
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
      spells: DndData.spellcastingClasses.contains(_class) ? _spells : const [],
    );

    try {
      await _service.save(character);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('No se pudo guardar el personaje: $e');
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar personaje' : 'Nuevo personaje'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Identidad', _buildIdentity()),
                _section('Características', _buildAbilities()),
                _section('Combate', _buildCombat()),
                _section('Tiradas de salvación', _buildSaves()),
                _section('Habilidades', _buildSkills()),
                if (DndData.spellcastingClasses.contains(_class))
                  _section('Hechizos', _buildSpells()),
                _section('Equipo', _buildEquipment()),
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
                      _isEditing ? 'Guardar cambios' : 'Crear personaje',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
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
          decoration: const InputDecoration(
            labelText: 'Nombre del personaje',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Introduce un nombre' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _race,
          decoration: const InputDecoration(
            labelText: 'Raza',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final r in DndData.races)
              DropdownMenuItem(value: r, child: Text(r)),
          ],
          onChanged: (v) => setState(() => _race = v),
          validator: (v) => v == null ? 'Elige una raza' : null,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _class,
          decoration: const InputDecoration(
            labelText: 'Clase',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final c in DndData.classes.keys)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) {
            setState(() {
              // Los hechizos elegidos pertenecen a la clase anterior
              if (v != _class) _spells = [];
              _class = v;
              // Salvaciones con competencia según la clase
              _saves = {...?DndData.classSaves[v]};
            });
          },
          validator: (v) => v == null ? 'Elige una clase' : null,
        ),
        if (_class != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClassInfoScreen(
                    className: _class!,
                    currentLevel: _level,
                  ),
                ),
              ),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text('Ver clase: $_class'),
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Nivel', style: TextStyle(fontSize: 16)),
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
          decoration: const InputDecoration(
            labelText: 'Trasfondo',
            hintText: 'Ej. Soldado, Acólito, Criminal...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _alignment,
          decoration: const InputDecoration(
            labelText: 'Alineamiento',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final a in DndData.alignments)
              DropdownMenuItem(value: a, child: Text(a)),
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
              label: const Text('Tirar 4d6'),
            ),
            OutlinedButton.icon(
              onPressed: _applyStandardArray,
              icon: const Icon(Icons.format_list_numbered),
              label: const Text('Array estándar'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final k in DndData.abilityKeys) _abilityBox(k),
          ],
        ),
      ],
    );
  }

  Widget _abilityBox(String key) {
    final score = _abilities[key]!;
    final mod = Character.modifier(score);

    return Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            DndData.abilityNames[key]!,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            Character.signed(mod),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: score > 1
                    ? () => setState(() => _abilities[key] = score - 1)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Text('$score', style: const TextStyle(fontSize: 16)),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: score < 30
                    ? () => setState(() => _abilities[key] = score + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCombat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _numberField(_acCtrl, 'Clase de armadura')),
            const SizedBox(width: 12),
            Expanded(child: _numberField(_speedCtrl, 'Velocidad (pies)')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _numberField(_hpCtrl, 'Puntos de golpe máx.')),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: OutlinedButton(
                onPressed: _suggestHp,
                child: const Text('Calcular PG'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Bonificador de competencia: ${Character.signed(_profBonus)}   ·   '
          'Iniciativa: ${Character.signed(Character.modifier(_abilities['dex']!))}',
          style: TextStyle(color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (v) =>
          int.tryParse(v ?? '') == null ? 'Número no válido' : null,
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
              '${Character.signed(Character.modifier(_abilities[k]!) + (_saves.contains(k) ? _profBonus : 0))}',
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
              '${entry.key} (${DndData.abilityShort[entry.value]}) '
              '${Character.signed(Character.modifier(_abilities[entry.value]!) + (_skills.contains(entry.key) ? _profBonus : 0))}',
            ),
            selected: _skills.contains(entry.key),
            onSelected: (sel) => setState(() {
              sel ? _skills.add(entry.key) : _skills.remove(entry.key);
            }),
          ),
      ],
    );
  }

  Future<void> _pickSpells() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => SpellPickerScreen(
          title: 'Hechizos de $_class',
          className: _class!,
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
          Text(
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
            _spells.isEmpty ? 'Elegir hechizos' : 'Editar hechizos',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Solo se guarda la lista; el texto de cada hechizo se consulta en '
          'la API.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildEquipment() {
    return Column(
      children: [
        TextFormField(
          controller: _equipmentCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Equipo y objetos',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Notas, rasgos e historia',
            alignLabelWithHint: true,
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
