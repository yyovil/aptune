# Contributing

Human pull requests are not welcomed here.

If you want something fixed or added, open an issue and include:

- what you expected
- what actually happened
- steps to reproduce
- environment details
- a prompt that you think would help resolve the issue

Use the issue form in GitHub. Issues that do not follow the form should be closed.

## Local development

Build:

```bash
swift build
```

Test:

```bash
./scripts/test.sh
```

This uses the active Xcode toolchain and an isolated `.build-tests` directory so test runs do not conflict with packaging builds.

## Packaging

Generate the release tarball and checksum expected by the Homebrew formula:

```bash
./scripts/create-release-artifact.sh
```

That script:

- builds a native macOS release with the active Xcode toolchain
- creates `dist/aptune-<version>-<system>.tar.gz`
- prints the SHA256 to copy into `Formula/aptune.rb`

Update the tap formula locally with:

```bash
./scripts/update-homebrew-formula.sh <version> <sha256>
```

## Release automation

Pushing a tag like `v0.2.0` triggers `.github/workflows/release.yml`, which:

- runs `./scripts/test.sh`
- builds the macOS release tarball
- publishes a GitHub Release with the tarball and a generated `aptune.rb`
- updates `Formula/aptune.rb` on the default branch so the repo stays tap-ready

## Local GitHub Actions testing

Use `act` for local smoke tests:

```bash
./scripts/test-github-actions.sh
```

This runs `.github/workflows/actions-smoke.yml` in Docker and checks the release helper scripts without pretending that Docker can execute the real `macos-14` release job. For the actual release path, keep using GitHub-hosted macOS runners.

## Local macOS VM release testing

Use Tart when you want macOS-native coverage of the release flow without publishing a GitHub release:

```bash
./scripts/test-release-workflow-in-tart.sh v0.2.0
```

This uses a temporary Tart VM, copies the repository into it, and runs `./scripts/test-release-workflow.sh` inside the guest. The flake enables the unfree `tart` package with a scoped predicate for `tart` only.
