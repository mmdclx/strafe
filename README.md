# Strafe v0.1

### Lateral tab navigation at the speed of thought.

**macOS only.** Designed for Apple Trackpads.

Most trackpad gestures are designed for scrolling; **Strafe** is designed for speed. By leveraging a high-cadence "rest + tap" interaction, it allows you to fly through browser tabs with zero friction and absolute precision.

---

## Features
* **The Lateral Gesture:** Rest a finger to anchor your position and tap left or right with a second finger to switch tabs instantly.
* **High-Performance Response:** Action latency is engineered to feel instantaneous, with a reaction time of less than 100ms.
* **Rapid Cycling:** A minimum 50ms cooldown between taps prevents accidental rapid cycling while allowing for fast, repeated movements.
* **End-to-End Wrap:** Seamlessly cycle from your final tab back to the start of the list.
* **Native Integration:** Low-level support for Chrome and Safari with zero configuration required.
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
Because Strafe interacts with your hardware at a low level and controls your browser, it requires specific macOS permissions to function:

* **Accessibility:** Required to send tab-switch commands to Chrome and Safari via simulated keystrokes.
* **Input Monitoring:** Required to observe raw trackpad touch data and detect the "rest + tap" gesture.

Upon first launch, Strafe will prompt you to enable these in **System Settings > Privacy & Security**. If permissions are denied, the app will fail gracefully and prompt for activation.

---

## Technical Details
* **Gesture Engine:** Uses the private `OpenMultitouchSupport` package for raw trackpad touch data.
* **Execution:** Injects standard keystrokes into the frontmost supported browser.
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

## Permissions

Strafe uses Accessibility to inject keystrokes. On first launch, macOS will prompt you to grant Accessibility access. You may need to enable Strafe in System Settings > Privacy & Security > Accessibility.

## Notes

This MVP uses the private `OpenMultitouchSupport` package to access raw trackpad touches. It is not App Store eligible in its current form, and App Sandbox must remain disabled.
