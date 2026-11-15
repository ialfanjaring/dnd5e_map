import '../models/character.dart';
import '../models/creature.dart';

/// Súbelo cuando añadas o corrijas criaturas predeterminadas: la app
/// cargará en la base de datos las que le falten a cada usuario.
const int kPresetsVersion = 1;

Creature _preset(
  String uid,
  String slug, {
  required String kind,
  required String name,
  required String size,
  required String type,
  required String alignment,
  required String cr,
  required int ac,
  required int hp,
  required String hitDice,
  required String speed,
  required List<int> abilities, // FUE, DES, CON, INT, SAB, CAR
  String skills = '',
  String senses = '',
  String languages = '',
  String traits = '',
  String actions = '',
}) {
  return Creature(
    id: '${uid}_srd_$slug',
    ownerUid: uid,
    kind: kind,
    name: name,
    size: size,
    creatureType: type,
    alignment: alignment,
    challengeRating: cr,
    armorClass: ac,
    maxHp: hp,
    hitDice: hitDice,
    speed: speed,
    abilities: {
      for (var i = 0; i < DndData.abilityKeys.length; i++)
        DndData.abilityKeys[i]: abilities[i],
    },
    skills: skills,
    senses: senses,
    languages: languages,
    traits: traits,
    actions: actions,
    isPreset: true,
  );
}

