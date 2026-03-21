#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "${1:-}" = "" ]; then
  echo "usage: $0 <tag> [remote-image]" >&2
  exit 1
fi

if [ "$(/usr/bin/uname -m)" != "arm64" ]; then
  echo "error: Tart requires Apple Silicon hosts" >&2
  exit 1
fi

if ! command -v tart >/dev/null 2>&1; then
  echo "error: tart is required; enter the nix dev shell or install it manually" >&2
  exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
  echo "error: sshpass is required; enter the nix dev shell or install it manually" >&2
  exit 1
fi

tag_name="$1"
remote_image="${2:-ghcr.io/cirruslabs/macos-sequoia-base:latest}"
vm_name="aptune-release-${tag_name//[^a-zA-Z0-9]/-}-$(date +%s)"
bundle_path="$(mktemp -u "${TMPDIR:-/tmp}/aptune-release-bundle.XXXXXX.tar.gz")"
run_log="${TMPDIR:-/tmp}/${vm_name}.log"

cleanup() {
  tart stop "$vm_name" >/dev/null 2>&1 || true
  tart delete "$vm_name" >/dev/null 2>&1 || true
  rm -f "$bundle_path"
}

trap cleanup EXIT

tar \
  --exclude='.git' \
  --exclude='.build' \
  --exclude='.build-release' \
  --exclude='.build-tests' \
  --exclude='.cache' \
  --exclude='dist' \
  -czf "$bundle_path" \
  .

tart clone "$remote_image" "$vm_name"
tart run "$vm_name" >"$run_log" 2>&1 &

./scripts/tart-wait-for-ssh.sh "$vm_name"

./scripts/tart-ssh.sh "$vm_name" "rm -rf ~/aptune && mkdir -p ~/aptune"
sshpass -p admin scp \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "$bundle_path" \
  "admin@$(tart ip "$vm_name"):~/aptune/repo.tar.gz"
./scripts/tart-ssh.sh "$vm_name" "cd ~/aptune && tar -xzf repo.tar.gz && rm repo.tar.gz && ./scripts/test-release-workflow.sh \"$tag_name\""
