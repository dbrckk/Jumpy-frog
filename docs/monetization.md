# Jumpy Frog monetization — real AdMob + Google Play Billing

This is a production implementation, not a local ad simulator. The ordinary offline/debug build remains ad-free without ad SDKs. **Revenue requires a monetized Gradle Android build, registered Google services and actual app-store distribution.**

## Business model (Play v1.4)

- The game remains playable for free: all chapters, Endless and Daily River are available without payments or ads.
- **No automatic advertisements.** Interstitial display/preload is disabled. Retry, Home, pause, and losing never open an ad.
- **Explicit voluntary rewarded video:** at the results screen, only a deliberate tap on `WATCH OPTIONAL VIDEO` invokes the native AdMob rewarded unit. The `OnUserEarnedRewardListener` confirms completion; only then does the game grant **+5 leaves** and **one Guardian protection on the next actual run**. Closing the ad prematurely or lacking inventory/consent pays nothing; earned boosts persist in the save if the player leaves the results screen.
- **Lifetime River Pass (existing Google Play non-consumable SKU `remove_ads`):** intended price **€2.00 in France**, configured in Play Console; the displayed price must come from Play Billing, never a hardcoded promise. Existing owners get the additional benefits automatically: **one Guardian rescue on every new run** and **12 metres extra lead over the wave** every run. It also removes any ads. Product ownership is restored via Billing, acknowledged, and revoked on an authoritative refund query; the premium perk is not fabricated from a click.
- Google/AdMob determines video length, creative type, and whether reward inventory is available. Do not advertise a guaranteed video duration.
- **No subscription, paywall for mandatory progression, purchase of leaves, or real-world gambling.** Records remain playable for all, though paid runs have a disclosed survival advantage.

## Pinned and verified components

- [Poing Studios AdMob Plugin 5.1.0](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0) (MIT; AdMob + Google UMP)
- [Godot Google Play Billing 3.3.0](https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/tag/3.3.0) (Billing Library 9.1.0)
- `tools/prepare_monetized_build.py`: pins exact ZIP SHA256 digests, validates them before extraction, copies the AdMob bridge and injects the Gradle plugin setup into the **CI workspace only**.
- No plugin binaries, private signing keys or real store credentials are committed.

## Required actions outside GitHub

1. Register Jumpy Frog in **Google Play Console** with package `org.dbrckk.jumpyfrog`, complete developer identity and set up Play App Signing.
2. Under **Monetize → Products → In-app products**, create and activate the existing product ID **`remove_ads`**, **one-time purchase, non-consumable**, priced at **€2.00 for France**, with a title/description reflecting the **lifetime River Pass (Guardian on every run + 12m wave head start + ad-free)**; retain the same SKU to honor former purchasers. Activate a permanent **Buy** purchase option (not Rent). The application automatically discovers its real `purchase_option_id` and localized price from the Play Billing 3.3.0 product response. Local pricing and taxes are decided/displayed by Google Play; a purchase in another territory may have another currency/price.
3. Register the app in [Google AdMob](https://admob.google.com/), create one **Rewarded** ad unit (no interstitial unit is necessary), complete the **Privacy & messaging / GDPR UMP** configuration, and configure the required consent message and ad technology partners. Do not run live ads before completing privacy disclosure/consent setup.
4. For advertising EU users, confirm CMP/Google policy compatibility and the public [privacy policy](privacy-policy.md); populate the Play Console **Data safety** declarations for Google Mobile Ads and Play Billing. The old 'no data collected' declaration is **not valid for the monetized version**.
5. Maintain an **app-ads.txt** file at a verified website domain according to AdMob instructions. Use your real publisher ID; do not copy another publisher's record.
6. In GitHub **Settings → Secrets and variables → Actions**, add:
    - `ADMOB_APP_ID` = `ca-app-pub-<publisher>~<app>`
    - `ADMOB_REWARDED_UNIT_ID` = `ca-app-pub-<publisher>/<rewarded-unit>`
    - `PLAY_KEYSTORE_BASE64`, `PLAY_KEY_ALIAS`, `PLAY_KEY_PASSWORD` from the secure signing guide in [release-readiness](release-readiness.md)
7. Use GitHub Actions **Monetized Android SDK QA** to verify the native Gradle integration with Google's **official test ad unit IDs**. This build is **not a publicly usable paid app**.
8. Use **Google Play signed monetized AAB** workflow only after closed testing and real-device signoff. Download its AAB artifact and upload to Play Console **internal testing**, then follow the required closed tests / approval path.

Do **not** put signing passwords in a chat message, commit them to Git, or share the keystore file.

## UMP and client behavior

At launch the native ad bridge calls UMP `consent_information.update()`. Ads load only after `OBTAINED` or `NOT_REQUIRED`; failures and `REQUIRED` without a completed form are **fail-closed**. The pause screen offers **Privacy options** when the native AdMob bridge is available.

A Google purchase is unlocked only after receiving `PurchaseState.PURCHASED` for `remove_ads`. `PENDING` is not owned. Non-consumable products are **acknowledged** (never consumed), and prior purchases queried on each connection. A local verification cache allows offline ad-free play after successful ownership verification.

For stronger anti-fraud guarantees and cross-device verification at scale, add a backend using the Google Play Developer API and a service account. The current client-side verification is appropriate for an initial small game but is not a fraud-proof server authority.

## Sound / Android 15

The affected Redmi crashed in the **native Godot OpenSL ES audio callback**. Android game audio remains in silent compatibility mode. AdMob itself can play video through Android media services; **test the monetized QA build on the affected Redmi** before any public rollout. Audio crash prevention is not proven by headless CI.

## Release verification checklist

- [ ] Google Play Console active product `remove_ads`, real local price verified
- [ ] AdMob app ID/ad units linked to the right package, UMP consent message active
- [ ] Data safety declaration and privacy policy linked correctly
- [ ] Test ads load on an approved device; real ads never used in development
- [ ] Reward callback grants exactly 5 leaves and one persisted next-run Guardian, only after the earned callback
- [ ] No unsolicited advertisements on retries, game-over screens, pause or gameplay
- [ ] A real Play test purchase restores a per-run Guardian and 12m wave relief, even after reinstall; refunds/revocations investigated
- [ ] Consent denied/offline: no ads, still fully playable
- [ ] Signed release AAB targets Android API 36, compatible with 16 KB pages, verified through Play Console
- [ ] Redmi Android 15 extended soak test after adding the native SDKs
- [ ] Play content ratings and audience declaration reviewed (not child-targeted)

Never claim purchase success, show made-up ad revenue or unlock a paid feature without a genuine Play Billing response.

## Account preflight

Use [Google Play readiness preflight](https://github.com/dbrckk/Jumpy-frog/actions/workflows/play-preflight.yml) on `main` after setting the five secrets. It checks formats, validates a copy of the upload key in ephemeral CI memory and reports a redacted summary. It does **not** access your real Play Console or AdMob accounts, activate products, or publish a release.
