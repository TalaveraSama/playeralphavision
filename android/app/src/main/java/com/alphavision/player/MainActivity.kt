package com.alphavision.player

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.alphavision.player.ui.AppViewModel
import com.alphavision.player.ui.HomeScreen
import com.alphavision.player.ui.LoadingBox
import com.alphavision.player.ui.LoginScreen
import com.alphavision.player.ui.PlayerScreen
import com.alphavision.player.ui.Screen
import com.alphavision.player.ui.SeriesDetailScreen
import com.alphavision.player.ui.theme.AlphaVisionTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            AlphaVisionTheme(darkTheme = true) {
                AlphaVisionRoot()
            }
        }
    }
}

@Composable
private fun AlphaVisionRoot(viewModel: AppViewModel = viewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(state.error) {
        val error = state.error
        if (error != null) {
            snackbarHostState.showSnackbar(error)
            viewModel.dismissError()
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        if (!state.bootstrapDone) {
            LoadingBox("Conectando…")
            return@Box
        }

        when (val screen = state.screen) {
            is Screen.Login -> LoginScreen(
                inProgress = state.loginInProgress,
                error = state.loginError,
                initialBaseUrl = state.credentials?.baseUrl.orEmpty(),
                initialUsername = state.credentials?.username.orEmpty(),
                onConnect = viewModel::submitLogin,
                onClearError = viewModel::clearLoginError,
            )

            is Screen.Home -> HomeScreen(
                state = state,
                onTab = viewModel::selectTab,
                onQuery = viewModel::setQuery,
                onLiveCategory = viewModel::selectLiveCategory,
                onVodCategory = viewModel::selectVodCategory,
                onSeriesCategory = viewModel::selectSeriesCategory,
                onPlayChannel = viewModel::playLive,
                onPlayMovie = viewModel::playMovie,
                onOpenSeries = viewModel::openSeries,
                onRetry = viewModel::retry,
                onLogout = viewModel::logout,
            )

            is Screen.SeriesDetail -> SeriesDetailScreen(
                state = state,
                title = screen.title,
                onBack = viewModel::closeSeries,
                onPlayEpisode = viewModel::playEpisode,
            )

            is Screen.Player -> PlayerScreen(
                request = screen.request,
                epg = state.epg,
                onBack = viewModel::closePlayer,
            )
        }

        SnackbarHost(
            hostState = snackbarHostState,
            modifier = Modifier.fillMaxSize(),
        )
    }
}
