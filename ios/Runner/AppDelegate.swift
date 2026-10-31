import Flutter
import UIKit
import UserNotifications
import BackgroundTasks

// Multiple Flutter plugins can respond to the same system notification.
final class NotificationCompletionGate {
    private let lock = NSLock()
    private var completion: (() -> Void)?

    init(_ completion: @escaping () -> Void) {
        self.completion = completion
    }

    func finish() {
        lock.lock()
        let callback = completion
        completion = nil
        lock.unlock()
        callback?()
    }

    func finishIfPluginsDoNotRespond() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { self.finish() }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
    private static let backgroundSyncChannelName = "com.zbooma.elabqrihr/background_sync"
    private static let backgroundTaskIdentifier = "com.zbooma.elabqrihr.background-sync"

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        // Register Attendance Trust Native Plugin
        if let trustRegistrar = self.registrar(forPlugin: "AttendanceTrustPlugin") {
            AttendanceTrustPlugin.register(with: trustRegistrar)
        }

        // Configure User Notifications Delegate
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }

        // Register Background Tasks (BGTaskScheduler)
        if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(
                forTaskWithIdentifier: AppDelegate.backgroundTaskIdentifier,
                using: nil
            ) { task in
                self.handleBackgroundSync(task: task as! BGAppRefreshTask)
            }
        }

        // Wire Background Sync Method Channel
        setupBackgroundSyncChannel()

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func setupBackgroundSyncChannel() {
        guard let controller = window?.rootViewController as? FlutterViewController else { return }
        let channel = FlutterMethodChannel(
            name: AppDelegate.backgroundSyncChannelName,
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "scheduleBackgroundSync":
                if #available(iOS 13.0, *) {
                    self?.scheduleAppRefresh()
                    result(true)
                } else {
                    result(false)
                }
            case "cancelBackgroundSync":
                if #available(iOS 13.0, *) {
                    BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: AppDelegate.backgroundTaskIdentifier)
                    result(true)
                } else {
                    result(false)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    @available(iOS 13.0, *)
    private func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: AppDelegate.backgroundTaskIdentifier)
        // Earliest begin date in 15 minutes
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background task scheduling can fail in development/simulator; non-fatal
        }
    }

    @available(iOS 13.0, *)
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        // Schedule next sync iteration
        scheduleAppRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        // Completed
        task.setTaskCompleted(success: true)
    }

    // MARK: - UNUserNotificationCenterDelegate

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let gate = NotificationCompletionGate {
            if #available(iOS 14.0, *) {
                completionHandler([.banner, .badge, .sound])
            } else {
                completionHandler([.alert, .badge, .sound])
            }
        }
        gate.finishIfPluginsDoNotRespond()
        super.userNotificationCenter(center, willPresent: notification) { _ in gate.finish() }
    }

    override func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let gate = NotificationCompletionGate(completionHandler)
        gate.finishIfPluginsDoNotRespond()
        super.userNotificationCenter(center, didReceive: response) { gate.finish() }
    }

    override func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    override func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
}
