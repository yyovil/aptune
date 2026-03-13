class Aptune < Formula
  desc "Duck macOS system volume while you speak"
  homepage "https://github.com/yyovil/aptune"
  version "0.2.0"
  url "https://github.com/yyovil/aptune/releases/download/v0.2.0/aptune-0.2.0-aarch64-darwin.tar.gz"
  sha256 "1662102e2fd3ba9e4a901d8d8a6f1ea6d2424b0d459565d26937ca1f923df735"
  depends_on arch: :arm64
  depends_on macos: :ventura

  def install
    bin.install "aptune"
    cp_r "Aptune_VAD.bundle", bin/"Aptune_VAD.bundle"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aptune --version")
  end
end
