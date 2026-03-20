# Aptune

Aptune is a cli tool for MacOS that ducks system volume while you speak.

[![Watch the demo](https://img.youtube.com/vi/bI2UbxcefwM/maxresdefault.jpg)](https://youtu.be/bI2UbxcefwM)

## Features

- On speech onset, volume ramps down to `current * configured multiplier`.
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

Optional macOS audio routing helper and Spotlight launcher: if you want Aptune to keep using your Mac's built-in microphone while playback stays on AirPods or another Bluetooth device, see [docs/audio-routing-helper.md](docs/audio-routing-helper.md).

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

Optional Spotlight launcher:

```bash
aptune install-plugin built-in-mic
```

If you want Aptune to keep using your Mac's built-in microphone while your audio output stays on AirPods or another Bluetooth device, see [docs/audio-routing-helper.md](docs/audio-routing-helper.md).

## Shell Completion

Aptune currently ships `zsh` completions.

If you install Aptune with the Nix flake or the Homebrew tap above, the completion file is installed automatically. Start a new `zsh` session or run:

```bash
exec zsh
```

If you install Aptune from a release tarball, copy `share/zsh/site-functions/_aptune` into a directory on your `fpath`, then reload completions:

```bash
autoload -Uz compinit
compinit -i
```
