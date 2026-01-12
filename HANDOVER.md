# Handover - Strafe MVP

## Project Summary
Strafe is a macOS menu bar app that enables a custom trackpad gesture (rest one finger + tap another to left/right) to switch browser tabs in Chrome/Safari. The app is intentionally minimal: menu bar icon with Quit, and a Debug window for visualizing gesture detection.

## Current State (as of handover)
- We migrated from raw `MultitouchSupport.framework` bindings to **OpenMultitouchSupport** (private, SPM) for stable touch IDs and touch state.
- Build tooling moved to **Swift Package Manager** via `Package.swift` and `Makefile` now calls `swift build` then copies the binary into `build/Strafe.app`.
- A Debug window exists in the menu bar to visualize touches and tap detection. It shows:
  - Green dots = current touches
  - Yellow ring = resting touch
  - Orange fill = tap candidate
  - Red ring = moved beyond scroll threshold
  - Blue/red line from resting to candidate
  - Label includes `Resting`, `Tap`, `dX`, `Locked`, `Suppressed`, and touch phase abbreviations.

## What Was Failing
- The original algorithm using raw MTContact data was unreliable; IDs were unstable and gestures misfired. We decided to switch to OpenMultitouchSupport.
- After migration, Swift 6 concurrency errors showed up. These were addressed by isolating AppKit code on the main actor and marking protocols `@MainActor`.
- The user is still not satisfied with gesture reliability; the algorithm needs further tuning/testing after the OpenMultitouchSupport migration.

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

## Current Compilation Status
- After marking protocols `@MainActor`, the next build **has not been re-run** yet. Run `make run` and fix any remaining compile errors.

## Known Behavior Issues
- Gesture detection still unreliable and user reports repeated flashes and suppression (likely due to tap state transitions).
- Need to verify if touch phases from OpenMultitouchSupport (e.g., `making`, `touching`, `breaking`) are being handled correctly for the tap-release detection.

## Next Steps (Recommended)
1) **Rebuild** (`make run`) and fix any remaining Swift 6 concurrency errors.
2) **Confirm OpenMultitouchSupport works**: Debug window should show live touches with phase abbreviations.
3) **Improve gesture logic**:
   - Trigger on tap finger phase change to `.breaking` / `.leaving`, not on movement jitter.
   - Ensure tap only triggers once per tap (debounce via `tapLocked` + `cooldownSeconds`).
   - If `Suppressed: yes` frequently, relax or disable scroll suppression until basic tap works.
4) **Tune thresholds** in `AppConstants.swift`:
   - `minTapDelta` (left/right separation)
   - `tapMaxDurationSeconds`
   - `restingMovementThreshold` and `scrollMovementThreshold`

## Notes
- This is direct distribution only; private multitouch is not App Store safe.
- Accessibility permission is required for keystroke injection.
