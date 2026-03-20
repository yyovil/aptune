#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ ! -x /usr/bin/xcode-select ] || [ ! -x /usr/bin/xcrun ]; then
  echo "error: Xcode command line tools are required to build release artifacts" >&2
  exit 1
fi

detect_version() {
  sed -n 's/.*current = "v\([0-9][0-9.]*\)".*/\1/p' \
    Sources/CLI/AptuneConfig.swift | head -n 1
}

detect_system() {
  case "$(/usr/bin/uname -m)" in
    arm64) echo "aarch64-darwin" ;;
    x86_64) echo "x86_64-darwin" ;;
    *)
      echo "error: unsupported macOS architecture '$(/usr/bin/uname -m)'" >&2
      exit 1
      ;;
  esac
}

version="${1:-$(detect_version)}"
system="${2:-$(detect_system)}"
artifact_name="aptune-${version}-${system}"
artifact_path="dist/${artifact_name}.tar.gz"
build_path="${repo_root}/.build-release"
stage_dir="$(mktemp -d "${repo_root}/dist-stage.XXXXXX")"
clean_env=(env -u DEVELOPER_DIR -u SDKROOT -u MACOSX_DEPLOYMENT_TARGET)

cleanup() {
  rm -rf "$stage_dir"
}

trap cleanup EXIT

stage_release_payload() {
  mkdir -p "${stage_dir}/share/zsh/site-functions"

  cp "${release_dir}/aptune" "${stage_dir}/aptune"
  cp -R "${release_dir}/Aptune_VAD.bundle" "${stage_dir}/Aptune_VAD.bundle"
  install -m644 "${repo_root}/completions/zsh/_aptune" "${stage_dir}/share/zsh/site-functions/_aptune"
}

export DEVELOPER_DIR="$("${clean_env[@]}" /usr/bin/xcode-select -p)"
export SDKROOT="$("${clean_env[@]}" /usr/bin/xcrun --sdk macosx --show-sdk-path)"
export CC="$("${clean_env[@]}" /usr/bin/xcrun --find clang)"
export CXX="$("${clean_env[@]}" /usr/bin/xcrun --find clang++)"
export MACOSX_DEPLOYMENT_TARGET="13.0"
export CLANG_MODULE_CACHE_PATH="${repo_root}/.cache/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${repo_root}/.cache/swiftpm-module-cache"

mkdir -p dist "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"
rm -rf "$build_path"

swift_bin="$("${clean_env[@]}" /usr/bin/xcrun --find swift)"

"${clean_env[@]}" \
  DEVELOPER_DIR="$DEVELOPER_DIR" \
  SDKROOT="$SDKROOT" \
  CC="$CC" \
  CXX="$CXX" \
  MACOSX_DEPLOYMENT_TARGET="$MACOSX_DEPLOYMENT_TARGET" \
  CLANG_MODULE_CACHE_PATH="$CLANG_MODULE_CACHE_PATH" \
  SWIFTPM_MODULECACHE_OVERRIDE="$SWIFTPM_MODULECACHE_OVERRIDE" \
  "$swift_bin" build -c release --build-path "$build_path"

release_dir="$(cd "${build_path}/release" && pwd -P)"

stage_release_payload

tar -C "$stage_dir" -czf "$artifact_path" .
sha256="$(shasum -a 256 "$artifact_path" | awk '{print $1}')"

cat <<EOF
artifact: $artifact_path
sha256:   $sha256

Homebrew formula URL:
https://github.com/yyovil/aptune/releases/download/v${version}/${artifact_name}.tar.gz
EOF

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "artifact_path=${artifact_path}"
    echo "artifact_name=${artifact_name}"
    echo "sha256=${sha256}"
  } >> "$GITHUB_OUTPUT"
fi
