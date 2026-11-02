package com.xtreamplayer.xtream_player

import android.content.Intent
import android.view.WindowManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var playlistChannel: MethodChannel? = null
    private var playlistResult: MethodChannel.Result? = null
    private var secureSessionHost: SecureSessionHost? = null
    private var vlcHost: VlcPlayerHost? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Session-wide: prevent route-transition/recents frames from exposing video.
        // This is screen protection, not protection against network capture/root.
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        playlistChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "alphavision/playlists")
        playlistChannel?.setMethodCallHandler { call, result ->
                if (call.method != "pick") { result.notImplemented(); return@setMethodCallHandler }
                if (playlistResult != null) { result.error("BUSY", "Selector abierto", null); return@setMethodCallHandler }
                try {
                    playlistResult = result
                    startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE); type = "*/*"
                    }, 7301)
                } catch (_: Exception) { playlistResult = null; result.error("PICKER", "No hay selector de archivos disponible", null) }
            }
        secureSessionHost = SecureSessionHost(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        // Reproductor VLC con textura de Flutter (sin SurfaceView): vídeo
        // estable en Fire TV. Canal `vlc_player`.
        vlcHost = VlcPlayerHost(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
            flutterEngine.renderer,
        )

        // Instalador de actualizaciones nativo: usa FileProvider.getUriForFile y
        // setDataAndType, que resuelven la ruta y el tipo juntos. El intent
        // manual (data y type por separado) hacía que el instalador no encontrara
        // el archivo («Unable to find path from root») en Fire OS / Android TV.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nova/installer")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path") ?: ""
                        installApk(path, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 7301) return
        val result = playlistResult ?: return
        playlistResult = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) { result.success(null); return }
        Thread {
            try {
                val bytes = contentResolver.openInputStream(uri)?.use { input ->
                    val out = java.io.ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        require(out.size() + n <= 10 * 1024 * 1024)
                        out.write(buffer, 0, n)
                    }
                    out.toByteArray() }
                    ?: throw java.io.IOException()
                require(bytes.size <= 10 * 1024 * 1024)
                val text = bytes.toString(Charsets.UTF_8)
                runOnUiThread { result.success(text) }
            } catch (_: Exception) { runOnUiThread { result.error("FILE", "No se pudo leer la lista o supera 10 MB", null) } }
        }.start()
    }

    override fun onStart() {
        super.onStart()
        vlcHost?.resumeAll()
    }
    override fun onResume() {
        super.onResume()
        vlcHost?.resumeAll() // Mark visible; Flutter must authorize before playback.
    }
    override fun onPause() {
        vlcHost?.suspendAll()
        super.onPause()
    }
    override fun onStop() {
        vlcHost?.suspendAll()
        super.onStop()
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        playlistChannel?.setMethodCallHandler(null)
        playlistChannel = null
        playlistResult?.error("CLOSED", "Selector cerrado", null)
        playlistResult = null
        secureSessionHost?.dispose()
        secureSessionHost = null
        vlcHost?.dispose()
        vlcHost = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
    override fun onDestroy() {
        playlistChannel?.setMethodCallHandler(null)
        playlistChannel = null
        playlistResult?.error("CLOSED", "Selector cerrado", null)
        playlistResult = null
        secureSessionHost?.dispose()
        secureSessionHost = null
        vlcHost?.dispose()
        vlcHost = null
        super.onDestroy()
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        try {
            val file = File(path)
            if (!file.exists()) {
                result.error("NO_FILE", "No existe el APK", null)
                return
            }
            val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_ERR", e.message ?: "error", null)
        }
    }
}
