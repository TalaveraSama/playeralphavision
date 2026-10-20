package com.alphavision.player.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.alphavision.core.Credentials
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

private val Context.sessionDataStore: DataStore<Preferences> by preferencesDataStore(name = "session")

/**
 * Persistencia de la sesión (panel + usuario).
 *
 * Nota de seguridad: DataStore guarda en el almacenamiento privado de la app,
 * pero no cifrado. Para producción conviene envolver la contraseña con
 * `EncryptedSharedPreferences`/Keystore. Aquí se guarda para no pedir login
 * en cada arranque, igual que hacen los players comerciales.
 */
class SessionStore(private val context: Context) {

    private object Keys {
        val BASE = stringPreferencesKey("base_url")
        val USER = stringPreferencesKey("username")
        val PASS = stringPreferencesKey("password")
    }

    val credentials: Flow<Credentials?> = context.sessionDataStore.data.map { prefs ->
        val base = prefs[Keys.BASE]
        val user = prefs[Keys.USER]
        val pass = prefs[Keys.PASS]
        if (!base.isNullOrBlank() && !user.isNullOrBlank() && pass != null) {
            Credentials(base, user, pass)
        } else {
            null
        }
    }

    suspend fun save(credentials: Credentials) {
        context.sessionDataStore.edit { prefs ->
            prefs[Keys.BASE] = credentials.baseUrl
            prefs[Keys.USER] = credentials.username
            prefs[Keys.PASS] = credentials.password
        }
    }

    suspend fun clear() {
        context.sessionDataStore.edit { it.clear() }
    }
}
