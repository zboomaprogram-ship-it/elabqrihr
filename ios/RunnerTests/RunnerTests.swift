import Flutter
import UIKit
import XCTest
import CryptoKit
import Security
import UserNotifications
@testable import Runner

class RunnerTests: XCTestCase {

  func testNotificationResponseReachesFlutterLifecycleDelegateOnce() {
    let app = AppDelegate()
    let delegate = NotificationResponseProbe()
    app.add(delegate)
    // The probe does not inspect the response; this exercises delegate routing
    // without constructing an OS-owned notification response in a unit test.
    let placeholder = NSObject()
    let response = unsafeBitCast(placeholder, to: UNNotificationResponse.self)
    var completions = 0
    app.userNotificationCenter(UNUserNotificationCenter.current(), didReceive: response) {
      completions += 1
    }
    XCTAssertEqual(delegate.calls, 1)
    XCTAssertEqual(completions, 1)
  }

  func testNotificationCompletionGateIgnoresDuplicatePluginCallbacks() {
    var completions = 0
    let gate = NotificationCompletionGate { completions += 1 }
    DispatchQueue.concurrentPerform(iterations: 32) { _ in gate.finish() }
    XCTAssertEqual(completions, 1)
  }

  func testForegroundNotificationReachesFlutterAndKeepsPresentation() {
    let app = AppDelegate()
    let delegate = NotificationResponseProbe()
    app.add(delegate)
    let placeholder = NSObject()
    let notification = unsafeBitCast(placeholder, to: UNNotification.self)
    var completions = 0
    app.userNotificationCenter(UNUserNotificationCenter.current(), willPresent: notification) { options in
      completions += 1
      XCTAssertTrue(options.contains(.sound))
      XCTAssertTrue(options.contains(.badge))
    }
    XCTAssertEqual(delegate.foregroundCalls, 1)
    XCTAssertEqual(completions, 1)
  }

  func testPersistentKeyLookupFailureDoesNotCreateAnotherKey() {
    var createCalled = false
    XCTAssertThrowsError(try AttendanceTrustPlugin.resolvePersistentKey(
      lookup: { (errSecInteractionNotAllowed, nil) },
      create: { createCalled = true; throw NSError(domain: "test", code: 1) }
    ))
    XCTAssertFalse(createCalled)
  }

  func testPersistentKeyCreationFailureIsReported() {
    var createCalls = 0
    XCTAssertThrowsError(try AttendanceTrustPlugin.resolvePersistentKey(
      lookup: { (errSecItemNotFound, nil) },
      create: { createCalls += 1; throw NSError(domain: "test", code: 1) }
    ))
    XCTAssertEqual(createCalls, 1)
  }

  func testSuccessfulLookupWithoutAKeyFailsClosed() {
    var createCalled = false
    XCTAssertThrowsError(try AttendanceTrustPlugin.resolvePersistentKey(
      lookup: { (errSecSuccess, nil) },
      create: { createCalled = true; throw NSError(domain: "test", code: 1) }
    ))
    XCTAssertFalse(createCalled)
  }

  func testPersistentKeyLookupReusesExistingKey() throws {
    let attributes: [String: Any] = [
      kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
      kSecAttrKeySizeInBits as String: 256
    ]
    let existing = try XCTUnwrap(SecKeyCreateRandomKey(attributes as CFDictionary, nil))
    var createCalled = false
    let resolved = try AttendanceTrustPlugin.resolvePersistentKey(
      lookup: { (errSecSuccess, existing) },
      create: { createCalled = true; throw NSError(domain: "test", code: 1) }
    )
    XCTAssertTrue(CFEqual(resolved, existing))
    XCTAssertFalse(createCalled)
  }

  func testAttendanceBridgeExportsSpkiAndSignsServerDigestBytes() throws {
    let plugin = AttendanceTrustPlugin()
    var identityResult: Any?
    plugin.handle(FlutterMethodCall(methodName: "installationIdentity", arguments: nil)) {
      identityResult = $0
    }
    let identity = try XCTUnwrap(identityResult as? [String: Any])
    let encodedKey = try XCTUnwrap(identity["publicKeySpki"] as? String)
    let spki = try XCTUnwrap(Data(base64Encoded: encodedKey))
    let publicKey = try P256.Signing.PublicKey(derRepresentation: spki)
    let expectedThumbprint = SHA256.hash(data: spki).map { String(format: "%02x", $0) }.joined()
    XCTAssertEqual(identity["publicKeyThumbprint"] as? String, expectedThumbprint)

    let digestHex = String(repeating: "ab", count: 32)
    let digestBytes = Data(repeating: 0xab, count: 32)
    var signatureResult: Any?
    plugin.handle(FlutterMethodCall(methodName: "signAttendanceDigest", arguments: ["contentDigest": digestHex])) {
      signatureResult = $0
    }
    let encodedSignature = try XCTUnwrap(signatureResult as? String)
    let signatureBytes = try XCTUnwrap(Data(base64Encoded: encodedSignature))
    let signature = try P256.Signing.ECDSASignature(derRepresentation: signatureBytes)
    // CryptoKit hashes these bytes once, matching Node verify("sha256", digestBytes, ...).
    XCTAssertTrue(publicKey.isValidSignature(signature, for: digestBytes))
  }

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

}

private final class NotificationResponseProbe: NSObject, FlutterApplicationLifeCycleDelegate {
  var calls = 0
  var foregroundCalls = 0

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    foregroundCalls += 1
    completionHandler([])
    completionHandler([])
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    calls += 1
    completionHandler()
    completionHandler()
  }
}
