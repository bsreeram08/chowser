#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Chowser Release Script
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.3.0
# ─────────────────────────────────────────────

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "❌ Usage: $0 <version>"
    echo "   Example: $0 1.3.0"
    exit 1
fi

# Validate semver format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Version must be in semver format (e.g. 1.3.0)"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/Chowser.xcodeproj"
SCHEME="Chowser"
RELEASE_DIR="$PROJECT_DIR/release"
ARCHIVE_PATH="$RELEASE_DIR/Chowser.xcarchive"
APP_PATH="$RELEASE_DIR/Chowser.app"
DMG_PATH="$RELEASE_DIR/Chowser-${VERSION}.dmg"
SCRIPTS_DIR="$PROJECT_DIR/scripts"

echo "🧭 Chowser Release v${VERSION}"
echo "────────────────────────────────"

# ─── Step 1: Update version in Xcode project ───
echo "📝 Setting version to ${VERSION}..."
cd "$PROJECT_DIR"

sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${VERSION}/" "$PROJECT/project.pbxproj"

BUILD_NUMBER=$(date +%Y%m%d%H%M)
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER}/" "$PROJECT/project.pbxproj"

echo "   Version: ${VERSION} (build ${BUILD_NUMBER})"

# ─── Step 2: Build archive ───
echo "🔨 Building Release archive..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    CODE_SIGN_IDENTITY="Apple Development" \
    DEVELOPMENT_TEAM="DN4N8L7YL9" \
    -quiet

echo "   Archive created"

# ─── Step 3: Export app ───
echo "📦 Exporting app..."
cp -R "$ARCHIVE_PATH/Products/Applications/Chowser.app" "$APP_PATH"

# ─── Step 4: Generate DMG background ───
echo "🎨 Generating styled background..."
BG_PATH="$RELEASE_DIR/background.png"
swift "$SCRIPTS_DIR/generate-dmg-background.swift" "$BG_PATH"

# ─── Step 5: Create styled DMG ───
echo "💿 Creating DMG..."

STAGING_DIR="$RELEASE_DIR/dmg_staging"
VOLUME_NAME="Chowser ${VERSION}"
RW_DMG="$RELEASE_DIR/rw_temp.dmg"

# Create staging folder
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
mkdir -p "$STAGING_DIR/.background"
cp "$BG_PATH" "$STAGING_DIR/.background/background.png"

# Create read-write DMG
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "$RW_DMG"

rm -rf "$STAGING_DIR"

# Mount and style the DMG
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify "$RW_DMG")
DEVICE=$(echo "$MOUNT_OUTPUT" | grep '/dev/' | head -1 | awk '{print $1}')
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep '/Volumes/' | sed 's/.*\/Volumes/\/Volumes/')

echo "   Styling DMG window..."

# AppleScript to set window appearance
# We use label position of icons to right to avoid overlap with background labels
osascript <<EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set the bounds of container window to {200, 120, 860, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 100
        set label position of viewOptions to bottom
        set background picture of viewOptions to file ".background:background.png"
        set position of item "Chowser.app" of container window to {165, 190}
        set position of item "Applications" of container window to {495, 190}
        close
        open
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Set volume icon if available
if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    cp "$APP_PATH/Contents/Resources/AppIcon.icns" "$MOUNT_POINT/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
fi

sync
hdiutil detach "$DEVICE" -quiet

# Convert to compressed read-only DMG
rm -f "$DMG_PATH"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"
rm -f "$RW_DMG" "$BG_PATH"

if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo "   ✅ DMG created: $DMG_PATH (${DMG_SIZE})"
else
    echo "   ❌ DMG creation failed"
    exit 1
fi

# ─── Step 6: Clean up ───
rm -rf "$ARCHIVE_PATH" "$APP_PATH"

# ─── Step 7: Git tag ───
echo "🏷️  Creating git tag v${VERSION}..."

git add -A
git commit -m "release: v${VERSION}" --allow-empty
git tag -fa "v${VERSION}" -m "Chowser v${VERSION}"

echo ""
echo "════════════════════════════════════════"
echo "  ✅ Chowser v${VERSION} is ready!"
echo "────────────────────────────────────────"
echo "  DMG: $DMG_PATH"
echo "  Tag: v${VERSION}"
echo ""
echo "  To push and overwrite remote tags:"
echo "    git push origin main --tags --force"
echo ""
echo "  Upload $DMG_PATH to GitHub Releases"
echo "════════════════════════════════════════"
