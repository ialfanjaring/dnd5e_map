import 'package:flutter/material.dart';

import '../settings/app_settings.dart';

/// Texto en español o en inglés según el idioma de la app. Se usa para los
/// textos largos de reglas, manual y tutoriales (van juntos en el código para
/// no repartirlos por el diccionario de traducciones).
String bi(String es, String en) => AppSettings.instance.lang == 'en' ? en : es;

/// Una regla con título, icono y explicación (en los dos idiomas).
class RuleEntry {
  const RuleEntry({
    required this.key,
    required this.icon,
    required this.es,
    required this.en,
    required this.helpEs,
    required this.helpEn,
  });

  final String key;
  final IconData icon;
  final String es;
  final String en;
  final String helpEs;
  final String helpEn;

  String get title => bi(es, en);
  String get help => bi(helpEs, helpEn);
}

/// Lo que puedes hacer en tu turno (las casillas del panel Acciones).
const List<RuleEntry> kTurnActions = [
  RuleEntry(
    key: 'action',
    icon: Icons.bolt,
    es: 'Acción principal',
    en: 'Action',
    helpEs: 'Tienes una por turno. Con ella puedes Atacar, Lanzar un conjuro '
        'de 1 acción, Correr, Retirarte, Esquivar, Ayudar, Esconderte, '
        'Prepararte, Buscar o Usar un objeto. Abajo tienes qué hace cada una.',
    helpEn: 'You get one per turn. You can Attack, Cast a 1-action spell, '
        'Dash, Disengage, Dodge, Help, Hide, Ready, Search or Use an object. '
        'Each one is explained below.',
  ),
  RuleEntry(
    key: 'bonus',
    icon: Icons.flash_on_outlined,
    es: 'Acción adicional',
    en: 'Bonus action',
    helpEs: 'Una por turno, pero solo si un rasgo, un conjuro u otra regla te '
        'da algo que hacer con ella. Ejemplos: atacar con una segunda arma '
        'ligera, Palabra curativa, la Acción astuta del pícaro o la Furia del '
        'bárbaro. Si nada te la da, no la tienes.',
    helpEn: 'One per turn, but only if a feature, spell or other rule gives '
        'you something to do with it. Examples: attacking with a second light '
        'weapon, Healing Word, the rogue\'s Cunning Action or the barbarian\'s '
        'Rage. If nothing grants one, you don\'t have it.',
  ),
  RuleEntry(
    key: 'move',
    icon: Icons.directions_walk,
    es: 'Movimiento',
    en: 'Movement',
    helpEs: 'Puedes moverte hasta tu velocidad en pies (cada casilla son 5 '
        'pies). Puedes repartirlo en varios tramos, antes y después de tu '
        'acción. El terreno difícil cuesta el doble. Si quieres moverte más, '
        'tienes que Correr. En la partida, el contador te dice cuánto te queda.',
    helpEn: 'You can move up to your speed in feet (each square is 5 feet). '
        'You can split it into several legs, before and after your action. '
        'Difficult terrain costs double. To move further you must Dash. In '
        'the game, the counter shows how much you have left.',
  ),
  RuleEntry(
    key: 'reaction',
    icon: Icons.reply,
    es: 'Reacción',
    en: 'Reaction',
    helpEs: 'Una por ronda, incluso fuera de tu turno, cuando pasa algo que '
        'la provoca. Lo más habitual es el ataque de oportunidad: cuando un '
        'enemigo sale de tu alcance, le atacas una vez. También conjuros como '
        'Escudo o una acción que hayas preparado.',
    helpEn: 'One per round, even outside your turn, when something triggers '
        'it. The most common is the opportunity attack: when an enemy leaves '
        'your reach, you attack it once. Also spells like Shield or an action '
        'you readied.',
  ),
];

