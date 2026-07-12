#!/bin/bash
set -euo pipefail

usage() {
    echo "Usage: $0 <version> <appcast-path>" >&2
    exit 64
}

version="${1:-}"
appcast_path="${2:-}"

[[ -n "$version" && -f "$appcast_path" ]] || usage

repository="${GITHUB_REPOSITORY:-}"
source_sha="${GITHUB_SHA:-}"
run_id="${GITHUB_RUN_ID:-manual}"

if [[ -z "$repository" || -z "$source_sha" || -z "${GH_TOKEN:-}" ]]; then
    echo "GITHUB_REPOSITORY, GITHUB_SHA, and GH_TOKEN are required" >&2
    exit 1
fi

if ! gh api "repos/$repository/git/ref/heads/updates" >/dev/null 2>&1; then
    gh api --method POST "repos/$repository/git/refs" \
        -f ref='refs/heads/updates' \
        -f sha="$source_sha" >/dev/null
fi

content="$(base64 < "$appcast_path" | tr -d '\n')"
existing_sha="$(gh api \
    "repos/$repository/contents/appcast.xml?ref=updates" \
    --jq .sha 2>/dev/null || true)"

arguments=(
    -f "message=release: update appcast for v$version"
    -f "content=$content"
    -f branch=updates
)
if [[ -n "$existing_sha" ]]; then
    arguments+=(-f "sha=$existing_sha")
fi

gh api --method PUT \
    "repos/$repository/contents/appcast.xml" \
    "${arguments[@]}" >/dev/null

published_appcast="$(mktemp)"
trap 'rm -f "$published_appcast"' EXIT
curl -fsSL --retry 3 \
    "https://raw.githubusercontent.com/$repository/updates/appcast.xml?run=$run_id" \
    -o "$published_appcast"
cmp "$appcast_path" "$published_appcast"

echo "Published signed appcast for $version to the updates branch"
