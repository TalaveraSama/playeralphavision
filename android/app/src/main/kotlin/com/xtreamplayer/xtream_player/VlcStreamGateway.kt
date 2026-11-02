package com.xtreamplayer.xtream_player

import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.ByteArrayOutputStream
import java.net.HttpURLConnection
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.net.URL
import java.util.Collections
import java.util.LinkedHashMap
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.ConcurrentHashMap

/** Ephemeral loopback relay. VLC never receives account URLs/headers.
 * All remote requests use Android TLS policy, including HLS keys/segments.
 * This is NOT DRM and is not a boundary against root/instrumentation.
 */
class VlcStreamGateway(
    private val source: String,
    private val headers: Map<String, String>,
    private val allowHttp: Boolean,
    private val panelOrigin: String,
    private val forceHls: Boolean,
    private val failure: (Map<String, Any?>) -> Unit,
) {
    private val server = ServerSocket(0, 8, InetAddress.getByName("127.0.0.1"))
    private val workers = Executors.newFixedThreadPool(6)
    private val sockets = Collections.newSetFromMap(ConcurrentHashMap<Socket, Boolean>())
    private val connections = Collections.newSetFromMap(ConcurrentHashMap<HttpURLConnection, Boolean>())
    private val routes = LinkedHashMap<String, String>()
    private fun origin(url: URL) = "${url.protocol.lowercase()}://${url.host.lowercase()}:${if (url.port >= 0) url.port else url.defaultPort}"
    private val rootOrigin = origin(URL(source))
    private val trustedPanelOrigin = try { origin(URL(panelOrigin)) } catch (_: Exception) { "" }
    @Volatile private var closed = false
    val url: String = route(source)
    init {
        Thread({
            while (!closed) {
                try {
                    val socket = server.accept()
                    if (closed || sockets.size >= 24) { socket.close(); continue }
                    socket.soTimeout = 15000
                    sockets.add(socket)
                    try { workers.execute { serve(socket) } }
                    catch (_: RejectedExecutionException) { sockets.remove(socket); socket.close(); break }
                } catch (_: Exception) { if (!closed) close() }
            }
        }, "VLC-stream-relay").start()
    }
    @Synchronized private fun route(target: String): String {
        val existing = routes.entries.firstOrNull { it.value == target }?.key
        val id = existing ?: UUID.randomUUID().toString().also {
            routes[it] = target
            if (routes.size > 5000) routes.entries.firstOrNull { entry -> entry.value != source }?.key?.let { key -> routes.remove(key) }
        }
        return "http://127.0.0.1:${server.localPort}/$id"
    }
    @Synchronized private fun lookup(path: String): String? = routes[path.removePrefix("/")]
    private fun line(input: BufferedInputStream): String {
        val out = ByteArrayOutputStream()
        while (true) {
            val b = input.read()
            if (b < 0 || b == 10) break
            if (b != 13) out.write(b)
            require(out.size() <= 8192)
        }
        return out.toString("ISO-8859-1")
    }
    private fun requestHeaders(input: BufferedInputStream): Map<String, String> {
        val result = mutableMapOf<String, String>()
        repeat(100) {
            val line = line(input)
            if (line.isEmpty()) return result
            val colon = line.indexOf(':')
            if (colon > 0) result[line.substring(0, colon).lowercase()] = line.substring(colon + 1).trim()
        }
        throw java.io.IOException("Cabeceras inválidas")
    }
    private fun remote(target: String, incoming: Map<String, String>): Pair<HttpURLConnection, URL> {
        check(!closed)
        var url = URL(target)
        repeat(6) {
            require(url.protocol == "https" || (allowHttp && url.protocol == "http"))
            require(url.userInfo == null && !(url.host == "127.0.0.1" && url.port == server.localPort))
            val conn = url.openConnection() as HttpURLConnection
            connections.add(conn)
            if (closed) { conn.disconnect(); connections.remove(conn); throw java.io.IOException("Sesión cerrada") }
            try {
                conn.instanceFollowRedirects = false
                conn.connectTimeout = 8000; conn.readTimeout = 12000; conn.useCaches = false
                conn.setRequestProperty("Accept-Encoding", "identity")
                for ((name, value) in headers) {
                    val sensitive = name.equals("X-Device-Token", true) || name.equals("Authorization", true) || name.equals("Cookie", true)
                    if (!sensitive || origin(url) == rootOrigin || origin(url) == trustedPanelOrigin) conn.setRequestProperty(name, value)
                }
                for (name in listOf("range", "if-range")) incoming[name]?.let { conn.setRequestProperty(name, it) }
                val status = conn.responseCode
                if (status !in listOf(301, 302, 303, 307, 308)) return Pair(conn, url)
                val location = conn.getHeaderField("Location") ?: throw java.io.IOException("Redirección inválida")
                val next = URL(url, location)
                conn.disconnect(); connections.remove(conn)
                // No HTTPS -> HTTP downgrade, even for profiles that consent to HTTP.
                require(!(url.protocol == "https" && next.protocol != "https"))
                url = next
            } catch (error: Exception) {
                conn.disconnect(); connections.remove(conn)
                throw error
            }
        }
        throw java.io.IOException("Demasiadas redirecciones")
    }
    private fun limited(input: java.io.InputStream, limit: Int): ByteArray {
        val out = ByteArrayOutputStream()
        val buf = ByteArray(8192)
        while (!closed) {
            val n = input.read(buf)
            if (n < 0) break
            require(out.size() + n <= limit)
            out.write(buf, 0, n)
        }
        return out.toByteArray()
    }
    private fun manifest(body: String, base: URL): ByteArray {
        val uriAttribute = Regex("URI=\"([^\"]+)\"")
        return body.lineSequence().joinToString("\n") { raw ->
            val trimmed = raw.trim()
            if (trimmed.isNotEmpty() && !trimmed.startsWith("#")) route(URL(base, trimmed).toString())
            else uriAttribute.replace(raw) { match -> "URI=\"${route(URL(base, match.groupValues[1]).toString())}\"" }
        }.toByteArray(Charsets.UTF_8)
    }
    private fun report(conn: HttpURLConnection, status: Int) {
        var code = ""
        try {
            val body = conn.errorStream?.use { limited(it, 8192).toString(Charsets.UTF_8) } ?: "{}"
            val value = JSONObject(body).optString("error")
            if (value in setOf("device_required", "device_invalid", "device_revoked", "device_limit")) code = value
        } catch (_: Exception) { }
        val retry = conn.getHeaderField("Retry-After")
        var seconds = retry?.toLongOrNull()
        if (seconds == null && retry != null) {
            try {
                val format = java.text.SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", java.util.Locale.US)
                val now = conn.getHeaderField("Date")?.let { format.parse(it)?.time } ?: System.currentTimeMillis()
                seconds = ((format.parse(retry)?.time ?: now) - now) / 1000
            } catch (_: Exception) { }
        }
        if (!closed) failure(mapOf("status" to status, "code" to code, "retryAfter" to maxOf(1L, seconds ?: 600L)))
    }
    private fun serve(socket: Socket) {
        var conn: HttpURLConnection? = null
        try {
            val input = BufferedInputStream(socket.getInputStream())
            val first = line(input).split(' ')
            val request = requestHeaders(input)
            require(first.size >= 2 && first[0] in listOf("GET", "HEAD"))
            val target = lookup(first[1]) ?: throw java.io.IOException("Ruta caducada")
            val response = remote(target, request); conn = response.first
            val status = conn.responseCode
            val out = socket.getOutputStream()
            if (status >= 400) {
                report(conn, status)
                out.write("HTTP/1.1 $status Error\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".toByteArray())
                return
            }
            val type = conn.contentType ?: "application/octet-stream"
            val raw = conn.inputStream
            val decoded = if (conn.getHeaderField("Content-Encoding").equals("gzip", true)) java.util.zip.GZIPInputStream(raw) else raw
            val stream = BufferedInputStream(decoded)
            stream.mark(64)
            val probe = ByteArray(16)
            var count = 0
            while (count < probe.size) {
                val n = stream.read(probe, count, probe.size-count)
                if (n < 0) break
                count += n
            }
            stream.reset()
            val sniffHls = String(probe, 0, count, Charsets.UTF_8).trimStart('\uFEFF', ' ', '\r', '\n').startsWith("#EXTM3U")
            val hls = sniffHls || (forceHls && target == source) || response.second.path.lowercase().endsWith(".m3u8") ||
                type.contains("mpegurl", true)
            if (hls) {
                val bytes = stream.use { manifest(limited(it, 4 * 1024 * 1024).toString(Charsets.UTF_8), response.second) }
                out.write("HTTP/1.1 200 OK\r\nContent-Type: application/vnd.apple.mpegurl\r\nContent-Length: ${bytes.size}\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".toByteArray())
                if (first[0] == "GET") out.write(bytes)
            } else {
                val responseHeaders = StringBuilder("HTTP/1.1 $status OK\r\nContent-Type: ${type.replace("\r", "").replace("\n", "")}\r\nConnection: close\r\nCache-Control: no-store\r\n")
                for (name in listOf("Content-Length", "Content-Range", "Accept-Ranges")) {
                    if (name == "Content-Length" && decoded !== raw) continue
                    conn.getHeaderField(name)?.let { responseHeaders.append("$name: ${it.replace("\r", "").replace("\n", "")}\r\n") }
                }
                out.write(responseHeaders.append("\r\n").toString().toByteArray())
                if (first[0] == "GET") stream.use { body ->
                    val buffer = ByteArray(32768)
                    while (!closed) {
                        val n = body.read(buffer)
                        if (n < 0) break
                        out.write(buffer, 0, n)
                    }
                }
            }
            out.flush()
        } catch (_: Exception) {
            if (!closed && conn == null) failure(mapOf("status" to null, "code" to "network"))
        } finally {
            conn?.disconnect(); conn?.let { connections.remove(it) }
            sockets.remove(socket)
            try { socket.close() } catch (_: Exception) { }
        }
    }
    fun close() {
        if (closed) return
        closed = true
        try { server.close() } catch (_: Exception) { }
        for (conn in connections) conn.disconnect()
        for (socket in sockets) try { socket.close() } catch (_: Exception) { }
        workers.shutdownNow()
        synchronized(this) { routes.clear() }
    }
}
