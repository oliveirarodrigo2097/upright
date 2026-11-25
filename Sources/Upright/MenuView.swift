import AppKit
import SwiftUI
import UprightCore

struct MenuView: View {
    @Bindable var model: AppModel
    @Environment(\.openSettings) private var openSettings

    /// Fixed panel height. The menu-bar window doesn't resize after it opens,
    /// so a panel that changes height gets clipped. Fits the tallest state.
    static let panelHeight: CGFloat = 310

    var body: some View {
        content
            .frame(width: 300, height: Self.panelHeight, alignment: .top)
    }

    /// The panel at its natural height (used to check it fits `panelHeight`).
    var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            if model.connection == .connected {
                if let progress = model.calibrationProgress {
                    calibrating(progress)
                } else if !model.isCalibrated {
                    calibratePrompt
                } else {
                    liveStatus
                }
            } else {
                connectionHelp
            }
            Divider()
            todaySection
            Spacer(minLength: 0)
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            Text("Upright").font(.headline)
            Spacer()
            Text(statusText)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
    }

    private var calibratePrompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sit up straight, look at your screen, then calibrate.")
                .font(.callout)
            Button("Calibrate") { model.beginCalibration() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func calibrating(_ progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hold still and sit tall…").font(.callout)
            ProgressView(value: progress)
        }
    }

    private var liveStatus: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.postureEnabled {
                let dev = model.deviationDegrees ?? 0
                let limit = model.postureSettings.thresholdDegrees
                HStack {
                    Text("Head tilt")
                    Spacer()
                    Text("\(Int(dev.rounded()))° of \(Int(limit))°")
                        .monospacedDigit()
                        .foregroundStyle(dev > limit ? .orange : .secondary)
                }
                TiltBar(fraction: min(dev, limit * 2) / (limit * 2), over: dev > limit)
            }
            if model.breaksEnabled {
                HStack {
                    Text("Screen time since break")
                    Spacer()
                    Text(clock(model.screenTime)).monospacedDigit().foregroundStyle(.secondary)
                }
                HStack {
                    Button("I took a break") { model.takeBreakNow() }
                    Spacer()
                    Button("Recalibrate") { model.beginCalibration() }
                }
                .controlSize(.small)
            } else {
                Button("Recalibrate") { model.beginCalibration() }.controlSize(.small)
            }
        }
    }

    private var connectionHelp: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch model.connection {
            case .notAuthorized:
                Text("Upright needs Motion & Fitness access to read head motion.")
                Button("Open Privacy Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Motion") {
                        NSWorkspace.shared.open(url)
                    }
                }
            case .unavailable:
                Text("Head motion isn't available. You need AirPods Pro, AirPods (3rd gen or later), or AirPods Max connected to this Mac.")
            default:
                Text("Put in your AirPods and connect them to this Mac.")
            }
        }
        .font(.callout)
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today").font(.subheadline.weight(.semibold))
            HStack {
                Text("Upright")
                Spacer()
                Text(model.today.uprightFraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "—")
                    .monospacedDigit()
            }
            HStack {
                Text("Tracked")
                Spacer()
                Text(AppModel.format(model.today.uprightSeconds + model.today.slouchSeconds)).monospacedDigit()
            }
            HStack {
                Text("Posture alerts · breaks taken")
                Spacer()
                Text("\(model.today.postureAlerts) · \(model.today.breaksTaken)").monospacedDigit()
            }
        }
        .font(.callout)
    }

    private var footer: some View {
        HStack {
            if model.isPaused {
                Button("Resume") { model.resume() }
            } else {
                Menu("Pause") {
                    Button("30 minutes") { model.pause(for: 30 * 60) }
                    Button("1 hour") { model.pause(for: 60 * 60) }
                    Button("2 hours") { model.pause(for: 2 * 60 * 60) }
                }
                .fixedSize()
            }
            Spacer()
            Button("Settings…") {
                openSettings()
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            Button("Quit") {
                model.saveNow()
                NSApplication.shared.terminate(nil)
            }
        }
        .controlSize(.small)
    }

    // MARK: Helpers

    private var statusText: String {
        if model.isPaused { return "Paused" }
        switch model.connection {
        case .unavailable: return "Unavailable"
        case .notAuthorized: return "No access"
        case .waiting: return "AirPods not connected"
        case .connected: break
        }
        switch model.postureState {
        case .uncalibrated: return "Needs calibration"
        case .upright: return "Good posture"
        case .slouching: return "Slouching"
        }
    }

    private var statusColor: Color {
        if case .slouching = model.postureState, model.connection == .connected { return .orange }
        return .secondary
    }

    private func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Tilt meter: fills toward twice the limit, with a tick at the limit.
/// Drawn by hand because the system bar ignores tint colours on macOS.
private struct TiltBar: View {
    let fraction: Double
    let over: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.1))
                Capsule()
                    .fill(over ? Color.orange : Color.green)
                    .frame(width: max(6, geo.size.width * fraction))
                Rectangle()
                    .fill(Color.primary.opacity(0.35))
                    .frame(width: 1.5)
                    .offset(x: geo.size.width / 2)
            }
        }
        .frame(height: 6)
    }
}
