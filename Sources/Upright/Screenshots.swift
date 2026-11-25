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
            ("settings", {
                $0.applyDemo(slouching: false, deviation: 4, screenTime: 3 * 60 + 10, today: day)
                $0.showSettings = true
            }),
        ]

        for (suffix, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            for state in states {
                let model = AppModel()
                state.configure(model)
                write(panel(MenuView(model: model)), appearance: appearance,
                      to: dir.appendingPathComponent("\(state.name)-\(suffix).png"))
            }
            write(panel(IconLegend()), appearance: appearance,
                  to: dir.appendingPathComponent("icons-\(suffix).png"))
        }
        print("Wrote screenshots to \(dir.path)")
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
