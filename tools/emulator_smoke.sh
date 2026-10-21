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

# Unlike a real GPU, software Vulkan can take 20+ seconds to compile
# its first pipeline. pidof() alone does not prove Godot has drawn a frame.
wait_for_game_frame() {
  local target="$1"
  local frame_state
  for attempt in $(seq 1 35); do
    adb exec-out screencap -p > "$target"
    frame_state="$(python3 - "$target" <<'PYIMG'
from PIL import Image
import sys
im=Image.open(sys.argv[1]).convert('RGB')
if im.size != (540, 960):
    print('bad_size')
    raise SystemExit
samples=[im.getpixel((x,y)) for y in range(160,820,15) for x in range(40,500,15)]
overlay=sum(rgb==(238,237,244) for rgb in samples)/len(samples)
splash=sum(rgb==(241,240,247) for rgb in samples)/len(samples)
spread=max(hi-lo for lo,hi in im.getextrema())
if overlay>0.20:
    print('overlay')
elif splash>0.25:
    # Android shows the application's large frog launcher icon before
    # Godot draws its first game frame: do not mistake it for gameplay.
    print('splash')
elif spread<55 or len(open(sys.argv[1],'rb').read())<10000:
    print('flat')
else:
    print('ready')
PYIMG
)"
    if [[ "$frame_state" == "ready" ]]; then
      echo "PASS: live illustrated game frame detected after attempt $attempt"
      return 0
    elif [[ "$frame_state" == "overlay" ]]; then
      # Dismiss the Android immersive onboarding once, not the game's UI.
      adb shell input tap 377 746
    fi
    sleep 2
  done
  echo "FAIL: no rendered game frame after bounded emulator startup wait"
  return 1
}

launch
wait_for_game_frame "$OUT/title.png"
assert_running
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

wait_for_game_frame "$OUT/final-screen.png"
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
from PIL import Image, ImageChops
for name in ("title.png", "first-run.png", "final-screen.png"):
    p = Path("build/emulator-qa") / name
    data = p.read_bytes()
    assert data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) > 10000, name
    im = Image.open(p).convert("RGB")
    assert im.size == (540, 960), (name, im.size)
before = Image.open("build/emulator-qa/title.png").convert("RGB")
after = Image.open("build/emulator-qa/first-run.png").convert("RGB")
diff = ImageChops.difference(before, after).convert("L")
changed = sum(count for index, count in enumerate(diff.histogram()) if index > 30)
assert changed > 0.03 * before.width * before.height, (
    f"Touch did not visibly change game screen: only {changed} altered pixels")
print("PASS: Android 15 app launch, visible gameplay, touch, lifecycle, screenshots and crash-log scan")
PY
