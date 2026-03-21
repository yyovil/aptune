#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  echo "usage: $0 <formula-path> <tag>" >&2
  exit 1
fi

formula_path="$1"
tag_name="$2"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/aptune-formula-sync.XXXXXX")"
source_checkout="${work_dir}/source"
tap_remote="${work_dir}/tap-remote.git"
tap_checkout="${work_dir}/tap-checkout"

cleanup() {
  rm -rf "$work_dir"
}

trap cleanup EXIT

mkdir -p "${source_checkout}/Formula"
cp "$formula_path" "${source_checkout}/Formula/aptune.rb"

git init --bare "$tap_remote" >/dev/null
git clone "$tap_remote" "$tap_checkout" >/dev/null 2>&1
git -C "$tap_checkout" checkout -b main >/dev/null
printf '# tap\n' > "${tap_checkout}/README.md"
git -C "$tap_checkout" add README.md
git -C "$tap_checkout" -c user.name=test -c user.email=test@example.com commit -m init >/dev/null
git -C "$tap_checkout" push origin HEAD:main >/dev/null 2>&1

./scripts/sync-homebrew-formula.sh "$source_checkout" "$tap_checkout" "$tag_name" "main"
git --git-dir="$tap_remote" show main:Formula/aptune.rb >/dev/null
