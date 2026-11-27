import 'package:flutter/material.dart';

import '../models/character.dart';
import '../services/character_service.dart';
import '../widgets/character_sheet_view.dart';
import 'character_form_screen.dart';
import '../widgets/spell_widgets.dart';
import 'class_info_screen.dart';
import 'race_info_screen.dart';
import '../widgets/avatars.dart';
import '../widgets/resolved_character.dart';
import '../i18n/i18n.dart';
import '../widgets/options_button.dart';

/// Apartado "Personajes": lista, crea, edita y elimina fichas.
class CharactersScreen extends StatelessWidget {
  /// true cuando se muestra como apartado de la pantalla principal
  final bool embedded;

  const CharactersScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final service = CharacterService();

    return Scaffold(
      appBar: AppBar(
        title: const Tx(
          'Mis personajes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: tr('Consultar razas'),
            icon: const Icon(Icons.diversity_3_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RacesScreen()),
            ),
          ),
          IconButton(
            tooltip: tr('Consultar clases'),
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ClassesScreen()),
            ),
          ),
          if (embedded) const OptionsButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CharacterFormScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Tx('Nuevo personaje'),
      ),
      body: SafeArea(top: false, child: StreamBuilder<List<Character>>(
        stream: service.myCharacters(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '${tr('No se pudieron cargar los personajes.')}\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final characters = snapshot.data!;

          if (characters.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_add_alt_1,
                      size: 80,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 16),
                    const Tx(
                      'Aún no tienes personajes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Tx(
                      'Crea tu primera ficha de D&D 5e para poder '
                      'unirte a una partida.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: characters.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final c = characters[i];
                  return _CharacterTile(
                    character: c,
                    onView: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CharacterSheetScreen(character: c),
                      ),
                    ),
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CharacterFormScreen(character: c),
                      ),
                    ),
                    onDelete: () => _confirmDelete(context, service, c),
                  );
                },
              ),
            ),
          );
        },
      )),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CharacterService service,
    Character c,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Tx('Eliminar personaje'),
        content: Text(tr('¿Seguro que quieres eliminar a "{n}"?').replaceAll('{n}', c.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Tx('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Tx('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true || c.id == null) return;

    try {
      await service.delete(c.id!);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('${tr('No se pudo eliminar')}: $e')),
      );
    }
  }
}

class _CharacterTile extends StatelessWidget {
  final Character character;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CharacterTile({
    required this.character,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = character;

    return Card(
      elevation: 3,
      child: ListTile(
        onTap: onView,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: EntityAvatar.character(c.characterClass),
        title: Text(
          c.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CharacterQuickStats(character: c, prefix: '${c.summary}\n'),
            SpellSummaryText(indexes: c.spells),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'view':
                onView();
                break;
              case 'edit':
                onEdit();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'view', child: Tx('Ver ficha')),
            PopupMenuItem(value: 'edit', child: Tx('Editar')),
            PopupMenuItem(value: 'delete', child: Tx('Eliminar')),
          ],
        ),
      ),
    );
  }
}
