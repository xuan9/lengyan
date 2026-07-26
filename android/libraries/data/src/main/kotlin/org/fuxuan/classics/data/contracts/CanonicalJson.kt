package org.fuxuan.classics.data.contracts

import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import java.security.MessageDigest
import java.text.Normalizer

internal object CanonicalJson {
    fun sha256Omitting(
        document: JsonObject,
        topLevelKey: String,
    ): String {
        val canonical = encode(JsonObject(document - topLevelKey))
        return MessageDigest.getInstance("SHA-256")
            .digest(canonical.toByteArray(Charsets.UTF_8))
            .joinToString(separator = "") { byte -> "%02x".format(byte.toInt() and 0xff) }
    }

    private fun encode(value: JsonElement): String = when (value) {
        JsonNull -> "null"
        is JsonArray -> value.joinToString(prefix = "[", postfix = "]", separator = ",", transform = ::encode)
        is JsonObject -> value.entries
            .sortedBy { it.key }
            .joinToString(prefix = "{", postfix = "}", separator = ",") { (key, child) ->
                "${encodeString(key)}:${encode(child)}"
            }
        is JsonPrimitive -> encodePrimitive(value)
    }

    private fun encodePrimitive(value: JsonPrimitive): String {
        if (value.isString) return encodeString(value.content)
        value.booleanOrNull?.let { return it.toString() }

        val number = value.content.toLongOrNull()
            ?: error("canonical JSON numbers must be integers")
        require(number in -MAX_SAFE_INTEGER..MAX_SAFE_INTEGER) {
            "canonical JSON numbers must be safe integers"
        }
        return number.toString()
    }

    private fun encodeString(value: String): String {
        require(Normalizer.isNormalized(value, Normalizer.Form.NFC)) {
            "canonical JSON strings must use NFC"
        }
        val result = StringBuilder(value.length + 2).append('"')
        var index = 0
        while (index < value.length) {
            val character = value[index]
            when (character) {
                '"' -> result.append("\\\"")
                '\\' -> result.append("\\\\")
                '\b' -> result.append("\\b")
                '\t' -> result.append("\\t")
                '\n' -> result.append("\\n")
                '\u000C' -> result.append("\\f")
                '\r' -> result.append("\\r")
                else -> when {
                    character.code <= 0x1f -> result.append("\\u%04x".format(character.code))
                    Character.isHighSurrogate(character) -> {
                        require(index + 1 < value.length && Character.isLowSurrogate(value[index + 1])) {
                            "canonical JSON cannot contain an unpaired surrogate"
                        }
                        result.append(character)
                        result.append(value[++index])
                    }
                    Character.isLowSurrogate(character) -> {
                        error("canonical JSON cannot contain an unpaired surrogate")
                    }
                    else -> result.append(character)
                }
            }
            index += 1
        }
        return result.append('"').toString()
    }

    private const val MAX_SAFE_INTEGER = 9_007_199_254_740_991L
}
