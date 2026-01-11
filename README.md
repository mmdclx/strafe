# TabTap (MVP)

Menu bar app that enables a custom trackpad gesture for left/right tab navigation in Chrome and Safari.

## Build and Run

Requirements:
- macOS 14+
- Xcode Command Line Tools
- Network access on first build (SwiftPM downloads OpenMultitouchSupport)

Commands:
- `make build` builds `build/TabTap.app`
- `make run` builds and opens the app
- `make build CONFIG=release` for a release build

## Permissions

TabTap uses Accessibility to inject keystrokes. On first launch, macOS will prompt you to grant Accessibility access. You may need to enable TabTap in System Settings > Privacy & Security > Accessibility.

## Notes

This MVP uses the private `OpenMultitouchSupport` package to access raw trackpad touches. It is not App Store eligible in its current form, and App Sandbox must remain disabled.
