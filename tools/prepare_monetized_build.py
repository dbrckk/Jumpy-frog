#!/usr/bin/env python3
"""Install pinned Godot Android AdMob + Play Billing plugins for monetized builds.

Use only during a Gradle-enabled monetized export. Offline gameplay builds do
not include network/ads/billing permissions or proprietary SDK binaries.
"""
from __future__ import annotations
import hashlib
import json
import os
from pathlib import Path
import shutil
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ASSETS = {
    "admob": (
        "https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/poing-godot-admob-v5.1.0.zip",
        "8c53ff52719edf6a81cc7d32a9cdaad2d9e11693c85faca25008a1c19355726f",
    ),
    "admob_android": (
        "https://github.com/poingstudios/godot-admob-plugin/releases/download/v5.1.0/android-template-v4.5.1.zip",
        "f7fdf644d50c0e231d8f02ae044057e489d0bcafcf50e908a4858477e7ee05ee",
    ),
    "billing": (
        "https://github.com/godot-sdk-integrations/godot-google-play-billing/releases/download/3.3.0/godot-google-play-billing.zip",
        "20d75623d6f337f08d8283c83098b73678d5f575e39247af5a8eb80588b18568",
    ),
}


def safe_extract(z: zipfile.ZipFile, destination: Path, prefix: str) -> int:
    count = 0
    for entry in z.infolist():
        if entry.is_dir():
            continue
        path = entry.filename
        if not path.startswith(prefix):
            continue
        name = Path(path.removeprefix(prefix))
        if not name.parts or name.is_absolute() or ".." in name.parts:
            raise ValueError(f"Unsafe archive path: {path}")
        target = destination.joinpath(*name.parts)
        target.parent.mkdir(parents=True, exist_ok=True)
        with z.open(entry) as src, target.open("wb") as dst:
            shutil.copyfileobj(src, dst)
        count += 1
    return count


def main() -> None:
    app_id = os.environ.get("ADMOB_APP_ID", "").strip()
    interstitial = os.environ.get("ADMOB_INTERSTITIAL_UNIT_ID", "").strip()
    rewarded = os.environ.get("ADMOB_REWARDED_UNIT_ID", "").strip()
    for label, value, token in (
        ("ADMOB_APP_ID", app_id, "~"),
        ("ADMOB_INTERSTITIAL_UNIT_ID", interstitial, "/"),
        ("ADMOB_REWARDED_UNIT_ID", rewarded, "/"),
    ):
        if not value.startswith("ca-app-pub-") or token not in value:
            raise SystemExit(f"Missing/invalid {label}; cannot produce monetized build")
    downloads = {}
    for name, (url, sha) in ASSETS.items():
        with urllib.request.urlopen(url, timeout=90) as response:
            contents = response.read()
        if hashlib.sha256(contents).hexdigest() != sha:
            raise RuntimeError(f"Checksum mismatch: {name}")
        cache = ROOT / ".monetization-cache"
        cache.mkdir(exist_ok=True)
        file = cache / (name + ".zip")
        file.write_bytes(contents)
        downloads[name] = file

    with zipfile.ZipFile(downloads["admob"]) as z:
        assert safe_extract(z, ROOT / "addons" / "admob", "poing-godot-admob/addons/admob/") > 100
    with zipfile.ZipFile(downloads["admob_android"]) as z:
        assert safe_extract(z, ROOT / "addons" / "admob" / "android" / "bin", "") > 5
    with zipfile.ZipFile(downloads["billing"]) as z:
        assert safe_extract(z, ROOT / "addons" / "GodotGooglePlayBilling", "GodotGooglePlayBilling/") >= 4

    template = ROOT / "monetization" / "admob_bridge.gd.template"
    shutil.copyfile(template, ROOT / "scripts" / "admob_bridge.gd")
    godot_settings = ROOT / "project.godot"
    text = godot_settings.read_text()
    if "[editor_plugins]" not in text:
        text += "\n[editor_plugins]\nenabled=PackedStringArray(\"res://addons/admob/plugin.cfg\", \"res://addons/GodotGooglePlayBilling/plugin.cfg\")\n"
    if "[admob]" not in text:
        text += "\n[admob]\ngeneral/android/enabled=true\ngeneral/android/app_id=%s\n" % json.dumps(app_id)
    if "[jumpy]" not in text:
        text += "\n[jumpy]\nmonetization/interstitial_unit_id=%s\nmonetization/rewarded_unit_id=%s\n" % (json.dumps(interstitial), json.dumps(rewarded))
    godot_settings.write_text(text)
    print("Monetized dependencies installed: AdMob 5.1.0 + Google Play Billing 3.3.0 (Billing 9.1.0).")


if __name__ == "__main__":
    main()
