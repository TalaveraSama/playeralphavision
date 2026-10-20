/**
 * Arnés de verificación del módulo `core` (JVM puro, sin dependencias).
 *
 *   javac/javac no hace falta: se compila con kotlinc.
 *
 * Modo offline (usa los fixtures que genera el mock):
 *   java -jar dev/core-check.jar mock_xui/fixtures
 *
 * Modo live (contra el mock escuchando):
 *   java -jar dev/core-check.jar mock_xui/fixtures http://127.0.0.1:8099
 */
import com.alphavision.core.Credentials
import com.alphavision.core.HttpTransport
import com.alphavision.core.Json
import com.alphavision.core.JsonException
import com.alphavision.core.JsonValue
import com.alphavision.core.XuiApi
import com.alphavision.core.XuiUrls
import com.alphavision.core.arr
import com.alphavision.core.asText
import com.alphavision.core.bool
import com.alphavision.core.int
import com.alphavision.core.obj
import com.alphavision.core.str
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

private var passed = 0
private var failed = 0
private val failures = mutableListOf<String>()

private fun test(name: String, block: () -> Unit) {
    try {
        block()
        passed++
        println("PASS  $name")
    } catch (t: Throwable) {
        failed++
        failures += "$name -> ${t.message}"
        println("FAIL  $name -> ${t.message}")
    }
}

private fun eq(expected: Any?, actual: Any?, label: String = "") {
    if (expected != actual) throw AssertionError("$label esperado=<$expected> actual=<$actual>")
}

private fun assertTrue(cond: Boolean, msg: String) {
    if (!cond) throw AssertionError(msg)
}

private fun fixture(dir: String, name: String): String = File(dir, name).readText()

