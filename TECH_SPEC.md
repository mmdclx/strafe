# macOS Tab Browsing Trackpad Helper - Technical Spec (MVP)

## 1) Scope
- macOS menu bar app that detects a custom trackpad gesture and switches tabs left/right in Chrome or Safari.
- MVP is direct distribution only; App Store eligibility is a future consideration.

## 2) Design Principles
- DRY: Centralize thresholds, timing windows, and browser shortcuts in one constants module.
- SOLID:
  - Single Responsibility: separate gesture detection, browser control, permissions, and UI lifecycle.
  - Open/Closed: allow swapping gesture backends (private vs. public APIs) via protocol.
  - Liskov + Interface Segregation: small protocols for each capability, easy mocks.
  - Dependency Inversion: app core depends on protocols, not concrete implementations.

## 3) Dependencies and Frameworks
### 3.1 MVP (Direct Distribution)
- Private: `OpenMultitouchSupport` (wraps `MultitouchSupport.framework`) for raw trackpad touch data with stable touch IDs/states.
- Public:
  - AppKit or SwiftUI for menu bar UI (`NSStatusItem` or `MenuBarExtra`).
  - Quartz Event Services for keystroke injection (`CGEventCreateKeyboardEvent`, `CGEventPost`).
  - Accessibility permission checks (`AXIsProcessTrustedWithOptions`).

### 3.2 Future App Store Path
- Replace private multitouch access with App Store-safe gesture detection.
- Keep multitouch logic behind a `GestureDetecting` protocol so the backend is swappable.

## 4) High-Level Architecture
- Menu bar app process only (no helper).
- Event pipeline: raw touch data -> gesture classifier -> navigation event -> browser control.

## 5) Core Modules
### 5.1 GestureEngine
- Consumes raw touch data and emits `GestureEvent.left` / `GestureEvent.right`.
- Owns a small state machine for "rest + tap" and a 50ms cooldown.

### 5.2 BrowserController
- Sends `Ctrl+Tab` and `Ctrl+Shift+Tab` to the frontmost browser.
- Gated by frontmost app: only Chrome or Safari.

### 5.3 PermissionService
- Checks Accessibility trust.
- Prompts via `AXIsProcessTrustedWithOptions` when needed.

### 5.4 AppLifecycle
- Creates menu bar icon and Quit menu.
- Starts and stops gesture pipeline.
- Shows minimal error messaging if permissions are missing.

### 5.5 EventRouter
- Wires `GestureEngine` to `BrowserController` with minimal logic.

## 6) Protocols (Interfaces)
- `GestureDetecting`: start/stop, emits high-level left/right events.
- `BrowserNavigating`: `navigateLeft()`, `navigateRight()`.
- `PermissionChecking`: `isTrusted()`, `promptIfNeeded()`.
- `FrontmostAppQuerying`: `frontmostAppId()`.

## 7) Gesture Detection Details
### 7.1 Touch Model
- Use OpenMultitouchSupport event stream to receive per-finger positions, identifiers, and touch states.
- Identify a "resting" finger (longest held touch) and a "tap" finger (new touch with short lifetime).

### 7.2 Classification Rules
- On second finger tap, compare X coordinate to resting finger.
- If delta X < -MIN_DELTA -> left; if delta X > MIN_DELTA -> right.
- Ignore taps where abs(delta X) < MIN_DELTA.

### 7.3 Scroll Suppression
- Detect two-finger scroll intent by movement magnitude and velocity while both fingers are down.
- If movement exceeds SCROLL_THRESHOLD, suppress gesture events until fingers lift.

### 7.4 Cooldown
- Minimum 50ms between recognized taps.
- Track last-trigger timestamp and ignore taps inside window.

### 7.5 Repeated Taps
- As long as resting finger remains down, allow subsequent taps to trigger navigation.

## 8) Browser Navigation
- If frontmost app bundle ID is Chrome or Safari, post keystrokes:
  - Right: `Ctrl+Tab`
  - Left: `Ctrl+Shift+Tab`
- Assume wrap-around behavior for MVP.

## 9) Permissions
- Accessibility is required for key injection.
- On startup, check trust; if not trusted, prompt and show a small explanation.

## 10) Constants (DRY)
- `MIN_DELTA`: minimum X difference between resting and tap finger.
- `SCROLL_THRESHOLD`: minimum motion to classify as scroll.
- `COOLDOWN_MS`: 50ms.
- `SUPPORTED_BROWSERS`: bundle IDs for Chrome and Safari.

## 11) Error Handling and Logging
- Fail gracefully if permissions are not granted; no crashes.
- Minimal logging (debug-only) for gesture classification and permission state.

## 12) Testing Strategy
- Unit tests for gesture classification and state machine transitions.
- Mocks for `BrowserNavigating` to verify left/right routing.
- Manual QA on MacBook trackpad and Magic Trackpad.

## 13) Risks
- Private API usage not App Store-safe.
- Gesture ambiguity with scroll/other trackpad actions.
- Hardware variability affecting threshold tuning.
