import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/equipment_effects.dart';
import '../services/equipment_api_service.dart';

/// Resumen de las características de un objeto, en español.
List<String> itemFacts(ApiItem it) {
  final facts = <String>[];

  if (it.isMagic) {
    if (it.category.isNotEmpty) facts.add(it.category);
    if (it.rarity.isNotEmpty) {
      facts.add('Rareza: ${EquipmentApiService.rarities[it.rarity] ?? it.rarity}');
    }
    // Los objetos mágicos propios con estadísticas siguen abajo
    if (!it.isEquippable) return facts;
  }
  if (it.magicBonus != 0) facts.add('Bonificador mágico: +${it.magicBonus}');

  if (it.isWeapon) {
    final type = EquipmentApiService.damageTypes[it.damageType] ??
        it.damageType.toLowerCase();
    facts.add('${it.weaponCategory == 'Martial' ? 'Marcial' : 'Sencilla'} · '
        '${it.isRanged ? 'a distancia' : 'cuerpo a cuerpo'}');
    facts.add('Daño ${it.damageDice} $type');
    if (it.rangeNormal != null && it.isRanged) {
      facts.add('Alcance ${it.rangeNormal} pies');
    }
    if (it.properties.isNotEmpty) {
      facts.add('Propiedades: ${it.properties.map((p) => EquipmentApiService.properties[p] ?? p).join(', ')}');
    }
  }

  if (it.isShield) {
    facts.add('Escudo: +${it.acBase} a la CA');
  } else if (it.isArmor) {
    final cat = EquipmentApiService.armorCategories[it.armorCategory] ??
        it.armorCategory;
    final dex = !it.acDexBonus
        ? ''
        : (it.acMaxBonus == null
            ? ' + Des'
            : ' + Des (máx. ${it.acMaxBonus})');
    facts.add('Armadura $cat: CA ${it.acBase}$dex');
    if (it.strMinimum > 0) facts.add('Requiere Fuerza ${it.strMinimum}');
    if (it.stealthDisadvantage) facts.add('Desventaja en Sigilo');
  }

  if (it.cost.isNotEmpty) facts.add('Coste: ${it.cost}');
  if (it.weight != null) facts.add('Peso: ${it.weight} lb');
  return facts;
}

