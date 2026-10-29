# 1.2.46+1050 — TV sin achicar el vídeo

El diseño anterior reservaba columnas para volver/lista y una fila inferior para
controles. Eso reducía el rectángulo del vídeo, como en la captura del usuario.

Ahora el vídeo ocupa todo el espacio del player tanto al abrir TV como al mostrar
la lista. La lista derecha, el título y los controles se superponen; no hay una
columna ni una fila que quite tamaño al vídeo. No se recrea el motor al abrirlos.

- Inicio a pantalla completa, sin lista permanente.
- Toque sobre vídeo u OK/flechas del mando: mostrar la lista y controles.
- Navegación con flechas mantiene la interacción activa.
- Tras 4 segundos de inactividad se ocultan, sin cambiar el tamaño del vídeo.
- Botón Ocultar controles o toque sobre el área de vídeo: ocultarlos manualmente.
- Atrás desde vídeo sin controles muestra la interfaz; otro Atrás permite salir.
- Se mantienen selección de canales, EPG, audio, subtítulos con color/tamaño,
  anuncios y único motor ExoPlayer estándar.

No se aplica zoom/crop para eliminar bandas que vengan dentro de la señal ni se
inventa un modo de cambio de relación de aspecto. Esta corrección elimina la
reducción causada por el layout de TV Nova3.

Descarga Source code (zip) de esta versión y usa una carpeta nueva si migras desde
una edición con motores antiguos. Conserva tu marca, applicationId, key.properties
y el mismo keystore de producción. Ejecuta flutter clean, flutter pub get y tu
generador habitual. No se necesita cambiar la firma.

Pruebas añadidas: test/nova3_live_overlay_test.dart (640×360 y 1280×720), verifican
que el área de vídeo sea la misma con lista abierta/cerrada y al cambiar canal.
Sintaxis comprobada; no hay SDK Flutter/Android aquí: analyzer, Flutter tests,
compilación APK y pruebas del mando en TV real pendientes.
