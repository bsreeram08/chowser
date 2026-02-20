#!/bin/bash
set -euo pipefail

# ─────────────────────────────────────────────
# Chowser Release Script
# Usage: ./scripts/release.sh <version>
# Example: ./scripts/release.sh 1.0.0
# ─────────────────────────────────────────────

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    echo "❌ Usage: $0 <version>"
    echo "   Example: $0 1.0.0"
    exit 1
fi

# Validate semver format
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Version must be in semver format (e.g. 1.0.0)"
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$PROJECT_DIR/Chowser.xcodeproj"
SCHEME="Chowser"
RELEASE_DIR="$PROJECT_DIR/release"
ARCHIVE_PATH="$RELEASE_DIR/Chowser.xcarchive"
APP_PATH="$RELEASE_DIR/Chowser.app"
DMG_PATH="$RELEASE_DIR/Chowser-${VERSION}.dmg"

echo "🧭 Chowser Release v${VERSION}"
echo "────────────────────────────────"

# ─── Step 1: Update version in Xcode project ───
echo "📝 Setting version to ${VERSION}..."
cd "$PROJECT_DIR"

# Update MARKETING_VERSION in pbxproj
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = ${VERSION}/" "$PROJECT/project.pbxproj"

# Increment build number (use timestamp for uniqueness)
BUILD_NUMBER=$(date +%Y%m%d%H%M)
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = ${BUILD_NUMBER}/" "$PROJECT/project.pbxproj"

echo "   Version: ${VERSION} (build ${BUILD_NUMBER})"

# ─── Step 2: Clean and build archive ───
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

echo "   Archive created at $ARCHIVE_PATH"

# ─── Step 3: Export the app ───
echo "📦 Exporting app..."
cp -R "$ARCHIVE_PATH/Products/Applications/Chowser.app" "$APP_PATH"
echo "   App exported to $APP_PATH"

# ─── Step 4: Create DMG using hdiutil ───
echo "💿 Creating DMG..."

STAGING_DIR="$RELEASE_DIR/dmg_staging"
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "Chowser ${VERSION}" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

rm -rf "$STAGING_DIR"

if [ -f "$DMG_PATH" ]; then
    DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
    echo "   ✅ DMG created: $DMG_PATH (${DMG_SIZE})"
else
    echo "   ❌ DMG creation failed"
    exit 1
fi

# ─── Step 5: Clean up ───
rm -rf "$ARCHIVE_PATH" "$APP_PATH"

# ─── Step 6: Git tag ───
echo "🏷️  Creating git tag v${VERSION}..."

git add -A
git commit -m "release: v${VERSION}" --allow-empty
git tag -a "v${VERSION}" -m "Chowser v${VERSION}"

echo ""
echo "════════════════════════════════════════"
echo "  ✅ Chowser v${VERSION} is ready!"
echo "────────────────────────────────────────"
echo "  DMG: $DMG_PATH"
echo "  Tag: v${VERSION}"
echo ""
echo "  Next steps:"
echo "    git push origin main --tags"
echo "    Upload $DMG_PATH to GitHub Releases"
echo "════════════════════════════════════════"
