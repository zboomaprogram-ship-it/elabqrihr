import Flutter
import UIKit
import Security
import CryptoKit
import DeviceCheck

public class AttendanceTrustPlugin: NSObject, FlutterPlugin {
    private static let channelName = "com.zbooma.elabqrihr/attendance_trust"
    private static let keyTag = "com.zbooma.elabqrihr.attendance.key.v1"
    private static let installationPrefKey = "attendance_installation_id"

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
        let instance = AttendanceTrustPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "installationIdentity":
            handleInstallationIdentity(result: result)
        case "signAttendanceDigest":
            guard let args = call.arguments as? [String: Any],
                  let digest = args["contentDigest"] as? String,
                  digest.range(of: "^[a-f0-9]{64}$", options: .regularExpression) != nil else {
                result(FlutterError(code: "INVALID_DIGEST", message: "A SHA-256 digest is required", details: nil))
                return
            }
            handleSignDigest(digestHex: digest, result: result)
        case "requestIntegrityToken":
            guard let args = call.arguments as? [String: Any],
                  let nonce = args["nonce"] as? String,
                  nonce.range(of: "^[A-Za-z0-9_-]{16,500}$", options: .regularExpression) != nil else {
                result(FlutterError(code: "INVALID_NONCE", message: "A server-issued nonce is required", details: nil))
                return
            }
            handleRequestIntegrityToken(nonce: nonce, result: result)
        case "revokeLocalInstallation":
            handleRevokeLocalInstallation(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func handleRevokeLocalInstallation(result: @escaping FlutterResult) {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: AttendanceTrustPlugin.installationPrefKey)

        let tagData = AttendanceTrustPlugin.keyTag.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData
        ]
        SecItemDelete(query as CFDictionary)
        result(nil)
    }

    private func handleInstallationIdentity(result: @escaping FlutterResult) {
        do {
            let key = try getOrCreateKeyPair()
            guard let publicKey = SecKeyCopyPublicKey(key) else {
                result(FlutterError(code: "KEYSTORE_UNAVAILABLE", message: "Public key copy failed", details: nil))
                return
            }

            var error: Unmanaged<CFError>?
            guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
                result(FlutterError(code: "KEYSTORE_UNAVAILABLE", message: "Public key export failed", details: nil))
                return
            }

            // Security exports a P-256 point in X9.63 form; the API contract
            // and server fingerprint both require DER SubjectPublicKeyInfo.
            let spki = try P256.Signing.PublicKey(x963Representation: keyData).derRepresentation
            let thumbprint = SHA256.hash(data: spki).map { String(format: "%02x", $0) }.joined()
            let spkiBase64 = spki.base64EncodedString()
            let installId = getOrCreateInstallationId()

            result([
                "installationId": installId,
                "publicKeySpki": spkiBase64,
                "publicKeyThumbprint": thumbprint,
                "keyAlgorithm": "ES256"
            ])
        } catch {
            result(FlutterError(code: "KEYSTORE_UNAVAILABLE", message: "Protected device key unavailable", details: nil))
        }
    }

    private func handleSignDigest(digestHex: String, result: @escaping FlutterResult) {
        do {
            let key = try getOrCreateKeyPair()
            guard let digestData = hexToData(hex: digestHex) else {
                result(FlutterError(code: "INVALID_DIGEST", message: "Failed to decode digest hex", details: nil))
                return
            }

            var error: Unmanaged<CFError>?
            guard let signature = SecKeyCreateSignature(
                key,
                // The backend verifies SHA256 over the 32 digest bytes.
                .ecdsaSignatureMessageX962SHA256,
                digestData as CFData,
                &error
            ) as Data? else {
                result(FlutterError(code: "KEYSTORE_UNAVAILABLE", message: "Signing failed", details: nil))
                return
            }

            result(signature.base64EncodedString())
        } catch {
            result(FlutterError(code: "KEYSTORE_UNAVAILABLE", message: "Protected device key unavailable", details: nil))
        }
    }

    private func handleRequestIntegrityToken(nonce: String, result: @escaping FlutterResult) {
        if #available(iOS 14.0, *), DCAppAttestService.shared.isSupported {
            guard let clientData = nonce.data(using: .utf8) else {
                result(FlutterError(code: "INVALID_NONCE", message: "Nonce encoding error", details: nil))
                return
            }
            let clientHash = Data(SHA256.hash(data: clientData))

            // Use App Attest service to generate key and assertion for the challenge
            let attestService = DCAppAttestService.shared
            attestService.generateKey { keyId, keyError in
                if let keyId = keyId {
                    attestService.generateAssertion(keyId, clientDataHash: clientHash) { assertion, assertError in
                        if let assertion = assertion {
                            result(assertion.base64EncodedString())
                        } else {
                            // Redact internal error detail
                            result(FlutterError(code: "INTEGRITY_UNAVAILABLE", message: "App Attest assertion unavailable", details: nil))
                        }
                    }
                } else {
                    result(FlutterError(code: "INTEGRITY_UNAVAILABLE", message: "App Attest key unavailable", details: nil))
                }
            }
        } else {
            // Emulate clean failure or fallback on unsupported targets
            result(FlutterError(code: "INTEGRITY_UNAVAILABLE", message: "App Attest not supported on this platform", details: nil))
        }
    }

    private func getOrCreateInstallationId() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: AttendanceTrustPlugin.installationPrefKey) {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: AttendanceTrustPlugin.installationPrefKey)
        return newId
    }

    private func getOrCreateKeyPair() throws -> SecKey {
        let tagData = AttendanceTrustPlugin.keyTag.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        // Generate P-256 key pair in Keychain
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tagData
            ]
        ]

        return try Self.resolvePersistentKey(
            lookup: {
                var item: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &item)
                guard status == errSecSuccess else { return (status, nil) }
                guard let item = item, CFGetTypeID(item) == SecKeyGetTypeID() else {
                    return (errSecInternalComponent, nil)
                }
                return (status, (item as! SecKey))
            },
            create: {
                var error: Unmanaged<CFError>?
                guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
                    throw error?.takeRetainedValue() ?? NSError(domain: "AttendanceTrust", code: -1)
                }
                return key
            }
        )
    }

    // Isolated so denied lookup and failed persistent creation can be tested
    // without touching a real user's Keychain.
    static func resolvePersistentKey(
        lookup: () -> (OSStatus, SecKey?),
        create: () throws -> SecKey
    ) throws -> SecKey {
        let (status, key) = lookup()
        if status == errSecSuccess, let key = key { return key }
        guard status == errSecItemNotFound else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
        return try create()
    }

    private func hexToData(hex: String) -> Data? {
        var data = Data()
        var hexStr = hex
        while !hexStr.isEmpty {
            let subIndex = hexStr.index(hexStr.startIndex, offsetBy: 2)
            let byteStr = String(hexStr[..<subIndex])
            hexStr = String(hexStr[subIndex...])
            if let num = UInt8(byteStr, radix: 16) {
                data.append(num)
            } else {
                return nil
            }
        }
        return data
    }
}
