#!/usr/bin/env bash

set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: $0 <vm-name> [timeout-seconds]" >&2
  exit 1
fi

vm_name="$1"
timeout_seconds="${2:-300}"
start_time="$(date +%s)"

while true; do
  if ./scripts/tart-ssh.sh "$vm_name" "uname -a" >/dev/null 2>&1; then
    exit 0
  fi

  current_time="$(date +%s)"
  if [ $((current_time - start_time)) -ge "$timeout_seconds" ]; then
    echo "error: timed out waiting for SSH on Tart VM '${vm_name}'" >&2
    exit 1
  fi

  sleep 5
done
