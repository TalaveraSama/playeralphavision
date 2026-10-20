package com.alphavision.player.data

import android.content.Context
import com.alphavision.core.HttpTransport
import com.alphavision.core.XuiApi
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.util.concurrent.TimeUnit

/**
 * Contenedor de dependencias manual (sin Hilt): una instancia por proceso.
 */
class AppContainer(context: Context) {

    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .followRedirects(true)
        .followSslRedirects(true)
        .retryOnConnectionFailure(true)
        .build()

    /** Implementación del transporte que usa el módulo `core`. */
    private val transport = HttpTransport { url ->
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", USER_AGENT)
            .header("Accept", "*/*")
            .get()
            .build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) throw IOException("HTTP ${response.code} al pedir $url")
            val body = response.body?.string()
            if (body.isNullOrBlank()) throw IOException("Respuesta vacía de $url")
            body
        }
    }

    val api: XuiApi = XuiApi(transport)
    val sessionStore: SessionStore = SessionStore(context)
    val repository: Repository = Repository(api, sessionStore)

    companion object {
        const val USER_AGENT = "AlphaVision/1.0 (Android)"
    }
}
