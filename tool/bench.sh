#!/usr/bin/env bash
# Build and validate before Drive can cache a stale package identifier.
set -euo pipefail
cd "$(dirname "$0")/.."
DEVICE="${1:?usage: tool/bench.sh <adb-device-id>}"
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
ADB="$SDK/platform-tools/adb"
APP=cam.quietake.app.dev
PROTECTED=(cam.quietake.app club.hubner.shuttered club.hubner.shuttered.dev)
"$ADB" -s "$DEVICE" get-state >/dev/null
ORIGINAL=()
for package in "${PROTECTED[@]}"; do
  ORIGINAL+=("$("$ADB" -s "$DEVICE" shell pm path "$package" 2>/dev/null || true)")
done

cleanup() {
  local bench_status=$?
  trap - EXIT
  "$ADB" -s "$DEVICE" shell am force-stop "$APP" >/dev/null 2>&1 || true
  for index in "${!PROTECTED[@]}"; do
    local current
    current=$("$ADB" -s "$DEVICE" shell pm path "${PROTECTED[$index]}" 2>/dev/null || true)
    if [ "$current" != "${ORIGINAL[$index]}" ]; then
      echo "ERROR: original application disappeared or changed: ${PROTECTED[$index]}; stop device testing." >&2
      exit 1
    fi
  done
  exit "$bench_status"
}

flutter build apk --profile --target=integration_test/crypto_bench_test.dart
APK=build/app/outputs/flutter-apk/app-profile.apk
PACKAGE=$(python3 - "$SDK" "$APK" <<'PY'
from pathlib import Path
import re, subprocess, sys
tools = list((Path(sys.argv[1]) / 'build-tools').glob('*/aapt'))
aapt = max(tools, key=lambda p: tuple(map(int, re.findall(r'\d+', p.parent.name))))
metadata = subprocess.check_output([str(aapt), 'dump', 'badging', sys.argv[2]], text=True)
print(re.search(r"^package: name='([^']+)'", metadata, re.MULTILINE).group(1))
PY
)
if [ "$PACKAGE" != "$APP" ]; then
  echo "Refusing benchmark: expected $APP, found $PACKAGE" >&2
  exit 1
fi
trap cleanup EXIT
# Prebuilt APK fixes the cached identity; keep-app-running prevents automatic uninstall.
flutter drive --profile --driver=test_driver/integration_test.dart \
  --target=integration_test/crypto_bench_test.dart --use-application-binary="$APK" \
  --keep-app-running -d "$DEVICE"
