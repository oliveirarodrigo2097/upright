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
        }
        .padding(20)
        .frame(width: 360)
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
