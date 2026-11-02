# 1.2.56+1060 — VLC principal (vista previa de código fuente)

## Implementación

- El IPTV de Android/Android TV usa **LibVLC oficial 3.6.3**, integrado en la app mediante una textura Flutter; no exige instalar VLC aparte. Se retiraron las clases y dependencias directas de Media3 del reproductor principal.
- **No se ha eliminado ExoPlayer de todo el APK**: el paquete `video_player`, conservado para anuncios, puede incluirlo como dependencia transitiva.
- Se mantienen las pantallas horizontales existentes, vídeo de tamaño completo con controles/lista superpuestos, navegación con mando, seguimiento del canal seleccionado, selección de pistas y suspensión/cierre del reproductor al salir.
- Decodificación: automática de VLC, hardware preferido con posibilidad de alternativa de VLC y software explícito. La preferencia anterior se conserva al actualizar.
- Subtítulos: pistas SPU nativas, color y tamaño 14–40 enviados a FreeType de VLC al crear el reproductor. Los subtítulos gráficos mantienen su propio aspecto. **La visibilidad y el estilo aún necesitan comprobarse en equipos reales**, especialmente con aceleración y subtítulos embebidos.
- Se conservaron perfiles independientes, registro/token del aparato, heartbeat, revocación y manejo de errores de autorización/`Retry-After`. No se reintrodujo una integración DRM.

## Búfer y compatibilidad

Las opciones **10/20/30 segundos** configuran `adaptive-maxbuffer`, la reserva máxima del demultiplexor adaptativo HLS de VLC; **no son una espera obligatoria al iniciar**. La caché de red/live es independiente, de 300 ms. El máximo no representa el total de memoria ni aplica igual a archivos progresivos u otros protocolos. No se ha medido una mejora de velocidad o RAM frente a ExoPlayer.

El puente está orientado a **HLS y archivos HTTP(S)**. DASH, UDP, RTSP y otras formas de entrada no quedan certificados por este cambio. Se deben probar directos TS/HLS, MP4/MKV, rangos/seek, VOD, audios alternativos y manifiestos con claves/segmentos en CDN. La app no transforma un stream protegido por DRM en un stream libre.

## Seguridad del transporte

VLC recibe una ruta aleatoria de un servidor efímero **solo en loopback**, no directamente la URL con las credenciales. El puente usa `HttpURLConnection` y la política TLS de Android para las peticiones externas, reescribe URI de HLS (también claves y listas secundarias), transmite rangos y conserva errores HTTP.

`X-Device-Token`, Authorization y Cookie solo se envían al origen exacto del stream o al origen del panel declarado, incluyendo protocolo y puerto. No se envían a una CDN de otro origen. Las redirecciones HTTPS → HTTP se rechazan; el HTTP externo requiere el consentimiento de perfil existente. No se cambia el servidor ni se inventan pins. Las conexiones, rutas y tareas se cierran con el reproductor.

Esto **no es DRM ni protección absoluta** contra root/hooks/extracción; HTTP externo sigue siendo capturable y el tráfico de loopback puede observarse en un equipo comprometido. Se conservan `FLAG_SECURE` y las políticas HTTPS de la marca; siguen pendientes los pins reales actual/de respaldo.

## Referencia de diseño y licencias

Se inspeccionó el repositorio público https://github.com/TalaveraSama/decoded-xc: recursos de controles superiores/inferiores, vista de vídeo y presencia de motores nativos. Es un proyecto decodificado de recursos/smali, no un proyecto fuente convencional. **No se copiaron sus APK, bibliotecas, marcas ni recursos**. Se mantienen los diseños propios aceptados y se implementó un adaptador independiente sobre VideoLAN.

LibVLC y sus módulos tienen licencias propias. Antes de distribuir un APK, revisar y cumplir avisos, licencias y obligaciones de distribución/código fuente correspondientes a la versión utilizada: https://www.videolan.org/legal.html y https://code.videolan.org/videolan/libvlcjni. Hacer público un repositorio decompilado no concede por sí solo permiso para redistribuir sus componentes.

## Validación y compilación en Windows

Realizado aquí: comprobación sintáctica de Dart/Kotlin y scripts estáticos de arquitectura, ciclo de vida, perfiles, seguridad, ausencia de integración DRM y firma. Se añadieron tests JVM del puente: reescritura HLS/clave, token en segmentos, aislamiento entre orígenes y rechazo de HTTP sin consentimiento.

**No ejecutados aquí**: compilación Kotlin/Flutter, analizador de Dart, tests Flutter/JVM, generación de APK ni pruebas de reproducción. No hay JDK/Flutter/SDK Android en este entorno. Los checks sintácticos no sustituyen esas pruebas.

Desde la raíz del proyecto, con Flutter, JDK 17 y SDK Android configurados:

```bat
flutter pub get
flutter analyze
flutter test
cd android
gradlew.bat :app:testDebugUnitTest
cd ..
admin_panel\Generar APK.cmd
```

Conservar `applicationId`, `android/key.properties` y la misma llave de firma anterior. No subir llaves ni contraseñas al repositorio.

Pruebas de aceptación: abrir/cambiar canales con mando, enseñar/ocultar lista sin reducir vídeo, hardware/automático/software (incluido Fire TV), pistas de audio y subtítulos de texto/gráficos, color/tamaño, VOD/seek, salir/Home/reanudar, cierre sin audio residual, HLS con CDN/claves/redirect/rangos y rechazo 401/403/429/revocación. Comprobar además perfiles HTTP y HTTPS y anuncios. Esta versión se publica como **vista previa de fuente**, no como APK probado.
