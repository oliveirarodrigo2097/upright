# Upright — posture and break coach that uses AirPods head motion

A Mac menu-bar app. It reads head motion from your AirPods, pings you when you've been slouching for a while, and reminds you to rest your eyes after long stretches looking at the screen. Everything runs on your own device: no account, no server, no data leaves the Mac.

## Why this app

- "Tech neck" is a common, everyday problem, and many desk workers already wear AirPods all day for calls and music.
- AirPods Pro, AirPods (3rd gen and later) and AirPods Max report head attitude at about 25 Hz through `CMHeadphoneMotionManager`, which works on macOS 14+.
- Posture alerts and break reminders use the same motion stream, the same calibration and the same app, so each feature gives the other a reason to stay installed.
- Competitors exist (for example Posture Pal on iOS). To stand out: fewer false alarms, a native Mac menu-bar app, and trends people actually look at.

## Features, in order

### v0.1 — Mac menu bar (building now)

1. **Calibration.** Sit up straight and click Calibrate. The app takes the median head pitch over 3 s as your baseline, saves it and reuses it on later launches.
2. **Slouch detection.** Smooth pitch (EMA, about 1.5 s). You count as slouching while pitch deviates from baseline by more than the threshold (default 15°). Recovery uses hysteresis: you have to come back within threshold − 5°.
3. **Posture alert.** A local notification fires when slouching lasts longer than the sustain time (default 2 min). Then there is a cooldown (default 10 min) before another one, so a quick glance at your phone never triggers an alert.
4. **Break reminders (20-20-20).** Screen time adds up while the AirPods stream motion. The timer resets when you take a real break:
   - looking away (yaw more than 25° from your screen direction) for 20 s or more,
   - moving around (head acceleration above walking level) for 20 s or more,
   - taking the AirPods out or disconnecting for 60 s or more.
   After 20 min of screen time you get: "Look at something 20 ft away for 20 s." If you ignore it, the reminder repeats after another full interval.
5. **Menu-bar status.** The icon changes for good posture, slouching and AirPods not connected. The menu shows live deviation, today's upright percentage, screen time since your last break, and settings (threshold, sustain, break interval, on/off toggles).
6. **Daily stats.** Upright and slouched seconds per day, saved locally.

### v0.2 — Trends

- Hour-by-hour slouch chart (Swift Charts) and a weekly view.
- Streaks ("4 days above 80% upright").
- Quiet re-calibration suggestions when the baseline seems to have drifted.

### v0.3 — Gesture shortcuts

- Nod, shake and tilt detection on the same motion stream.
- Map gestures to actions: next/previous slide, play/pause media, scroll, dismiss notifications.
- Accessibility mode: a head gesture works as a switch input.

### v0.4 — iPhone

- iPhone app with the same detectors (shared `UprightCore` package) for slouching while away from the Mac (phone-in-lap "tech neck").
- Risk to check first: iOS may stop headphone motion updates when the app is in the background. Prototype this before promising it.
- Optional handoff: when the AirPods switch from the Mac to the iPhone, the iPhone takes over alerts.

### Later

- Daily posture summaries in plain language with a time-series language model (OpenTSLM), where every number is checked against the stored stats.
- Neck physio mode: guided rotations and tilts with range-of-motion tracking.

## Architecture

```
AirPods ──▶ MotionService (CMHeadphoneMotionManager, @MainActor)
                │  MotionSample(t, pitch, roll, yaw, accel)
                ▼
            AppModel (@Observable)
             ├─ PostureDetector  ─▶ .slouchAlert ─▶ Notifier (UNUserNotificationCenter)
             ├─ BreakTracker     ─▶ .breakDue    ─▶ Notifier
             ├─ Calibrator
             └─ DailyStats (UserDefaults)
                ▼
            MenuBarExtra UI (SwiftUI)
```

- `UprightCore` (Swift package library): pure, testable logic with no Apple-framework dependencies: detectors, calibration, angle maths, stats.
- `Upright` (executable): Core Motion, notifications, SwiftUI menu bar.
- Built with SwiftPM, then `scripts/bundle.sh` wraps it into `Upright.app` (Info.plist with `LSUIElement`, `NSMotionUsageDescription`, ad-hoc signed). No Xcode project needed.

## Known limits

- It only works while the AirPods are worn and connected to the Mac running the app.
- Pitch is measured against gravity, so it stays stable. Yaw drifts, so the break tracker compares yaw only against a slowly updated "screen direction".
- The detector uses the size of the pitch deviation, not its direction, so looking up for minutes also counts. That's rare at a desk, and it avoids depending on the sign convention of headphone pitch.
- A Mac notification doesn't reach the iPhone. iPhone pings come in v0.4.

## Done when (v0.1)

- `swift test` passes: detector timing, hysteresis, cooldown, break resets, yaw wrap-around.
- `Upright.app` launches into the menu bar, asks for motion and notification permission, calibrates, and fires a slouch notification after the sustain time in a real test with AirPods.
