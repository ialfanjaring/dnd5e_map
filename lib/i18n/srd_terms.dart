import '../settings/app_settings.dart';

/// Términos cortos del SRD (competencias, idiomas, tamaños, etiquetas de
/// clase…) y textos fijos de las razas, en español. Son datos estáticos de la
/// app: no se traduce nada en línea.
///
/// Los textos largos de clases, subclases, rasgos y subrazas salen de
/// assets/data/srd_es.json (ver tool/build_srd.dart).

bool get _es => AppSettings.instance.lang == 'es';

const Map<String, String> _terms = {
  // Armaduras y escudos
  'light armor': 'Armadura ligera',
  'medium armor': 'Armadura media',
  'heavy armor': 'Armadura pesada',
  'all armor': 'Todas las armaduras',
  'shields': 'Escudos',
  // Armas
  'simple weapons': 'Armas sencillas',
  'martial weapons': 'Armas marciales',
  'daggers': 'Dagas',
  'darts': 'Dardos',
  'slings': 'Hondas',
  'quarterstaffs': 'Bastones',
  'light crossbows': 'Ballestas ligeras',
  'hand crossbows': 'Ballestas de mano',
  'longswords': 'Espadas largas',
  'shortswords': 'Espadas cortas',
  'rapiers': 'Estoques',
  'scimitars': 'Cimitarras',
  'clubs': 'Mazas',
  'maces': 'Mazas pesadas',
  'sickles': 'Hoces',
  'spears': 'Lanzas',
  'javelins': 'Jabalinas',
  'handaxes': 'Hachas de mano',
  'battleaxes': 'Hachas de batalla',
  'light hammers': 'Martillos ligeros',
  'warhammers': 'Martillos de guerra',
  'shortbows': 'Arcos cortos',
  'longbows': 'Arcos largos',
  'crossbows, hand': 'Ballestas de mano',
  'crossbows, light': 'Ballestas ligeras',
  // Herramientas
  "thieves' tools": 'Herramientas de ladrón',
  "smith's tools": 'Herramientas de herrero',
  "brewer's supplies": 'Suministros de cervecero',
  "mason's tools": 'Herramientas de albañil',
  "tinker's tools": 'Herramientas de manitas',
  "herbalism kit": 'Kit de herboristería',
  "navigator's tools": 'Herramientas de navegante',
  "poisoner's kit": 'Kit de envenenador',
  "disguise kit": 'Kit de disfraz',
  "forgery kit": 'Kit de falsificación',
  "alchemist's supplies": 'Suministros de alquimista',
  "carpenter's tools": 'Herramientas de carpintero',
  "cobbler's tools": 'Herramientas de zapatero',
  "cook's utensils": 'Utensilios de cocinero',
  "glassblower's tools": 'Herramientas de soplador de vidrio',
  "jeweler's tools": 'Herramientas de joyero',
  "leatherworker's tools": 'Herramientas de peletero',
  "painter's supplies": 'Suministros de pintor',
  "potter's tools": 'Herramientas de alfarero',
  "weaver's tools": 'Herramientas de tejedor',
  "woodcarver's tools": 'Herramientas de tallista',
  "calligrapher's supplies": 'Suministros de calígrafo',
  "cartographer's tools": 'Herramientas de cartógrafo',
  'land vehicles': 'Vehículos terrestres',
  'water vehicles': 'Vehículos acuáticos',
  'dice set': 'Juego de dados',
  'playing card set': 'Juego de cartas',
  'musical instrument': 'Instrumento musical',
  'bagpipes': 'Gaita',
  'drum': 'Tambor',
  'dulcimer': 'Dulcémele',
  'flute': 'Flauta',
  'lute': 'Laúd',
  'lyre': 'Lira',
  'horn': 'Cuerno',
  'pan flute': 'Flauta de pan',
  'shawm': 'Chirimía',
  'viol': 'Viola',
  // Idiomas
  'common': 'Común',
  'dwarvish': 'Enano',
  'elvish': 'Élfico',
  'giant': 'Gigante',
  'gnomish': 'Gnomo',
  'goblin': 'Goblin',
  'halfling': 'Mediano',
  'orc': 'Orco',
  'abyssal': 'Abisal',
  'celestial': 'Celestial',
  'draconic': 'Dracónico',
  'deep speech': 'Habla profunda',
  'infernal': 'Infernal',
  'primordial': 'Primordial',
  'sylvan': 'Silvano',
  'undercommon': 'Infracomún',
  // Tamaños
  'tiny': 'Diminuto',
  'small': 'Pequeño',
  'medium': 'Mediano',
  'large': 'Grande',
  'huge': 'Enorme',
  'gargantuan': 'Gargantuesco',
  // Habilidades
  'acrobatics': 'Acrobacias',
  'animal handling': 'Trato con animales',
  'arcana': 'Arcanos',
  'athletics': 'Atletismo',
  'deception': 'Engaño',
  'history': 'Historia',
  'insight': 'Perspicacia',
  'intimidation': 'Intimidación',
  'investigation': 'Investigación',
  'medicine': 'Medicina',
  'nature': 'Naturaleza',
  'perception': 'Percepción',
  'performance': 'Interpretación',
  'persuasion': 'Persuasión',
  'religion': 'Religión',
  'sleight of hand': 'Juego de manos',
  'stealth': 'Sigilo',
  'survival': 'Supervivencia',
  // Características
  'str': 'FUE',
  'dex': 'DES',
  'con': 'CON',
  'int': 'INT',
  'wis': 'SAB',
  'cha': 'CAR',
  'strength': 'Fuerza',
  'dexterity': 'Destreza',
  'constitution': 'Constitución',
  'intelligence': 'Inteligencia',
  'wisdom': 'Sabiduría',
  'charisma': 'Carisma',
};

