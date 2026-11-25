import Foundation

/// Upright vs slouched seconds for one calendar day.
public struct DayStats: Sendable, Equatable, Codable {
    public var uprightSeconds: TimeInterval = 0
    public var slouchSeconds: TimeInterval = 0
    public var postureAlerts: Int = 0
    public var breakReminders: Int = 0
    public var breaksTaken: Int = 0

    public init() {}

    /// Share of tracked time spent upright, 0...1, or nil with no data.
    public var uprightFraction: Double? {
        let total = uprightSeconds + slouchSeconds
        return total > 0 ? uprightSeconds / total : nil
    }
}

public struct DailyStats: Sendable, Codable, Equatable {
    public private(set) var days: [String: DayStats] = [:]

    public init() {}

    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public func day(_ date: Date) -> DayStats { days[Self.key(for: date)] ?? DayStats() }

    public mutating func update(_ date: Date, _ change: (inout DayStats) -> Void) {
        let k = Self.key(for: date)
        var d = days[k] ?? DayStats()
        change(&d)
        days[k] = d
    }

    /// Keep only the most recent `count` days.
    public mutating func prune(keeping count: Int = 120) {
        guard days.count > count else { return }
        for k in days.keys.sorted().dropLast(count) { days[k] = nil }
    }
}
