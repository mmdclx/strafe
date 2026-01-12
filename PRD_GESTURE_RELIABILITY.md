# Gesture Reliability Tuning PRD (Concise)

## Summary
Reduce accidental tab-switch triggers during two-finger scrolling while preserving fast, reliable tap navigation. Keep a strict allowlist of bundle IDs and add Finder.

## Goals
- Eliminate scroll-triggered tab switches in Chrome/Safari/Finder.
- Maintain responsive, reliable left/right tap detection.
- Keep explicit bundle allowlist (no auto-discovery).

## Non-goals
- App Store compatibility or public distribution changes.
- UI for configuration or per-app settings.
- Dynamic detection of "apps with tabs."

## Scope & Approach
- Track cumulative movement since touch-down (not per-sample jitter).
- Strengthen scroll suppression when two touches show scroll-like movement.
- Tighten tap candidate rules (resting age gate, candidate max travel, end-phase requirement).
- Adjust thresholds in `AppConstants` and validate in the Debug window.

## Success Criteria
- 0 accidental triggers during typical two-finger scroll sessions.
- >=95% success for deliberate tap gestures.
- No noticeable latency regression.

## QA Notes
- Manual test matrix: two-finger scroll, tap left/right, repeated taps, jittery rests.
- Confirm frontmost app gating works for Chrome, Safari, Finder only.
