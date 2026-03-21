#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ] || [ "${3:-}" = "" ]; then
  echo "usage: $0 <tag> <arm64-sha256> <x86_64-sha256> [output-path]" >&2
  exit 1
fi

tag_name="$1"
arm64_sha256="$2"
x86_64_sha256="$3"
output_path="${4:-dist/release-notes.md}"
repo_slug="${APTUNE_GITHUB_REPO:-${GITHUB_REPOSITORY:-}}"

if [ -z "$repo_slug" ]; then
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  repo_slug="$(printf '%s\n' "$origin_url" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
fi

if [ -z "$repo_slug" ]; then
  repo_slug="yyovil/aptune"
fi

repo_owner="${repo_slug%%/*}"
version="${tag_name#v}"
arm64_asset="aptune-${version}-aarch64-darwin.tar.gz"
x86_64_asset="aptune-${version}-x86_64-darwin.tar.gz"

mkdir -p "$(dirname "$output_path")"

cat > "$output_path" <<EOF
aptune ${tag_name} release

Direct downloads:
- Apple Silicon: [${arm64_asset}](https://github.com/${repo_slug}/releases/download/${tag_name}/${arm64_asset})
- Intel: [${x86_64_asset}](https://github.com/${repo_slug}/releases/download/${tag_name}/${x86_64_asset})

SHA256:
- Apple Silicon: \`${arm64_sha256}\`
- Intel: \`${x86_64_sha256}\`

Install with Nix:
\`nix profile install github:${repo_slug}#aptune\`

Install with Homebrew:
\`brew tap ${repo_owner}/aptune https://github.com/${repo_slug}\`
\`brew install aptune\`
EOF
