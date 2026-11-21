// Genera/amplía assets/data/srd_es.json traduciendo UNA sola vez lo que
// falte (hechizos y objetos que no estén ya en español). La app solo lee ese
// archivo: no traduce en línea ni guarda nada en Firestore.
//
// Uso (desde la raíz del proyecto, con internet):
//   dart run tool/build_translations.dart
//   dart run tool/build_translations.dart --email=tu@correo.com   (50.000 car./día)
//   DeepL (mejor calidad, gratis 500.000 car./mes):
//     PowerShell:  $env:DEEPL_KEY="tu-clave"; dart run tool/build_translations.dart
//
// Es reanudable: guarda tras cada entrada. Si se agota la cuota diaria, se
// detiene; vuelve a ejecutarlo al día siguiente y continúa donde lo dejó.
// Revisa el JSON resultante; la traducción automática puede tener fallos.
import 'dart:convert';
import 'dart:io';

const _api = 'https://www.dnd5eapi.co/api/2014';
const _file = 'assets/data/srd_es.json';

late Map<String, dynamic> data;
String? email;
String? deepl;
int sent = 0;

String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

class QuotaExceeded implements Exception {}

Future<dynamic> getJson(String url) async {
  final c = HttpClient();
  try {
    final r = await (await c.getUrl(Uri.parse(url))).close();
    final body = await r.transform(utf8.decoder).join();
    if (r.statusCode != 200) throw 'HTTP ${r.statusCode} en $url';
    return jsonDecode(body);
  } finally {
    c.close();
  }
}

Future<String> translateChunk(String text) async {
  final c = HttpClient();
  try {
    if (deepl != null) {
      final req = await c.postUrl(Uri.parse('https://api-free.deepl.com/v2/translate'));
      req.headers.set('Authorization', 'DeepL-Auth-Key $deepl');
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({'text': [text], 'source_lang': 'EN', 'target_lang': 'ES'}));
      final r = await req.close();
      final body = await r.transform(utf8.decoder).join();
      if (r.statusCode == 456 || r.statusCode == 429) throw QuotaExceeded();
      if (r.statusCode != 200) throw 'DeepL ${r.statusCode}: $body';
      return jsonDecode(body)['translations'][0]['text'] as String;
    }
    final uri = Uri.https('api.mymemory.translated.net', '/get', {
      'q': text,
      'langpair': 'en|es',
      if (email != null) 'de': email!,
    });
    final r = await (await c.getUrl(uri)).close();
    final body = await r.transform(utf8.decoder).join();
    if (r.statusCode == 429) throw QuotaExceeded();
    final j = jsonDecode(body);
    final out = (j['responseData']?['translatedText'] ?? '').toString();
    if ('${j['responseStatus']}' == '429' ||
        out.toUpperCase().contains('MYMEMORY WARNING')) {
      throw QuotaExceeded();
    }
    return out
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
  } finally {
    c.close();
  }
}

List<String> split(String s) {
  final res = <String>[];
  for (final para in s.split('\n')) {
    if (para.length <= 450) {
      res.add(para);
      continue;
    }
    var cur = '';
    for (final sent in para.split(RegExp(r'(?<=[.!?])\s+'))) {
      if (cur.isNotEmpty && cur.length + sent.length + 1 > 450) {
        res.add(cur);
        cur = sent;
      } else {
        cur = cur.isEmpty ? sent : '$cur $sent';
      }
      while (cur.length > 450) {
        res.add(cur.substring(0, 450));
        cur = cur.substring(450);
      }
    }
    if (cur.isNotEmpty) res.add(cur);
  }
  return res;
}

Future<String> tr(String text) async {
  if (text.trim().isEmpty) return text;
  final out = <String>[];
  for (final p in split(text)) {
    if (p.trim().isEmpty) {
      out.add(p);
      continue;
    }
    out.add(await translateChunk(p));
    sent += p.length;
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  return out.join('\n');
}

void save() => File(_file).writeAsStringSync(jsonEncode(data));

String join(dynamic v) =>
    v is List ? v.map((e) => e.toString()).join('\n\n') : (v ?? '').toString();

Future<void> section(
  String key,
  List<String> listPaths,
  List<String> detailPrefixes,
  bool spells,
) async {
  final sec = (data[key] as Map?)?.cast<String, dynamic>() ?? {};
  data[key] = sec;
  final refs = <Map>[];
  for (final lp in listPaths) {
    final l = await getJson('$_api$lp');
    refs.addAll((l['results'] as List).cast<Map>());
  }
  final todo = refs.where((r) => !sec.containsKey(norm('${r['name']}'))).toList();
  stdout.writeln('[$key] ${refs.length} en la API, ${todo.length} por traducir');
  var i = 0;
  for (final r in todo) {
    i++;
    final url = '${r['url']}'.replaceFirst('/api/2014', '');
    final d = await getJson('$_api$url');
    final name = '${d['name']}';
    final desc = join(d['desc']);
    final high = spells ? join(d['higher_level']) : '';
    try {
      final entry = <String, String>{
        'n': await tr(name),
        'd': await tr(desc),
        if (high.isNotEmpty) 'h': await tr(high),
      };
      sec[norm(name)] = entry;
      save();
      stdout.writeln('  [$i/${todo.length}] $name -> ${entry['n']}');
    } on QuotaExceeded {
      save();
      stdout.writeln('\nCuota agotada. Guardado lo hecho ($sent caracteres). '
          'Vuelve a ejecutar mañana, o usa --email o DEEPL_KEY.');
      exit(0);
    }
  }
}

Future<void> main(List<String> args) async {
  for (final a in args) {
    if (a.startsWith('--email=')) email = a.substring(8);
  }
  deepl = Platform.environment['DEEPL_KEY'];
  final f = File(_file);
  data = f.existsSync()
      ? (jsonDecode(f.readAsStringSync()) as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  await section('spells', ['/spells'], [], true);
  await section('items', ['/equipment', '/magic-items'], [], false);
  stdout.writeln('\nListo. Caracteres traducidos: $sent');
}
