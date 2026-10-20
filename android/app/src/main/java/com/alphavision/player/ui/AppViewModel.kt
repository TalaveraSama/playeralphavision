package com.alphavision.player.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.alphavision.core.Category
import com.alphavision.core.Credentials
import com.alphavision.core.EpgEntry
import com.alphavision.core.Episode
import com.alphavision.core.LiveStream
import com.alphavision.core.Series
import com.alphavision.core.SeriesDetail
import com.alphavision.core.UserInfo
import com.alphavision.core.VodStream
import com.alphavision.core.XuiUrls
import com.alphavision.player.AlphaVisionApp
import com.alphavision.player.data.Repository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

enum class Tab { LIVE, MOVIES, SERIES }

sealed interface Screen {
    data object Login : Screen
    data object Home : Screen
    data class Player(val request: PlayerRequest) : Screen
    data class SeriesDetail(val seriesId: Int, val title: String) : Screen
}

data class PlayerRequest(
    val url: String,
    val title: String,
    val subtitle: String? = null,
    val isLive: Boolean = false,
)

data class UiState(
    val screen: Screen = Screen.Login,
    val bootstrapDone: Boolean = false,
    val credentials: Credentials? = null,
    val user: UserInfo? = null,
    val loginInProgress: Boolean = false,
    val loginError: String? = null,
    val tab: Tab = Tab.LIVE,
    val loading: Boolean = false,
    val error: String? = null,
    val query: String = "",
    val liveCategories: List<Category> = emptyList(),
    val selectedLiveCategory: String? = null,
    val live: List<LiveStream> = emptyList(),
    val vodCategories: List<Category> = emptyList(),
    val selectedVodCategory: String? = null,
    val vod: List<VodStream> = emptyList(),
    val seriesCategories: List<Category> = emptyList(),
    val selectedSeriesCategory: String? = null,
    val series: List<Series> = emptyList(),
    val seriesDetail: SeriesDetail? = null,
    val seriesDetailLoading: Boolean = false,
    val epg: List<EpgEntry> = emptyList(),
    val epgChannelName: String? = null,
)

class AppViewModel(app: Application) : AndroidViewModel(app) {

    private val repository: Repository = (app as AlphaVisionApp).container.repository
    private val _state = MutableStateFlow(UiState())
    val state: StateFlow<UiState> = _state.asStateFlow()

    private var liveLoaded = false
    private var vodLoaded = false
    private var seriesLoaded = false

    init {
        restoreSession()
    }

    // ------------------------------------------------------------- sesión --
    private fun restoreSession() {
        viewModelScope.launch {
            val saved = runCatching { repository.savedSession.first() }.getOrNull()
            if (saved == null) {
                _state.value = _state.value.copy(bootstrapDone = true, screen = Screen.Login)
                return@launch
            }
            _state.value = _state.value.copy(credentials = saved, loginInProgress = true)
            runCatching { repository.login(saved) }
                .onSuccess { result ->
                    if (result.isAuthenticated) {
                        _state.value = _state.value.copy(
                            bootstrapDone = true,
                            screen = Screen.Home,
                            user = result.user,
                            loginInProgress = false,
                        )
                        loadLive()
                    } else {
                        repository.clearSession()
                        _state.value = _state.value.copy(
                            bootstrapDone = true,
                            screen = Screen.Login,
                            credentials = null,
                            loginInProgress = false,
                            loginError = "Tu acceso venció o fue desactivado en el panel.",
                        )
                    }
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(
                        bootstrapDone = true,
                        screen = Screen.Login,
                        loginInProgress = false,
                        loginError = "Sin conexión con el panel: ${e.friendly()}",
                    )
                }
        }
    }

    fun submitLogin(baseUrl: String, username: String, password: String) {
        if (baseUrl.isBlank() || username.isBlank() || password.isBlank()) {
            _state.value = _state.value.copy(loginError = "Completa los tres campos.")
            return
        }
        val credentials = Credentials(baseUrl.trim(), username.trim(), password)
        viewModelScope.launch {
            _state.value = _state.value.copy(loginInProgress = true, loginError = null)
            runCatching { repository.login(credentials) }
                .onSuccess { result ->
                    if (result.isAuthenticated) {
                        repository.saveSession(credentials)
                        _state.value = _state.value.copy(
                            credentials = credentials,
                            user = result.user,
                            loginInProgress = false,
                            screen = Screen.Home,
                            loginError = null,
                        )
                        loadLive()
                    } else {
                        _state.value = _state.value.copy(
                            loginInProgress = false,
                            loginError = if (result.user.status.equals("Expired", true)) {
                                "La suscripción expiró."
                            } else {
                                "Usuario o contraseña incorrectos."
                            },
                        )
                    }
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(
                        loginInProgress = false,
                        loginError = "No se pudo conectar: ${e.friendly()}",
                    )
                }
        }
    }

    fun logout() {
        viewModelScope.launch { repository.clearSession() }
        liveLoaded = false
        vodLoaded = false
        seriesLoaded = false
        _state.value = UiState(screen = Screen.Login, bootstrapDone = true)
    }

    // ------------------------------------------------------------ catálogo --
    private fun requireCredentials(): Credentials? = _state.value.credentials

