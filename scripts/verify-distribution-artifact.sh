#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <direct|app-store> <path-to-Chowser.app>" >&2
    exit 64
}

distribution="${1:-}"
app_path="${2:-}"

case "$distribution" in
    direct|app-store) ;;
    *) usage ;;
esac

if [[ -z "$app_path" || ! -d "$app_path" ]]; then
    echo "App bundle not found: $app_path" >&2
    exit 1
fi

info_plist="$app_path/Contents/Info.plist"
executable="$app_path/Contents/MacOS/Chowser"

if [[ ! -f "$info_plist" || ! -x "$executable" ]]; then
    echo "Incomplete Chowser app bundle: $app_path" >&2
    exit 1
fi

plist_value() {
    /usr/libexec/PlistBuddy -c "Print :$1" "$info_plist" 2>/dev/null
}

require_plist_value() {
    local key="$1"
    local value
    value="$(plist_value "$key")" || {
        echo "Missing Info.plist key: $key" >&2
        exit 1
    }
    if [[ -z "$value" ]]; then
        echo "Empty Info.plist key: $key" >&2
        exit 1
    fi
    printf '%s' "$value"
}

reject_plist_key() {
    local key="$1"
    if plist_value "$key" >/dev/null; then
        echo "Forbidden Info.plist key in $distribution build: $key" >&2
        exit 1
    fi
}

bundle_id="$(require_plist_value CFBundleIdentifier)"
version="$(require_plist_value CFBundleShortVersionString)"
build="$(require_plist_value CFBundleVersion)"
architectures="$(lipo -archs "$executable")"

if [[ "$bundle_id" != "in.sreerams.Chowser" ]]; then
    echo "Unexpected bundle identifier: $bundle_id" >&2
    exit 1
fi

if [[ ! "$build" =~ ^[0-9]+$ ]]; then
    echo "CFBundleVersion must be numeric for Sparkle ordering: $build" >&2
    exit 1
fi

for architecture in $architectures; do
    case "$architecture" in
        arm64|x86_64) ;;
        *)
            echo "Unsupported executable architecture: $architecture" >&2
            exit 1
            ;;
    esac
done

if [[ " $architectures " != *" arm64 "* ]]; then
    echo "Chowser must contain an arm64 executable slice: $architectures" >&2
    exit 1
fi

if [[ "${REQUIRE_UNIVERSAL:-0}" == "1" && " $architectures " != *" x86_64 "* ]]; then
    echo "Release artifact must contain both arm64 and x86_64 slices: $architectures" >&2
    exit 1
fi

sparkle_framework="$app_path/Contents/Frameworks/Sparkle.framework"

if [[ "$distribution" == "direct" ]]; then
    if [[ ! -d "$sparkle_framework" ]]; then
        echo "Direct build does not contain Sparkle.framework" >&2
        exit 1
    fi

    feed_url="$(require_plist_value SUFeedURL)"
    public_key="$(require_plist_value SUPublicEDKey)"
    require_signed_feed="$(require_plist_value SURequireSignedFeed)"
    verify_before_extraction="$(require_plist_value SUVerifyUpdateBeforeExtraction)"

    if [[ "$feed_url" != https://* || "$feed_url" == *'$('* ]]; then
        echo "Invalid Sparkle feed URL: $feed_url" >&2
        exit 1
    fi
    if [[ "$public_key" == *'$('* ]]; then
        echo "Unexpanded Sparkle public key" >&2
        exit 1
    fi
    if [[ "$require_signed_feed" != "true" ]]; then
        echo "SURequireSignedFeed must be true" >&2
        exit 1
    fi
    if [[ "$verify_before_extraction" != "true" ]]; then
        echo "SUVerifyUpdateBeforeExtraction must be true" >&2
        exit 1
    fi
    if [[ "${ALLOW_PLACEHOLDER_SPARKLE_KEY:-0}" != "1" && "$public_key" == "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=" ]]; then
        echo "Placeholder Sparkle public key is not allowed in a release artifact" >&2
        exit 1
    fi
else
    if [[ -e "$sparkle_framework" ]]; then
        echo "App Store build must not contain Sparkle.framework" >&2
        exit 1
    fi

    if find "$app_path/Contents" \
        \( -name 'Updater.app' -o -name 'Autoupdate' -o -name '*.xpc' \) \
        -print -quit | grep -q .; then
        echo "App Store build contains a bundled updater helper or XPC service" >&2
        exit 1
    fi

    for key in \
        SUFeedURL \
        SUPublicEDKey \
        SUEnableAutomaticChecks \
        SUAllowsAutomaticUpdates \
        SUAutomaticallyUpdate \
        SUScheduledCheckInterval \
        SUVerifyUpdateBeforeExtraction \
        SURequireSignedFeed; do
        reject_plist_key "$key"
    done

    if strings "$executable" | grep -E \
        'SUFeedURL|SPUUpdater|Sparkle|DIRECT_DISTRIBUTION|updates\.includeBetaReleases|sparkle-project|raw\.githubusercontent\.com|github\.com/.*/releases|Check for Updates' \
        >/dev/null; then
        echo "App Store executable contains direct-update implementation markers" >&2
        exit 1
    fi
fi

if codesign -d "$app_path" >/dev/null 2>&1 \
    && codesign --verify --deep --strict --verbose=2 "$app_path" >/dev/null 2>&1; then
    codesign --verify --deep --strict --verbose=2 "$app_path"
    signature_details="$(codesign -dvvv "$app_path" 2>&1)"
    if [[ "$signature_details" != *"flags="*"runtime"* && "$signature_details" != *"Runtime Version"* ]]; then
        echo "Signed release build does not enable the hardened runtime" >&2
        exit 1
    fi
    if [[ "${REQUIRE_DEVELOPER_ID:-0}" == "1" \
        && "$signature_details" != *"Authority=Developer ID Application:"* ]]; then
        echo "Direct release is not signed with a Developer ID Application certificate" >&2
        exit 1
    fi

    entitlements_file="$(mktemp)"
    trap 'rm -f "$entitlements_file"' EXIT
    codesign -d --entitlements :- "$app_path" >"$entitlements_file" 2>/dev/null

    sandbox_value="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.app-sandbox' "$entitlements_file" 2>/dev/null || true)"
    debug_entitlement="$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$entitlements_file" 2>/dev/null || true)"
    if [[ "$debug_entitlement" == "true" ]]; then
        echo "Release build must not contain the get-task-allow entitlement" >&2
        exit 1
    fi
    if [[ "$distribution" == "direct" && "$sandbox_value" == "true" ]]; then
        echo "Direct build must not be sandboxed" >&2
        exit 1
    fi
    if [[ "$distribution" == "app-store" && "$sandbox_value" != "true" ]]; then
        echo "App Store build must contain the app sandbox entitlement" >&2
        exit 1
    fi
elif [[ "${ALLOW_UNSIGNED:-0}" != "1" ]]; then
    echo "Unsigned or invalidly signed app bundle: $app_path" >&2
    exit 1
else
    echo "Warning: signature checks skipped for unsigned local artifact" >&2
fi

if [[ "${REQUIRE_NOTARIZATION:-0}" == "1" ]]; then
    xcrun stapler validate "$app_path"
    spctl --assess --type execute --verbose=2 "$app_path"
fi

echo "Verified $distribution Chowser $version ($build), architectures $architectures: $app_path"
