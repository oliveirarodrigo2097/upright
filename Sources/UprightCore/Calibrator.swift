import Foundation

/// Collects samples for a fixed window and returns the median pitch as the upright baseline.
public struct Calibrator: Sendable {
    public let duration: TimeInterval
    private var start: TimeInterval?
    private var pitches: [Double] = []

    public init(duration: TimeInterval = 3) { self.duration = duration }

    public var progress: Double {
        guard let start, let last = lastTime else { return 0 }
        return min(1, (last - start) / duration)
    }
    private var lastTime: TimeInterval?

    /// Feed a sample. Returns the baseline pitch once the window is full, otherwise nil.
    public mutating func add(_ sample: MotionSample) -> Double? {
        if start == nil { start = sample.time }
        lastTime = sample.time
        pitches.append(sample.pitch)
        guard let start, sample.time - start >= duration, !pitches.isEmpty else { return nil }
        let sorted = pitches.sorted()
        let mid = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }
}