/// Traduce un término corto del SRD (competencia, idioma, tamaño…).
/// Devuelve el original si la app no está en español o no se conoce.
String srdTerm(String en) {
  if (!_es || en.isEmpty) return en;
  final t = en.trim();
  final low = t.toLowerCase();

  final direct = _terms[low];
  if (direct != null) return direct;

  // «Skill: Athletics», «Saving Throw: STR»
  final m = RegExp(r'^(skill|saving throw)\s*:\s*(.+)$', caseSensitive: false)
      .firstMatch(t);
  if (m != null) {
    final kind = m[1]!.toLowerCase() == 'skill'
        ? 'Habilidad'
        : 'Tirada de salvación';
    final rest = m[2]!.trim();
    return '$kind: ${_terms[rest.toLowerCase()] ?? rest}';
  }

  // «Herbalism Kit» sin apóstrofo, etc.: prueba sin mayúsculas ni apóstrofos
  final plain = low.replaceAll("'", '');
  for (final e in _terms.entries) {
    if (e.key.replaceAll("'", '') == plain) return e.value;
  }
  return t;
}

/// Traduce una lista de términos.
List<String> srdTerms(List<String> l) => [for (final e in l) srdTerm(e)];

const Map<String, String> _classSpecific = {
  'rage_count': 'Furias',
  'rage_damage_bonus': 'Bonificador de daño de furia',
  'brutal_critical_dice': 'Dados de crítico brutal',
  'bardic_inspiration_die': 'Dado de inspiración bárdica',
  'song_of_rest_die': 'Dado de canción de descanso',
  'magical_secrets_max_5': 'Secretos mágicos (hasta nivel 5)',
  'magical_secrets_max_7': 'Secretos mágicos (hasta nivel 7)',
  'magical_secrets_max_9': 'Secretos mágicos (hasta nivel 9)',
  'channel_divinity_charges': 'Usos de Canalizar divinidad',
  'destroy_undead_cr': 'VD máximo de Destruir muertos vivientes',
  'wild_shape_max_cr': 'VD máximo de Forma salvaje',
  'wild_shape_swim': 'Forma salvaje: nadar',
  'wild_shape_fly': 'Forma salvaje: volar',
  'action_surges': 'Oleadas de acción',
  'indomitable_uses': 'Usos de Indomable',
  'extra_attacks': 'Ataques adicionales',
  'martial_arts': 'Dado de artes marciales',
  'ki_points': 'Puntos de ki',
  'unarmored_movement': 'Movimiento sin armadura',
  'aura_range': 'Radio de aura',
  'favored_enemies': 'Enemigos predilectos',
  'favored_terrain': 'Terrenos predilectos',
  'sneak_attack': 'Ataque furtivo',
  'sorcery_points': 'Puntos de hechicería',
  'metamagic_known': 'Opciones de metamagia',
  'invocations_known': 'Invocaciones conocidas',
  'arcane_recovery_levels': 'Recuperación arcana (niveles)',
  'mystic_arcanum_level_6': 'Arcanum místico (nivel 6)',
  'mystic_arcanum_level_7': 'Arcanum místico (nivel 7)',
  'mystic_arcanum_level_8': 'Arcanum místico (nivel 8)',
  'mystic_arcanum_level_9': 'Arcanum místico (nivel 9)',
};

/// Etiqueta de un dato propio de clase (clave snake_case de la API).
String classSpecificLabel(String key) {
  if (_es) {
    final t = _classSpecific[key];
    if (t != null) return t;
  }
  final t = key.replaceAll('_', ' ');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}

/// Textos fijos de las razas del SRD (edad, alineamiento, tamaño, idiomas).
/// null si la app no está en español o la raza no está aquí.
String? raceText(String raceIndex, String field) {
  if (!_es) return null;
  return _raceTexts[raceIndex]?[field];
}

/// Descripción de una subraza del SRD (null si no está o no es español).
String? subraceText(String subraceIndex) =>
    _es ? _subraceTexts[subraceIndex] : null;

