import 'package:flutter/material.dart';

import '../widgets/demo_board.dart';
import '../widgets/rules_help.dart';
import '../widgets/step_viewer.dart';

/// Manual para principiantes: lo básico de D&D 5e, paso a paso.
const List<GuideStep> kBeginnerManual = [
  GuideStep(
    icon: Icons.auto_stories,
    es: 'Qué es D&D',
    en: 'What D&D is',
    bodyEs: 'Dungeons & Dragons es un juego de rol: cada jugador lleva a un '
        'personaje inventado (un guerrero, una maga, un pícaro…) y el Master '
        'cuenta la historia, describe el mundo y lleva a todos los demás '
        'personajes y monstruos.\n\n'
        'No hay un tablero fijo ni un final escrito: dices qué quiere hacer tu '
        'personaje, el Master te dice qué pasa y, cuando el resultado es '
        'incierto, se tiran dados.',
    bodyEn: 'Dungeons & Dragons is a role-playing game: each player plays a '
        'made-up character (a fighter, a wizard, a rogue…) and the Master '
        'tells the story, describes the world and plays every other character '
        'and monster.\n\n'
        'There is no fixed board or written ending: you say what your '
        'character wants to do, the Master tells you what happens and, when '
        'the outcome is uncertain, dice are rolled.',
    tipEs: 'No hace falta saberse las reglas para empezar. La app calcula casi '
        'todo; tú decides qué hace tu personaje.',
    tipEn: 'You don\'t need to know the rules to start. The app works out '
        'almost everything; you decide what your character does.',
  ),
  GuideStep(
    icon: Icons.casino_outlined,
    es: 'Los dados',
    en: 'The dice',
    bodyEs: 'Se usan siete dados: d4, d6, d8, d10, d12, d20 y d100. «2d6» '
        'significa tirar dos dados de seis caras y sumarlos. «1d8+3» es un '
        'dado de ocho caras más 3.\n\n'
        'El más importante es el d20: casi todo lo que haces se decide con '
        'un d20 más un modificador.',
    bodyEn: 'Seven dice are used: d4, d6, d8, d10, d12, d20 and d100. "2d6" '
        'means rolling two six-sided dice and adding them. "1d8+3" is one '
        'eight-sided die plus 3.\n\n'
        'The most important is the d20: almost everything you do is decided '
        'with a d20 plus a modifier.',
    tipEs: 'En la partida, la pestaña Dados te deja montar la tirada tocando '
        'los dados que quieras.',
    tipEn: 'In the game, the Dice tab lets you build a roll by tapping the '
        'dice you want.',
  ),
  GuideStep(
    icon: Icons.person_outline,
    es: 'Tu personaje',
    en: 'Your character',
    bodyEs: 'Tu personaje tiene una raza (humano, elfo, enano…), una clase '
        '(guerrero, mago, clérigo…) y un nivel, que empieza en 1 y sube con '
        'la experiencia.\n\n'
        'La raza da rasgos como ver en la oscuridad; la clase decide cómo '
        'luchas, qué armaduras llevas y si lanzas conjuros. En Personajes lo '
        'creas paso a paso y la app aplica todo lo que dan raza y clase.',
    bodyEn: 'Your character has a race (human, elf, dwarf…), a class (fighter, '
        'wizard, cleric…) and a level, which starts at 1 and goes up with '
        'experience.\n\n'
        'Race gives traits like seeing in the dark; class decides how you '
        'fight, what armour you wear and whether you cast spells. In '
        'Characters you build it step by step and the app applies everything '
        'race and class give you.',
  ),
  GuideStep(
    icon: Icons.fitness_center,
    es: 'Las seis características',
    en: 'The six ability scores',
    bodyEs: 'Fuerza, Destreza, Constitución, Inteligencia, Sabiduría y '
        'Carisma. Cada una tiene una puntuación (normalmente de 8 a 18) y un '
        'modificador que es lo que sumas a los dados:\n\n'
        '10–11 → +0 · 12–13 → +1 · 14–15 → +2 · 16–17 → +3 · 8–9 → −1\n\n'
        'La Fuerza sirve para golpear y cargar, la Destreza para esquivar y '
        'disparar, la Constitución para aguantar, la Inteligencia para saber, '
        'la Sabiduría para percibir y el Carisma para convencer.',
    bodyEn: 'Strength, Dexterity, Constitution, Intelligence, Wisdom and '
        'Charisma. Each has a score (usually 8 to 18) and a modifier, which '
        'is what you add to the dice:\n\n'
        '10–11 → +0 · 12–13 → +1 · 14–15 → +2 · 16–17 → +3 · 8–9 → −1\n\n'
        'Strength is for hitting and carrying, Dexterity for dodging and '
        'shooting, Constitution for enduring, Intelligence for knowing, '
        'Wisdom for noticing and Charisma for persuading.',
  ),
  GuideStep(
    icon: Icons.flag_outlined,
    es: 'La tirada básica',
    en: 'The basic roll',
    bodyEs: 'Cuando intentas algo difícil: tiras 1d20, sumas el modificador '
        'que toque y lo comparas con un número objetivo.\n\n'
        '• Pruebas: contra una Clase de Dificultad (CD) que pone el Master. '
        'Fácil 10, media 15, difícil 20.\n'
        '• Ataques: contra la Clase de Armadura (CA) del objetivo.\n'
        '• Salvaciones: para resistir algo (un veneno, un conjuro) contra una '
        'CD.\n\n'
        'Si igualas o superas el número, lo consigues.',
    bodyEn: 'When you try something hard: roll 1d20, add the right modifier '
        'and compare it with a target number.\n\n'
        '• Checks: against a Difficulty Class (DC) set by the Master. Easy 10, '
        'medium 15, hard 20.\n'
        '• Attacks: against the target\'s Armour Class (AC).\n'
        '• Saving throws: to resist something (a poison, a spell) against a '
        'DC.\n\n'
        'If you meet or beat the number, you succeed.',
  ),
  GuideStep(
    icon: Icons.star_outline,
    es: 'Competencia, ventaja y desventaja',
    en: 'Proficiency, advantage and disadvantage',
    bodyEs: 'Si tu personaje es competente en algo (una habilidad, un arma, '
        'una salvación) suma además su bonificador de competencia: +2 a nivel '
        '1, que sube con el nivel.\n\n'
        'Con ventaja tiras dos d20 y te quedas el más alto; con desventaja, '
        'el más bajo. Se dan, por ejemplo, al atacar a alguien que no te ve '
        '(ventaja) o al atacar desde muy lejos (desventaja).',
    bodyEn: 'If your character is proficient in something (a skill, a weapon, '
        'a saving throw) they also add their proficiency bonus: +2 at level '
        '1, rising with level.\n\n'
        'With advantage you roll two d20s and keep the higher; with '
        'disadvantage, the lower. You get them, for example, when attacking '
        'someone who can\'t see you (advantage) or attacking from very far '
        '(disadvantage).',
    tipEs: 'Todas las tiradas de la app tienen el selector Normal / Ventaja / '
        'Desventaja.',
    tipEn: 'Every roll in the app has the Normal / Advantage / Disadvantage '
        'selector.',
  ),
  GuideStep(
    icon: Icons.format_list_numbered,
    es: 'El combate: iniciativa y turnos',
    en: 'Combat: initiative and turns',
    bodyEs: 'Cuando empieza una pelea, todos tiran iniciativa (1d20 + '
        'Destreza). Se juega por orden, de mayor a menor. Cuando todos han '
        'actuado, termina la ronda (6 segundos en el juego) y se vuelve a '
        'empezar.\n\n'
        'En la app, el Master inicia el combate, cada jugador tira su '
        'iniciativa y la ficha de quien tiene el turno lleva un borde dorado.',
    bodyEn: 'When a fight starts, everyone rolls initiative (1d20 + '
        'Dexterity). Turns go in order, highest first. When everyone has '
        'acted the round ends (6 seconds in the game) and it starts again.\n\n'
        'In the app, the Master starts combat, each player rolls their '
        'initiative and the token whose turn it is has a gold border.',
    scene: DemoScene(
      cols: 8,
      rows: 5,
      tokens: [
        DemoToken(2, 2, Colors.indigo, 'A', turn: true),
        DemoToken(5, 1, Colors.red, 'O'),
        DemoToken(5, 3, Colors.red, 'O'),
      ],
    ),
  ),
  GuideStep(
    icon: Icons.directions_walk,
    es: 'Tu turno',
    en: 'Your turn',
    bodyEs: 'En tu turno tienes:\n\n'
        '• Movimiento: hasta tu velocidad (30 pies = 6 casillas para la '
        'mayoría). Puedes repartirlo en varios tramos.\n'
        '• Una acción principal: atacar, lanzar un conjuro, correr, '
        'esquivar…\n'
        '• Una acción adicional, solo si algo te la da.\n'
        '• Una reacción por ronda, por ejemplo un ataque de oportunidad.\n\n'
        'En la pestaña Acciones de la partida tienes estas casillas para '
        'marcar lo que ya has usado, y el botón ⓘ explica cada una.',
    bodyEn: 'On your turn you have:\n\n'
        '• Movement: up to your speed (30 feet = 6 squares for most). You can '
        'split it into several legs.\n'
        '• One action: attack, cast a spell, dash, dodge…\n'
        '• One bonus action, only if something grants it.\n'
        '• One reaction per round, such as an opportunity attack.\n\n'
        'The Actions tab in the game has these as checkboxes to mark what '
        'you\'ve used, and the ⓘ button explains each one.',
    scene: DemoScene(
      cols: 9,
      rows: 6,
      walls: {'4_0', '4_1', '4_2'},
      tokens: [DemoToken(1, 3, Colors.indigo, 'A', turn: true)],
      reach: {
        '0_0', '1_0', '2_0', '3_0', '0_1', '1_1', '2_1', '3_1', '0_2', '1_2',
        '2_2', '3_2', '0_3', '2_3', '3_3', '4_3', '5_3', '0_4', '1_4', '2_4',
        '3_4', '4_4', '5_4', '0_5', '1_5', '2_5', '3_5', '4_5', '5_5',
      },
    ),
    tipEs: 'Lo verde es hasta dónde llegas con el movimiento que te queda.',
    tipEn: 'The green area is how far you can go with the movement you have '
        'left.',
  ),
  GuideStep(
    icon: Icons.gps_fixed,
    es: 'Atacar y hacer daño',
    en: 'Attacking and dealing damage',
    bodyEs: 'Para atacar tiras 1d20 + tu modificador de ataque. Si iguala o '
        'supera la CA del objetivo, aciertas y tiras el daño del arma (por '
        'ejemplo 1d8 + Fuerza con una espada larga).\n\n'
        'Un 20 natural en el dado es un crítico: tiras el doble de dados de '
        'daño. Un 1 natural siempre falla.\n\n'
        'En la pestaña Armas eliges el arma y la app hace las dos tiradas.',
    bodyEn: 'To attack you roll 1d20 + your attack modifier. If it meets or '
        'beats the target\'s AC you hit and roll the weapon\'s damage (for '
        'example 1d8 + Strength with a longsword).\n\n'
        'A natural 20 on the die is a critical hit: roll twice the damage '
        'dice. A natural 1 always misses.\n\n'
        'In the Weapons tab you choose the weapon and the app makes both '
        'rolls.',
  ),
  GuideStep(
    icon: Icons.favorite_outline,
    es: 'Puntos de golpe y caer a 0',
    en: 'Hit points and dropping to 0',
    bodyEs: 'Los puntos de golpe (PG) son lo que aguantas. El daño los resta '
        'y la curación los devuelve, hasta tu máximo.\n\n'
        'Si llegas a 0 PG caes inconsciente. En cada uno de tus turnos haces '
        'una tirada de salvación de muerte (1d20): con 10 o más es un éxito, '
        'con menos un fallo. Tres éxitos y te estabilizas; tres fallos y '
        'mueres. Cualquier curación te levanta.',
    bodyEn: 'Hit points (HP) are how much you can take. Damage reduces them '
        'and healing restores them, up to your maximum.\n\n'
        'At 0 HP you fall unconscious. On each of your turns you make a death '
        'saving throw (1d20): 10 or more is a success, less is a failure. '
        'Three successes and you stabilise; three failures and you die. Any '
        'healing gets you back up.',
  ),
  GuideStep(
    icon: Icons.auto_fix_high,
    es: 'Conjuros',
    en: 'Spells',
    bodyEs: 'Magos, clérigos, bardos y otras clases lanzan conjuros. Los '
        'trucos (nivel 0) se lanzan sin límite. Los de nivel 1 o más gastan '
        'un espacio de conjuro, que recuperas al descansar.\n\n'
        'Algunos conjuros piden una tirada de ataque y otros obligan al '
        'objetivo a hacer una salvación contra tu CD de conjuros. Clérigos, '
        'druidas, paladines y magos eligen cada día qué conjuros tienen '
        'preparados.',
    bodyEn: 'Wizards, clerics, bards and other classes cast spells. Cantrips '
        '(level 0) can be cast at will. Level 1+ spells use a spell slot, '
        'which you get back when you rest.\n\n'
        'Some spells need an attack roll and others force the target to make '
        'a saving throw against your spell DC. Clerics, druids, paladins and '
        'wizards choose each day which spells they have prepared.',
    tipEs: 'En la pestaña Hechizos ves tus espacios y lanzas el conjuro con '
        'un botón.',
    tipEn: 'In the Spells tab you see your slots and cast with one button.',
  ),
  GuideStep(
    icon: Icons.bedtime_outlined,
    es: 'Descansar y subir de nivel',
    en: 'Resting and levelling up',
    bodyEs: 'Un descanso corto (1 hora) te deja gastar dados de golpe para '
        'curarte. Un descanso largo (8 horas) te devuelve todos los PG y los '
        'espacios de conjuro.\n\n'
        'Al ganar experiencia subes de nivel: más PG, mejor competencia y '
        'nuevos rasgos de clase. Edita el nivel de tu personaje y la app '
        'recalcula lo demás.',
    bodyEn: 'A short rest (1 hour) lets you spend hit dice to heal. A long '
        'rest (8 hours) restores all HP and spell slots.\n\n'
        'Gaining experience levels you up: more HP, better proficiency and '
        'new class features. Edit your character\'s level and the app '
        'recalculates the rest.',
  ),
  GuideStep(
    icon: Icons.tips_and_updates_outlined,
    es: 'Consejos para tu primera partida',
    en: 'Tips for your first game',
    bodyEs: '• Describe lo que quieres hacer, no solo la regla: «salto sobre '
        'la mesa y ataco al orco».\n'
        '• Trabajad en equipo: Ayudar da ventaja a un aliado.\n'
        '• Si tienes dudas, pregunta al Master o mira el Libro.\n'
        '• Lo importante es pasarlo bien: el Master puede adaptar las reglas.',
    bodyEn: '• Describe what you want to do, not just the rule: "I leap onto '
        'the table and attack the orc".\n'
        '• Work as a team: Help gives an ally advantage.\n'
        '• When in doubt, ask the Master or check the Book.\n'
        '• Having fun is what matters: the Master can adapt the rules.',
  ),
];

/// Apartado «Manual» del Libro: capítulos del manual y de las acciones.
class ManualView extends StatelessWidget {
  const ManualView({super.key});

  void _open(BuildContext context, int start) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StepViewerScreen(
          title: bi('Manual para principiantes', 'Beginner\'s manual'),
          steps: kBeginnerManual,
          initial: start,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              color: scheme.primaryContainer,
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Icon(Icons.school_outlined,
                    size: 36, color: scheme.onPrimaryContainer),
                title: Text(
                  bi('Manual para principiantes', 'Beginner\'s manual'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                subtitle: Text(
                  bi('Lo básico para jugar a D&D, paso a paso.',
                      'The basics of playing D&D, step by step.'),
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
                trailing: FilledButton(
                  onPressed: () => _open(context, 0),
                  child: Text(bi('Empezar', 'Start')),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < kBeginnerManual.length; i++)
              Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(kBeginnerManual[i].title),
                  trailing: Icon(kBeginnerManual[i].icon),
                  onTap: () => _open(context, i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
