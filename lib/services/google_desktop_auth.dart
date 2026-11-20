import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Inicio de sesión con Google para Windows sin librerías de terceros.
///
/// Abre el navegador, recibe el código en http://localhost:[port] y lo
/// cambia por los tokens. Si Google rechaza algo, el error incluye la
/// respuesta de Google (por ejemplo `invalid_client` si el secreto no
/// corresponde al ID de cliente), así se ve el motivo real.
class GoogleDesktopAuth {
  GoogleDesktopAuth._();

  static Future<({String idToken, String accessToken})> signIn({
    required String clientId,
    required String clientSecret,
    required int port,
  }) async {
    final redirect = 'http://localhost:$port';
    final rnd = Random.secure();
    final state = List.generate(16, (_) => rnd.nextInt(16).toRadixString(16)).join();

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

      // Canje del código por los tokens
      final client = HttpClient();
      try {
        final req = await client.postUrl(Uri.https('oauth2.googleapis.com', '/token'));
        req.headers.contentType =
            ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
        req.write(Uri(queryParameters: {
          'code': code,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirect,
          'grant_type': 'authorization_code',
        }).query);
        final res = await req.close();
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
}
