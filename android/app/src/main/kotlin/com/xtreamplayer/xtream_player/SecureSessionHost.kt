package com.xtreamplayer.xtream_player

import android.content.Context
import android.os.Build
import android.provider.Settings
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.MessageDigest
import java.util.UUID
import android.os.Handler
import android.os.Looper
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import java.util.concurrent.Executors

/** Never exports keys or uses plaintext as a credential fallback. */
class SecureSessionHost(private val context: Context, messenger: BinaryMessenger) {
    private val executor = Executors.newFixedThreadPool(3)
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "alphavision/security")
    private val prefs by lazy {
        EncryptedSharedPreferences.create(context, "session_secure",
            MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM)
    }
    private val allowed = setOf("xtream.server", "xtream.username", "xtream.password",
        "xtream.remote_config", "xtream.favorites", "xtream.recent", "xtream.resume", "xtream.last_error", "device.session")
    init {
        channel.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "request" -> {
                        val uri = URL(call.argument<String>("url") ?: "")
                        require(uri.protocol == "https")
                        val headers = call.argument<Map<String, String>>("headers") ?: emptyMap()
                        executor.execute {
                            var connection: HttpsURLConnection? = null
                            try {
                                val conn = uri.openConnection() as HttpsURLConnection
                                connection = conn
                                conn.connectTimeout = 8000
                                conn.readTimeout = 12000
                                conn.instanceFollowRedirects = false
                                conn.useCaches = false
                                headers.forEach { (k, v) -> conn.setRequestProperty(k, v) }
                                val status = conn.responseCode
                                val body = (if (status < 400) conn.inputStream else conn.errorStream)
                                    ?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: ""
                                val responseHeaders = conn.headerFields.filterKeys { it != null }
                                    .mapKeys { it.key.lowercase(java.util.Locale.ROOT) }.mapValues { it.value.joinToString(",") }
                                main.post { result.success(mapOf("status" to status, "body" to body, "headers" to responseHeaders)) }
                            } catch (error: Exception) {
                                val code = when (error) {
                                    is javax.net.ssl.SSLException -> "TLS_CERTIFICATE"
                                    is java.net.UnknownHostException -> "DNS"
                                    is java.net.SocketTimeoutException -> "TIMEOUT"
                                    is java.net.ConnectException -> "CONNECTION"
                                    else -> "NETWORK"
                                }
                                main.post { result.error(code, "No se pudo conectar con el panel", null) }
                            } finally { connection?.disconnect() }
                        }
                    }
                    "readAll" -> result.success(prefs.all.filterKeys { it in allowed })
                    "write" -> {
                        val key = call.argument<String>("key")
                        require(key in allowed)
                        val value = call.argument<String>("value")
                        val edit = prefs.edit()
                        if (value == null) edit.remove(key) else edit.putString(key, value)
                        check(edit.commit())
                        result.success(null)
                    }
                    "identity" -> result.success(mapOf("device_id" to deviceId(),
                        "device_name" to Build.MODEL, "platform" to "Android ${Build.VERSION.RELEASE}"))
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("SECURE_STORAGE", "No se pudo acceder al almacenamiento seguro", null)
            }
        }
    }
    private fun deviceId(): String {
        prefs.getString("device_id", null)?.let { return it }
        val backup = context.getSharedPreferences("device_identity", Context.MODE_PRIVATE)
        val cached = backup.getString("device_id", null)
        val id = cached ?: run {
            val androidId = Settings.Secure.getString(context.contentResolver, Settings.Secure.ANDROID_ID)
                ?.takeIf { it.isNotBlank() } ?: UUID.randomUUID().toString()
            "PA-" + MessageDigest.getInstance("SHA-256").digest("PlayerAlphavision:$androidId".toByteArray())
                .joinToString("") { "%02x".format(it.toInt() and 0xff) }.take(40)
        }
        check(prefs.edit().putString("device_id", id).commit())
        check(backup.edit().putString("device_id", id).commit())
        return id
    }
    fun dispose() { channel.setMethodCallHandler(null); executor.shutdownNow() }
}
