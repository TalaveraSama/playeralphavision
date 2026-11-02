# 1.2.56+1060 — VLC principal (2026-11-02)

Reemplazo independiente sobre LibVLC oficial 3.6.3, textura de vídeo completa, controles existentes, audio/SPU, decodificación auto/hardware/software y reserva HLS 10/20/30 s. Puente loopback para conservar TLS Android, tokens por origen exacto y errores HTTP. Se conservan perfiles y seguridad sin integración DRM. Tests JVM añadidos; sintaxis y checks estáticos ejecutados, pero no hay compilación ni prueba de dispositivo/APK. ExoPlayer puede permanecer para anuncios. Detalles: [REPRODUCTOR_VLC.md](REPRODUCTOR_VLC.md).

> Las reglas/notas de motores anteriores que siguen debajo son **históricas**; no representan el motor actual. El cambio a VLC fue solicitado explícitamente por el usuario.

---

# CHANGELOG / ANOTADOR DE CAMBIOS — Alpha Vision Digital

> Este archivo es la memoria del proyecto. **Léelo antes de tocar el reproductor.**
> Si un cambio rompe algo de aquí, se revierte.

---

## ⚠️ REGLAS DE ORO (no romper)

### 🎬 REPRODUCTOR (live + películas) — mpv / media_kit

**Todo el contenido (canales en vivo y películas) usa `PlayerMpvPage` (mpv/media_kit).**

| Regla | Por qué |
| --- | --- |
| **Render adaptativo según el dispositivo** (`_videoConfig()` en `player_mpv_page.dart`) | ⭐ HALLAZGO 2026-10-17: en el **Fire TV Stick** el render **hardware** de mpv (mediacodec/OMX) decodifica pero **NO engancha el surface** → **pantalla negra** (`AHierarchicalStateMachine ... event = 3`). Solución: **Fire TV / Amazon → software** (`enableHardwareAcceleration: false`); **otras Android TV → hardware** (rápido, 4K). Se detecta con `device_info_plus` (`manufacturer`/`brand` contienen "amazon" o `model` empieza por "AFT"). |
| El `VideoController` debe crearse con `configuration:` (nombrado) | `VideoController(player, configuration: _videoConfig())` — el 2.º parámetro NO es posicional. |
| mpv expone **todas las pistas de audio** del TS (el player de textura/Media3 solo veía 1) | El live tiene 2 AAC PIDs en el PMT; Media3 dejaba 1 ("Pista 1"). mpv las lista y permite cambiar. |
| No volver al `PlayerTexturePage` para el live sin necesidad | El live actual funciona con mpv + software render. |

> ❌ **NO tocar el "arranque rápido" de mpv** (`demuxer-lavf-probesize`,
> `demuxer-lavf-analyzeduration`, `demuxer-readahead-secs` corto).
> Se probó el 2026-10-19 para que los canales SD entraran antes y **empeoró**:
> muchos canales dejaron de entrar o entraban inestables. El player que mejor
> funciona en el Fire TV Stick es el de siempre:
> `cache=yes`, `demuxer-max-bytes=48MiB`, `demuxer-readahead-secs=45`.
>
> ❌ **NO volver a poner el "vigía de congelación" (freeze detector) en el live.**
> Se probó el 2026-10-18: un `Timer.periodic(5s)` comparando la posición deja
> disparar `_scheduleReconnect()` (que espera 3 s y reabre el stream) aunque el
> canal esté bien, y el resultado es **parpadeo cada pocos segundos**.
> Si el panel reinicia un canal y la imagen queda pegada, **el usuario cambia
> de canal y vuelve**, o se pulsa Atrás y se reabre. No automatizar con timer.

> ⚠️ El player de textura (`Media3TexturePlayer`) queda en el repo por si hay que volver,
> pero **ya no se enruta**. Si se usara: vídeo `DecoderMode.FFMPEG` fijado UNA sola vez
> (sin cambio en caliente), sin `onCues`/`seekTo`, render por Textura de Flutter.

### Enrutado — `open_player.dart`

```dart
// TODO (live + VOD) -> PlayerMpvPage (mpv)
builder: (_) => PlayerMpvPage(
  playlist: playlist,
  initialIndex: initialIndex,
  headers: app.headers,
  mediaType: mediaType,
  categoryName: categoryName,
),
```

---

### 🎬 Reproductor ijkplayer (alternativa al mpv) — 2026-10-19

El live se enruta ahora a `PlayerIjkPage` (ijkplayer/FFmpeg), el mismo motor que usan
Xuper e IPTV Smarters. Elegido tras analizar ambas APK (ver
`ott_apixcode/apk/INFORME_PLAYERS.md`).

- Paquete: **`fijkplayer_plus: ^0.0.1`** (fork mantenido). El `fijkplayer` 0.11 **NO compila**
  con Flutter 3.47 (usa `PluginRegistry.Registrar`, API eliminada).
- Parche necesario en el paquete (pub cache): `android/build.gradle` → `compileSdk 35`,
  `minSdk 24`, `lint {}`, `compileOptions` Java 17.
- Opciones aplicadas en `player_ijk_page.dart`:
  `start-on-prepared=1`, `framedrop=1`, `packet-buffering=1`, `infbuf=1`,
  `probesize=1000000`, `analyzeduration=2000000`, y las cabeceras HTTP vía
  `formatCategory 'headers'`.
- El mpv (`PlayerMpvPage`) sigue en el repo; para volver basta cambiar
  `PlayerIjkPage` → `PlayerMpvPage` en `open_player.dart`.

