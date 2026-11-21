# Publicar la app: APK, instalador de Windows y web (gratis)

Todo lo construye GitHub Actions en la nube (no hace falta compilar en tu PC).
Al subir una etiqueta `v1.0.0` se genera:
- `dnd5e_map.apk` y `dnd5e_map_setup.exe` → se adjuntan a una *Release* de GitHub.
- la versión web + la página de descargas → https://ialfanjaring.github.io/dnd5e_map/

## 1. Copiar al repositorio (raíz del proyecto)
- `.github/workflows/release.yml`
- `installer/dnd5e_map.iss`
- `site/` (index.html y logo.png)
- `lib/` (incluye `google_desktop_auth_stub.dart`, necesario para compilar la web)

Añade a `.gitignore`:
```
android/key.properties
android/app/*.jks
```

## 2. Firma del APK (para que Android lo trate como una app normal)
Una sola vez, en tu PC (guarda el archivo y las contraseñas: si los pierdes no podrás actualizar):
```
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
En PowerShell, para obtener el archivo en base64:
```
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) | Set-Clipboard
```
Edita `android/app/build.gradle.kts` (Kotlin DSL; si usas `build.gradle` con Groovy, dímelo):
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ...lo que ya tienes...
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```
(Los imports van al principio del archivo; `signingConfigs` y `buildTypes` dentro de `android { }`.)

## 3. Secretos del repositorio
GitHub → Settings → Secrets and variables → Actions → New repository secret:
| Nombre | Valor |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | el base64 del .jks |
| `ANDROID_KEYSTORE_PASSWORD` | contraseña del keystore |
| `ANDROID_KEY_PASSWORD` | contraseña de la clave |
| `ANDROID_KEY_ALIAS` | `upload` |

**Client Secret de Google:** ya no va en la app ni en GitHub. Vive solo en el Worker de Cloudflare (ver `worker/LEEME.md`).
En `auth_service.dart` solo va la dirección pública del Worker.

## 4. Activar la web
- Repositorio → Settings → Pages → *Build and deployment* → Source: **GitHub Actions**.
- GitHub Pages gratis requiere que el repositorio sea **público**.
- Firebase Console → Authentication → Settings → *Authorized domains* → añade `ialfanjaring.github.io`.
- Para la web hace falta una app «Web» en el proyecto de Firebase (`flutterfire configure`) y que
  `lib/firebase_options.dart` incluya la configuración web.

## 5. Publicar
```
git tag v1.0.0
git push origin v1.0.0
```
Sigue el progreso en la pestaña **Actions**. Para actualizar, sube la versión en `pubspec.yaml`
(`version: 1.0.1+2`) y crea otra etiqueta.

## Avisos al instalar
- **Windows:** sin un certificado de firma de código de pago, SmartScreen mostrará «Windows protegió tu PC»
  (Más información → Ejecutar de todas formas).
- **Android:** un APK fuera de Google Play siempre pide permiso para instalar desde el navegador y puede mostrar
  el aviso de desarrollador no verificado. Con una firma propia fija (paso 2) los avisos son los mínimos.
