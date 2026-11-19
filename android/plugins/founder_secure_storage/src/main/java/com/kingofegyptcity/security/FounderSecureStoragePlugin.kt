package com.kingofegyptcity.security

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Godot Android plugin backing FounderAuthClient's optional FounderSecureStorage singleton.
 * Only ciphertext is written to app-private storage. AES keys remain non-exportable in Android Keystore.
 */
class FounderSecureStoragePlugin(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName() = "FounderSecureStorage"

    override fun getPluginMethods() = listOf(
        org.godotengine.godot.plugin.GodotPluginMethod("is_available"),
        org.godotengine.godot.plugin.GodotPluginMethod("save_secret"),
        org.godotengine.godot.plugin.GodotPluginMethod("load_secret"),
        org.godotengine.godot.plugin.GodotPluginMethod("delete_secret")
    )

    @UsedByGodot
    fun is_available(): Boolean = android.os.Build.VERSION.SDK_INT >= 23

    @UsedByGodot
    @Synchronized
    fun save_secret(alias: String, value: String): Boolean {
        if (!is_available() || alias.isBlank() || value.isEmpty()) return false
        return try {
            val key = getOrCreateKey(alias)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, key)
            val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
            val iv = cipher.iv
            val packed = byteArrayOf(VERSION) + byteArrayOf(iv.size.toByte()) + iv + encrypted
            val target = secretFile(alias)
            val temp = File(target.parentFile, target.name + ".tmp")
            temp.writeText(Base64.encodeToString(packed, Base64.NO_WRAP), Charsets.UTF_8)
            if (target.exists() && !target.delete()) {
                temp.delete()
                return false
            }
            if (!temp.renameTo(target)) {
                temp.delete()
                return false
            }
            true
        } catch (_: Exception) {
            false
        }
    }

    @UsedByGodot
    @Synchronized
    fun load_secret(alias: String): String {
        if (!is_available() || alias.isBlank()) return ""
        return try {
            val target = secretFile(alias)
            if (!target.isFile) return ""
            val packed = Base64.decode(target.readText(Charsets.UTF_8), Base64.NO_WRAP)
            if (packed.size < 2 || packed[0] != VERSION) return ""
            val ivLength = packed[1].toInt() and 0xff
            if (ivLength !in 12..16 || packed.size <= 2 + ivLength) return ""
            val iv = packed.copyOfRange(2, 2 + ivLength)
            val ciphertext = packed.copyOfRange(2 + ivLength, packed.size)
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(alias), GCMParameterSpec(128, iv))
            String(cipher.doFinal(ciphertext), Charsets.UTF_8)
        } catch (_: Exception) {
            // Corrupt data, invalidated key, or authentication failure: fail closed.
            ""
        }
    }

    @UsedByGodot
    @Synchronized
    fun delete_secret(alias: String) {
        if (alias.isBlank()) return
        try {
            secretFile(alias).delete()
            val store = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
            val keyAlias = keyAlias(alias)
            if (store.containsAlias(keyAlias)) store.deleteEntry(keyAlias)
        } catch (_: Exception) {
            // Deletion is best-effort; callers never receive secret material here.
        }
    }

    private fun getOrCreateKey(alias: String): SecretKey {
        val store = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val name = keyAlias(alias)
        val existing = store.getKey(name, null) as? SecretKey
        if (existing != null) return existing

        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE)
        generator.init(
            KeyGenParameterSpec.Builder(
                name,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .setKeySize(256)
                .build()
        )
        return generator.generateKey()
    }

    private fun secretFile(alias: String): File {
        val directory = File(godot.getActivity().filesDir, "founder_secure").apply { mkdirs() }
        return File(directory, stableName(alias) + ".bin")
    }

    private fun keyAlias(alias: String) = "king_of_egypt_founder_" + stableName(alias)

    private fun stableName(value: String): String {
        val digest = java.security.MessageDigest.getInstance("SHA-256")
            .digest(value.toByteArray(Charsets.UTF_8))
        return digest.joinToString("") { "%02x".format(it) }
    }

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val VERSION: Byte = 1
    }
}