const Map<String, String> _subraceTexts = {
  'hill-dwarf':
      'Como enano de las colinas, tienes sentidos agudos, una intuición profunda y una resistencia notable.',
  'high-elf':
      'Como alto elfo, tienes una mente aguda y un dominio de, al menos, lo básico de la magia. En muchos mundos de fantasía hay dos clases de altos elfos. Una es altiva y reservada, y se cree superior a los no elfos e incluso a otros elfos. La otra es más común y más amistosa, y suele tratar con humanos y otras razas.',
  'lightfoot-halfling':
      'Como mediano piesligeros, puedes esconderte con facilidad, incluso usando a otras personas como cobertura. Tiendes a ser afable y a llevarte bien con los demás. Los piesligeros son más propensos a la inquietud viajera que otros medianos y a menudo viven junto a otras razas o llevan una vida nómada.',
  'rock-gnome':
      'Como gnomo de las rocas, tienes una inventiva natural y una robustez superiores a las de otros gnomos.',
};

const Map<String, Map<String, String>> _raceTexts = {
  'dwarf': {
    'age':
        'Los enanos maduran al mismo ritmo que los humanos, pero se los considera jóvenes hasta que cumplen 50 años. De media viven unos 350 años.',
    'alignment':
        'La mayoría de los enanos son legales, pues creen firmemente en los beneficios de una sociedad bien ordenada. También tienden al bien, con un fuerte sentido del juego limpio y la convicción de que todos merecen compartir los beneficios de un orden justo.',
    'size_description':
        'Los enanos miden entre 4 y 5 pies de altura y pesan una media de 150 libras. Tu tamaño es Mediano.',
    'language_desc':
        'Puedes hablar, leer y escribir Común y Enano. El enano está lleno de consonantes duras y sonidos guturales, y esas características se trasladan a cualquier otro idioma que hable un enano.',
  },
  'elf': {
    'age':
        'Aunque los elfos alcanzan la madurez física a una edad parecida a la de los humanos, su idea de la edad adulta va más allá del crecimiento físico e incluye la experiencia del mundo. Un elfo suele considerarse adulto y adoptar un nombre de adulto hacia los 100 años, y puede vivir hasta los 750.',
    'alignment':
        'Los elfos aman la libertad, la variedad y la expresión personal, por lo que se inclinan con fuerza hacia los aspectos más suaves del caos. Valoran y protegen la libertad de los demás tanto como la suya, y son más a menudo buenos que no. Los drow son una excepción: su exilio al Underdark los ha vuelto crueles y peligrosos, y suelen ser malvados.',
    'size_description':
        'Los elfos miden entre menos de 5 y más de 6 pies de altura y tienen una constitución esbelta. Tu tamaño es Mediano.',
    'language_desc':
        'Puedes hablar, leer y escribir Común y Élfico. El élfico es fluido, con entonaciones sutiles y una gramática intrincada. La literatura élfica es rica y variada, y sus canciones y poemas son famosos entre otras razas. Muchos bardos aprenden su idioma para añadir baladas élficas a su repertorio.',
  },
  'halfling': {
    'age':
        'Un mediano alcanza la edad adulta a los 20 años y por lo general vive hasta mediados de su segundo siglo.',
    'alignment':
        'La mayoría de los medianos son legales buenos. Por norma son bondadosos y amables, odian ver sufrir a otros y no toleran la opresión. También son muy ordenados y tradicionales, y se apoyan mucho en su comunidad y en la comodidad de sus viejas costumbres.',
    'size_description':
        'Los medianos miden de media unos 3 pies de altura y pesan unas 40 libras. Tu tamaño es Pequeño.',
    'language_desc':
        'Puedes hablar, leer y escribir Común y Mediano. El idioma mediano no es secreto, pero a los medianos no les gusta compartirlo con otros. Escriben muy poco, así que no tienen una literatura extensa, pero su tradición oral es muy fuerte. Casi todos los medianos hablan Común para conversar con la gente de las tierras en las que viven o por las que viajan.',
  },
  'human': {
    'age':
        'Los humanos alcanzan la edad adulta a finales de la adolescencia y viven menos de un siglo.',
    'alignment':
        'Los humanos no tienden a ningún alineamiento concreto. Entre ellos se encuentran los mejores y los peores.',
    'size_description':
        'Los humanos varían mucho en altura y complexión, desde apenas 5 pies hasta bastante más de 6. Estés donde estés dentro de ese rango, tu tamaño es Mediano.',
    'language_desc':
        'Puedes hablar, leer y escribir Común y un idioma adicional a tu elección. Los humanos suelen aprender los idiomas de otros pueblos con los que tratan, incluidos dialectos poco conocidos. Les gusta salpicar su habla de palabras prestadas: maldiciones orcas, expresiones musicales élficas, frases militares enanas y similares.',
  },
  'dragonborn': {
    'age':
        'Los dracónidos jóvenes crecen rápido. Caminan a las pocas horas de nacer, alcanzan el tamaño y el desarrollo de un niño humano de 10 años a los 3 y llegan a la edad adulta a los 15. Viven alrededor de 80 años.',
    'alignment':
        'Los dracónidos tienden a los extremos y toman una decisión consciente por un bando u otro en la guerra cósmica entre el bien y el mal (representados por Bahamut y Tiamat, respectivamente). La mayoría son buenos, pero los que se alían con Tiamat pueden ser villanos terribles.',
    'size_description':
        'Los dracónidos son más altos y pesados que los humanos: miden bastante más de 6 pies y pesan casi 250 libras de media. Tu tamaño es Mediano.',
    'language_desc':
        'Puedes hablar, leer y escribir Común y Dracónico. Se cree que el dracónico es uno de los idiomas más antiguos y se usa a menudo en el estudio de la magia. A la mayoría de las criaturas les suena áspero y tiene muchas consonantes duras y sibilantes.',
  },
  'gnome': {
    'age':
        'Los gnomos maduran al mismo ritmo que los humanos y se espera que la mayoría sienten la cabeza y lleven una vida adulta hacia los 40 años. Pueden vivir entre 350 y casi 500 años.',
    'alignment':
        'Los gnomos suelen ser buenos. Los que tienden a la ley son sabios, ingenieros, investigadores, eruditos o inventores. Los que tienden al caos son juglares, bromistas, vagabundos o joyeros fantasiosos. Los gnomos son de buen corazón, e incluso los bromistas son más juguetones que crueles.',
    'size_description':
        'Los gnomos miden entre 3 y 4 pies de altura y pesan de media unas 40 libras. Tu tamaño es Pequeño.',
    'language_desc':
        'Puedes hablar, leer y escribir Común y Gnomo. El gnomo, que usa la escritura enana, es famoso por sus tratados técnicos y sus catálogos de conocimientos sobre el mundo natural.',
  },
  'half-elf': {
    'age':
        'Los semielfos maduran al mismo ritmo que los humanos y alcanzan la edad adulta hacia los 20 años. Sin embargo, viven mucho más que los humanos, a menudo más de 180 años.',
    'alignment':
        'Los semielfos comparten la inclinación caótica de su herencia élfica. Valoran tanto la libertad personal como la expresión creativa, y no muestran ni amor por los líderes ni deseo de tener seguidores. Se sienten incómodos con las reglas, se resienten de las exigencias ajenas y a veces resultan poco fiables, o al menos impredecibles.',
    'size_description':
        'Los semielfos tienen un tamaño parecido al de los humanos, entre 5 y 6 pies de altura. Tu tamaño es Mediano.',
    'language_desc':
        'Puedes hablar, leer y escribir Común, Élfico y un idioma adicional a tu elección.',
  },
  'half-orc': {
    'age':
        'Los semiorcos maduran algo más rápido que los humanos y alcanzan la edad adulta hacia los 14 años. Envejecen notablemente más deprisa y rara vez viven más de 75 años.',
    'alignment':
        'Los semiorcos heredan de sus padres orcos una tendencia al caos y no se inclinan con fuerza hacia el bien. Los que se crían entre orcos y están dispuestos a vivir entre ellos suelen ser malvados.',
    'size_description':
        'Los semiorcos son algo más grandes y corpulentos que los humanos, y miden entre 5 y bastante más de 6 pies de altura. Tu tamaño es Mediano.',
    'language_desc':
        'Puedes hablar, leer y escribir Común y Orco. El orco es un idioma áspero y chirriante, con consonantes duras. No tiene escritura propia, pero se escribe con la escritura enana.',
  },
  'tiefling': {
    'age':
        'Los tieflings maduran al mismo ritmo que los humanos, pero viven unos años más.',
    'alignment':
        'Puede que los tieflings no tengan una tendencia innata hacia el mal, pero muchos acaban en él. Sean malvados o no, su carácter independiente inclina a muchos hacia un alineamiento caótico.',
    'size_description':
        'Los tieflings tienen un tamaño y una complexión parecidos a los de los humanos. Tu tamaño es Mediano.',
    'language_desc': 'Puedes hablar, leer y escribir Común e Infernal.',
  },
};

