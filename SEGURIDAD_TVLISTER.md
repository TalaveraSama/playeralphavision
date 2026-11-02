# 1.2.50+1054 — Integración de seguridad TVLister (PREVIEW)

Contrato seguido: [SEGURIDAD_PLAYER_APP_INDICACIONES.md](https://github.com/TalaveraSama/tvlister24-7/blob/arena/85cc9902-tvlister24-7/docs/SEGURIDAD_PLAYER_APP_INDICACIONES.md), consultado para esta implementación.

**NO es una entrega de «seguridad cerrada»**: falta configurar el dominio/pines reales, compilar con Android/Flutter y pasar las 15 pruebas contra una línea de pruebas del panel. No instalar masivamente todavía. No hay APK compilado en este entorno.

## Player

Se conserva el único motor ExoPlayer/Media3: no se agregan VLC, FFmpeg, IJK ni otro motor. Cambiar el motor no demostraría que los saltos desaparezcan. Se retira el trabajo inútil de construir volcados de pistas y se activa R8/reducción de recursos en release; el tamaño y rendimiento aún no se han medido. Se mantienen vídeo completo, foco/lista sincronizados, buffer de 10/20/30 s, subtítulos y controles.

Al cambiar de canal se detiene y limpia la fuente anterior antes de comprobar autorización/preparar la nueva. No se precargan otros canales. Se bloquean aperturas duplicadas y el host rechaza una segunda instancia simultánea. Android detiene desde `onPause`/`onStop`; volver a primer plano no reanuda hasta comprobar el latido. Los rechazos 401/403/429/503 dejan de disparar bucles de carga nativos, reintentos Flutter o salto automático a otro canal. Otros fallos de red/decodificación conservan el mecanismo anterior: esta entrega **no acredita resolver congelaciones de códec/señal**.

## Implementado

- `EncryptedSharedPreferences`/Keystore para credenciales y token de aparato; migración desde preferencias antiguas: copiar al almacén seguro antes de borrar el original. También se cifran favoritos, recientes, progreso y configuración remota porque pueden incluir URLs con credenciales. Sin fallback en claro en Android. En otras plataformas la sesión es sólo memoria (reproducción sólo Android).
- ID `PA-<SHA256 truncado>` derivado del Android ID (no crudo), persistido cifrado y con copia no secreta. No se borra al salir de sesión. Con firma/usuario Android idénticos puede recuperarse del Android ID tras reinstalar; la copia local por sí sola no sobrevive a desinstalar ni a un restablecimiento de fábrica.
- Registro `register_device` al iniciar/restaurar sesión; reutilización de token cifrado hasta su TTL (máximo 30 días), vinculado al servidor/base y usuario. No se registra al cambiar cada canal. No se admite reproducir sin token cuando falla la autorización.
- `X-Device-Token` en el `DefaultHttpDataSource.Factory` compartido por manifiestos/segmentos y en las llamadas al panel. Se conservan las rutas de reproducción y no se utiliza WebTV ni la API administrativa. Se deja de usar un token global de marca para compartir acceso entre instalaciones.
- Primer latido antes de abrir contenido, cada 90 s reproduciendo y al volver del segundo plano, antes de reanudar. Pausa manual/segundo plano cancelan el temporizador; respuestas de suspensión/vencimiento/revocación detienen/liberan el player y cierran sesión. Vencimiento calculado con `server_time`, no el reloj del teléfono. Rechazo de token recuperable: un registro y un reintento; revocación: nunca revincular automáticamente.
- `429`: respeta segundos o fecha HTTP en `Retry-After`; login deshabilitado durante la espera. Latido espera al menos 180 s y nunca menos de `Retry-After`. `503`: mensaje de canal temporalmente no disponible, sin bucle. Rechazos de cuenta/red: aviso y cierre.
- Ajustes → **Desvincular este aparato**, con confirmación y llamada `unlink_device`. Sólo cierra sesión/borra token después de confirmación del panel.
- HTTPS obligatorio: una URL `http://` ya no funciona. Un host sin esquema se interpreta como HTTPS. Sin aceptación de certificados de usuario/autofirmados ni TrustManager permisivo. API del panel usa HTTPS nativo Android para aplicar la misma política TLS/pinning que Media3; no sigue redirecciones de API ni guarda respuestas en caché.
- Backup de la aplicación desactivado. Logs propios con URLs/cabeceras/excepciones retirados; logs Media3 deshabilitados. Diagnóstico persistente genérico, no texto arbitrario de excepciones.
- `get_drm` se consulta por reproducción con `streamId`; no persiste respuestas/claves ni modifica sus URLs. HLS AES compatible se deja al motor. ClearKey/Widevine/PlayReady/`requires_eme` se rechazan con aviso de compatibilidad: **no se ha añadido soporte de licencias DRM ni descifrado propio**. En un 403 de ruta DRM se permite una recarga de autorización/manifiesto, no un bucle.

## Pendiente obligatorio: pinning del dominio real

Sin dominio y **dos SPKI públicos reales distintos** no se pueden fijar pines fiables. El XML actual exige HTTPS/certificados del sistema, pero **aún no contiene pin-set**. No se inventaron pines ni se copió dos veces el mismo certificado.

El operador debe preparar un pin actual y otro correspondiente a una clave de respaldo que pueda usar al rotar TLS. No se necesitan claves privadas ni contraseñas en el chat.

Antes de compilar, ejecutar (sustituyendo los argumentos por datos públicos reales):

```powershell
python tools/configure_panel_pins.py --domain HOST_REAL --primary PIN_SPKI_ACTUAL --backup PIN_SPKI_RESPALDO --expires AAAA-MM-DD
```

La herramienta valida host, formato SHA-256, pines distintos y vencimiento futuro máximo 365 días. Escribe `android/app/src/main/res/xml/network_security_config.xml`. La selección de dominio es configuración de compilación, no cambia las URLs de login/reproducción. Probar conexión con ambas claves/certificados, rechazo de un pin erróneo y redirecciones/manifiestos externos. Planificar rotación antes de caducar; Android deja de aplicar pines al vencer el pin-set.

## Compatibilidad y compilación

Requiere TVLister con las acciones `register_device`, `heartbeat`, `unlink_device`, `get_drm` descritas. Otros paneles antiguos sin este contrato ya no se aceptan silenciosamente; no activar en producción sin actualizar/probar el panel.

Conservar `applicationId`, keystore y firma de producción. No cambiarla para sortear un fallo de compilación. Se agregó `androidx.security:security-crypto:1.1.0`; `pubspec.lock` no requiere nuevo paquete Dart.

En Windows:

```powershell
flutter pub get
flutter analyze
flutter test
```

Después compilar con `admin_panel\Generar APK.cmd`, una vez configurados los pines reales. Verificar R8, migración desde APK firmado anterior y cierre/reapertura en Fire TV, Android TV, tableta y teléfono.

## Validación realmente realizada

- Análisis sintáctico tree-sitter de Dart/Kotlin (no análisis de tipos ni compilación).
- Verificadores estáticos `check_player_security.py`, `check_player_lifecycle.py`, `check_exoplayer_only.py`, `check_release_signing.py`.
- Prueba Python de generación/rechazo de configuración de pines sintéticos; esos pines **no** se guardaron en el XML.
- Añadidas pruebas Flutter de registro/reutilización de token, revocación, migración, desvinculación, 429, hora del servidor y rechazo de HTTP. Adaptadas las fixtures antiguas al contrato mediante inyección explícita, sin excepciones HTTP en producción.
- **No ejecutado:** `flutter analyze`, tests Flutter, Gradle/APK, rendimiento ni pruebas contra panel/dispositivos. No hay Flutter/Android SDK ni acceso a una línea de pruebas configurada.

### Tabla de aceptación solicitada (§14)

Las 15 pruebas del contrato (registro, renovación, límite de aparatos, latido con/sin/manipulado/revocado, reproducción con/sin token, desvincular/revincular, rate limit, reinicio, límite de conexiones, matar app y reloj alterado) están **PENDIENTES de ejecución real**. Los tests simulados no sustituyen esas comprobaciones y no se adjunta una salida de éxito inventada.

La desconexión observada por el panel en <2 minutos, el comportamiento de segmentos/redirecciones y la revocación durante reproducción deben medirse contra el servidor real. El latido detecta revocación en el siguiente intervalo/respuesta, no garantiza corte instantáneo por sí mismo.
