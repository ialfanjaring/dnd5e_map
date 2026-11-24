import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/custom_item_service.dart';
import '../services/equipment_api_service.dart';
import '../i18n/i18n.dart';

/// Crear o editar un objeto propio del Master.
class ItemFormScreen extends StatefulWidget {
  final ApiItem? item;

  const ItemFormScreen({super.key, this.item});

  @override
  State<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends State<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = CustomItemService();

  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _cost;
  late final TextEditingController _weight;
  late final TextEditingController _dice;
  late final TextEditingController _range;
  late final TextEditingController _ac;
  late final TextEditingController _maxDex;
  late final TextEditingController _strMin;

  /// weapon, armor, shield, other
  String _kind = 'weapon';
  String _weaponCategory = 'Simple';
  String _weaponRange = 'Melee';
  String _damageType = 'Slashing';
  String _armorCategory = 'Light';
  bool _dexBonus = true;
  bool _limitDex = false;
  bool _stealth = false;
  bool _magic = false;
  String _rarity = 'Common';
  int _bonus = 0;
  final Set<String> _props = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final it = widget.item;

    _name = TextEditingController(text: it?.name ?? '');
    _desc = TextEditingController(text: it?.desc.join('\n\n') ?? '');
    _cost = TextEditingController(text: it?.cost ?? '');
    _weight = TextEditingController(text: it?.weight?.toString() ?? '');
    _dice = TextEditingController(text: it?.damageDice ?? '1d6');
    _range = TextEditingController(text: '${it?.rangeNormal ?? 30}');
    _ac = TextEditingController(text: '${it?.acBase ?? 11}');
    _maxDex = TextEditingController(text: '${it?.acMaxBonus ?? 2}');
    _strMin = TextEditingController(text: '${it?.strMinimum ?? 0}');