/// Acciones gratuitas.
const RuleEntry kFreeActions = RuleEntry(
  key: 'free',
  icon: Icons.chat_bubble_outline,
  es: 'Acciones gratuitas',
  en: 'Free actions',
  helpEs: 'No gastan nada: hablar brevemente, hacer un gesto o interactuar con '
      'un objeto una vez por turno (abrir una puerta, desenvainar un arma, '
      'coger algo del suelo). Una segunda interacción gasta tu acción.',
  helpEn: 'They cost nothing: speaking briefly, a gesture, or interacting with '
      'one object once per turn (opening a door, drawing a weapon, picking '
      'something up). A second interaction uses your action.',
);

/// Opciones de la acción principal.
const List<RuleEntry> kActionOptions = [
  RuleEntry(
    key: 'attack',
    icon: Icons.gps_fixed,
    es: 'Atacar',
    en: 'Attack',
    helpEs: 'Haces un ataque cuerpo a cuerpo o a distancia. Tiras 1d20 + tu '
        'modificador de ataque; si iguala o supera la CA del objetivo, aciertas '
        'y tiras el daño. Con un 20 natural es crítico (dados de daño dobles); '
        'con un 1 natural fallas siempre. Úsalo desde la pestaña Armas.',
    helpEn: 'You make one melee or ranged attack. Roll 1d20 + your attack '
        'modifier; if it meets or beats the target\'s AC you hit and roll '
        'damage. A natural 20 is a critical (double damage dice); a natural 1 '
        'always misses. Use it from the Weapons tab.',
  ),
  RuleEntry(
    key: 'cast',
    icon: Icons.auto_fix_high,
    es: 'Lanzar un conjuro',
    en: 'Cast a spell',
    helpEs: 'Lanzas un conjuro cuyo tiempo de lanzamiento sea 1 acción. Si es '
        'de nivel 1 o más gasta una ranura. Úsalo desde la pestaña Hechizos.',
    helpEn: 'You cast a spell with a casting time of 1 action. Level 1+ spells '
        'use a spell slot. Use it from the Spells tab.',
  ),
  RuleEntry(
    key: 'dash',
    icon: Icons.directions_run,
    es: 'Correr',
    en: 'Dash',
    helpEs: 'Ganas tanto movimiento extra como tu velocidad este turno. En la '
        'partida, cuando trazas un recorrido más largo de lo que te queda, te '
        'avisa y, si aceptas, te devuelve el movimiento. Algunos rasgos (como '
        'la Acción astuta del pícaro) permiten correr con la acción '
        'adicional: marca tú la que uses.',
    helpEn: 'You gain extra movement equal to your speed this turn. In the '
        'game, when you trace a path longer than what you have left, you get '
        'a warning and, if you accept, your movement is given back. Some '
        'features (like the rogue\'s Cunning Action) let you dash as a bonus '
        'action: tick whichever you use.',
  ),
  RuleEntry(
    key: 'disengage',
    icon: Icons.exit_to_app,
    es: 'Retirarse',
    en: 'Disengage',
    helpEs: 'Tu movimiento no provoca ataques de oportunidad durante el resto '
        'del turno. Úsalo para alejarte de un enemigo sin que te golpee.',
    helpEn: 'Your movement doesn\'t provoke opportunity attacks for the rest of '
        'the turn. Use it to get away from an enemy without being hit.',
  ),
  RuleEntry(
    key: 'dodge',
    icon: Icons.shield_outlined,
    es: 'Esquivar',
    en: 'Dodge',
    helpEs: 'Hasta tu próximo turno, los ataques contra ti tienen desventaja '
        '(si puedes ver al atacante) y tus salvaciones de Destreza tienen '
        'ventaja.',
    helpEn: 'Until your next turn, attacks against you have disadvantage (if '
        'you can see the attacker) and your Dexterity saves have advantage.',
  ),
  RuleEntry(
    key: 'help',
    icon: Icons.handshake_outlined,
    es: 'Ayudar',
    en: 'Help',
    helpEs: 'Un aliado tiene ventaja en su próxima prueba para una tarea, o en '
        'su próximo ataque contra una criatura a 5 pies de ti.',
    helpEn: 'An ally gets advantage on their next check for a task, or on '
        'their next attack against a creature within 5 feet of you.',
  ),
  RuleEntry(
    key: 'hide',
    icon: Icons.visibility_off_outlined,
    es: 'Esconderse',
    en: 'Hide',
    helpEs: 'Haces una prueba de Destreza (Sigilo) para ocultarte. Necesitas '
        'algo donde esconderte y que no te estén viendo claramente.',
    helpEn: 'You make a Dexterity (Stealth) check to hide. You need cover or '
        'concealment and must not be clearly seen.',
  ),
  RuleEntry(
    key: 'ready',
    icon: Icons.hourglass_top,
    es: 'Prepararse',
    en: 'Ready',
    helpEs: 'Eliges una acción y lo que la dispara («si el orco cruza la '
        'puerta, le disparo»). Cuando ocurre, la haces con tu reacción.',
    helpEn: 'You choose an action and its trigger ("if the orc comes through '
        'the door, I shoot it"). When it happens, you take it with your '
        'reaction.',
  ),
  RuleEntry(
    key: 'search',
    icon: Icons.search,
    es: 'Buscar',
    en: 'Search',
    helpEs: 'Dedicas el turno a encontrar algo: una prueba de Sabiduría '
        '(Percepción) o de Inteligencia (Investigación), según el caso.',
    helpEn: 'You spend the turn looking for something: a Wisdom (Perception) or '
        'Intelligence (Investigation) check, as appropriate.',
  ),
  RuleEntry(
    key: 'use',
    icon: Icons.backpack_outlined,
    es: 'Usar un objeto',
    en: 'Use an object',
    helpEs: 'Usas un objeto que lo requiere, como beber una poción o '
        'encender una antorcha, o haces una segunda interacción con un objeto.',
    helpEn: 'You use an object that needs it, like drinking a potion or '
        'lighting a torch, or make a second object interaction.',
  ),
];

