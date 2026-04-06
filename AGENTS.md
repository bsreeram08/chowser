# Repository Guidelines

**Chowser** is a macOS menu-bar app that intercepts HTTP/HTTPS links and routes them to configured browsers.

## Project Structure

```
Chowser/                    # Main app source (Swift/SwiftUI)
ChowserTests/               # Unit tests
ChowserUITests/             # UI tests
chowser-electrobun/         # Cross-platform Electron companion app
docs/                       # Documentation site (Vite + Bun)
scripts/                    # Build/release scripts
Chowser.xcodeproj/          # Xcode project
```

## Build & Test Commands

```bash
# Build the macOS app
xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build

# Run unit tests
xcodebuild test -project Chowser.xcodeproj -scheme Chowser -destination 'platform=macOS' -only-testing:ChowserTests

# Run UI tests
xcodebuild test -project Chowser.xcodeproj -scheme ChowserUITests -destination 'platform=macOS'

# App Store archive build
xcodebuild archive -project Chowser.xcodeproj -scheme Chowser -configuration Release \
  ENABLE_APP_SANDBOX=YES CODE_SIGN_ENTITLEMENTS=Chowser/ChowserAppStore.entitlements \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited) APP_STORE'
```

## Architecture

- **AppDelegate.swift** — Menu bar setup, Apple Event handler for URL interception, source-app tracking
- **BrowserManager.swift** — `@MainActor @Observable` singleton managing browsers, routing rules, and browser launching
- **ContentView.swift** — SwiftUI picker UI (hosted in `NSPanel` for full-screen app compatibility)
- **SettingsView.swift** — Settings window decomposed into extensions (`SettingsView+Browsers.swift`, `SettingsView+Rules.swift`, etc.)

## Coding Style

- Swift 6, iOS 18+, SwiftUI with AppKit interop
- Use `@MainActor @Observable` for state management (avoid `ObservableObject`)
- UserDefaults writes are **debounced at 0.3s** via `DispatchWorkItem` to avoid I/O stutter
- Settings window uses `NSWindowController` + `NSHostingController` (not SwiftUI `Settings` scene)
- Row views use local `@State` with commit-on-blur to avoid full-list re-renders

## Testing

- **Unit tests**: `ChowserTests` target; run with `-only-testing:ChowserTests`
- **UI tests**: `ChowserUITests` target; uses separate UserDefaults suite (`in.sreerams.Chowser.UITests`) for isolation
- Test flags via `AppEnvironment.swift` (e.g., `-UITesting`, `-UITesting_MockInstalledBrowsers`)

## Commit & PR Guidelines

Follow conventional commits:
- `ci:` — CI/CD changes
- `fix:` — Bug fixes
- `feat:` — New features
- `chore:` — Maintenance
- `docs:` — Documentation

Pull requests should include a description of changes and reference any related issues.

## Distribution

- **Direct download**: Hardened runtime, no sandbox (`Chowser.entitlements`)
- **App Store**: Sandboxed with `APP_STORE` compilation flag + `ChowserAppStore.entitlements`
- `#if APP_STORE` guards sandbox-incompatible code (Process-based browser launching)
