#!/bin/bash
set -euo pipefail

output_path="${1:-}"
if [[ -z "$output_path" ]]; then
    echo "Usage: $0 <output-appcast-path>" >&2
    exit 64
fi

repository="${GITHUB_REPOSITORY:-}"
if [[ -z "$repository" || -z "${GH_TOKEN:-}" ]]; then
    echo "GITHUB_REPOSITORY and GH_TOKEN are required" >&2
    exit 1
fi

response_file="$(mktemp)"
trap 'rm -f "$response_file"' EXIT

api_request() {
    local url="$1"
    curl --silent --show-error --location \
        --output "$response_file" \
        --write-out '%{http_code}' \
        --header "Accept: application/vnd.github+json" \
        --header "Authorization: Bearer $GH_TOKEN" \
        --header "X-GitHub-Api-Version: 2022-11-28" \
        "$url"
}

contents_url="https://api.github.com/repos/$repository/contents/appcast.xml?ref=updates"
contents_status="$(api_request "$contents_url")"

case "$contents_status" in
    200)
        jq -r '.content' "$response_file" | tr -d '\n' | base64 --decode > "$output_path"
        xmllint --noout "$output_path"
        echo "Fetched existing signed appcast"
        ;;
    404)
        branch_url="https://api.github.com/repos/$repository/git/ref/heads/updates"
        branch_status="$(api_request "$branch_url")"
        if [[ "$branch_status" == "404" ]]; then
            rm -f "$output_path"
            echo "No updates branch exists; the first release will create the feed"
        elif [[ "$branch_status" == "200" ]]; then
            echo "The updates branch exists but appcast.xml is missing; refusing to discard feed history" >&2
            exit 1
        else
            echo "Could not verify updates branch (HTTP $branch_status)" >&2
            exit 1
        fi
        ;;
    *)
        echo "Could not fetch existing appcast (HTTP $contents_status)" >&2
        exit 1
        ;;
esac
