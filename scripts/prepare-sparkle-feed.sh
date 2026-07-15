#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <version> <build-number> <release-directory>" >&2
    exit 64
}

version="${1:-}"
build_number="${2:-}"
release_dir="${3:-}"

[[ -n "$version" && -n "$build_number" && -d "$release_dir" ]] || usage

if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-beta\.[0-9]+)?$ ]]; then
    echo "Version must be stable semver or a numbered beta: $version" >&2
    exit 1
fi

if [[ ! "$build_number" =~ ^[0-9]+$ ]]; then
    echo "Build number must be numeric: $build_number" >&2
    exit 1
fi

repository="${GITHUB_REPOSITORY:-bsreeram08/chowser}"
tag="v$version"
archive_name="Chowser-$version.dmg"
notes_name="Chowser-$version.md"
archive_path="$release_dir/$archive_name"
notes_path="$release_dir/$notes_name"
appcast_path="$release_dir/appcast.xml"
generate_appcast="${SPARKLE_GENERATE_APPCAST:-}"

if [[ ! -f "$archive_path" || ! -f "$notes_path" ]]; then
    echo "Missing update archive or matching release notes in $release_dir" >&2
    exit 1
fi

if [[ -z "$generate_appcast" || ! -x "$generate_appcast" ]]; then
    echo "SPARKLE_GENERATE_APPCAST must point to Sparkle's generate_appcast tool" >&2
    exit 1
fi

if [[ -z "${SPARKLE_PRIVATE_KEY:-}" ]]; then
    echo "SPARKLE_PRIVATE_KEY is required to sign the archive and feed" >&2
    exit 1
fi

if [[ -f "$appcast_path" ]]; then
    xmllint --noout "$appcast_path"
    highest_existing_build="$(
        grep -Eo '<sparkle:version>[0-9]+</sparkle:version>' "$appcast_path" \
            | sed -E 's/.*>([0-9]+)<.*/\1/' \
            | sort -n \
            | tail -1 \
            || true
    )"

    if [[ -n "$highest_existing_build" && "$build_number" -lt "$highest_existing_build" ]]; then
        echo "Build $build_number is older than published appcast build $highest_existing_build" >&2
        exit 1
    fi

    if [[ -n "$highest_existing_build" && "$build_number" -eq "$highest_existing_build" ]] \
        && ! grep -Fq "<sparkle:shortVersionString>$version</sparkle:shortVersionString>" "$appcast_path"; then
        echo "Build $build_number is already used by a different published version" >&2
        exit 1
    fi
fi

download_prefix="https://github.com/$repository/releases/download/$tag/"
release_link="https://github.com/$repository/releases/tag/$tag"

arguments=(
    --ed-key-file -
    --download-url-prefix "$download_prefix"
    --embed-release-notes
    --link "$release_link"
    --versions "$build_number"
    --maximum-versions 10
    --maximum-deltas 0
    --disable-signing-warning
    -o "$appcast_path"
)

if [[ "$version" == *-beta.* ]]; then
    arguments+=(--channel beta)
else
    arguments+=(--phased-rollout-interval 86400)
fi

printf '%s' "$SPARKLE_PRIVATE_KEY" \
    | "$generate_appcast" "${arguments[@]}" "$release_dir"

xmllint --noout "$appcast_path"

expected_url="$download_prefix$archive_name"
item_xpath="//*[local-name()='item'][*[local-name()='version' and normalize-space(text())='$build_number'] and *[local-name()='shortVersionString' and normalize-space(text())='$version'] and *[local-name()='enclosure' and @url='$expected_url']]"
item_count="$(xmllint --xpath "count($item_xpath)" "$appcast_path")"
if [[ "$item_count" != "1" ]]; then
    echo "Generated appcast must contain exactly one current item for $version ($build_number) at $expected_url" >&2
    exit 1
fi

current_signature="$(xmllint --xpath "string(($item_xpath/*[local-name()='enclosure']/@*[local-name()='edSignature'])[1])" "$appcast_path")"
if [[ -z "$current_signature" ]]; then
    echo "Current enclosure is not signed; verify that SPARKLE_PRIVATE_KEY matches SUPublicEDKey" >&2
    exit 1
fi

current_length="$(xmllint --xpath "string(($item_xpath/*[local-name()='enclosure']/@length)[1])" "$appcast_path")"
archive_length="$(stat -f %z "$archive_path")"
if [[ ! "$current_length" =~ ^[0-9]+$ || "$current_length" != "$archive_length" ]]; then
    echo "Current enclosure length $current_length does not match archive length $archive_length" >&2
    exit 1
fi

if ! grep -Fq 'sparkle-signatures:' "$appcast_path"; then
    echo "Generated appcast is not signed" >&2
    exit 1
fi

current_channel="$(xmllint --xpath "string(($item_xpath/*[local-name()='channel'])[1])" "$appcast_path")"
if [[ "$version" == *-beta.* ]]; then
    if [[ "$current_channel" != "beta" ]]; then
        echo "Generated beta update is missing the beta channel on the current item" >&2
        exit 1
    fi
elif [[ -n "$current_channel" ]]; then
    echo "Generated stable update unexpectedly has channel $current_channel" >&2
    exit 1
fi

echo "Prepared signed Sparkle feed for $version ($build_number): $appcast_path"
