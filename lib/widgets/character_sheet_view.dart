import 'package:flutter/material.dart';

import '../models/character.dart';
import '../models/equipment_effects.dart';
import '../services/class_api_service.dart';
import '../services/equipment_api_service.dart';
import 'item_widgets.dart';
import '../screens/class_info_screen.dart';
import '../screens/race_info_screen.dart';
import 'spell_widgets.dart';
import '../i18n/i18n.dart';

/// Pantalla completa con la ficha de un personaje (solo lectura).
class CharacterSheetScreen extends StatelessWidget {
  final Character character;

  const CharacterSheetScreen({super.key, required this.character});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(character.name)),
      body: SafeArea(top: false, child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CharacterSheetView(character: character),
          ),
        ),
      )),
    );
  }
}

class CharacterSheetView extends StatefulWidget {
  final Character character;

  /// Si se indican, la ficha permite equipar, añadir y quitar objetos.
  final void Function(List<String> equipped)? onEquippedChanged;
  final VoidCallback? onAddItems;
  final void Function(String index)? onRemoveItem;

  const CharacterSheetView({
    super.key,
    required this.character,
    this.onEquippedChanged,
    this.onAddItems,
    this.onRemoveItem,
  });

  @override
  State<CharacterSheetView> createState() => _CharacterSheetViewState();
}

