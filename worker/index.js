// Cloudflare Worker: canjea el código de Google por los tokens usando el
// Client Secret, que solo existe aquí (secreto del Worker), nunca en la app.
//
// Variables (wrangler.toml): GOOGLE_CLIENT_ID, REDIRECT_URI
// Secreto (wrangler secret put): GOOGLE_CLIENT_SECRET

const json = (obj, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { 'content-type': 'application/json' },
  });

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') return json({ error: 'method_not_allowed' }, 405);

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'bad_request' }, 400);
    }
    const { code, code_verifier, redirect_uri } = body || {};

    if (
      typeof code !== 'string' || code.length === 0 || code.length > 2048 ||
      typeof code_verifier !== 'string' || code_verifier.length < 43 || code_verifier.length > 128
    ) {
      return json({ error: 'bad_request' }, 400);
    }
    // Solo se acepta el redirect de la app de escritorio
    if (redirect_uri !== env.REDIRECT_URI) return json({ error: 'bad_redirect' }, 400);

    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        code,
        code_verifier,
        client_id: env.GOOGLE_CLIENT_ID,
        client_secret: env.GOOGLE_CLIENT_SECRET,
        redirect_uri,
        grant_type: 'authorization_code',
      }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      return json(
        { error: data.error || 'token_error', error_description: data.error_description || '' },
        400,
      );
    }
    // Solo se devuelve lo que la app necesita (sin refresh_token)
    return json({ id_token: data.id_token, access_token: data.access_token });
  },
};
