Task 44: README updated for Windows/Linux release

STATUS: COMPLETED

File: chowser-electrobun/README.md
Lines: 481 (was 168, +313 lines)

SECTIONS ADDED/UPDATED:
1. Title with Windows/Linux badges
2. "How It Works" section (platform-agnostic flow)
3. Comprehensive Features list (all platforms)
4. Updated Architecture diagram:
   - Added domainFrequency.ts
   - Added urlUtils.ts
   - Added platform.ts
   - Added mcpServer.ts
   - Cross-platform src/views structure with Svelte
5. Prerequisites for all platforms:
   - macOS (Bun, Xcode CLT)
   - Windows (Windows 10+, WebView2 Runtime)
   - Linux (WebKit2GTK, GTK 3.0+)
6. Getting Started:
   - npm run dev
   - npm run build / build:windows / build:linux
   - npm run package / package:windows / package:linux
   - npm run test / test:e2e
7. Setting as Default Browser (platform-specific):
   - macOS: System Settings → Default web browser
   - Windows: Settings → Apps → Default apps + registry auto-registration
   - Linux: xdg-settings manual + GUI option
8. Routing Rules section (updated with source-app note for macOS)
9. Browser Profiles section (cross-platform support)
10. Import/Export section (with JSON structure)
11. Domain Frequency Tracking section
12. URL Unshortening section
13. Clipboard URL section
14. MCP Server section (REST API endpoints with examples)
15. Platform-Specific Configuration Paths:
    - macOS: ~/Library/Application Support/...
    - Windows: %APPDATA%\...
    - Linux: ~/.config/...
16. Launch at Login paths (LaunchAgent, Registry, Desktop file)
17. Known Limitations section:
    - Shift-to-force-picker unavailable (all platforms)
    - Source-app routing disabled on Windows/Linux
    - Launch at login preference-only
18. Picker Keyboard Shortcuts table
19. Testing section (unit, E2E, type checking)
20. Regression Checklist (with platform-specific builds)
21. Differences table updated:
    - Added "macOS, Windows, Linux" for Electrobun
    - Marked Swift as "macOS only"
    - Marked Tauri as "Tauri (Rust)" (cross-platform capable)
    - Added parity metrics: source-app routing, bundle size, startup time
22. Support & Contributing section

ALL REQUIREMENTS MET:
✓ Full Windows 10+ installation coverage
✓ Full Linux (Ubuntu/Fedora/Arch) installation coverage
✓ All features documented: picker, rules, profiles, private mode, settings, onboarding, domain frequency, URL unshortening, clipboard URL, MCP server, launch-at-login, default browser registration
✓ Updated architecture diagram with Svelte, domainFrequency.ts, platform.ts, browserLauncher.ts
✓ Differences table updated to show Windows/Linux support
✓ Platform-specific paths documented
✓ Known limitations updated with Windows/Linux notes
✓ Regression checklist includes platform-specific builds
✓ No placeholder content — all sections are real and accurate
✓ Feature parity coverage
✓ Keyboard shortcuts table
✓ MCP Server REST API documentation
✓ Testing instructions
✓ Line count: 481 (well above 150 minimum)
