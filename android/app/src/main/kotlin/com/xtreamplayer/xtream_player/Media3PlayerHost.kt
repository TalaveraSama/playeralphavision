package com.xtreamplayer.xtream_player

import android.content.Context
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Host del reproductor Media3 con textura de Flutter.
 *
 * Canal `media3_player`:
 *  - `create`  -> { id, textureId }
 *  - `release` -> { id }
 */
class Media3PlayerHost(
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val textureRegistry: TextureRegistry,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "media3_player")
    private val players = HashMap<Long, Media3TexturePlayer>()
    private var nextId = 1L

    init {
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                val id = nextId++
                val mode = call.argument<String>("decoderMode") ?: "auto"
                val bufferSeconds = call.argument<Number>("bufferSeconds")?.toInt() ?: 10
                val player = Media3TexturePlayer(context, messenger, textureRegistry, id, mode, bufferSeconds)
                players[id] = player
                result.success(mapOf("id" to id, "textureId" to player.textureId))
            }
            "release" -> {
                val id = call.argument<Number>("id")?.toLong()
                if (id != null) players.remove(id)?.dispose()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }
}
