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

/// The menu-bar icon states, for the README.
private struct IconLegend: View {
    private let items: [(String, String)] = [
        ("figure.stand", "Upright"),
        ("exclamationmark.triangle.fill", "Slouching"),
        ("scope", "Needs calibration"),
        ("airpods", "AirPods not connected"),
        ("pause.circle", "Paused"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Menu-bar icon").font(.headline)
            ForEach(items, id: \.0) { symbol, label in
                HStack(spacing: 10) {
                    Image(systemName: symbol).frame(width: 22)
                    Text(label)
                }
                .font(.callout)
            }
        }
        .padding(14)
        .frame(width: 300, alignment: .leading)
    }
}
