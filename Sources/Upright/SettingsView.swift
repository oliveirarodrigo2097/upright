import AppKit
import SwiftUI
import UprightCore

/// The Settings window (Upright ▸ Settings…, or the Settings button in the menu panel).
struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Posture").font(.headline)
            Toggle("Posture alerts", isOn: $model.postureEnabled)
            labeledSlider("Tilt limit", value: $model.postureSettings.thresholdDegrees, in: 8...30, step: 1) {
                "\(Int($0))°"
            }
            .disabled(!model.postureEnabled)
            labeledSlider("Alert after", value: $model.postureSettings.sustainSeconds, in: 30...600, step: 30) {
                AppModel.format($0)
            }
            .disabled(!model.postureEnabled)

            Divider()

            Text("Eye breaks").font(.headline)
            Toggle("Eye-break reminders (20-20-20)", isOn: $model.breaksEnabled)
            labeledSlider("Remind every", value: $model.breakSettings.intervalSeconds, in: 600...3600, step: 300) {
                AppModel.format($0)
            }
            .disabled(!model.breaksEnabled)

            Divider()

            HStack {
                Button("Send test notification") { model.sendTestNotification() }
                Spacer()
                Button("Recalibrate") { model.beginCalibration() }
                    .disabled(model.connection != .connected)
            }
            if let result = model.testNotificationResult {
                testResult(result)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    @ViewBuilder
    private func testResult(_ result: Notifier.TestResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch result {
            case .sent:
                Label("Sent. If no banner appeared, a Focus mode such as Do Not Disturb may be hiding it. Check Control Center, or look in Notification Center (click the clock).",
                      systemImage: "checkmark.circle")
            case .sentQuietly:
                Label("Sent, but Upright's alert style is set to None, so it only goes to Notification Center. Choose Banners or Alerts.",
                      systemImage: "exclamationmark.triangle")
            case .notAllowed:
                Label("Notifications are turned off for Upright, so posture and break alerts can't appear.",
                      systemImage: "xmark.octagon")
            case .failed(let message):
                Label("Couldn't send: \(message)", systemImage: "xmark.octagon")
            case .noBundle:
                Label("Notifications only work when Upright runs as an app (scripts/bundle.sh).", systemImage: "xmark.octagon")
            }
            if result != .sent {
                Button("Open Notification Settings") {
                    let id = Bundle.main.bundleIdentifier ?? ""
                    if let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func labeledSlider(
        _ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double,
        format: @escaping (Double) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value.wrappedValue)).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }
}
