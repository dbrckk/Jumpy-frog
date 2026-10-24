#!/usr/bin/env python3
"""Fail a Play build if its *compiled* Android bundle omits Billing permission.

Google Play Console does not allow creation of one-time in-app products until
it has processed a build that declares com.android.vending.BILLING.
The manifest used for this check comes from bundletool, NOT the Godot preset.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print("Usage: verify_play_billing_permission.py PATH_TO_AAB [BUNDLETOOL_JAR]", file=sys.stderr)
        return 2
    bundle = Path(sys.argv[1])
    jar = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("/tmp/bundletool.jar")
    if not bundle.is_file() or not jar.is_file():
        print("ERROR: Play AAB or bundletool.jar is missing", file=sys.stderr)
        return 2
    result = subprocess.run(
        ["java", "-jar", str(jar), "dump", "manifest",
         f"--bundle={bundle}", "--module=base"],
        capture_output=True, text=True, timeout=45, check=False
    )
    if result.returncode != 0:
        print("ERROR: failed to inspect AAB AndroidManifest with bundletool", file=sys.stderr)
        return 1
    manifest = result.stdout
    if "com.android.vending.BILLING" not in manifest:
        print("ERROR: compiled Play bundle is missing com.android.vending.BILLING.", file=sys.stderr)
        print("Enable this permission in Play export preset before uploading an AAB.", file=sys.stderr)
        return 1
    if "<uses-permission" not in manifest and "<uses-permission-sdk" not in manifest:
        print("ERROR: Billing string found but not as a manifest permission", file=sys.stderr)
        return 1
    print("PASS: compiled Android AAB declares com.android.vending.BILLING.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
