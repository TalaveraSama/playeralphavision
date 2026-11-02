# 1.2.52+1056 — Canal con URL HTTP aunque el servidor ya tiene TLS

El mensaje «Este canal necesita una URL HTTPS» es una comprobación local de la app antes de abrir el vídeo. No demuestra un fallo del certificado. El panel puede anunciar todavía `server_protocol=http` o la lista/progreso puede contener una URL anterior.

## Corrección

- La configuración de marca permite separar explícitamente API y vídeo:

```json
"xtream": {
  "server": "https://tvadmin.alphadigitalnic.xyz",
  "streamServer": "https://live-stream.alphadigitalnic.xyz",
  "userAgent": "AlphaVision-Player",
  "streamToken": ""
}
```

- Ambos archivos (`assets/config.json`, `admin_panel/config.json`) contienen esos destinos. El panel de configuración PHP añade el campo **Servidor HTTPS de vídeo (opcional)**.
- Con `streamServer` configurado, las URLs nuevas de canales/películas/series/catch-up usan ese origen HTTPS aunque `server_info` conserve HTTP. Sólo se aplica a sesiones cuya API coincide con el origen `xtream.server`; no se mandan credenciales de otro proveedor al servidor de la marca.
- Sin ese ajuste, si el panel anuncia un `https_port` válido se prefiere ese puerto TLS frente a `server_protocol=http`.
- Una URL HTTP anterior del **mismo host de vídeo** y una ruta `/live/`, `/movie/`, `/series/` o `/timeshift/` puede elevarse a HTTPS conservando ruta y consulta. No se cambian hosts desconocidos, rutas arbitrarias ni puertos no previstos. Las referencias antiguas a una IP/dominio distinto requieren abrir el contenido de nuevo desde el catálogo.
- No se habilitó tráfico HTTP, no hay fallback a HTTP y no se omite la validación de certificados ni la autorización del panel. Los manifiestos/segmentos/keys también deben ser servidos por HTTPS por el servidor.

## Aplicar

1. Actualizar **el config.json remoto que consume la app**, no sólo el archivo del proyecto. Si hay configuración remota, añadir allí `xtream.streamServer` con el valor de arriba.
2. Compilar/instalar 1.2.52 conservando aplicación y firma de producción.
3. Cerrar sesión y entrar de nuevo para reconstruir sesión/URLs. Abrir un canal desde el catálogo, no una URL de historial con IP antigua.
4. En TVLister mantener `public_stream_base=https://live-stream.alphadigitalnic.xyz`; así sus listas y manifiestos también anuncian HTTPS.

El usuario aportó el diagnóstico del servidor con certificados públicos válidos para ambos dominios. No se volvieron a verificar los servidores desde este entorno y no se cambiaron puertos/nginx.

## Validación

Pruebas añadidas para configuración explícita, protocolo HTTP heredado con puerto TLS, conservación de ruta/consulta y rechazo de cambios a otros hosts/puertos/rutas. Sintaxis Dart/Kotlin y comprobaciones estáticas aprobadas. PHP no está instalado aquí: no se pudo ejecutar `php -l` para el campo añadido al panel. Sin Flutter/Android SDK aquí: tests Flutter, compilación APK y reproducción real pendientes. El pinning y la aceptación real del contrato siguen pendientes según `SEGURIDAD_TVLISTER.md`.
