package com.xtreamplayer.xtream_player

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import org.videolan.libvlc.LibVLC
import org.videolan.libvlc.Media
import org.videolan.libvlc.MediaPlayer
import org.videolan.libvlc.interfaces.IVLCVout
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/** Official LibVLC, rendering to a Flutter texture (no external VLC app). */
class VlcTexturePlayer(
    context: Context,
    messenger: BinaryMessenger,
    textureRegistry: TextureRegistry,
    viewId: Long,
    private val decoderMode: String,
    bufferSeconds: Int,
    subtitleColor: String,
    subtitleSize: Int,
) : MethodChannel.MethodCallHandler, IVLCVout.OnNewVideoLayoutListener {
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "vlc_player_$viewId")
    private val color = try { subtitleColor.removePrefix("#").toLong(16).toInt() and 0xffffff } catch (_: Exception) { 0xffffff }
    private val lib = LibVLC(context.applicationContext, arrayListOf("--quiet", "--verbose=-1", "--no-video-title-show",
        "--network-caching=300", "--live-caching=300", "--adaptive-maxbuffer=${if (bufferSeconds in listOf(10,20,30)) bufferSeconds else 10}",
        "--freetype-color=$color", "--freetype-fontsize=${subtitleSize.coerceIn(14,40)}"))
    private val player = MediaPlayer(lib)
    private val entry = textureRegistry.createSurfaceTexture()
    private var gateway: VlcStreamGateway? = null
    private var source = ""
    private var headers = emptyMap<String, String>()
    private var panelOrigin = ""
    private var allowHttp = false
    private var isLive = true
    private var isHls = false
    private var loaded = false
    private var released = false
    private var visible = true
    private var suspended = false
    private var resumeWhenVisible = false
    private var savedPosition = 0L
    private var generation = 0
    private var errorSent = false
    private var pendingSeek = false
    init {
        entry.surfaceTexture().setDefaultBufferSize(1280, 720)
        player.vlcVout.setVideoSurface(entry.surfaceTexture())
        player.vlcVout.setWindowSize(1280,720)
        player.vlcVout.attachViews(this)
        channel.setMethodCallHandler(this)
    }
    val textureId: Long get() = entry.id()
    override fun onNewVideoLayout(vout: IVLCVout, width: Int, height: Int, visibleWidth: Int, visibleHeight: Int, sarNum: Int, sarDen: Int) {
        if (released || width <= 0 || height <= 0 || width > 8192 || height > 8192) return
        entry.surfaceTexture().setDefaultBufferSize(width,height)
        vout.setWindowSize(width,height)
        val w = if (visibleWidth > 0) visibleWidth else width
        val h = if (visibleHeight > 0) visibleHeight else height
        val ratio = w.toDouble() / h * if (sarNum > 0 && sarDen > 0) sarNum.toDouble()/sarDen else 1.0
        channel.invokeMethod("onVideoSize", ratio)
    }
    private fun stopStream() {
        generation++
        player.setEventListener(null)
        gateway?.close(); gateway = null
        player.stop()
        loaded = false
    }
    private fun report(data: Map<String, Any?>, version: Int) {
        main.post {
            if (!released && version == generation && !errorSent) {
                errorSent = true
                channel.invokeMethod("onBuffering", false)
                channel.invokeMethod("onError", data)
            }
        }
    }
    private fun play() {
        if (released || suspended || !visible || source.isEmpty()) return
        if (!loaded) {
            stopStream()
            val version = generation
            errorSent = false
            val relay = VlcStreamGateway(source, headers, allowHttp, panelOrigin, isHls) { data -> report(data, version) }
            gateway = relay
            player.setEventListener { event ->
                if (!released && version == generation) {
                    when (event.type) {
                        MediaPlayer.Event.Opening -> channel.invokeMethod("onBuffering", true)
                        MediaPlayer.Event.Buffering -> channel.invokeMethod("onBuffering", event.buffering < 100f)
                        MediaPlayer.Event.Playing -> {
                            if (pendingSeek && !isLive && savedPosition > 0) { player.setTime(savedPosition); pendingSeek = false }
                            channel.invokeMethod("onReady", null)
                        }
                        MediaPlayer.Event.EncounteredError -> report(mapOf("status" to null, "code" to "vlc_playback"), version)
                        MediaPlayer.Event.EndReached -> channel.invokeMethod("onComplete", null)
                    }
                }
            }
            val media = Media(lib, Uri.parse(relay.url))
            when (decoderMode) {
                "software" -> media.setHWDecoderEnabled(false, false)
                "hardware" -> media.setHWDecoderEnabled(true, false)
                else -> Unit
            }
            if (isHls || Uri.parse(source).path?.lowercase()?.endsWith(".m3u8") == true) media.addOption(":demux=adaptive")
            media.addOption(":network-caching=300")
            player.setMedia(media)
            media.release()
            loaded = true
        }
        player.play()
    }
    fun setAppVisible(value: Boolean) { visible = value; if (!value) suspendPlayback() }
    fun suspendPlayback() {
        if (released || suspended) return
        resumeWhenVisible = player.isPlaying
        if (!isLive) savedPosition = maxOf(0L, player.time)
        suspended = true
        stopStream()
    }
    fun resumePlayback() {
        if (released || !suspended || !visible) return
        suspended = false
        pendingSeek = !isLive
        if (resumeWhenVisible) play()
    }
    private fun tracks(text: Boolean): List<Map<String, Any?>> {
        val items = if (text) player.spuTracks else player.audioTracks
        val selected = if (text) player.spuTrack else player.audioTrack
        return items?.filter { it.id >= 0 }?.map { mapOf("index" to it.id, "label" to it.name, "selected" to (it.id == selected)) } ?: emptyList()
    }
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (released) { result.error("RELEASED", "VLC ya fue liberado", null); return }
        try {
            when (call.method) {
                "setUrl" -> {
                    stopStream()
                    val url = call.argument<String>("url") ?: ""
                    val permit = call.argument<Boolean>("allowHttp") == true
                    val uri = Uri.parse(url)
                    require(uri.scheme == "https" || (permit && uri.scheme == "http"))
                    require(uri.host != null && uri.userInfo == null)
                    source = url; allowHttp = permit
                    headers = call.argument<Map<String,String>>("headers") ?: emptyMap()
                    panelOrigin = call.argument<String>("panelOrigin") ?: ""
                    isLive = call.argument<Boolean>("isLive") != false
                    isHls = call.argument<Boolean>("isHls") == true
                    savedPosition = 0; pendingSeek = false
                    result.success(null)
                }
                "stopPlayback" -> { stopStream(); source = ""; result.success(null) }
                "start", "resume" -> {
                    if (suspended || !visible) resumeWhenVisible = true else play()
                    result.success(null)
                }
                "pause" -> { resumeWhenVisible = false; player.pause(); result.success(null) }
                "suspendPlayback" -> { suspendPlayback(); result.success(null) }
                "resumePlayback" -> { resumePlayback(); result.success(null) }
                "getPosition" -> result.success(mapOf("pos" to maxOf(0L,player.time), "dur" to maxOf(0L,player.length)))
                "seekTo" -> { player.setTime(call.argument<Number>("ms")?.toLong() ?: 0L); result.success(null) }
                "getTracks" -> result.success(mapOf("audio" to tracks(false), "text" to tracks(true), "textDisabled" to (player.spuTrack < 0)))
                "selectAudio" -> { player.setAudioTrack(call.argument<Int>("index") ?: -1); result.success(null) }
                "selectText" -> { player.setSpuTrack(call.argument<Int>("index") ?: -1); result.success(null) }
                "release" -> { dispose(); result.success(null) }
                else -> result.notImplemented()
            }
        } catch (_: Exception) { result.error("VLC_PLAYER", "No se pudo completar la operación de VLC", null) }
    }
    fun dispose() {
        if (released) return
        released = true
        channel.setMethodCallHandler(null)
        stopStream()
        player.vlcVout.detachViews()
        player.release(); lib.release(); entry.release()
    }
}
