import Foundation
import Testing
@testable import UprightCore

/// Generates samples at 25 Hz from `start` for `seconds`.
private func samples(
    from start: TimeInterval = 0, seconds: TimeInterval,
    pitchDeg: Double = 0, yawDeg: Double = 0, accel: Double = 0
) -> [MotionSample] {
    let n = Int(seconds * 25)
    return (0..<n).map { i in
        MotionSample(
            time: start + Double(i) / 25,
            pitch: Angle.radians(pitchDeg),
            yaw: Angle.radians(yawDeg),
            acceleration: accel)
    }
}

private func feed(_ d: inout PostureDetector, _ s: [MotionSample]) -> [PostureEvent] {
    s.compactMap { d.add($0) }
}

private func feed(_ b: inout BreakTracker, _ s: [MotionSample]) -> [BreakEvent] {
    s.compactMap { b.add($0) }
}

@Suite struct AngleTests {
    @Test func wrapsAcrossPi() {
        let d = Angle.difference(Angle.radians(179), Angle.radians(-179))
        #expect(abs(Angle.degrees(d) - (-2)) < 1e-9)
    }
}

@Suite struct CalibratorTests {
    @Test func returnsMedianAfterWindow() {
        var c = Calibrator(duration: 3)
        var result: Double?
        // Mostly 10°, with an outlier spike that the median ignores.
        for (i, s) in samples(seconds: 3.2, pitchDeg: 10).enumerated() {
            var s = s
            if i == 5 { s.pitch = Angle.radians(80) }
            if let r = c.add(s) { result = r; break }
        }
        #expect(result.map { abs(Angle.degrees($0) - 10) < 1e-9 } == true)
    }
}

@Suite struct PostureDetectorTests {
    @Test func uncalibratedNeverAlerts() {
        var d = PostureDetector()
        #expect(feed(&d, samples(seconds: 300, pitchDeg: 40)).isEmpty)
        #expect(d.state == .uncalibrated)
    }

    @Test func alertsOnceAfterSustainedSlouch() {
        var d = PostureDetector(baselinePitch: 0)
        let events = feed(&d, samples(seconds: 130, pitchDeg: 25))
        #expect(events.count == 1)
        if case .slouchAlert(let duration, let dev) = events.first {
            #expect(duration >= 120)
            #expect(dev > 20)
        } else {
            Issue.record("expected a slouch alert")
        }
    }

    @Test func shortSlouchDoesNotAlert() {
        var d = PostureDetector(baselinePitch: 0)
        var events = feed(&d, samples(seconds: 60, pitchDeg: 25))
        events += feed(&d, samples(from: 60, seconds: 60, pitchDeg: 0))
        events += feed(&d, samples(from: 120, seconds: 60, pitchDeg: 25))
        #expect(events.isEmpty)
    }

    @Test func worksForEitherPitchSign() {
        var d = PostureDetector(baselinePitch: 0)
        #expect(feed(&d, samples(seconds: 130, pitchDeg: -25)).count == 1)
    }

    @Test func hysteresisKeepsSlouchingJustBelowThreshold() {
        var d = PostureDetector(baselinePitch: 0)
        _ = feed(&d, samples(seconds: 30, pitchDeg: 25))
        _ = feed(&d, samples(from: 30, seconds: 30, pitchDeg: 12))  // between 10° and 15°
        if case .slouching = d.state {} else { Issue.record("should still be slouching") }
        _ = feed(&d, samples(from: 60, seconds: 30, pitchDeg: 5))
        #expect(d.state == .upright)
    }

    @Test func recoveredAfterAlert() {
        var d = PostureDetector(baselinePitch: 0)
        var events = feed(&d, samples(seconds: 130, pitchDeg: 25))
        events += feed(&d, samples(from: 130, seconds: 10, pitchDeg: 0))
        #expect(events.last == .recovered)
    }

    @Test func longSlouchRealertsOnlyAfterCooldown() {
        var d = PostureDetector(baselinePitch: 0)  // sustain 120 s, cooldown 600 s
        let events = feed(&d, samples(seconds: 15 * 60, pitchDeg: 25))
        #expect(events.count == 2)  // ~121 s and ~721 s
    }

    @Test func recalibratingResetsState() {
        var d = PostureDetector(baselinePitch: 0)
        _ = feed(&d, samples(seconds: 30, pitchDeg: 25))
        d.baselinePitch = Angle.radians(25)
        #expect(d.state == .upright)
        #expect(feed(&d, samples(from: 30, seconds: 200, pitchDeg: 25)).isEmpty)
    }
}

@Suite struct BreakTrackerTests {
    @Test func remindsAfterInterval() {
        var b = BreakTracker()
        let events = feed(&b, samples(seconds: 20 * 60 + 5))
        #expect(events.count == 1)
        if case .breakDue(let t) = events.first { #expect(t >= 20 * 60) }
    }

    @Test func repeatsIfIgnored() {
        var b = BreakTracker()
        let events = feed(&b, samples(seconds: 40 * 60 + 5))
        #expect(events.filter { if case .breakDue = $0 { true } else { false } }.count == 2)
    }

    @Test func lookingAwayCountsAsBreak() {
        var b = BreakTracker()
        _ = feed(&b, samples(seconds: 10 * 60))
        let events = feed(&b, samples(from: 600, seconds: 25, yawDeg: 60))
        #expect(events == [.breakTaken(reason: .lookedAway)])
        #expect(b.screenTime == 0)
    }

    @Test func briefGlanceIsNotABreak() {
        var b = BreakTracker()
        _ = feed(&b, samples(seconds: 10 * 60))
        _ = feed(&b, samples(from: 600, seconds: 10, yawDeg: 60))
        _ = feed(&b, samples(from: 610, seconds: 10))
        #expect(b.screenTime > 10 * 60)
    }

    @Test func movingCountsAsBreak() {
        var b = BreakTracker()
        _ = feed(&b, samples(seconds: 300))
        let events = feed(&b, samples(from: 300, seconds: 30, accel: 0.2))
        #expect(events == [.breakTaken(reason: .moved)])
    }

    @Test func disconnectGapCountsAsBreak() {
        var b = BreakTracker()
        _ = feed(&b, samples(seconds: 300))
        let events = feed(&b, samples(from: 400, seconds: 1))
        #expect(events == [.breakTaken(reason: .disconnected)])
    }

    @Test func yawWrapIsNotLookingAway() {
        var b = BreakTracker()
        var events = feed(&b, samples(seconds: 60, yawDeg: 179))
        events += feed(&b, samples(from: 60, seconds: 60, yawDeg: -179))
        #expect(events.isEmpty)
        #expect(b.screenTime > 110)
    }

    @Test func slowYawDriftIsAbsorbed() {
        var b = BreakTracker()
        // Drift 40° over 20 minutes: slower than the screen-direction tracker.
        let n = 20 * 60 * 25
        var events: [BreakEvent] = []
        for i in 0..<n {
            let t = Double(i) / 25
            let s = MotionSample(time: t, pitch: 0, yaw: Angle.radians(40 * t / 1200))
            if let e = b.add(s) { events.append(e) }
        }
        #expect(!events.contains { if case .breakTaken = $0 { true } else { false } })
    }
}

@Suite struct DailyStatsTests {
    @Test func accumulatesAndComputesFraction() {
        var s = DailyStats()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        s.update(now) { $0.uprightSeconds += 75; $0.slouchSeconds += 25 }
        #expect(s.day(now).uprightFraction == 0.75)
        #expect(DayStats().uprightFraction == nil)
    }
}
