#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

detect_tag() {
  sed -n 's/.*current = "\(v[0-9][0-9.]*\)".*/\1/p' Sources/CLI/AptuneConfig.swift | head -n 1
}

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is required to run act locally" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "error: docker daemon is not available" >&2
  exit 1
fi

if ! command -v actionlint >/dev/null 2>&1; then
  echo "error: actionlint is required; enter the nix dev shell or install it manually" >&2
  exit 1
fi

if ! command -v act >/dev/null 2>&1; then
  echo "error: act is required; enter the nix dev shell or install it manually" >&2
  exit 1
fi

tag_name="${1:-$(detect_tag)}"
shift || true

act_args=("$@")
if [ -z "${act_default_container_arch:-}" ]; then
  act_default_container_arch="linux/amd64"
fi

if [ "$(/usr/bin/uname -m)" = "arm64" ]; then
  has_container_arch=false
  for arg in "${act_args[@]}"; do
    case "$arg" in
      --container-architecture*) has_container_arch=true ;;
    esac
  done

  if [ "$has_container_arch" = false ]; then
    act_args=("--container-architecture" "$act_default_container_arch" "${act_args[@]}")
  fi
fi

cache_root="${repo_root}/.cache/act"
mkdir -p "${cache_root}/actions" "${cache_root}/artifacts" "${cache_root}/cache"

actionlint .github/workflows/release.yml .github/workflows/actions-smoke.yml

exec act workflow_dispatch \
  -W .github/workflows/actions-smoke.yml \
  --input "tag=${tag_name}" \
  --action-cache-path "${cache_root}/actions" \
  --artifact-server-path "${cache_root}/artifacts" \
  --cache-server-path "${cache_root}/cache" \
  "${act_args[@]}"
