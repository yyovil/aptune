#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ] || [ "${3:-}" = "" ]; then
  echo "usage: $0 <version> <arm64-sha256> <x86_64-sha256> [formula-path] [formula-asset-path]" >&2
  exit 1
fi

version="$1"
arm64_sha256="$2"
x86_64_sha256="$3"
formula_path="${4:-Formula/aptune.rb}"
formula_asset_path="${5:-}"

repo_slug="${APTUNE_GITHUB_REPO:-}"
if [ -z "$repo_slug" ]; then
  origin_url="$(git remote get-url origin 2>/dev/null || true)"
  repo_slug="$(printf '%s\n' "$origin_url" | sed -E 's#(git@github.com:|https://github.com/)##; s#\.git$##')"
fi
if [ -z "$repo_slug" ]; then
  repo_slug="yyovil/aptune"
fi

arm64_url="https://github.com/${repo_slug}/releases/download/v${version}/aptune-${version}-aarch64-darwin.tar.gz"
x86_64_url="https://github.com/${repo_slug}/releases/download/v${version}/aptune-${version}-x86_64-darwin.tar.gz"

cat > "$formula_path" <<EOF
class Aptune < Formula
  desc "Duck macOS system volume while you speak"
  homepage "https://github.com/${repo_slug}"
  version "${version}"
  depends_on macos: :ventura

  if Hardware::CPU.arm?
    url "${arm64_url}"
    sha256 "${arm64_sha256}"
  else
    url "${x86_64_url}"
    sha256 "${x86_64_sha256}"
  end

  def install
    bin.install "aptune"
    cp_r "Aptune_VAD.bundle", bin/"Aptune_VAD.bundle"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aptune --version")
  end
end
EOF

if [ -n "$formula_asset_path" ]; then
  mkdir -p "$(dirname "$formula_asset_path")"
  cp "$formula_path" "$formula_asset_path"
fi
