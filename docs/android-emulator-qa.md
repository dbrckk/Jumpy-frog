# Android 15 emulator visual QA — release gate

Assessed 2026-10-21; Godot 4.5.1, Android API 35, x86_64 emulator.

## Verified

- GitHub Actions builds, signs and validates the normal Android debug APK. The eight headless Godot test suites pass with no reported leaked instances.
- The monetization QA test bundle builds with the real SDK integrations and Google sample advertising IDs, but does not prove live advertising or Play payments.
- The emulator installs/launches an emulator-only x86_64 APK and the application process survives several background/foreground cycles and restarts.

## Not verified: visible playable game on emulator

The emulator has NOT yet produced a confirmed playable Godot game frame in the automated visual QA. Earlier successful process-only checks were false positives. A first-run Android full-screen permissions hint and the OS frog icon launch splash had been misidentified as game output.

The smoke script now dismisses the Android immersive onboarding screen and rejects the known OS splash and flat-color frames. It waits a bounded time for genuine gameplay instead of accepting a running process as sufficient proof.

## Reproduced renderer issues

- Compatibility/OpenGL ES under emulator SwiftShader: flat clear-color image. The logs report CanvasShaderGLES3 program linking failures and fragment active uniforms exceeding GL_MAX_FRAGMENT_UNIFORM_VECTORS (261). [Run](https://github.com/dbrckk/Jumpy-frog/actions/runs/39567913031).
- Emulator-only Vulkan Mobile on SwiftShader: dark frames and Vulkan presentation errors. [Run](https://github.com/dbrckk/Jumpy-frog/actions/runs/39568695998).
- Emulator-only Vulkan Mobile with Mesa Lavapipe: the process remains alive, but screenshots captured the Android frog launch splash followed by black frames, rather than playable Godot graphics. [Run](https://github.com/dbrckk/Jumpy-frog/actions/runs/39569938886).

The Vulkan renderer override was applied ONLY inside the emulator CI checkout. Production Godot Compatibility rendering and Android Dummy audio remain unchanged.

## CI policy

The normal Android build and all headless suites remain automatic on main. The Android 15 runtime emulator smoke is available manually under Actions > Android 15 runtime emulator smoke > Run workflow, until a reliable software GPU configuration is available. An emulator success based solely on Android process liveness must not be reported as working gameplay.

## Outstanding release checks

1. Obtain actual game menu/gameplay screenshots from an Android emulator with a compatible GPU and verify gesture-driven scene changes.
2. On the affected Redmi Android 15 test at least 30 minutes, including navigation, hops, app switch, pause/resume, multiple cold starts and native crash logs. In particular check the previous libwilhelm audio failure.
3. Re-enable full Android audio only when a safe backend is verified on the real device; the Dummy workaround must remain otherwise.
4. With a correctly signed Google Play internal testing build, test live Billing, restore/refunds, UMP consent and AdMob earned-reward callbacks. Headless billing response tests do not replace an actual checkout.