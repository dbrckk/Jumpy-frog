# Jumpy Frog 1.3.0 — final release candidate

**Status:** implementation and automated build verification are complete after the workflows below pass. **Public Google Play distribution is not authorized until the final Android physical-device, account and billing checks are completed.** The release requires developer-owned credentials that must never be shared in a chat or committed to Git.

## Shippable gameplay

- Endless mode, rotating through six illustrated environments.
- Six curated chapters with changing platform widths, lateral drift, wave pressure, saved level unlocks, and replayable bronze/silver/gold medals.
- An offline **Daily River**: a deterministic 180-meter route, best score and 25 leaves once per UTC day, with daily rollover/clock safeguards.
- Daily missions, nine lifelong milestones, record tracking, eight free-unlockable color styles, precision streaks, rescued companions, temporary wave-relief lily pads, pause and retry.
- Protected, persistent progress stored locally. Android app backgrounding also pauses the chase wave during an interrupted jump.

## Audio and vibration — Redmi native crash response

- Desktop: original procedural sound effects, river ambience and music.
- Android: Godot OpenSL audio remains **disabled** to avoid the recorded Redmi/Android-15 `libwilhelm.so` native crash.
- Android **Tones** button in Pause: experimental, disabled by default. Uses Android system `ToneGenerator` accessed by Godot's `JavaClassWrapper`; it does not re-enable Godot native mixing.
- Android **Vibrate** button: separate and optional; changes take effect immediately and are saved.
- Java initialization/playing errors fail closed. This feature is a **fallback** with basic beep feedback, not restored high-fidelity soundtrack.

Do **not** enable ToneGenerator by default for all customers until device testing demonstrates that it does not introduce any crashes.

## Privacy and revenue

- Free game with non-intrusive AdMob interstitials only at voluntary transitions after the score screen (at least four completed runs and six-minute cooldown).
- Rewarded video is optional, and leaves are granted only after a real SDK reward event. Refused/cancelled ads never issue a reward.
- Purchase `remove_ads`: one-time, non-consumable Google Play Billing item, intended **€2.00 in France**. Play Console defines the price, taxes and localized storefront display.
- Play Billing must confirm `PURCHASED`; `PENDING` does not unlock it. Signed-in purchase restores are queried; locally cached entitlements remain offline where previously verified.
- AdMob UMP consent required. If consent is unresolved or withdrawn, loaded ads and late-arriving ad responses are discarded.
- The monetized build **must** declare advertising SDK data handling and the in-app purchase in Play Console and link the [live public privacy policy](https://micro-matrix-a49rp83.shipstatic.com/privacy.html).

## Verified by automation (once green)

- Godot 4.5.1: project import without parse errors, gameplay smoke, chapter milestones, daily goals/ads, seeded Daily River, six-chapter + 155-hop endurance and Android lifecycle tests.
- Signed DEBUG APK (ordinary offline build), ZIP integrity, launcher icons, package metadata, APK signature.
- Monetized test APK and QA AAB with **real AdMob and Play Billing plugins**, official **Google test ad IDs**, ZIP and APK signature checks.
- QA AAB target Android 16 **API 36** and `bundletool validate`.
- All included native `.so` PT_LOAD segments verified to have **16 KiB** minimum alignment, plus `PAGE_ALIGNMENT_16K` in AAB bundletool configuration.
- Original Play Store icon, feature graphic, and four screenshots from the running Godot scene.

Official packaging requirement: https://developer.android.com/guide/practices/page-sizes

## Release build

The normal GitHub QA APK and QA AAB are **not** monetized production binaries. To create one:

1. In **Google Play Console**, enable Play App Signing, set up the package `org.dbrckk.jumpyfrog`, configure the one-time `remove_ads` product and intended €2.00 French price, verify tester accounts and tax/storefront settings.
2. In **AdMob**, register the same app and configure the GDPR/UMP consent message plus actual rewarded and interstitial ad units. Supply an app-ads.txt web page when required by AdMob.
3. In GitHub **Actions Secrets**, supply `PLAY_KEYSTORE_BASE64`, `PLAY_KEY_ALIAS`, `PLAY_KEY_PASSWORD`, `ADMOB_APP_ID`, `ADMOB_INTERSTITIAL_UNIT_ID`, and `ADMOB_REWARDED_UNIT_ID`. Keep permanent upload key and password private and backed up securely.
4. Trigger [Google Play signed monetized AAB](../.github/workflows/play-release.yml). The workflow is manually dispatched; it does not publish automatically. Download the `JumpyFrog-GooglePlay-Monetized-signed-AAB` artifact only after the release workflow reports success.
5. Upload to **Play Console internal testing**. Complete store screenshots, developer contact email, privacy policy, Data safety, `Contains ads` declaration, age rating and intended target audience.
6. Test on the Redmi that previously force-closed: 30+ minutes, device lock/unlock, screen/notification interruptions, fly+resume, six stages, daily challenge and 10+ app restarts. Test Android tones separately, both disabled and enabled; disable instantly if any crash occurs.
7. Via **Google Play testers**, purchase `remove_ads`, confirm no ads after purchase and after restart/reinstall, then test refunds/revocations and restore ownership. Test rewarded ads by verifying exactly one payout only after completion. Check UMP consent-denied behavior.
8. Comply with account-specific closed-test requirements and only then submit the signed release for Google review. Production approval and future revenue are not guaranteed.

## Release artifacts

- [Standard debug Android APK workflow](../.github/workflows/ci.yml).
- [Native AdMob + Billing integration test workflow](../.github/workflows/monetization-qa.yml).
- [API 36 and 16 KiB QA AAB workflow](../.github/workflows/play-aab-qa.yml).
- [Signed monetized release AAB workflow](../.github/workflows/play-release.yml).
- [Original store-art generator](../tools/generate_store_assets.py) and [real gameplay screenshot capture](../tests/capture_store.gd).

**Version:** `1.3.0` / Android `versionCode 5`. Because the debug CI generates a fresh signing identity on every run, installing it over an older debug APK can fail; uninstalling the old debug build normally clears its local save data.

## Final acceptance

- [x] Gameplay feature set frozen for this release candidate.
- [x] Export definitions and automated QA pipelines configured.
- [x] Permanent public bilingual privacy page: https://micro-matrix-a49rp83.shipstatic.com/privacy.html.
- [x] Verified earned-ad payouts persist even when a delayed native callback arrives after the result screen is left.
- [ ] All latest CI workflows green on the same exact final commit.
- [ ] Real-device Redmi crash regression signed off.
- [ ] Sound fallback approved (or opt-in kept off until fixed).
- [ ] Production signing secrets configured privately.
- [ ] Real Play product and AdMob/UMP IDs activated and payments tested.
- [ ] AAB accepted by Google Play internal test and then release reviewed.

**Until these last gates are closed, this is a playable final *release candidate*, not a publicly published app.**
