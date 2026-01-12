# Handover - Strafe MVP

## Project Summary
Strafe is a macOS menu bar app that enables a custom trackpad gesture (rest one finger + tap another to left/right) to switch tabs in supported apps (Chrome, Safari, Finder, Terminal). The app is intentionally minimal: menu bar icon with Quit, and a Debug window for visualizing gesture detection.

## Current State (as of handover)
- We migrated from raw `MultitouchSupport.framework` bindings to **OpenMultitouchSupport** (private, SPM) for stable touch IDs and touch state.
- Build tooling moved to **Swift Package Manager** via `Package.swift` and `Makefile` now calls `swift build`, embeds the framework, and re-signs `build/Strafe.app`.
- A Debug window exists in the menu bar to visualize touches and tap detection. It shows:
  - Green dots = current touches
  - Yellow ring = resting touch
  - Orange fill = tap candidate
  - Red ring = moved beyond scroll threshold
  - Blue/red line from resting to candidate
  - Label includes `Trusted`, `Front`, `Resting`, `Tap`, `dX`, movement metrics, `Locked`, `Suppressed`, and touch phase abbreviations.
- Gesture reliability improvements: cumulative travel tracking, scroll suppression window, tap candidate travel limits, and a fast tap rearm for rapid repeats.
- Allowlist expanded to include Finder and Terminal.

## Recent Fixes
- The original algorithm using raw MTContact data was unreliable; IDs were unstable and gestures misfired. We decided to switch to OpenMultitouchSupport.
- After migration, Swift 6 concurrency errors showed up. These were addressed by isolating AppKit code on the main actor and marking protocols `@MainActor`.
- Gesture reliability was improved by tightening scroll suppression and rearming taps faster while the resting finger stays stable.

## Build/Run
- `make run` builds and opens the app bundle.
- First build will download OpenMultitouchSupport from GitHub via SPM.
- You may get a Keychain prompt for GitHub credentials; **Deny** should still allow download since it is a public repo.

## Important Files
- `Package.swift` — SPM manifest (OpenMultitouchSupport dependency).
- `Makefile` — build/run wrapper for SPM binary -> app bundle.
- `Sources/Strafe/Gesture/MultitouchGestureEngine.swift` — now uses `OMSManager` (OpenMultitouchSupport) to stream touches.
- `Sources/Strafe/Gesture/GestureClassifier.swift` — current gesture logic, now using touch phases (`starting/making/touching/breaking/leaving`).
- `Sources/Strafe/Debug/DebugWindowController.swift` — debug overlay and label string.
- `Sources/Strafe/AppDelegate.swift` — menu bar setup, Debug window entry.
- `Sources/Strafe/Protocols.swift` — protocols now `@MainActor` to satisfy Swift 6 concurrency checks.
- `PRD.md` and `TECH_SPEC.md` — updated to mention OpenMultitouchSupport.

## Current Build Status
- `make run` builds and launches the app; the Makefile embeds OpenMultitouchSupport and re-signs the app bundle.

## Known Behavior Issues
- Finder/Terminal may not use `Ctrl+Tab` for tab switching; per-app key mappings are not implemented yet.
- Threshold tuning may still need adjustment per trackpad hardware.

## Next Steps (Recommended)
1) **Consider per-app shortcuts** for Finder/Terminal (e.g., Cmd+Shift+[ / ]).
2) **Continue tuning thresholds** in `AppConstants.swift` based on real usage.
3) **Optional cleanup**: remove or relocate the reliability PRD once the changes are stable.

## Notes
- This is direct distribution only; private multitouch is not App Store safe.
- Accessibility permission is required for keystroke injection.
