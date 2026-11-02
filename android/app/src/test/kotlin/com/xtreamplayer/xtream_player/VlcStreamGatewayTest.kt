package com.xtreamplayer.xtream_player

import com.sun.net.httpserver.HttpServer
import java.net.InetSocketAddress
import java.net.URL
import org.junit.Assert.*
import org.junit.Test

/** JVM tests: no device, VLC or real account required. Run with Gradle/Android SDK. */
class VlcStreamGatewayTest {
    @Test fun hlsUrisAreRewrittenAndTokenIsAttachedToSegments() {
        val requests = java.util.concurrent.CopyOnWriteArrayList<Pair<String, String?>>()
        val server = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        server.createContext("/") { exchange ->
            requests.add(Pair(exchange.requestURI.path, exchange.requestHeaders.getFirst("X-Device-Token")))
            val manifest = "#EXTM3U\n#EXT-X-KEY:METHOD=AES-128,URI=\"/key\"\n#EXTINF:6,\n/segment.ts\n"
            val data = if (exchange.requestURI.path == "/live.m3u8") manifest.toByteArray() else ByteArray(32) { 7 }
            exchange.responseHeaders.add("Content-Type", if (exchange.requestURI.path == "/live.m3u8") "application/vnd.apple.mpegurl" else "application/octet-stream")
            exchange.sendResponseHeaders(200, data.size.toLong())
            exchange.responseBody.use { it.write(data) }
        }
        server.start()
        val relay = VlcStreamGateway("http://127.0.0.1:${server.address.port}/live.m3u8", mapOf("X-Device-Token" to "test-only"), true, "", true) { }
        try {
            val manifest = URL(relay.url).readText()
            val segment = manifest.lineSequence().first { it.startsWith("http://") }
            val key = Regex("URI=\"([^\"]+)\"").find(manifest)!!.groupValues[1]
            assertFalse(segment.contains("segment.ts")); assertFalse(key.contains("/key"))
            assertEquals(32, URL(segment).readBytes().size)
            assertEquals(32, URL(key).readBytes().size)
            assertTrue(requests.all { it.second == "test-only" })
        } finally { relay.close(); server.stop(0) }
    }
    @Test fun sensitiveHeadersAreNotSentToADifferentOrigin() {
        val seen = java.util.concurrent.atomic.AtomicReference<String?>()
        val other = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        other.createContext("/") { e ->
            seen.set(e.requestHeaders.getFirst("X-Device-Token"))
            val bytes = ByteArray(32); e.sendResponseHeaders(200, 32); e.responseBody.use { it.write(bytes) }
        }
        other.start()
        val root = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        root.createContext("/") { e ->
            val bytes = "#EXTM3U\n#EXTINF:6,\nhttp://127.0.0.1:${other.address.port}/part.ts\n".toByteArray()
            e.responseHeaders.add("Content-Type", "application/vnd.apple.mpegurl")
            e.sendResponseHeaders(200, bytes.size.toLong()); e.responseBody.use { it.write(bytes) }
        }
        root.start()
        val relay = VlcStreamGateway("http://127.0.0.1:${root.address.port}/live.m3u8", mapOf("X-Device-Token" to "test-only"), true, "", true) { }
        try {
            val segment = URL(relay.url).readText().lineSequence().first { it.startsWith("http://") }
            URL(segment).readBytes()
            assertNull(seen.get())
        } finally { relay.close(); root.stop(0); other.stop(0) }
    }
    @Test fun httpIsRejectedWhenProfileDidNotConsent() {
        val failed = java.util.concurrent.CountDownLatch(1)
        val relay = VlcStreamGateway("http://127.0.0.1:1/live.m3u8", emptyMap(), false, "", true) { failed.countDown() }
        try {
            try { URL(relay.url).readBytes() } catch (_: Exception) { }
            assertTrue(failed.await(2, java.util.concurrent.TimeUnit.SECONDS))
        } finally { relay.close() }
    }
}
