#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Chowser Release Script
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 3.1.0
#
# Environment variables (CI overrides):
#   CODE_SIGN_IDENTITY    - Signing identity (default: "Developer ID Application")
#   CODE_SIGNING_ALLOWED  - "YES" or "NO" (default: "YES")
#   NOTARIZE              - "YES" to notarize after build (default: "NO")
#   APPLE_ID              - Apple ID for notarization
#   APPLE_ID_PASSWORD     - App-specific password for notarization
#   APPLE_TEAM_ID         - Team ID for notarization
# ─────────────────────────────────────────────

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version>"
    echo "   Example: $0 3.1.0"
    exit 1
fi

# Validate semver format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]]; then
    echo "Version must be in semver format (e.g. 3.1.0 or 2.12.0-beta.1)"
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

echo "Chowser Release v${VERSION}"
echo "────────────────────────────────"

# ─── Step 1: Update version in Xcode project ───
echo "Setting version to ${VERSION}..."
cd "$PROJECT_DIR"

sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${VERSION}/" "$PROJECT/project.pbxproj"

BUILD_NUMBER=$(date +%Y%m%d%H%M)
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER}/" "$PROJECT/project.pbxproj"

echo "   Version: ${VERSION} (build ${BUILD_NUMBER})"

# ─── Step 2: Build archive ───
echo "Building Release archive..."
rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

# Signing: CI uses Developer ID (set via env), local defaults to unsigned
if [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
    SIGN_ARGS=(CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY" DEVELOPMENT_TEAM="TH2VPAUX6Y")
else
    # Local build — disable signing to avoid cert conflicts
    SIGN_ARGS=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=-)
fi

xcodebuild archive \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    "${SIGN_ARGS[@]}" \
    -quiet

echo "   Archive created"

# ─── Step 3: Export app ───
echo "Exporting app..."
cp -R "$ARCHIVE_PATH/Products/Applications/Chowser.app" "$APP_PATH"

# ─── Step 4: Notarize (if enabled) ───
SHOULD_NOTARIZE="${NOTARIZE:-NO}"
if [ "$SHOULD_NOTARIZE" = "YES" ]; then
    echo "Notarizing app..."
    NOTARY_APPLE_ID="${APPLE_ID:-}"
    NOTARY_PASSWORD="${APPLE_ID_PASSWORD:-}"
    NOTARY_TEAM_ID="${APPLE_TEAM_ID:-TH2VPAUX6Y}"

    if [ -z "$NOTARY_APPLE_ID" ] || [ -z "$NOTARY_PASSWORD" ]; then
        echo "   APPLE_ID and APPLE_ID_PASSWORD required for notarization"
        exit 1
    fi

    # Create a ZIP for notarization
    ditto -c -k --keepParent "$APP_PATH" "$RELEASE_DIR/Chowser-notarize.zip"

    xcrun notarytool submit "$RELEASE_DIR/Chowser-notarize.zip" \
        --apple-id "$NOTARY_APPLE_ID" \
        --team-id "$NOTARY_TEAM_ID" \
        --password "$NOTARY_PASSWORD" \
        --wait

    xcrun stapler staple "$APP_PATH"
    rm -f "$RELEASE_DIR/Chowser-notarize.zip"
    echo "   Notarization complete"
fi

# ─── Step 5: Generate DMG background ───
echo "Generating styled background..."
BG_PATH="$RELEASE_DIR/background.png"
swift "$SCRIPTS_DIR/generate-dmg-background.swift" "$BG_PATH"

# ─── Step 6: Create styled DMG ───
echo "Creating DMG..."

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
    echo "   DMG created: $DMG_PATH (${DMG_SIZE})"
else
    echo "   DMG creation failed"
    exit 1
fi

# ─── Step 7: Notarize DMG (if enabled) ───
if [ "$SHOULD_NOTARIZE" = "YES" ]; then
    echo "Notarizing DMG..."
    xcrun notarytool submit "$DMG_PATH" \
        --apple-id "$NOTARY_APPLE_ID" \
        --team-id "$NOTARY_TEAM_ID" \
        --password "$NOTARY_PASSWORD" \
        --wait

    xcrun stapler staple "$DMG_PATH"
    echo "   DMG notarization complete"
fi

# ─── Step 8: Clean up ───
rm -rf "$ARCHIVE_PATH" "$APP_PATH"

# ─── Step 10: Git tag ───
echo "Creating git tag v${VERSION}..."

git add -A
git commit -m "release: v${VERSION}" --allow-empty
git tag -fa "v${VERSION}" -m "Chowser v${VERSION}"

echo ""
echo "========================================"
echo "  Chowser v${VERSION} is ready!"
echo "────────────────────────────────────────"
echo "  DMG: $DMG_PATH"
echo "  Tag: v${VERSION}"
echo ""
echo "  To push and trigger release:"
echo "    git push origin main --tags"
echo ""
echo "  Upload $DMG_PATH to GitHub Releases"
echo "========================================"
