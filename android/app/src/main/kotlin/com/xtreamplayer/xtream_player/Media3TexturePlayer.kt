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
) : MethodChannel.MethodCallHandler {

    private val surfaceEntry: TextureRegistry.SurfaceTextureEntry =
        textureRegistry.createSurfaceTexture()
    private val channel = MethodChannel(messenger, "media3_player_$viewId")
    private val player: ExoPlayer
    private var surface: Surface? = null

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
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(8_000, 40_000, 1_500, 3_000)
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
                android.util.Log.e("TEXPLAYER", "PLAYER_ERROR: " + error.message, error)
                channel.invokeMethod("onError", null)
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
        try {
            val dbg = player.currentTracks.groups.mapIndexed { gi, g ->
                "g" + gi + ":type=" + g.type + ":len=" + g.length +
                    ":sup=" + (0 until g.length).joinToString(",") { g.isTrackSupported(it).toString() } +
                    ":lang=" + (0 until g.length).joinToString(",") { (g.getTrackFormat(it).language ?: "-") }
            }
            android.util.Log.e("TEXPLAYER", "tracks-dump " + dbg)
        } catch (e: Exception) {
            android.util.Log.e("TEXPLAYER", "tracks-dump err " + e.message)
        }
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

    private fun buildSource(url: String, headers: Map<String, String>): MediaSource {
        // El User-Agent del panel (AlphaVision-Player) debe ir SIEMPRE; si no,
        // XUI.one devuelve una pagina HTML y el HLS falla con #EXTM3U.
        val ua = headers["User-Agent"]?.takeIf { it.isNotBlank() } ?: "AlphaVision-Player"
        val ds = DefaultHttpDataSource.Factory()
            .setUserAgent(ua)
            .setDefaultRequestProperties(headers)
        val item = MediaItem.Builder().setUri(url).build()
        return if (url.contains(".m3u8")) {
            HlsMediaSource.Factory(ds).createMediaSource(item)
        } else {
            ProgressiveMediaSource.Factory(ds).createMediaSource(item)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setUrl" -> {
                val url = call.argument<String>("url") ?: ""
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                val isLive = call.argument<Boolean>("isLive") ?: true
                android.util.Log.e("TEXPLAYER", "setUrl url=" + url + " live=" + isLive + " headers=" + headers)
                clearCues()
                player.setMediaSource(buildSource(url, headers))
                result.success(null)
            }
            "start" -> { player.prepare(); player.play(); result.success(null) }
            "pause" -> { player.pause(); result.success(null) }
            "resume" -> { player.play(); result.success(null) }
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
            "release" -> {
                player.release()
                surface?.release()
                surface = null
                surfaceEntry.release()
                channel.setMethodCallHandler(null)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun dispose() {
        player.release()
        surface?.release()
        surface = null
        surfaceEntry.release()
    }
}