    if (it != null) {
      _kind = it.isShield
          ? 'shield'
          : it.isArmor
              ? 'armor'
              : it.isWeapon
                  ? 'weapon'
                  : 'other';
      if (it.weaponCategory.isNotEmpty) _weaponCategory = it.weaponCategory;
      if (it.weaponRange.isNotEmpty) _weaponRange = it.weaponRange;
      if (it.damageType.isNotEmpty) _damageType = it.damageType;
      if (it.armorCategory.isNotEmpty && !it.isShield) {
        _armorCategory = it.armorCategory;
      }
      _dexBonus = it.acDexBonus;
      _limitDex = it.acMaxBonus != null;
      _stealth = it.stealthDisadvantage;
      _magic = it.isMagic;
      if (it.rarity.isNotEmpty) _rarity = it.rarity;
      _bonus = it.magicBonus;
      _props.addAll(it.properties);
    } else {
      _kind = 'weapon';
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _cost, _weight, _dice, _range, _ac, _maxDex, _strMin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final isWeapon = _kind == 'weapon';
    final isArmor = _kind == 'armor';
    final isShield = _kind == 'shield';

    final item = ApiItem(
      index: widget.item?.index ?? ApiItem.customPrefix,
      name: _name.text.trim(),
      category: 'Personalizado',
      isMagic: _magic || _bonus != 0,
      rarity: (_magic || _bonus != 0) ? _rarity : '',
      desc: _desc.text.trim().isEmpty ? const [] : [_desc.text.trim()],
      cost: _cost.text.trim(),
      weight: double.tryParse(_weight.text.trim().replaceAll(',', '.')),
      weaponCategory: isWeapon ? _weaponCategory : '',
      weaponRange: isWeapon ? _weaponRange : '',
      damageDice: isWeapon ? _dice.text.trim() : '',
      damageType: isWeapon ? _damageType : '',
      rangeNormal: isWeapon && _weaponRange == 'Ranged'
          ? int.tryParse(_range.text)
          : null,
      properties: isWeapon ? _props.toList() : const [],
      armorCategory: isShield ? 'Shield' : (isArmor ? _armorCategory : ''),
      acBase: (isArmor || isShield) ? (int.tryParse(_ac.text) ?? (isShield ? 2 : 10)) : null,
      acDexBonus: isArmor && _dexBonus,
      acMaxBonus: isArmor && _dexBonus && _limitDex ? int.tryParse(_maxDex.text) : null,
      strMinimum: isArmor ? (int.tryParse(_strMin.text) ?? 0) : 0,
      stealthDisadvantage: isArmor && _stealth,
      magicBonus: (isWeapon || isArmor || isShield) ? _bonus : 0,
    );

    try {
      await _service.save(
        item,
        index: widget.item?.index,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWeapon = _kind == 'weapon';
    final isArmor = _kind == 'armor';
    final isShield = _kind == 'shield';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Nuevo objeto' : 'Editar objeto'),
        actions: [
          TextButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: const Tx('Guardar'),
          ),
        ],
      ),
      body: SafeArea(top: false, child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _name,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Pon un nombre' : null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _kind,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de objeto',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'weapon', child: Tx('Arma')),
                    DropdownMenuItem(value: 'armor', child: Tx('Armadura')),
                    DropdownMenuItem(value: 'shield', child: Tx('Escudo')),
                    DropdownMenuItem(value: 'other', child: Tx('Otro (sin estadísticas)')),
                  ],
                  onChanged: (v) => setState(() => _kind = v ?? 'weapon'),
                ),

                if (isWeapon) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _dice,
                          decoration: const InputDecoration(
                            labelText: 'Daño (ej. 1d8)',
                            border: OutlineInputBorder(),
                          ),
                          validator: (v) => RegExp(r'^\d+d\d+$')
                                  .hasMatch((v ?? '').trim())
                              ? null
                              : 'Formato: 1d8',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _damageType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de daño',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            for (final e in EquipmentApiService.damageTypes.entries)
                              DropdownMenuItem(value: e.key, child: Text(e.value)),
                          ],
                          onChanged: (v) => setState(() => _damageType = v ?? 'Slashing'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _weaponRange,
                          decoration: const InputDecoration(
                            labelText: 'Alcance',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Melee', child: Tx('Cuerpo a cuerpo')),
                            DropdownMenuItem(value: 'Ranged', child: Tx('A distancia')),
                          ],
                          onChanged: (v) => setState(() => _weaponRange = v ?? 'Melee'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _weaponCategory,
                          decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'Simple', child: Tx('Sencilla')),
                            DropdownMenuItem(value: 'Martial', child: Tx('Marcial')),
                          ],
                          onChanged: (v) => setState(() => _weaponCategory = v ?? 'Simple'),
                        ),
                      ),
                    ],
                  ),
                  if (_weaponRange == 'Ranged') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _range,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Alcance normal (pies)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Tx('Propiedades'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final e in EquipmentApiService.properties.entries)
                        FilterChip(
                          label: Text(e.value),
                          selected: _props.contains(e.key),
                          onSelected: (on) => setState(() {
                            on ? _props.add(e.key) : _props.remove(e.key);
                          }),
                        ),
                    ],
                  ),
                ],

                if (isArmor || isShield) ...[
                  const SizedBox(height: 12),
                  if (isArmor)
                    DropdownButtonFormField<String>(
                      value: _armorCategory,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de armadura',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final e in EquipmentApiService.armorCategories.entries)
                          if (e.key != 'Shield')
                            DropdownMenuItem(value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _armorCategory = v ?? 'Light'),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _ac,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: isShield ? 'Bonificador a la CA' : 'CA base',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (isArmor) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Tx('Suma el modificador de Destreza'),
                      value: _dexBonus,
                      onChanged: (v) => setState(() => _dexBonus = v),
                    ),
                    if (_dexBonus)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Tx('Limitar la Destreza (como la armadura media)'),
                        value: _limitDex,
                        onChanged: (v) => setState(() => _limitDex = v),
                      ),
                    if (_dexBonus && _limitDex)
                      TextFormField(
                        controller: _maxDex,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Máximo de Destreza',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _strMin,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Fuerza mínima (0 = sin requisito)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Tx('Desventaja en Sigilo'),
                      value: _stealth,
                      onChanged: (v) => setState(() => _stealth = v),
                    ),
                  ],
                ],

                if (isWeapon || isArmor || isShield) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(isWeapon
                          ? 'Bonificador mágico (ataque y daño)'
                          : 'Bonificador mágico (CA)'),
                      const Spacer(),
                      IconButton(
                        onPressed: _bonus > 0 ? () => setState(() => _bonus--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(_bonus == 0 ? '—' : '+$_bonus'),
                      IconButton(
                        onPressed: _bonus < 5 ? () => setState(() => _bonus++) : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Tx('Objeto mágico'),
                  value: _magic || _bonus != 0,
                  onChanged: _bonus != 0 ? null : (v) => setState(() => _magic = v),
                ),
                if (_magic || _bonus != 0)
                  DropdownButtonFormField<String>(
                    value: _rarity,
                    decoration: const InputDecoration(
                      labelText: 'Rareza',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final e in EquipmentApiService.rarities.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _rarity = v ?? 'Common'),
                  ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _cost,
                        decoration: const InputDecoration(
                          labelText: 'Coste (ej. 15 gp)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Peso (lb)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  maxLines: 6,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }
}
