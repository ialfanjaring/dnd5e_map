import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/character.dart';
import '../models/creature.dart';
import '../services/creature_service.dart';
import '../widgets/ability_grid.dart';
import '../widgets/spell_widgets.dart';
import 'spell_picker_screen.dart';
import '../i18n/i18n.dart';

/// Crear o editar un monstruo o NPC.
class CreatureFormScreen extends StatefulWidget {
  final Creature? creature;

  /// Tipo con el que se abre el formulario al crear ('monster' o 'npc').
  final String initialKind;

  const CreatureFormScreen({
    super.key,
    this.creature,
    this.initialKind = 'monster',
  });

  @override
  State<CreatureFormScreen> createState() => _CreatureFormScreenState();
}

class _CreatureFormScreenState extends State<CreatureFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CreatureService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _acCtrl;
  late final TextEditingController _hpCtrl;
  late final TextEditingController _hitDiceCtrl;
  late final TextEditingController _speedCtrl;
  late final TextEditingController _skillsCtrl;
  late final TextEditingController _sensesCtrl;
  late final TextEditingController _languagesCtrl;
  late final TextEditingController _traitsCtrl;
  late final TextEditingController _actionsCtrl;
  late final TextEditingController _notesCtrl;

  late String _kind;
  late String _size;
  late String _type;
  late String _alignment;
  late String _cr;
  late Map<String, int> _abilities;
  late List<String> _spells; // índices de la API (monstruos y NPC)
  bool _saving = false;

  bool get _isEditing => widget.creature != null;

  @override
  void initState() {
    super.initState();
    final c = widget.creature;

    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _acCtrl = TextEditingController(text: '${c?.armorClass ?? 10}');
    _hpCtrl = TextEditingController(text: '${c?.maxHp ?? 10}');
    _hitDiceCtrl = TextEditingController(text: c?.hitDice ?? '');
    _speedCtrl = TextEditingController(text: c?.speed ?? '30 pies');
    _skillsCtrl = TextEditingController(text: c?.skills ?? '');
    _sensesCtrl = TextEditingController(text: c?.senses ?? '');
    _languagesCtrl = TextEditingController(text: c?.languages ?? '');
    _traitsCtrl = TextEditingController(text: c?.traits ?? '');
    _actionsCtrl = TextEditingController(text: c?.actions ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');

    _kind = c?.kind ?? widget.initialKind;
    _size = c?.size ?? 'Mediana';
    _type = c?.creatureType ?? (_kind == 'npc' ? 'Humanoide' : 'Bestia');
    _alignment = c?.alignment ?? 'Sin alineamiento';
    _cr = c?.challengeRating ?? '1';
    _abilities = {
      for (final k in DndData.abilityKeys) k: c?.abilities[k] ?? 10,
    };
    _spells = [...?c?.spells];
  }

  @override
  void dispose() {
    for (final ctrl in [
      _nameCtrl,
      _acCtrl,
      _hpCtrl,
      _hitDiceCtrl,
      _speedCtrl,
      _skillsCtrl,
      _sensesCtrl,
      _languagesCtrl,
      _traitsCtrl,
      _actionsCtrl,
      _notesCtrl,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final creature = Creature(
      id: widget.creature?.id,
      ownerUid: _service.uid,
      kind: _kind,
      name: _nameCtrl.text.trim(),
      size: _size,
      creatureType: _type,
      alignment: _alignment,
      challengeRating: _cr,
      armorClass: int.tryParse(_acCtrl.text) ?? 10,
      maxHp: max(1, int.tryParse(_hpCtrl.text) ?? 1),
      hitDice: _hitDiceCtrl.text.trim(),
      speed: _speedCtrl.text.trim(),
      abilities: Map<String, int>.from(_abilities),
      skills: _skillsCtrl.text.trim(),
      senses: _sensesCtrl.text.trim(),
      languages: _languagesCtrl.text.trim(),
      traits: _traitsCtrl.text.trim(),
      actions: _actionsCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      spells: _spells,
    );

    try {
      await _service.save(creature);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _kind == 'npc' ? 'NPC' : 'monstruo';

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar $label' : 'Nuevo $label'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('General', _buildGeneral()),
                _section('Características', _buildAbilities()),
                _section('Combate', _buildCombat()),
                _section('Rasgos y acciones', _buildText()),
                _section('Hechizos', _buildSpells()),
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
                    label: Text(_isEditing ? 'Guardar cambios' : 'Crear $label'),
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

  /// Dropdown que añade el valor actual si no está en la lista.
  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    final items = options.contains(value) ? options : [value, ...options];

    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final o in items) DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: (v) {
        if (v != null) setState(() => onChanged(v));
      },
    );
  }

  Widget _buildGeneral() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'monster',
                label: Tx('Monstruo'),
                icon: Icon(Icons.pets),
              ),
              ButtonSegment(
                value: 'npc',
                label: Tx('NPC'),
                icon: Icon(Icons.person),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (s) => setState(() => _kind = s.first),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Introduce un nombre' : null,
        ),
        const SizedBox(height: 12),
        _dropdown('Tamaño', _size, CreatureData.sizes, (v) => _size = v),
        const SizedBox(height: 12),
        _dropdown('Tipo', _type, CreatureData.types, (v) => _type = v),
        const SizedBox(height: 12),
        _dropdown(
          'Alineamiento',
          _alignment,
          CreatureData.alignments,
          (v) => _alignment = v,
        ),
        const SizedBox(height: 12),
        _dropdown(
          'Valor de desafío (FP)',
          _cr,
          CreatureData.challengeRatings.keys.toList(),
          (v) => _cr = v,
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Experiencia: ${CreatureData.challengeRatings[_cr] ?? 0} PX',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }

  Widget _buildAbilities() {
    return AbilityGrid(
      abilities: _abilities,
      onChanged: (k, v) => setState(() => _abilities[k] = v),
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
          int.tryParse(v ?? '') == null ? 'Número no válido' : null,
    );
  }

  Widget _buildCombat() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _numberField(_acCtrl, 'Clase de armadura')),
            const SizedBox(width: 12),
            Expanded(child: _numberField(_hpCtrl, 'Puntos de golpe')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _hitDiceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dados de golpe',
                  hintText: '2d8+2',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _speedCtrl,
                decoration: const InputDecoration(
                  labelText: 'Velocidad',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickSpells() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => SpellPickerScreen(
          title: 'Hechizos del NPC',
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
            'Este NPC no tiene hechizos.',
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
          label: Text(_spells.isEmpty ? 'Elegir hechizos' : 'Editar hechizos'),
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

  Widget _buildText() {
    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: true,
          border: const OutlineInputBorder(),
        );

    return Column(
      children: [
        TextFormField(
          controller: _skillsCtrl,
          decoration: deco('Habilidades y salvaciones', hint: 'Sigilo +6'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _sensesCtrl,
          decoration: deco(
            'Sentidos',
            hint: 'Visión en la oscuridad 60 pies; Percepción pasiva 10',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _languagesCtrl,
          decoration: deco('Idiomas', hint: 'Común, goblin'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _traitsCtrl,
          maxLines: 5,
          decoration: deco('Rasgos especiales'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _actionsCtrl,
          maxLines: 6,
          decoration: deco('Acciones'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notesCtrl,
          maxLines: 3,
          decoration: deco('Notas del Master'),
        ),
      ],
    );
  }
}
