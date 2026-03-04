#!/bin/bash
# Chowser App Store Screenshot Generator
# Usage: ./scripts/take-screenshots.sh
# Saves screenshots to ~/Desktop/Chowser-Screenshots/
set -euo pipefail

BUNDLE_ID="in.sreerams.Chowser"
OUTPUT_DIR="$HOME/Desktop/Chowser-Screenshots"
APP_PATH=$(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null | head -1)
[ -z "$APP_PATH" ] && APP_PATH="/Applications/Chowser.app"

mkdir -p "$OUTPUT_DIR"
echo "Chowser Screenshot Generator → $OUTPUT_DIR"
echo "────────────────────────────────────────────"

# ─── Kill any running Chowser ───
echo "Stopping Chowser..."
killall Chowser 2>/dev/null || true
sleep 1

# ─── Seed demo data ───
echo "Seeding demo data..."

python3 << 'PYEOF'
import subprocess, json

BUNDLE_ID = "in.sreerams.Chowser"

browsers = [
    {"id": "11111111-0000-0000-0000-000000000001", "name": "Safari",   "bundleId": "com.apple.Safari",               "shortcutKey": "1"},
    {"id": "11111111-0000-0000-0000-000000000002", "name": "Chrome",   "bundleId": "com.google.Chrome",              "shortcutKey": "2"},
    {"id": "11111111-0000-0000-0000-000000000003", "name": "Firefox",  "bundleId": "org.mozilla.firefox",            "shortcutKey": "3"},
    {"id": "11111111-0000-0000-0000-000000000004", "name": "Arc",      "bundleId": "company.thebrowser.Browser",     "shortcutKey": "4"},
]

rules = [
    {"id": "22222222-0000-0000-0000-000000000001", "name": "GitHub",          "hostPattern": "github.com",            "browserBundleId": "com.google.Chrome",          "isEnabled": True,  "usePrivateMode": False, "useRegex": False},
    {"id": "22222222-0000-0000-0000-000000000002", "name": "Google Workspace","hostPattern": "*.google.com",          "browserBundleId": "com.google.Chrome",          "isEnabled": True,  "usePrivateMode": False, "useRegex": False},
    {"id": "22222222-0000-0000-0000-000000000003", "name": "Work Slack",      "hostPattern": "mycompany.slack.com",   "browserBundleId": "org.mozilla.firefox",        "isEnabled": True,  "usePrivateMode": False, "useRegex": False},
    {"id": "22222222-0000-0000-0000-000000000004", "name": "Apple Developer", "hostPattern": "developer.apple.com",  "browserBundleId": "com.apple.Safari",           "isEnabled": True,  "usePrivateMode": False, "useRegex": False},
    {"id": "22222222-0000-0000-0000-000000000005", "name": "YouTube Private", "hostPattern": "youtube.com",          "browserBundleId": "company.thebrowser.Browser", "isEnabled": True,  "usePrivateMode": True,  "useRegex": False},
]

def write_data(bid, key, obj):
    hex_data = json.dumps(obj, separators=(',', ':')).encode('utf-8').hex()
    subprocess.run(['defaults', 'write', bid, key, '-data', hex_data], check=True)

write_data(BUNDLE_ID, 'configuredBrowsers', browsers)
write_data(BUNDLE_ID, 'routingRules', rules)
subprocess.run(['defaults', 'write', BUNDLE_ID, 'onboardingCompleted', '-bool', 'YES'], check=True)
print("   Demo data written")
PYEOF

# ─── Helper: capture frontmost Chowser window ───
capture_chowser() {
    local output="$1"
    local wait="${2:-0.5}"
    sleep "$wait"
    WINDOW_ID=$(swift - << 'SWEOF'
import Cocoa
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as! [[String: Any]]
for w in list {
    if let owner = w["kCGWindowOwnerName"] as? String, owner.lowercased().contains("chowser") {
        if let wid = w["kCGWindowNumber"] as? Int, wid > 0 { print(wid); break }
    }
}
SWEOF
    )
    if [ -n "$WINDOW_ID" ]; then
        screencapture -l "$WINDOW_ID" -o "$output"
        echo "   Saved: $(basename "$output")"
    else
        echo "   Warning: no Chowser window found"
    fi
}

# ─── Launch Chowser ───
echo "Launching Chowser..."
open "$APP_PATH"
sleep 2

# Screenshot 1: Picker
echo "1/5 Browser Picker..."
open "https://github.com/apple/swift"
sleep 2
capture_chowser "$OUTPUT_DIR/01-BrowserPicker.png" 0.5

# Screenshot 2: Settings – Browsers
echo "2/5 Settings – Browsers..."
osascript << 'ASEOF'
tell application "System Events"
    tell process "Chowser"
        set frontmost to true
        keystroke "," using command down
    end tell
end tell
ASEOF
sleep 1.5
capture_chowser "$OUTPUT_DIR/02-Browsers.png" 0.3

# Screenshot 3: Settings – Rules
echo "3/5 Settings – Rules..."
osascript << 'ASEOF'
tell application "System Events"
    tell process "Chowser"
        keystroke "2" using {command down, shift down}
    end tell
end tell
ASEOF
sleep 1
capture_chowser "$OUTPUT_DIR/03-Rules.png" 0.3

# Screenshot 4: Settings – General
echo "4/5 Settings – General..."
osascript << 'ASEOF'
tell application "System Events"
    tell process "Chowser"
        keystroke "3" using {command down, shift down}
    end tell
end tell
ASEOF
sleep 1
capture_chowser "$OUTPUT_DIR/04-General.png" 0.3

# Screenshot 5: Picker (second URL)
echo "5/5 Picker (second URL)..."
open "https://developer.apple.com/swift"
sleep 1.5
capture_chowser "$OUTPUT_DIR/05-Picker2.png" 0.3

echo ""
echo "Done! Opening folder..."
open "$OUTPUT_DIR"
