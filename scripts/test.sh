#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -x /usr/bin/xcode-select ] || [ ! -x /usr/bin/xcrun ]; then
  echo "error: Xcode command line tools are required to run tests" >&2
  exit 1
fi

clean_env=(env -u DEVELOPER_DIR -u SDKROOT)

export DEVELOPER_DIR="$("${clean_env[@]}" /usr/bin/xcode-select -p)"
export SDKROOT="$("${clean_env[@]}" /usr/bin/xcrun --sdk macosx --show-sdk-path)"
export CC="$(${clean_env[@]} /usr/bin/xcrun --find clang)"
export CXX="$(${clean_env[@]} /usr/bin/xcrun --find clang++)"
export MACOSX_DEPLOYMENT_TARGET="13.0"
export CLANG_MODULE_CACHE_PATH="${repo_root}/.cache/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${repo_root}/.cache/swiftpm-module-cache"

mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"

swift_bin="$("${clean_env[@]}" /usr/bin/xcrun --find swift)"

exec "${clean_env[@]}" \
  DEVELOPER_DIR="$DEVELOPER_DIR" \
  SDKROOT="$SDKROOT" \
  CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE_PATH" \
  SWIFTPM_MODULECACHE_OVERRIDE="$SWIFTPM_MODULECACHE_OVERRIDE" \
  "$swift_bin" test --build-path "${repo_root}/.build-tests" "$@"
