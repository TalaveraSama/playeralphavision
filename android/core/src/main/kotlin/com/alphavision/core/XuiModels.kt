package com.alphavision.core

/** Credenciales de acceso al panel XUI.one (API Xtream Codes). */
data class Credentials(
    val baseUrl: String,
    val username: String,
    val password: String,
) {
    /** URL base ya normalizada (con esquema y sin barra final). */
    val base: String get() = XuiUrls.normalizeBase(baseUrl)
}

data class ServerInfo(
    val url: String? = null,
    val port: String? = null,
    val httpsPort: String? = null,
    val protocol: String? = null,
    val rtmpPort: String? = null,
    val timeNow: String? = null,
    val timezone: String? = null,
)

enum class SubscriptionStatus { ACTIVE, EXPIRED, DISABLED, BANNED, UNKNOWN;

    companion object {
        fun from(raw: String?): SubscriptionStatus = when (raw?.lowercase()?.trim()) {
            "active" -> ACTIVE
            "expired" -> EXPIRED
            "disabled" -> DISABLED
            "banned" -> BANNED
            else -> UNKNOWN
        }
    }
}

data class UserInfo(
    val username: String = "",
    /** 1 si el login fue correcto, 0 si no. */
    val auth: Int = 1,
    val status: String? = null,
    val expDate: Long? = null,
    val isTrial: Boolean = false,
    val activeConnections: Int = 0,
    val maxConnections: Int = 0,
    val allowedOutputFormats: List<String> = emptyList(),
    val createdAt: Long? = null,
) {
    val subscription: SubscriptionStatus get() = SubscriptionStatus.from(status)

    /** Días restantes (null si es ilimitado o desconocido). */
    fun daysLeft(nowEpochSeconds: Long): Long? {
        val exp = expDate ?: return null
        if (exp <= 0L) return null
        return (exp - nowEpochSeconds) / 86_400L
    }
}

data class LoginResult(
    val user: UserInfo,
    val server: ServerInfo?,
) {
    val isAuthenticated: Boolean get() = user.auth == 1
}

data class Category(
    val id: String,
    val name: String,
)

data class LiveStream(
    val num: Int = 0,
    val name: String = "",
    val streamId: Int = 0,
    val streamIcon: String? = null,
    val epgChannelId: String? = null,
    val categoryId: String? = null,
    val tvArchive: Int = 0,
    val streamType: String? = null,
) {
    val hasArchive: Boolean get() = tvArchive > 0
}

data class VodStream(
    val num: Int = 0,
    val name: String = "",
    val streamId: Int = 0,
    val streamIcon: String? = null,
    val categoryId: String? = null,
    val containerExtension: String = "mp4",
    val rating: String? = null,
    val added: Long? = null,
    val plot: String? = null,
    val genre: String? = null,
    val year: String? = null,
)

data class Series(
    val num: Int = 0,
    val name: String = "",
    val seriesId: Int = 0,
    val cover: String? = null,
    val categoryId: String? = null,
    val plot: String? = null,
    val cast: String? = null,
    val director: String? = null,
    val genre: String? = null,
    val releaseDate: String? = null,
    val rating: String? = null,
    val backdropPath: String? = null,
)

data class Episode(
    val id: String,
    val title: String,
    val season: Int,
    val episodeNum: Int,
    val containerExtension: String = "mp4",
    val plot: String? = null,
    val duration: String? = null,
    val image: String? = null,
) {
    /** Los episodios se reproducen con el id del episodio, no con el de la serie. */
    val streamId: String get() = id
}

data class SeriesDetail(
    val seriesId: Int,
    val info: Series?,
    /** Temporada -> episodios, ordenados por número de episodio. */
    val seasons: Map<Int, List<Episode>>,
)

data class EpgEntry(
    val id: String? = null,
    val channelId: String? = null,
    /** Título ya decodificado (el API lo manda en base64). */
    val title: String = "",
    val description: String? = null,
    val start: String? = null,
    val end: String? = null,
    val startTimestamp: Long? = null,
    val stopTimestamp: Long? = null,
    val nowPlaying: Boolean = false,
    val hasArchive: Boolean = false,
) {
    val startMillis: Long? get() = startTimestamp?.times(1000)
    val endMillis: Long? get() = stopTimestamp?.times(1000)
}

data class VodDetail(
    val streamId: Int,
    val name: String,
    val containerExtension: String,
    val plot: String? = null,
    val cast: String? = null,
    val director: String? = null,
    val genre: String? = null,
    val releaseDate: String? = null,
    val rating: String? = null,
    val duration: String? = null,
    val cover: String? = null,
    val backdrop: String? = null,
    val youtubeTrailer: String? = null,
)
