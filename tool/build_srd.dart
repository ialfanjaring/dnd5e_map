// Añade a assets/data/srd_es.json las secciones de clases, subclases, razas,
// subrazas, rasgos de clase/raza y los NOMBRES de hechizos en español OFICIAL.
//
// NO traduce nada con IA ni en línea: copia las traducciones del módulo de
// Foundry "ravanno-dnd5e-es" (SRD 5.1 en español, licencia MIT):
//   https://github.com/ravanno/ravanno-dnd5e-es
// Se ejecuta UNA vez y el resultado queda dentro de la app.
//
// Uso (desde la raíz del proyecto, con internet):
//   dart run tool/build_srd.dart --list      (solo muestra qué archivos usaría)
//   dart run tool/build_srd.dart             (genera las secciones)
//   dart run tool/build_srd.dart --dir=C:\ruta\a\ravanno-dnd5e-es   (copia local)
//
// Secciones que escribe (cada entrada: n = nombre, d = descripción):
//   classes, subclasses, races, subraces, features, traits
// y completa spells (solo añade el nombre 'n' si falta; no pisa lo que ya hay).
//
// Si dos rasgos distintos se llaman igual (p. ej. «Spellcasting» de cada
// clase) se guarda solo el nombre y NO la descripción, para no mostrar el
// texto de otra clase.
//
// Conserva el resto del archivo (objetos, hechizos y monstruos) tal cual.
import 'dart:convert';
import 'dart:io';

const _repo = 'ravanno/ravanno-dnd5e-es';
const _file = 'assets/data/srd_es.json';

String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

Future<String> getText(String url) async {
  final c = HttpClient();
  try {
    final req = await c.getUrl(Uri.parse(url));
    req.headers.set('User-Agent', 'dnd5e_map-tool');
    final r = await req.close();
    final body = await r.transform(utf8.decoder).join();
    if (r.statusCode != 200) throw 'HTTP ${r.statusCode} en $url';
    return body;
  } finally {
    c.close();
  }
}

/// Convierte el HTML/marcado de Foundry en texto plano.
String clean(String s) {
  var t = s;
  t = t.replaceAll(RegExp(r'<\s*br\s*/?>', caseSensitive: false), '\n');
  t = t.replaceAll(
      RegExp(r'</\s*(p|div|li|tr|h\d)\s*>', caseSensitive: false), '\n');
  t = t.replaceAll(RegExp(r'<[^>]+>'), '');
  t = t.replaceAllMapped(RegExp(r'@\w+\[[^\]]*\]\{([^}]*)\}'), (m) => m[1]!);
  t = t.replaceAll(RegExp(r'@\w+\[[^\]]*\]'), '');
  t = t.replaceAllMapped(
    RegExp(r'\[\[\s*/?\w+\s+([^\]#]*?)(?:\s*#[^\]]*)?\]\](?:\{([^}]*)\})?'),
    (m) => (m[2] != null && m[2]!.isNotEmpty) ? m[2]! : m[1]!.trim(),
  );
  t = t
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  t = t.replaceAll(RegExp(r'[ \t]+'), ' ');
  t = t.replaceAll(RegExp(r' *\n *'), '\n').replaceAll(RegExp(r'\n{2,}'), '\n');
  return t.trim();
}

List<MapEntry<String, Map>> entriesOf(dynamic node) {
  final out = <MapEntry<String, Map>>[];
  if (node is Map) {
    node.forEach((k, v) {
      if (v is Map) out.add(MapEntry(k.toString(), v));
    });
  } else if (node is List) {
    for (final v in node) {
      if (v is Map) {
        final key = (v['id'] ?? v['originalName'] ?? v['key'] ?? '').toString();
        if (key.isNotEmpty) out.add(MapEntry(key, v));
      }
    }
  }
  return out;
}

/// A qué sección de srd_es.json va un archivo, según su ruta. null = ignorar.
String? sectionFor(String path) {
  final p = path.toLowerCase();
  if (!p.endsWith('.json') || p.contains('module.json')) return null;
  if (p.contains('monster') || p.contains('actor') || p.contains('bestiary')) {
    return null; // los monstruos los genera tool/build_monsters.dart
  }
  if (p.contains('subclass')) return 'subclasses';
  if (p.contains('subrace')) return 'subraces';
  if (p.contains('classfeature') ||
      p.contains('class-feature') ||
      p.contains('class_feature') ||
      p.contains('features')) {
    return 'features';
  }
  if (p.contains('racial') || p.contains('trait')) return 'traits';
  if (p.contains('race')) return 'races';
  if (p.contains('class')) return 'classes';
  if (p.contains('spell')) return 'spells';
  return null;
}

class Entry {
  Entry(this.n, this.d);
  final String n;
  final String d;
}

