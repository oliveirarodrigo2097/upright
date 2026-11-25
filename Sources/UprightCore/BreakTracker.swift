import Foundation

public struct BreakSettings: Sendable, Equatable, Codable {
    /// Screen time before a reminder (the "20 minutes" in 20-20-20).
    public var intervalSeconds: TimeInterval = 20 * 60
    /// How long a look-away or movement must last to count as a break.
    public var breakSeconds: TimeInterval = 20
    /// Yaw away from the screen direction that counts as looking away.
    public var lookAwayDegrees: Double = 25
    /// Smoothed head acceleration (g) that counts as moving around.
    public var movingAcceleration: Double = 0.06
    /// A gap in samples this long (AirPods out / disconnected) counts as a break.
    public var disconnectSeconds: TimeInterval = 60
    /// How slowly the "screen direction" follows your head, so yaw drift is absorbed.
    public var screenYawSeconds: TimeInterval = 90

    public init() {}
}

public enum BreakEvent: Sendable, Equatable {
    case breakDue(screenTime: TimeInterval)
    case breakTaken(reason: BreakReason)
}

public enum BreakReason: Sendable, Equatable {
    case lookedAway, moved, disconnected
}

/// Tracks continuous screen time and fires 20-20-20 reminders.
public struct BreakTracker: Sendable {
    public var settings: BreakSettings
    /// Screen time since the last break, in seconds.
    public private(set) var screenTime: TimeInterval = 0

    private var lastTime: TimeInterval?
    private var screenYaw: Double?
    private var accel: EMA
    private var awaySince: TimeInterval?
    private var movingSince: TimeInterval?
    private var nextReminderAt: TimeInterval

    public init(settings: BreakSettings = BreakSettings()) {
        self.settings = settings
        self.accel = EMA(timeConstant: 2)
        self.nextReminderAt = settings.intervalSeconds
    }

    public mutating func takeBreak() {
        screenTime = 0
        nextReminderAt = settings.intervalSeconds
        awaySince = nil
        movingSince = nil
    }

    public mutating func add(_ sample: MotionSample) -> BreakEvent? {
        defer { lastTime = sample.time }

        // AirPods were out or disconnected for long enough: that was a break.
        if let last = lastTime, sample.time - last >= settings.disconnectSeconds {
            let hadScreenTime = screenTime > 0
            takeBreak()
            screenYaw = sample.yaw
            accel.reset()
            return hadScreenTime ? .breakTaken(reason: .disconnected) : nil
        }

        let dt = lastTime.map { max(0, sample.time - $0) } ?? 0
        let a = accel.update(sample.acceleration, at: sample.time)

        let reference = screenYaw ?? sample.yaw
        let yawOff = abs(Angle.degrees(Angle.difference(sample.yaw, reference)))
        let lookingAway = yawOff > settings.lookAwayDegrees
        let moving = a > settings.movingAcceleration

        // Follow slow yaw drift only while facing the screen and still.
        if !lookingAway && !moving {
            let alpha = dt > 0 ? 1 - exp(-dt / settings.screenYawSeconds) : 1
            screenYaw = reference + alpha * Angle.difference(sample.yaw, reference)
        }

        awaySince = lookingAway ? (awaySince ?? sample.time) : nil
        movingSince = moving ? (movingSince ?? sample.time) : nil

        if let since = awaySince, sample.time - since >= settings.breakSeconds {
            let had = screenTime > 0
            takeBreak()
            return had ? .breakTaken(reason: .lookedAway) : nil
        }
        if let since = movingSince, sample.time - since >= settings.breakSeconds {
            let had = screenTime > 0
            takeBreak()
            return had ? .breakTaken(reason: .moved) : nil
        }

        // Only time spent facing the screen counts. This also keeps the rest of a
        // look-away from counting as screen time right after a break.
        if !lookingAway && !moving { screenTime += dt }
        if screenTime >= nextReminderAt {
            nextReminderAt += settings.intervalSeconds
            return .breakDue(screenTime: screenTime)
        }
        return nil
    }
}
