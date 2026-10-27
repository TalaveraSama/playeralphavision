# Avisos y recordatorio de descanso — APK 1.2.42+1046

## Instalar el panel sin perder tu configuración

1. Respalda tu `index.php` y `config.json` del servidor.
2. Conserva tu `$PASSWORD` y reemplaza **solo `index.php`** por el de este paquete.
3. No borres ni reemplaces `config.json`, `.htaccess`, carpetas de APK/updates o marcas.
4. Abre el panel con Ctrl+F5. En **Avisos y descanso**, activa el recordatorio y guarda en el servidor.
5. Compila e instala la app nueva: el panel no añade esta función a un APK antiguo.
   Conserva tu `remoteConfigUrl` y tu configuración de marca al compilar.

## La nota de descanso

- Ajustes iniciales del JSON incluido: activada, **240 minutos / 10 segundos**.
- Título `Consejos`, botón `Continuar usando`, ventana gris con botón azul.
- El tiempo se acumula desde iniciar sesión mientras la app está en primer plano.
  Navegar y cambiar de canal no lo reinicia. No es un temporizador exclusivo de vídeo.
- Continuar reinicia las cuatro horas. Sin respuesta se abandonan las rutas de vídeo;
  Android solicita cerrar la actividad, iOS permanece en Inicio porque no permite
  cerrar una app por código. No se borra la cuenta ni se fuerza un logout.
- El contador de sesión se reinicia al cerrar completamente la app. No es un control
  parental persistente. En segundo plano no avanza ni el plazo ni la cuenta atrás.
- Título, texto, botón, intervalo y cuenta atrás se editan en **Avisos y descanso**.
  Variables del texto: `{hours}`, `{minutes}`, `{seconds}`.
- Para probar rápidamente, usa **1 minuto**; al terminar vuelve a **240**.
- `ejemplo-descanso.json` es un fragmento para **fusionar**, nunca reemplaces con él
  el JSON completo de tu marca. Configuraciones antiguas sin esta sección no
  activan el recordatorio hasta recibir los valores nuevos del panel/paquete.

## Publicidad sobre el reproductor actual

Los dos JSON del repositorio eran válidos, pero tenían `ads.enabled=false`,
`ads.inPlayer=false` y `ads.ads=[]`: no podían mostrar anuncios. Además, faltaba
la integración de la franja en Media3/ExoPlayer. Ahora se conecta sin cambiar ni
eliminar ningún motor. Los avisos publicitarios de esta franja se integran en
**Media3/ExoPlayer**, no se promete la misma franja en los motores alternativos.
El recordatorio de descanso es global, independiente del motor y de los anuncios.

Para un aviso de texto, usa **Anuncios → Añadir aviso de texto sobre el vídeo**,
escribe su Texto y guarda. El botón activa anuncios, avisos en reproductor y Overlay.
También puedes hacerlo manualmente: `ads.enabled=true`, `ads.inPlayer=true`,
`ads.placements.overlay.enabled=true` y un anuncio `type=message`, `enabled=true`,
con `text` no vacío. Para imágenes usa `type=image` y `mediaUrl`.

- Se respetan topes horarios de Overlay, diarios por anuncio y segmentación.
- Rotación de varios mensajes/imágenes: `rotationSeconds`.
- `inPlayerSeconds=0` no fija un anuncio eternamente: permite la franja durante
  la reproducción, pero los topes siguen teniendo prioridad. Un valor positivo
  limita su ventana visible desde abrir/cambiar el contenido.
- Los vídeos publicitarios no se reproducen encima del vídeo principal.
- La franja es informativa, no roba foco al mando ni abre enlaces al pulsar OK.
- Las ubicaciones comparten la lista de anuncios del JSON; no existe selección
  de ubicación por creativo. No confundas Overlay con Interstitial/Preroll.
- No se activa publicidad de ejemplo automáticamente ni se inventan URLs.

## Validación pendiente en tu equipo

Aquí se comprobaron sintaxis Dart/PHP/JavaScript, JSON y renderizado lógico de las
pestañas del panel. **No hay SDK Flutter ni runtime PHP en este entorno**: no se
compiló APK ni se ejecutaron analyzer, pruebas Flutter o el servidor PHP.

```sh
flutter pub get
flutter analyze
flutter test test/usage_reminder_test.dart test/player_notice_rotation_test.dart
flutter test
flutter build apk --release
```

Prueba en TV: abrir vídeo, poner intervalo 1 minuto, pulsar OK en Continuar,
y repetir dejando vencer los 10 segundos. Verifica también segundo plano,
rotación/topes del aviso y cambio de canal. Luego restaura 240 minutos.
