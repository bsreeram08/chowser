#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: SPARKLE_PUBLIC_ED_KEY=<public-key> $0 <version>" >&2
    echo "Examples:" >&2
    echo "  SPARKLE_PUBLIC_ED_KEY=... $0 3.10.0" >&2
    echo "  SPARKLE_PUBLIC_ED_KEY=... $0 3.10.0-beta.1" >&2
    exit 64
}

version="${1:-}"
[[ -n "$version" ]] || usage

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]]; then
    echo "Version must be stable semver or a numbered beta: $version" >&2
    exit 1
fi

if [[ -z "${SPARKLE_PUBLIC_ED_KEY:-}" ]]; then
    echo "SPARKLE_PUBLIC_ED_KEY is required so the prepared direct build is update-capable" >&2
    exit 1
fi

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
project="$project_dir/Chowser.xcodeproj"
pbxproj="$project/project.pbxproj"
build_number="$(date +%Y%m%d%H%M)"

cd "$project_dir"

if [[ "${ALLOW_DIRTY:-0}" != "1" && -n "$(git status --short)" ]]; then
    echo "Working tree must be clean before preparing a release" >&2
    exit 1
fi

if ! rg -q "^## \[$version\]" CHANGELOG.md; then
    echo "Add a reviewed CHANGELOG.md section for $version before preparing the release" >&2
    exit 1
fi

if git show-ref --verify --quiet "refs/tags/v$version"; then
    echo "Tag v$version already exists locally" >&2
    exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/v$version" >/dev/null 2>&1; then
    echo "Tag v$version already exists on origin" >&2
    exit 1
fi

echo "Preparing Chowser $version ($build_number)"
sed -i '' "s/MARKETING_VERSION = [^;]*/MARKETING_VERSION = $version/g" "$pbxproj"
sed -i '' "s/CURRENT_PROJECT_VERSION = [^;]*/CURRENT_PROJECT_VERSION = $build_number/g" "$pbxproj"

derived_root="$(mktemp -d "${TMPDIR:-/tmp}/chowser-release.XXXXXX")"
trap 'rm -rf "$derived_root"' EXIT

xcodebuild test \
    -project "$project" \
    -scheme Chowser \
    -destination 'platform=macOS' \
    -derivedDataPath "$derived_root/tests" \
    -only-testing:ChowserTests \
    CODE_SIGNING_ALLOWED=NO \
    SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY"

xcodebuild build \
    -project "$project" \
    -scheme Chowser \
    -configuration Release \
    -derivedDataPath "$derived_root/direct" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO \
    SPARKLE_PUBLIC_ED_KEY="$SPARKLE_PUBLIC_ED_KEY"

xcodebuild build \
    -project "$project" \
    -scheme Chowser-AppStore \
    -configuration Release \
    -derivedDataPath "$derived_root/app-store" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY=- \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    DEVELOPMENT_TEAM=""

ALLOW_UNSIGNED=1 REQUIRE_UNIVERSAL=1 scripts/verify-distribution-artifact.sh \
    direct "$derived_root/direct/Build/Products/Release/Chowser.app"
REQUIRE_UNIVERSAL=1 scripts/verify-distribution-artifact.sh \
    app-store "$derived_root/app-store/Build/Products/Release/Chowser.app"

echo
echo "Release metadata prepared and both products verified."
echo "Review and commit the version/changelog change, merge it to main, then create:"
echo "  git tag -s v$version -m 'Chowser v$version'"
echo "  git push origin v$version"
echo
echo "The tag triggers the signed, notarized GitHub release workflow."