// ---------------------------------------------------------------------------
// Cuadro «Lanzamiento de conjuros» de cada clase lanzadora (SRD 5.1)
// ---------------------------------------------------------------------------

const Map<String, String> _castingNames = {
  'cantrips': 'Trucos',
  'spell slots': 'Espacios de conjuro',
  'spells known of 1st level and higher':
      'Hechizos conocidos de nivel 1 y superior',
  'spellcasting ability': 'Característica para lanzar conjuros',
  'ritual casting': 'Lanzamiento ritual',
  'spellcasting focus': 'Foco de lanzamiento',
  'preparing and casting spells': 'Preparar y lanzar hechizos',
  'spellbook': 'Libro de conjuros',
  'learning spells of 1st level and higher':
      'Aprender hechizos de nivel 1 y superior',
};

String _cDc(String ab) =>
    'CD de salvación de hechizos = 8 + tu bonificador de competencia + tu modificador de $ab\n\n'
    'Modificador de ataque de hechizos = tu bonificador de competencia + tu modificador de $ab';

String _cCantrips(String intro, String cls, String table) =>
    '$intro de tu elección de la lista de hechizos de $cls. Aprendes trucos de $cls adicionales de tu elección en niveles superiores, como se muestra en la columna Trucos conocidos de la tabla del $table.';

