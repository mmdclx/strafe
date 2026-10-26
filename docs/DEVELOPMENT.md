# Development

## Build and Run

Requirements:

- macOS 14+
- Xcode Command Line Tools
- Network access on first build for Swift Package Manager dependencies

Commands:

- `make build` builds `build/Strafe.app`
- `make run` builds and opens the app
- `make build CONFIG=release` builds a release app bundle
- `make package-release` builds a release app bundle plus a zip and checksum
- `make clean` removes `build/`
- `swift package clean` clears SwiftPM artifacts in `.build`

## Automated Smoke Tests (MM-27)

Run from the repository root on macOS with Xcode 16 or newer selected:

```sh
swift test
```

If `xcode-select -p` points to Command Line Tools and the build reports
`no such module 'Testing'`, select the installed Xcode for this command only:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

This does not change your system-wide developer-directory selection.

SwiftPM builds current sources before running the tests. The first run needs
network access to resolve the OpenMultitouchSupport dependency, just like an app
build. Tests do not start the app or multitouch listener, install an event tap,
post keystrokes, or request Accessibility/Input Monitoring permissions.

The suite covers:

- Synthetic rest-and-tap sequences: left/right release, ending phases without
  duplicate triggers, rapid repeats/cooldown, reset, and debug-stream parity.
- False-positive guards: single/simultaneous fingers, immature or moving rest,
  insufficient separation, long holds, moving taps, scrolling, and lost rest.
- The production click-suppression timing policy: starts on request, expires at
  the deadline even if its timer is delayed, extends on repeat requests, rejects
  stale timer deadlines, and clears on stop.
- Permission and frontmost-app routing, including changes between gestures.
  The real navigation controller's generated key-down/key-up events are captured
  to verify Ctrl+Shift+Tab / Ctrl+Tab for Chrome, Safari, Finder, and Terminal.

Touch sequences and suppression tests supply explicit monotonic timestamps;
they do not sleep or depend on wall-clock timing. Suppression-policy tests do
not validate the OS event tap, timer scheduling, or thread interleavings.

### Remaining Manual Smoke Checks

Before a release or after changes to OS/hardware integration:

1. Launch the freshly built app. Check Accessibility and Input Monitoring
   denied/granted flows, including relaunch where macOS requires it. Confirm
   missing permissions do not crash the app or send navigation keys.
2. On a MacBook trackpad and Magic Trackpad when available, verify left/right
   taps and rapid repeats, ordinary scrolling, and no navigation from incidental
   touches. Record hardware/macOS version and any device not tested.
3. In each supported app, verify tab direction and boundary wrap-around. Switch
   to an unsupported app and confirm gestures leave it alone. Check underlying
   controls are not clicked by successful gestures and normal clicking resumes
   immediately afterward, including after rapid repeats.
4. Open/close the debug window while gesturing; confirm feedback and navigation
   still work. Quit and relaunch; confirm no lingering click suppression.

Record the test command/result and manual outcomes in the relevant Linear issue.

## Performance Metrics

Strafe includes lightweight aggregated runtime metrics for local profiling.

- Debug builds emit a `performance` log line every 10 seconds.
- Release builds keep metrics off unless `STRAFE_PERF_METRICS=1`.
- Reported metrics include callback/query rates and timing summaries for touch mapping, gesture classification, frontmost-app queries, and click suppression.

To capture metrics in a release build:

```sh
make build CONFIG=release
STRAFE_PERF_METRICS=1 build/Strafe.app/Contents/MacOS/Strafe
```

## Workflow

- Start from a clean tree: `git status -s`
- Tie substantive work to a Linear issue
- Validate locally before committing
- Keep `main` stable
- Tag releases on `main` as `vX.Y.Z`

For the exact manual release procedure, use [RELEASING.md](RELEASING.md).
