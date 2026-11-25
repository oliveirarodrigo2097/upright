import AppKit
import SwiftUI
import UprightCore

@main
struct UprightApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            Image(systemName: iconName)
        }
        .menuBarExtraStyle(.window)
    }

    private var iconName: String {
        if model.isPaused { return "pause.circle" }
        switch model.connection {
        case .unavailable, .notAuthorized: return "exclamationmark.circle"
        case .waiting: return "airpods"
        case .connected: break
        }
        switch model.postureState {
        case .uncalibrated: return "scope"
        case .upright: return "figure.stand"
        case .slouching: return "exclamationmark.triangle.fill"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--screenshots") {
            let dir = i + 1 < args.count ? args[i + 1] : "docs/screenshots"
            MainActor.assumeIsolated {
                Screenshots.render(to: URL(fileURLWithPath: dir))
                NSApplication.shared.terminate(nil)
            }
            return
        }
        Task { @MainActor in await AppModel.shared.start() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { AppModel.shared.saveNow() }
    }
}
