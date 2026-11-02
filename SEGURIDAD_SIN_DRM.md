> **Actualización 1.2.56:** el reproductor principal ahora es LibVLC. Este documento describe una versión anterior; las diferencias y límites actuales están en [REPRODUCTOR_VLC.md](REPRODUCTOR_VLC.md).

# 1.2.55+1059 — Sin integración DRM, con seguridad de acceso

## Retirado

Se eliminaron todas las consultas `get_drm`, el filtro previo de compatibilidad DRM y los reintentos específicos de rutas de claves/licencias. Los canales se abren directamente con ExoPlayer después de la autorización de cuenta/aparato. No se añadió DRM propio, cifrado de vídeo inventado, claves embebidas ni un descifrador alternativo.

La eliminación corresponde a **la integración de esta app**, no al cifrado de un servidor: no se modificó el panel TVLister ni el origen de los streams. Para emitir sin DRM, el operador debe desactivarlo en sus propios canales/panel. Un contenido que siga exigiendo una licencia no se vuelve libre por retirar código de la app. El motor mantiene su manejo estándar de HLS, incluido AES cuando el manifiesto facilita una clave autorizada; no se parcheó la librería Media3.

## Protecciones aplicadas/conservadas

- API y vídeo de la marca usan HTTPS y validación de certificados del sistema; ambos dominios tienen además política Android explícita que prohíbe HTTP: `tvadmin.alphadigitalnic.xyz` y `live-stream.alphadigitalnic.xyz`.
- No hay TrustManager permisivo ni aceptación de certificados instalados por el usuario para interceptar TLS. No se sigue una redirección de API ni un cambio de protocolo de vídeo para degradar TLS.
- Identidad de aparato estable, registro, `X-Device-Token`, latido, revocación y límites decididos por TVLister permanecen. No se sustituye la autorización del servidor por una bandera local.
- Credenciales, tokens y perfiles cifrados con Keystore/EncryptedSharedPreferences; backup desactivado. Sin logs propios con URLs autenticadas/cabeceras ni volcados de excepciones, logs Media3 desactivados.
- R8 y reducción de recursos en release, firma de producción sin fallback debug. La ofuscación dificulta la inspección pero no oculta para siempre un secreto que tenga el cliente.
- `FLAG_SECURE` durante la actividad: solicita bloquear capturas de pantalla, grabaciones y miniaturas de recientes en Android compatible. Puede impedir ciertos métodos de duplicación/casting. **No es una medida contra captura de paquetes**, no impide una cámara externa y no se garantiza frente a sistemas modificados. La protección se aplica a toda la ventana, no sólo al widget de vídeo, evitando huecos en transiciones.
- La herramienta de configurar pines conserva las políticas de otros dominios al cambiar los pines del panel.

## Qué resiste y qué NO se puede prometer

HTTPS bien validado protege el contenido frente a un sniffer pasivo de la red. Verá datos de conexión y tamaños/tiempos, no las URLs/rutas autenticadas, tokens o vídeo en claro dentro de TLS. La resolución DNS y el nombre de servidor pueden seguir siendo observables según la red/protocolo.

Un dispositivo con root, hooks, instrumentación o un APK modificado puede observar datos antes/después de TLS y utilizar lo que su cuenta tenga autorizado. **Sin DRM no existe garantía de impedir toda extracción del stream desde un cliente controlado por el atacante.** Ni FLAG_SECURE, ni ofuscación, ni un secreto común embebido en el APK cambian ese límite.

El pinning con dos SPKI reales NO está configurado todavía: se sigue necesitando una clave actual y una de respaldo mantenidas por el operador. No se inventaron pines ni se bloqueó la app con un pin único no renovable. Incluso con pinning, un atacante con control del cliente puede intentar saltarse la validación.

Los perfiles externos HTTP que el usuario pidió conservar siguen requiriendo consentimiento: **sus credenciales y vídeo pueden capturarse sin cifrar**. No se anuncian como protegidos frente a sniffing. Usar perfiles HTTPS si se necesita confidencialidad de transporte. La excepción HTTP no permite texto plano en los dos dominios de marca protegidos por Android.

## Configuración indispensable del servidor

En las cuentas de TVLister que deban estar protegidas, activar la exigencia de aparato vinculado (`device_lock`) y límites adecuados. Enviar una cabecera desde la app no protege si el servidor permite el mismo stream sin ella. Una URL copiada sin el token debe ser rechazada **por el servidor**, incluidos manifiestos y segmentos. La app no puede impedir que una URL pública funcione en otro programa.

Tokens de reproducción firmados, de corta duración, revocables y ligados a sesión/aparato serían una defensa adicional del servidor. No se implementó un endpoint nuevo de tickets ni una reducción del TTL del servidor en esta tarea; el token de aparato conserva su contrato existente. No se aplicó vinculación obligatoria por IP, porque rompería movilidad/cambios de red sin una política acordada.

## Validación

Pasaron análisis de sintaxis Dart/Kotlin y verificadores estáticos de ausencia de DRM, seguridad, perfiles, ciclo de vida, motor único y firma. La combinación de políticas HTTPS y rotación de pines se comprueba con un test Python sintético que no guarda pines de prueba en la app.

Sin SDK Flutter/Android aquí: no se ejecutaron analyzer, tests Flutter, compilación APK ni pruebas de TLS, capturas, grabación, revocación o dispositivos reales. Antes de distribuir, comprobar: reproducción sin DRM, revocación, rechazo de URL sin token, rechazo de proxy con CA de usuario, política de HTTP por perfil y capturas/recientes en cada familia de dispositivos.
