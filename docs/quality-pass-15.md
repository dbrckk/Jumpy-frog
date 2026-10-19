# Jumpy Frog — 15-pillar quality pass (Godot 4.5.1)

This document is the engineering acceptance checklist for the mobile 1.3 quality iteration. It deliberately distinguishes **implemented**, **CI-verified** and **requires Android hardware validation**. An emulator or headless Godot run cannot measure thermal throttling or certify a Redmi audio fix.

| # | Pillar | Engineering implementation | Test/acceptance |
|---|---|---|---|
| 1 | Touch precision | Single active touch index; secondary fingers cannot hijack the trajectory | `tests/touch_and_fairness.gd` |
| 2 | Predictive trajectory | One `_landing_target()` function shared by green preview and final jump; preview snaps to intended lily | `tests/smoke.gd` |
| 3 | Fair generated levels | Bounded gaps, lateral drift and collision radii; validate required physical swipe of every generated segment in all six biomes | `tests/touch_and_fairness.gd` |
| 4 | Jump game feel | Anticipation squash, sinusoidal airborne arc, interpolated lateral tilt and damped landing recovery | `tests/smoke.gd` |
| 5 | Reward feedback | Perfect-landings, streak feedback, companion and leaf bonuses; avoid unearned replay of rewards | `tests/smoke.gd`, `tests/retention_and_ads.gd` |
| 6 | Camera | Exponentially damped follow + 4m look-ahead on aiming/flying; shake affects illustrated world but not HUD | `scripts/game.gd`, `scripts/art.gd` |
| 7 | Mobile water shader | Original transparent GL-compatible `canvas_item` caustics shader, no scene-color samples, texture fetches or unbounded loops | `shaders/river_surface.gdshader`, import and screenshot CI |
| 8 | Visual readability | Hand-painted six-biome color scripts, pads with visible collision zones, safe/unsafe aim guide, warning HUD | `scripts/art.gd` |
| 9 | Frame-rate independent easing | `1-exp(-k*dt)` dampening for camera and character secondary motion; clamp giant frame deltas | `scripts/game.gd`, `tests/render_quality.gd` |
| 10 | CPU/GPU cost | Dynamic render detail tiers 2/1/0 with two slow 2-second windows to lower settings, five good windows to increase; cap Android at 60Hz | `scripts/game.gd`, `tests/render_quality.gd` |
| 11 | VFX memory control | Maximum 110 particles, 12 ripples and 8 labels, faded by delta time; automatically limit decoration at lower tiers | `tests/smoke.gd`, `tests/endurance.gd` |
| 12 | Difficulty curve | Six increasing biome hop rhythms, pad sizes, side drift and rising flood pressure | `scripts/chapters.gd`, `tests/chapters.gd` |
| 13 | UX and interruption | Pause/resume midair and on Android focus loss; touch cancellation on pause and no shader over menus | `tests/lifecycle.gd`, `tests/touch_and_fairness.gd` |
| 14 | Long-term retention | Six chapters + medals, cyclic endless river, daily seeded challenge, three daily missions, nine lifetime milestones, eight cosmetics | `tests/endurance.gd`, `tests/daily_river.gd` |
| 15 | Sound, haptics and stability | Original synthesized desktop soundtrack, optional Android vibration and experimental system tones **off by default**; native Godot Android audio stays disabled after observed crash | `scripts/audio.gd`, `tests/lifecycle.gd`; Redmi physical test required |

## Render-budget design

At **tier 2**, render all illustrated reeds, surface arcs, drifting bands, flow lines, glints and shader caustics. Tier **1** halves expensive decoration and lowers shader intensity. Tier **0** preserves river silhouette, lily collision outlines and all vital HUD while disabling caustic shader and reducing most purely decorative water primitives. Rendering quality **never affects** player input, hit detection, procedural geometry, waves, scoring or purchases.

The automatic system uses only accumulated frame deltas from the active run. It downgrades after two consecutive 2-second windows averaging slower than 40 FPS, and upgrades only after five consecutive windows faster than about 55 FPS. This hysteresis prevents quality switching rapidly under intermittent load. Godot `TIME` animates the shader on the GPU, avoiding per-frame CPU uniform uploads. A 60 FPS cap on Android limits wasteful refresh work on 90/120Hz phones.

This is an **adaptive heuristic, not measured on-device optimization**. The renderer is still vector-heavy and the 540×960 Compatibility backend may behave differently across GPUs.

## CI and regression policy

- `tests/render_quality.gd`: shader is installed, cannot intercept touches, stays hidden on menus, 2→1→0→2 quality hysteresis, collision unchanged.
- `tests/touch_and_fairness.gd`: multi-touch ownership and 100+ generated pads in each of six biomes reachable using the game's exact 215-pixel gesture mapping.
- Existing suites cover gesture prediction, VFX bounds, campaign, 155-hop endurance, daily rewards, ads and lifecycle pause.
- Rebuild and validate both ordinary Android APK and Gradle monetized test AAB/APK.

## Remaining **non-negotiable** acceptance

1. Android 15 Redmi: 30+ minutes at 60Hz, 155+ hops, all biomes, touch multitasking and lock/unlock.
2. Hardware profiler comparison: frame-time percentiles (p50/p95/p99), actual draw calls, GPU usage, power and temperature. Compare tiers 2 vs 1 vs 0; screenshots and headless CI cannot prove GPU speedups.
3. The reported `libwilhelm.so` OpenSL crash must remain absent; Android system tones should stay disabled until explicitly accepted. Do not enable Godot native audio just to claim a complete soundtrack.
4. Real AdMob consent, Google Play `remove_ads` checkout/refund and signed AAB still need developer account validation. No simulated IAP revenue is claimed.

This quality pass is a **functional regression-tested candidate**, not a substitute for a physical performance lab or Google Play approval.
