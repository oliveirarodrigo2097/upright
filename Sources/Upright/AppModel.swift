import Foundation
import Observation
import UprightCore

@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    // MARK: Published (refreshed ~4×/s, not per sample)
    private(set) var connection: ConnectionState = .waiting
    private(set) var postureState: PostureState = .uncalibrated
    private(set) var deviationDegrees: Double?
    private(set) var screenTime: TimeInterval = 0
    private(set) var calibrationProgress: Double?   // non-nil while calibrating
    private(set) var today = DayStats()
    private(set) var pausedUntil: Date?

    var postureSettings: PostureSettings { didSet { applySettings() } }
    var breakSettings: BreakSettings { didSet { applySettings() } }
    var postureEnabled: Bool { didSet { applySettings() } }
    var breaksEnabled: Bool { didSet { applySettings() } }

    /// Puts the model in a fixed state for README screenshots (`Upright --screenshots <dir>`).
    /// Never started, so it reads no motion and posts no notifications.
    func applyDemo(slouching: Bool, deviation: Double, screenTime: TimeInterval, today: DayStats) {
        posture.baselinePitch = 0
        connection = .connected
        postureState = slouching ? .slouching(since: 0) : .upright
        deviationDegrees = deviation
        self.screenTime = screenTime
        self.today = today
    }

    func forgetCalibrationForDemo() {
        posture.baselinePitch = nil
    }

    var isCalibrated: Bool { posture.baselinePitch != nil }
    var isPaused: Bool { pausedUntil.map { $0 > Date() } ?? false }

    // MARK: Internals
    @ObservationIgnored private let motion = MotionService()
    @ObservationIgnored private let notifier = Notifier()
    @ObservationIgnored private var posture: PostureDetector
    @ObservationIgnored private var breaks: BreakTracker
    @ObservationIgnored private var calibrator: Calibrator?
    @ObservationIgnored private var stats: DailyStats
    @ObservationIgnored private var lastSampleTime: TimeInterval?
    @ObservationIgnored private var lastPublish: TimeInterval = 0
    @ObservationIgnored private var lastStatsSave: TimeInterval = 0
    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Key {
        static let baseline = "baselinePitch"
        static let posture = "postureSettings"
        static let breaks = "breakSettings"
        static let postureOn = "postureEnabled"
        static let breaksOn = "breaksEnabled"
        static let stats = "dailyStats"
    }

    init() {
        let ps = Self.load(PostureSettings.self, Key.posture) ?? PostureSettings()
        let bs = Self.load(BreakSettings.self, Key.breaks) ?? BreakSettings()
        postureSettings = ps
        breakSettings = bs
        postureEnabled = defaults.object(forKey: Key.postureOn) as? Bool ?? true
        breaksEnabled = defaults.object(forKey: Key.breaksOn) as? Bool ?? true
        let baseline = defaults.object(forKey: Key.baseline) as? Double
        posture = PostureDetector(settings: ps, baselinePitch: baseline)
        breaks = BreakTracker(settings: bs)
        stats = Self.load(DailyStats.self, Key.stats) ?? DailyStats()
        today = stats.day(Date())
        postureState = posture.state

        motion.onSample = { [weak self] s in self?.handle(s) }
        motion.onStateChange = { [weak self] s in self?.connectionChanged(s) }
    }

    @ObservationIgnored private var started = false

    func start() async {
        guard !started else { return }
        started = true
        await notifier.setUp()
        motion.start()
    }

    // MARK: Actions

    func beginCalibration() {
        calibrator = Calibrator(duration: 3)
        calibrationProgress = 0
    }

    func takeBreakNow() {
        breaks.takeBreak()
        notifier.clear(id: "break")
        publish(force: true)
    }

    func pause(for seconds: TimeInterval) {
        pausedUntil = Date().addingTimeInterval(seconds)
        posture.pause()
        breaks.takeBreak()
        publish(force: true)
    }

    func resume() {
        pausedUntil = nil
        publish(force: true)
    }

    func sendTestNotification() {
        notifier.post(id: "test", title: "Upright is working", body: "This is how posture and break alerts will look.")
    }

    func saveNow() {
        save(stats, Key.stats)
    }

    // MARK: Sample pipeline

    private func handle(_ s: MotionSample) {
        defer { lastSampleTime = s.time; publish() }

        if var c = calibrator {
            if let baseline = c.add(s) {
                calibrator = nil
                calibrationProgress = nil
                posture.baselinePitch = baseline
                defaults.set(baseline, forKey: Key.baseline)
            } else {
                calibrator = c
                calibrationProgress = c.progress
            }
            return
        }

        if let until = pausedUntil {
            if until > Date() { return }
            pausedUntil = nil
        }

        let now = Date()
        // Credit time to upright/slouch (cap gaps so a disconnect isn't counted).
        if let last = lastSampleTime, isCalibrated, postureEnabled {
            let dt = min(1, max(0, s.time - last))
            stats.update(now) { day in
                if case .slouching = posture.state { day.slouchSeconds += dt } else { day.uprightSeconds += dt }
            }
        }

        if postureEnabled, let event = posture.add(s) {
            switch event {
            case .slouchAlert(let duration, let dev):
                stats.update(now) { $0.postureAlerts += 1 }
                notifier.post(
                    id: "posture",
                    title: "Sit up straight",
                    body: "Your head has been tilted about \(Int(dev.rounded()))° for \(Self.format(duration)). Roll your shoulders back and lift your chin.")
            case .recovered:
                notifier.clear(id: "posture")
            }
        }

        if breaksEnabled, let event = breaks.add(s) {
            switch event {
            case .breakDue(let t):
                stats.update(now) { $0.breakReminders += 1 }
                notifier.post(
                    id: "break",
                    title: "Time for an eye break",
                    body: "\(Self.format(t)) at the screen. Look at something 20 ft (6 m) away for 20 seconds.")
            case .breakTaken:
                stats.update(now) { $0.breaksTaken += 1 }
                notifier.clear(id: "break")
            }
        }

        if s.time - lastStatsSave > 30 {
            lastStatsSave = s.time
            stats.prune()
            save(stats, Key.stats)
        }
    }

    private func connectionChanged(_ s: ConnectionState) {
        connection = s
        if s != .connected {
            // AirPods out: end any slouch episode. The break tracker sees the gap itself.
            posture.pause()
            calibrator = nil
            calibrationProgress = nil
            save(stats, Key.stats)
        }
        publish(force: true)
    }

    private func publish(force: Bool = false) {
        let t = Date().timeIntervalSinceReferenceDate
        guard force || t - lastPublish >= 0.25 else { return }
        lastPublish = t
        postureState = posture.state
        deviationDegrees = posture.deviationDegrees
        screenTime = breaks.screenTime
        today = stats.day(Date())
    }

    private func applySettings() {
        posture.settings = postureSettings
        breaks.settings = breakSettings
        save(postureSettings, Key.posture)
        save(breakSettings, Key.breaks)
        defaults.set(postureEnabled, forKey: Key.postureOn)
        defaults.set(breaksEnabled, forKey: Key.breaksOn)
    }

    // MARK: Persistence helpers

    private static func load<T: Decodable>(_ type: T.Type, _ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, _ key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded())
        if s < 60 { return "\(s) s" }
        let m = s / 60
        if m < 60 { return "\(m) min" }
        return "\(m / 60) h \(m % 60) min"
    }
}
