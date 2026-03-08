#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

version="${1:-0.2.0}"
system="${2:-$(nix eval --impure --raw --expr 'builtins.currentSystem')}"
artifact_name="aptune-${version}-${system}"
artifact_path="dist/${artifact_name}.tar.gz"

nix build ".#packages.${system}.aptune"
out_path="$(nix path-info ".#packages.${system}.aptune")"

rm -rf dist
mkdir -p dist/stage
cp "$out_path/bin/aptune" dist/stage/aptune
cp -R "$out_path/bin/Aptune_VAD.bundle" dist/stage/Aptune_VAD.bundle

tar -C dist/stage -czf "$artifact_path" .
sha256="$(shasum -a 256 "$artifact_path" | awk '{print $1}')"

rm -rf dist/stage

cat <<EOF
artifact: $artifact_path
sha256:   $sha256

Homebrew formula URL:
https://github.com/yyovil/aptune/releases/download/v${version}/${artifact_name}.tar.gz
EOF
