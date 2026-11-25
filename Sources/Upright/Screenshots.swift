import AppKit
import SwiftUI
import UprightCore

/// Renders the real menu panel with demo data to PNGs for the README.
/// Run: `build/Upright.app/Contents/MacOS/Upright --screenshots docs/screenshots`
@MainActor
enum Screenshots {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var day = DayStats()
        day.uprightSeconds = 3 * 3600 + 18 * 60
        day.slouchSeconds = 42 * 60
        day.postureAlerts = 3
        day.breaksTaken = 5

        let states: [(name: String, configure: (AppModel) -> Void)] = [
            ("upright", { $0.applyDemo(slouching: false, deviation: 6, screenTime: 12 * 60 + 34, today: day) }),
            ("slouching", { $0.applyDemo(slouching: true, deviation: 23, screenTime: 18 * 60 + 5, today: day) }),
        ]

        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            for state in states {
                let model = AppModel()
                state.configure(model)
                write(panel(MenuView(model: model)), appearance: appearance,
                      to: dir.appendingPathComponent("\(state.name)-\(suffix).png"))
            }
            let settingsModel = AppModel()
            settingsModel.applyDemo(slouching: false, deviation: 4, screenTime: 0, today: day)
            write(panel(SettingsView(model: settingsModel)), appearance: appearance,
                  to: dir.appendingPathComponent("settings-\(suffix).png"))
            write(panel(IconLegend()), appearance: appearance,
                  to: dir.appendingPathComponent("icons-\(suffix).png"))
            let heroModel = AppModel()
            heroModel.applyDemo(slouching: false, deviation: 6, screenTime: 12 * 60 + 34, today: day)
            write(MenuBarScene(model: heroModel), appearance: appearance,
                  to: dir.appendingPathComponent("menubar-\(suffix).png"))
        }
        reportPanelHeights(day: day)
        print("Wrote screenshots to \(dir.path)")
    }

    /// Prints each panel state's natural height against MenuView.panelHeight.
    private static func reportPanelHeights(day: DayStats) {
        let cases: [(String, (AppModel) -> Void)] = [
            ("live", { $0.applyDemo(slouching: false, deviation: 6, screenTime: 60, today: day) }),
            ("live, paused", { $0.applyDemo(slouching: false, deviation: 6, screenTime: 60, today: day); $0.pause(for: 60) }),
            ("not connected", { _ in }),
            ("needs calibration", { $0.applyDemo(slouching: false, deviation: 0, screenTime: 0, today: day); $0.forgetCalibrationForDemo() }),
        ]
        for (name, configure) in cases {
            let m = AppModel()
            configure(m)
            let h = NSHostingView(rootView: MenuView(model: m).content).fittingSize.height
            print(String(format: "panel %-18@ %4.0f pt (limit %.0f)%@", name as NSString, h, MenuView.panelHeight,
                         h > MenuView.panelHeight ? " TOO TALL" : ""))
        }
    }

    private static func panel(_ content: some View) -> some View {
        content
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.15)))
            .padding(2)
    }

    private static func write(_ view: some View, appearance: NSAppearance.Name, to url: URL) {
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: appearance)
        let size = host.fittingSize
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.appearance = NSAppearance(named: appearance)
        window.contentView = host
        host.frame = NSRect(origin: .zero, size: size)
        host.layoutSubtreeIfNeeded()
        host.display()

        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        do {
            try rep.representation(using: .png, properties: [:])?.write(to: url)
        } catch {
            print("Failed to write \(url.path): \(error)")
        }
    }
}

/// The menu-bar icon states as one compact row, for the README.
private struct IconLegend: View {
    private let items: [(String, String)] = [
        ("figure.stand", "Good posture"),
        ("exclamationmark.triangle.fill", "Slouching"),
        ("scope", "Needs calibration"),
        ("airpods", "AirPods not connected"),
        ("pause.circle", "Paused"),
    ]

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(items, id: \.0) { symbol, label in
                VStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.system(size: 18))
                        .frame(height: 22)
                    Text(label)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 116)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
    }
}

/// Illustration of Upright in the menu bar with its panel open, built from the real MenuView.
private struct MenuBarScene: View {
    let model: AppModel
    private let width: CGFloat = 640

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            menuBar
            MenuView(model: model)
                .background(.regularMaterial)
                .background(Color(nsColor: .windowBackgroundColor).opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.15)))
                .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
                .padding(.trailing, 150)   // drop down under the Upright icon
                .padding(.bottom, 36)
        }
        .frame(width: width)
        .background(desktop)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(2)
    }

    private var menuBar: some View {
        HStack(spacing: 18) {
            Spacer()
            Image(systemName: "figure.stand")
                .frame(width: 30, height: 22)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.18)))
            Image(systemName: "battery.75percent")
            Image(systemName: "wifi")
            Image(systemName: "magnifyingglass")
            Image(systemName: "switch.2")
            Text("Tue 24 Nov  9:41")
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(.bar)
    }

    private var desktop: some View {
        LinearGradient(
            colors: [Color(red: 0.36, green: 0.52, blue: 0.86), Color(red: 0.62, green: 0.45, blue: 0.80)],
            startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
