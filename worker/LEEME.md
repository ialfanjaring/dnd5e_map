# Worker para el inicio de sesión de Google en Windows

Sirve para que el Client Secret NO esté en la app ni en GitHub.

## Publicarlo (una sola vez, gratis, sin tarjeta)
1. Crea una cuenta en https://dash.cloudflare.com (plan gratuito).
2. Instala Node.js (https://nodejs.org) y, en una terminal dentro de la carpeta `worker`:
   ```
   npx wrangler login
   npx wrangler secret put GOOGLE_CLIENT_SECRET
   ```
   (pega el Client Secret del cliente de escritorio cuando lo pida)
   ```
   npx wrangler deploy
   ```
3. Al terminar muestra una dirección como
   `https://dnd5e-google-token.TU-USUARIO.workers.dev`. Cópiala.
4. Pégala en `lib/services/auth_service.dart`, en `_tokenProxyUrl`.
5. Ejecuta la app de nuevo (parar y Run).

## Después
- Ya puedes borrar el secreto de GitHub (`GOOGLE_DESKTOP_CLIENT_SECRET`): no se usa.
- Si cambias de Client ID o de puerto, edita `wrangler.toml` y repite `npx wrangler deploy`.
