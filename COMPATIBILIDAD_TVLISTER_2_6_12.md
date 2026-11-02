> Actualización 1.2.55: la integración DRM descrita históricamente se retiró. Consulta `SEGURIDAD_SIN_DRM.md` para el comportamiento vigente.

# 1.2.53+1057 — Revisión de TVLister v2.6.12

Se revisaron las notas de https://github.com/TalaveraSama/tvlister24-7/releases/tag/v2.6.12 y `server/iptvApi.js` de esa etiqueta.

## Hallazgos

1. El panel corrigió `streams-port` para que los puertos TLS 443/8443/2053/2083/2087/2096 se anuncien como HTTPS. La API devuelve el origen de vídeo en `server_info.url`, su puerto activo en `port` y protocolo en `server_protocol`. Sin embargo, en esta etiqueta devuelve también `https_port: '443'` fijo. La app podía priorizar ese 443 incorrectamente.
2. `get_drm` es independiente de ese problema: devuelve `drm_enabled` y metadatos de canales. El aviso de URL HTTPS de la app ocurre **antes** de consultar esos datos: no demuestra que DRM lo haya causado.

## Cambios

- Cuando el panel anuncia vídeo HTTPS se respeta su puerto activo, también en 8443 y otros puertos TLS enumerados por esta versión, en vez de sustituirlo por 443.
- El `streamServer` de marca conserva su host seguro. Si ese host coincide con el anunciado por el panel se respeta el puerto TLS activo de ese mismo servidor, evitando que el valor predeterminado sin puerto fuerce 443. No se redirigen credenciales a otro host.
- Metadatos HTTP heredados con puerto TLS conocido se elevan a HTTPS conservando ese puerto. No se habilita HTTP ni se ignoran certificados.
- Si `get_drm` devuelve `drm_enabled: false`, no se bloquea contenido por entradas DRM inactivas. AES compatible sigue en manos de ExoPlayer. Widevine/PlayReady/ClearKey que requieran soporte de licencia siguen mostrando aviso: **no se añadió soporte DRM nuevo ni se eliminó el control de acceso**.
- Se mantienen registro, token, latido y rechazo de revocaciones del panel.

## Aplicar

Actualizar el panel siguiendo sus instrucciones de v2.6.12 y verificar `public_stream_base` y puerto. No cambiar puertos/nginx sólo para acomodar un error de la app. La API sigue en `https://tvadmin.alphadigitalnic.xyz` y el vídeo en el dominio directo `live-stream.alphadigitalnic.xyz`, con el puerto realmente configurado en el panel.

Instalar 1.2.53 con la firma habitual y cerrar/abrir sesión para obtener `server_info` actualizado. Si se usa configuración remota, mantener los campos `xtream.server` y `xtream.streamServer` de `CORRECCION_URL_HTTPS.md`. Abrir desde catálogo para no usar referencias a una IP antigua.

Si vuelve a fallar, comunicar **sólo protocolo, host y puerto**, o el mensaje exacto; no copiar URLs con usuario, contraseña o tokens. No se han consultado credenciales ni endpoints privados del usuario.

## Validación y límites

Incluidas regresiones de 443/8443/2053/2083/2087/2096 con `https_port=443`, con y sin ajuste de marca, y metadatos HTTP heredados en 8443. Pasaron sintaxis Dart/Kotlin y verificadores estáticos de seguridad, ciclo de vida, motor único y firma. No hay SDK Flutter/Android: tests Flutter, compilación y reproducción real pendientes. No se comprobó el estado actual del servidor del usuario ni se afirma que el error del aparato esté resuelto. El pinning y aceptación completa de seguridad siguen pendientes.
