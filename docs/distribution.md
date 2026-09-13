# LumaWall macOS distribution

LumaWall can be used directly from SwiftPM during development, but normal users should install the app bundle.

## Build installable artifacts

From the repository root, verify the Apple developer toolchain first:

```bash
make doctor
```

Then package:

```bash
make package
```

or:

```bash
VERSION=0.4.0 ./scripts/package-macos.sh
```

The build writes:

```text
dist/
├── LumaWall.app
├── LumaWall-0.4.0-macOS.zip
├── LumaWall-0.4.0.dmg
├── LumaWall-0.4.0.pkg
└── SHA256SUMS.txt
```

The DMG contains LumaWall plus an Applications shortcut. The PKG installs the app into `/Applications`. The ZIP is useful for direct download/update systems.

## Local install

For a development machine:

```bash
make install
```

This packages the current source, copies LumaWall to `/Applications`, and opens it.

## Code signing

Without an Apple Developer certificate, `package-macos.sh` applies an ad-hoc signature. This is useful for development and private testing, but downloaded builds may still trigger Gatekeeper warnings.

If a Developer ID Application identity is already installed in the current keychain:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
VERSION=0.4.0 \
./scripts/package-macos.sh
```

The script then signs the app with the hardened runtime and timestamp.

## Notarization

For a public release distributed outside the Mac App Store, the recommended final pipeline is:

1. sign `LumaWall.app` with Developer ID Application;
2. package it into the DMG/ZIP;
3. submit the DMG or ZIP with `xcrun notarytool`;
4. wait for Apple approval;
5. staple the notarization ticket to the app/DMG;
6. publish checksums with the release.

The current repository intentionally does not hard-code developer credentials. When Developer ID credentials are available, the release workflow can import them from GitHub Actions secrets.

## GitHub Actions

`.github/workflows/macos-build.yml` now builds, tests, packages, and uploads installable artifacts for pushes to `main`.

`.github/workflows/release.yml` supports:

- versioned manual package builds via **Run workflow**;
- automatic GitHub Releases for tags such as `v0.4.0`.

A tag release publishes the ZIP, DMG, PKG, and SHA-256 checksum file.

## Wallpaper file association

The generated app bundle registers `.wall` as the LumaWall wallpaper-package type. Opening a `.wall` package in Finder sends it to the running app and imports it into the local wallpaper library.