/// Bestiario básico basado en el SRD 5.1 (traducido).
List<Creature> buildPresetCreatures(String uid) {
  return [
    // ===================== MONSTRUOS =====================
    _preset(
      uid,
      'rata-gigante',
      kind: 'monster',
      name: 'Rata gigante',
      size: 'Pequeña',
      type: 'Bestia',
      alignment: 'Sin alineamiento',
      cr: '1/8',
      ac: 12,
      hp: 7,
      hitDice: '2d6',
      speed: '30 pies',
      abilities: [7, 15, 11, 2, 10, 4],
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 10',
      traits: 'Olfato agudo. Ventaja en las pruebas de Sabiduría '
          '(Percepción) que dependan del olfato.\n'
          'Táctica de manada. Ventaja en las tiradas de ataque contra una '
          'criatura si al menos un aliado de la rata está a 5 pies de ella '
          'y no está incapacitado.',
      actions: 'Mordisco. +4 al ataque, alcance 5 pies, un objetivo. '
          'Impacto: 1d4+2 de daño perforante.',
    ),
    _preset(
      uid,
      'kobold',
      kind: 'monster',
      name: 'Kobold',
      size: 'Pequeña',
      type: 'Humanoide (kobold)',
      alignment: 'Legal malvado',
      cr: '1/8',
      ac: 12,
      hp: 5,
      hitDice: '2d6-2',
      speed: '30 pies',
      abilities: [7, 15, 9, 8, 7, 8],
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 8',
      languages: 'Común, dracónico',
      traits: 'Sensibilidad a la luz solar. Desventaja en tiradas de ataque '
          'y en pruebas de Percepción basadas en la vista bajo luz solar.\n'
          'Táctica de manada. Ventaja en las tiradas de ataque si un aliado '
          'está a 5 pies del objetivo y no está incapacitado.',
      actions: 'Daga. +4 al ataque, alcance 5 pies. Impacto: 1d4+2 '
          'perforante.\n'
          'Honda. +4 al ataque, alcance 30/120 pies. Impacto: 1d4+2 '
          'contundente.',
    ),
    _preset(
      uid,
      'goblin',
      kind: 'monster',
      name: 'Goblin',
      size: 'Pequeña',
      type: 'Humanoide (goblinoide)',
      alignment: 'Neutral malvado',
      cr: '1/4',
      ac: 15,
      hp: 7,
      hitDice: '2d6',
      speed: '30 pies',
      abilities: [8, 14, 10, 10, 8, 8],
      skills: 'Sigilo +6',
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 9',
      languages: 'Común, goblin',
      traits: 'Huida ágil. El goblin puede realizar la acción de Destrabarse '
          'o Esconderse como acción adicional en cada uno de sus turnos.',
      actions: 'Cimitarra. +4 al ataque, alcance 5 pies. Impacto: 1d6+2 '
          'cortante.\n'
          'Arco corto. +4 al ataque, alcance 80/320 pies. Impacto: 1d6+2 '
          'perforante.',
    ),
    _preset(
      uid,
      'lobo',
      kind: 'monster',
      name: 'Lobo',
      size: 'Mediana',
      type: 'Bestia',
      alignment: 'Sin alineamiento',
      cr: '1/4',
      ac: 13,
      hp: 11,
      hitDice: '2d8+2',
      speed: '40 pies',
      abilities: [12, 15, 12, 3, 12, 6],
      skills: 'Percepción +3, Sigilo +4',
      senses: 'Percepción pasiva 13',
      traits: 'Oído y olfato agudos. Ventaja en las pruebas de Percepción '
          'que dependan del oído o el olfato.\n'
          'Táctica de manada. Ventaja en las tiradas de ataque si un aliado '
          'está a 5 pies del objetivo y no está incapacitado.',
      actions: 'Mordisco. +4 al ataque, alcance 5 pies. Impacto: 2d4+2 '
          'perforante. Si el objetivo es una criatura, debe superar una '
          'salvación de Fuerza CD 11 o quedar derribado.',
    ),
    _preset(
      uid,
      'esqueleto',
      kind: 'monster',
      name: 'Esqueleto',
      size: 'Mediana',
      type: 'No-muerto',
      alignment: 'Legal malvado',
      cr: '1/4',
      ac: 13,
      hp: 13,
      hitDice: '2d8+4',
      speed: '30 pies',
      abilities: [10, 14, 15, 6, 8, 5],
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 9',
      languages: 'Entiende los idiomas que conocía en vida, pero no habla',
      traits: 'Vulnerabilidad al daño contundente.\n'
          'Inmunidad al daño de veneno y a las condiciones de agotamiento '
          'y envenenado.',
      actions: 'Espada corta. +4 al ataque, alcance 5 pies. Impacto: 1d6+2 '
          'perforante.\n'
          'Arco corto. +4 al ataque, alcance 80/320 pies. Impacto: 1d6+2 '
          'perforante.',
    ),
    _preset(
      uid,
      'zombi',
      kind: 'monster',
      name: 'Zombi',
      size: 'Mediana',
      type: 'No-muerto',
      alignment: 'Neutral malvado',
      cr: '1/4',
      ac: 8,
      hp: 22,
      hitDice: '3d8+9',
      speed: '20 pies',
      abilities: [13, 6, 16, 3, 6, 5],
      skills: 'Salvación de Sabiduría +0',
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 8',
      languages: 'Entiende los idiomas que conocía en vida, pero no habla',
      traits: 'Inmunidad al daño de veneno y a la condición de envenenado.\n'
          'Fortaleza de no-muerto. Si el daño reduce al zombi a 0 PG, '
          'realiza una salvación de Constitución con CD 5 + el daño recibido '
          '(salvo daño radiante o crítico). Si tiene éxito, queda a 1 PG.',
      actions: 'Golpe. +3 al ataque, alcance 5 pies. Impacto: 1d6+1 '
          'contundente.',
    ),
    _preset(
      uid,
      'orco',
      kind: 'monster',
      name: 'Orco',
      size: 'Mediana',
      type: 'Humanoide (orco)',
      alignment: 'Caótico malvado',
      cr: '1/2',
      ac: 13,
      hp: 15,
      hitDice: '2d8+6',
      speed: '30 pies',
      abilities: [16, 12, 16, 7, 11, 10],
      skills: 'Intimidación +2',
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 10',
      languages: 'Común, orco',
      traits: 'Agresivo. Como acción adicional, puede moverse hasta su '
          'velocidad hacia una criatura hostil que pueda ver.',
      actions: 'Hacha a dos manos. +5 al ataque, alcance 5 pies. Impacto: '
          '1d12+3 cortante.\n'
          'Jabalina. +5 al ataque, alcance 5 pies o 30/120 pies. Impacto: '
          '1d6+3 perforante.',
    ),
    _preset(
      uid,
      'hobgoblin',
      kind: 'monster',
      name: 'Hobgoblin',
      size: 'Mediana',
      type: 'Humanoide (goblinoide)',
      alignment: 'Legal malvado',
      cr: '1/2',
      ac: 18,
      hp: 11,
      hitDice: '2d8+2',
      speed: '30 pies',
      abilities: [13, 12, 12, 10, 10, 9],
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 10',
      languages: 'Común, goblin',
      traits: 'Ventaja marcial. Una vez por turno, causa 2d6 de daño '
          'adicional a una criatura a la que impacte con un arma si un '
          'aliado suyo está a 5 pies de ella y no está incapacitado.',
      actions: 'Espada larga. +3 al ataque, alcance 5 pies. Impacto: 1d8+1 '
          'cortante (1d10+1 a dos manos).\n'
          'Arco largo. +3 al ataque, alcance 150/600 pies. Impacto: 1d8+1 '
          'perforante.',
    ),
    _preset(
      uid,
      'arana-gigante',
      kind: 'monster',
      name: 'Araña gigante',
      size: 'Grande',
      type: 'Bestia',
      alignment: 'Sin alineamiento',
      cr: '1',
      ac: 14,
      hp: 26,
      hitDice: '4d10+4',
      speed: '30 pies, trepar 30 pies',
      abilities: [14, 16, 12, 2, 11, 4],
      skills: 'Sigilo +7',
      senses: 'Vista ciega 10 pies, visión en la oscuridad 60 pies; '
          'Percepción pasiva 10',
      traits: 'Trepar como arácnido. Puede trepar por superficies difíciles, '
          'incluso boca abajo en techos, sin pruebas de característica.\n'
          'Sentido de la telaraña. Conoce la ubicación de cualquier '
          'criatura en contacto con su telaraña.\n'
          'Caminar por telarañas. Ignora las restricciones de movimiento '
          'causadas por telarañas.',
      actions: 'Mordisco. +5 al ataque, alcance 5 pies. Impacto: 1d8+3 '
          'perforante, y el objetivo hace una salvación de Constitución '
          'CD 11: 2d8 de daño de veneno si falla, la mitad si tiene éxito. '
          'Si el veneno lo reduce a 0 PG, queda estable pero envenenado y '
          'paralizado 1 hora.\n'
          'Telaraña (Recarga 5-6). Ataque a distancia +5, alcance 30/60 '
          'pies. Impacto: el objetivo queda inmovilizado (CD 12 de Fuerza '
          'para soltarse; la telaraña tiene CA 10 y 5 PG).',
    ),
    _preset(
      uid,
      'oso-pardo',
      kind: 'monster',
      name: 'Oso pardo',
      size: 'Grande',
      type: 'Bestia',
      alignment: 'Sin alineamiento',
      cr: '1',
      ac: 11,
      hp: 34,
      hitDice: '4d10+12',
      speed: '40 pies, trepar 30 pies',
      abilities: [19, 10, 16, 2, 13, 7],
      skills: 'Percepción +3',
      senses: 'Percepción pasiva 13',
      traits: 'Olfato agudo. Ventaja en las pruebas de Percepción que '
          'dependan del olfato.',
      actions: 'Ataque múltiple. Un mordisco y un ataque de garras.\n'
          'Mordisco. +6 al ataque, alcance 5 pies. Impacto: 1d8+4 '
          'perforante.\n'
          'Garras. +6 al ataque, alcance 5 pies. Impacto: 2d6+4 cortante.',
    ),
    _preset(
      uid,
      'ogro',
      kind: 'monster',
      name: 'Ogro',
      size: 'Grande',
      type: 'Gigante',
      alignment: 'Caótico malvado',
      cr: '2',
      ac: 11,
      hp: 59,
      hitDice: '7d10+21',
      speed: '40 pies',
      abilities: [19, 8, 16, 5, 7, 7],
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 8',
      languages: 'Común, gigante',
      actions: 'Garrote. +6 al ataque, alcance 5 pies. Impacto: 2d8+4 '
          'contundente.\n'
          'Jabalina. +6 al ataque, alcance 5 pies o 30/120 pies. Impacto: '
          '2d6+4 perforante.',
    ),
    _preset(
      uid,
      'buho-oso',
      kind: 'monster',
      name: 'Búho oso',
      size: 'Grande',
      type: 'Monstruosidad',
      alignment: 'Sin alineamiento',
      cr: '3',
      ac: 13,
      hp: 59,
      hitDice: '7d10+21',
      speed: '40 pies',
      abilities: [20, 12, 17, 3, 12, 7],
      skills: 'Percepción +3',
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 13',
      traits: 'Vista y olfato agudos. Ventaja en las pruebas de Percepción '
          'que dependan de la vista o el olfato.',
      actions: 'Ataque múltiple. Un ataque de pico y uno de garras.\n'
          'Pico. +7 al ataque, alcance 5 pies. Impacto: 1d10+5 perforante.\n'
          'Garras. +7 al ataque, alcance 5 pies. Impacto: 2d8+5 cortante.',
    ),
    _preset(
      uid,
      'trol',
      kind: 'monster',
      name: 'Trol',
      size: 'Grande',
      type: 'Gigante',
      alignment: 'Caótico malvado',
      cr: '5',
      ac: 15,
      hp: 84,
      hitDice: '8d10+40',
      speed: '30 pies',
      abilities: [18, 13, 20, 7, 9, 7],
      skills: 'Percepción +2',
      senses: 'Visión en la oscuridad 60 pies; Percepción pasiva 12',
      languages: 'Gigante',
      traits: 'Olfato agudo. Ventaja en las pruebas de Percepción que '
          'dependan del olfato.\n'
          'Regeneración. Recupera 10 PG al inicio de su turno. Si recibe '
          'daño de ácido o fuego, este rasgo no funciona en su siguiente '
          'turno. Solo muere si empieza su turno con 0 PG y no se regenera.',
      actions: 'Ataque múltiple. Un mordisco y dos ataques de garras.\n'
          'Mordisco. +7 al ataque, alcance 5 pies. Impacto: 1d6+4 '
          'perforante.\n'
          'Garras. +7 al ataque, alcance 5 pies. Impacto: 2d6+4 cortante.',
    ),
    _preset(
      uid,
      'dragon-rojo-joven',
      kind: 'monster',
      name: 'Dragón rojo joven',
      size: 'Grande',
      type: 'Dragón',
      alignment: 'Caótico malvado',
      cr: '10',
      ac: 18,
      hp: 178,
      hitDice: '17d10+85',
      speed: '40 pies, trepar 40 pies, volar 80 pies',
      abilities: [23, 10, 21, 14, 11, 19],
      skills: 'Salvaciones: DES +4, CON +9, SAB +4, CAR +8; '
          'Percepción +8, Sigilo +4',
      senses: 'Vista ciega 30 pies, visión en la oscuridad 120 pies; '
          'Percepción pasiva 18',
      languages: 'Común, dracónico',
      traits: 'Inmunidad al daño de fuego.',
      actions: 'Ataque múltiple. Un mordisco y dos ataques de garras.\n'
          'Mordisco. +10 al ataque, alcance 10 pies. Impacto: 2d10+6 '
          'perforante más 1d6 de fuego.\n'
          'Garras. +10 al ataque, alcance 5 pies. Impacto: 2d6+6 cortante.\n'
          'Aliento de fuego (Recarga 5-6). Cono de 30 pies. Salvación de '
          'Destreza CD 17: 16d6 de daño de fuego si falla, la mitad si '
          'tiene éxito.',
    ),

    // ========================= NPC =========================
    _preset(
      uid,
      'plebeyo',
      kind: 'npc',
      name: 'Plebeyo',
      size: 'Mediana',
      type: 'Humanoide',
      alignment: 'Cualquier alineamiento',
      cr: '0',
      ac: 10,
      hp: 4,
      hitDice: '1d8',
      speed: '30 pies',
      abilities: [10, 10, 10, 10, 10, 10],
      senses: 'Percepción pasiva 10',
      languages: 'Cualquier idioma (normalmente común)',
      actions: 'Garrote. +2 al ataque, alcance 5 pies. Impacto: 1d4 '
          'contundente.',
    ),
    _preset(
      uid,
      'guardia',
      kind: 'npc',
      name: 'Guardia',
      size: 'Mediana',
      type: 'Humanoide',
      alignment: 'Cualquier alineamiento',
      cr: '1/8',
      ac: 16,
      hp: 11,
      hitDice: '2d8+2',
      speed: '30 pies',
      abilities: [13, 12, 12, 10, 11, 10],
      skills: 'Percepción +2',
      senses: 'Percepción pasiva 12',
      languages: 'Cualquier idioma (normalmente común)',
      actions: 'Lanza. +3 al ataque, alcance 5 pies o 20/60 pies. Impacto: '
          '1d6+1 perforante, o 1d8+1 si se usa a dos manos en cuerpo a '
          'cuerpo.',
    ),
    _preset(
      uid,
      'bandido',
      kind: 'npc',
      name: 'Bandido',
      size: 'Mediana',
      type: 'Humanoide',
      alignment: 'Cualquiera no legal',
      cr: '1/8',
      ac: 12,
      hp: 11,
      hitDice: '2d8+2',
      speed: '30 pies',
      abilities: [11, 12, 12, 10, 10, 10],
      senses: 'Percepción pasiva 10',
      languages: 'Cualquier idioma (normalmente común)',
      actions: 'Cimitarra. +3 al ataque, alcance 5 pies. Impacto: 1d6+1 '
          'cortante.\n'
          'Ballesta ligera. +3 al ataque, alcance 80/320 pies. Impacto: '
          '1d8+1 perforante.',
    ),
    _preset(
      uid,
      'noble',
      kind: 'npc',
      name: 'Noble',
      size: 'Mediana',
      type: 'Humanoide',
      alignment: 'Cualquier alineamiento',
      cr: '1/8',
      ac: 15,
      hp: 9,
      hitDice: '2d8',
      speed: '30 pies',
      abilities: [11, 12, 11, 12, 14, 16],
      skills: 'Engaño +5, Perspicacia +4, Persuasión +5',
      senses: 'Percepción pasiva 12',
      languages: 'Dos idiomas cualesquiera',
      actions: 'Estoque. +3 al ataque, alcance 5 pies. Impacto: 1d8+1 '
          'perforante.\n'
          'Parada (reacción). Suma +2 a su CA contra un ataque cuerpo a '
          'cuerpo que le fuera a impactar. Debe ver al atacante y empuñar '
          'un arma cuerpo a cuerpo.',
    ),
    _preset(
      uid,
      'acolito',
      kind: 'npc',
      name: 'Acólito',
      size: 'Mediana',
      type: 'Humanoide',
      alignment: 'Cualquier alineamiento',
      cr: '1/4',
      ac: 10,
      hp: 9,
      hitDice: '2d8',
      speed: '30 pies',
      abilities: [10, 10, 10, 10, 14, 11],
      skills: 'Medicina +4, Religión +2',
      senses: 'Percepción pasiva 12',
      languages: 'Cualquier idioma (normalmente común)',
      traits: 'Lanzamiento de conjuros. Lanzador de nivel 1, característica '
          'de lanzamiento Sabiduría (CD 12, +4 al ataque con conjuros).\n'
          'Trucos: luz, llama sagrada, taumaturgia.\n'
          'Nivel 1 (3 espacios): bendecir, curar heridas, santuario.',
      actions: 'Garrote. +2 al ataque, alcance 5 pies. Impacto: 1d4 '
          'contundente.',
    ),
    _preset(
      uid,
      'veterano',
      kind: 'npc',
      name: 'Veterano',
      size: 'Mediana',
      type: 'Humanoide',
      alignment: 'Cualquier alineamiento',
      cr: '3',
      ac: 17,
      hp: 58,
      hitDice: '9d8+18',
      speed: '30 pies',
      abilities: [16, 13, 14, 10, 11, 10],
      skills: 'Atletismo +5, Percepción +2',
      senses: 'Percepción pasiva 12',
      languages: 'Cualquier idioma (normalmente común)',
      actions: 'Ataque múltiple. Dos ataques con la espada larga. Si '
          'empuña también una espada corta, un tercer ataque con ella.\n'
          'Espada larga. +5 al ataque, alcance 5 pies. Impacto: 1d8+3 '
          'cortante (1d10+3 a dos manos).\n'
          'Espada corta. +5 al ataque, alcance 5 pies. Impacto: 1d6+3 '
          'perforante.\n'
          'Ballesta ligera. +3 al ataque, alcance 80/320 pies. Impacto: '
          '1d8+1 perforante.',
    ),
  ];
}