String _cSlots(String cls, String table, String example) =>
    'La tabla del $table muestra cuántos espacios de conjuro tienes para lanzar tus hechizos de nivel 1 y superior. Para lanzar uno de estos hechizos de $cls, debes gastar un espacio del nivel del hechizo o superior. Recuperas todos los espacios de conjuro gastados cuando terminas un descanso largo.\n\n'
    'Por ejemplo, si conoces el hechizo de nivel 1 $example y tienes un espacio de nivel 1 y otro de nivel 2 disponibles, puedes lanzarlo usando cualquiera de los dos.';

String _cReplace(String cls) =>
    'Además, cuando subes de nivel de $cls, puedes elegir uno de los hechizos de $cls que conoces y sustituirlo por otro hechizo de la lista de hechizos de $cls, que también debe ser de un nivel para el que tengas espacios de conjuro.';

String _cPrepared(String cls, String table, String count, String ex, String how) =>
    'La tabla del $table muestra cuántos espacios de conjuro tienes para lanzar tus hechizos de nivel 1 y superior. Para lanzar uno de estos hechizos de $cls, debes gastar un espacio del nivel del hechizo o superior. Recuperas todos los espacios de conjuro gastados cuando terminas un descanso largo.\n\n'
    'Preparas la lista de hechizos de $cls que tienes disponibles para lanzar, $count (mínimo un hechizo). Los hechizos deben ser de un nivel para el que tengas espacios de conjuro.\n\n'
    '$ex\n\n'
    'Puedes cambiar tu lista de hechizos preparados cuando terminas un descanso largo. $how';

