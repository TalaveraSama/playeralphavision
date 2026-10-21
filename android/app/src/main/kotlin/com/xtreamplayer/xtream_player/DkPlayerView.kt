package com.xtreamplayer.xtream_player

import android.content.Context
import android.view.SurfaceView
import android.view.View
import android.widget.FrameLayout
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.TrackSelectionOverride
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.hls.HlsMediaSource
import androidx.media3.exoplayer.source.MediaSource
import androidx.media3.exoplayer.source.ProgressiveMediaSource
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import io.github.anilbeesetti.nextlib.media3ext.ffdecoder.DecoderManager
import io.github.anilbeesetti.nextlib.media3ext.ffdecoder.DecoderMode
import io.github.anilbeesetti.nextlib.media3ext.ffdecoder.NextRenderersFactory

class DkPlayerViewFactory(private val messenger: BinaryMessenger) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        DkPlayerView(context, messenger, viewId)
}

class DkPlayerView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
) : PlatformView, MethodChannel.MethodCallHandler {

    private val container = FrameLayout(context)
    private val channel = MethodChannel(messenger, "dk_video_player_$viewId")
    private val player: ExoPlayer
    private val videoView: SurfaceView

    init {
        val decoderManager = DecoderManager()
        val renderersFactory = NextRenderersFactory(context).setDecoderManager(decoderManager)
        val loadControl = DefaultLoadControl.Builder()
            .setBufferDurationsMs(30_000, 120_000, 15_000, 15_000)
            .build()
        player = ExoPlayer.Builder(context, renderersFactory)
            .setLoadControl(loadControl)
            .build()
        decoderManager.attach(player)
        decoderManager.selectVideoDecoder(DecoderMode.HARDWARE)
        decoderManager.selectAudioDecoder(DecoderMode.AUTO)
        videoView = SurfaceView(context)
        container.addView(videoView, FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT))
        player.setVideoSurfaceView(videoView)
        player.addListener(object : Player.Listener {
            override fun onPlayerError(error: PlaybackException) { channel.invokeMethod("onError", null) }
            override fun onPlaybackStateChanged(state: Int) {
                if (state == Player.STATE_READY) channel.invokeMethod("onReady", null)
                if (state == Player.STATE_ENDED) channel.invokeMethod("onCompleted", null)
            }
        })
        channel.setMethodCallHandler(this)
    }

    private fun buildSource(url: String, headers: Map<String, String>): MediaSource {
        val ds = DefaultHttpDataSource.Factory().setDefaultRequestProperties(headers)
        val item = MediaItem.Builder().setUri(url).build()
        return if (url.contains(".m3u8")) HlsMediaSource.Factory(ds).createMediaSource(item)
        else ProgressiveMediaSource.Factory(ds).createMediaSource(item)
    }

    override fun getView(): View = container

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setUrl" -> {
                val url = call.argument<String>("url") ?: ""
                val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                player.setMediaSource(buildSource(url, headers)); result.success(null)
            }
            "start" -> { player.prepare(); player.play(); result.success(null) }
            "pause" -> { player.pause(); result.success(null) }
            "resume" -> { player.play(); result.success(null) }
            "release" -> { player.release(); result.success(null) }
            "seekTo" -> { val ms = call.argument<Number>("ms")?.toLong() ?: 0L; player.seekTo(ms); result.success(null) }
            else -> result.notImplemented()
        }
    }

    override fun dispose() { player.release(); channel.setMethodCallHandler(null) }
}
