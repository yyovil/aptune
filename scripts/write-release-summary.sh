#!/usr/bin/env bash

set -euo pipefail

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ] || [ "${3:-}" = "" ] || [ "${4:-}" = "" ] || [ "${5:-}" = "" ]; then
  echo "usage: $0 <tag> <arm64-artifact-name> <arm64-sha256> <x86_64-artifact-name> <x86_64-sha256>" >&2
  exit 1
fi

if [ -z "${GITHUB_STEP_SUMMARY:-}" ]; then
  echo "error: GITHUB_STEP_SUMMARY is not set" >&2
  exit 1
fi

tag_name="$1"
arm64_artifact_name="$2"
arm64_sha256="$3"
x86_64_artifact_name="$4"
x86_64_sha256="$5"

{
  echo "## Release published"
  echo
  echo "- Tag: \`${tag_name}\`"
  echo "- Apple Silicon artifact: \`${arm64_artifact_name}\`"
  echo "- Apple Silicon SHA256: \`${arm64_sha256}\`"
  echo "- Intel artifact: \`${x86_64_artifact_name}\`"
  echo "- Intel SHA256: \`${x86_64_sha256}\`"
} >> "$GITHUB_STEP_SUMMARY"
