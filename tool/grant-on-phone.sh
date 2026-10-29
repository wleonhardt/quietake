#!/usr/bin/env bash
# On phones whose shell may not grant runtime permissions (OxygenOS), answer the
# camera and microphone dialogs once by tapping them through uiautomator while
# the capture e2e brings the camera up. The grants survive later installs as
# long as the app is not uninstalled (tool/e2e.sh passes --no-uninstall).
#
#   tool/grant-on-phone.sh <adb-device-id>
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="$1"
APP=cam.quietake.app.dev
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$SDK/platform-tools/adb"
a() { "$ADB" -s "$DEVICE" "$@"; }

granted() {
  a shell dumpsys package "$APP" | grep -q "android.permission.$1: granted=true"
}
if granted CAMERA && granted RECORD_AUDIO; then echo "already granted"; exit 0; fi

flutter build apk --debug >/dev/null
python3 tool/dev_identity.py build/app/outputs/flutter-apk/app-debug.apk
flutter test integration_test/capture_test.dart -d "$DEVICE" --no-uninstall >/tmp/quietake-grant.log 2>&1 &
TEST=$!
for _ in $(seq 1 90); do
  sleep 2
  if granted CAMERA && granted RECORD_AUDIO; then echo "granted: camera + microphone"; break; fi
  a shell uiautomator dump /sdcard/ui.xml >/dev/null 2>&1 || continue
  # Prefer "While using the app"; fall back to any Allow button.
  TAP=$(a shell cat /sdcard/ui.xml | python3 -c '
import sys,re
x=sys.stdin.read()
best=None
for m in re.finditer(r"<node[^>]*?text=\"([^\"]*)\"[^>]*?bounds=\"\[(\d+),(\d+)\]\[(\d+),(\d+)\]\"", x):
    t=m.group(1).strip().lower()
    c=((int(m.group(2))+int(m.group(4)))//2,(int(m.group(3))+int(m.group(5)))//2)
    if "while using" in t: best=c; break
    if t.startswith("allow") and best is None: best=c
if best: print(best[0], best[1])
')
  if [ -n "$TAP" ]; then echo "tap $TAP"; a shell input tap $TAP; fi
done
wait $TEST || true
grep -E "PHOTO|VIDEO|All tests|Some tests|timed out" /tmp/quietake-grant.log | tail -4
granted CAMERA && granted RECORD_AUDIO
