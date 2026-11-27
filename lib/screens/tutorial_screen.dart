import 'package:flutter/material.dart';

import '../widgets/demo_board.dart';
import '../widgets/rules_help.dart';
import '../widgets/step_viewer.dart';

/// Tutorial del editor de mapas.
const List<GuideStep> kMapEditorTutorial = [
  GuideStep(
    icon: Icons.map_outlined,
    es: 'Crear un mapa',
    en: 'Create a map',
    bodyEs: 'Ve a la pestaña Mapas y pulsa «Nuevo mapa». Ponle un nombre y '
        'elige el tamaño de la rejilla (columnas y filas). Cada casilla son '
        '5 pies.\n\nTambién puedes partir de uno de los mapas de ejemplo y '
        'modificarlo.',
    bodyEn: 'Go to the Maps tab and tap "New map". Give it a name and choose '
        'the grid size (columns and rows). Each square is 5 feet.\n\nYou can '
        'also start from one of the example maps and change it.',
    scene: DemoScene(cols: 10, rows: 6),
  ),
  GuideStep(
    icon: Icons.brush,
    es: 'Pintar el terreno',
    en: 'Paint the terrain',
    bodyEs: 'Elige un terreno en el pincel y toca o arrastra sobre las '
        'casillas. Los muros y el mobiliario bloquean el paso; el agua, el '
        'bosque o el barro son terreno difícil y cuestan el doble de '
        'movimiento.\n\nPara borrar, elige el suelo vacío y pinta encima.',
    bodyEn: 'Choose a terrain in the brush and tap or drag over the squares. '
        'Walls and furniture block movement; water, forest or mud are '
        'difficult terrain and cost double movement.\n\nTo erase, choose '
        'empty floor and paint over it.',
    scene: DemoScene(
      cols: 10,
      rows: 6,
      walls: {'0_0', '1_0', '2_0', '3_0', '4_0', '5_0', '6_0', '7_0', '8_0', '9_0', '0_1', '0_2', '0_3', '0_4', '0_5'},
      water: {'6_3', '7_3', '6_4', '7_4', '8_4'},
      brush: {'3_3', '4_3', '5_3'},
      finger: (5, 3),
    ),
  ),
  GuideStep(
    icon: Icons.stairs_outlined,
    es: 'Escenas, escaleras, portales y puertas',
    en: 'Scenes, stairs, portals and doors',
    bodyEs: 'Un mapa puede tener varias escenas: las alturas de una casa, '
        'las partes de una cueva o salas distintas. Cada escena tiene su '
        'propio tamaño (las columnas y filas cambian solo la escena que '
        'ves). Crea una con «Añadir escena».\n\n'
        'Pinta escaleras, teletransportadores o puertas y dales un número de '
        'conexión con el selector: las casillas con el mismo número están '
        'unidas, aunque estén en escenas distintas. Cuando una ficha llega a '
        'una de ellas, la app pregunta a cuál de las conectadas quiere ir. '
        'Una puerta sin número es una puerta normal.',
    bodyEn: 'A map can have several scenes: the floors of a house, the parts '
        'of a cave or separate rooms. Each scene has its own size (columns '
        'and rows only change the scene you are viewing). Create one with '
        '"Add scene".\n\n'
        'Paint stairs, teleporters or doors and give them a connection number '
        'with the selector: squares with the same number are linked, even in '
        'different scenes. When a token reaches one, the app asks which of '
        'the linked ones to go to. A door without a number is a normal door.',
    scene: DemoScene(
      cols: 10,
      rows: 6,
      walls: {'5_0', '5_1', '5_2', '5_4', '5_5'},
      stairs: {'8_1', '1_4'},
      chest: {'8_4'},
    ),
    tipEs: 'El cofre marca un tesoro: el Master decide qué hay dentro.',
    tipEn: 'The chest marks treasure: the Master decides what is inside.',
  ),
  GuideStep(
    icon: Icons.layers_outlined,
    es: 'Zonas ocultables',
    en: 'Hideable zones',
    bodyEs: 'Con los pinceles de zona (1 a 8) marcas habitaciones o áreas. '
        'En la partida, el Master decide quién ve cada zona: todos, nadie o '
        'algunos jugadores. Lo que un jugador no ve queda tapado por niebla.'
        '\n\nPara quitar una zona usa «Quitar zona».',
    bodyEn: 'With the zone brushes (1 to 8) you mark rooms or areas. In the '
        'game, the Master decides who sees each zone: everyone, no one or '
        'some players. What a player can\'t see is covered by fog.\n\nTo '
        'remove a zone use "Remove zone".',
    scene: DemoScene(
      cols: 10,
      rows: 6,
      walls: {'5_0', '5_1', '5_2', '5_4', '5_5'},
      zone: {'6_0', '7_0', '8_0', '9_0', '6_1', '7_1', '8_1', '9_1', '6_2', '7_2', '8_2', '9_2', '6_3', '7_3', '8_3', '9_3', '6_4', '7_4', '8_4', '9_4', '6_5', '7_5', '8_5', '9_5'},
    ),
  ),
  GuideStep(
    icon: Icons.save_outlined,
    es: 'Guardar y usar el mapa',
    en: 'Save and use the map',
    bodyEs: 'Pulsa Guardar. El mapa queda en tu lista y lo puedes elegir al '
        'crear una partida. Al usarlo se copia a la partida: si luego editas '
        'el mapa, las partidas que ya están en marcha no cambian.',
    bodyEn: 'Tap Save. The map stays in your list and you can choose it when '
        'creating a game. Using it copies it into the game: if you edit the '
        'map later, games already running don\'t change.',
  ),
];

