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

  const InitEntry({
    required this.id,
    required this.name,
    required this.kind,
    required this.color,
    required this.mod,
    required this.roll,
    required this.total,
  });

  bool get isPlayer => kind == 'player';

  InitEntry copyWith({int? total}) => InitEntry(
        id: id,
        name: name,
        kind: kind,
        color: color,
        mod: mod,
        roll: roll,
        total: total ?? this.total,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'kind': kind,
        'color': color,
        'mod': mod,
        'roll': roll,
        'total': total,
      };

  factory InitEntry.fromMap(Map<dynamic, dynamic> m) => InitEntry(
        id: (m['id'] ?? '').toString(),
        name: (m['name'] ?? '').toString(),
        kind: (m['kind'] ?? 'creature').toString(),
        color: ((m['color'] ?? 0xFF607D8B) as num).toInt(),
        mod: ((m['mod'] ?? 0) as num).toInt(),
        roll: ((m['roll'] ?? 0) as num).toInt(),
        total: ((m['total'] ?? 0) as num).toInt(),
      );
}

/// Estado del combate: orden de iniciativa, ronda y ficha con el turno.
class CombatState {
  final bool active;
  final int round;

  /// id de la ficha que tiene el turno
  final String current;
  final List<InitEntry> entries;

  const CombatState({
    required this.active,
    required this.round,
    required this.current,
    required this.entries,
  });

  factory CombatState.fromMap(Map<String, dynamic> m) => CombatState(
        active: (m['active'] ?? false) as bool,
        round: ((m['round'] ?? 1) as num).toInt(),
        current: (m['current'] ?? '').toString(),
        entries: ((m['entries'] as List?) ?? const [])
            .whereType<Map>()
            .map(InitEntry.fromMap)
            .toList(),
      );

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
