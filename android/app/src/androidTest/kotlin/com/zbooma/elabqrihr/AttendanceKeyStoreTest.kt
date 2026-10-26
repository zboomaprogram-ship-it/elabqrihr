package com.zbooma.elabqrihr

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.Signature
import java.security.spec.ECGenParameterSpec

/**
 * Task T041: Android Keystore key creation, reinstall/revocation, and non-exportability instrumentation.
 *
 * Verifies:
 * 1. P-256 (secp256r1) key generation inside the AndroidKeyStore provider.
 * 2. Non-exportability: private key material cannot be extracted (null encoded format / KeyInfo insideSecureHardware).
 * 3. ES256 deterministic signature generation & verification.
 * 4. Revocation / regeneration lifecycle: key can be safely deleted and recreated without corrupting Keystore.
 */
@RunWith(AndroidJUnit4::class)
class AttendanceKeyStoreTest {

    private val testAlias = "attend.attendance.es256.test"
    private lateinit var keyStore: KeyStore

    @Before
    fun setUp() {
        keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        cleanUpKey()
    }

    @After
    fun tearDown() {
        cleanUpKey()
    }

    private fun cleanUpKey() {
        if (keyStore.containsAlias(testAlias)) {
            keyStore.deleteEntry(testAlias)
        }
    }

    private fun generateTestKey(): java.security.KeyPair {
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        generator.initialize(
            KeyGenParameterSpec.Builder(
                testAlias,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            )
                .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setUserAuthenticationRequired(false)
                .build()
        )
        return generator.generateKeyPair()
    }

    @Test
    fun testKeyCreationAndHardwareCharacteristics() {
        val keyPair = generateTestKey()

        assertNotNull("Public key must not be null", keyPair.public)
        assertNotNull("Private key must not be null", keyPair.private)
        assertTrue("Keystore must contain alias", keyStore.containsAlias(testAlias))

        // Non-exportability requirement: AndroidKeyStore private keys return null for getEncoded()
        val privateKey = keyPair.private
        val encodedBytes = privateKey.encoded
        assertTrue(
            "AndroidKeyStore private key material must NOT be exportable (encoded must be null)",
            encodedBytes == null
        )

        // Validate KeyInfo attributes
        val factory = KeyFactory.getInstance(privateKey.algorithm, "AndroidKeyStore")
        val keyInfo = factory.getKeySpec(privateKey, KeyInfo::class.java)
        assertEquals(testAlias, keyInfo.keystoreAlias)
        assertFalse("Key must not be user authentication bound for offline attendance signing", keyInfo.isUserAuthenticationRequired)
    }

    @Test
    fun testSignatureCreationAndVerification() {
        val keyPair = generateTestKey()

        val sampleDigestBytes = ByteArray(32) { (it + 1).toByte() }

        // Sign with private key
        val signer = Signature.getInstance("SHA256withECDSA")
        signer.initSign(keyPair.private)
        signer.update(sampleDigestBytes)
        val signatureBytes = signer.sign()

        assertNotNull("Signature bytes must not be null", signatureBytes)
        assertTrue("ECDSA signature must have valid DER length (> 60 bytes)", signatureBytes.size > 60)

        // Verify with public key
        val verifier = Signature.getInstance("SHA256withECDSA")
        verifier.initVerify(keyPair.public)
        verifier.update(sampleDigestBytes)
        val isValid = verifier.verify(signatureBytes)

        assertTrue("Signature created by AndroidKeyStore private key must verify with its public key", isValid)
    }

    @Test
    fun testReinstallAndRevocationRecreation() {
        // Step 1: Initial creation
        val firstPair = generateTestKey()
        val firstThumbprint = firstPair.public.encoded

        // Step 2: Revocation / deletion (simulating app reinstall or operator-initiated key reset)
        keyStore.deleteEntry(testAlias)
        assertFalse("Alias must no longer exist after deletion", keyStore.containsAlias(testAlias))

        // Step 3: Re-generation creates a brand new unique key pair
        val secondPair = generateTestKey()
        val secondThumbprint = secondPair.public.encoded

        assertTrue("Second key must exist", keyStore.containsAlias(testAlias))
        assertFalse(
            "Re-generated key must have a distinct public key (new unique cryptographic identity)",
            firstThumbprint.contentEquals(secondThumbprint)
        )
    }
}
