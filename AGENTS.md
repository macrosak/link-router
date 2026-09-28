# Link Router

macOS menu-bar app (LSUIElement) that registers as the default browser and routes each link to a
browser / Chromium profile — by rule, or via a keyboard-first picker. Sibling of
`../recallyx`: same look (theme tokens, panel chrome, settings chrome were ported from it), same
repo layout, scripts, and release workflow.

## Layout

- `Sources/LinkRouterCore` — pure logic, unit-tested: `BrowserTarget` (one browser, one
  profile, or a Chromium Incognito entry), `ChromiumProfiles` (reads `Local State`), `BrowserCatalog` (expand + merge detection
  into saved order/flags/custom names), `Rule` / `RuleMatcher`, `FuzzyMatcher`, `Config` (JSON),
  `ChromiumSingleton` (the fast hand-off).
- `Sources/LinkRouter` — AppKit/SwiftUI app: `AppDelegate` (GURL Apple-event handler → `route`),
  `SourceContext` (source app + AX window title), `Launcher`, `PickerController`/`PickerView`,
  `Settings*View`, `DebugHooks`.
- `Tests/LinkRouterTests` — swift-testing.
- `site/` — product page on GitHub Pages (`.github/workflows/pages.yml`); the screenshots come from
  `docs/` at deploy time. Preview with `./scripts/site.sh serve`.

## Key decisions

- **Speed:** for a running Chromium browser, `Launcher` writes
  `START\0<cwd>\0<argv…>` into `<user-data-dir>/SingletonSocket` (see
  `process_singleton_posix.cc`) → ~5 ms, vs seconds for spawning the browser binary / `open -na`.
  Then it activates the browser itself (macOS 14 cooperative activation: `yieldActivation` +
  `activate`, LaunchServices fallback).
- **Source app:** LaunchServices activates us before delivering the link and IDEs often use the
  short-lived `open` CLI (dead by the time we look), so `SourceContext` walks the sender's parent
  chain and falls back to the last non-self app that was active.
- Only apps handling both `https` and `public.html` are detected; other link pickers are
  deny-listed (`BrowserCatalog.excludedBundleIDs`).
- Rule without conditions never matches. ⌥ held at click time forces the picker.
- **Switching** (global hotkey, default ⌃⇧B, Carbon `RegisterEventHotKey` + click-to-record
  recorder ported from Recallyx — suspend the hotkey while recording): the picker without links.
  A Chromium profile is raised by pressing its item in the browser's **Profiles menu** via AX
  (`BrowserSwitcher`) — `--profile-directory` without a URL always opens a new window, and the AX
  window list only covers the current Space. Activate only after the profile's window is focused
  (its AX title ends with ` - <menu title>`), otherwise macOS switches to an older window's Space.

## Commands

```bash
swift test                        # or ./scripts/test.sh
./scripts/bundle.sh && ./scripts/install.sh
./scripts/debug.sh launch         # isolated debug instance; then: open <url> | query <t> | key <k> | state | shot <png>
```

Don't commit real Chrome profile data / avatars — docs screenshots come from
`scripts/screenshots.sh` + `scripts/demo-config.json`.

## Pull requests

- **Any UI change needs a screenshot in the PR.** If a PR changes what the picker, Settings, menu
  bar or any other UI looks like, the PR description must show it (before/after when something
  existing changed). Render it with `scripts/screenshots.sh` (README images, commit the updated
  `docs/*.png`) or `scripts/debug.sh shot <file.png>` for other states, always from the demo
  config (`scripts/demo-config.json`) so no real accounts or avatars get published. Put them in
  the description with `gh pr create/edit --attach './shot.png#alt text'` (gh ≥ 2.101): write
  `![alt](./shot.png)` in the body and gh uploads the file and rewrites the reference. Don't
  commit PR-only screenshots or push them to a side branch.
