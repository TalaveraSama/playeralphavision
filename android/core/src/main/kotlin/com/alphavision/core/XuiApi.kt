package com.alphavision.core

import java.util.Base64

/** Transporte HTTP síncrono. La app lo implementa con OkHttp y lo llama desde IO. */
fun interface HttpTransport {
    fun get(url: String): String
}

/**
 * Cliente del API XUI.one / Xtream Codes.
 *
 * Todas las funciones son **síncronas** a propósito: el módulo `core` no depende
 * de coroutines ni de Android, así se puede compilar y testear en JVM puro.
 * En la app se invocan dentro de `withContext(Dispatchers.IO)`.
 */
class XuiApi(private val http: HttpTransport) {

    // ---------------------------------------------------------------- auth --
    fun login(creds: Credentials): LoginResult = parseLogin(http.get(XuiUrls.apiUrl(creds)))

    /** Parsea la respuesta de `player_api.php` (sin acción). */
    fun parseLogin(json: String, creds: Credentials? = null): LoginResult {
        val root = Json.parse(json)
        val userObj = root.obj("user_info")
            ?: throw XuiException("Respuesta inválida del panel: falta 'user_info'")
        val user = UserInfo(
            username = userObj.str("username") ?: creds?.username ?: "",
            auth = userObj.int("auth") ?: 0,
            status = userObj.str("status"),
            expDate = userObj.long("exp_date"),
            isTrial = userObj.bool("is_trial") ?: false,
            activeConnections = userObj.int("active_cons") ?: 0,
            maxConnections = userObj.int("max_connections") ?: 0,
            allowedOutputFormats = userObj.arr("allowed_output_formats")
                .mapNotNull { it.asText() },
            createdAt = userObj.long("created_at"),
        )
        val serverObj = root.obj("server_info")
        val server = serverObj?.let {
            ServerInfo(
                url = it.str("url"),
                port = it.str("port"),
                httpsPort = it.str("https_port"),
                protocol = it.str("server_protocol"),
                rtmpPort = it.str("rtmp_port"),
                timeNow = it.str("time_now"),
                timezone = it.str("timezone"),
            )
        }
        return LoginResult(user, server)
    }

    // ------------------------------------------------------------ catalogo --
    fun liveCategories(creds: Credentials): List<Category> =
        parseCategories(http.get(XuiUrls.apiUrl(creds, "get_live_categories")))

    fun vodCategories(creds: Credentials): List<Category> =
        parseCategories(http.get(XuiUrls.apiUrl(creds, "get_vod_categories")))

    fun seriesCategories(creds: Credentials): List<Category> =
        parseCategories(http.get(XuiUrls.apiUrl(creds, "get_series_categories")))

    fun liveStreams(creds: Credentials, categoryId: String? = null): List<LiveStream> =
        parseLiveStreams(http.get(XuiUrls.apiUrl(creds, "get_live_streams", categoryId?.let { mapOf("category_id" to it) } ?: emptyMap())))

    fun parseLiveStreams(json: String): List<LiveStream> =
        arr(json).mapNotNull { o ->
                val id = o.int("stream_id") ?: return@mapNotNull null
                LiveStream(
                    num = o.int("num") ?: 0,
                    name = o.str("name") ?: "Canal $id",
                    streamId = id,
                    streamIcon = o.str("stream_icon")?.asCleanUrl(),
                    epgChannelId = o.str("epg_channel_id"),
                    categoryId = o.str("category_id"),
                    tvArchive = o.int("tv_archive") ?: 0,
                    streamType = o.str("stream_type"),
                )
            }

    fun vodStreams(creds: Credentials, categoryId: String? = null): List<VodStream> =
        parseVodStreams(http.get(XuiUrls.apiUrl(creds, "get_vod_streams", categoryId?.let { mapOf("category_id" to it) } ?: emptyMap())))

