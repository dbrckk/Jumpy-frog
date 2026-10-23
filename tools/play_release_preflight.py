#!/usr/bin/env python3
"""Read-only production release audit. Never prints credentials or key bytes.

Available as manual GitHub Actions dispatch; no Google account access needed.
Checks exact repository release metadata and validates private variables *only*
when they were explicitly provided through GitHub Actions encrypted secrets.
"""
from __future__ import annotations

import base64
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
results: list[tuple[str, bool, str]] = []


def check(name: str, ok: bool, action: str) -> None:
    results.append((name, ok, action))


def read(relative_path: str) -> str:
    return (ROOT / relative_path).read_text(encoding="utf-8")


export = read("export_presets.cfg")
settings = read("project.godot")
billing = read("scripts/monetization.gd")
bridge = read("monetization/admob_bridge.gd.template")
policy = read("docs/privacy-policy.md")
store = read("docs/play-store-listing.md")

check("Package identity", export.count('package/unique_name="org.dbrckk.jumpyfrog"') == 2,
      "Align the package ID in both export presets.")
check("Version code", export.count("version/code=6") == 2 and
      export.count('version/name="1.4.0"') == 2,
      "Both Android export presets should use 1.4.0 (code 6); increase code for later uploads.")
check("Google Play target", 'gradle_build/target_sdk="36"' in export and
      'gradle_build/export_format=1' in export,
      "AAB must target API 36 via Gradle.")
check("Android 15 crash workaround", 'driver/driver.android="Dummy"' in settings,
      "Do not re-enable Android native audio until the Redmi is stable.")
check("Rewarded-only advertising", "_load_interstitial()" not in
      bridge.split("func _initialize_ads() -> void:", 1)[1].split("func _load_interstitial()", 1)[0] and
      "return false" in billing.split("func request_break_interstitial() -> bool:", 1)[1].split("func can_watch_rewarded()", 1)[0],
      "Remove any automatic interstitial advertising for v1.4.")
check("One-time paid SKU", 'PRODUCT_ID := "remove_ads"' in billing and
      "purchase_option_id" in billing and "billing.purchase(PRODUCT_ID, purchase_option_id)" in billing,
      "Keep the old remove_ads product and select the confirmed Buy option.")
check("Bilingual privacy declaration", "## Français" in policy and
      "## English" in policy and
      "https://vector-array-z8pwj3f.shipstatic.com/privacy.html" in policy,
      "Publish current French/English policy and update the link.")
check("Store copy", "River Pass" in store and "Aucune publicité imposée" in store,
      "Update Play listing to the rewarded-only River Pass model.")
check("Real Google Play signing workflow", (ROOT / ".github/workflows/play-release.yml").exists() and
      "REQUIRE_LIVE_ADMOB_IDS" in read(".github/workflows/play-release.yml"),
      "Run the production AAB workflow, not the test-only build.")

app = os.environ.get("ADMOB_APP_ID", "").strip()
rewarded = os.environ.get("ADMOB_REWARDED_UNIT_ID", "").strip()
encoded_key = os.environ.get("PLAY_KEYSTORE_BASE64", "").strip()
alias = os.environ.get("PLAY_KEY_ALIAS", "").strip()
password = os.environ.get("PLAY_KEY_PASSWORD", "")

check("AdMob application ID", bool(re.fullmatch(r"ca-app-pub-(\\d{16})~\\d+", app)) and
      not app.startswith("ca-app-pub-3940256099942544"),
      "Add a REAL ADMOB_APP_ID under GitHub Actions repository secrets.")
check("Rewarded ad unit", bool(re.fullmatch(r"ca-app-pub-(\\d{16})/\\d+", rewarded)) and
      not rewarded.startswith("ca-app-pub-3940256099942544") and
      app.split("~", 1)[0] == rewarded.split("/", 1)[0],
      "Add ADMOB_REWARDED_UNIT_ID from the same publisher (not a Google test ID).")

key_ok = False
if encoded_key and alias and password:
    try:
        key_bytes = base64.b64decode(encoded_key, validate=True)
        if 1000 <= len(key_bytes) <= 32768:
            with tempfile.TemporaryDirectory(prefix="jumpy-signing-check-") as temp:
                filename = Path(temp) / "upload-key.jks"
                filename.write_bytes(key_bytes)
                filename.chmod(0o600)
                finished = subprocess.run(
                    ["keytool", "-list", "-keystore", str(filename),
                     "-alias", alias, "-storepass", password],
                    stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    timeout=30, check=False,
                )
                key_ok = finished.returncode == 0
    except (ValueError, OSError, subprocess.TimeoutExpired):
        key_ok = False
check("Google Play upload signature", key_ok,
      "Set PLAY_KEYSTORE_BASE64, PLAY_KEY_ALIAS and PLAY_KEY_PASSWORD for your EXISTING Play upload key.")

summary = ["# Jumpy Frog 1.4 · Google Play preflight", "",
           "This audits GitHub configuration only. It does not access Play Console or AdMob.",
           "",
           "| Check | Status | Next action if needed |", "|---|---|---|"]
for label, ok, action in results:
    summary.append(f"| {label} | {'PASS' if ok else 'ACTION NEEDED'} | {'—' if ok else action} |")
summary.extend(["", "## External checks still required",
                "1. Play Console: correct existing app ID, active permanent Buy option `remove_ads` priced €2 in France, data safety, contact, ratings, privacy link.",
                "2. AdMob: Rewarded unit active, UMP consent ready, app-ads.txt published with YOUR publisher ID on the listed developer website.",
                "3. Internal Play track: upload signed production AAB and verify paid test purchase, restore, rewarded ad and Android 15 Redmi stability.",
                "",
                "Secrets and keystore contents were not written to these logs or to artifacts."])
output = "\n".join(summary) + "\n"
summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
if summary_path:
    with open(summary_path, "a", encoding="utf-8") as dst:
        dst.write(output)
print("JumpyFrog Play release readiness: " +
      str(sum(good for _, good, _ in results)) + "/" + str(len(results)) +
      " checks passed. See the GitHub Actions job summary for next steps.")
raise SystemExit(0 if all(good for _, good, _ in results) else 1)
