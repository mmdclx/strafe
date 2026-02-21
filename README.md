<p align="center">
  <img src="docs/assets/logo_with_title.png" width="347" alt="Strafe logo">
</p>

# Strafe v0.1

### Lateral tab navigation at the speed of thought.

**macOS only.** Designed for Apple Trackpads.

Most trackpad gestures are designed for scrolling; **Strafe** is designed for speed. By leveraging a high-cadence "rest + tap" interaction, it lets you fly through browser tabs and other supported apps with zero friction and absolute precision.

---

## Features
* **The Lateral Gesture:** Rest a finger to anchor your position and tap left or right with a second finger to switch tabs instantly.
* **High-Performance Response:** Action latency is engineered to feel instantaneous, targeting a reaction time under 100ms.
* **Rapid Cycling:** A short cooldown (currently 25ms) prevents accidental rapid cycling while allowing fast, repeated movements.
* **Click Safety:** Successful gestures suppress accidental clicks for a brief window.
* **End-to-End Wrap:** Wrap-around behavior comes from the target app's default tab navigation (e.g., Ctrl+Tab).
* **Native Integration:** Low-level trackpad capture with context-aware tab switching for supported apps (Chrome, Safari, Finder, Terminal).
* **Minimalist Footprint:** A single-purpose menu bar utility that stays out of your way and runs until quit.

---

## How It Works
Strafe operates on a "Rest + Tap" logic. Unlike standard macOS gestures that require swiping or movement, Strafe triggers on a stationary state:

1.  **Rest:** Place one finger anywhere on the trackpad to act as your anchor.
2.  **Tap:** Tap a second finger to the left or right of the resting finger.
3.  **Result:** Immediately switch to the adjacent tab.

Keep the resting finger down to repeatedly tap and cycle through your workspace.

---

## Supported Apps
Strafe is context-aware. It only triggers when one of the following apps is frontmost, ensuring it never interferes with your other workflows:

* **Google Chrome:** Rapidly cycle through your open tabs.
* **Safari:** Native support for Apple’s default browser.
* **Finder:** Pivot between multiple open Finder tabs with ease.
* **Terminal:** Move laterally across your active terminal sessions.

---

## Installation & Permissions
Because Strafe interacts with your hardware at a low level and controls your frontmost app, it requires specific macOS permissions to function:

* **Accessibility:** Required to send tab-switch commands via simulated keystrokes.
* **Input Monitoring:** Required to observe raw trackpad touch data and detect the "rest + tap" gesture.

Upon first launch, Strafe will prompt you to enable Accessibility in **System Settings > Privacy & Security**. If permissions are denied, the app will fail gracefully and prompt for activation.

---

## Technical Details
* **Gesture Engine:** Uses the private `OpenMultitouchSupport` package for raw trackpad touch data.
* **Execution:** Injects standard keystrokes into the frontmost supported app (Ctrl+Tab / Ctrl+Shift+Tab).
* **Click Guard:** Drops left-clicks immediately after a successful gesture to avoid accidental UI activation.
* **Constraint:** Only active when a supported app is frontmost; it will not steal focus from other apps.

---

## Privacy
Strafe is a local-only utility. It does not collect data, require network access, or track your browsing history.


## Apps
Menu bar app that enables a custom trackpad gesture for left/right tab navigation in Chrome, Safari, Finder, and Terminal.

## Build and Run

Requirements:
- macOS 14+
- Xcode Command Line Tools
- Network access on first build (SwiftPM downloads OpenMultitouchSupport)

Commands:
- `make build` builds `build/Strafe.app`
- `make run` builds and opens the app
- `make build CONFIG=release` for a release build
- `make clean` removes `build/` output
- `swift package clean` clears SwiftPM artifacts in `.build` if you want a full rebuild

## Performance Metrics (MM-63)

Strafe includes lightweight aggregated perf instrumentation to support gesture profiling.

- Debug builds (`make run`) emit a `performance` log line every 10s.
- Release builds keep metrics off unless `STRAFE_PERF_METRICS=1`.
- Metrics include callback/query rates and per-path timing summaries:
  - touch callback frequency and sample volume
  - gesture candidate evaluation count
  - successful gesture triggers
  - click suppressor invocations and dropped click events
  - frontmost app query frequency
  - avg/max timing for touch mapping, classifier processing, frontmost query, and click event handling

To capture in release for local profiling:
- `make build CONFIG=release`
- `STRAFE_PERF_METRICS=1 build/Strafe.app/Contents/MacOS/Strafe`

## Development Workflow (Feature Checklist)

- Start from a clean tree: `git status -s`
- Create/confirm a Linear issue and set it In Progress
- Branch from `main` with a short-lived feature branch
- Implement the change and validate locally (`make run`)
- Commit the change with a clear message
- Push the branch and merge to `main`
- Update the Linear issue with findings and mark Done
- Optionally delete the feature branch

## Branching and Releases

Branching is intentionally simple:
- `main` stays stable.
- Releases are tagged on `main` as `vX.Y.Z`.
- If needed, cut a short-lived `release/vX.Y.Z` branch from `main` for prep or hotfixes, then merge back and delete it after tagging.

Lightweight release flow:
- Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
- Build a release binary (`make build CONFIG=release`).
- Tag the release on `main` (`vX.Y.Z`).

## Permissions

Strafe uses Accessibility to inject keystrokes. On first launch, macOS will prompt you to grant Accessibility access. You may need to enable Strafe in System Settings > Privacy & Security > Accessibility, and also grant Input Monitoring to capture raw trackpad touches.

## Notes

This MVP uses the private `OpenMultitouchSupport` package to access raw trackpad touches. It is not App Store eligible in its current form, and App Sandbox must remain disabled.