---

### 🎬 REPRODUCTOR ACTUAL (2026-10-19): Media3 / ExoPlayer

**Live y VOD usan `PlayerTexturePage` + `Media3TexturePlayer` (Media3/ExoPlayer), el mismo motor que IPTV Smarters.** Se descartaron mpv e ijk para el enrutado (siguen en el repo como respaldo).

| Fallo | Causa | Solución |
| --- | --- | --- |
| Barra de minutos en 0 | El polling llamaba a `getPosition` en el canal **host** (`media3_player`), pero el método vive en el canal **del player** (`media3_player_<id>`) → `notImplemented` silenciado por el `catch` | Usar `_channel.invokeMethod('getPosition')` |
| Barra no aparecía | El polling arrancaba en `initState`, antes de crear el player (`_playerId == 0`) | Arrancar el polling **después** de `start()` |
| ⏩ reiniciaba la película | `_seek` hacía `clamp(0, _durMs > 0 ? _durMs : 0)`; en vivo `_durMs=0` → destino 0 ms | `if (isLive) return;` y `if (_durMs <= 0) return;` |
| Duración negativa | `player.duration` devuelve `C.TIME_UNSET` (negativo enorme) en vivo | `maxOf(0L, player.duration)` en el nativo |
| Flechas hacían seek | `arrowLeft/Right` mapeadas a `_seek` | Flechas = navegación de foco; seek solo con ⏪/⏩ |
| Controles sin foco | El `HardwareKeyboard` handler se comía el D-pad | Con controles visibles → `return false` para que navegue el foco |

Nativo añadido al canal `media3_player_<id>`: `seekTo`, `getPosition` (devuelve `pos` y `dur` saneados).

---

## 🔑 XUI.one / Streams

| Tema | Valor |
| --- | --- |
| **User-Agent** | `AlphaVision-Player` (config `xtream.userAgent`; se fuerza con `setUserAgent` en el `DefaultHttpDataSource` del player de textura) |
| **Access Token** | **Opcional**. Vacío = usa `usuario/clave`. |
| **URL live** | `http://173.208.183.66:80/live/{user}/{pass}/{id}.m3u8` |
| **URL play** | `http://173.208.183.66:80/play/{token}/m3u8` (también sirve) |
| **Playlist** | HLS con **AES-128** (`#EXT-X-KEY`) y segmentos relativos `/hls/...`; clave en `/key/...` |
| **Audio** | Algunos canales traen **2 pistas AAC sin etiqueta de idioma** (el PMT no tiene `ISO_639`) → se muestran como "Pista 1 / Pista 2" |
| **Canal caído** | El panel devuelve un playlist **vacío** (`''`) → el player muestra "Canal no disponible (sin emisión)" y salta solo al siguiente a los 5 s |

> Si un canal no reproduce: primero verifica en el navegador que `.../{id}.m3u8` devuelva `#EXTM3U`. Si devuelve vacío → **el canal está caído**, no es la app.

---

## 🖼️ Imágenes — `net_image.dart`

- Usa `cached_network_image` (caché **memoria + disco**).
- **NO** re-añadir la cola propia (`_ImageQueue`, max 4): al re-entrar a una pantalla volvía a pintar el marcador gris y parecía que "recargaban".
- `fadeInDuration: 0` + `useOldImageOnUrlChange: true` → aparecen al instante desde caché.
- `memCacheWidth` se mantiene para no reventar la RAM del Fire TV (1 GB).

---

## 🎨 Inicio (home) — `nova_discover_page.dart`

- Carrusel grande = **Últimas películas** (`_latestMovies`, orden por `added`).
- Se **quitó** la sección suelta "Últimas películas".
- Después va **"En vivo ahora"**.
- Escala TV: `NovaMetrics.tv => 0.85`.
- `NeonFocus` sin `AnimatedScale` (el "pulso" parecía luciérnaga).

---

## 👤 Perfil → Subtítulos

- Color: blanco (defecto), amarillo, cian, verde.
- Tamaño: slider 14–40 (defecto 22).
- Se guardan en prefs (`player.subtitle_color`, `player.subtitle_size`).

---

## 📌 Pendientes

- Subir `index.php` actualizado al aaPanel (secciones nuevas: pestañas, TMDB, streamToken).
- Probar películas (mpv) con subtítulos y audio en español.
- Token por usuario (campo en login) — ahora es global/opcional.
- Confirmar cambio de pista de audio en el canal de 2 audios.

---

## Historial

| Fecha | Cambio |
| --- | --- |
| 2026-10-17 | ⭐ **LIVE + VOD con mpv y render adaptativo** (Fire TV/Amazon = software; otras Android TV = hardware). Vídeo perfecto en Fire TV. |
| 2026-10-17 | Render adaptativo por dispositivo (`device_info_plus`): sirve para varios modelos de Android TV. |
| 2026-10-17 | Todo el contenido se enruta a `PlayerMpvPage` (expone las 2 pistas de audio). |
| 2026-10-17 | Imágenes: fuera la cola propia → ya no "recargan". |
| 2026-10-17 | Inicio: carrusel = últimas películas, sin sección suelta. |
| 2026-10-17 | Live: aviso "Canal no disponible" + salto automático. |
| 2026-10-17 | UA `AlphaVision-Player` + Access Token opcional. |
| 2026-10-17 | Live: vuelta a FFmpeg software sin cambio en caliente (sin parpadeo/crash) — *histórico del player de textura*. |
