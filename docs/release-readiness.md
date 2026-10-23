# Release gate for Jumpy Frog 1.3.0

**Code-ready does not mean Play-published.** The Google Play submission is blocked until every gate is verified.

## Build and security
- [x] Final release-candidate version 1.3.0, Android versionCode 5
- [x] Original artwork and no runtime dependencies on third-party servers
- [x] Monetization is opt-in at build time; ordinary debug APK remains offline and ad-free
- [x] API 36 Gradle AAB preset configured, real AdMob/UMP + Google Play Billing 9.1.0 integrated in monetized QA/release workflow
- [x] Gradle signed-release workflow defined, secrets kept outside Git
- [x] Unsigned-for-publication **debug AAB** successfully built and validated via the Android API 36 QA workflow
- [x] Original 512×512 store icon and 1024×500 feature artwork generated and checked
- [x] Four real screenshots (1080×1920) captured automatically from a running Godot build
- [ ] **Monetized production AAB signed with permanent private upload key, validated, and accepted** in Play Console (requires upload keystore secrets)
- [x] Android API 36 and 16 KiB native ELF/bundle alignment verified on QA AAB (Godot and monetized SDKs)
- [ ] The final signed production AAB must pass the same 16 KiB checks and Play Console review
- [ ] Android 16 edge-to-edge and API 36 behavior tested on device
- [ ] No native audio crash on the affected Redmi running the release candidate
- [x] Android OpenSL audio disabled; separate opt-in experimental Java system tones and haptics available
- [ ] Real-device confirmation that Android system tones do not reproduce the audio crash, and sound quality signoff

## Product
- [x] Endless river jumping, pickups, companions and increasing pressure
- [x] Six replayable chapters, stars, saved level unlocks, eight cosmetic styles and endless cyclical biomes
- [x] Deterministic 180 m daily challenge, one first-win leaf reward per UTC day and best-score persistence
- [x] Auto-pause on phone focus loss, including safe midair resume after notification/app switch
- [x] Precision-landing rewards and temporary current boost pads
- [x] Optional Android haptic feedback, with VIBRATE permission requested
- [x] Pause/resume, retry and local save. Offline debug has no network; monetized build uses network only for advertising and Google Play Billing
- [ ] 30-minute device soak test with suspend/resume, rotation lock and repeated app restarts
- [ ] Screen-reader/talkback and touch-accessibility manual audit
- [ ] Real-device rendering performance confirmed at steady frame rate

## Play Console
- [x] Listing draft in French and English
- [x] Public bilingual privacy policy hosted permanently: https://vector-array-z8pwj3f.shipstatic.com/privacy.html
- [ ] Verified developer account, identity and developer support email
- [ ] Upload generated 512×512 store icon, 1024×500 graphic and authentic screenshots in Play Console
- [ ] Data safety, content rating and target audience declarations completed **for the monetized version (Google Ads identifiers, AdMob and Billing)**
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

## Verified GitHub Actions evidence

- Android 1.0 debug APK + store artwork: https://github.com/dbrckk/Jumpy-frog/actions/runs/39219456272
- API 36 AAB format smoke test: https://github.com/dbrckk/Jumpy-frog/actions/runs/39219737629
- Four genuine portrait gameplay screenshots: https://github.com/dbrckk/Jumpy-frog/actions/runs/39219964989

The test AAB is debug-signed and **must never be uploaded as a production app**. The separate manually dispatched signed-release workflow requires the user's long-lived upload keystore and real device signoff.

## Revenue publication gates (1.1)

- [x] Persistent daily missions with three rotating daily sets, UTC clock-backwards protection, long-term progress and free unlockable skins
- [x] Actual Google AdMob plugin installed via hash-verified release packages in the monetized Gradle build
- [x] Actual Google Play Billing plugin v3.3.0 using Billing Library 9.1.0, product identifier `remove_ads`
- [x] Fail-closed UMP consent adapter; no advertising unless consent state is usable
- [x] Permanent non-consumable entitlement with restore, acknowledge, local verified cache and refund revocation on authoritative Google purchase query
- [x] Interstitial policy: 4-run minimum and 6-minute cooldown, score screen only; rewarded advertisements explicitly opt-in
- [x] Automated mission, save, payout and anti-frequency tests
- [ ] Google Play in-app product `remove_ads` configured with €2.00 French price and activated
- [ ] Real AdMob app/units and GDPR/UMP privacy message configured; real publisher IDs stored in GitHub Actions secrets
- [ ] Google Play signed monetized release built using real identifiers and published to internal test track
- [ ] Test purchase, restore, refunds, declined ad consent and actual rewarded video callback on Android device
- [ ] Play Console new Data safety, targeted audience and 'Contains ads' declarations verified and public privacy policy linked
- [ ] Long soak test on the specific Android 15 Redmi where Godot's OpenSL audio previously crashed

See [final 1.3.0 checklist](final-1.3.md) and [monetization manual](monetization.md). **The ordinary ad-free debug APK does not validate paid purchase or live ad revenue.**


## Version 1.2 physical-device checks

- [ ] Complete all six chapter routes at least once on the affected Redmi.
- [ ] Confirm 1–3 stars, persistent progress and earned bonus leaves after app restart.
- [ ] Verify the pause-screen haptic toggle works, and Android VIBRATE permission is present.
- [ ] Compare framerate across all six themed river environments.
- [ ] Confirm music is correctly available on desktop only; Android sound is not advertised as restored.


## v1.4 River Pass release gates (23 October 2026)

- In Play Console keep the **existing** non-consumable `remove_ads` rather than publishing a second product; use a River Pass title and description matching the lifetime Guardian + 12m wave head start + ad-free status.
- Set the France one-time product price **€2.00** through the Play Console price editor. Do not promise €2 worldwide: local prices/currencies and taxes are controlled by Google Play.
- All Android installable test packages and real-money flows must be tested with Play license testers/internal track and **test ad units** until an approved live configuration exists.
- A single voluntary rewarded video gives **5 leaves + one Guardian on the next actual run**, on the native earned callback only; never claim a guaranteed ad duration. No interstitial auto-inventory or forced popups are used.
- Import/install `org.dbrckk.jumpyfrog` from Play internal testing and verify purchase, restore after reinstall, refund/revoke behavior, and ad consent denied; none of these can be certified by desktop CI alone.
- Upload signed RELEASE AAB using `.github/workflows/play-release.yml` after adding all publisher and keystore secrets, and verify Google Play's API 36 / 16-KiB/ signing checks. **Do not use disposable CI QA signing credentials for production.**
- Update the French/English store listing and public privacy policy to describe optional Google rewarded advertising, ads/device data from its SDK, the lifetime IAP and no login. Verify developer contact/website, content rating, data safety, advertising declaration and age targeting in Play Console.
- Conduct a real Redmi Android 15 soak test (including a rewarded full-screen video, Billing, switching apps, screen-off/resume and ≥20 jumps). CI is not a substitute for this sign-off.

- Public bilingual v1.4 privacy policy deployment verified published: https://vector-array-z8pwj3f.shipstatic.com/privacy.html. Update this URL in Play Console and re-check the live text from an Android device before submitting.
