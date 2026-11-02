package com.xtreamplayer.xtream_player

import android.content.Context
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

/**
 * Host del reproductor VLC con textura de Flutter.
 *
 * Canal `vlc_player`:
 *  - `create`  -> { id, textureId }
 *  - `release` -> { id }
 */
class VlcPlayerHost(
    private val context: Context,
    private val messenger: BinaryMessenger,
    private val textureRegistry: TextureRegistry,
) : MethodChannel.MethodCallHandler {

    private val channel = MethodChannel(messenger, "vlc_player")
    private val players = HashMap<Long, VlcTexturePlayer>()
    private var nextId = 1L
    private var suspended = false

    init {
        channel.setMethodCallHandler(this)
    }

    fun suspendAll() {
        suspended = true
        players.values.forEach { it.setAppVisible(false) }
    }
    fun resumeAll() {
        suspended = false
        players.values.forEach { it.setAppVisible(true) }
    }
    fun dispose() {
        channel.setMethodCallHandler(null)
        players.values.forEach { it.dispose() }
        players.clear()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> {
                if (players.isNotEmpty()) {
                    result.error("PLAYER_ALREADY_ACTIVE", "Cierra el reproductor anterior", null)
                    return
                }
                val id = nextId++
                val mode = call.argument<String>("decoderMode") ?: "auto"
                val bufferSeconds = call.argument<Number>("bufferSeconds")?.toInt() ?: 10
                val player = try {
                    VlcTexturePlayer(context, messenger, textureRegistry, id, mode, bufferSeconds,
                        call.argument<String>("subtitleColor") ?: "#FFFFFF",
                        call.argument<Number>("subtitleSize")?.toInt() ?: 22)
                } catch (error: LinkageError) {
                    // MethodChannel catches RuntimeException, not JNI load/link errors.
                    // Creation has not received a stream URL or any account headers.
                    Log.e("AlphaVisionVLC", "Native library initialization failed", error)
                    result.error("VLC_NATIVE_LOAD", "No se pudo cargar la biblioteca nativa VLC.", error.javaClass.simpleName)
                    return
                } catch (error: RuntimeException) {
                    Log.e("AlphaVisionVLC", "Player initialization failed", error)
                    result.error("VLC_INIT", "No se pudo inicializar VLC.", error.javaClass.simpleName)
                    return
                }
                if (suspended) player.setAppVisible(false)
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
