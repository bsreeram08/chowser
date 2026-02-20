# Chowser — Distribution Guide

## Prerequisites

- macOS with Xcode installed
- An Apple Developer account (free or paid)
  - **Free account**: Can sign for local use only (your friends need to right-click → Open on first launch)
  - **Paid account ($99/yr)**: Can notarize, which removes all Gatekeeper warnings

## Option A: Simple Distribution (Free Account)

### 1. Build the Release App

```bash
# From the project root
xcodebuild -project Chowser.xcodeproj -scheme Chowser -configuration Release build
```

Or in Xcode: **Product → Archive → Distribute App → Copy App**

### 2. Create a DMG

```bash
# Install create-dmg (one time)
brew install create-dmg

# Create the DMG
create-dmg \
  --volname "Chowser" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Chowser.app" 150 200 \
  --app-drop-link 450 200 \
  "Chowser.dmg" \
  "path/to/Chowser.app"
```

### 3. Share with Friends

Send the DMG. They'll need to:
1. Open the DMG and drag Chowser to Applications
2. Right-click → Open (first time only — bypasses Gatekeeper)
3. Go to **System Settings → Desktop & Dock → Default Web Browser** → select Chowser

---

## Option B: Notarized Distribution (Paid Account)

### 1. Archive in Xcode

**Product → Archive → Distribute App → Developer ID → Upload**

### 2. Or Manual Notarization

```bash
# Create a ZIP of the app
ditto -c -k --keepParent "Chowser.app" "Chowser.zip"

# Submit for notarization
xcrun notarytool submit "Chowser.zip" \
  --apple-id "your@email.com" \
  --team-id "DN4N8L7YL9" \
  --password "app-specific-password" \
  --wait

# Staple the ticket
xcrun stapler staple "Chowser.app"

# Then create DMG as above
```

### 3. App-Specific Password

Generate one at [appleid.apple.com](https://appleid.apple.com) → Sign-In and Security → App-Specific Passwords.

---

## Setting Up as Default Browser

After installing, users should:
1. Open Chowser (it appears in the menu bar)
2. Click the menu bar icon → **Set as Default Browser**
3. Or go to **System Settings → Desktop & Dock → Default Web Browser → Chowser**

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "App is damaged" | Right-click → Open, or `xattr -cr Chowser.app` |
| Not appearing as browser option | Run once, then check System Settings |
| Menu bar icon missing | Check if app is running in Activity Monitor |