fun main(args: Array<String>) {
    val fixtures = args.getOrNull(0) ?: "mock_xui/fixtures"
    val liveBase = args.getOrNull(1)

    println("== JSON ==")
    test("parsea objeto anidado") {
        val v = Json.parse("""{"a":1,"b":{"c":[true,null,"x"],"d":"e"},"f":2.5}""")
        eq("1", v.str("a"), "a")
        eq("e", v.obj("b")?.str("d"), "b.d")
        eq(3, v.obj("b")?.arr("c")?.size, "b.c.size")
        eq("x", v.obj("b")?.arr("c")?.get(2)?.asText(), "b.c[2]")
    }
    test("respeta escapes y unicode") {
        val v = Json.parse("""{"s":"linea\nnueva \"comilla\" \u00f1andú \\ barra"}""")
        eq("linea\nnueva \"comilla\" ñandú \\ barra", v.str("s"), "s")
    }
    test("números negativos y exponente") {
        val v = Json.parse("""{"a":-12.5,"b":1e3}""")
        eq("-12.5", v.str("a"), "a")
        eq("1000", v.str("b"), "b")
    }
    test("stream_id como string se lee como int") {
        val v = Json.parse("""{"stream_id":"101","num":7,"ok":"1"}""")
        eq(101, v.int("stream_id"), "int desde string")
        eq(7, v.int("num"), "int desde número")
        eq(true, v.bool("ok"), "bool desde \"1\"")
        eq(null, v.int("inexistente"), "campo ausente")
    }
    test("JSON inválido lanza excepción") {
        var threw = false
        try { Json.parse("""{"a": }""") } catch (e: JsonException) { threw = true }
        assertTrue(threw, "debía lanzar JsonException")
        threw = false
        try { Json.parse("{") } catch (e: JsonException) { threw = true }
        assertTrue(threw, "json truncado debía fallar")
    }

    println("== URLs ==")
    test("normaliza host sin esquema") { eq("http://panel.tv:8080", XuiUrls.normalizeBase("panel.tv:8080")) }
    test("quita barra final") { eq("https://panel.tv", XuiUrls.normalizeBase("https://panel.tv/")) }
    test("quita ruta pegada por el usuario") {
        eq("http://1.2.3.4:8099", XuiUrls.normalizeBase("http://1.2.3.4:8099/player_api.php"))
    }
    test("respeta https") { eq("https://panel.tv:8443", XuiUrls.normalizeBase("https://panel.tv:8443")) }

    val creds = Credentials("panel.tv:8080", "us er", "p@ss&1")
    test("apiUrl sin acción") {
        eq("http://panel.tv:8080/player_api.php?username=us+er&password=p%40ss%261", XuiUrls.apiUrl(creds))
    }
    test("apiUrl con acción y parámetros") {
        eq(
            "http://panel.tv:8080/player_api.php?username=us+er&password=p%40ss%261&action=get_live_streams&category_id=1",
            XuiUrls.apiUrl(creds, "get_live_streams", mapOf("category_id" to "1")),
        )
    }
    test("URL live") { eq("http://panel.tv:8080/live/us+er/p%40ss%261/101.m3u8", XuiUrls.liveUrl(creds, 101)) }
    test("URL vod respeta extensión") {
        eq("http://panel.tv:8080/movie/us+er/p%40ss%261/201.mkv", XuiUrls.vodUrl(creds, 201, ".mkv"))
    }
    test("URL serie usa el id del episodio") {
        eq("http://panel.tv:8080/series/us+er/p%40ss%261/9003.mp4", XuiUrls.seriesUrl(creds, "9003"))
    }

    println("== Auth ==")
    val api = XuiApi { "" } // transporte vacío: aquí parseamos fixtures
    test("login correcto") {
        val r = api.parseLogin(fixture(fixtures, "login_ok.json"), creds)
        assertTrue(r.isAuthenticated, "debía autenticar")
        eq("Active", r.user.status, "status")
        eq(2, r.user.maxConnections, "max_conn")
        eq(listOf("m3u8", "ts"), r.user.allowedOutputFormats, "formatos")
        eq("8099", r.server?.port, "puerto")
        assertTrue((r.user.expDate ?: 0) > 1_700_000_000L, "exp_date")
        eq(12L, (r.user.daysLeft(r.user.expDate!! - 12 * 86_400)) as Long?, "días restantes")
    }
    test("login rechazado") {
        val r = api.parseLogin(fixture(fixtures, "login_fail.json"), creds)
        assertTrue(!r.isAuthenticated, "no debía autenticar")
        eq("Disabled", r.user.status, "status")
    }

    println("== Catálogo ==")
    test("categorías live") {
        val cats = api.parseCategories(fixture(fixtures, "live_categories.json"))
        eq(3, cats.size, "n")
        eq("Deportes", cats.first().name, "primera")
        eq("1", cats.first().id, "id")
    }
    test("canales live") {
        val ch = api.parseLiveStreams(fixture(fixtures, "live_streams.json"))
        eq(6, ch.size, "n")
        eq("ESPN HD", ch.first().name, "nombre")
        eq(101, ch.first().streamId, "stream_id")
        assertTrue(ch.first().hasArchive, "tv_archive=1 debía marcar archivo")
        assertTrue(!ch[1].hasArchive, "tv_archive=0")
        eq("espn.hd", ch.first().epgChannelId, "epg id")
    }
    test("películas") {
        val v = api.parseVodStreams(fixture(fixtures, "vod_streams.json"))
        eq(2, v.size, "n")
        eq("mp4", v.first().containerExtension, "ext")
        eq("7.4", v.first().rating, "rating")
        eq(201, v.first().streamId, "id")
    }
    test("series") {
        val s = api.parseSeriesList(fixture(fixtures, "series.json"))
        eq(2, s.size, "n")
        eq(301, s.first().seriesId, "id")
        eq("Nicaragua Salvaje", s.first().name, "nombre")
    }
    test("detalle de serie: temporadas ordenadas") {
        val d = api.parseSeriesInfo(fixture(fixtures, "series_info.json"), 301)
        eq(listOf(1, 2), d.seasons.keys.toList(), "temporadas")
        eq(2, d.seasons[1]?.size, "eps t1")
        eq(1, d.seasons[2]?.size, "eps t2")
        eq("9001", d.seasons[1]?.first()?.id, "primer ep")
        eq("Volcanes", d.seasons[2]?.first()?.title, "titulo t2")
        eq(301, d.info?.seriesId, "seriesId en info")
    }
    test("detalle de película") {
        val m = api.parseVodInfo(fixture(fixtures, "vod_info.json"), 201)
        eq(201, m.streamId, "id")
        eq("mp4", m.containerExtension, "ext")
        eq("1h 45min", m.duration, "duración")
    }

    println("== EPG ==")
    test("EPG base64 decodificado") {
        val epg = api.parseEpg(fixture(fixtures, "epg.json"))
        eq(2, epg.size, "n")
        eq("Programa en curso", epg.first().title, "título")
        eq("Transmisión en directo de prueba.", epg.first().description, "descripción")
        assertTrue(epg.first().nowPlaying, "now_playing")
        assertTrue((epg.first().startTimestamp ?: 0) > 0, "timestamp")
        eq(epg.first().startTimestamp!! * 1000, epg.first().startMillis!!, "millis")
    }

    if (liveBase != null) {
        println("== Integración contra el mock ($liveBase) ==")
        val http = object : HttpTransport {
            override fun get(url: String): String {
                val c = URL(url).openConnection() as HttpURLConnection
                c.connectTimeout = 5000
                c.readTimeout = 15000
                c.setRequestProperty("User-Agent", "AlphaVision/1.0")
                if (c.responseCode !in 200..299) throw IllegalStateException("HTTP ${c.responseCode} en $url")
                return c.inputStream.bufferedReader().readText()
            }
        }
        val realApi = XuiApi(http)
        val realCreds = Credentials(liveBase, "demo", "demo")

        test("login real") {
            val r = realApi.login(realCreds)
            assertTrue(r.isAuthenticated, "auth")
            eq("Active", r.user.status, "status")
        }
        test("login real con clave mala") {
            val r = realApi.login(Credentials(liveBase, "demo", "mala"))
            assertTrue(!r.isAuthenticated, "no debía autenticar")
        }
        test("catálogo real completo") {
            eq(3, realApi.liveCategories(realCreds).size, "cats live")
            eq(6, realApi.liveStreams(realCreds).size, "canales")
            eq(2, realApi.vodStreams(realCreds).size, "pelis")
            eq(2, realApi.seriesList(realCreds).size, "series")
        }
        test("filtro por categoría en el API") {
            eq(2, realApi.liveStreams(realCreds, "1").size, "deportes")
        }
        test("detalle de serie real") {
            val d = realApi.seriesInfo(realCreds, 301)
            eq(2, d.seasons.size, "temporadas")
        }
        test("EPG real") {
            val e = realApi.shortEpg(realCreds, 101)
            eq(2, e.size, "n")
            eq("Programa en curso", e.first().title, "título decodificado")
        }
        test("m3u real") {
            val text = http.get(XuiUrls.m3uUrl(realCreds))
            assertTrue(text.startsWith("#EXTM3U"), "cabecera m3u")
            assertTrue(text.contains("/live/demo/demo/101.m3u8"), "canal en m3u")
        }
        test("stream live responde HLS válido") {
            val url = XuiUrls.liveUrl(realCreds, 101)
            val body = http.get(url)
            assertTrue(body.startsWith("#EXTM3U"), "playlist HLS: ${body.take(40)}")
            assertTrue(body.contains("seg000.ts"), "segmentos")
        }
        test("segmento .ts descargable") {
            val url = XuiUrls.liveUrl(realCreds, 101).replace("101.m3u8", "seg000.ts")
            val c = URL(url).openConnection() as HttpURLConnection
            eq(200, c.responseCode, "status")
            assertTrue((c.contentLengthLong) > 10_000, "tamaño del segmento")
        }
        test("stream vod responde mp4 con Range") {
            val url = XuiUrls.vodUrl(realCreds, 201, "mp4")
            val c = URL(url).openConnection() as HttpURLConnection
            c.setRequestProperty("Range", "bytes=0-1023")
            eq(206, c.responseCode, "status parcial")
            eq(1024, c.inputStream.readBytes().size, "bytes recibidos")
        }
        test("episodio de serie descargable") {
            val c = URL(XuiUrls.seriesUrl(realCreds, "9001")).openConnection() as HttpURLConnection
            eq(200, c.responseCode, "status")
        }
    }

    println()
    println("RESULTADO: $passed OK, $failed fallos")
    if (failed > 0) {
        failures.forEach { println("  - $it") }
        kotlin.system.exitProcess(1)
    }
}
