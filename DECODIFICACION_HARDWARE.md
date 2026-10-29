# 1.2.47+1051 — decodificación opcional en ExoPlayer

En Ajustes → Reproductor → Decodificación de vídeo:

- **Automático** (predeterminado): selección normal de ExoPlayer.
- **Hardware preferido**: ordena primero los decodificadores de vídeo que Android
  identifica como acelerados. Mantiene alternativas del sistema y fallback si
  falla la inicialización de un decodificador. No garantiza solucionar errores
  durante la reproducción ni ofrece hardware para códecs no soportados.
- **Software de Android**: filtra los decodificadores de vídeo a los que Android
  identifica como software. No incluye FFmpeg, VLC, IJK ni MPV. Si no existe un
  decodificador software compatible, ese formato no se reproducirá. Vuelve a
  Automático o Hardware preferido en ese caso.

Se guarda por dispositivo, no por canal. Se aplica al salir y volver a abrir el
reproductor, no recrea el motor mientras miras un vídeo. El audio conserva la
selección estándar de ExoPlayer. No se afirma que esté usándose hardware solo
porque el usuario lo prefiera: la elección final depende del equipo y del flujo.

## No confundir con transcodificación ni copy/copy

Esta opción es para **reproducir**, según la elección confirmada por el usuario.
No hay encoder, archivo/salida nueva ni retransmisión UDP. La app descarga el flujo
original y lo decodifica para mostrarlo y escucharlo; no lo vuelve a codificar.
`video copy / audio copy` corresponde a otra función de remultiplexado o salida,
no a un modo que pueda mostrar vídeo sin decodificarlo. No se añadió una casilla
copy que fingiera hacer esa función.

Se mantiene ExoPlayer como único motor, vídeo completo, lista superpuesta,
subtítulos/color/tamaño y firma de producción. Compila con tu generador habitual,
conservando marca, applicationId, key.properties y keystore.

Validación disponible: sintaxis Dart/Kotlin y chequeos de motor único/firma.
Pruebas de valores y persistencia añadidas en video_decode_mode_test.dart.
Sin SDK Flutter/Android aquí: analyzer, pruebas Flutter, build y uso real de
MediaCodec quedan pendientes en móvil/TV. No se incluye APK compilado.
