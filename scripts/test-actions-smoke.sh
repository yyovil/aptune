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
arm64_sha256="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
x86_64_sha256="fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
arm64_artifact_name="aptune-${version}-aarch64-darwin.tar.gz"
x86_64_artifact_name="aptune-${version}-x86_64-darwin.tar.gz"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/aptune-actions-smoke.XXXXXX")"
formula_path="${work_dir}/aptune.rb"
notes_path="${work_dir}/release-notes.md"
summary_path="${work_dir}/summary.md"
artifacts_dir="${work_dir}/release-assets"

cleanup() {
  rm -rf "$work_dir"
}

trap cleanup EXIT

mkdir -p "$artifacts_dir"
touch "${artifacts_dir}/${arm64_artifact_name}" "${artifacts_dir}/${x86_64_artifact_name}"

./scripts/verify-release-tag.sh "$tag_name"
./scripts/write-release-manifest.sh "$version" "aarch64-darwin" "dist/${arm64_artifact_name}" "$arm64_sha256" "${artifacts_dir}/release-manifest-aarch64-darwin.env"
./scripts/write-release-manifest.sh "$version" "x86_64-darwin" "dist/${x86_64_artifact_name}" "$x86_64_sha256" "${artifacts_dir}/release-manifest-x86_64-darwin.env"
./scripts/collect-release-artifacts.sh "$artifacts_dir"
./scripts/update-homebrew-formula.sh "$version" "$arm64_sha256" "$x86_64_sha256" "$formula_path"
./scripts/write-release-notes.sh "$tag_name" "$arm64_sha256" "$x86_64_sha256" "$notes_path"
GITHUB_STEP_SUMMARY="$summary_path" ./scripts/write-release-summary.sh "$tag_name" "$arm64_artifact_name" "$arm64_sha256" "$x86_64_artifact_name" "$x86_64_sha256"

grep -q 'class Aptune < Formula' "$formula_path"
grep -q "version \"${version}\"" "$formula_path"
grep -q "${arm64_artifact_name}" "$formula_path"
grep -q "${x86_64_artifact_name}" "$formula_path"
grep -q "${arm64_sha256}" "$formula_path"
grep -q "${x86_64_sha256}" "$formula_path"
grep -q "aptune ${tag_name} release" "$notes_path"
grep -q "$arm64_sha256" "$notes_path"
grep -q "$x86_64_sha256" "$notes_path"
grep -q "$arm64_artifact_name" "$summary_path"
grep -q "$x86_64_artifact_name" "$summary_path"
./scripts/test-formula-sync.sh "$formula_path" "$tag_name"
