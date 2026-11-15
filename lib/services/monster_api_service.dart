import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/character.dart';
import '../models/creature.dart';

/// Monstruo de la lista de la API (solo índice y nombre).
class ApiMonsterRef {
  final String index;
  final String name;

  const ApiMonsterRef({required this.index, required this.name});
}

/// Cliente de la D&D 5e SRD API (https://www.dnd5eapi.co/).
///
/// La API solo tiene los textos en inglés (soporta fr-FR y pt-BR, pero no
/// español), así que traducimos tamaño, tipo, alineamiento y etiquetas, y
/// dejamos en inglés los nombres y las descripciones.
class MonsterApiService {
  static const String _base = 'https://www.dnd5eapi.co/api/2014';

  // Caché en memoria de las listas ya descargadas (clave: filtro de FP)
  static final Map<String, List<ApiMonsterRef>> _listCache = {};

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  /// Id del documento de Firestore con el que se guarda un monstruo importado.
  String docIdFor(String index) => '${_uid}_api_$index';

  // ---------------- Consultas ----------------

  Future<dynamic> _getJson(String path) async {
    final res = await http
        .get(Uri.parse('$_base$path'))
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('La API respondió con el código ${res.statusCode}.');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  /// Lista de monstruos. [crValue] filtra por valor de desafío (ej. 0.25).
  Future<List<ApiMonsterRef>> fetchList({num? crValue}) async {
    final key = crValue?.toString() ?? 'all';
    final cached = _listCache[key];
    if (cached != null) return cached;

    final path = crValue == null
        ? '/monsters'
        : '/monsters?challenge_rating=$crValue';
    final data = await _getJson(path) as Map<String, dynamic>;

    final list = ((data['results'] ?? []) as List)
        .map(
          (e) => ApiMonsterRef(
            index: (e['index'] ?? '') as String,
            name: (e['name'] ?? '') as String,
          ),
        )
        .where((m) => m.index.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    _listCache[key] = list;
    return list;
  }

  /// Descarga un monstruo y lo convierte a nuestro modelo.
  Future<Creature> fetchMonster(String index) async {
    final data = await _getJson('/monsters/$index') as Map<String, dynamic>;
    return creatureFromApi(data, _uid);
  }

  /// Importa monstruos al bestiario del usuario. Devuelve cuántos se guardaron.
  Future<int> importMonsters(List<String> indices) async {
    final creatures = <Creature>[];

    // Descargas en grupos de 5 para no saturar la red
    for (var i = 0; i < indices.length; i += 5) {
      final chunk = indices.skip(i).take(5);
      creatures.addAll(await Future.wait(chunk.map(fetchMonster)));
    }

    final db = FirebaseFirestore.instance;
    final col = db.collection('creatures');

    for (var i = 0; i < creatures.length; i += 400) {
      final batch = db.batch();
      for (final c in creatures.skip(i).take(400)) {
        batch.set(col.doc(c.id), c.toMap());
      }
      await batch.commit();
    }

    return creatures.length;
  }

  // ---------------- Conversión API -> Creature ----------------

  static const Map<String, String> _sizes = {
    'Tiny': 'Diminuta',
    'Small': 'Pequeña',
    'Medium': 'Mediana',
    'Large': 'Grande',
    'Huge': 'Enorme',
    'Gargantuan': 'Gargantuesca',
  };

  static const Map<String, String> _types = {
    'aberration': 'Aberración',
    'beast': 'Bestia',
    'celestial': 'Celestial',
    'construct': 'Constructo',
    'dragon': 'Dragón',
    'elemental': 'Elemental',
    'fey': 'Feérico',
    'fiend': 'Infernal',
    'giant': 'Gigante',
    'humanoid': 'Humanoide',
    'monstrosity': 'Monstruosidad',
    'ooze': 'Cieno',
    'plant': 'Planta',
    'undead': 'No-muerto',
  };

  static const Map<String, String> _alignments = {
    'lawful good': 'Legal bueno',
    'neutral good': 'Neutral bueno',
    'chaotic good': 'Caótico bueno',
    'lawful neutral': 'Legal neutral',
    'neutral': 'Neutral',
    'chaotic neutral': 'Caótico neutral',
    'lawful evil': 'Legal malvado',
    'neutral evil': 'Neutral malvado',
    'chaotic evil': 'Caótico malvado',
    'unaligned': 'Sin alineamiento',
    'any alignment': 'Cualquier alineamiento',
    'any non-lawful alignment': 'Cualquiera no legal',
    'any non-good alignment': 'Cualquiera no bueno',
    'any chaotic alignment': 'Cualquiera caótico',
    'any evil alignment': 'Cualquiera malvado',
  };

  static String _feet(String s) => s.replaceAll('ft.', 'pies').trim();

  static String _crToString(num cr) {
    if (cr == 0.125) return '1/8';
    if (cr == 0.25) return '1/4';
    if (cr == 0.5) return '1/2';
    return cr.toInt().toString();
  }

  static String _namedBlocks(dynamic list) {
    if (list is! List) return '';
    return list
        .whereType<Map>()
        .map((e) => '${e['name'] ?? ''}. ${e['desc'] ?? ''}'.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  static String _stringList(dynamic v) =>
      v is List ? v.map((e) => e.toString()).join(', ') : '';

  /// Convierte el JSON de la API en una criatura de nuestro modelo.
  Creature creatureFromApi(Map<String, dynamic> m, String uid) {
    final index = (m['index'] ?? '') as String;

    // Clase de armadura: lista de objetos {type, value} (o número en versiones antiguas)
    var ac = 10;
    final rawAc = m['armor_class'];
    if (rawAc is num) {
      ac = rawAc.toInt();
    } else if (rawAc is List && rawAc.isNotEmpty && rawAc.first is Map) {
      ac = (((rawAc.first as Map)['value'] ?? 10) as num).toInt();
    }

    // Velocidad
    final speedParts = <String>[];
    final speed = m['speed'];
    if (speed is Map) {
      const labels = {
        'walk': '',
        'burrow': 'excavar ',
        'climb': 'trepar ',
        'fly': 'volar ',
        'swim': 'nadar ',
      };
      labels.forEach((key, label) {
        final v = speed[key];
        if (v is String && v.isNotEmpty) {
          speedParts.add('$label${_feet(v)}');
        }
      });
    }

    // Salvaciones y habilidades con competencia
    final saves = <String>[];
    final skills = <String>[];
    for (final p in (m['proficiencies'] as List? ?? const [])) {
      if (p is! Map) continue;
      final name = ((p['proficiency'] as Map?)?['name'] ?? '') as String;
      final value = Character.signed(((p['value'] ?? 0) as num).toInt());
      if (name.startsWith('Saving Throw: ')) {
        saves.add('${name.substring(14)} $value');
      } else if (name.startsWith('Skill: ')) {
        skills.add('${name.substring(7)} $value');
      }
    }
    final skillsText = [
      if (saves.isNotEmpty) 'Salvaciones: ${saves.join(', ')}',
      if (skills.isNotEmpty) 'Habilidades: ${skills.join(', ')}',
    ].join('. ');

    // Sentidos
    final sensesParts = <String>[];
    final senses = m['senses'];
    if (senses is Map) {
      const labels = {
        'blindsight': 'Vista ciega',
        'darkvision': 'Visión en la oscuridad',
        'tremorsense': 'Sentido sísmico',
        'truesight': 'Visión verdadera',
      };
      labels.forEach((key, label) {
        final v = senses[key];
        if (v is String && v.isNotEmpty) sensesParts.add('$label ${_feet(v)}');
      });
      final pp = senses['passive_perception'];
      if (pp is num) sensesParts.add('Percepción pasiva ${pp.toInt()}');
    }

    // Resistencias e inmunidades -> primeras líneas de los rasgos
    final conditionImmunities = (m['condition_immunities'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => (e['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .join(', ');

    final traitLines = <String>[
      if (_stringList(m['damage_vulnerabilities']).isNotEmpty)
        'Vulnerabilidades al daño: ${_stringList(m['damage_vulnerabilities'])}',
      if (_stringList(m['damage_resistances']).isNotEmpty)
        'Resistencias al daño: ${_stringList(m['damage_resistances'])}',
      if (_stringList(m['damage_immunities']).isNotEmpty)
        'Inmunidades al daño: ${_stringList(m['damage_immunities'])}',
      if (conditionImmunities.isNotEmpty)
        'Inmunidades a condiciones: $conditionImmunities',
      _namedBlocks(m['special_abilities']),
    ].where((s) => s.isNotEmpty).join('\n');

    // Acciones, reacciones y acciones legendarias
    final reactions = _namedBlocks(m['reactions']);
    final legendary = _namedBlocks(m['legendary_actions']);
    final actionsText = [
      _namedBlocks(m['actions']),
      if (reactions.isNotEmpty) 'Reacciones:\n$reactions',
      if (legendary.isNotEmpty) 'Acciones legendarias:\n$legendary',
    ].where((s) => s.isNotEmpty).join('\n\n');

    final subtype = (m['subtype'] ?? '') as String;
    final typeEs = _types[(m['type'] ?? '').toString().toLowerCase()] ??
        (m['type'] ?? 'Monstruosidad').toString();
    final alignmentRaw = (m['alignment'] ?? 'unaligned').toString();

    final hitRoll = (m['hit_points_roll'] ?? m['hit_dice'] ?? '').toString();

    return Creature(
      id: '${uid}_api_$index',
      ownerUid: uid,
      kind: 'monster',
      name: (m['name'] ?? index) as String,
      size: _sizes[m['size']] ?? (m['size'] ?? 'Mediana') as String,
      creatureType: subtype.isEmpty ? typeEs : '$typeEs ($subtype)',
      alignment: _alignments[alignmentRaw.toLowerCase()] ?? alignmentRaw,
      challengeRating: _crToString((m['challenge_rating'] ?? 0) as num),
      armorClass: ac,
      maxHp: ((m['hit_points'] ?? 1) as num).toInt(),
      hitDice: hitRoll,
      speed: speedParts.isEmpty ? '30 pies' : speedParts.join(', '),
      abilities: {
        'str': ((m['strength'] ?? 10) as num).toInt(),
        'dex': ((m['dexterity'] ?? 10) as num).toInt(),
        'con': ((m['constitution'] ?? 10) as num).toInt(),
        'int': ((m['intelligence'] ?? 10) as num).toInt(),
        'wis': ((m['wisdom'] ?? 10) as num).toInt(),
        'cha': ((m['charisma'] ?? 10) as num).toInt(),
      },
      skills: skillsText,
      senses: sensesParts.join('; '),
      languages: (m['languages'] ?? '') as String,
      traits: traitLines,
      actions: actionsText,
      notes: 'Importado de la D&D 5e SRD API (textos en inglés).',
      isPreset: true, // dato SRD: se muestra con la etiqueta "SRD"
    );
  }
}
