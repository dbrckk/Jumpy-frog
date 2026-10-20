# Jumpy Frog — 15 quality pillars (v1.4 development pass)

This document records what is **implemented**, what is **automatically tested**, and what still needs **physical Android verification**. No numerical FPS/thermal improvements are claimed without measurements on a real device.

| # | Pillar | Implementation / acceptance criteria |
|---|---|---|
| 1 | Water shaders | `shaders/river_surface.gdshader`: 3 procedural wave layers, cubic crests (no pow), smooth shoreline fades, no texture reads. |
| 2 | GPU fill rate | `RiverSurfaceCaustics` ColorRect cropped to x=76..464 rather than 540px full screen (about 28% less fragment area); hidden on menus and lowest quality. |
| 3 | CPU/memory | Reclaim all pads beyond camera trailing edge in a bounded loop; particles, floating labels, ripples have fixed limits. |
| 4 | Adaptive quality | 2s average frame budget; downgrade after two slow windows, recover after five fast windows; ignore app-switch stalls >120ms. Quality changes only affect visuals, not physics. |
| 5 | Jump game feel | Launch squash, airborne tilt, springy landing, reactive squash/stretch and combo feedback. |
| 6 | Touch precision | Touch finger ownership, landing preview and limited magnetism to valid pads; no forced ad interruption mid-jump. |
| 7 | Camera | Frame-rate-independent exponential follow, look-ahead while aiming and airborne, brief world-only screen shake. |
| 8 | Visual effects | Bounded splashes, water ripples, floating text, soft impact flashes and animated pads. |
| 9 | Readability | Clear aim indicator, warning for approaching wave, pause overlays, readable HUD. |
| 10 | Difficulty pacing | Biome-dependent pad radius, gap, lateral drift and river pressure; procedural generation remains endless. |
| 11 | Replay value | Infinite mode, deterministic daily route and local bests. |
| 12 | Structured progression | Six chapters, medal rewards and unlocking. |
| 13 | Cosmetics | Eight unlockable appearance variants, persistent leaves and wardrobe. |
| 14 | Android safety | 60 FPS cap, background pause, native OpenSL ES workaround, optional system tones (device verification still required). |
| 15 | Shipping | Android CI, smoke/retention tests, real game screenshots, Play Store assets and separate signed release workflow. Signing/AdMob/Play account setup still required. |

## Performance design

- Shader color/speed uniforms are updated **only on biome changes**, not per frame.
- The water shader is drawn in a **388px**-wide rect rather than the entire **540px** canvas; estimated fragment reduction `(540-388)/540 = 28.15%` for this overlay only, **not** a measured overall GPU gain.
- Quality settings never change pad positions, jump physics, score, or collision checks.
- Slow windows are filtered for app switching; recovery hysteresis prevents frequent toggling.
- No additional textures or external assets are required; offline gameplay remains available.

## Real-device release gate

1. Play 20–30 minutes on Redmi Android 15 with the new shader enabled.
2. Check sustained FPS, phone heat, memory and battery consumption; repeat at quality 0/1/2.
3. Check input during jumps, app-switch/resume and pause, and at least 3 chapters.
4. Verify that Android audio compatibility mode remains stable; optional system tones are not a proven universal fix.
5. Validate the monetized QA APK separately; do not confuse a test AAB with a signed production bundle.

**Scope:** These optimizations are source-level improvements with CI smoke tests. They are not substitutes for GPU profiling or release-device testing.