    fun parseVodStreams(json: String): List<VodStream> =
        arr(json).mapNotNull { o ->
                val id = o.int("stream_id") ?: return@mapNotNull null
                VodStream(
                    num = o.int("num") ?: 0,
                    name = o.str("name") ?: "Película $id",
                    streamId = id,
                    streamIcon = o.str("stream_icon")?.asCleanUrl(),
                    categoryId = o.str("category_id"),
                    containerExtension = (o.str("container_extension") ?: "mp4").trimStart('.'),
                    rating = o.str("rating"),
                    added = o.long("added"),
                    plot = o.str("plot"),
                    genre = o.str("genre"),
                    year = o.str("year"),
                )
            }

    fun seriesList(creds: Credentials, categoryId: String? = null): List<Series> =
        parseSeriesList(http.get(XuiUrls.apiUrl(creds, "get_series", categoryId?.let { mapOf("category_id" to it) } ?: emptyMap())))

    fun parseSeriesList(json: String): List<Series> =
        arr(json).mapNotNull { o ->
                val id = o.int("series_id") ?: return@mapNotNull null
                Series(
                    num = o.int("num") ?: 0,
                    name = o.str("name") ?: "Serie $id",
                    seriesId = id,
                    cover = o.str("cover")?.asCleanUrl(),
                    categoryId = o.str("category_id"),
                    plot = o.str("plot"),
                    cast = o.str("cast"),
                    director = o.str("director"),
                    genre = o.str("genre"),
                    releaseDate = o.str("releaseDate") ?: o.str("release_date"),
                    rating = o.str("rating"),
                    backdropPath = o.str("backdrop_path")?.asCleanUrl(),
                )
            }

    // ------------------------------------------------------------- detalles --
    fun seriesInfo(creds: Credentials, seriesId: Int): SeriesDetail =
        parseSeriesInfo(http.get(XuiUrls.apiUrl(creds, "get_series_info", mapOf("series_id" to seriesId.toString()))), seriesId)

    fun parseSeriesInfo(json: String, seriesId: Int): SeriesDetail {
        val root = Json.parse(json)
        val infoObj = root.obj("info")
        val info = infoObj?.let {
            Series(
                seriesId = seriesId,
                name = it.str("name") ?: "",
                cover = it.str("cover")?.asCleanUrl(),
                plot = it.str("plot"),
                cast = it.str("cast"),
                director = it.str("director"),
                genre = it.str("genre"),
                releaseDate = it.str("releaseDate") ?: it.str("release_date"),
                rating = it.str("rating"),
                backdropPath = it.str("backdrop_path")?.asCleanUrl(),
            )
        }
        val seasons = LinkedHashMap<Int, MutableList<Episode>>()
        // El API devuelve `episodes` como objeto: { "1": [...], "2": [...] }
        (root.obj("episodes")?.fields ?: emptyMap()).forEach { (seasonKey, value) ->
            val seasonNumber = seasonKey.toIntOrNull() ?: 0
            val items = (value as? JsonValue.Arr)?.items ?: return@forEach
            for (ep in items) {
                val epId = ep.str("id") ?: ep.str("episode_id") ?: continue
                val infoEp = ep.obj("info")
                val episode = Episode(
                    id = epId,
                    title = ep.str("title") ?: "Episodio ${ep.int("episode_num") ?: 0}",
                    season = ep.int("season") ?: seasonNumber,
                    episodeNum = ep.int("episode_num") ?: 0,
                    containerExtension = (ep.str("container_extension") ?: "mp4").trimStart('.'),
                    plot = infoEp?.str("plot") ?: ep.str("plot"),
                    duration = infoEp?.str("duration") ?: ep.str("duration"),
                    image = (infoEp?.str("movie_image") ?: ep.str("movie_image"))?.asCleanUrl(),
                )
                seasons.getOrPut(episode.season) { mutableListOf() }.add(episode)
            }
        }
        seasons.values.forEach { it.sortBy { ep -> ep.episodeNum } }
        return SeriesDetail(
            seriesId = seriesId,
            info = info,
            seasons = seasons.toSortedMap().mapValues { it.value.toList() },
        )
    }

    fun vodInfo(creds: Credentials, vodId: Int): VodDetail =
        parseVodInfo(http.get(XuiUrls.apiUrl(creds, "get_vod_info", mapOf("vod_id" to vodId.toString()))), vodId)