/// Tutorial del Master.
const List<GuideStep> kMasterTutorial = [
  GuideStep(
    icon: Icons.castle_outlined,
    es: 'Crear la partida',
    en: 'Create the game',
    bodyEs: 'En Partidas pulsa «Crear partida», ponle un nombre y elige el '
        'mapa. Entrarás en la sala de espera.\n\nEl botón de la llave muestra '
        'el nombre de la sala y su código: compártelo con tus jugadores.',
    bodyEn: 'In Games tap "Create game", give it a name and choose the map. '
        'You\'ll enter the waiting room.\n\nThe key button shows the room '
        'name and its code: share it with your players.',
  ),
  GuideStep(
    icon: Icons.groups_outlined,
    es: 'Esperar a los jugadores',
    en: 'Wait for the players',
    bodyEs: 'Cada jugador entra con el código y elige su personaje. Los ves '
        'aparecer en la sala y puedes abrir su ficha. Cuando estéis todos, '
        'pulsa «Empezar».',
    bodyEn: 'Each player joins with the code and picks their character. You '
        'see them appear in the room and can open their sheet. When everyone '
        'is in, tap "Start".',
  ),
  GuideStep(
    icon: Icons.dashboard_outlined,
    es: 'La pantalla de juego',
    en: 'The game screen',
    bodyEs: 'El mapa ocupa toda la pantalla. A la izquierda están tus '
        'opciones de Master: Mapa (mover fichas, pintar, escenas y zonas), '
        'Jugadores, Criaturas y Objetos. A la derecha, lo general que también '
        'tienen los jugadores: Dados, Iniciativa, Libro y Chat.\n\nComo Master '
        'puedes tocar una ficha y luego una casilla para colocarla donde '
        'quieras.',
    bodyEn: 'The map fills the screen. On the left are your Master options: '
        'Map (move tokens, paint, scenes and zones), Players, Creatures and '
        'Items. On the right, the general tabs the players also have: Dice, '
        'Initiative, Book and Chat.\n\nAs Master you can tap a token and then '
        'a square to place it anywhere.',
    scene: DemoScene(
      cols: 10,
      rows: 6,
      walls: {'5_0', '5_1', '5_2'},
      tokens: [
        DemoToken(1, 2, Colors.indigo, 'A'),
        DemoToken(2, 4, Colors.teal, 'B'),
        DemoToken(8, 1, Colors.red, 'O'),
      ],
      finger: (8, 1),
    ),
  ),
  GuideStep(
    icon: Icons.pets_outlined,
    es: 'Añadir criaturas',
    en: 'Add creatures',
    bodyEs: 'En la pestaña Criaturas (panel izquierdo) añade monstruos del bestiario o '
        'criaturas tuyas. Aparecen ocultas: colócalas en el mapa y muéstralas '
        'cuando los jugadores las descubran.\n\nCuando una criatura llega a 0 '
        'PG se quita del mapa. Mientras esté en combate no se puede borrar.',
    bodyEn: 'In the Creatures tab (left panel) add monsters from the bestiary or your own '
        'creatures. They start hidden: place them on the map and reveal them '
        'when the players find them.\n\nWhen a creature drops to 0 HP it is '
        'removed from the map. While it is in combat it can\'t be deleted.',
  ),
  GuideStep(
    icon: Icons.visibility_off_outlined,
    es: 'Mostrar y ocultar zonas',
    en: 'Show and hide zones',
    bodyEs: 'Con el ojo junto a las escenas ocultas una escena entera a los '
        'jugadores hasta que la descubran. Si el mapa tiene zonas, en la pestaña Mapa del panel izquierdo decides '
        'quién ve cada una. Así revelas una habitación solo cuando los '
        'jugadores abren la puerta.',
    bodyEn: 'With the eye next to the scenes you hide a whole scene from the '
        'players until they find it. If the map has zones, in the Map tab of the left panel you choose who sees each '
        'one. That way you reveal a room only when the players open the '
        'door.',
    scene: DemoScene(
      cols: 10,
      rows: 6,
      walls: {'5_0', '5_1', '5_2', '5_4', '5_5'},
      tokens: [DemoToken(3, 3, Colors.indigo, 'A')],
      fog: {'6_0', '7_0', '8_0', '9_0', '6_1', '7_1', '8_1', '9_1', '6_2', '7_2', '8_2', '9_2', '6_3', '7_3', '8_3', '9_3', '6_4', '7_4', '8_4', '9_4', '6_5', '7_5', '8_5', '9_5'},
    ),
    tipEs: 'Así lo ve el jugador: la zona oculta está tapada.',
    tipEn: 'This is what the player sees: the hidden zone is covered.',
  ),
  GuideStep(
    icon: Icons.format_list_numbered,
    es: 'Llevar el combate',
    en: 'Run combat',
    bodyEs: 'En Iniciativa pulsa para preparar el combate y elige qué fichas '
        'entran. Cada jugador tira su iniciativa y tú la de las criaturas. '
        'Luego empiezan los turnos: quien tiene el turno lleva borde dorado y '
        'tú pasas al siguiente.\n\nEn combate el movimiento de cada jugador '
        'está limitado a su velocidad.',
    bodyEn: 'In Initiative tap to prepare combat and choose which tokens join. '
        'Each player rolls their initiative and you roll for the creatures. '
        'Then turns begin: whoever has the turn gets a gold border and you '
        'move on to the next.\n\nIn combat each player\'s movement is limited '
        'to their speed.',
    scene: DemoScene(
      cols: 9,
      rows: 5,
      tokens: [
        DemoToken(2, 2, Colors.indigo, 'A', turn: true),
        DemoToken(1, 3, Colors.teal, 'B'),
        DemoToken(6, 2, Colors.red, 'O'),
      ],
    ),
  ),
  GuideStep(
    icon: Icons.undo,
    es: 'Peticiones de los jugadores',
    en: 'Player requests',
    bodyEs: 'En combate, si un jugador quiere desmarcar una acción que ya '
        'había gastado, te llega un aviso arriba a la izquierda. Acéptalo (✓) '
        'si fue un error o recházalo (✗).',
    bodyEn: 'In combat, if a player wants to untick an action they had '
        'already used, you get a notice at the top left. Accept it (✓) if it '
        'was a mistake or reject it (✗).',
  ),
  GuideStep(
    icon: Icons.chat_outlined,
    es: 'El chat',
    en: 'The chat',
    bodyEs: 'En la pestaña Chat ves todos los mensajes, también los que los '
        'jugadores te mandan en privado. Puedes escribir a todos o a un solo '
        'jugador: útil para contarle algo que solo su personaje sabe.',
    bodyEn: 'In the Chat tab you see every message, including the ones '
        'players send you privately. You can write to everyone or to a single '
        'player: handy for telling them something only their character knows.',
  ),
  GuideStep(
    icon: Icons.exit_to_app,
    es: 'Terminar la sesión',
    en: 'End the session',
    bodyEs: 'Al salir, la app pide confirmación. Puedes volver a la sala más '
        'tarde desde Partidas y seguir donde lo dejasteis.',
    bodyEn: 'When you leave, the app asks for confirmation. You can return to '
        'the room later from Games and continue where you left off.',
  ),
];

