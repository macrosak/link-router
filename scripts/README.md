# scripts/

Build, packaging, and dev tooling. Everything runs with Command Line Tools only (no Xcode).

## Build & ship

- **`bundle.sh`** — builds `Link Router.app` in the repo root via `swift build` + a hand-rolled bundle. Signs with `$LINKROUTER_SIGN_IDENTITY` (default `Link Router Dev`) if present, else ad-hoc. Honors `LINKROUTER_VERSION` (set by CI) for the Info.plist version.
- **`make-dmg.sh`** — wraps an existing `Link Router.app` into `LinkRouter-<version>-arm64.dmg` (drag-to-install layout). Run `bundle.sh` first.
- **`install.sh`** — killalls any running instance, copies the bundle to `~/Applications`, and launches it.
- **`test.sh`** — runs the test suite (adds the swift-testing search paths needed under CLT-only setups).
- **`../install.sh`** (repo root) — the end-user one-command installer: downloads the latest release DMG and installs it.

## Signing

- **`create-signing-identity.sh`** — creates a self-signed `Link Router Dev` certificate in the login keychain so signing stays stable across rebuilds and the Accessibility grant survives recompiles. One-time setup.

## App icon

- **`gen-icon.swift`** — renders the 1024×1024 source icon: `swift scripts/gen-icon.swift Sources/LinkRouter/Resources/icon.png`.
- **`make-icon.sh`** — turns that PNG into `AppIcon.icns` via `iconutil`.

## Dev / docs tooling

- **`debug.sh`** — drives a live `LINKROUTER_DEBUG=1` instance over distributed notifications: launch with an isolated config, send links, set the filter, press keys, dump state as JSON, render the picker / Settings to PNG. See the header comment for commands.
- **`screenshots.sh`** — re-records `docs/*.png` from `demo-config.json` (fake profiles, synthetic source — no real accounts in the repo).
