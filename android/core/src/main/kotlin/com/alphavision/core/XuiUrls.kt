package com.alphavision.core

import java.net.URLEncoder

/**
 * Construcción de URLs del API XUI.one (compatible con Xtream Codes).
 *
 * Rutas usadas:
 *  - `{base}/player_api.php`        JSON (auth, categorías, listados, EPG)
 *  - `{base}/get.php`               playlist M3U
 *  - `{base}/xmltv.php`             EPG XMLTV
 *  - `{base}/live/{user}/{pass}/{id}.m3u8`
 *  - `{base}/movie/{user}/{pass}/{id}.{ext}`
 *  - `{base}/series/{user}/{pass}/{episodeId}.{ext}`
 */
object XuiUrls {

    /**
     * Acepta `panel.tv`, `panel.tv:8080`, `http://panel.tv:8080/` o `https://...`
     * y devuelve siempre `esquema://host[:puerto]` sin barra final.
     *
     * Si no se indica esquema se asume `http` (los paneles XUI suelen escuchar
     * el 80/8080 en claro; con panel HTTPS el usuario debe escribir `https://`).
     */
    fun normalizeBase(raw: String): String {
        var s = raw.trim()
        if (s.isEmpty()) return s
        if (s.endsWith("/")) s = s.trimEnd('/')
        val hasScheme = s.startsWith("http://", true) || s.startsWith("https://", true)
        if (!hasScheme) s = "http://$s"
        // quita rutas tipo /player_api.php o /get.php que el usuario haya pegado
        val schemeEnd = s.indexOf("://") + 3
        val pathStart = s.indexOf('/', schemeEnd)
        if (pathStart > 0) s = s.substring(0, pathStart)
        return s
    }

    private fun enc(v: String): String = URLEncoder.encode(v, "UTF-8")

    /** `player_api.php` con credenciales y, opcionalmente, una acción y parámetros. */
    fun apiUrl(creds: Credentials, action: String? = null, params: Map<String, String> = emptyMap()): String {
        val sb = StringBuilder(creds.base)
            .append("/player_api.php?username=").append(enc(creds.username))
            .append("&password=").append(enc(creds.password))
        if (action != null) sb.append("&action=").append(enc(action))
        for ((k, v) in params) sb.append('&').append(enc(k)).append('=').append(enc(v))
        return sb.toString()
    }

    fun liveUrl(creds: Credentials, streamId: Int, extension: String = "m3u8"): String =
        "${creds.base}/live/${enc(creds.username)}/${enc(creds.password)}/$streamId.$extension"

    fun vodUrl(creds: Credentials, streamId: Int, extension: String = "mp4"): String =
        "${creds.base}/movie/${enc(creds.username)}/${enc(creds.password)}/$streamId.${extension.trimStart('.')}"

    fun seriesUrl(creds: Credentials, episodeId: String, extension: String = "mp4"): String =
        "${creds.base}/series/${enc(creds.username)}/${enc(creds.password)}/$episodeId.${extension.trimStart('.')}"

    /** Playlist M3U completa (útil para exportar a otros reproductores). */
    fun m3uUrl(creds: Credentials, output: String = "ts"): String =
        "${creds.base}/get.php?username=${enc(creds.username)}&password=${enc(creds.password)}&type=m3u_plus&output=$output"

    fun xmltvUrl(creds: Credentials): String =
        "${creds.base}/xmltv.php?username=${enc(creds.username)}&password=${enc(creds.password)}"

    fun epgUrl(creds: Credentials, streamId: Int): String =
        apiUrl(creds, "get_short_epg", mapOf("stream_id" to streamId.toString()))

    fun catchupUrl(creds: Credentials, streamId: Int, start: String, durationMinutes: Int): String {
        // Formato estándar Xtream para catch-up
        val startFmt = if (start.length >= 19) {
            start.replace("-", "").replace(":", "").replace(" ", "-").substring(0, 14)
        } else {
            start.replace("-", "").replace(":", "")
        }
        return "${creds.base}/streaming/timeshift.php?username=${enc(creds.username)}&password=${enc(creds.password)}" +
            "&stream=$streamId&start=$startFmt&duration=$durationMinutes"
    }
}
