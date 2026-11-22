import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Inicio de sesión con Google para Windows sin librerías de terceros y SIN
/// guardar ningún secreto en la app.
///
/// Abre el navegador (con PKCE), recibe el código en http://localhost:[port]
/// y lo envía a [tokenUrl] (un Cloudflare Worker propio, ver carpeta worker/),
/// que es quien conoce el Client Secret y lo canjea por los tokens.
class GoogleDesktopAuth {
  GoogleDesktopAuth._();

  static Future<({String idToken, String accessToken})> signIn({
    required String clientId,
    required String tokenUrl,
    required int port,
  }) async {
    final redirect = 'http://localhost:$port';
    final rnd = Random.secure();
    final state = _random(rnd, 16);
    // PKCE: el verificador solo lo conoce esta app
    final verifier = _random(rnd, 64);
    final challenge = base64Url
        .encode(_sha256(ascii.encode(verifier)))
        .replaceAll('=', '');

    final HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    } on SocketException {
      throw Exception(
          'El puerto $port está ocupado. Cierra otras ventanas de la app y '
          'pestañas con localhost:$port y vuelve a intentarlo.');
    }

    try {
      final url = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': 'openid email profile',
        'state': state,
        'prompt': 'select_account',
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
      });
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url.toString()]);

      String? code;
      String? error;
      await for (final req in server.timeout(const Duration(minutes: 3))) {
        final q = req.uri.queryParameters;
        final isCallback = q.containsKey('code') || q.containsKey('error');
        req.response
          ..statusCode = isCallback ? 200 : 404
          ..headers.contentType = ContentType.html
          ..write(isCallback
              ? '<html><body style="font-family:sans-serif;background:#121018;'
                  'color:#fff;text-align:center;padding-top:80px">'
                  '<h2>Listo</h2><p>Ya puedes cerrar esta pestaña y volver a la app.</p>'
                  '</body></html>'
              : '');
        await req.response.close();
        if (!isCallback) continue;
        if (q['state'] != state) {
          error = 'state_mismatch';
        } else {
          code = q['code'];
          error = q['error'];
        }
        break;
      }

      if (error != null) throw Exception('Google devolvió un error: $error');
      if (code == null) throw Exception('No se recibió el código de Google.');

      // El Worker canjea el código por los tokens usando el secreto
      final client = HttpClient();
      try {
        final req = await client
            .postUrl(Uri.parse(tokenUrl))
            .timeout(const Duration(seconds: 20));
        req.headers.contentType = ContentType.json;
        req.write(jsonEncode({
          'code': code,
          'code_verifier': verifier,
          'redirect_uri': redirect,
        }));
        final res = await req.close().timeout(const Duration(seconds: 30));
        final body = await res.transform(utf8.decoder).join();
        if (res.statusCode != 200) {
          throw Exception('Google rechazó el canje del código '
              '(${res.statusCode}): $body');
        }
        final json = jsonDecode(body) as Map<String, dynamic>;
        final idToken = json['id_token'] as String?;
        final accessToken = json['access_token'] as String?;
        if (idToken == null || accessToken == null) {
          throw Exception('Google no devolvió los tokens esperados.');
        }
        return (idToken: idToken, accessToken: accessToken);
      } finally {
        client.close(force: true);
      }
    } on TimeoutException {
      throw Exception('cancel: se agotó el tiempo de espera del inicio de sesión.');
    } finally {
      await server.close(force: true);
    }
  }

  static const _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';

  static String _random(Random r, int n) =>
      List.generate(n, (_) => _chars[r.nextInt(_chars.length)]).join();

  // SHA-256 (necesario para PKCE; así no hace falta ningún paquete extra)
  static const List<int> _k = [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2];

  static List<int> _sha256(List<int> data) {
    const mask = 0xFFFFFFFF;
    var h = <int>[
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];
    final n = data.length;
    final padLen = ((n + 9 + 63) ~/ 64) * 64;
    final m = List<int>.filled(padLen, 0);
    m.setRange(0, n, data);
    m[n] = 0x80;
    final bits = n * 8;
    for (var i = 0; i < 8; i++) {
      m[padLen - 1 - i] = (bits >> (8 * i)) & 0xff;
    }
    int rotr(int x, int k) => ((x >> k) | (x << (32 - k))) & mask;
    final w = List<int>.filled(64, 0);
    for (var off = 0; off < padLen; off += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = (m[off + 4 * i] << 24) |
            (m[off + 4 * i + 1] << 16) |
            (m[off + 4 * i + 2] << 8) |
            m[off + 4 * i + 3];
      }
      for (var i = 16; i < 64; i++) {
        final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & mask;
      }
      var a = h[0], b = h[1], c = h[2], d = h[3];
      var e = h[4], f = h[5], g = h[6], hh = h[7];
      for (var i = 0; i < 64; i++) {
        final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        final ch = (e & f) ^ ((~e & mask) & g);
        final t1 = (hh + s1 + ch + _k[i] + w[i]) & mask;
        final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final t2 = (s0 + maj) & mask;
        hh = g;
        g = f;
        f = e;
        e = (d + t1) & mask;
        d = c;
        c = b;
        b = a;
        a = (t1 + t2) & mask;
      }
      h = [
        (h[0] + a) & mask, (h[1] + b) & mask, (h[2] + c) & mask, (h[3] + d) & mask,
        (h[4] + e) & mask, (h[5] + f) & mask, (h[6] + g) & mask, (h[7] + hh) & mask,
      ];
    }
    final out = <int>[];
    for (final v in h) {
      out.addAll([(v >> 24) & 255, (v >> 16) & 255, (v >> 8) & 255, v & 255]);
    }
    return out;
  }
}
