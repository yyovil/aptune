#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "${1:-}" = "" ]; then
  echo "usage: $0 <artifacts-dir>" >&2
  exit 1
fi

artifacts_dir="$1"

if [ ! -d "$artifacts_dir" ]; then
  echo "error: artifacts directory not found: $artifacts_dir" >&2
  exit 1
fi

load_manifest() {
  local manifest_path="$1"
  local output_name="$2"

  unset version system artifact_name artifact_path sha256
  # shellcheck disable=SC1090
  source "$manifest_path"

  if [ -z "${system:-}" ] || [ -z "${artifact_name:-}" ] || [ -z "${artifact_path:-}" ] || [ -z "${sha256:-}" ]; then
    echo "error: incomplete manifest: $manifest_path" >&2
    exit 1
  fi

  local resolved_artifact_path="${artifacts_dir}/${artifact_name}"
  if [ ! -f "$resolved_artifact_path" ]; then
    echo "error: artifact referenced by ${manifest_path} was not downloaded: ${artifact_name}" >&2
    exit 1
  fi

  printf -v "${output_name}_artifact_name" '%s' "$artifact_name"
  printf -v "${output_name}_artifact_path" '%s' "${artifacts_dir}/${artifact_name}"
  printf -v "${output_name}_sha256" '%s' "$sha256"
}

arm64_manifest="${artifacts_dir}/release-manifest-aarch64-darwin.env"
x86_64_manifest="${artifacts_dir}/release-manifest-x86_64-darwin.env"

if [ ! -f "$arm64_manifest" ]; then
  echo "error: missing arm64 release manifest" >&2
  exit 1
fi

if [ ! -f "$x86_64_manifest" ]; then
  echo "error: missing x86_64 release manifest" >&2
  exit 1
fi

load_manifest "$arm64_manifest" arm64
load_manifest "$x86_64_manifest" x86_64

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "arm64_artifact_name=${arm64_artifact_name}"
    echo "arm64_artifact_path=${arm64_artifact_path}"
    echo "arm64_sha256=${arm64_sha256}"
    echo "x86_64_artifact_name=${x86_64_artifact_name}"
    echo "x86_64_artifact_path=${x86_64_artifact_path}"
    echo "x86_64_sha256=${x86_64_sha256}"
  } >> "$GITHUB_OUTPUT"
fi

cat <<EOF
arm64 artifact: ${arm64_artifact_path}
arm64 sha256:  ${arm64_sha256}
x86_64 artifact: ${x86_64_artifact_path}
x86_64 sha256:  ${x86_64_sha256}
EOF
