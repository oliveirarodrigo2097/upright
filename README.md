# Upright

A Mac menu-bar app that uses your AirPods' head-motion sensors to tell you when you've been slouching, and reminds you to rest your eyes after long stretches at the screen.

Everything runs on your Mac. No account, no server, and no motion data leaves your machine.

## What it does

- **Posture alerts.** Calibrate once while sitting up straight. If your head stays tilted more than 15° from that position for 2 minutes, you get a notification. A quick look at your phone won't trigger it, and alerts repeat at most every 10 minutes.
- **Eye-break reminders (20-20-20).** After 20 minutes facing the screen, Upright reminds you to look at something 20 ft (6 m) away for 20 seconds. It notices real breaks on its own: looking away for 20 s, moving around, or taking your AirPods out for a minute.
- **Menu-bar status.** The icon shows whether you're upright, slouching or disconnected. The panel shows live head tilt, screen time since your last break, today's upright percentage and alert counts.
- **Settings.** Tilt limit, how long before an alert, reminder interval, on/off switches for each feature, and pause for 30 min, 1 h or 2 h.

## Screenshots

<table>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/upright-dark.png"><img src="docs/screenshots/upright-light.png" alt="Menu panel with good posture: head tilt 6° of a 15° limit, 12:34 screen time since the last break, 83% upright today" width="300"></picture><br><sub>Good posture</sub></td>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/slouching-dark.png"><img src="docs/screenshots/slouching-light.png" alt="Menu panel while slouching: head tilt 23° of a 15° limit shown in orange" width="300"></picture><br><sub>Slouching</sub></td>
  </tr>
  <tr>
    <td align="center"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/settings-dark.png"><img src="docs/screenshots/settings-light.png" alt="Settings: posture alerts on, 15° tilt limit, alert after 2 min, eye-break reminders every 20 min" width="300"></picture><br><sub>Settings</sub></td>
    <td align="center" valign="top"><picture><source media="(prefers-color-scheme: dark)" srcset="docs/screenshots/icons-dark.png"><img src="docs/screenshots/icons-light.png" alt="Menu-bar icon states: upright, slouching, needs calibration, AirPods not connected, paused" width="300"></picture><br><sub>Menu-bar icon states</sub></td>
  </tr>
</table>

## Requirements

- macOS 14 (Sonoma) or later
- AirPods that report head motion: AirPods Pro (any generation), AirPods (3rd generation or later) or AirPods Max, connected to the Mac
- Swift 6 toolchain (Xcode or the Command Line Tools)

## Build and run

```bash
scripts/bundle.sh
open build/Upright.app
```

`bundle.sh` builds with SwiftPM and wraps the binary in an ad-hoc signed `build/Upright.app`. The bundle carries the motion-permission text and runs as a menu-bar-only app. Pass `debug` for a debug build: `scripts/bundle.sh debug`.

On first launch, allow **Motion & Fitness** access and **notifications** when macOS asks. If you missed the motion prompt, turn it on in System Settings → Privacy & Security → Motion & Fitness.

## Using it

1. Put in your AirPods and connect them to the Mac.
2. Click the menu-bar icon, sit up straight, look at your screen, and click **Calibrate** (it takes 3 s).
3. Work as usual. To see an alert quickly, open **Settings**, set **Alert after** to 30 s, and slouch.

Recalibrate if you change chair, desk or monitor height.

## Tests

```bash
swift test
```

The detection logic lives in `UprightCore`, has no Apple-framework dependencies, and is tested with Swift Testing. The tests cover alert timing, hysteresis, cooldown, calibration, break detection, yaw wrap-around and drift.

### Regenerating the screenshots

The README images come from the app's real menu view, rendered with demo data in light and dark mode:

```bash
scripts/bundle.sh && build/Upright.app/Contents/MacOS/Upright --screenshots docs/screenshots
```

## Project layout

```
Sources/
  UprightCore/        Pure logic: PostureDetector, BreakTracker, Calibrator, DailyStats
  Upright/            App: MotionService (Core Motion), Notifier, AppModel, menu-bar UI
Tests/UprightCoreTests/
scripts/bundle.sh     Build + app bundle
docs/screenshots/     README images (generated, see above)
PLAN.md               Roadmap and design notes
```

## Limitations

- It only works while AirPods are worn and connected to the Mac running Upright.
- Detection uses the size of the head tilt, not its direction, so looking up for minutes also counts.
- Alerts appear on the Mac only. iPhone support is on the roadmap.
