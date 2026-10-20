# playeralphavision

Dos cosas en este repo:

1. **`android/`** — app Android nueva (Kotlin + Compose + Media3) que consume el API
   de **XUI.one** (Xtream Codes): TV en vivo con EPG, películas y series.
2. **`tools/`** — pipeline para **decompilar y auditar** `Alpha-Vision-1.2.21.apk`
   (el APK original del usuario), pendiente de recibir el archivo.

---

## 1. App Android — Alpha Vision

| | |
|---|---|
| Lenguaje | Kotlin 2.0 · Jetpack Compose (Material 3) |
| Reproductor | Media3 / ExoPlayer (HLS + MP4/MKV) |
| Red | OkHttp |
| Módulos | `:core` (Kotlin puro, testeable en JVM) · `:app` (UI + Android) |
| mínSdk | 26 (Android 8.0) |

```bash
# probar el API sin panel real
tools/run_mock.sh --port 8099 --public-host 10.0.2.2

# compilar y correr las pruebas del núcleo (34 checks)
tools/verify_core.sh
```

Luego abre `android/` en Android Studio y entra con `http://10.0.2.2:8099` /
`demo` / `demo`. Detalles en [`android/README.md`](android/README.md) y
[`docs/XUI_API.md`](docs/XUI_API.md).

**Verificado en este repo:** el módulo `core` compila con `kotlinc 2.4.21` y pasa
34 comprobaciones (JSON, URLs, login, catálogo, series, EPG base64 y streaming
real contra el mock: HLS, segmentos `.ts`, MP4 con `Range`). La capa Compose/Media3
no se pudo compilar aquí porque el sandbox no tiene Android SDK; se validó
sintaxis y estructura, no el APK final.

### Qué implementa

- Login contra `player_api.php`, con `Expired` / `Disabled` / `Banned`.
- Sesión persistente (DataStore) y restauración al arrancar.
- **TV**: categorías, búsqueda, lista de canales, EPG del canal (base64
  decodificado) y reproducción HLS.
- **Películas**: carátulas, categorías, búsqueda, extensión real del panel.
- **Series**: temporadas/episodios; reproduce el episodio con su propio `id`.
- Reproductor con User-Agent propio, buffer, `keepScreenOn` y liberación correcta.

Falta: catch-up/timeshift en UI, favoritos y “continuar viendo”, cifrado de la
contraseña con Keystore, control parental, Chromecast/PiP/offline.

### Mock del API (`mock_xui/`)

Servidor Python sin dependencias que replica `player_api.php`, `get.php`,
`xmltv.php`, `/live/…m3u8`, `/movie/…`, `/series/…`, con **media real** generada
por ffmpeg (`mock_xui/make_media.sh`). Incluye:
- EPG con títulos en base64, como el panel real.
- `stream_id` como string, categorías vacías `{}`, carátulas `"null"`:
  los casos que rompen los clientes hechos a mano.
- `--dump fixtures/` para generar respuestas de ejemplo y testear offline.
- Soporte de `Range` en MP4 (necesario para que ExoPlayer pueda buscar).

---

## 2. Decompilación del APK original (pendiente)

`Alpha-Vision-1.2.21.apk` pesa 140 MiB y el conector de Drive rechaza archivos
> 100 MiB, así que hay que subirlo **en 2 partes**:

1. Clic derecho en el APK → **7-Zip → Dividir archivo…** → tamaño **`70M`**.
2. Sube `Alpha-Vision-1.2.21.apk.001` y `.002` a la carpeta `alphavisionap` de
   Drive (o usa ZArchiver en Android: ZIP dividido en 70 MB).

Cuando estén:

```bash
# deja las partes en parts/
tools/decompile.sh --parts parts --out decompiled/apktool
```

`tools/decompile.sh` une las partes, valida tamaño y ZIP, y decompila con
apktool 2.9+. `tools/audit.py` genera `AUDIT.md` con **lo que le falta al código**:

| área | qué detecta |
|---|---|
| clases faltantes | actividades/servicios/providers del manifest sin `.smali` |
| nativas | `loadLibrary("x")` sin `lib/libx.so`; `.so` solo en algunas ABIs |
| recursos | `@string`/`@drawable`/`@layout` inexistentes; IDs `0x7f……` fuera de `public.xml` |
| reflexión | `Class.forName()` a clases del propio APK que no existen |
| assets | ficheros referenciados en código y ausentes en `assets/` |
| ofuscación | % de clases con nombres de 1–2 letras (R8/ProGuard) |
| seguridad | componentes exportados, permisos sensibles, firma v1 |

Probado de punta a punta con un APK real (340 clases) y con un fixture que
provoca los 8 tipos de fallo: sin falsos positivos.

---

## Requisitos

- Android Studio (Ladybug+) con JDK 17+
- Python 3.9+ (mock y auditoría; solo stdlib)
- `ffmpeg` para la media del mock (`mock_xui/make_media.sh`)
- Opcional: `kotlinc` para `tools/verify_core.sh`; `apktool.jar` 2.9+ y JDK para
  `tools/decompile.sh`
