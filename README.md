# Strafe
Lateral tab navigation at the speed of thought.
macOS only. Designed for Apple Trackpads.

Most trackpad gestures are designed for scrolling; Strafe is designed for speed. By leveraging a high-cadence "rest + tap" interaction, it lets you fly through browser tabs and other supported apps with zero friction and absolute precision.

<p align="center">
  <img src="docs/assets/logo_with_title.png" width="347" alt="Strafe logo">
</p>

## Status

Strafe is currently a public preview for macOS 14+.

- Apple trackpad required
- Direct distribution only
- Uses the private `OpenMultitouchSupport` package
- Not App Store eligible in its current form
- Unsigned preview release assets may trigger Gatekeeper warnings on first launch

## Download

GitHub release assets are published here:

- <https://github.com/mmdclx/strafe/releases/latest>

The intended first downloadable asset format is:

- `Strafe-X.Y.Z-macos.zip`
- `SHA256SUMS.txt`

Preview builds are currently unsigned. If macOS blocks first launch, right-click `Strafe.app`, choose `Open`, and confirm. If the app was quarantined by the browser, you may also need to clear quarantine manually.

## Build From Source

Requirements:

- macOS 14+
- Xcode Command Line Tools
- Network access on first build for Swift Package Manager dependencies

Happy path:

```sh
make build CONFIG=release
open build/Strafe.app
```

Useful commands:

- `make build` builds a debug app bundle at `build/Strafe.app`
- `make run` builds and opens the debug app bundle
- `make build CONFIG=release` builds the release app bundle
- `make package-release` builds a release bundle and creates a zip plus checksum in `build/`
- `make clean` removes `build/`

## Permissions

Strafe needs the following macOS permissions:

- Accessibility: required to send tab-switch keystrokes
- Input Monitoring: required to read raw trackpad touch data

On first launch, macOS should prompt for Accessibility. You may need to grant both permissions in `System Settings > Privacy & Security`.

## Supported Apps

Strafe only triggers when one of these apps is frontmost:

- Google Chrome
- Safari
- Finder
- Terminal

## How It Works

Strafe uses a rest-and-tap gesture:

1. Rest one finger anywhere on the trackpad.
2. Tap a second finger to the left or right of the resting finger.
3. Strafe sends the corresponding tab-navigation shortcut to the frontmost supported app.

Keep the resting finger down to repeat taps and cycle quickly.

## Notes

- Strafe is local-only and does not collect data.
- Release builds keep runtime performance metrics disabled unless `STRAFE_PERF_METRICS=1`.
- This repository is public, but no open-source license is included at this stage.

## Maintainer Docs

- Development notes: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md)
- Release checklist: [docs/RELEASING.md](docs/RELEASING.md)
- Changelog: [CHANGELOG.md](CHANGELOG.md)
