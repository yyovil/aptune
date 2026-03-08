{
  description = "Aptune is a macOS CLI that ducks system volume while you speak";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, flake-utils, nixpkgs }:
    flake-utils.lib.eachSystem [ "aarch64-darwin" "x86_64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        lib = pkgs.lib;
        appleSdk = pkgs.apple-sdk_14;
        swift = pkgs.swiftPackages.swift;
        swiftpm = pkgs.swiftPackages.swiftpm;
        version = "0.2.0";
      in
      {
        packages = rec {
          aptune = pkgs.stdenv.mkDerivation {
            pname = "aptune";
            inherit version;
            src = lib.cleanSource ./.;

            strictDeps = true;
            dontConfigure = true;

            nativeBuildInputs = [
              swift
              swiftpm
            ];

            buildInputs = [
              appleSdk
              pkgs.libiconv
            ];

            DEVELOPER_DIR = appleSdk;
            SDKROOT = "${appleSdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk";

            buildPhase = ''
              export HOME="$TMPDIR"
              swift build -c release --build-path .build
            '';

            installPhase = ''
              release_dir="$(cd .build/release && pwd -P)"

              mkdir -p "$out/bin"
              install -m755 "$release_dir/aptune" "$out/bin/aptune"
              cp -R "$release_dir/Aptune_VAD.bundle" "$out/bin/Aptune_VAD.bundle"
            '';

            meta = with lib; {
              description = "Duck macOS system volume while speaking";
              homepage = "https://github.com/yyovil/aptune";
              license = licenses.mit;
              mainProgram = "aptune";
              platforms = platforms.darwin;
            };
          };

          default = aptune;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = self.packages.${system}.aptune;
          exePath = "/bin/aptune";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = [
            swift
            swiftpm
            appleSdk
            pkgs.libiconv
          ];

          shellHook = ''
            export DEVELOPER_DIR="${appleSdk}"
            export SDKROOT="${appleSdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
            export CLANG_MODULE_CACHE_PATH="$PWD/.cache/clang-module-cache"
            export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.cache/swiftpm-module-cache"
          '';
        };
      });
}
