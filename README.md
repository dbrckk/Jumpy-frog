# Jumpy Frog

An original, small Godot 4.5.1 mobile arcade game inspired by the *gameplay genre* shown in the user's Capy Hop reference footage. All illustrations are code-drawn originals; no frames, art, sounds or trademarks from the reference game are redistributed.

## Play

Hold your finger anywhere, drag **down** to choose a forward jump, shift the drag **left/right** to steer (pull left = launch right), then release. Land on a lily pad. Missing it means splash. The trailing wave catches idle players. Collect golden bonuses and stack up to eight animal passengers. Best score is saved on device.

## Requirements

- Godot Engine **4.5.1** (regular/non-.NET build)
- No external assets, packages, network access or paid services.
- Android export target: ARM64 in portrait orientation.

## Run or test

```bash
godot --path .
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/smoke.gd
```

The repository's GitHub Actions workflow runs the same tests and exports an Android debug APK that can be downloaded from the workflow's Artifacts section.

## Android locally

Install Godot Android export templates for exactly 4.5.1, Android SDK and Java SDK, then run:

```bash
mkdir -p build
godot --headless --path . --export-debug "Android" build/JumpyFrog-debug.apk
```

To publish to Google Play, configure your own private release keystore outside version control and export an AAB (not a debug APK). Consult the [official Godot Android exporter](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html).

## Development

- `scripts/game.gd`: gesture controls, endless generation, camera, scoring, chase and save system.
- `scripts/art.gd`: original scalable 2D illustrations, animated wave and interface.
- `tests/smoke.gd`: gameplay regression tests.
- `project.godot`, `main.tscn`: entry point and portrait/compatibility settings.

No user data is collected or transmitted. No Android permissions are required. Audio is synthesized at runtime.

## Next quality improvements

Expand illustrated asset detail, add proper animation tweening and haptic feedback, add an accessible pause and settings menu, validate touch sizing on several physical Android devices, optimize rendering based on profiling and add production signing/AAB export.
