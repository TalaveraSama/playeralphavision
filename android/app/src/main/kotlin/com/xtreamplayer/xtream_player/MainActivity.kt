package com.xtreamplayer.xtream_player

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "dk_video_player",
            DkPlayerViewFactory(flutterEngine.dartExecutor.binaryMessenger),
        )

        // Reproductor ijkplayer NATIVO (con lista real de pistas de audio/subtitulo).
        IjkPlayerHost(
            applicationContext,
            flutterEngine.dartExecutor.binaryMessenger,
            flutterEngine.renderer,
        )

        // Reproductor Media3 con textura de Flutter (sin SurfaceView): vídeo
        // estable en Fire TV. Canal `media3_player`.
        Media3PlayerHost(
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
