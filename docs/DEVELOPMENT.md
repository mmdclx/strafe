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

## Fieldnote Inspector (MM-87)

The Debug menu opens the native Fieldnote inspector. Accessibility is checked
when it opens, when the active app changes, and once per second while visible.
The warning stays until macOS confirms access. The Settings action opens the
Accessibility pane; it does not grant permission. Input Monitoring is a separate
permission and is not inferred from absent touch input.

The main state shows current input and briefly retains recognized outcomes.
The footer keeps the last outcome and its original destination. “Shortcut sent”
means Strafe dispatched the shortcut, not that it verified a tab change. Gestures
with Strafe frontmost are previews. Details keeps only Accessibility access,
the current app's support status, and a plain-language summary of the last gesture.
Finger IDs, timing, movement thresholds, and internal flags are omitted from the UI.
The window scrolls when its content exceeds the available height.

Debug delivery is capped at 30 Hz and coalesces to the latest frame, including
the final lift. Closing, minimizing, or hiding the window stops delivery and the
permission/age timer. Reopening clears stale contacts. Gesture recognition and
navigation continue independently.

Recognized taps produce a circular Contact echo at the last measured tapping-finger
position, replacing the floating arrow. Defaults are depth 0.75, iridescence 0.3,
and a 1,000 ms settle. Recognition events bypass live-frame coalescing so rapid
taps are not lost; at most three independent echoes overlap. The effect confirms
recognition only: the existing text still distinguishes preview, blocked, and sent.
The native Metal surface renders at up to 60 Hz only while a visible echo is active,
then stops. Reduce Motion uses a static 300 ms crest. If Metal is unavailable, a
simple circular fallback remains. No shader resource files are needed in the bundle.

To check GPU frames and the visible-window timer lifecycle (opens a small test window):

```sh
STRAFE_ECHO_SNAPSHOTS=/tmp/strafe-echo STRAFE_ECHO_WINDOW_REVIEW=1 swift test --filter ContactEchoTests
```

For contact-echo acceptance, check left/right taps at different trackpad positions,
rapid repeats, and scrolling. The ring should originate at the tapping finger,
stay circular as the window resizes, and leave the resting marker fixed. Check
preview/blocked states, both appearances, Reduce Motion, and close/reopen or
minimize/restore; no stale echo should replay.

For optional native screenshots of permission, idle, sent, and expanded Details
at two widths and in both appearances:

```sh
STRAFE_INSPECTOR_SNAPSHOTS=/tmp/strafe-inspector swift test --filter InspectorModelTests
```

Manual review for this UI:

1. With Accessibility off, open Debug before touching the trackpad. Check the
   red pane and Settings action. Enable Strafe, return, and confirm the pane
   disappears. Revoke access and confirm it returns without a gesture.
2. Try left/right taps, rapid repeats, scrolling, and lifting all fingers. Check
   supported apps, an unsupported app, and the inspector frontmost. No preview
   or blocked gesture should be labeled as a sent shortcut.
3. Check Details, narrow/wide resizing, light/dark, Increase Contrast, Reduce
   Motion, keyboard focus, and VoiceOver. Check close/reopen and minimize/restore.
4. Profile real trackpad input with Debug open and closed using the performance
   metrics below. Unit tests do not establish hardware CPU/latency overhead.

Until MM-86 is fixed, explicitly compile before bundling to avoid stale binaries:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift build -c release
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer make build CONFIG=release
```

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
