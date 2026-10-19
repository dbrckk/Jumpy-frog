# Jumpy Frog 1.0 — River Hop

A portrait arcade game for Android, built with Godot 4.5.1. Inspired by the genre of one-finger river-hopping games; all characters and illustrations are original. No third-party assets are redistributed.

## Playing

Hold and drag **down** to aim a forward jump; drag left/right to steer, then release. Land safely on a lily pad to earn points. Collect leaves, rescue animal companions, and keep ahead of the wave. Missing a pad ends the run.

A persistent progression system lets you earn leaves and unlock four character color styles in the **Customize** screen. Your best score, currency, unlocked styles, chosen style and sound preference are saved locally.

The game runs entirely offline. No ads, in-app purchases, user accounts, analytics, tracking or network permission.

## Quality and device compatibility

- 540 × 960 portrait design with Godot Compatibility renderer
- Illustrated capybara, four companion species, animated lily pads and water effects
- Run loop, increasing wave difficulty, HUD, restart and pause menu
- High score, leaves and unlocked cosmetics stored on device
- Android 15 crash mitigation: **Android audio intentionally disabled pending physical-device validation.** See [audio crash investigation](docs/android-audio-crash.md).
- Desktop builds retain cached original procedural SFX and ambient river audio

## Development

Use Godot Engine 4.5.1 (non-.NET).

```bash
godot --path .
godot --headless --editor --path . --quit
godot --headless --path . --script res://tests/smoke.gd
```

The GitHub Actions **Godot QA and Android APK** workflow tests the game and produces a signed-for-debug APK. The debug signing key is newly generated on each CI run, so older debug builds may not accept an in-place update.

## Google Play release

The project includes a separate **Google Play AAB** export preset targeting Android 16 / API level 36 through Gradle, and a manually triggered [Google Play signed AAB](.github/workflows/play-release.yml) workflow. This requires your **private upload keystore** to be configured as GitHub Actions secrets; there is no release key or password in Git.

Read **[release readiness checklist](docs/release-readiness.md)** before distributing or uploading anything. A successful APK export is not proof of Play approval or stability on your Redmi.

Store materials:
- [Bilingual store listing](docs/play-store-listing.md)
- [Privacy policy (English + français)](docs/privacy-policy.md)
- [Original store icon/feature graphic generator](tools/generate_store_assets.py)

```bash
python -m pip install pillow
python tools/generate_store_assets.py
```

This generates `build/store/play-icon-512.png` and `build/store/feature-graphic-1024x500.png`. Real screenshots must be captured from the running app.

## Code map

- `scripts/game.gd`: touch gameplay, scoring, progression, cosmetics, saves
- `scripts/art.gd`: original character/river rendering, HUD, menus and VFX
- `scripts/audio.gd`: original cached sounds for desktop; Android native crash mitigation
- `tests/smoke.gd`: end-to-end gameplay, progression, audio and VFX tests
- `tools/`: original Android and store icon generators

## License and content

All code and illustrations in this repository are the original work of the project. Verify project ownership and choose a source-code license deliberately before releasing source for reuse. The app does not embed art or audio copied from the referenced game.
