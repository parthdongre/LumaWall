# LumaWall macOS distribution

LumaWall can be used directly from SwiftPM during development, but normal users should install the app bundle.

## Release version

The root `VERSION` file is the default version for local packaging, CI artifacts, notarization, and verification. Update it together with `AppVersion.fallbackVersion`; the test suite enforces that they match.

Tagged public releases must use the same version as `VERSION`. A mismatched tag fails before signing or publishing.

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

## Development signing

Without an Apple Developer certificate, `package-macos.sh` applies an ad-hoc signature. This is useful for local development and CI smoke testing, but it is not the public release path and downloaded builds may trigger Gatekeeper warnings.

## Developer ID signing

Public releases use two separate Apple identities:

- **Developer ID Application** signs `LumaWall.app` and the DMG.
- **Developer ID Installer** signs the PKG.

If those identities already exist in the current keychain:

```bash
APP_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
PKG_SIGN_IDENTITY="Developer ID Installer: Your Name (TEAMID)" \
VERSION=0.4.0 \
./scripts/package-macos.sh
```

`SIGN_IDENTITY` remains accepted as a backward-compatible alias for the app-signing identity.

The app signature uses the hardened runtime and a trusted timestamp. The packaging script verifies the app signature before creating release containers.

## Notarization and stapling

After a Developer ID-signed package is created, run:

```bash
VERSION=0.4.0 \
NOTARY_KEY_FILE="/path/to/AuthKey_KEYID.p8" \
NOTARY_KEY_ID="KEYID" \
NOTARY_ISSUER_ID="ISSUER_UUID" \
./scripts/notarize-macos.sh
```

The script supports three authentication modes:

1. `NOTARY_KEYCHAIN_PROFILE` created with `notarytool store-credentials`;
2. App Store Connect API key variables: `NOTARY_KEY_FILE`, `NOTARY_KEY_ID`, and `NOTARY_ISSUER_ID`;
3. Apple ID variables: `APPLE_ID`, `APPLE_TEAM_ID`, and `APPLE_APP_PASSWORD`.

The notarization script submits the DMG and PKG with `xcrun notarytool --wait`, staples the returned tickets, validates both tickets, and then regenerates `SHA256SUMS.txt`.

Regenerating checksums **after stapling is required** because stapling modifies the release container bytes.

## Release verification

Run:

```bash
VERSION=0.4.0 ./scripts/verify-release.sh
```

Development builds verify the app signature and all SHA-256 entries.

For a public build:

```bash
VERSION=0.4.0 \
REQUIRE_DEVELOPER_ID=1 \
REQUIRE_NOTARIZED=1 \
./scripts/verify-release.sh
```

That additionally verifies Developer ID identities, validates stapled notarization tickets, and asks Gatekeeper to assess the DMG and PKG.

## GitHub Actions public-release policy

`.github/workflows/macos-build.yml` continues to produce ad-hoc signed CI artifacts for development and smoke testing.

`.github/workflows/release.yml` has two modes:

- **manual workflow dispatch**: development packaging, which may remain ad-hoc;
- **version tag such as `v0.4.0`**: public release, which now fails closed unless signing and notarization credentials are configured.

A tagged public release requires these GitHub Actions secrets:

```text
MACOS_CERTIFICATE_P12
MACOS_CERTIFICATE_PASSWORD
APP_SIGN_IDENTITY
PKG_SIGN_IDENTITY
NOTARY_PRIVATE_KEY
NOTARY_KEY_ID
NOTARY_ISSUER_ID
```

`MACOS_CERTIFICATE_P12` should contain the exported signing certificate/private-key material encoded as base64. `NOTARY_PRIVATE_KEY` is the App Store Connect `.p8` key contents.

The release workflow creates a temporary keychain on the runner, imports the signing identities, builds and signs the artifacts, notarizes and staples the DMG/PKG, verifies the result, uploads workflow artifacts, and only then publishes the GitHub Release.

If any public-release credential is missing, the tag workflow stops before publishing. This prevents accidentally shipping an ad-hoc or unnotarized build as an official LumaWall release.

## In-app update integrity

LumaWall's updater downloads the published `SHA256SUMS.txt` beside the DMG/PKG and verifies the selected installer before opening it.

Because notarization stapling changes the installer bytes, the release workflow always regenerates checksums after stapling. The checksum consumed by the app therefore matches the exact artifact users download.

## Wallpaper file association

The generated app bundle registers `.wall` as the LumaWall wallpaper-package type. Opening a `.wall` package in Finder sends it to the running app and imports it into the local wallpaper library.
