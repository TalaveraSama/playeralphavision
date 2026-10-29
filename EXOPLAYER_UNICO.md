# 1.2.45+1049 — ExoPlayer como único motor Android

## Alcance solicitado

Se retiraron VLC, IJK, MPV/media_kit, el reproductor DK alternativo, sus puentes
nativos y la extensión Nextlib/FFmpeg. Se usa `DefaultRenderersFactory` de
ExoPlayer con extensiones desactivadas y fallback entre decodificadores estándar
del dispositivo. No hay salto oculto a otro motor ni selector de motores.

ExoPlayer estándar se integra mediante **AndroidX Media3**. No se rebaja al antiguo
paquete `com.google.android.exoplayer2`: Media3 mantiene ExoPlayer como motor.
Se conserva la textura Flutter estable y los subtítulos temporizados con el color
/tamaño del perfil, así como anuncios Overlay, descanso y orientación horizontal.
Audio y subtítulos tienen botones separados; si no hay pistas compatibles se avisa.
La navegación con mando, lista de canales, EPG y pantalla completa siguen disponibles.

IPTV Smarters Pro se toma solo como referencia funcional de un reproductor IPTV:
controles claros, cambio de canal, pistas y pantalla completa. No se copiaron sus
recursos, marca, código ni se afirma reproducir exactamente su diseño. La interfaz
Nova3 aceptada se conserva; un rediseño visual idéntico no forma parte de este cambio.

## Compatibilidad

- Esta edición reproduce **solo en Android/Android TV/Fire TV compatibles**.
- ExoPlayer no existe para iOS: al retirar VLC también se retira la solución de
  reproducción de iPhone que se había preparado en 1.2.43. En iOS se muestra un
  aviso, no se intenta abrir el canal nativo de Android. `GUIA_IPHONE.md` es histórica.
- Sin FFmpeg, formatos como ciertos AC3/EAC3/DTS/MP2 y variantes HEVC dependen del
  soporte del dispositivo. Puede haber canales sin audio/imagen que antes funcionaban.
- No se añade transcodificación, DRM nuevo ni configuración UDP de interfaz dedicada.
- `video_player` se conserva para anuncios de vídeo y usa su implementación ExoPlayer
  en Android; no vuelve a introducir VLC/MPV/IJK como motores alternativos.
- Valores antiguos `player.engine`, `player.video_decoder`, `features.vlcPlayer`
  y `features.dkPlayer` no vuelven a activar motores eliminados.

## Instalar el código sin conservar restos

1. Respalda tu proyecto y claves. Extrae el **Source code ZIP en una carpeta NUEVA**.
   No lo descomprimas encima de la anterior: quedarían clases Kotlin de IJK/DK y
   archivos de plugins que ya no tienen dependencias y pueden romper el build.
2. Lleva solo tu configuración de marca (`admin_panel/config.json`, o el JSON de
   tu marca), `android/key.properties` local y los ajustes propios necesarios.
   Conserva tu keystore externo. No copies páginas de players viejos ni caches.
3. Mantén el mismo applicationId y la misma firma si vas a actualizar tu app.
4. Desde la carpeta nueva:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
```

5. Ejecuta `admin_panel/Generar APK.cmd` como siempre. El lock se limpió de las
   dependencias retiradas; `flutter pub get` debe resolver/verificar el grafo final
   y regenerar los archivos de plugins. No se ejecutó el resolvedor aquí.
6. Actualiza también el index del panel si quieres eliminar la casilla antigua de
   motor secundario. Conserva la contraseña y config.json del servidor.

## Validación

Pasaron sintaxis Dart y Kotlin, estructuras JSON/YAML, chequeos estáticos de motor
único y firma, y regresiones JavaScript del panel. Nuevas pruebas de configuración
antigua y conservación de subtítulos en `test/exoplayer_only_test.dart`.

**No hay SDK Flutter/Android aquí:** no se ejecutaron pub get, analyzer, tests
Flutter, Gradle ni compilación APK. No se promete un tamaño exacto ni compatibilidad
universal por retirar librerías. Prueba TV real y móvil: login, canales TS/HLS,
audio, cambio de pista, subtítulos/color/tamaño, pausa/seek, pantalla completa,
salida/entrada, anuncios y recordatorio. Comprueba dispositivos con y sin AC3/HEVC.
