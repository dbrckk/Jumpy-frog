# Release gate for Jumpy Frog 1.0

**Code-ready does not mean Play-published.** The Google Play submission is blocked until every gate is verified.

## Build and security
- [x] Version bumped to 1.0.0 (versionCode 2)
- [x] Original artwork and no runtime dependencies on third-party servers
- [x] No in-app purchases or ad SDK
- [x] API 36 Gradle AAB export preset configured
- [x] Gradle signed-release workflow defined, secrets kept outside Git
- [ ] AAB **built, signed, inspected and accepted** by Play Console (requires upload keystore secrets)
- [ ] 16 KB page-size support validated on the actual AAB/native libraries
- [ ] Android 16 edge-to-edge and API 36 behavior tested on device
- [ ] No native audio crash on the affected Redmi running the release candidate
- [ ] Stable, audible sound restored and tested without the native audio callback crash

## Product
- [x] Endless river jumping, pickups, companions and increasing pressure
- [x] Local progression and unlockable cosmetic styles
- [x] Pause/resume, retry, offline save and no runtime network access
- [ ] 30-minute device soak test with suspend/resume, rotation lock and repeated app restarts
- [ ] Screen-reader/talkback and touch-accessibility manual audit
- [ ] Real-device rendering performance confirmed at steady frame rate

## Play Console
- [x] Listing draft in French and English
- [x] Public privacy policy source available in repo
- [ ] Verified developer account, identity and developer support email
- [ ] Final 512×512 store icon, 1024×500 feature graphic and real gameplay screenshots uploaded
- [ ] Data safety, content rating and target audience declarations completed
- [ ] Closed test requirements fulfilled if required for the developer account
- [ ] AAB uploaded first to internal testing, then closed testing
- [ ] Release manually submitted for review (never automatic without permission)

## Signing: REQUIRED PRIVATE USER ACTION

Generate or select a **long-lived, private upload key** and keep a secure offline backup. Do not commit the key or passwords. With JDK 17 installed:

```bash
keytool -genkeypair -v -keystore jumpy-play-upload.jks -alias jumpy-upload -keyalg RSA -keysize 3072 -validity 10000
base64 -w0 jumpy-play-upload.jks
```

Set three GitHub Actions repository secrets (**Settings → Secrets and variables → Actions**):

- `PLAY_KEYSTORE_BASE64`: output of the last command (use `base64 -i jumpy-play-upload.jks | tr -d '\n'` on macOS).
- `PLAY_KEY_ALIAS`: the alias `jumpy-upload`.
- `PLAY_KEY_PASSWORD`: the keystore password (must also be the key password).

Then **Actions → Google Play signed AAB → Run workflow**. If successful, download `JumpyFrog-GooglePlay-signed-AAB`, verify it and upload to the Play Console internal testing track. Once Play App Signing is enabled, do not rotate upload keys casually.

The existing debug APK workflow generates an ephemeral key per run; it is **not** suitable for publishing and can require uninstalling the previous debug build.

Sources:
- https://support.google.com/googleplay/android-developer/answer/11926878
- https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_android.html
- https://developer.android.com/guide/practices/page-sizes
- https://support.google.com/googleplay/android-developer/answer/14151465

## Honest status

This release is a serious internal-testing candidate. It is **not** a publicly releasable binary while the native Redmi audio issue and device/Play Console gates are open.
