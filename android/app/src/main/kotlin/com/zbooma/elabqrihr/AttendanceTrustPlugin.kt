package com.zbooma.elabqrihr

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.os.Handler
import android.os.Looper
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.IntegrityTokenRequest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec
import java.util.UUID
import java.security.MessageDigest
import java.util.concurrent.Executors

/**
 * Minimal bridge to Google Play Integrity.
 *
 * It accepts only a server-issued nonce and returns the opaque token. No
 * attendance data, location, account identifier, or private key is passed to
 * Google Play through this channel.
 */
object AttendanceTrustPlugin : MethodChannel.MethodCallHandler {
    private const val channelName = "com.zbooma.elabqrihr/attendance_trust"
    private const val keyAlias = "attend.attendance.es256.v1"
    private const val installationPreference = "attendance_installation_id"
    // This is the public Google Cloud project number linked to the Play app.
    // Supplying it is required when Play Integrity is verified by that linked
    // server-side project rather than a default Play-managed project.
    private const val cloudProjectNumber = 385268233795L
    private lateinit var context: Context
    // Android calls MethodChannel handlers on the main thread. Keystore access
    // and Play Integrity startup can block on some low-memory devices, so they
    // must never run in that handler. Results are posted back to Flutter's
    // main thread only after native work has completed.
    private val protectedWork = Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "attendance-trust").apply { isDaemon = true }
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    fun attach(messenger: BinaryMessenger, applicationContext: Context) {
        context = applicationContext
        MethodChannel(messenger, channelName).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "installationIdentity") {
            runProtectedWork(result, "KEYSTORE_UNAVAILABLE") {
                val publicKey = keyPair().public.encoded
                mapOf(
                    "installationId" to installationId(),
                    "publicKeySpki" to Base64.encodeToString(publicKey, Base64.NO_WRAP),
                    "publicKeyThumbprint" to sha256(publicKey),
                    "keyAlgorithm" to "ES256"
                )
            }
            return
        }
        if (call.method == "revokeLocalInstallation") {
            runProtectedWork(result, "KEYSTORE_UNAVAILABLE") {
                val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
                if (store.containsAlias(keyAlias)) {
                    store.deleteEntry(keyAlias)
                }
                val preferences = context.getSharedPreferences("attendance_trust", Context.MODE_PRIVATE)
                preferences.edit().remove(installationPreference).commit()
                null
            }
            return
        }
        if (call.method == "signAttendanceDigest") {
            val digest = call.argument<String>("contentDigest")
            if (digest == null || !digest.matches(Regex("^[a-f0-9]{64}$"))) {
                result.error("INVALID_DIGEST", "A SHA-256 digest is required", null)
                return
            }
            runProtectedWork(result, "KEYSTORE_UNAVAILABLE") {
                val signer = Signature.getInstance("SHA256withECDSA")
                signer.initSign(keyPair().private)
                signer.update(hexBytes(digest))
                Base64.encodeToString(signer.sign(), Base64.NO_WRAP)
            }
            return
        }
        if (call.method != "requestIntegrityToken") {
            result.notImplemented()
            return
        }
        val nonce = call.argument<String>("nonce")
        if (nonce == null || !nonce.matches(Regex("^[A-Za-z0-9_-]{16,500}$"))) {
            result.error("INVALID_NONCE", "A server-issued nonce is required", null)
            return
        }

        protectedWork.execute {
            try {
                IntegrityManagerFactory.create(context)
                    .requestIntegrityToken(
                        IntegrityTokenRequest.builder()
                            .setNonce(nonce)
                            .setCloudProjectNumber(cloudProjectNumber)
                            .build(),
                    )
                    .addOnSuccessListener(protectedWork) { response ->
                        respond { result.success(response.token()) }
                    }
                    .addOnFailureListener(protectedWork) {
                        // Do not send Play-service diagnostic detail to Dart/UI.
                        respond {
                            result.error("INTEGRITY_UNAVAILABLE", "Integrity token unavailable", null)
                        }
                    }
            } catch (_: Exception) {
                respond {
                    result.error("INTEGRITY_UNAVAILABLE", "Integrity token unavailable", null)
                }
            }
        }
    }

    private fun runProtectedWork(
        result: MethodChannel.Result,
        errorCode: String,
        work: () -> Any?,
    ) {
        protectedWork.execute {
            try {
                val value = work()
                respond { result.success(value) }
            } catch (_: Exception) {
                respond {
                    result.error(errorCode, "Protected device key unavailable", null)
                }
            }
        }
    }

    private fun respond(action: () -> Unit) {
        mainHandler.post(action)
    }

    private fun installationId(): String {
        val preferences = context.getSharedPreferences("attendance_trust", Context.MODE_PRIVATE)
        return preferences.getString(installationPreference, null) ?: UUID.randomUUID().toString().also {
            preferences.edit().putString(installationPreference, it).apply()
        }
    }

    private fun keyPair(): java.security.KeyPair {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val privateKey = store.getKey(keyAlias, null) as? java.security.PrivateKey
        val certificate = store.getCertificate(keyAlias)
        if (privateKey != null && certificate != null) return java.security.KeyPair(certificate.publicKey, privateKey)
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        generator.initialize(KeyGenParameterSpec.Builder(keyAlias, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(false)
            .build())
        return generator.generateKeyPair()
    }

    private fun sha256(value: ByteArray): String = MessageDigest.getInstance("SHA-256").digest(value)
        .joinToString("") { "%02x".format(it.toInt() and 0xff) }

    private fun hexBytes(value: String): ByteArray = value.chunked(2)
        .map { it.toInt(16).toByte() }.toByteArray()
}
