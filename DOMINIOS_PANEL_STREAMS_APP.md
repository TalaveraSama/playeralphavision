# 1.2.51+1055 — API y vídeo en dominios separados

## Hallazgo en el código

La configuración empaquetada y la de `admin_panel/config.json` aún señalaban `173.208.183.66:80`. Con la política HTTPS de 1.2.50, un host sin esquema se interpretaba como HTTPS conservando el puerto 80. Eso no equivale a conectar al panel HTTPS público y puede causar el mensaje genérico de conexión segura. **No se ha verificado qué configuración remota/guardada usa el dispositivo afectado, ni el estado actual de los dominios.**

Ahora el valor predeterminado de la API es `https://tvadmin.alphadigitalnic.xyz`. Publicar también el `config.json` actualizado en el hosting de configuración remota; cambiar sólo el asset del APK no garantiza sobrescribir una sesión o configuración remota antigua. Cerrar sesión y volver a entrar con el dominio correcto si había otra dirección guardada.

El constructor de URLs utiliza `server_info.url` y protocolo/puertos anunciados por el panel para `/live`, `/movie`, `/series` y catch-up. API, registro, heartbeat, `get_drm`, playlist y XMLTV permanecen en el dominio de acceso. No se adivina ni se fija un dominio de vídeo en el código.

Se distinguen DNS, timeout, conexión rechazada, fallo TLS y redirección de API mediante códigos seguros, sin exponer URLs autenticadas, cabeceras, excepciones ni claves. Una redirección no reenvía las credenciales.

## Configuración esperada en TVLister

Basado en su documentación `docs/DOMINIOS_PANEL_STREAMS.md`:

- Panel/API: `https://tvadmin.alphadigitalnic.xyz`.
- `panel_domain`: `tvadmin.alphadigitalnic.xyz`.
- `stream_domain`: `live-stream.alphadigitalnic.xyz`.
- `public_stream_base`: `https://live-stream.alphadigitalnic.xyz`.
- El vídeo necesita certificado de CA pública válido para su propio nombre y servicio HTTPS accesible en 443. Un Cloudflare Origin Certificate no es de confianza pública para acceso directo desde los reproductores.
- Si el panel usa Cloudflare, la API puede estar proxied; el vídeo debe seguir las recomendaciones del operador/TVLister para salida directa, no compartir por error la ruta de vídeo del proxy del panel.

El enlace de vídeo facilitado usa **HTTP**, pero eso no demuestra que no exista HTTPS. No se comprobó en vivo desde este entorno: acceso de red restringido a hosts de desarrollo. **No se activó HTTP ni se desactivó la validación TLS.** La versión anterior exige HTTPS y el contrato de seguridad también; si sólo hay HTTP, primero se debe habilitar TLS en el servidor de vídeo o acordar explícitamente una excepción con su riesgo de exponer credenciales/tokens/tráfico.

## Comprobación sin contraseñas

En Windows (no añadir `-k`):

```powershell
curl.exe -i --max-time 15 https://tvadmin.alphadigitalnic.xyz/player_api.php
curl.exe -I --max-time 15 https://live-stream.alphadigitalnic.xyz/
```

La API puede rechazar por faltar usuario/clave; esa respuesta no equivale a un fallo TLS. Una página HTML de desafío/login de Cloudflare no es una respuesta JSON de la API para la app. No publicar comandos/resultados con credenciales reales.

En el servidor, si dispone de la herramienta de TVLister, usar primero el diagnóstico de sólo lectura:

```bash
sudo tvlister-admin dominios
```

Revisar quién sirve 443 y sus certificados antes de ejecutar comandos que cambien puertos/nginx. No hace falta sustituir ni apagar servidores a ciegas.

## Validación y pendientes

Incluidas pruebas `test/panel_stream_domains_test.dart`. Pasaron comprobaciones estáticas y sintácticas; no hay SDK Flutter/Android para compilar ni ejecutar tests/dispositivo. No se verificaron certificados, DNS ni endpoints de estos dominios desde aquí.

Sigue pendiente el pinning con dos SPKI reales distintos y la tabla de aceptación del panel de `SEGURIDAD_TVLISTER.md`; conocer el hostname no aporta automáticamente un pin de respaldo. Esta versión es PREVIEW, sin APK compilado y sin afirmar que el fallo del equipo esté resuelto.