final Map<String, Map<String, String>> _castingTexts = {
  'bard': {
    'cantrips': _cCantrips('Conoces dos trucos', 'bardo', 'Bardo'),
    'spell slots': _cSlots('bardo', 'Bardo', '«curar heridas»'),
    'spells known of 1st level and higher':
        'Conoces cuatro hechizos de bardo de tu elección de la lista de hechizos de bardo.\n\n'
        'La columna Hechizos conocidos de la tabla del Bardo muestra cuándo aprendes más hechizos de bardo de tu elección. Cada uno de estos hechizos debe ser de un nivel para el que tengas espacios de conjuro, como se muestra en la tabla. Por ejemplo, cuando alcanzas el nivel 3 de bardo, puedes aprender un nuevo hechizo de nivel 1 o 2.\n\n'
            '${_cReplace('bardo')}',
    'spellcasting ability':
        'Carisma es tu característica para lanzar conjuros de bardo. Tu magia surge del corazón y el alma que viertes en tu interpretación. Usas tu Carisma siempre que un hechizo se refiera a tu característica para lanzar conjuros. Además, usas tu modificador de Carisma al establecer la CD de la tirada de salvación de un hechizo de bardo que lances y al hacer una tirada de ataque con uno.\n\n${_cDc('Carisma')}',
    'ritual casting':
        'Puedes lanzar cualquier hechizo de bardo que conozcas como ritual si ese hechizo tiene el descriptor de ritual.',
    'spellcasting focus':
        'Puedes usar un instrumento musical (ver el capítulo de equipo) como foco de lanzamiento de tus hechizos de bardo.',
  },
  'cleric': {
    'cantrips': _cCantrips('Al nivel 1, conoces tres trucos', 'clérigo', 'Clérigo'),
    'preparing and casting spells': _cPrepared(
      'clérigo',
      'Clérigo',
      'eligiendo de la lista de hechizos de clérigo. Al hacerlo, elige un número de hechizos de clérigo igual a tu modificador de Sabiduría + tu nivel de clérigo',
      'Por ejemplo, si eres un clérigo de nivel 3, tienes cuatro espacios de nivel 1 y dos de nivel 2. Con una Sabiduría de 16, tu lista de hechizos preparados puede incluir seis hechizos de nivel 1 o 2, en cualquier combinación. Si preparas el hechizo de nivel 1 «curar heridas», puedes lanzarlo usando un espacio de nivel 1 o de nivel 2. Lanzar el hechizo no lo elimina de tu lista de hechizos preparados.',
      'Preparar una nueva lista de hechizos de clérigo requiere tiempo dedicado a la oración y la meditación: al menos 1 minuto por nivel de hechizo por cada hechizo de tu lista.',
    ),
    'spellcasting ability':
        'Sabiduría es tu característica para lanzar conjuros de clérigo. El poder de tus hechizos proviene de tu devoción a tu deidad. Usas tu Sabiduría siempre que un hechizo de clérigo se refiera a tu característica para lanzar conjuros. Además, usas tu modificador de Sabiduría al establecer la CD de la tirada de salvación de un hechizo de clérigo que lances y al hacer una tirada de ataque con uno.\n\n${_cDc('Sabiduría')}',
    'ritual casting':
        'Puedes lanzar un hechizo de clérigo como ritual si ese hechizo tiene el descriptor de ritual y lo tienes preparado.',
    'spellcasting focus':
        'Puedes usar un símbolo sagrado (ver el capítulo de equipo) como foco de lanzamiento de tus hechizos de clérigo.',
  },
  'druid': {
    'cantrips': _cCantrips('Al nivel 1, conoces dos trucos', 'druida', 'Druida'),
    'preparing and casting spells': _cPrepared(
      'druida',
      'Druida',
      'eligiendo de la lista de hechizos de druida. Al hacerlo, elige un número de hechizos de druida igual a tu modificador de Sabiduría + tu nivel de druida',
      'Por ejemplo, si eres un druida de nivel 3, tienes cuatro espacios de nivel 1 y dos de nivel 2. Con una Sabiduría de 16, tu lista de hechizos preparados puede incluir seis hechizos de nivel 1 o 2, en cualquier combinación. Si preparas el hechizo de nivel 1 «curar heridas», puedes lanzarlo usando un espacio de nivel 1 o de nivel 2. Lanzar el hechizo no lo elimina de tu lista de hechizos preparados.',
      'Preparar una nueva lista de hechizos de druida requiere tiempo dedicado a la oración y la meditación: al menos 1 minuto por nivel de hechizo por cada hechizo de tu lista.',
    ),
    'spellcasting ability':
        'Sabiduría es tu característica para lanzar conjuros de druida, ya que tu magia se basa en tu devoción y sintonía con la naturaleza. Usas tu Sabiduría siempre que un hechizo de druida se refiera a tu característica para lanzar conjuros. Además, usas tu modificador de Sabiduría al establecer la CD de la tirada de salvación de un hechizo de druida que lances y al hacer una tirada de ataque con uno.\n\n${_cDc('Sabiduría')}',
    'ritual casting':
        'Puedes lanzar un hechizo de druida como ritual si ese hechizo tiene el descriptor de ritual y lo tienes preparado.',
    'spellcasting focus':
        'Puedes usar un foco druídico (ver el capítulo de equipo) como foco de lanzamiento de tus hechizos de druida.',
  },
  'paladin': {
    'preparing and casting spells': _cPrepared(
      'paladín',
      'Paladín',
      'eligiendo de la lista de hechizos de paladín. Al hacerlo, elige un número de hechizos de paladín igual a tu modificador de Carisma + la mitad de tu nivel de paladín, redondeando hacia abajo',
      'Por ejemplo, si eres un paladín de nivel 5, tienes cuatro espacios de nivel 1 y dos de nivel 2. Con un Carisma de 14, tu lista de hechizos preparados puede incluir cuatro hechizos de nivel 1 o 2, en cualquier combinación. Si preparas el hechizo de nivel 1 «curar heridas», puedes lanzarlo usando un espacio de nivel 1 o de nivel 2. Lanzar el hechizo no lo elimina de tu lista de hechizos preparados.',
      'Preparar una nueva lista de hechizos de paladín requiere tiempo dedicado a la oración y la meditación: al menos 1 minuto por nivel de hechizo por cada hechizo de tu lista.',
    ),
    'spellcasting ability':
        'Carisma es tu característica para lanzar conjuros de paladín, ya que su poder proviene de la fuerza de tus convicciones. Usas tu Carisma siempre que un hechizo se refiera a tu característica para lanzar conjuros. Además, usas tu modificador de Carisma al establecer la CD de la tirada de salvación de un hechizo de paladín que lances y al hacer una tirada de ataque con uno.\n\n${_cDc('Carisma')}',
    'spellcasting focus':
        'Puedes usar un símbolo sagrado (ver el capítulo de equipo) como foco de lanzamiento de tus hechizos de paladín.',
  },
  'ranger': {
    'spell slots': _cSlots('explorador', 'Explorador', '«amistad con los animales»'),
    'spells known of 1st level and higher':
        'Conoces dos hechizos de explorador de tu elección de la lista de hechizos de explorador.\n\n'
        'La columna Hechizos conocidos de la tabla del Explorador muestra cuándo aprendes más hechizos de explorador de tu elección. Cada uno de estos hechizos debe ser de un nivel para el que tengas espacios de conjuro. Por ejemplo, cuando alcanzas el nivel 5 de explorador, puedes aprender un nuevo hechizo de nivel 1 o 2.\n\n'
            '${_cReplace('explorador')}',
    'spellcasting ability':
        'Sabiduría es tu característica para lanzar conjuros de explorador, ya que tu magia se basa en tu sintonía con la naturaleza. Usas tu Sabiduría siempre que un hechizo se refiera a tu característica para lanzar conjuros. Además, usas tu modificador de Sabiduría al establecer la CD de la tirada de salvación de un hechizo de explorador que lances y al hacer una tirada de ataque con uno.\n\n${_cDc('Sabiduría')}',
  },
  'sorcerer': {
    'cantrips': _cCantrips('Al nivel 1, conoces cuatro trucos', 'hechicero', 'Hechicero'),
    'spell slots': _cSlots('hechicero', 'Hechicero', '«manos ardientes»'),
    'spells known of 1st level and higher':
        'Al nivel 1, conoces dos hechizos de nivel 1 de tu elección de la lista de hechizos de hechicero.\n\n'
        'La columna Hechizos conocidos de la tabla del Hechicero muestra cuándo aprendes más hechizos de hechicero de tu elección. Cada uno de estos hechizos debe ser de un nivel para el que tengas espacios de conjuro, como se muestra en la tabla. Por ejemplo, cuando alcanzas el nivel 3 de hechicero, puedes aprender un nuevo hechizo de nivel 1 o 2.\n\n'
            '${_cReplace('hechicero')}',
    'spellcasting ability':
        'Carisma es tu característica para lanzar conjuros de hechicero, ya que el poder de tu magia depende de tu capacidad para proyectar tu voluntad en el mundo. Usas tu Carisma siempre que un hechizo se refiera a tu característica para lanzar conjuros. Además, usas tu modificador de Carisma al establecer la CD de la tirada de salvación de un hechizo de hechicero que lances y al hacer una tirada de ataque con uno.\n\n${_cDc('Carisma')}',
    'spellcasting focus':
        'Puedes usar un foco arcano (ver el capítulo de equipo) como foco de lanzamiento de tus hechizos de hechicero.',
  },
  'warlock': {
    'cantrips': _cCantrips('Conoces dos trucos', 'brujo', 'Brujo'),
    'spell slots':
        'La tabla del Brujo muestra cuántos espacios de conjuro tienes. La tabla también muestra de qué nivel son esos espacios; todos tus espacios de conjuro son del mismo nivel. Para lanzar uno de tus hechizos de brujo de nivel 1 o superior, debes gastar un espacio de conjuro. Recuperas todos los espacios gastados cuando terminas un descanso corto o largo.\n\n'
        'Por ejemplo, cuando eres de nivel 5, tienes dos espacios de conjuro de nivel 3. Para lanzar el hechizo de nivel 1 «ola atronadora», debes gastar uno de esos espacios y lo lanzas como un hechizo de nivel 3.',
    'spells known of 1st level and higher':
        'Al nivel 1, conoces dos hechizos de nivel 1 de tu elección de la lista de hechizos de brujo.\n\n'
        'La columna Hechizos conocidos de la tabla del Brujo muestra cuándo aprendes más hechizos de brujo de nivel 1 o superior. Un hechizo que elijas debe ser de un nivel no superior al que se muestra en la columna Nivel de espacio de la tabla para tu nivel. Cuando alcanzas el nivel 6, por ejemplo, aprendes un nuevo hechizo de brujo, que puede ser de nivel 1, 2 o 3.\n\n'
            '${_cReplace('brujo')}',
    'spellcasting ability':
        'Carisma es tu característica para lanzar conjuros de brujo, ya que el poder de tu magia depende de tu capacidad para influir en los demás. Usas tu Carisma siempre que un hechizo se refiera a tu característica para lanzar conjuros. Además, usas tu modificador de Carisma al establecer la CD de la tirada de salvación de un hechizo de brujo que lances y al hacer una tirada de ataque con uno.\n\n${_cDc('Carisma')}',
    'spellcasting focus':
        'Puedes usar un foco arcano (ver el capítulo de equipo) como foco de lanzamiento de tus hechizos de brujo.',
  },
  'wizard': {
    'cantrips': _cCantrips('Al nivel 1, conoces tres trucos', 'mago', 'Mago'),
    'spellbook':
        'Al nivel 1, tienes un libro de conjuros que contiene seis hechizos de mago de nivel 1 de tu elección. Tu libro de conjuros es el depósito de los hechizos de mago que conoces, salvo tus trucos, que están grabados en tu mente.',
    'preparing and casting spells': _cPrepared(
      'mago',
      'Mago',
      'eligiendo de tu libro de conjuros. Al hacerlo, elige un número de hechizos de mago de tu libro de conjuros igual a tu modificador de Inteligencia + tu nivel de mago',
      'Por ejemplo, si eres un mago de nivel 3, tienes cuatro espacios de nivel 1 y dos de nivel 2. Con una Inteligencia de 16, tu lista de hechizos preparados puede incluir seis hechizos de nivel 1 o 2 de tu libro de conjuros, en cualquier combinación. Si preparas el hechizo de nivel 1 «proyectil mágico», puedes lanzarlo usando un espacio de nivel 1 o de nivel 2. Lanzar el hechizo no lo elimina de tu lista de hechizos preparados.',
      'Preparar una nueva lista de hechizos de mago requiere tiempo dedicado al estudio de tu libro de conjuros y a la memorización de las fórmulas e invocaciones del hechizo: al menos 1 minuto por nivel de hechizo por cada hechizo de tu lista.',
    ),
    'spellcasting ability':
        'Inteligencia es tu característica para lanzar conjuros de mago, ya que aprendes tus hechizos mediante el estudio y la memorización. Usas tu Inteligencia siempre que un hechizo se refiera a tu característica para lanzar conjuros. Además, usas tu modificador de Inteligencia al establecer la CD de la tirada de salvación de un hechizo de mago que lances y al hacer una tirada de ataque con uno.\n\n${_cDc('Inteligencia')}',
    'ritual casting':
        'Puedes lanzar un hechizo de mago como ritual si ese hechizo tiene el descriptor de ritual y está en tu libro de conjuros. No necesitas tenerlo preparado.',
    'spellcasting focus':
        'Puedes usar un foco arcano (ver el capítulo de equipo) como foco de lanzamiento de tus hechizos de mago.',
    'learning spells of 1st level and higher':
        'Cada vez que subes un nivel de mago, puedes añadir gratis dos hechizos de mago de tu elección a tu libro de conjuros. Cada uno de estos hechizos debe ser de un nivel para el que tengas espacios de conjuro, como se muestra en la tabla del Mago. En tus aventuras puedes encontrar otros hechizos que puedas añadir a tu libro de conjuros.',
  },
};

