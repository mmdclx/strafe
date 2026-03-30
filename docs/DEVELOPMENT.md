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