class _CharacterSheetViewState extends State<CharacterSheetView> {
  final ClassApiService _api = ClassApiService();
  final EquipmentApiService _equipApi = EquipmentApiService();
  Map<String, int> _racial = const {};
  String _loadedFor = '';
  Map<String, ApiItem> _itemData = const {};
  String _itemsLoadedFor = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CharacterSheetView old) {
    super.didUpdateWidget(old);
    _load();
  }

  /// Lee de la API los bonificadores de raza y subraza (no se guardan).
  Future<void> _loadItems() async {
    EquipmentApiService.registerCustomMap(widget.character.customItems);
    final key = widget.character.items.join(',');
    if (key == _itemsLoadedFor) return;
    _itemsLoadedFor = key;
    final data = await _equipApi.fetchItems(widget.character.items);
    if (mounted && _itemsLoadedFor == key) setState(() => _itemData = data);
  }

  Future<void> _load() async {
    _loadItems();
    final c = widget.character;
    final key = '${c.race}|${c.subrace}';
    if (key == _loadedFor) return;
    _loadedFor = key;
    try {
      final b = await _api.fetchRacialBonuses(c.race, c.subrace);
      if (mounted && _loadedFor == key) setState(() => _racial = b);
    } catch (_) {
      // Sin conexión: se muestran las puntuaciones base
    }
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.character.withRacial(_racial);

    // El equipo cambia la CA, la velocidad y los ataques automáticamente
    final effects = EquipmentEffects.compute(base, _itemData);
    final c = base.withDerived(
      ac: effects.armorClass,
      speedPenalty: effects.speedPenalty,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CABECERA
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  c.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  c.summary,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (c.background.isNotEmpty || c.alignment.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      [c.background, DndData.alignmentLabel(c.alignment)]
                          .where((e) => e.isNotEmpty)
                          .join(' · '),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // ACCESO A LA CLASE Y A LA RAZA (datos de la API)
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ClassInfoScreen(
                    classIndex: c.characterClass,
                    currentLevel: c.level,
                  ),
                ),
              ),
              icon: const Icon(Icons.menu_book_outlined),
              label: Text('${tr('Ver clase')}: ${DndData.className(c.characterClass)}'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RaceInfoScreen(
                    raceIndex: c.race,
                    subraceIndex: c.subrace,
                  ),
                ),
              ),
              icon: const Icon(Icons.diversity_3_outlined),
              label: Text('${tr('Ver raza')}: ${c.raceLabel}'),
            ),
          ],
        ),

        // COMBATE
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatBox(label: tr('CA'), value: '${c.effectiveAc}'),
            _StatBox(label: tr('PG'), value: '${c.maxHp}'),
            _StatBox(label: tr('Velocidad'), value: '${c.effectiveSpeed} ${tr('pies')}'),
            _StatBox(label: tr('Iniciativa'), value: Character.signed(c.initiative)),
            _StatBox(
              label: tr('Competencia'),
              value: Character.signed(c.proficiencyBonus),
            ),
            _StatBox(
              label: tr('Percepción pasiva'),
              value: '${c.passivePerception}',
            ),
          ],
        ),

        const SizedBox(height: 12),

        // CARACTERÍSTICAS
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final k in DndData.abilityKeys)
              _StatBox(
                label: DndData.abilityNames[k]!,
                value: Character.signed(c.mod(k)),
                caption: (c.racialBonuses[k] ?? 0) == 0
                    ? '${c.score(k)}'
                    : '${c.score(k)} (${c.abilities[k]} ${Character.signed(c.racialBonuses[k]!)})',
                width: 110,
              ),
          ],
        ),

        const SizedBox(height: 12),

        // SALVACIONES
        _SectionCard(
          title: tr('Tiradas de salvación'),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final k in DndData.abilityKeys)
                _ProfRow(
                  proficient: c.savingThrows.contains(k),
                  label: DndData.abilityNames[k]!,
                  bonus: c.saveBonus(k),
                ),
            ],
          ),
        ),

        // HABILIDADES
        _SectionCard(
          title: tr('Habilidades'),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in DndData.skills.keys)
                _ProfRow(
                  proficient: c.skills.contains(s),
                  label: '${DndData.skillLabel(s)} (${DndData.abilityShort[DndData.skills[s]]})',
                  bonus: c.skillBonus(s),
                ),
            ],
          ),
        ),

        // RASGOS DE RAZA Y SUBRAZA
        _SectionCard(
          title: '${tr('Rasgos de raza')}: ${c.raceLabel}',
          child: _RaceTraits(race: c.race, subrace: c.subrace),
        ),

        // SUBCLASES DE LA CLASE
        _SectionCard(
          title: '${tr('Subclases')}: ${DndData.className(c.characterClass)}',
          child: _Subclasses(classIndex: c.characterClass),
        ),

        if (c.spells.isNotEmpty ||
            DndData.spellcastingClasses.contains(c.characterClass))
          CharacterSpellsCard(spells: c.spells),

        // OBJETOS (API): equipar, CA, ataques...
        if (c.items.isNotEmpty ||
            widget.onAddItems != null ||
            widget.onEquippedChanged != null)
          CharacterItemsCard(
            character: c,
            data: _itemData,
            effects: effects,
            onEquippedChanged: widget.onEquippedChanged,
            onAdd: widget.onAddItems,
            onRemove: widget.onRemoveItem,
          ),

        if (c.equipment.isNotEmpty)
          _SectionCard(title: tr('Equipo'), child: Text(c.equipment)),

        if (c.notes.isNotEmpty)
          _SectionCard(
            title: tr('Notas e historia'),
            child: Text(c.notes),
          ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final double width;

  const _StatBox({
    required this.label,
    required this.value,
    this.caption,
    this.width = 120,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            children: [
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (caption != null)
                Text(
                  caption!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _ProfRow extends StatelessWidget {
  final bool proficient;
  final String label;
  final int bonus;

  const _ProfRow({
    required this.proficient,
    required this.label,
    required this.bonus,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Row(
        children: [
          Icon(
            proficient ? Icons.circle : Icons.circle_outlined,
            size: 12,
            color: Colors.deepPurple,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              Character.signed(bonus),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}


/// Texto expandible leído de la API.
class _ApiTextTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Future<List<String>> Function() loader;

  const _ApiTextTile({required this.title, required this.loader, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<String>>(
          future: loader(),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              );
            }
            if (snap.hasError) {
              return const Tx('No se pudo cargar la descripción.');
            }
            return Text(snap.data!.join('\n\n'));
          },
        ),
      ],
    );
  }
}

class _RaceTraits extends StatelessWidget {
  final String race;
  final String subrace;

  const _RaceTraits({required this.race, required this.subrace});

  @override
  Widget build(BuildContext context) {
    final api = ClassApiService();

    return FutureBuilder<List<ApiRef>>(
      future: () async {
        final r = await api.fetchRace(race);
        final sub = subrace.isEmpty ? null : await api.fetchSubrace(subrace);
        return [...r.traits, ...?sub?.traits];
      }(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snap.hasError) {
          return const Tx('No se pudieron cargar los rasgos (sin conexión).');
        }
        final traits = snap.data!;
        if (traits.isEmpty) return const Tx('Esta raza no tiene rasgos.');
        return Column(
          children: [
            for (final t in traits)
              _ApiTextTile(
                title: t.name,
                loader: () => api.fetchTraitText(t.index),
              ),
          ],
        );
      },
    );
  }
}

class _Subclasses extends StatelessWidget {
  final String classIndex;

  const _Subclasses({required this.classIndex});

  @override
  Widget build(BuildContext context) {
    final api = ClassApiService();

    return FutureBuilder<ApiClass>(
      future: api.fetchClass(classIndex),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator();
        }
        if (snap.hasError) {
          return const Tx('No se pudieron cargar las subclases.');
        }
        final subs = snap.data!.subclasses;
        if (subs.isEmpty) return const Tx('Sin subclases en el SRD.');
        return Column(
          children: [
            for (final sc in subs)
              _ApiTextTile(
                title: sc.name,
                loader: () => api.fetchSubclassText(sc.index),
              ),
          ],
        );
      },
    );
  }
}
