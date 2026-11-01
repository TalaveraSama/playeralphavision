# 1.2.49+1053 — Lista sincronizada y cierre del reproductor

- Nova3 conserva el vídeo a tamaño completo. Al despertar la franja de canales o cambiar el canal reproducido, desplaza la lista hasta la fila actual y después le entrega el foco del mando. No se cambia de canal simplemente al recorrer la lista; hay que pulsar OK.
- La lista utiliza filas de tamaño fijo, controlador de desplazamiento y nodos de foco propios. La fila puede estar muy lejos del inicio: se construye antes de solicitar foco. La navegación mantenida con flechas renueva el plazo de ocultación.
- Al pasar la aplicación a segundo plano, se cancelan reintentos, salto automático y sondeo; se detiene ExoPlayer, incluida la carga del stream. Android también lo hace desde `onStop`, sin depender únicamente de Flutter.
- Al volver a la aplicación se prepara nuevamente el contenido. Se mantiene la pausa manual; si estaba reproduciendo, continúa. En directo vuelve al punto de emisión disponible.
- Al abandonar la pantalla se anula el canal de eventos, se cancelan todos sus temporizadores y se libera el reproductor. Al destruir la actividad o separar el motor Flutter, el host libera todos los reproductores, superficies y texturas. La liberación admite llamadas repetidas.
- Las respuestas de cargas antiguas ya no pueden iniciar la reproducción después de cambiar de canal, cerrar la pantalla o pasar a segundo plano.

## Comprobación

Incluidos `test/nova3_channel_sync_test.dart` (200 canales, selección 80/150/190 y reapertura), pruebas previas de geometría del vídeo y `tools/check_player_lifecycle.py` (comprobaciones estáticas).

Se comprobaron sintaxis Dart/Kotlin y las verificaciones estáticas de motor, firma y ciclo de vida. Este entorno no tiene Flutter, SDK Android ni dispositivo: **no se ejecutaron los tests Flutter, no se compiló APK y falta validación real**.

En Windows, ejecutar `flutter pub get`, `flutter analyze`, `flutter test test/nova3_channel_sync_test.dart test/nova3_live_overlay_test.dart` y compilar con `admin_panel\Generar APK.cmd`, conservando la firma de producción.

Prueba manual: abrir un canal de número alto, cambiar con CH+/CH−, ocultar/despertar la lista y navegar con el mando. Pulsar Inicio, cambiar a otra app, regresar, salir con Atrás y quitar la app de recientes: no debe quedar audio ni reproducción en segundo plano. Repetir con una película pausada, con un canal caído durante reintentos y saliendo inmediatamente mientras se abre un canal. El cierre forzado del proceso por Android lo gestiona el propio sistema; no se presupone que siempre entregue un callback Dart.
