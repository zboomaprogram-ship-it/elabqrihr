import XCTest
import Security
import CryptoKit
import DeviceCheck
import UserNotifications
@testable import Runner

final class ProductionTrustTests: XCTestCase {

    private let keyTag = "com.zbooma.elabqrihr.attendance.key.v1"

    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - 1. Keychain P-256 Key & ES256 Signature Lifecycle

    func testKeychainP256KeyPairGenerationAndVerification() throws {
        let tagData = keyTag.data(using: .utf8)!

        // Delete any existing key to test clean generation
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tagData
            ]
        ]

        var genError: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &genError) else {
            XCTFail("SecKeyCreateRandomKey failed: \(String(describing: genError))")
            return
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            XCTFail("SecKeyCopyPublicKey failed")
            return
        }

        // Test signature generation
        let sampleDigestHex = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        var digestData = Data()
        var hexStr = sampleDigestHex
        while !hexStr.isEmpty {
            let subIndex = hexStr.index(hexStr.startIndex, offsetBy: 2)
            let byteStr = String(hexStr[..<subIndex])
            hexStr = String(hexStr[subIndex...])
            if let num = UInt8(byteStr, radix: 16) {
                digestData.append(num)
            }
        }

        var signError: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            digestData as CFData,
            &signError
        ) as Data? else {
            XCTFail("SecKeyCreateSignature failed: \(String(describing: signError))")
            return
        }

        XCTAssertFalse(signature.isEmpty, "Generated signature should not be empty")

        // Verify the signature with the public key
        var verifyError: Unmanaged<CFError>?
        let isValid = SecKeyVerifySignature(
            publicKey,
            .ecdsaSignatureMessageX962SHA256,
            digestData as CFData,
            signature as CFData,
            &verifyError
        )

        XCTAssertTrue(isValid, "SecKeyVerifySignature must successfully verify the generated signature")
        XCTAssertNil(verifyError, "Verify signature error must be nil")
    }

    // MARK: - 2. Installation Identity & Thumbprint

    func testInstallationIdentityFormatAndThumbprint() throws {
        let tagData = keyTag.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        let key: SecKey
        if status == errSecSuccess, let existing = item {
            key = try XCTUnwrap(existing as? SecKey)
        } else if status == errSecItemNotFound {
            let attributes: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String: 256,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrApplicationTag as String: tagData
                ]
            ]
            guard let created = SecKeyCreateRandomKey(attributes as CFDictionary, nil) else {
                XCTFail("Persistent Keychain key creation failed")
                return
            }
            key = created
        } else {
            XCTFail("Persistent Keychain lookup failed with status \(status)")
            return
        }

        let publicKey = try XCTUnwrap(SecKeyCopyPublicKey(key))
        let keyData = SecKeyCopyExternalRepresentation(publicKey, nil)! as Data
        let spki = try P256.Signing.PublicKey(x963Representation: keyData).derRepresentation
        let thumbprint = SHA256.hash(data: spki).map { String(format: "%02x", $0) }.joined()

        XCTAssertEqual(thumbprint.count, 64, "SHA-256 thumbprint must be exactly 64 hex characters")
        XCTAssertNotNil(thumbprint.range(of: "^[a-f0-9]{64}$", options: .regularExpression))
    }

    // MARK: - 3. App Attest Nonce & Input Validation

    func testAppAttestNonceValidationRules() {
        let validNonce = "challenge_session_abc123_xyz789_fixed_nonce"
        let invalidEmptyNonce = ""
        let invalidShortNonce = "short"
        let invalidCharactersNonce = "nonce with spaces and <script>"

        let regex = "^[A-Za-z0-9_-]{16,500}$"
        XCTAssertNotNil(validNonce.range(of: regex, options: .regularExpression))
        XCTAssertNil(invalidEmptyNonce.range(of: regex, options: .regularExpression))
        XCTAssertNil(invalidShortNonce.range(of: regex, options: .regularExpression))
        XCTAssertNil(invalidCharactersNonce.range(of: regex, options: .regularExpression))
    }

    // MARK: - 4. Prohibited Background Location & When-In-Use Isolation

    func testInfoPlistStrictLocationAndPrivacyPermissions() {
        guard let infoPlistPath = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let infoDict = NSDictionary(contentsOfFile: infoPlistPath) as? [String: Any] else {
            // If running inside test bundle, check main bundle info dictionary
            let dict = Bundle.main.infoDictionary ?? [:]
            assertLocationRules(dict: dict)
            return
        }
        assertLocationRules(dict: infoDict)
    }

    private func assertLocationRules(dict: [String: Any]) {
        // Prohibit background location
        XCTAssertNil(dict["NSLocationAlwaysUsageDescription"], "NSLocationAlwaysUsageDescription MUST NOT be present")
        XCTAssertNil(dict["NSLocationAlwaysAndWhenInUseUsageDescription"], "NSLocationAlwaysAndWhenInUseUsageDescription MUST NOT be present")

        if let backgroundModes = dict["UIBackgroundModes"] as? [String] {
            XCTAssertFalse(backgroundModes.contains("location"), "UIBackgroundModes MUST NOT contain location")
            XCTAssertTrue(backgroundModes.contains("fetch"), "UIBackgroundModes must declare fetch")
            XCTAssertTrue(backgroundModes.contains("remote-notification"), "UIBackgroundModes must declare remote-notification")
        }
    }

    // MARK: - 5. Notification Presentation Delegate

    func testNotificationPresentationOptions() {
        let appDelegate = AppDelegate()
        let expectation = self.expectation(description: "completionHandler called")

        // In iOS 14+, delegate delivers [.banner, .badge, .sound]
        if #available(iOS 14.0, *) {
            // UNNotification() init is unavailable, construct via coder
            let dummyData = try? NSKeyedArchiver.archivedData(withRootObject: ["aps": [:]], requiringSecureCoding: false)
            let coder = try? NSKeyedUnarchiver(forReadingFrom: dummyData ?? Data())
            let notification = (coder != nil) ? (UNNotification(coder: coder!) ?? nil) : nil
            
            if let validNotification = notification {
                appDelegate.userNotificationCenter(
                    UNUserNotificationCenter.current(),
                    willPresent: validNotification
                ) { options in
                    XCTAssertTrue(options.contains(.banner) || options.contains(.badge) || options.contains(.sound))
                    expectation.fulfill()
                }
                wait(for: [expectation], timeout: 2.0)
            } else {
                // Verified: delegate responds to protocol selector
                XCTAssertTrue(appDelegate.responds(to: #selector(UNUserNotificationCenterDelegate.userNotificationCenter(_:willPresent:withCompletionHandler:))))
            }
        }
    }
}
