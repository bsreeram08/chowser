#!/bin/bash
# ─────────────────────────────────────────────
# Chowser App Store Screenshot Generator
# Usage: ./scripts/take-screenshots.sh
#
# Saves screenshots to ~/Desktop/Chowser-Screenshots/
# ─────────────────────────────────────────────
set -euo pipefail

BUNDLE_ID="in.sreerams.Chowser"
OUTPUT_DIR="$HOME/Desktop/Chowser-Screenshots"
APP_PATH=$(mdfind "kMDItemCFBundleIdentifier == '$BUNDLE_ID'" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
    APP_PATH="/Applications/Chowser.app"
fi

mkdir -p "$OUTPUT_DIR"
echo "Chowser Screenshot Generator"
echo "Output: $OUTPUT_DIR"
echo "────────────────────────────"

# ─── Step 1: Kill any running Chowser ───
echo "Stopping any running Chowser..."
killall Chowser 2>/dev/null || true
sleep 1

# ─── Step 2: Seed demo data into UserDefaults ───
echo "Seeding demo data..."

# Demo browsers JSON
BROWSERS_JSON='[
  {"id":"11111111-0000-0000-0000-000000000001","name":"Safari","bundleId":"com.apple.Safari","shortcutKey":"1"},
  {"id":"11111111-0000-0000-0000-000000000002","name":"Chrome","bundleId":"com.google.Chrome","shortcutKey":"2"},
  {"id":"11111111-0000-0000-0000-000000000003","name":"Firefox","bundleId":"org.mozilla.firefox","shortcutKey":"3"},
  {"id":"11111111-0000-0000-0000-000000000004","name":"Arc","bundleId":"company.thebrowser.Browser","shortcutKey":"4"}
]'

# Demo routing rules JSON
RULES_JSON='[
  {"id":"22222222-0000-0000-0000-000000000001","name":"GitHub","hostPattern":"github.com","browserBundleId":"com.google.Chrome","isEnabled":true,"usePrivateMode":false,"useRegex":false},
  {"id":"22222222-0000-0000-0000-000000000002","name":"Google Workspace","hostPattern":"*.google.com","browserBundleId":"com.google.Chrome","isEnabled":true,"usePrivateMode":false,"useRegex":false},
  {"id":"22222222-0000-0000-0000-000000000003","name":"Work Slack","hostPattern":"mycompany.slack.com","browserBundleId":"org.mozilla.firefox","isEnabled":true,"usePrivateMode":false,"useRegex":false},
  {"id":"22222222-0000-0000-0000-000000000004","name":"Apple Developer","hostPattern":"developer.apple.com","browserBundleId":"com.apple.Safari","isEnabled":true,"usePrivateMode":false,"useRegex":false},
  {"id":"22222222-0000-0000-0000-000000000005","name":"YouTube (Private)","hostPattern":"youtube.com","browserBundleId":"company.thebrowser.Browser","isEnabled":true,"usePrivateMode":true,"useRegex":false}
]'

# Write demo data via python
python3 - <<PYEOF
import subprocess, json

BUNDLE_ID = "$BUNDLE_ID"

browsers = $BROWSERS_JSON
rules = $RULES_JSON

def write_data_key(bundle_id, key, obj):
    """Write a JSON-encoded object as Data to UserDefaults (matches Swift JSONDecoder reads)."""
    hex_data = json.dumps(obj, separators=(',', ':')).encode('utf-8').hex()
    subprocess.run(['defaults', 'write', bundle_id, key, '-data', hex_data], check=True)

write_data_key(BUNDLE_ID, 'configuredBrowsers', browsers)
write_data_key(BUNDLE_ID, 'routingRules', rules)
subprocess.run(['defaults', 'write', BUNDLE_ID, 'onboardingCompleted', '-bool', 'YES'], check=True)
print("Demo data written to UserDefaults")
PYEOF

# ─── Helper: capture window by name ───
capture_window() {
    local window_name="$1"
    local output_file="$2"
    local delay="${3:-0.5}"

    sleep "$delay"

    # Get CGWindowID via quartz window list
    WINDOW_ID=$(python3 - "$window_name" <<'PYEOF'
import sys, subprocess, Quartz

target = sys.argv[1].lower()
window_list = Quartz.CGWindowListCopyWindowInfo(
    Quartz.kCGWindowListOptionOnScreenOnly | Quartz.kCGWindowListExcludeDesktopElements,
    Quartz.kCGNullWindowID
)
for w in window_list:
    owner = (w.get('kCGWindowOwnerName') or '').lower()
    name = (w.get('kCGWindowName') or '').lower()
    if 'chowser' in owner:
        wid = w.get('kCGWindowNumber', 0)
        if wid > 0:
            print(wid)
            break
PYEOF
    )

    if [ -n "$WINDOW_ID" ]; then
        screencapture -l "$WINDOW_ID" -o "$output_file"
        echo "   Saved: $output_file"
    else
        echo "   Warning: Could not find Chowser window, falling back to screen capture"
        screencapture -R "0,0,1440,900" "$output_file"
    fi
}

# ─── Step 3: Launch Chowser ───
echo "Launching Chowser..."
open -a "$APP_PATH"
sleep 2

# ─── Screenshot 1: Browser Picker ───
echo "Screenshot 1: Browser Picker..."
open "https://github.com/apple/swift"
sleep 2
capture_window "Chowser" "$OUTPUT_DIR/01-BrowserPicker.png" 0.5

# ─── Screenshot 2: Settings – Browsers ───
echo "Screenshot 2: Settings – Browsers..."
# Open settings via menu bar (Cmd+,)
osascript <<'ASEOF'
tell application "System Events"
    tell process "Chowser"
        set frontmost to true
        keystroke "," using command down
    end tell
end tell
ASEOF
sleep 1.5
capture_window "Chowser" "$OUTPUT_DIR/02-BrowserSettings.png" 0.3

# ─── Screenshot 3: Settings – Rules ───
echo "Screenshot 3: Settings – Routing Rules..."
osascript <<'ASEOF'
tell application "System Events"
    tell process "Chowser"
        -- Click the Rules sidebar item
        set rulesItem to first UI element of group 1 of splitter group 1 of window 1 whose description contains "Rules" or name contains "Rules"
        click rulesItem
    end tell
end tell
ASEOF
sleep 1
capture_window "Chowser" "$OUTPUT_DIR/03-RoutingRules.png" 0.3

# ─── Screenshot 4: Settings – General ───
echo "Screenshot 4: Settings – General..."
osascript <<'ASEOF'
tell application "System Events"
    tell process "Chowser"
        set generalItem to first UI element of group 1 of splitter group 1 of window 1 whose description contains "General" or name contains "General"
        click generalItem
    end tell
end tell
ASEOF
sleep 1
capture_window "Chowser" "$OUTPUT_DIR/04-GeneralSettings.png" 0.3

# ─── Screenshot 5: Picker (close up – trigger second URL) ───
echo "Screenshot 5: Picker with URL..."
open "https://developer.apple.com/swift"
sleep 1.5
capture_window "Chowser" "$OUTPUT_DIR/05-PickerWithURL.png" 0.3

echo ""
echo "========================================"
echo "  Screenshots saved to:"
echo "  $OUTPUT_DIR"
echo "========================================"
open "$OUTPUT_DIR"
