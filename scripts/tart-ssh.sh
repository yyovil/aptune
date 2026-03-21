#!/usr/bin/env bash

set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "usage: $0 <vm-name> [command ...]" >&2
  exit 1
fi

vm_name="$1"
shift || true

if ! command -v tart >/dev/null 2>&1; then
  echo "error: tart is required" >&2
  exit 1
fi

if ! command -v sshpass >/dev/null 2>&1; then
  echo "error: sshpass is required" >&2
  exit 1
fi

vm_ip="$(tart ip "$vm_name")"

if [ "$#" -eq 0 ]; then
  exec sshpass -p admin ssh \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    "admin@${vm_ip}"
fi

exec sshpass -p admin ssh \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  "admin@${vm_ip}" \
  "$@"
