#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ] || [ "${3:-}" = "" ] || [ "${4:-}" = "" ]; then
  echo "usage: $0 <version> <system> <artifact-path> <sha256> [output-path]" >&2
  exit 1
fi

version="$1"
system="$2"
artifact_path="$3"
sha256="$4"
output_path="${5:-dist/release-manifest-${system}.env}"
artifact_name="$(basename "$artifact_path")"

mkdir -p "$(dirname "$output_path")"

cat > "$output_path" <<EOF
version=${version}
system=${system}
artifact_name=${artifact_name}
artifact_path=${artifact_path}
sha256=${sha256}
EOF
