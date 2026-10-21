package com.xtreamplayer.xtream_player

import android.content.Context
import android.graphics.SurfaceTexture
import android.view.Surface
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry
import tv.danmaku.ijk.media.player.IMediaPlayer
import tv.danmaku.ijk.media.player.misc.ITrackInfo
import tv.danmaku.ijk.media.player.IjkMediaPlayer

/**
 * Reproductor ijkplayer NATIVO con textura de Flutter (sin plugin de terceros).
 *
 * Permite leer la lista real de pistas (`getTrackInfo`) y cambiar audio/subtítulo
 * igual que hacen Xuper e IPTV Smarters.
 *
 * Canal `ijk_player`:
 *  - `create`      -> { id, textureId }
 *  - `open`        -> { id, url, headers? }
 *  - `play` / `pause` / `seek` / `release`
 *  - `tracks`      -> lista de pistas (audio y subtítulos)
 *  - `selectTrack` -> { id, index }
 *
 * Eventos hacia Dart: `prepared`, `size`, `position`, `completed`, `error`.
 */
class IjkPlayerHost(
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val textureRegistry: TextureRegistry,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "ijk_player")
    private val players = HashMap<Long, Entry>()
    private var nextId = 1L

    private class Entry(
        val id: Long,
        val player: IjkMediaPlayer,
        val texture: TextureRegistry.SurfaceTextureEntry,
        val surface: Surface,
    )

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> create(result)
            "open" -> open(call, result)
            "play" -> tap(call, result) { it.start() }
            "pause" -> tap(call, result) { it.pause() }
            "seek" -> {
                val id = call.argument<Number>("id")?.toLong()
                val ms = call.argument<Number>("ms")?.toLong() ?: 0L
                players[id]?.player?.seekTo(ms)
                result.success(null)
            }
            "tracks" -> tracks(call, result)
            "selectTrack" -> {
                val id = call.argument<Number>("id")?.toLong()
                val index = call.argument<Number>("index")?.toInt() ?: 0
                players[id]?.player?.selectTrack(index)
                result.success(null)
            }
            "release" -> {
                val id = call.argument<Number>("id")?.toLong()
                players.remove(id)?.let {
                    it.player.release()
                    it.surface.release()
                    it.texture.release()
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun create(result: MethodChannel.Result) {
        val id = nextId++
        val texture = textureRegistry.createSurfaceTexture()
        val surface = Surface(texture.surfaceTexture())
        val player = IjkMediaPlayer().apply {
            setSurface(surface)
            isLooping = false
            setOnPreparedListener {
                channel.invokeMethod("prepared", mapOf("id" to id))
            }
            setOnVideoSizeChangedListener { _, width, height, _, _ ->
                channel.invokeMethod(
                    "size",
                    mapOf("id" to id, "width" to width, "height" to height),
                )
            }
            setOnCompletionListener {
                channel.invokeMethod("completed", mapOf("id" to id))
            }
            setOnErrorListener { _, what, extra ->
                channel.invokeMethod(
                    "error",
                    mapOf("id" to id, "what" to what, "extra" to extra),
                )
                true
            }
        }
        players[id] = Entry(id, player, texture, surface)
        result.success(mapOf("id" to id, "textureId" to texture.id()))
    }

    private fun open(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("id")?.toLong()
        val url = call.argument<String>("url") ?: ""
        val headers = call.argument<Map<String, String>>("headers")
        val entry = players[id]
        if (entry == null) {
            result.error("NO_PLAYER", "id desconocido", null)
            return
        }
        try {
            val player = entry.player
            if (!headers.isNullOrEmpty()) {
                val line = headers.entries.joinToString("\r\n") { "${it.key}: ${it.value}" }
                player.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "headers", line)
            }
            player.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "probesize", 1000000)
            player.setOption(IjkMediaPlayer.OPT_CATEGORY_FORMAT, "analyzeduration", 2000000)
            player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "framedrop", 1)
            player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "packet-buffering", 1)
            player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "infbuf", 1)
            player.setOption(IjkMediaPlayer.OPT_CATEGORY_PLAYER, "start-on-prepared", 1)
            player.setDataSource(url)
            player.prepareAsync()
            result.success(null)
        } catch (e: Exception) {
            result.error("OPEN_ERR", e.message ?: "error", null)
        }
    }

    private inline fun tap(
        call: MethodCall,
        result: MethodChannel.Result,
        action: (IjkMediaPlayer) -> Unit,
    ) {
        val id = call.argument<Number>("id")?.toLong()
        val entry = players[id]
        if (entry == null) {
            result.error("NO_PLAYER", "id desconocido", null)
            return
        }
        action(entry.player)
        result.success(null)
    }

    private fun tracks(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<Number>("id")?.toLong()
        val player = players[id]?.player
        val list = ArrayList<Map<String, Any?>>()
        try {
            val infos = player?.trackInfo ?: emptyArray()
            for (i in infos.indices) {
                val info = infos[i]
                val type = when (info.trackType) {
                    ITrackInfo.MEDIA_TRACK_TYPE_AUDIO -> "audio"
                    ITrackInfo.MEDIA_TRACK_TYPE_SUBTITLE -> "subtitle"
                    ITrackInfo.MEDIA_TRACK_TYPE_VIDEO -> "video"
                    else -> "other"
                }
                if (type == "audio" || type == "subtitle") {
                    list.add(
                        mapOf(
                            "index" to i,
                            "type" to type,
                            "language" to (info.language ?: ""),
                            "label" to (info.infoInline ?: ""),
                        ),
                    )
                }
            }
            result.success(list)
        } catch (e: Exception) {
            result.error("TRACKS_ERR", e.message ?: "error", null)
        }
    }

    fun disposeAll() {
        players.values.forEach {
            it.player.release()
            it.surface.release()
            it.texture.release()
        }
        players.clear()
    }
}
