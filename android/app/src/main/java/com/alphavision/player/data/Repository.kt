package com.alphavision.player.data

import com.alphavision.core.Category
import com.alphavision.core.Credentials
import com.alphavision.core.EpgEntry
import com.alphavision.core.LiveStream
import com.alphavision.core.LoginResult
import com.alphavision.core.Series
import com.alphavision.core.SeriesDetail
import com.alphavision.core.VodDetail
import com.alphavision.core.VodStream
import com.alphavision.core.XuiApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Envuelve el cliente síncrono de `core` en coroutines (IO) y centraliza
 * el acceso de la UI a los datos.
 */
class Repository(
    private val api: XuiApi,
    private val sessionStore: SessionStore,
) {

    suspend fun login(credentials: Credentials): LoginResult = io { api.login(credentials) }

    suspend fun liveCategories(credentials: Credentials): List<Category> =
        io { api.liveCategories(credentials) }

    suspend fun liveStreams(credentials: Credentials, categoryId: String?): List<LiveStream> =
        io { api.liveStreams(credentials, categoryId) }

    suspend fun vodCategories(credentials: Credentials): List<Category> =
        io { api.vodCategories(credentials) }

    suspend fun vodStreams(credentials: Credentials, categoryId: String?): List<VodStream> =
        io { api.vodStreams(credentials, categoryId) }

    suspend fun vodDetail(credentials: Credentials, vodId: Int): VodDetail =
        io { api.vodInfo(credentials, vodId) }

    suspend fun seriesCategories(credentials: Credentials): List<Category> =
        io { api.seriesCategories(credentials) }

    suspend fun seriesList(credentials: Credentials, categoryId: String?): List<Series> =
        io { api.seriesList(credentials, categoryId) }

    suspend fun seriesDetail(credentials: Credentials, seriesId: Int): SeriesDetail =
        io { api.seriesInfo(credentials, seriesId) }

    suspend fun epg(credentials: Credentials, streamId: Int): List<EpgEntry> =
        io { api.shortEpg(credentials, streamId) }

    suspend fun saveSession(credentials: Credentials) = sessionStore.save(credentials)

    suspend fun clearSession() = sessionStore.clear()

    val savedSession = sessionStore.credentials

    private suspend fun <T> io(block: () -> T): T = withContext(Dispatchers.IO) { block() }
}