/// Ficha de un objeto en un diálogo. [extraActions] añade botones (asignar...).
Future<void> showItemDetail(
  BuildContext context,
  String index, {
  List<Widget> Function(BuildContext dialogContext, ApiItem item)? extraActions,
}) {
  final api = EquipmentApiService();

  return showDialog<void>(
    context: context,
    builder: (ctx) => FutureBuilder<ApiItem>(
      future: api.fetchItem(index),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const AlertDialog(
            content: SizedBox(
              height: 60,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }
        if (snap.hasError) {
          return AlertDialog(
            title: const Text('Objeto'),
            content: Text(
              'No se pudo cargar el objeto.\n\nDetalle: ${snap.error}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ],
          );
        }

        final it = snap.data!;
        final facts = itemFacts(it);

        return AlertDialog(
          title: Text(it.name),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final f in facts)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(f),
                    ),
                  if (it.desc.isNotEmpty) ...[
                    const Divider(),
                    Text(it.desc.join('\n\n')),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            ...?extraActions?.call(ctx, it),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    ),
  );
}

/// Objetos del personaje: equipar, ver sus efectos y (si se puede) añadir o
/// quitar. Las estadísticas (CA, velocidad, ataques) se recalculan solas.
class CharacterItemsCard extends StatelessWidget {
  final Character character;
  final Map<String, ApiItem> data;
  final EquipmentEffects effects;

  /// null = solo lectura
  final void Function(List<String> equipped)? onEquippedChanged;

  /// null = no se pueden añadir objetos desde aquí
  final VoidCallback? onAdd;

  /// null = no se pueden quitar objetos
  final void Function(String index)? onRemove;

  /// false: solo se muestran las ranuras de equipo activo (por ejemplo, en
  /// el formulario del personaje, donde los objetos ya aparecen arriba)
  final bool showList;

  const CharacterItemsCard({
    super.key,
    required this.character,
    required this.data,
    required this.effects,
    this.onEquippedChanged,
    this.onAdd,
    this.onRemove,
    this.showList = true,
  });

  /// Cambia el objeto activo de una ranura (arma, armadura o escudo).
  void _setSlot(bool Function(ApiItem) isKind, String? index) {
    final list = [
      for (final e in character.equipped)
        if (!(data[e] != null && isKind(data[e]!))) e,
    ];
    if (index != null) list.add(index);
    onEquippedChanged?.call(list);
  }

  /// Objeto activo actual de una ranura.
  String? _activeOf(bool Function(ApiItem) isKind) {
    for (final e in character.equipped) {
      final it = data[e];
      if (it != null && isKind(it) && character.items.contains(e)) return e;
    }
    return null;
  }

  Widget _slot(
    String label,
    IconData icon,
    bool Function(ApiItem) isKind,
  ) {
    // Opciones: los objetos de ese tipo que tiene el personaje (sin repetir)
    final options = <String>[];
    for (final i in character.items) {
      final it = data[i];
      if (it != null && isKind(it) && !options.contains(i)) options.add(i);
    }

    final active = _activeOf(isKind);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DropdownButtonFormField<String?>(
        value: options.contains(active) ? active : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Ninguna')),
          for (final i in options)
            DropdownMenuItem<String?>(
              value: i,
              child: Text(
                '${data[i]!.name} · ${_oneLine(data[i]!)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onEquippedChanged == null || options.isEmpty
            ? null
            : (v) => _setSlot(isKind, v),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = character;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Objetos',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (onAdd != null)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir'),
                  ),
              ],
            ),

            if (c.items.isEmpty)
              Text(
                'Sin objetos.',
                style: TextStyle(color: Colors.grey.shade600),
              )
            else ...[
              const Text(
                'Equipo activo',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              _slot('Arma activa', Icons.gavel, (it) => it.slot == 'weapon'),
              _slot('Armadura activa', Icons.checkroom, (it) => it.slot == 'armor'),
              _slot('Escudo activo', Icons.shield_outlined, (it) => it.slot == 'shield'),
              if (showList) ...[
                const Divider(height: 24),
                const Text(
                  'Todos los objetos',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],

            if (showList)
              for (var i = 0; i < c.items.length; i++)
                _tile(context, c.items[i]),

            // Efectos del equipo
            if (effects.attacks.isNotEmpty) ...[
              const Divider(),
              const Text('Ataques', style: TextStyle(fontWeight: FontWeight.bold)),
              for (final a in effects.attacks)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${a.weapon.name}: ${Character.signed(a.attackBonus)} para '
                    'impactar · ${a.damage}',
                  ),
                ),
              Text(
                'Se asume competencia con el arma.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
            if (effects.armorClass != null ||
                effects.stealthDisadvantage ||
                effects.notes.isNotEmpty) ...[
              const Divider(),
              if (effects.armorClass != null)
                Text('CA con el equipo: ${effects.armorClass}'),
              if (effects.stealthDisadvantage)
                const Text('Desventaja en Sigilo por la armadura.'),
              for (final n in effects.notes) Text(n),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, String index) {
    final it = data[index];
    final name = it?.name ?? index.replaceFirst(ApiItem.magicPrefix, '');
    final isEquipped = character.equipped.contains(index);

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      onTap: () => showItemDetail(context, index),
      leading: Icon(
        it == null
            ? Icons.inventory_2_outlined
            : it.isShield
                ? Icons.shield_outlined
                : it.isArmor
                    ? Icons.checkroom
                    : it.isWeapon
                        ? Icons.gavel
                        : it.isMagic
                            ? Icons.auto_awesome
                            : Icons.inventory_2_outlined,
      ),
      title: Text(name),
      subtitle: it == null ? null : Text(_oneLine(it)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isEquipped)
            const Tooltip(
              message: 'Activo',
              child: Icon(Icons.check_circle, color: Colors.green),
            ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Quitar',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => onRemove!(index),
            ),
        ],
      ),
    );
  }

  String _oneLine(ApiItem it) {
    if (it.isShield) return 'Escudo +${it.acBase} CA';
    if (it.isArmor) return 'CA ${it.acBase}${it.acDexBonus ? ' + Des' : ''}';
    if (it.isWeapon) return '${it.damageDice} ${EquipmentApiService.damageTypes[it.damageType] ?? it.damageType.toLowerCase()}';
    if (it.isMagic) {
      final r = EquipmentApiService.rarities[it.rarity] ?? it.rarity;
      return it.magicBonus != 0 ? '$r · +${it.magicBonus}' : r;
    }
    return it.category;
  }
}
