# Aptune

Aptune is a macOS Swift CLI that ducks system output volume while you speak.

## Versioning

Aptune uses canonical SwiftPM versioning via Git tags (SemVer). `v0.1.0` is the native SoundAnalysis release, and `v0.2.0` adds the Silero backend/profile.

## Build

```bash
swift build
```

## Run

```bash
swift run aptune --downTo 0.25
```

```bash
swift run aptune --version
```

## Options

- `--downTo <0...1>` (default `0.25`)
- `--engine native|silero` (default `native`)
- `--attack-ms <int>` (default `80`)
- `--release-ms <int>` (default `600`)
- `--hold-ms <int>` (default `250`)
- `--log-level info|debug` (default `info`)
- `--speech-threshold <0...1>` (default `0.55`)
- `-h`, `--help`, `help`
- `-v`, `--version`, `version`

## Behavior

- Uses mic input with Apple SoundAnalysis (`native` engine) for speech activity.
- The `silero` engine uses a separate local amplitude-based VAD path, exposed as the `v0.2` CLI profile.
- On speech onset, volume ramps down to `current * downTo`.
- After silence hold, volume ramps back to the pre-duck baseline.
- On exit (`Ctrl+C`), Aptune restores baseline volume.