/// Bloque del cuadro «Lanzamiento de conjuros» en español (nombre y texto), o
/// null si la app no está en español o no está traducido.
({String n, String d})? spellcastingInfoEs(String classIndex, String enName) {
  if (!_es) return null;
  final key = enName.trim().toLowerCase();
  final text = _castingTexts[classIndex]?[key];
  final name = _castingNames[key];
  if (text == null || name == null) return null;
  return (n: name, d: text);
}

// ---------------------------------------------------------------------------
// Rasgos raciales que no vienen en el repositorio de traducciones (SRD 5.1)
// ---------------------------------------------------------------------------

const Map<String, ({String n, String d})> _traitsEs = {
  'darkvision': (
    n: 'Visión en la oscuridad',
    d: 'Tienes una visión superior en condiciones de oscuridad y penumbra. Puedes ver en luz tenue a menos de 60 pies como si fuera luz brillante, y en la oscuridad como si fuera luz tenue. No puedes distinguir colores en la oscuridad, solo tonos de gris.',
  ),
  'dwarven combat training': (
    n: 'Entrenamiento de combate enano',
    d: 'Tienes competencia con el hacha de batalla, el hacha de mano, el martillo ligero y el martillo de guerra.',
  ),
  'tool proficiency': (
    n: 'Competencia con herramientas',
    d: 'Tienes competencia con una herramienta de artesano de tu elección: herramientas de herrero, suministros de cervecero o herramientas de albañil.',
  ),
  'dwarven toughness': (
    n: 'Dureza enana',
    d: 'Tu máximo de puntos de golpe aumenta en 1, y aumenta en 1 cada vez que subes de nivel.',
  ),
  'elf weapon training': (
    n: 'Entrenamiento con armas élficas',
    d: 'Tienes competencia con la espada larga, la espada corta, el arco corto y el arco largo.',
  ),
  'keen senses': (
    n: 'Sentidos agudos',
    d: 'Tienes competencia en la habilidad Percepción.',
  ),
  'cantrip': (
    n: 'Truco',
    d: 'Conoces un truco de tu elección de la lista de hechizos de mago. Inteligencia es tu característica para lanzarlo.',
  ),
  'extra language': (
    n: 'Idioma adicional',
    d: 'Puedes hablar, leer y escribir un idioma adicional a tu elección.',
  ),
  'skill versatility': (
    n: 'Versatilidad en habilidades',
    d: 'Obtienes competencia en dos habilidades de tu elección.',
  ),
  'menacing': (
    n: 'Amenazador',
    d: 'Tienes competencia en la habilidad Intimidación.',
  ),
  'draconic ancestry': (
    n: 'Ascendencia dracónica',
    d: 'Tienes ascendencia dracónica. Elige un tipo de dragón de la tabla de ascendencia dracónica. Tu arma de aliento y tu resistencia al daño se determinan por el tipo de dragón, como se muestra en la tabla.',
  ),
  'breath weapon': (
    n: 'Arma de aliento',
    d: 'Puedes usar tu acción para exhalar energía destructiva. Tu ascendencia dracónica determina el tamaño, la forma y el tipo de daño de la exhalación. Cuando uses tu arma de aliento, cada criatura en el área de la exhalación debe hacer una tirada de salvación, cuyo tipo determina tu ascendencia dracónica. La CD de esta tirada de salvación es 8 + tu modificador de Constitución + tu bonificador de competencia. Una criatura sufre 2d6 de daño si falla la salvación, y la mitad si la supera. El daño aumenta a 3d6 al nivel 6, 4d6 al nivel 11 y 5d6 al nivel 16. Tras usar tu arma de aliento, no puedes volver a usarla hasta que completes un descanso corto o largo.',
  ),
  'damage resistance': (
    n: 'Resistencia al daño',
    d: 'Tienes resistencia al tipo de daño asociado a tu ascendencia dracónica.',
  ),
};

/// Rasgo racial en español (nombre y texto) o null.
({String n, String d})? traitEs(String enName) =>
    _es ? _traitsEs[enName.trim().toLowerCase()] : null;
