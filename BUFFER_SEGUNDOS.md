> **Actualización 1.2.56:** el reproductor principal ahora es LibVLC. Este documento describe una versión anterior; las diferencias y límites actuales están en [REPRODUCTOR_VLC.md](REPRODUCTOR_VLC.md).

# 1.2.48+1052 — búfer por tiempo e inicio más corto

Ajustes → Reproducción → Búfer de reproducción ofrece **10, 20 o 30 segundos**,
con **10 segundos por defecto**. Se retiran las opciones 8/32/64 MB. La elección
se guarda por dispositivo y se aplica al volver a abrir el reproductor.

Antes, el ajuste visible en MB no se enviaba al motor actual. Media3 tenía valores
fijos (mínimo 8 s, máximo 40 s, umbral de inicio 1,5 s y rebuffer 3 s).
Ahora el ajuste sí viaja por el canal nativo y configura DefaultLoadControl:

| Selección | Mínimo de carga | Reserva máxima | Umbral inicial | Tras rebuffer |
|---|---|---|---|---|
| 10 s | 5 s | 10 s | 0,5 s | 1 s |
| 20 s | 10 s | 20 s | 0,5 s | 1 s |
| 30 s | 15 s | 30 s | 0,5 s | 1 s |

La reserva máxima **no obliga a esperar a llenarla**. El mínimo de carga controla
cuándo seguir cargando; no es una puerta que obligue a esperar antes de iniciar.
Se priorizan umbrales por tiempo sobre tamaño. ExoPlayer sigue usando memoria:
esto no elimina sus buffers internos ni garantiza un consumo fijo de RAM.
Los valores en MB guardados por versiones antiguas se ignoran, no se convierten
a segundos sin conocer el bitrate; se arranca con el nuevo predeterminado 10 s.

Un umbral de 0,5 s de contenido NO significa vídeo visible en 0,5 s reales.
Servidor, autenticación, red, manifiesto/segmentos HLS, fotogramas clave y codec
pueden retrasar el primer frame. Este ajuste no elimina el retraso que ya trae
la emisión ni configura una salida UDP. Menos precarga también puede causar más
cortes en redes inestables. Prueba 10 s y compara con 20/30 s en el mismo canal.

Se conserva ExoPlayer único, selector hardware, pantalla completa, subtítulos con
estilo, configuración de marca y firma. No se modifica la caché de imágenes,
que es independiente de la reserva de vídeo. No se añaden motores ni FFmpeg.

Compila conservando JSON de marca, applicationId y key.properties/keystore. Ejecuta
flutter pub get, flutter analyze, flutter test y tu Generar APK.cmd habitual.

Validación estática de sintaxis/canal y pruebas de valores/persistencia añadidas
(playback_buffer_test.dart). Sin SDK aquí: no se ejecutaron Flutter tests, Gradle,
APK ni mediciones reales de primer frame. Hay que validar cambio de canal, cortes
y consumo en TV/móvil, y aumentar la reserva si la conexión lo requiere.
