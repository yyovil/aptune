#!/usr/bin/env bash

set -euo pipefail

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ] || [ "${3:-}" = "" ] || [ "${4:-}" = "" ]; then
  echo "usage: $0 <source-checkout> <tap-checkout> <tag> <default-branch>" >&2
  exit 1
fi

source_checkout="$1"
tap_checkout="$2"
tag_name="$3"
default_branch="$4"

mkdir -p "${tap_checkout}/Formula"
cp "${source_checkout}/Formula/aptune.rb" "${tap_checkout}/Formula/aptune.rb"

if [ -z "$(git -C "$tap_checkout" status --short -- Formula/aptune.rb)" ]; then
  echo "Formula already up to date."
  exit 0
fi

git -C "$tap_checkout" config user.name "github-actions[bot]"
git -C "$tap_checkout" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git -C "$tap_checkout" add Formula/aptune.rb
git -C "$tap_checkout" commit -m "chore: update Homebrew formula for ${tag_name}"
git -C "$tap_checkout" push origin HEAD:"${default_branch}"
