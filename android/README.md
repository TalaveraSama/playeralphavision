# Alpha Vision — app Android (Kotlin + Compose + Media3)

Player IPTV que consume el API de **XUI.one** (Xtream Codes): login, TV en vivo
con EPG, películas y series con temporadas/episodios.

## Abrir y compilar

1. Abre la carpeta `android/` en **Android Studio** (Ladybug o superior).
2. Deja que sincronice Gradle. Si falta el wrapper:
   ```bash
   cd android && gradle wrapper --gradle-version 8.9
   ```
3. Run ▶ sobre un emulador o dispositivo (Android 8.0 / API 26 mínimo).

Sin Android Studio también sirve:

```bash
cd android && ./gradlew :app:assembleDebug
# APK en app/build/outputs/apk/debug/app-debug.apk
```

## Probar contra el mock

En la raíz del repo:

```bash
tools/run_mock.sh --port 8099 --public-host 10.0.2.2   # emulador
tools/run_mock.sh --port 8099 --public-host 192.168.1.50  # dispositivo en tu LAN
```

En la pantalla de login de la app:

| campo | valor |
|---|---|
| URL | `http://10.0.2.2:8099` (emulador) o `http://TU_IP_LAN:8099` (teléfono) |
| usuario | `demo` |
| contraseña | `demo` |

`10.0.2.2` es la IP con la que el emulador ve la máquina anfitriona; en un
teléfono físico usa la IP local de tu PC (y el mock debe estar en `0.0.0.0`).

## Estructura

```
android/
├── core/            Kotlin puro, sin Android: API, JSON, modelos, URLs
│   └── src/main/kotlin/com/alphavision/core/
│       ├── Json.kt        parser propio (sin Gson/serialization)
│       ├── XuiModels.kt   UserInfo, LiveStream, Episode, EpgEntry…
│       ├── XuiUrls.kt     URLs del API y de los streams
│       └── XuiApi.kt      cliente + parsing tolerante
└── app/             UI Compose + reproducción
    └── src/main/java/com/alphavision/player/
        ├── data/      AppContainer (OkHttp), SessionStore (DataStore), Repository
        └── ui/        Login, Home (TV/Películas/Series), detalle de serie, Player
```

El módulo `core` no depende de Android **a propósito**: se compila y prueba en
cualquier JVM con `tools/verify_core.sh` (34 comprobaciones, incluidas
integraciones HTTP contra el mock).

## Qué hace

- Login contra `player_api.php`, con manejo de `Expired/Disabled/Banned`.
- Sesión persistente (DataStore) y restauración al abrir.
- TV en vivo: categorías, búsqueda, EPG del canal (título y descripción
  decodificados de base64) y reproducción HLS.
- Películas: carátulas, categorías, búsqueda y reproducción con la extensión
  real del panel (`mp4`, `mkv`, …).
- Series: lista, detalle con temporadas y episodios; el episodio se reproduce
  con su propio `id`.
- Reproductor Media3/ExoPlayer con User-Agent propio, HLS, buffer y
  `keepScreenOn`; libera el player al salir.

## Qué falta / siguientes pasos

- **Catch-up / archivo**: `XuiUrls.catchupUrl()` está implementado pero no hay UI
  de timeshift todavía.
- **Favoritos y “continuar viendo”**: no persistidos aún (DataStore ya está).
- **Contraseña cifrada**: hoy se guarda en DataStore privado sin cifrar; mover a
  Keystore/`EncryptedSharedPreferences` para producción.
- **Múltiples cuentas / perfiles**: el modelo lo permite, la UI no.
- **Control parental y bloqueo por categoría** (`is_adult`): sin implementar.
- **Chromecast**, PiP y descarga offline: no incluidos.
- **Iconos**: `material-icons-extended`; si pesa demasiado, cambiar a
  `material-icons-core` y usar solo iconos básicos.

## Notas de seguridad

- El APK debug añade el sufijo `.debug` para convivir con la versión release.
- `allowBackup=false` para no filtrar credenciales en el backup de Android.
- Hay `usesCleartextTraffic=true` porque muchos paneles XUI.one son HTTP puro.