/// Lee un archivo Babele: {name, description} por entrada.
Map<String, List<Entry>> parse(dynamic json) {
  dynamic root = json;
  if (root is Map && root['entries'] != null) root = root['entries'];
  final res = <String, List<Entry>>{};
  for (final e in entriesOf(root)) {
    final v = e.value;
    final esName = (v['name'] ?? '').toString().trim();
    if (esName.isEmpty) continue;
    final d = clean((v['description'] ?? v['desc'] ?? '').toString());
    final key = norm((v['originalName'] ?? e.key).toString());
    if (key.isEmpty) continue;
    res.putIfAbsent(key, () => []).add(Entry(esName, d));
  }
  return res;
}


Future<void> main(List<String> args) async {
  String? dir;
  var listOnly = false;
  for (final a in args) {
    if (a.startsWith('--dir=')) dir = a.substring(6);
    if (a == '--list') listOnly = true;
  }

  // 1) Archivos candidatos
  final files = <String, String>{};
  if (dir != null) {
    for (final f in Directory(dir).listSync(recursive: true)) {
      if (f is File && sectionFor(f.path) != null) {
        files[f.path] = await f.readAsString();
      }
    }
  } else {
    stdout.writeln('Buscando archivos en github.com/$_repo ...');
    final tree = jsonDecode(await getText(
        'https://api.github.com/repos/$_repo/git/trees/main?recursive=1'));
    for (final n in (tree['tree'] as List)) {
      final p = n['path'].toString();
      if (n['type'] == 'blob' && sectionFor(p) != null) {
        stdout.writeln('  descargando $p');
        files[p] =
            await getText('https://raw.githubusercontent.com/$_repo/main/$p');
      }
    }
  }
  if (files.isEmpty) {
    stderr.writeln('No se encontró ningún archivo. Prueba con --dir=');
    exit(1);
  }

  stdout.writeln('Archivos y sección a la que irían:');
  for (final p in files.keys) {
    stdout.writeln('  ${sectionFor(p)!.padRight(11)} $p (${files[p]!.length} bytes)');
  }
  if (listOnly) return;

  // 2) Analizar y juntar por sección
  final bySection = <String, Map<String, List<Entry>>>{};
  for (final f in files.entries) {
    final sec = sectionFor(f.key)!;
    try {
      final r = parse(jsonDecode(f.value));
      if (r.isEmpty) {
        stdout.writeln('  (sin entradas reconocibles) ${f.key}');
        continue;
      }
      stdout.writeln('  ${f.key}: ${r.length} entradas -> $sec');
      final dst = bySection.putIfAbsent(sec, () => {});
      r.forEach((k, v) => dst.putIfAbsent(k, () => []).addAll(v));
    } catch (err) {
      stdout.writeln('  (no se pudo leer ${f.key}: $err)');
    }
  }
  if (bySection.isEmpty) {
    stderr.writeln('No se pudo extraer nada. Envíame la salida de --list.');
    exit(1);
  }

  // 3) Guardar sin tocar el resto del archivo
  final f = File(_file);
  Map<String, dynamic> data = {};
  if (f.existsSync()) {
    final d = jsonDecode(await f.readAsString());
    if (d is Map) data = Map<String, dynamic>.from(d);
  }

  bySection.forEach((sec, entries) {
    final out = <String, dynamic>{};
    var ambiguous = 0;
    entries.forEach((key, list) {
      final name = list.first.n;
      // Varias entradas con el mismo nombre en inglés y textos distintos:
      // solo se guarda el nombre.
      final texts = list.map((e) => e.d).where((t) => t.isNotEmpty).toSet();
      final amb = texts.length > 1;
      if (amb) ambiguous++;
      final d = (!amb && texts.isNotEmpty) ? texts.first : '';
      out[key] = {'n': name, if (d.isNotEmpty) 'd': d};
    });

    if (sec == 'spells') {
      // Solo completa nombres que falten; no pisa nada de lo existente.
      final cur = Map<String, dynamic>.from((data['spells'] as Map?) ?? {});
      var added = 0;
      out.forEach((k, v) {
        final e = cur[k];
        if (e is Map) {
          if ((e['n'] ?? '').toString().isEmpty) {
            cur[k] = {...Map<String, dynamic>.from(e), 'n': v['n']};
            added++;
          }
        } else {
          cur[k] = {'n': v['n']};
          added++;
        }
      });
      data['spells'] = cur;
      stdout.writeln('spells: $added nombres añadidos.');
    } else {
      data[sec] = out;
      stdout.writeln('$sec: ${out.length} entradas'
          '${ambiguous > 0 ? " ($ambiguous solo con nombre por estar repetidas)" : ""}.');
    }
  });

  await f.writeAsString(jsonEncode(data));
  stdout.writeln('Guardado en $_file');
}
