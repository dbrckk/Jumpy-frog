# Jumpy Frog 1.1 — River Hop

A portrait arcade game for Android, built with Godot 4.5.1. Inspired by the genre of one-finger river-hopping games; all characters and illustrations are original. No third-party assets are redistributed.

## Playing

Hold and drag **down** to aim a forward jump; drag left/right to steer, then release. Land safely on a lily pad to earn points. Collect leaves, rescue animal companions, and keep ahead of the wave. Missing a pad ends the run.

A persistent progression system lets you earn leaves and unlock eight character color styles in the **Customize** screen. **Daily missions** refresh each UTC day, awarding bonus leaves for eight hops, four leaves, or reaching 80 meters. A play streak and lifetime statistics persist across sessions. Scores, unlocked styles, currency and preferences are saved locally.

The default/debug build runs entirely offline with no ads. The **optional monetized Google Play build** integrates real Google AdMob/UMP advertising plus Google Play Billing for a permanent one-time remove-ads purchase; it requires real publisher credentials, consent configuration and a signed Gradle AAB.

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

The project includes an Android API 36 AAB export preset and **two export paths**: the normal no-ads debug APK and an explicitly configured, monetized Gradle Play build with [AdMob 5.1](https://github.com/poingstudios/godot-admob-plugin) and [Play Billing 3.3](https://github.com/godot-sdk-integrations/godot-google-play-billing). [Monetized Android SDK QA](.github/workflows/monetization-qa.yml) compiles a test-only AAB with Google's official test ad IDs; [Google Play signed AAB](.github/workflows/play-release.yml) requires private upload and AdMob credentials. This requires your **private upload keystore** to be configured as GitHub Actions secrets; there is no release key or password in Git.

Read **[monetization integration and Play Console setup](docs/monetization.md)** and the **[release readiness checklist](docs/release-readiness.md)** before distributing or uploading anything. A successful APK export is not proof of Play approval or stability on your Redmi.

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
- `scripts/daily.gd`: three repeatable daily objectives, offline progression and streak tracking
- `scripts/monetization.gd`: fail-closed real billing/advertising orchestration and ad scheduling
- `monetization/admob_bridge.gd.template`: native SDK adapter, installed only into monetized builds
- `scripts/audio.gd`: original cached sounds for desktop; Android native crash mitigation
- `tests/smoke.gd`: end-to-end gameplay, progression, audio and VFX tests
- `tests/retention_and_ads.gd`: regression tests for daily rewards, clock rollover and ads/billing guards
- `tools/`: original Android and store icon generators

## License and content

All code and illustrations in this repository are the original work of the project. Verify project ownership and choose a source-code license deliberately before releasing source for reuse. The app does not embed art or audio copied from the referenced game.

## Revenue policy

Only advertise at natural game-over breaks; no interstitials during active jumps. First 4 games are ad-free and interstitials have 6-minute cooldowns. Rewarded videos are optional, granting leaves only after an SDK-earned-reward callback. A **non-consumable** Google Play purchase `remove_ads` removes all ads after confirmed ownership, including restores. The price is configured in Play Console (intended €2.00 in France) and fetched from Play Billing. See [monetization](docs/monetization.md).


## Six replayable chapters (version 1.2)

Beyond endless running, the CHAPTERS menu offers Sunny Banks, Lily Garden, Golden Reeds, Moonlit Pond, Crystal River and Stormy Rapids. Each stage uses different pad widths, lateral drift, wave pressure, water colors and vegetation. Finishing a stage earns permanent medals (1–3 stars) and unlocks the next stage. First-time rewards cannot be farmed by repeating the same medal; higher medals can award a small improvement bonus.

Endless mode now cycles continuously through all six environments. Precise center-aimed hops build a PERFECT streak and every fifth perfect landing grants a bonus leaf. Glowing current-boost pads push the chasing wave back to reward exploration. Daily goals, lifelong achievements and the eight cosmetic styles remain obtainable without spending money.

## Music and Android feedback

Desktop builds have eleven original procedural sound effects plus an eight-second gentle pentatonic music loop with biome-dependent pitch. Android continues to use the safe dummy audio driver because a native OpenSL ES callback crashed on a Redmi running Android 15. Android audio is deliberately disabled until a genuinely safe backend has been tested on that device. Optional short vibrations replace some audio cues, can be turned off in Pause and require the VIBRATE Android permission.

Run the extended campaign tests:

~~~bash
godot --headless --path . --script res://tests/chapters.gd
~~~
