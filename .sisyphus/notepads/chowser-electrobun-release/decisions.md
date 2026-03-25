# Architectural Decisions

## Distribution Model
- Self-extracting archives only (no NSIS/MSI, no AppImage/deb)
- User accepted this constraint given Electrobun limitations

## Platform Support
- Windows 10+ (with legacy consideration, works with WebView2)
- All major Linux distros
- Keep existing macOS build working

## Source App Routing
- **DISABLED on Windows/Linux** due to reliability concerns
- macOS-only feature

## Design System
- CSS custom properties for tokens (no Tailwind - bundle size consideration)
- Glass effects with backdrop-filter fallbacks
- Support light/dark mode via prefers-color-scheme

---
