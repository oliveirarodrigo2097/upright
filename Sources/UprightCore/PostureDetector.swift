import Foundation

public struct PostureSettings: Sendable, Equatable, Codable {
    /// Deviation from baseline that counts as slouching, in degrees.
    public var thresholdDegrees: Double = 15
    /// Must come back within threshold − hysteresis to count as upright again.
    public var hysteresisDegrees: Double = 5
    /// How long slouching must last before an alert.
    public var sustainSeconds: TimeInterval = 120
    /// Minimum gap between alerts.
    public var cooldownSeconds: TimeInterval = 600
    /// Pitch smoothing time constant.
    public var smoothingSeconds: TimeInterval = 1.5

    public init() {}
}

public enum PostureState: Sendable, Equatable {
    case uncalibrated
    case upright
    case slouching(since: TimeInterval)
}

public enum PostureEvent: Sendable, Equatable {
    case slouchAlert(duration: TimeInterval, deviationDegrees: Double)
    case recovered
}

/// Turns a stream of head pitch into slouch alerts.
///
/// Uses the size of the deviation, not its sign, so it doesn't depend on the
/// headphones' pitch sign convention.
public struct PostureDetector: Sendable {
    public var settings: PostureSettings
    public var baselinePitch: Double? {
        didSet { reset() }
    }
    public private(set) var state: PostureState
    /// Smoothed deviation from baseline, in degrees (nil until calibrated and fed).
    public private(set) var deviationDegrees: Double?

    private var smoother: EMA
    private var lastAlert: TimeInterval?
    private var alertedThisEpisode = false

    public init(settings: PostureSettings = PostureSettings(), baselinePitch: Double? = nil) {
        self.settings = settings
        self.baselinePitch = baselinePitch
        self.state = baselinePitch == nil ? .uncalibrated : .upright
        self.smoother = EMA(timeConstant: settings.smoothingSeconds)
    }

    public mutating func reset() {
        smoother = EMA(timeConstant: settings.smoothingSeconds)
        state = baselinePitch == nil ? .uncalibrated : .upright
        deviationDegrees = nil
        alertedThisEpisode = false
    }

    /// Call when samples stop (AirPods removed). Ends any slouch episode.
    public mutating func pause() {
        reset()
    }

    public mutating func add(_ sample: MotionSample) -> PostureEvent? {
        guard let baseline = baselinePitch else {
            state = .uncalibrated
            return nil
        }
        let raw = abs(Angle.degrees(Angle.difference(sample.pitch, baseline)))
        let dev = smoother.update(raw, at: sample.time)
        deviationDegrees = dev

        switch state {
        case .uncalibrated:
            state = .upright
            return nil

        case .upright:
            if dev > settings.thresholdDegrees {
                state = .slouching(since: sample.time)
                alertedThisEpisode = false
            }
            return nil

        case .slouching(let since):
            if dev < settings.thresholdDegrees - settings.hysteresisDegrees {
                state = .upright
                let hadAlert = alertedThisEpisode
                alertedThisEpisode = false
                return hadAlert ? .recovered : nil
            }
            let duration = sample.time - since
            let cooledDown = lastAlert.map { sample.time - $0 >= settings.cooldownSeconds } ?? true
            // Re-alerts during one long slouch, but never more often than the cooldown.
            if duration >= settings.sustainSeconds, cooledDown {
                alertedThisEpisode = true
                lastAlert = sample.time
                return .slouchAlert(duration: duration, deviationDegrees: dev)
            }
            return nil
        }
    }
}