    fun parseVodInfo(json: String, vodId: Int): VodDetail {
        val root = Json.parse(json)
        val info = root.obj("info")
        val movie = root.obj("movie_data")
        val name = movie?.str("name") ?: info?.str("name") ?: "Película $vodId"
        return VodDetail(
            streamId = movie?.int("stream_id") ?: vodId,
            name = name,
            containerExtension = (movie?.str("container_extension") ?: info?.str("container_extension") ?: "mp4").trimStart('.'),
            plot = info?.str("plot") ?: info?.str("description"),
            cast = info?.str("cast") ?: info?.str("actors"),
            director = info?.str("director"),
            genre = info?.str("genre"),
            releaseDate = info?.str("releasedate") ?: info?.str("release_date"),
            rating = info?.str("rating"),
            duration = info?.str("duration"),
            cover = (info?.str("movie_image") ?: movie?.str("stream_icon"))?.asCleanUrl(),
            backdrop = info?.str("backdrop_path")?.asCleanUrl(),
            youtubeTrailer = info?.str("youtube_trailer"),
        )
    }

    // ----------------------------------------------------------------- EPG --
    fun shortEpg(creds: Credentials, streamId: Int, limit: Int = 12): List<EpgEntry> =
        parseEpg(http.get(XuiUrls.apiUrl(creds, "get_short_epg", mapOf("stream_id" to streamId.toString(), "limit" to limit.toString()))))

    fun fullEpg(creds: Credentials, streamId: Int): List<EpgEntry> =
        parseEpg(http.get(XuiUrls.apiUrl(creds, "get_simple_data_table", mapOf("stream_id" to streamId.toString()))))

    // ------------------------------------------------------------- interne --
    private fun arr(json: String): List<JsonValue.Obj> = when (val v = Json.parse(json)) {
        is JsonValue.Arr -> v.items.mapNotNull { it as? JsonValue.Obj }
        is JsonValue.Obj -> emptyList() // el panel devuelve {} cuando no hay resultados
        else -> throw XuiException("Respuesta inesperada del panel")
    }

    fun parseCategories(json: String): List<Category> =
        arr(json).mapNotNull { o ->
            val id = o.str("category_id") ?: return@mapNotNull null
            Category(id = id, name = o.str("category_name") ?: "Categoría $id")
        }

    fun parseEpg(json: String): List<EpgEntry> {
        val root = Json.parse(json)
        val list = root.arr("epg_listings").ifEmpty { root.arr("listings") }
        return list.mapNotNull { o ->
            val title = o.str("title")?.decodeB64() ?: return@mapNotNull null
            EpgEntry(
                id = o.str("id"),
                channelId = o.str("channel_id"),
                title = title,
                description = o.str("description")?.decodeB64(),
                start = o.str("start"),
                end = o.str("stop") ?: o.str("end"),
                startTimestamp = o.long("start_timestamp"),
                stopTimestamp = o.long("stop_timestamp"),
                nowPlaying = (o.bool("now_playing") ?: false) || (o.int("now_playing") ?: 0) == 1,
                hasArchive = (o.bool("has_archive") ?: false) || (o.int("has_archive") ?: 0) == 1,
            )
        }
    }
}

class XuiException(message: String) : Exception(message)

/** El API manda títulos/descripciones de EPG en base64; a veces ya vienen en claro. */
internal fun String.decodeB64(): String {
    val looksB64 = length >= 8 && length % 4 == 0 && all { it.isLetterOrDigit() || it == '+' || it == '/' || it == '=' }
    if (!looksB64) return this
    return runCatching { String(Base64.getDecoder().decode(this), Charsets.UTF_8).takeIf { it.isNotEmpty() } }.getOrNull() ?: this
}

/** Limpia URLs de carátulas que algunos paneles devuelven como "null" o vacías. */
internal fun String.asCleanUrl(): String? {
    val t = trim()
    return t.takeIf { it.startsWith("http://") || it.startsWith("https://") }
}
