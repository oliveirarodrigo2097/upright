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