/// Tutorial del jugador.
const List<GuideStep> kPlayerTutorial = [
  GuideStep(
    icon: Icons.person_add_alt,
    es: 'Crear tu personaje',
    en: 'Create your character',
    bodyEs: 'En Personajes pulsa «Nuevo personaje». Elige raza, clase y nivel, reparte '
        'las características y escoge tus habilidades (las marcadas con ★ son '
        'las que permite tu clase). La app añade el equipo inicial de tu '
        'clase.',
    bodyEn: 'In Characters tap "New character". Choose race, class and level, assign '
        'the ability scores and pick your skills (those marked ★ are allowed '
        'by your class). The app adds your class\'s starting equipment.',
  ),
  GuideStep(
    icon: Icons.key_outlined,
    es: 'Unirte a la partida',
    en: 'Join the game',
    bodyEs: 'Pide el código al Master. En Partidas pulsa «Unirse a partida», '
        'escribe el código y elige el personaje con el que vas a jugar. '
        'Esperarás en la sala hasta que el Master empiece.',
    bodyEn: 'Ask the Master for the code. In Games tap "Join game", type the '
        'code and choose the character you\'ll play. You\'ll wait in the room '
        'until the Master starts.',
  ),
  GuideStep(
    icon: Icons.touch_app_outlined,
    es: 'Moverte por el mapa',
    en: 'Move on the map',
    bodyEs: 'Toca tu ficha: se ilumina en verde hasta dónde puedes llegar. '
        'Luego traza tú el recorrido tocando casillas: cada toque añade un '
        'tramo recto hasta esa casilla, y tocar la anterior lo deshace. Así '
        'decides por dónde pasas (importa, por ejemplo, para no provocar '
        'ataques de oportunidad).\n\nPulsa «Mover» o toca otra vez la última '
        'casilla para confirmar. También puedes arrastrar desde tu ficha.',
    bodyEn: 'Tap your token: the squares you can reach light up green. Then '
        'trace the path yourself by tapping squares: each tap adds a straight '
        'leg to that square, and tapping the previous one undoes it. That way '
        'you choose where you pass (it matters, for example, to avoid '
        'opportunity attacks).\n\nTap "Move" or tap the last square again to '
        'confirm. You can also drag from your token.',
    scene: DemoScene(
      cols: 9,
      rows: 6,
      walls: {'4_1', '4_2', '4_3'},
      tokens: [DemoToken(1, 2, Colors.indigo, 'A', turn: true)],
      path: [(1, 2), (2, 3), (3, 4), (4, 4), (5, 3)],
      pathLabel: '20 / 30',
      finger: (5, 3),
    ),
  ),
  GuideStep(
    icon: Icons.directions_run,
    es: 'Movimiento en combate y correr',
    en: 'Movement in combat and dashing',
    bodyEs: 'En combate tienes un contador arriba a la izquierda con los pies '
        'que te quedan. Puedes moverte en varios tramos: si tu velocidad es '
        '30 pies y ya has hecho 15, el alcance verde solo llega a 15 más.\n\n'
        'Si eliges una casilla más lejos, la app te avisa de que vas a '
        'Correr. Al aceptar, se marca el movimiento y el contador te '
        'devuelve tu velocidad. Marca tú en Acciones si lo haces con la '
        'acción principal o con la adicional (si un rasgo te lo permite).',
    bodyEn: 'In combat you have a counter at the top left with the feet you '
        'have left. You can move in several legs: if your speed is 30 feet '
        'and you\'ve moved 15, the green area only reaches 15 more.\n\nIf you '
        'pick a square further away, the app warns you that you\'ll Dash. '
        'When you accept, movement is ticked and the counter gives you your '
        'speed again. Tick in Actions whether you did it with your action or '
        'a bonus action (if a feature allows it).',
    scene: DemoScene(
      cols: 9,
      rows: 5,
      tokens: [DemoToken(3, 2, Colors.indigo, 'A', turn: true)],
      reach: {'0_0', '1_0', '2_0', '3_0', '4_0', '5_0', '6_0', '0_1', '1_1', '2_1', '3_1', '4_1', '5_1', '6_1', '0_2', '1_2', '2_2', '4_2', '5_2', '6_2', '0_3', '1_3', '2_3', '3_3', '4_3', '5_3', '6_3', '0_4', '1_4', '2_4', '3_4', '4_4', '5_4', '6_4'},
      path: [(3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2)],
      pathLabel: '25 / 15',
      pathOver: true,
    ),
    tipEs: 'Naranja: el recorrido se pasa de lo que te queda y tendrás que '
        'correr.',
    tipEn: 'Orange: the path goes beyond what you have left and you\'ll have '
        'to dash.',
  ),
  GuideStep(
    icon: Icons.checklist,
    es: 'Tus acciones',
    en: 'Your actions',
    bodyEs: 'En el panel de la izquierda, la pestaña Acciones tiene las '
        'casillas de acción principal, adicional, movimiento y reacción. Se '
        'marcan solas al atacar, lanzar un conjuro o moverte; el resto lo '
        'marcas tú. El botón ⓘ '
        'explica qué hace cada una.\n\nEn combate, para desmarcar una acción '
        'tienes que pedírselo al Master.',
    bodyEn: 'In the left panel, the Actions tab has the action, bonus action, '
        'movement and reaction checkboxes. They tick themselves when you '
        'attack, cast a spell or move; you tick the rest. The ⓘ button explains each one.\n\nIn '
        'combat, to untick an action you have to ask the Master.',
  ),
  GuideStep(
    icon: Icons.gps_fixed,
    es: 'Atacar y lanzar conjuros',
    en: 'Attack and cast spells',
    bodyEs: 'En Armas eliges el arma equipada y pulsas atacar: la app tira el '
        'ataque y, si quieres, el daño (doble con un 20 natural). En Hechizos '
        'ves tus espacios de conjuro y lanzas cada conjuro con su tirada de '
        'ataque o salvación y su daño o curación.',
    bodyEn: 'In Weapons choose the equipped weapon and tap attack: the app '
        'rolls the attack and, if you want, the damage (double on a natural '
        '20). In Spells you see your spell slots and cast each spell with its '
        'attack or save and its damage or healing.',
  ),
  GuideStep(
    icon: Icons.place_outlined,
    es: 'Marcar casillas y tirar dados',
    en: 'Mark squares and roll dice',
    bodyEs: 'Mantén pulsada una casilla para marcarla: todos la ven durante 3 '
        'minutos. Úsalo para decir «voy ahí» o «cuidado aquí».\n\nEn la '
        'pestaña Dados de la derecha montas cualquier tirada y eliges si es '
        'normal, con ventaja o con desventaja.',
    bodyEn: 'Press and hold a square to mark it: everyone sees it for 3 '
        'minutes. Use it to say "I\'m going there" or "careful here".\n\nIn '
        'the Dice tab on the right you build any roll and choose normal, '
        'advantage or disadvantage.',
    scene: DemoScene(
      cols: 9,
      rows: 5,
      tokens: [DemoToken(2, 2, Colors.indigo, 'A'), DemoToken(3, 3, Colors.teal, 'B')],
      ping: (6, 1),
      finger: (6, 1),
    ),
  ),
  GuideStep(
    icon: Icons.chat_outlined,
    es: 'El chat',
    en: 'The chat',
    bodyEs: 'En la pestaña Chat del panel derecho escribes a todos o, '
        'eligiendo «Solo al Master», en privado. Los mensajes privados salen '
        'con un candado y nadie más los ve. Si llega un mensaje con el panel '
        'cerrado, verás un número en la pestaña.',
    bodyEn: 'In the Chat tab of the right panel you write to everyone or, '
        'choosing "Only to the Master", privately. Private messages show a '
        'padlock and nobody else sees them. If a message arrives while the '
        'panel is closed, you\'ll see a number on the tab.',
  ),
  GuideStep(
    icon: Icons.badge_outlined,
    es: 'Ver fichas',
    en: 'View sheets',
    bodyEs: 'Toca cualquier ficha del mapa: en la pestaña Ficha ves la de '
        'otro jugador (solo lectura) o la barra de vida de una criatura. '
        'Toca la tuya para volver a tu ficha.',
    bodyEn: 'Tap any token on the map: the Sheet tab shows another player\'s '
        'sheet (read only) or a creature\'s health bar. Tap yours to go back '
        'to your sheet.',
  ),
];

