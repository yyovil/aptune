#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "${1:-}" = "" ]; then
  echo "usage: $0 <tag>" >&2
  exit 1
fi

tag_name="$1"
version="${tag_name#v}"
local_formula_path="dist/local-aptune.rb"
release_formula_path="dist/aptune.rb"
native_system="$(
  case "$(/usr/bin/uname -m)" in
    arm64) echo "aarch64-darwin" ;;
    x86_64) echo "x86_64-darwin" ;;
    *)
      echo "error: unsupported macOS architecture '$(/usr/bin/uname -m)'" >&2
      exit 1
      ;;
  esac
)"
alternate_system="aarch64-darwin"

if [ "$native_system" = "aarch64-darwin" ]; then
  alternate_system="x86_64-darwin"
fi

./scripts/verify-release-tag.sh "$tag_name"
./scripts/test.sh
./scripts/create-release-artifact.sh "$version" "$native_system"

native_artifact_path="dist/aptune-${version}-${native_system}.tar.gz"
if [ ! -f "$native_artifact_path" ]; then
  echo "error: release artifact was not created" >&2
  exit 1
fi

alternate_artifact_path="dist/aptune-${version}-${alternate_system}.tar.gz"
cp "$native_artifact_path" "$alternate_artifact_path"

native_sha256="$(shasum -a 256 "$native_artifact_path" | awk '{print $1}')"
alternate_sha256="$(shasum -a 256 "$alternate_artifact_path" | awk '{print $1}')"

./scripts/write-release-manifest.sh "$version" "$native_system" "$native_artifact_path" "$native_sha256" "dist/release-manifest-${native_system}.env"
./scripts/write-release-manifest.sh "$version" "$alternate_system" "$alternate_artifact_path" "$alternate_sha256" "dist/release-manifest-${alternate_system}.env"
./scripts/collect-release-artifacts.sh "dist"

arm64_sha256="$native_sha256"
x86_64_sha256="$alternate_sha256"
arm64_artifact_name="aptune-${version}-aarch64-darwin.tar.gz"
x86_64_artifact_name="aptune-${version}-x86_64-darwin.tar.gz"

if [ "$native_system" = "x86_64-darwin" ]; then
  arm64_sha256="$alternate_sha256"
  x86_64_sha256="$native_sha256"
fi

./scripts/update-homebrew-formula.sh "$version" "$arm64_sha256" "$x86_64_sha256" "$local_formula_path" "$release_formula_path"
./scripts/write-release-notes.sh "$tag_name" "$arm64_sha256" "$x86_64_sha256" "dist/release-notes.md"
./scripts/test-formula-sync.sh "$local_formula_path" "$tag_name"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  ./scripts/write-release-summary.sh "$tag_name" "$arm64_artifact_name" "$arm64_sha256" "$x86_64_artifact_name" "$x86_64_sha256"
fi

tar -tzf "$native_artifact_path" | grep -q './aptune'
tar -tzf "$native_artifact_path" | grep -q './Aptune_VAD.bundle/'
grep -q "${arm64_sha256}" "$local_formula_path"
grep -q "${x86_64_sha256}" "$local_formula_path"
grep -q "${tag_name}" "dist/release-notes.md"
