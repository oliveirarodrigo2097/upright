import Foundation

/// One head-motion reading. Angles in radians, acceleration in g.
public struct MotionSample: Sendable, Equatable {
    public var time: TimeInterval
    public var pitch: Double
    public var roll: Double
    public var yaw: Double
    /// Magnitude of user acceleration (gravity removed), in g.
    public var acceleration: Double

    public init(time: TimeInterval, pitch: Double, roll: Double = 0, yaw: Double = 0, acceleration: Double = 0) {
        self.time = time
        self.pitch = pitch
        self.roll = roll
        self.yaw = yaw
        self.acceleration = acceleration
    }
}

public enum Angle {
    public static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    public static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    /// Smallest signed difference a − b, wrapped to (−π, π].
    public static func difference(_ a: Double, _ b: Double) -> Double {
        var d = (a - b).truncatingRemainder(dividingBy: 2 * .pi)
        if d > .pi { d -= 2 * .pi }
        if d <= -.pi { d += 2 * .pi }
        return d
    }
}

/// Exponential moving average with a time constant, robust to uneven sample spacing.
public struct EMA: Sendable {
    public let timeConstant: TimeInterval
    public private(set) var value: Double?
    private var lastTime: TimeInterval?

    public init(timeConstant: TimeInterval) { self.timeConstant = timeConstant }

    @discardableResult
    public mutating func update(_ x: Double, at time: TimeInterval) -> Double {
        guard let v = value, let t0 = lastTime, time > t0 else {
            value = value ?? x
            lastTime = time
            return value ?? x
        }
        let alpha = 1 - exp(-(time - t0) / timeConstant)
        let next = v + alpha * (x - v)
        value = next
        lastTime = time
        return next
    }

    public mutating func reset() {
        value = nil
        lastTime = nil
    }
}