/// Ventana para elegir qué tutorial ver.
Future<void> showTutorialPicker(BuildContext context) {
  void open(String title, List<GuideStep> steps, Color color) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StepViewerScreen(title: title, steps: steps, color: color),
      ),
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              bi('Tutoriales', 'Tutorials'),
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
              child: Icon(Icons.map_outlined),
            ),
            title: Text(bi('Editor de mapas', 'Map editor')),
            subtitle: Text(bi('Pinta un mapa con escenas, escaleras y zonas.',
                'Paint a map with scenes, stairs and zones.')),
            onTap: () => open(bi('Tutorial: editor de mapas', 'Tutorial: map editor'),
                kMapEditorTutorial, Colors.brown),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              child: Icon(Icons.castle_outlined),
            ),
            title: Text(bi('Master', 'Master')),
            subtitle: Text(bi('Crea una partida y dirige la aventura.',
                'Create a game and run the adventure.')),
            onTap: () => open(bi('Tutorial: Master', 'Tutorial: Master'),
                kMasterTutorial, Colors.deepPurple),
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              child: Icon(Icons.person_outline),
            ),
            title: Text(bi('Jugador', 'Player')),
            subtitle: Text(bi('Únete, muévete, ataca y lanza conjuros.',
                'Join, move, attack and cast spells.')),
            onTap: () => open(bi('Tutorial: jugador', 'Tutorial: player'),
                kPlayerTutorial, Colors.teal),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Abre directamente el tutorial del Master o del jugador (desde la partida).
void openGameTutorial(BuildContext context, {required bool master}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => StepViewerScreen(
        title: master
            ? bi('Tutorial: Master', 'Tutorial: Master')
            : bi('Tutorial: jugador', 'Tutorial: player'),
        steps: master ? kMasterTutorial : kPlayerTutorial,
        color: master ? Colors.deepPurple : Colors.teal,
        initial: 2,
      ),
    ),
  );
}
