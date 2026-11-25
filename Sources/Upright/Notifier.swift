import Foundation
import UserNotifications

/// Local notifications. Needs a real app bundle: UNUserNotificationCenter crashes without one.
@MainActor
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private(set) var authorized = false
    private var center: UNUserNotificationCenter? {
        Bundle.main.bundleIdentifier == nil ? nil : UNUserNotificationCenter.current()
    }

    func setUp() async {
        guard let center else {
            NSLog("Upright: not running from an app bundle; notifications disabled. Use scripts/bundle.sh.")
            return
        }
        center.delegate = self
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            NSLog("Upright: notification authorization failed: \(error.localizedDescription)")
        }
    }

    func post(id: String, title: String, body: String) {
        guard let center else {
            NSLog("Upright [\(id)]: \(title) — \(body)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.threadIdentifier = id
        // Same identifier replaces the previous alert of that kind instead of stacking.
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        center.add(request) { error in
            if let error { NSLog("Upright: failed to post notification: \(error.localizedDescription)") }
        }
    }

    enum TestResult: Equatable {
        case sent           // macOS accepted it; banners are allowed
        case sentQuietly    // accepted, but alert style is None (Notification Center only)
        case notAllowed     // user turned notifications off for Upright
        case failed(String)
        case noBundle
    }

    /// Posts the sample alert and reports what macOS will do with it.
    func sendTest() async -> TestResult {
        guard let center else { return .noBundle }
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .denied: return .notAllowed
        case .notDetermined:
            authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
            if !authorized { return .notAllowed }
        default: break
        }
        let content = UNMutableNotificationContent()
        content.title = "Upright is working"
        content.body = "This is how posture and break alerts will look."
        content.sound = .default
        do {
            try await center.add(UNNotificationRequest(identifier: "test", content: content, trigger: nil))
        } catch {
            return .failed(error.localizedDescription)
        }
        return settings.alertStyle == .none ? .sentQuietly : .sent
    }

    func clear(id: String) {
        center?.removeDeliveredNotifications(withIdentifiers: [id])
    }

    // Show banners even while the menu is open (app is active).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
