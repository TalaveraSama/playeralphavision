> **Actualización 1.2.56:** el reproductor principal ahora es LibVLC. Este documento describe una versión anterior; las diferencias y límites actuales están en [REPRODUCTOR_VLC.md](REPRODUCTOR_VLC.md).

# Corrección de subtítulos — 1.2.44+1048

## Causa encontrada

El reproductor actual Media3/ExoPlayer dibuja el vídeo con SurfaceTexture.
Las pistas de subtítulos se detectaban y podían seleccionarse, pero la textura
solo contiene píxeles del vídeo: no incluye la capa de texto de ExoPlayer.
Faltaba conectar los cues temporizados con una capa visible en Flutter.

## Cambios

- Media3 envía los cues activos mediante `onCues` al reproductor Flutter.
- La capa se compone sobre la textura en películas/series y en TV Nova3, tanto
  en vista previa como a pantalla completa, sin crear otro motor/reproductor.
- El texto toma **color y tamaño** del perfil de Ajustes; reacciona a sus cambios.
  Respeta el tamaño guardado (14–40), no el estilo de fuente/color del archivo.
- Texto multilínea con sombra negra para mejorar lectura y sin capturar toques
  ni teclas. Cuando aparecen controles, el texto automático sube para despejar
  el área inferior. Las posiciones fraccionales explícitas se conservan.
- Se transportan también cues de imagen como PNG (cuando Media3 los decodifica).
  **Una imagen de subtítulo no es texto:** no permite cambiar fuente/color como
  un SRT/WebVTT. Su dibujo original se conserva.
- Se limpia el subtítulo al desactivarlo, seleccionar otra pista, cambiar de
  contenido, buscar otra posición, terminar el vídeo o recibir un error.

Este cambio se dirige al motor actual **Media3/ExoPlayer en Android**. No modifica
ni elimina VLC/IJK/MPV; no afirma aplicar preferencias de estilo a esos motores.
No añade descarga de subtítulos externos ni pistas que el proveedor no incluya.
Tampoco reconstruye texto grabado permanentemente dentro de la imagen del vídeo.
Las particularidades de tipografía ASS y posiciones por líneas/verticales no se
reproducen íntegramente: esta capa prioriza el estilo elegido por el usuario.

## Compilar y verificar

1. Usa el código 1.2.44+1048 conservando tu marca, servidor y `remoteConfigUrl`.
2. Conserva tu almacén de firma y `android/key.properties` local. Nunca compartas
   las contraseñas. La firma de producción ya es obligatoria para release.
3. Ejecuta `flutter pub get`, `flutter analyze`, `flutter test`, y compila el APK
   con tu generador habitual (o `flutter build apk --release`).
4. En Ajustes elige **Media3/ExoPlayer**. Pon subtítulos amarillos y tamaño 32.
5. Abre una película que realmente tenga subtítulos internos compatibles, entra
   en Audio y subtítulos y selecciona la pista. Avanza hasta un diálogo subtitulado.
6. Comprueba aparición/desaparición sincronizada, pausa, seek, cambio de idioma,
   Desactivados y cambio de vídeo. Repite en TV con vista previa/pantalla completa.
7. Cambia a cian/tamaño 20 y comprueba el nuevo estilo. Los subtítulos de imagen
   o grabados dentro del vídeo no pueden adoptar ese estilo.

## Validación disponible

Sintaxis de Dart y del Kotlin Media3 modificado comprobadas con parser; pruebas
Flutter añadidas en `test/player_subtitles_test.dart` para cues, posiciones, color,
tamaño, limpieza, imagen y persistencia de preferencias.

**No se ejecutaron Flutter tests, analyzer, Gradle ni APK:** no hay SDK Flutter/
Android aquí. Hay que validar sincronía y reproducción con pistas reales en TV
/teléfono. Las pruebas de widget no sustituyen un stream real ni un build nativo.