    fun loadLive(force: Boolean = false) {
        val creds = requireCredentials() ?: return
        if (liveLoaded && !force) return
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)
            runCatching { repository.liveCategories(creds) to repository.liveStreams(creds, null) }
                .onSuccess { (cats, streams) ->
                    liveLoaded = true
                    _state.value = _state.value.copy(
                        loading = false,
                        liveCategories = cats,
                        live = streams.sortedBy { it.num },
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(loading = false, error = e.friendly())
                }
        }
    }

    fun loadVod(force: Boolean = false) {
        val creds = requireCredentials() ?: return
        if (vodLoaded && !force) return
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)
            runCatching { repository.vodCategories(creds) to repository.vodStreams(creds, null) }
                .onSuccess { (cats, movies) ->
                    vodLoaded = true
                    _state.value = _state.value.copy(
                        loading = false,
                        vodCategories = cats,
                        vod = movies.sortedBy { it.name.lowercase() },
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(loading = false, error = e.friendly())
                }
        }
    }

    fun loadSeries(force: Boolean = false) {
        val creds = requireCredentials() ?: return
        if (seriesLoaded && !force) return
        viewModelScope.launch {
            _state.value = _state.value.copy(loading = true, error = null)
            runCatching { repository.seriesCategories(creds) to repository.seriesList(creds, null) }
                .onSuccess { (cats, list) ->
                    seriesLoaded = true
                    _state.value = _state.value.copy(
                        loading = false,
                        seriesCategories = cats,
                        series = list.sortedBy { it.name.lowercase() },
                    )
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(loading = false, error = e.friendly())
                }
        }
    }

    fun selectTab(tab: Tab) {
        _state.value = _state.value.copy(tab = tab, query = "")
        when (tab) {
            Tab.LIVE -> loadLive()
            Tab.MOVIES -> loadVod()
            Tab.SERIES -> loadSeries()
        }
    }

    fun selectLiveCategory(categoryId: String?) {
        _state.value = _state.value.copy(selectedLiveCategory = categoryId)
    }

    fun selectVodCategory(categoryId: String?) {
        _state.value = _state.value.copy(selectedVodCategory = categoryId)
    }

    fun selectSeriesCategory(categoryId: String?) {
        _state.value = _state.value.copy(selectedSeriesCategory = categoryId)
    }

    fun setQuery(query: String) {
        _state.value = _state.value.copy(query = query)
    }

    fun retry() {
        when (_state.value.tab) {
            Tab.LIVE -> loadLive(force = true)
            Tab.MOVIES -> loadVod(force = true)
            Tab.SERIES -> loadSeries(force = true)
        }
    }

    // -------------------------------------------------------------- player --
    fun playLive(channel: LiveStream) {
        val creds = requireCredentials() ?: return
        val url = XuiUrls.liveUrl(creds, channel.streamId, "m3u8")
        _state.value = _state.value.copy(
            screen = Screen.Player(
                PlayerRequest(url = url, title = channel.name, subtitle = "EN VIVO", isLive = true),
            ),
            epgChannelName = channel.name,
            epg = emptyList(),
        )
        viewModelScope.launch {
            runCatching { repository.epg(creds, channel.streamId) }
                .onSuccess { entries -> _state.value = _state.value.copy(epg = entries) }
        }
    }

    fun playMovie(movie: VodStream) {
        val creds = requireCredentials() ?: return
        // La extensión real (mp4/mkv/avi) viene en el detalle del VOD.
        viewModelScope.launch {
            val extension = runCatching { repository.vodDetail(creds, movie.streamId) }
                .map { it.containerExtension }
                .getOrElse { movie.containerExtension }
            val url = XuiUrls.vodUrl(creds, movie.streamId, extension)
            _state.value = _state.value.copy(
                screen = Screen.Player(
                    PlayerRequest(url = url, title = movie.name, subtitle = movie.rating?.let { "★ $it" }),
                ),
            )
        }
    }

    fun playEpisode(episode: Episode, seriesTitle: String) {
        val creds = requireCredentials() ?: return
        val url = XuiUrls.seriesUrl(creds, episode.id, episode.containerExtension)
        _state.value = _state.value.copy(
            screen = Screen.Player(
                PlayerRequest(
                    url = url,
                    title = episode.title,
                    subtitle = "$seriesTitle · T${episode.season}E${episode.episodeNum}",
                ),
            ),
        )
    }

    fun closePlayer() {
        _state.value = _state.value.copy(screen = Screen.Home, epg = emptyList(), epgChannelName = null)
    }

    // -------------------------------------------------------------- series --
    fun openSeries(series: Series) {
        val creds = requireCredentials() ?: return
        _state.value = _state.value.copy(
            screen = Screen.SeriesDetail(series.seriesId, series.name),
            seriesDetail = null,
            seriesDetailLoading = true,
        )
        viewModelScope.launch {
            runCatching { repository.seriesDetail(creds, series.seriesId) }
                .onSuccess { detail ->
                    _state.value = _state.value.copy(seriesDetail = detail, seriesDetailLoading = false)
                }
                .onFailure { e ->
                    _state.value = _state.value.copy(
                        seriesDetailLoading = false,
                        error = "No se pudo cargar la serie: ${e.friendly()}",
                    )
                }
        }
    }

    fun closeSeries() {
        _state.value = _state.value.copy(screen = Screen.Home, seriesDetail = null)
    }

    fun dismissError() {
        _state.value = _state.value.copy(error = null)
    }

    fun clearLoginError() {
        _state.value = _state.value.copy(loginError = null)
    }
}

/** Mensajes de error entendibles para el usuario final. */
private fun Throwable.friendly(): String = when (this) {
    is UnknownHostException -> "no se encontró el servidor (revisa la URL)"
    is SocketTimeoutException -> "el panel tardó demasiado en responder"
    is IOException -> message ?: "problema de red"
    else -> message ?: this::class.java.simpleName
}
