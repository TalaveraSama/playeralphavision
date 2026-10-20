package com.alphavision.core

import java.io.Reader

/**
 * Parser JSON mínimo, sin dependencias externas (ni Gson, ni kotlinx.serialization).
 *
 * Se usa para hablar con el API de XUI.one / Xtream Codes, que devuelve JSON con
 * tipos inconsistentes (p. ej. `stream_id` a veces número y a veces string),
 * por eso los modelos se construyen con conversiones tolerantes.
 */
sealed interface JsonValue {
    data class Obj(val fields: Map<String, JsonValue>) : JsonValue
    data class Arr(val items: List<JsonValue>) : JsonValue
    data class Str(val value: String) : JsonValue
    data class Num(val value: Double) : JsonValue
    data class Bool(val value: Boolean) : JsonValue

    data object Null : JsonValue
}

object Json {

    fun parse(text: String): JsonValue {
        val p = Parser(text)
        p.skipWhitespace()
        val v = p.readValue()
        p.skipWhitespace()
        return v
    }

    fun objOrNull(text: String): JsonValue.Obj? = runCatching { parse(text) as? JsonValue.Obj }.getOrNull()

    fun arrOrNull(text: String): List<JsonValue>? = runCatching {
        when (val v = parse(text)) {
            is JsonValue.Arr -> v.items
            else -> null
        }
    }.getOrNull()

    private class Parser(private val src: String) {
        private var i = 0

        fun skipWhitespace() {
            while (i < src.length && src[i].isWhitespace()) i++
        }

        fun readValue(): JsonValue {
            skipWhitespace()
            if (i >= src.length) throw JsonException("fin inesperado del JSON")
            return when (val c = src[i]) {
                '{' -> readObject()
                '[' -> readArray()
                '"' -> JsonValue.Str(readString())
                't' -> readLiteral("true", JsonValue.Bool(true))
                'f' -> readLiteral("false", JsonValue.Bool(false))
                'n' -> readLiteral("null", JsonValue.Null)
                else -> if (c == '-' || c.isDigit()) readNumber() else throw JsonException("carácter inesperado '$c' en posición $i")
            }
        }

        private fun readObject(): JsonValue.Obj {
            expect('{')
            val map = LinkedHashMap<String, JsonValue>()
            skipWhitespace()
            if (peek() == '}') { i++; return JsonValue.Obj(map) }
            while (true) {
                skipWhitespace()
                val key = readString()
                skipWhitespace()
                expect(':')
                map[key] = readValue()
                skipWhitespace()
                when (peek()) {
                    ',' -> i++
                    '}' -> { i++; return JsonValue.Obj(map) }
                    else -> throw JsonException("se esperaba ',' o '}' en posición $i")
                }
            }
        }

        private fun readArray(): JsonValue.Arr {
            expect('[')
            val items = ArrayList<JsonValue>()
            skipWhitespace()
            if (peek() == ']') { i++; return JsonValue.Arr(items) }
            while (true) {
                items.add(readValue())
                skipWhitespace()
                when (peek()) {
                    ',' -> i++
                    ']' -> { i++; return JsonValue.Arr(items) }
                    else -> throw JsonException("se esperaba ',' o ']' en posición $i")
                }
            }
        }

        private fun readString(): String {
            expect('"')
            val sb = StringBuilder()
            while (i < src.length) {
                when (val c = src[i++]) {
                    '"' -> return sb.toString()
                    '\\' -> {
                        if (i >= src.length) break
                        when (val e = src[i++]) {
                            '"' -> sb.append('"')
                            '\\' -> sb.append('\\')
                            '/' -> sb.append('/')
                            'b' -> sb.append('\b')
                            'f' -> sb.append('\u000C')
                            'n' -> sb.append('\n')
                            'r' -> sb.append('\r')
                            't' -> sb.append('\t')
                            'u' -> {
                                if (i + 4 > src.length) throw JsonException("\\u incompleto")
                                sb.append(src.substring(i, i + 4).toInt(16).toChar())
                                i += 4
                            }
                            else -> throw JsonException("escape desconocido '\\$e'")
                        }
                    }
                    else -> sb.append(c)
                }
            }
            throw JsonException("string sin cerrar")
        }

        private fun readNumber(): JsonValue.Num {
            val start = i
            if (peek() == '-') i++
            while (i < src.length && (src[i].isDigit() || src[i] == '.' || src[i] == 'e' || src[i] == 'E' || src[i] == '+' || src[i] == '-')) i++
            val raw = src.substring(start, i)
            return JsonValue.Num(raw.toDoubleOrNull() ?: throw JsonException("número inválido '$raw'"))
        }

        private fun readLiteral(word: String, value: JsonValue): JsonValue {
            if (!src.startsWith(word, i)) throw JsonException("literal inválido en posición $i")
            i += word.length
            return value
        }

        private fun peek(): Char = if (i < src.length) src[i] else throw JsonException("fin inesperado")

        private fun expect(c: Char) {
            if (i >= src.length || src[i] != c) throw JsonException("se esperaba '$c' en posición $i")
            i++
        }
    }
}

class JsonException(message: String) : Exception(message)

// --------------------------------------------------------------------------- //
// Accesores tolerantes
// --------------------------------------------------------------------------- //

fun JsonValue.obj(key: String): JsonValue.Obj? = (this as? JsonValue.Obj)?.fields?.get(key) as? JsonValue.Obj

fun JsonValue.arr(key: String): List<JsonValue> = ((this as? JsonValue.Obj)?.fields?.get(key) as? JsonValue.Arr)?.items ?: emptyList()

fun JsonValue.str(key: String): String? = (this as? JsonValue.Obj)?.fields?.get(key)?.asText()

fun JsonValue.int(key: String): Int? = (this as? JsonValue.Obj)?.fields?.get(key)?.asInt()

fun JsonValue.long(key: String): Long? = (this as? JsonValue.Obj)?.fields?.get(key)?.asLong()

fun JsonValue.bool(key: String): Boolean? = (this as? JsonValue.Obj)?.fields?.get(key)?.asBool()

/** Texto de cualquier escalar (número entero sin ".0", bool como "true"/"false"). */
fun JsonValue.asText(): String? = when (this) {
    is JsonValue.Str -> value
    is JsonValue.Num ->
        if (value == value.toLong().toDouble() && kotlin.math.abs(value) < 9.0e15) value.toLong().toString()
        else value.toString()
    is JsonValue.Bool -> value.toString()
    else -> null
}

fun JsonValue.asInt(): Int? = when (this) {
    is JsonValue.Num -> value.toInt()
    is JsonValue.Str -> value.trim().toIntOrNull() ?: value.trim().toDoubleOrNull()?.toInt()
    else -> null
}

fun JsonValue.asLong(): Long? = when (this) {
    is JsonValue.Num -> value.toLong()
    is JsonValue.Str -> value.trim().toLongOrNull() ?: value.trim().toDoubleOrNull()?.toLong()
    else -> null
}

fun JsonValue.asBool(): Boolean? = when (this) {
    is JsonValue.Bool -> value
    is JsonValue.Num -> value != 0.0
    is JsonValue.Str -> value == "1" || value.equals("true", ignoreCase = true)
    else -> null
}

/** `null`, `"null"`, `""` y `"None"` se tratan como ausentes. */
fun JsonValue.asCleanText(): String? = asText()?.trim()?.takeIf {
    it.isNotEmpty() && !it.equals("null", ignoreCase = true) && !it.equals("none", ignoreCase = true)
}

internal fun Reader.readAllText(): String = readText()
