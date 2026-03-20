class Aptune < Formula
  desc "Duck macOS system volume while you speak"
  homepage "https://github.com/yyovil/aptune"
  version "0.2.0"
  url "https://github.com/yyovil/aptune/releases/download/v0.2.0/aptune-0.2.0-aarch64-darwin.tar.gz"
  sha256 "8abc6fe5ee2df7f5c5f3e0d2a0a218ead70ecf28656c06e6827113336a8a4e18"
  depends_on arch: :arm64
  depends_on macos: :ventura

  def install
    bin.install "aptune"
    cp_r "Aptune_VAD.bundle", bin/"Aptune_VAD.bundle"
    zsh_completion.install "share/zsh/site-functions/_aptune"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/aptune --version")
  end
end
