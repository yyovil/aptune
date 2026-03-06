# Aptune

Aptune is a macOS Swift CLI that ducks system output volume while you speak.

## Versioning

Aptune uses canonical SwiftPM versioning via Git tags (SemVer). The current codebase is a FireRedVAD-only `v0.2.0` build.

## Build

```bash
swift build
```

Aptune uses a bundled FireRedVAD Core ML package. There is no Python runtime, no external model download, and no extra setup required at runtime.

## Run

```bash
swift run aptune --downTo 0.25
```

```bash
swift run aptune --version
```

On first run, macOS will ask for microphone permission.

## Options

- `--downTo <0...1>` (default `0.25`)
- `--attack-ms <int>` (default `80`)
- `--release-ms <int>` (default `600`)
- `--hold-ms <int>` (default `250`)
- `--log-level info|debug` (default `info`)
- `--speech-threshold <0...1>` (default `0.7`)
- `-h`, `--help`, `help`
- `-v`, `--version`, `version`

## Behavior

- Uses the FireRedVAD Core ML model with native feature extraction and the `fr-v0.2` CLI profile.
- On speech onset, volume ramps down to `current * downTo`.
- After silence hold, volume ramps back to the pre-duck baseline.
- On exit (`Ctrl+C`), Aptune restores baseline volume.
