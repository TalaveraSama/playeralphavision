package com.xtreamplayer.xtream_player

import android.content.Context
import android.graphics.Bitmap
import java.io.ByteArrayOutputStream
import androidx.media3.common.text.CueGroup
import android.graphics.SurfaceTexture
import android.view.Surface
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.common.Tracks
import androidx.media3.datasource.DataSource
import androidx.media3.datasource.DataSpec
import androidx.media3.datasource.TransferListener
import androidx.media3.datasource.HttpDataSource
import androidx.media3.exoplayer.upstream.DefaultLoadErrorHandlingPolicy
import androidx.media3.exoplayer.upstream.LoadErrorHandlingPolicy
import org.json.JSONObject
import android.net.Uri
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.mediacodec.MediaCodecSelector
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Reproductor Media3 (ExoPlayer) que dibuja con una [SurfaceTexture] registrada
 * en el motor de Flutter (igual que `video_player`). Así el vídeo se compone
 * como una Textura de Flutter en vez de un SurfaceView: sin parpadeos ni
 * cuadros congelados por el buffer del SurfaceView en Fire TV.
 */
class Media3TexturePlayer(
    private val context: Context,
    messenger: BinaryMessenger,
    textureRegistry: TextureRegistry,
    viewId: Long,
    decoderMode: String = "auto",
    bufferSeconds: Int = 10,
) : MethodChannel.MethodCallHandler {

    private val surfaceEntry: TextureRegistry.SurfaceTextureEntry =
        textureRegistry.createSurfaceTexture()
    private val channel = MethodChannel(messenger, "media3_player_$viewId")
    private val player: ExoPlayer
    private var surface: Surface? = null
    private var released = false
    private var appVisible = true
    private var suspended = false
    private var resumeWhenVisible = false

    private val audioRefs = ArrayList<Pair<Tracks.Group, Int>>()
    private val textRefs = ArrayList<Pair<Tracks.Group, Int>>()

    init {
        // Standard ExoPlayer decoders only: no bundled FFmpeg or alternate engine.
        val renderersFactory = DefaultRenderersFactory(context)
            .setExtensionRendererMode(DefaultRenderersFactory.EXTENSION_RENDERER_MODE_OFF)
            .setEnableDecoderFallback(true)
            .setMediaCodecSelector(MediaCodecSelector { mimeType, secure, tunneling ->
                val available = MediaCodecSelector.DEFAULT.getDecoderInfos(mimeType, secure, tunneling)
                // Audio remains under ExoPlayer's normal selection. No encoder or FFmpeg.
                if (!mimeType.startsWith("video/")) available else when (decoderMode) {
                    "hardware" -> available.sortedByDescending { it.hardwareAccelerated }
                    "software" -> available.filter { it.softwareOnly }
                    else -> available
                }
            })
        val reserveSeconds = if (bufferSeconds in listOf(10, 20, 30)) bufferSeconds else 10
        val maxBufferMs = reserveSeconds * 1000
        val loadControl = DefaultLoadControl.Builder()
            // Reserve != startup delay. Begin after ~500 ms of playable media;
            // rebuffer needs ~1 s. Network/keyframes/manifest still affect startup.
            .setBufferDurationsMs(maxBufferMs / 2, maxBufferMs, 500, 1_000)
            .setPrioritizeTimeOverSizeThresholds(true)
            .build()
        player = ExoPlayer.Builder(context, renderersFactory)
            .setLoadControl(loadControl)
            .build()
        val st: SurfaceTexture = surfaceEntry.surfaceTexture()
        surface = Surface(st)
        player.setVideoSurface(surface)

        player.addListener(object : Player.Listener {
            override fun onCues(cueGroup: CueGroup) {
                sendCues(cueGroup)
            }

            override fun onPlayerError(error: PlaybackException) {
                clearCues()
                val http = generateSequence(error as Throwable?) { it.cause }
                    .filterIsInstance<HttpDataSource.InvalidResponseCodeException>().firstOrNull()
                val allowed = setOf("device_required", "device_invalid", "device_revoked", "device_limit")
                val code = try { JSONObject(http?.responseBody?.toString(Charsets.UTF_8) ?: "{}").optString("error") }
                    catch (_: Exception) { "" }
                val headers = http?.headerFields ?: emptyMap()
                val retry = headers.entries.firstOrNull { it.key.equals("Retry-After", true) }?.value?.firstOrNull()
                var retrySeconds = retry?.toLongOrNull()
                if (retrySeconds == null && retry != null) {
                    try {
                        val format = java.text.SimpleDateFormat("EEE, dd MMM yyyy HH:mm:ss zzz", java.util.Locale.US)
                        val serverDate = headers.entries.firstOrNull { it.key.equals("Date", true) }?.value?.firstOrNull()
                        val base = serverDate?.let { format.parse(it)?.time } ?: System.currentTimeMillis()
                        retrySeconds = ((format.parse(retry)?.time ?: base) - base) / 1000
                    } catch (_: Exception) { }
                }
                val drm = http?.dataSpec?.uri?.path?.contains("/drm/") == true
                channel.invokeMethod("onError", mapOf("status" to http?.responseCode,
                    "code" to if (code in allowed) code else "", "drm" to drm,
                    "retryAfter" to maxOf(1L, retrySeconds ?: 600L)))
            }

            override fun onPlaybackStateChanged(state: Int) {
                channel.invokeMethod("onBuffering", state == Player.STATE_BUFFERING)
                if (state == Player.STATE_READY) channel.invokeMethod("onReady", null)
                if (state == Player.STATE_ENDED) {
                    clearCues()
                    channel.invokeMethod("onComplete", null)
                }
            }

            override fun onTracksChanged(tracks: Tracks) {
                refreshTracks()
                channel.invokeMethod("onTracksChanged", null)
            }
        })
        player.addAnalyticsListener(object : AnalyticsListener {
            override fun onBandwidthEstimate(
                eventTime: AnalyticsListener.EventTime,
                totalLoadTimeMs: Int,
                totalBytesLoaded: Long,
                bitrateEstimate: Long,
            ) {
                // Una medición real del stream, no un contador simulado.
                if (totalLoadTimeMs > 0 && totalBytesLoaded > 0) {
                    channel.invokeMethod("onNetworkSample", totalBytesLoaded * 1000.0 / totalLoadTimeMs)
                }
            }
        })
        channel.setMethodCallHandler(this)
    }

    val textureId: Long get() = surfaceEntry.id()

    // A SurfaceTexture carries video pixels only, not ExoPlayer text output.
    // Forward timed cues separately so Flutter can apply the user's text style.
    private fun clearCues() = channel.invokeMethod("onCues", emptyList<Any>())

    private fun sendCues(group: CueGroup) {
        val payload = group.cues.map { cue ->
            val bitmapBytes = cue.bitmap?.let { bitmap ->
                ByteArrayOutputStream().use { stream ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    stream.toByteArray()
                }
            }
            mapOf(
                "text" to cue.text?.toString(),
                "bitmap" to bitmapBytes,
                "position" to cue.position,
                "positionAnchor" to cue.positionAnchor,
                "line" to cue.line,
                "lineType" to cue.lineType,
                "lineAnchor" to cue.lineAnchor,
                "size" to cue.size,
                "bitmapHeight" to cue.bitmapHeight,
                "alignment" to cue.textAlignment?.name,
            )
        }
        channel.invokeMethod("onCues", payload)
    }

    private fun refreshTracks() {
        audioRefs.clear()
        textRefs.clear()
        for (group in player.currentTracks.groups) {
            for (i in 0 until group.length) {
                if (!group.isTrackSupported(i)) continue
                when (group.type) {
                    C.TRACK_TYPE_AUDIO -> audioRefs.add(group to i)
                    C.TRACK_TYPE_TEXT -> textRefs.add(group to i)
                }
            }
        }
    }

    private fun tracksPayload(): Map<String, Any?> {
        refreshTracks()
        val audio = audioRefs.mapIndexed { idx, pair ->
            val f = pair.first.getTrackFormat(pair.second)
            mapOf(
                "index" to idx,
                "language" to (f.language ?: ""),
                "label" to (f.label ?: ""),
                "selected" to pair.first.isTrackSelected(pair.second),
            )
        }
        val text = textRefs.mapIndexed { idx, pair ->
            val f = pair.first.getTrackFormat(pair.second)
            mapOf(
                "index" to idx,
                "language" to (f.language ?: ""),
                "label" to (f.label ?: ""),
                "selected" to pair.first.isTrackSelected(pair.second),
            )
        }
        val disabled = player.trackSelectionParameters.disabledTrackTypes.contains(C.TRACK_TYPE_TEXT)
        return mapOf("audio" to audio, "text" to text, "textDisabled" to disabled)
    }

    private fun selectTrack(type: Int, index: Int) {
        refreshTracks()
        if (type == C.TRACK_TYPE_TEXT) clearCues()
        val refs = if (type == C.TRACK_TYPE_AUDIO) audioRefs else textRefs
        val builder = player.trackSelectionParameters.buildUpon()
        if (index < 0) {
            if (type == C.TRACK_TYPE_TEXT) builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, true)
            player.trackSelectionParameters = builder.build()
            return
        }
        if (index >= refs.size) return
        val pair = refs[index]
        if (type == C.TRACK_TYPE_TEXT) builder.setTrackTypeDisabled(C.TRACK_TYPE_TEXT, false)
        builder.setOverrideForType(TrackSelectionOverride(pair.first.mediaTrackGroup, pair.second))
        player.trackSelectionParameters = builder.build()
    }

    private fun buildSource(url: String, headers: Map<String, String>, allowHttp: Boolean, isHls: Boolean): MediaSource {
        // El User-Agent del panel (AlphaVision-Player) debe ir SIEMPRE; si no,
        // XUI.one devuelve una pagina HTML y el HLS falla con #EXTM3U.
        val ua = headers["User-Agent"]?.takeIf { it.isNotBlank() } ?: "AlphaVision-Player"
        require(Uri.parse(url).scheme == "https" || (allowHttp && Uri.parse(url).scheme == "http")) { "HTTPS requerido" }
        val ds = DefaultHttpDataSource.Factory()
            .setAllowCrossProtocolRedirects(false)
            .setConnectTimeoutMs(8000)
            .setReadTimeoutMs(12000)
            .setUserAgent(ua)
            .setDefaultRequestProperties(headers)
        val item = MediaItem.Builder().setUri(url).build()
        val guarded = DataSource.Factory {
            val upstream = ds.createDataSource()
            object : DataSource {
                override fun open(spec: DataSpec): Long {
                    if (spec.uri.scheme != "https" && !(allowHttp && spec.uri.scheme == "http"))
                        throw java.io.IOException("HTTP no autorizado para este perfil")
                    return upstream.open(spec)
                }
                override fun read(buffer: ByteArray, offset: Int, length: Int) = upstream.read(buffer, offset, length)
                override fun getUri() = upstream.uri
                override fun getResponseHeaders() = upstream.responseHeaders
                override fun addTransferListener(listener: TransferListener) = upstream.addTransferListener(listener)
                override fun close() = upstream.close()
            }
        }
        val policy = object : DefaultLoadErrorHandlingPolicy() {
            override fun getRetryDelayMsFor(info: LoadErrorHandlingPolicy.LoadErrorInfo): Long {
                val failure = generateSequence(info.exception as Throwable?) { it.cause }
                    .filterIsInstance<HttpDataSource.InvalidResponseCodeException>().firstOrNull()
                if (failure != null && failure.responseCode in setOf(401, 403, 429, 503)) return C.TIME_UNSET
                return super.getRetryDelayMsFor(info)
            }
        }
        return if (isHls || (Uri.parse(url).path ?: "").lowercase().endsWith(".m3u8")) {
            HlsMediaSource.Factory(guarded).setLoadErrorHandlingPolicy(policy).createMediaSource(item)
        } else {
            ProgressiveMediaSource.Factory(guarded).setLoadErrorHandlingPolicy(policy).createMediaSource(item)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (released) { result.error("RELEASED", "Player already released", null); return }
        when (call.method) {
            "setUrl" -> {
                val url = call.argument<String>("url") ?: ""
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                val isLive = call.argument<Boolean>("isLive") ?: true
                clearCues()
                player.stop()
                player.clearMediaItems()
                player.setMediaSource(buildSource(url, headers, call.argument<Boolean>("allowHttp") == true, call.argument<Boolean>("isHls") == true))
                result.success(null)
            }
            "stopPlayback" -> { player.stop(); player.clearMediaItems(); result.success(null) }
            "start" -> {
                if (suspended || !appVisible) resumeWhenVisible = true else { player.prepare(); player.play() }
                result.success(null)
            }
            "pause" -> { resumeWhenVisible = false; player.pause(); result.success(null) }
            "resume" -> {
                if (suspended || !appVisible) resumeWhenVisible = true else player.play()
                result.success(null)
            }
            "suspendPlayback" -> { suspendPlayback(); result.success(null) }
            "resumePlayback" -> { resumePlayback(); result.success(null) }
            "getTracks" -> result.success(tracksPayload())
            "selectAudio" -> {
                selectTrack(C.TRACK_TYPE_AUDIO, call.argument<Int>("index") ?: 0)
                result.success(null)
            }
            "selectText" -> {
                selectTrack(C.TRACK_TYPE_TEXT, call.argument<Int>("index") ?: -1)
                result.success(null)
            }
            "seekTo" -> {
                clearCues()
                player.seekTo(call.argument<Number>("ms")?.toLong() ?: 0L)
                result.success(null)
            }
            "getPosition" -> result.success(mapOf("pos" to maxOf(0L, player.currentPosition), "dur" to maxOf(0L, player.duration)))
            "release" -> { dispose(); result.success(null) }
            else -> result.notImplemented()
        }
    }

    fun setAppVisible(visible: Boolean) {
        appVisible = visible
        if (!visible) suspendPlayback()
        // Returning requires Flutter to complete the panel heartbeat first.
    }

    fun suspendPlayback() {
        if (released || suspended) return
        resumeWhenVisible = player.playWhenReady
        suspended = true
        player.stop() // Stop loading and audio/video while the app is not visible.
    }

    fun resumePlayback() {
        if (released || !suspended || !appVisible) return
        suspended = false
        player.prepare()
        if (player.isCurrentMediaItemLive) player.seekToDefaultPosition()
        player.playWhenReady = resumeWhenVisible
    }

    fun dispose() {
        if (released) return
        released = true
        channel.setMethodCallHandler(null)
        player.release()
        surface?.release()
        surface = null
        surfaceEntry.release()
    }
}
