# Introduction

![Aptune Banner](APTUNE_BANNER.svg)

Aptune is a cli tool for MacOS that ducks system volume while you speak.

[![Watch the demo](https://img.youtube.com/vi/bI2UbxcefwM/maxresdefault.jpg)](https://youtu.be/bI2UbxcefwM)

## Features

- On speech onset, volume ramps down to `current * configured ducking multiplier`.
- After silence hold, volume ramps back to the pre-duck baseline.
- On exit (`Ctrl+C`), Aptune restores baseline volume.

## Usage

- `--down-to <0...1>` (default `0.25`)
- `--attack-ms <int>` (default `80`)
- `--release-ms <int>` (default `600`)
- `--hold-ms <int>` (default `250`)
- `--log-level info|debug` (default `info`)
- `--speech-threshold <0...1>` (default `0.7`)
- `-h`, `--help`, `help`
- `-v`, `--version`, `version`

## Install

### Nix flake

```bash
nix profile install github:yyovil/aptune#aptune
```

You can also run it without installing:

```bash
nix run github:yyovil/aptune#aptune -- --version
```

This flake is macOS-only because Aptune depends on Apple audio, Core ML, and AppleScript APIs.

### Homebrew tap

Install Aptune from the tap:

```bash
brew tap yyovil/aptune https://github.com/yyovil/aptune
brew install aptune
```
