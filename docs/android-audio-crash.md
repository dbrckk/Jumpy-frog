# Android 15 native audio crash — compatibility hotfix

## Report (2026-10-19)

Device: Xiaomi Redmi `kunzite`, Android 15 / HyperOS 2.0.205.0, `arm64`.
The supplied native stack has:
- `libgodot_android.so` (Godot 4.5.1 official export template)
- `libwilhelm.so: audioTrack_handleMoreData_lockPlay`
- `libaudioclient.so: AudioTrack::processAudioBuffer`

The fault appears on the **Android audio callback thread**. This is strongly consistent with the OpenSL ES output path, but the backtrace was not symbolicated and does not prove that the custom synthesized sounds were the direct trigger.

## Hotfix: stability first

- `project.godot` chooses `audio/driver/driver.android = "Dummy"`. Godot must select this driver during engine startup, before the scene loads.
- `scripts/audio.gd` immediately skips stream generation, player instantiation and loop playback when `OS.has_feature("android")`.
- `scripts/game.gd` marks audio temporarily unavailable on Android without overwriting the player's saved preference for other builds.
- All other platforms retain the nine original synthesized sound effects and ambient loop.
- `tests/smoke.gd` verifies the project override plus the regular audio/gameplay tests. CI also exports and signs the Android APK.

**Tradeoff: this build is intentionally silent on Android.** Re-enable only after physical-device and regression testing, or when a compatible native audio backend is confirmed. Merely lowering the audio volume will not avoid entering the native callback thread.

## Installing a new debug APK

Retrieve the successful latest workflow artifact from
https://github.com/dbrckk/Jumpy-frog/actions

Important: the workflow currently creates an ephemeral debug keystore on each run. Different builds have different signing identities. A newer APK may therefore **fail to install over an older one**. If that occurs, first uninstall the old debug app, then install the new APK. Uninstalling normally clears locally saved records. Avoid uninstalling if preserving that data is important, pending a production keystore.

For adb (from a PC):

```bash
adb uninstall org.dbrckk.jumpyfrog
adb install JumpyFrog-debug.apk
adb logcat -c
adb shell monkey -p org.dbrckk.jumpyfrog -c android.intent.category.LAUNCHER 1
adb logcat -d -v threadtime | grep -E 'godot|Godot|libwilhelm|FATAL|signal 11|signal 6|crash' > jumpy-frog-logcat.txt
```

The crash reporter's original unsymbolicated frames can be investigated using the **matching** official Godot `4.5.1.stable` Android native debug symbols and the exact exported library build ID. See:
https://docs.godotengine.org/en/stable/tutorials/platform/android/resolving_crashes_on_android.html

## Exit criteria

This issue is only closed when an updated APK:
1. Opens on the affected Redmi handset without force-closing.
2. Survives multiple hops, water splashes, pickups, pause/resume and repeated restarts.
3. Has no native `libwilhelm` crash in device logs.
4. Eventually restores audio using a separately verified Android-safe implementation.

Headless CI tests or package signature checks alone **cannot** establish (1)–(3).


## v1.2 audio status

Android audio remains deliberately off to avoid the reported native Godot OpenSL ES callback failure. Android now has optional short vibration feedback on jumps, pickups and wins, backed by the Android VIBRATE permission. This should be tested on the affected Redmi, and does not demonstrate that the original audio crash is resolved. Desktop builds include an original musical loop; it is not active on Android.
