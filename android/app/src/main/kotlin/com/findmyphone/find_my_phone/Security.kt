package com.findmyphone.find_my_phone

import android.util.Base64
import java.security.MessageDigest
import java.security.SecureRandom

object Security {
    private val allowed = Regex("^[A-Za-z0-9]{6,12}$")

    fun isValidFormat(code: String): Boolean = allowed.matches(code)

    fun verify(code: String, salt: String, expectedHash: String): Boolean {
        if (!allowed.matches(code)) return false
        return hash(code, salt) == expectedHash
    }

    /** Generates a fresh random salt for a new emergency code (used by the RESET command). */
    fun generateSalt(): String {
        val bytes = ByteArray(16)
        SecureRandom().nextBytes(bytes)
        return Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP)
    }

    fun hash(code: String, salt: String): String {
        var digest = sha256("$salt:$code".toByteArray(Charsets.UTF_8))
        val saltBytes = salt.toByteArray(Charsets.UTF_8)
        repeat(120000) {
            digest = sha256(digest + saltBytes)
        }
        return Base64.encodeToString(digest, Base64.URL_SAFE or Base64.NO_WRAP)
    }

    private fun sha256(bytes: ByteArray): ByteArray = MessageDigest.getInstance("SHA-256").digest(bytes)
}
