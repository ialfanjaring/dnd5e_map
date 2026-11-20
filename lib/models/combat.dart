/// Una ficha dentro del orden de iniciativa.
class InitEntry {
  /// id de la ficha del mapa ('p_<uid>' en jugadores, id de la criatura en el resto)
  final String id;
  final String name;

  /// 'player' o 'creature'
  final String kind;

  /// Color ARGB de la ficha
  final int color;

  /// Modificador de iniciativa
  final int mod;

  /// Resultado del d20
  final int roll;

  /// Resultado final (editable por el Master)
  final int total;

  /// false mientras todavía no ha tirado la iniciativa
  final bool rolled;

  /// Fichas que forman un grupo (actúan a la vez con una sola iniciativa).
  /// Vacío en una ficha individual.
  final List<String> members;

  const InitEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.color,
    required this.mod,
    required this.roll,
    required this.total,
    this.rolled = true,
    this.members = const [],
  });

  bool get isPlayer => kind == 'player';
  bool get isGroup => members.isNotEmpty;

  /// La ficha [tokenId] actúa en este turno de iniciativa.
  bool covers(String tokenId) => id == tokenId || members.contains(tokenId);

  InitEntry copyWith({int? total, int? roll, int? mod, bool? rolled}) =>
      InitEntry(
        id: id,
        name: name,
        kind: kind,
        color: color,
        mod: mod ?? this.mod,
        roll: roll ?? this.roll,
        total: total ?? this.total,
        rolled: rolled ?? this.rolled,
        members: members,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'kind': kind,
        'color': color,
        'mod': mod,
        'roll': roll,
        'total': total,
        'rolled': rolled,
        'members': members,
      };

  factory InitEntry.fromMap(Map<dynamic, dynamic> m) => InitEntry(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        kind: (m['kind'] ?? 'creature').toString(),
        color: ((m['color'] ?? 0xFF607D8B) as num).toInt(),
        mod: ((m['mod'] ?? 0) as num).toInt(),
        roll: ((m['roll'] ?? 0) as num).toInt(),
        total: ((m['total'] ?? 0) as num).toInt(),
        rolled: (m['rolled'] ?? true) as bool,
        members: ((m['members'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );
}

/// Estado del combate: orden de iniciativa, ronda y ficha con el turno.
///
/// Tiene dos fases: «rolling» (cada uno tira su iniciativa) y «turns»
/// (combate en marcha).
class CombatState {
  final bool active;
  final String phase;
  final int round;

  /// id de la entrada que tiene el turno
  final String current;
  final List<InitEntry> entries;

  const CombatState({
    required this.active,
    this.phase = 'turns',
    required this.round,
    required this.current,
    required this.entries,
  });

  bool get rolling => active && phase == 'rolling';
  bool get inTurns => active && phase != 'rolling';

  factory CombatState.fromMap(Map<String, dynamic> m) {
    // Tiradas hechas durante la fase de iniciativa: rolls.{id} = {roll, mod}
    final rolls = (m['rolls'] as Map?) ?? const {};
    final entries = ((m['entries'] as List?) ?? const [])
        .whereType<Map>()
        .map(InitEntry.fromMap)
        .map((e) {
      final r = rolls[e.id];
      if (r is Map) {
        final roll = ((r['roll'] ?? 0) as num).toInt();
        final mod = ((r['mod'] ?? 0) as num).toInt();
        return e.copyWith(roll: roll, mod: mod, total: roll + mod, rolled: true);
      }
      return e;
    }).toList();

    return CombatState(
      active: (m['active'] ?? false) as bool,
      phase: (m['phase'] ?? 'turns').toString(),
      round: ((m['round'] ?? 1) as num).toInt(),
      current: (m['current'] ?? '').toString(),
      entries: entries,
    );
  }

  /// Fichas del mapa que actúan ahora (una, o todas las de un grupo).
  Set<String> get currentTokenIds {
    final e = currentEntry;
    if (!inTurns || e == null) return const {};
    return {e.id, ...e.members};
  }

  /// Entradas que aún no han tirado.
  List<InitEntry> get pending => entries.where((e) => !e.rolled).toList();

  InitEntry? get currentEntry {
    for (final e in entries) {
      if (e.id == current) return e;
    }
    return null;
  }

  /// Quién tiene el turno después del actual (y en qué ronda).
  ({String id, int round}) next() {
    if (entries.isEmpty) return (id: '', round: round);

    final i = entries.indexWhere((e) => e.id == current);
    if (i < 0) return (id: entries.first.id, round: round);
    if (i + 1 >= entries.length) return (id: entries.first.id, round: round + 1);
    return (id: entries[i + 1].id, round: round);
  }

  /// Orden por resultado (de mayor a menor) y, a igualdad, por modificador.
  static List<InitEntry> sorted(List<InitEntry> list) {
    final out = List<InitEntry>.from(list);
    out.sort((a, b) {
      final t = b.total.compareTo(a.total);
      return t != 0 ? t : b.mod.compareTo(a.mod);
    });
    return out;
  }
}
