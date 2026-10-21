#!/usr/bin/env bash
# Android 15 emulator smoke test of the exported, installable Godot APK.
# This checks launch/interaction/background/force-stop; it cannot certify a Redmi GPU.
set -Eeuo pipefail
APP_ID="org.dbrckk.jumpyfrog"
APK="build/JumpyFrog-emulator.apk"
OUT="build/emulator-qa"
mkdir -p "$OUT"

collect_evidence() {
  adb logcat -d -v threadtime > "$OUT/logcat.txt" 2>/dev/null || true
  adb exec-out screencap -p > "$OUT/final-screen.png" 2>/dev/null || true
  adb shell dumpsys meminfo "$APP_ID" > "$OUT/meminfo.txt" 2>/dev/null || true
}
trap collect_evidence EXIT

test -s "$APK"
adb wait-for-device
adb install -r "$APK"
adb shell wm size 540x960
adb logcat -c

assert_running() {
  local process_id
  process_id="$(adb shell pidof "$APP_ID" | tr -d '\r' || true)"
  if [[ -z "$process_id" ]]; then
    echo "FAIL: $APP_ID process terminated unexpectedly."
    return 1
  fi
  echo "PASS: $APP_ID running (pid=$process_id)"
}

launch() {
  adb shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1
  for attempt in $(seq 1 15); do
    if adb shell pidof "$APP_ID" | grep -Eq '[0-9]'; then
      return 0
    fi
    sleep 1
  done
  echo "FAIL: app did not start after 15 seconds"
  return 1
}

launch
sleep 7
assert_running
adb exec-out screencap -p > "$OUT/title.png"
# Tap start (not one of the title's smaller navigation buttons), then aim.
adb shell input tap 250 780
sleep 1
adb shell input swipe 260 630 265 850 350
sleep 3
assert_running
adb exec-out screencap -p > "$OUT/first-run.png"

# Verify a background/foreground transition while the game is active.
adb shell input keyevent KEYCODE_HOME
sleep 2
launch
sleep 3
assert_running
# The game may show the safe pause overlay; resume without forcing progress.
adb shell input tap 265 488
sleep 2
assert_running

# Repeat cold starts to catch process initialization/shutdown regressions.
for pass in 1 2; do
  adb shell am force-stop "$APP_ID"
  sleep 2
  launch
  sleep 5
  assert_running
done

collect_evidence
python3 - <<'PY'
from pathlib import Path
import re
text = Path("build/emulator-qa/logcat.txt").read_text(errors="replace")
lines = text.splitlines()
for i, line in enumerate(lines):
    if re.search(r"FATAL EXCEPTION|Fatal signal|libwilhelm\.so", line, re.I):
        surrounding = "\n".join(lines[max(0, i-12):i+36])
        if re.search(r"org\.dbrckk\.jumpyfrog|GodotAndroidThread|libwilhelm\.so", surrounding, re.I):
            raise SystemExit("FAIL: Godot/app-related Android crash marker in emulator logcat")
for name in ("title.png", "first-run.png", "final-screen.png"):
    p = Path("build/emulator-qa") / name
    data = p.read_bytes()
    assert data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) > 10000, name
print("PASS: Android 15 app launch, touch, background/resume, cold starts, screenshots and crash-log scan")
PY
