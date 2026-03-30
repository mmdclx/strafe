# Releasing Strafe

This project currently uses a manual release flow. Release assets are public preview builds and are not notarized in this first pass.

## Release Inputs

- `Resources/Info.plist` is the version source of truth
- Git tag must match the app version exactly: `vX.Y.Z`
- Release assets are:
  - `Strafe-X.Y.Z-macos.zip`
  - `SHA256SUMS.txt`

## Manual Release Checklist

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in `Resources/Info.plist`.
2. Add release notes to `CHANGELOG.md`.
3. Build and package the release artifacts:

```sh
make package-release
```

4. Confirm the generated files in `build/`:
   - `Strafe.app`
   - `Strafe-X.Y.Z-macos.zip`
   - `SHA256SUMS.txt`
5. Smoke-test the packaged app locally.
6. Commit the release changes.
7. Tag the release on `main`:

```sh
git tag vX.Y.Z
```

8. Push `main` and the tag.
9. Create a GitHub Release from the tag.
10. Attach the zip and checksum files from `build/`.
11. Paste release notes based on `CHANGELOG.md`.

## Release Notes Template

Use this structure for GitHub Releases:

- Summary of the release
- User-visible changes
- Known limitations
- First-run note for unsigned builds
- Permission note for Accessibility and Input Monitoring

## First-Run Note for Unsigned Builds

Current public preview assets are unsigned. macOS may block first launch. If that happens:

- right-click `Strafe.app`
- choose `Open`
- confirm the launch prompt

If the browser applied quarantine, the user may also need to remove quarantine manually before opening the app.
