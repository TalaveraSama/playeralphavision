> Actualización 1.2.55: la integración DRM descrita históricamente se retiró. Consulta `SEGURIDAD_SIN_DRM.md` para el comportamiento vigente.

# 1.2.54+1058 — Perfiles IPTV (PREVIEW)

## Uso

En acceso: **Perfiles / agregar servidor o lista**. En Ajustes: **Perfiles IPTV / agregar servidor o lista**. Si hay perfiles guardados, el siguiente arranque muestra el selector, sin abrir automáticamente una cuenta.

Hasta 20 perfiles locales con nombre y una fuente:

- **TVLister**: servidor, usuario y contraseña, con registro/latido/token de aparato del contrato anterior.
- **Xtream Codes estándar**: servidor propio, usuario y contraseña. No exige `register_device`, `heartbeat` ni `get_drm` de TVLister. Catálogos/películas/series dependen de lo que ofrezca el proveedor.
- **Lista M3U/M3U8 por URL**: carga canales, nombres, grupos y logos. Si la URL devuelve un manifiesto HLS, se añade como un canal directo, no se importan los segmentos como canales.
- **Archivo M3U/M3U8**: selector nativo Android, sin permiso de acceso general a todos los archivos. Importa una copia cifrada de la lista, no necesita conservar acceso al archivo original. Fire TV requiere un proveedor/selector de documentos instalado; si no existe, usar el enlace.

Las listas se presentan como **canales en directo**; no crean catálogos de películas/episodios a partir de una lista, ni importan automáticamente XMLTV ni opciones propietarias `EXTVLCOPT`. Archivos HLS locales con segmentos relativos no se admiten: usar el enlace HLS original. Sólo enlaces de reproducción HTTP/HTTPS, no `file:`, UDP, RTSP ni código ejecutable.

Se pueden agregar, seleccionar y eliminar perfiles (con confirmación). Para modificar una fuente, eliminar/recrear el perfil; no se añadió editor en esta entrega. Eliminar un perfil elimina su copia y datos locales, no la cuenta del proveedor. Los perfiles no son usuarios del sistema ni están protegidos por PIN: quien use el dispositivo puede seleccionar una cuenta guardada.

## Aislamiento y persistencia

Credenciales, URLs, archivos importados y datos de los perfiles se guardan en `EncryptedSharedPreferences`/Keystore, no en preferencias en claro. Nombre, tipo y aviso de HTTP se muestran en la lista; no se muestran contraseñas ni URLs autenticadas en ella.

Favoritos, recientes y progreso tienen instantáneas separadas. Al cambiar se notifica el cierre del player, se cierra el cliente anterior, se limpia el catálogo en memoria y se carga el perfil elegido. No hay reproducción simultánea de varios perfiles. El ID del aparato no se regenera al cambiar.

Al agregar un perfil desde una cuenta de marca ya abierta sin perfiles, se conserva como «Cuenta actual». Cerrar sesión sale al selector; no borra las credenciales del perfil guardado (para eso, eliminarlo). El token de aparato de la sesión cerrada se elimina también de su instantánea. Un cambio de perfil puede conservar su token cifrado por cuenta mientras sea válido. No se realiza `unlink_device` al cambiar de cuenta.

Límites: 10 MB por descarga/archivo, 10 MB totales de texto importado y 50.000 entradas por lista. Las listas por enlace se vuelven a descargar al seleccionar el perfil; los archivos son copias locales, se deben reimportar si cambian.

## HTTP: decisión explícita del usuario

El usuario autorizó compatibilidad **HTTPS y HTTP** para proveedores externos. Cada perfil externo empieza sin HTTP. El interruptor **Permitir HTTP en este perfil** pide confirmar que usuario, contraseña, token y vídeo pueden viajar sin cifrar. No es una conexión segura y no se omiten errores de certificado HTTPS.

Para permitir esa función, el permiso de texto plano de Android ahora está habilitado a nivel de aplicación. La restricción se aplica explícitamente en el transporte de la API y en cada apertura de datos del player (manifiestos, segmentos y claves), según el perfil. El transporte del panel no sigue redirecciones y Media3 no permite redirecciones entre protocolos. No afirmar que el manifiesto Android sigue prohibiendo HTTP globalmente: cambió deliberadamente por esta función.

El perfil TVLister no tiene ese interruptor y mantiene HTTPS/token/latido. Una cuenta Xtream cuyo host sea el de la marca se trata como TVLister aunque se elija el tipo estándar; no se ofrece como vía para desactivar su control de aparato. Otros proveedores TVLister deben elegirse como tipo TVLister. El servidor siempre decide permisos, vencimiento y conexiones.

Si se usa `tools/configure_panel_pins.py`, el dominio fijado conserva política HTTPS y pines; otros hosts pueden usar la excepción consentida. El pinning real de la marca y las pruebas de aceptación siguen pendientes como se documentó antes.

## Validación realmente disponible

- Análisis de sintaxis de 78 archivos Dart de aplicación, 30 de tests y 4 Kotlin.
- Verificadores estáticos de perfil/HTTP, seguridad, ciclo de vida, motor único y firma.
- Nuevos tests Flutter para parseo M3U/HLS, URLs relativas, esquemas rechazados, persistencia y aislamiento de favoritos/cambio/eliminación de perfiles.
- **No ejecutados**: Flutter analyze/tests, Gradle, APK, selector de archivos Android/Fire TV, reproducción real y navegación con mando. No hay SDK Flutter/Android aquí. No se garantiza todavía compatibilidad con todos los proveedores.

Compilar en Windows con `flutter pub get`, `flutter analyze`, `flutter test` y `admin_panel\Generar APK.cmd`, conservando firma y applicationId. Antes de distribuir, probar dos cuentas distintas, una lista por archivo y otra por URL, ambas políticas HTTP, reinicio, eliminación del perfil activo y cambio con un player abierto.
