# Optional Audio Routing Helper

If you want Aptune to keep using your Mac's built-in microphone while your audio output stays on AirPods or another Bluetooth device, Aptune can set that up directly from its own CLI.

## Spotlight Setup

After installing Aptune, run:

```bash
aptune install-plugin built-in-mic
```

That creates `~/Applications/Aptune Built-in Mic.app`.

After that, you can open Spotlight and launch `Aptune Built-in Mic` directly.

The launcher:

- switches Aptune back to your Mac's built-in microphone
- leaves your current output device unchanged
- restarts Aptune if it is already running so the new input route takes effect
- launches `aptune` in the background

## Optional CLI Usage

If you want to inspect devices or launch the same built-in-mic flow from Terminal:

```bash
aptune use-built-in-mic --list
aptune use-built-in-mic -- --down-to 0.25
```

If you want to switch the output device explicitly as well:

```bash
aptune use-built-in-mic --output "AirPods Pro" -- --down-to 0.25
```

## Notes

- If you move or reinstall Aptune later, rerun `aptune install-plugin built-in-mic`.
- If `~/Applications/Aptune Built-in Mic.app` already exists, Aptune asks before replacing it.
- The Spotlight launcher writes logs to `~/Library/Logs/Aptune/spotlight-launcher.log`.
- This helper is optional and macOS-only.
