#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "${1:-}" = "" ]; then
  echo "usage: $0 <tag>" >&2
  exit 1
fi

tag_name="$1"
tag_version="${tag_name#v}"
source_version="$(sed -n 's/.*current = "v\([^"]*\)".*/\1/p' Sources/CLI/AptuneConfig.swift | head -n 1)"

if [ -z "$source_version" ]; then
  echo "Unable to read CLI version from Sources/CLI/AptuneConfig.swift" >&2
  exit 1
fi

if [ "$source_version" != "$tag_version" ]; then
  echo "Tag ${tag_name} does not match CLI version v${source_version}" >&2
  exit 1
fi
