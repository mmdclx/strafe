# macOS Tab Browsing Trackpad Helper — PRD (Draft)

## 1) Summary
A macOS menu bar app that enables a single, custom trackpad gesture for fast left/right tab navigation in Chrome and Safari. The app runs as an icon-only menu bar utility with a single “Quit” action.

## 2) Goals
- Provide a fast, low-friction way to move left/right across tabs in Chrome and Safari via a custom two-finger “rest + tap” gesture.
- Keep the MVP minimal: no settings UI, no onboarding beyond system permission prompts.
- Ensure wrap-around behavior at tab boundaries.

## 3) Non-goals (MVP)
- Windows or Linux support.
- Other browsers (Firefox, Arc, etc.).
- Gesture customization or keyboard shortcuts.
- UI beyond menu bar icon with “Quit”.
- Analytics, accounts, or cloud sync.

## 4) Users & Use Cases
- macOS power users who browse with many tabs and want rapid tab navigation.
- Users accustomed to BetterTouchTool-like gestures but want a single-purpose, lightweight tool.

## 5) User Stories
- As a user, when I rest one finger on the trackpad and tap a second finger to the left, I move to the tab left of the active tab.
- As a user, when I rest one finger on the trackpad and tap a second finger to the right, I move to the tab right of the active tab.
- As a user, if I’m at the far-left tab and go left, I wrap to the far-right tab (and vice versa).
- As a user, if I keep the resting finger down and repeatedly tap, I can rapidly move across tabs.

## 6) Functional Requirements (MVP)
### 6.1 Gesture Detection
- Detect a “resting finger” on trackpad.
- Detect a second finger tap and classify whether it occurred to the left or right of the resting finger.
- Trigger a tab navigation action immediately on detection.
- Allow repeated taps while the resting finger remains down, producing repeated tab switches.
- Distinguish intentional tap gestures from two-finger scrolls; do not trigger tab switches on scroll gestures.
- Apply a minimum 50ms cooldown between taps to prevent accidental rapid cycling.

### 6.2 Browser Targeting
- Support Chrome and Safari only.
- Only act when Chrome or Safari is frontmost; otherwise do nothing.
- Actions are sent to the frontmost supported browser.

### 6.3 Tab Navigation
- Move left or right among tabs.
- Wrap-around at the ends (left from first tab → last tab; right from last tab → first tab).

### 6.4 Menu Bar App Behavior
- App runs in menu bar with an icon.
- Clicking icon opens a minimal menu containing only “Quit”.
- App auto-starts on launch and continues until quit.

### 6.5 Permissions & System Integration
- The app must request the minimum macOS permissions required to:
  - Observe trackpad touches/gestures.
  - Send tab-switch actions to the active browser (Accessibility permission for simulated keystrokes).
- If permissions are not granted, the app should fail gracefully and prompt the user to enable them.

## 7) UX Requirements
- No visible UI besides menu bar icon and “Quit” menu item.
- Zero configuration for MVP.
- Action latency should feel instantaneous (<100ms from tap to tab switch).

## 8) Technical Considerations (MVP)
- Gesture capture: use trackpad touch events (likely via NSEvent or a lower-level tap if necessary).
- Browser control:
  - Send standard tab-navigation keystrokes to the frontmost browser (e.g., Ctrl+Tab / Ctrl+Shift+Tab) and assume wrap-around behavior for MVP.
- Process: single background menu bar app; no separate helper.
### 8.1 Libraries & Framework Approach (MVP)
- Prefer well-known system frameworks over custom code wherever possible.
- Use the private OpenMultitouchSupport package (wraps MultitouchSupport.framework) for raw trackpad touch data in the MVP (direct distribution only).
- Wrap multitouch access behind a protocol to allow a future App Store-safe implementation without rewriting the app.
- Use AppKit/SwiftUI for menu bar UI and Quartz/Accessibility APIs for keystroke injection and permissions.

## 9) Edge Cases
- User taps too close to resting finger; define a minimal left/right delta (e.g., N points) to avoid misfires.
- Accidental second-finger taps when performing other trackpad actions.
- Trackpad hardware differences (Magic Trackpad vs MacBook trackpad).
- When Chrome/Safari isn’t frontmost, do nothing (do not steal focus).
- Two-finger scroll should not trigger tab switching.

## 10) Security & Privacy
- No data collection.
- No network access.
- Only local gesture processing and local browser control.

## 11) Success Criteria
- 95%+ correct left/right detection during normal usage.
- <100ms reaction time from tap to tab change.
- Reliable wrap-around on both Chrome and Safari.
- No crashes when permissions are denied.

## 12) MVP Scope Checklist
- [ ] Menu bar app with icon and “Quit”.
- [ ] Trackpad “rest + tap left/right” detection.
- [ ] Tab navigation for Chrome & Safari.
- [ ] Wrap-around behavior.
- [ ] Permissions handling and graceful failure messaging.
- [ ] Minimum 50ms tap cooldown.

## 13) Visual Design (MVP)
- Menu bar icon uses a Lucide-style minimalist glyph (template monochrome).
