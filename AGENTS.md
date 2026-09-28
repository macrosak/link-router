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
  config (`scripts/demo-config.json`) so no real accounts or avatars get published. Embed images
  pushed to the branch with
  `![…](https://github.com/macrosak/link-router/blob/<branch>/<path>?raw=true)`.