/// Muestra la explicación de una regla en una ventana.
Future<void> showRuleDialog(BuildContext context, RuleEntry r,
    {List<RuleEntry> more = const []}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(children: [
        Icon(r.icon),
        const SizedBox(width: 8),
        Expanded(child: Text(r.title)),
      ]),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.help),
              for (final m in more) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Icon(m.icon, size: 18),
                  const SizedBox(width: 6),
                  Text(m.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 2),
                Text(m.help, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(bi('Cerrar', 'Close')),
        ),
      ],
    ),
  );
}

/// Apartado del Libro con las acciones del turno y las opciones de la acción
/// principal.
class ActionsRulesView extends StatelessWidget {
  const ActionsRulesView({super.key});

  Widget _tile(RuleEntry r) => Card(
        child: ExpansionTile(
          leading: Icon(r.icon),
          title: Text(r.title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(r.help)],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final head = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
        );
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(bi('En tu turno', 'On your turn'), style: head),
            const SizedBox(height: 4),
            Text(bi(
              'En cada turno tienes movimiento, una acción principal y, si '
                  'algo te la da, una acción adicional. La reacción la puedes '
                  'usar una vez por ronda, también en el turno de otro.',
              'Each turn you have movement, one action and, if something '
                  'grants it, one bonus action. You can use your reaction '
                  'once per round, even on someone else\'s turn.',
            )),
            const SizedBox(height: 8),
            for (final r in kTurnActions) _tile(r),
            _tile(kFreeActions),
            const SizedBox(height: 16),
            Text(bi('Qué puedes hacer con tu acción', 'What you can do with your action'),
                style: head),
            const SizedBox(height: 8),
            for (final r in kActionOptions) _tile(r),
          ],
        ),
      ),
    );
  }
}
