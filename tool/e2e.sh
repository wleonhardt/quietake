#!/usr/bin/env bash
# End-to-end run on a simulator or device. Grants the camera and microphone
# permissions first so the integration tests never hit a native dialog.
#
#   tool/e2e.sh android          # boots the "quietake" AVD headless if needed
#   tool/e2e.sh ios              # boots an iPhone simulator if needed
#   tool/e2e.sh <flutter-device-id> [integration_test/name_test.dart ...]
set -euo pipefail
cd "$(dirname "$0")/.."

APP=cam.quietake.app.dev
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"

# Validate the entire selection before booting or changing any device.
TARGET="${1:-android}"
if [ "$#" -gt 0 ]; then shift; fi
if [ "$#" -gt 0 ]; then
  TEST_FILES=("$@")
else
  TEST_FILES=(integration_test/*_test.dart)
fi
for test_file in "${TEST_FILES[@]}"; do
  if [[ ! "$test_file" =~ ^integration_test/[a-z0-9_]+_test\.dart$ ]] ||
     [ ! -f "$test_file" ] || [ -L "$test_file" ]; then
    echo "Invalid integration test selection: $test_file" >&2
    exit 2
  fi
done
bounded() {
  local seconds="$1" label="$2"
  shift 2
  python3 tool/run_bounded.py --seconds "$seconds" --grace 5 --label "$label" -- "$@"
}

case "$TARGET" in
  android)
    ADB="$SDK/platform-tools/adb"
    if ! "$ADB" devices | grep -q "emulator-.*device"; then
      nohup "$SDK/emulator/emulator" -avd quietake -port 5554 -no-window -no-audio -no-boot-anim \
        -gpu swiftshader_indirect >/tmp/quietake-emulator.log 2>&1 &
      bounded 120 android-boot bash -c '
        "$1" -s emulator-5554 wait-for-device
        until [ "$("$1" -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d "\r")" = "1" ]; do sleep 2; done
      ' _ "$ADB"
    fi
    DEVICE=$("$ADB" devices | awk '/emulator-.*device/{print $1; exit}')
    bounded 900 android-build flutter build apk --debug
    python3 tool/dev_identity.py build/app/outputs/flutter-apk/app-debug.apk
    bounded 120 android-install "$ADB" -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk
    "$ADB" -s "$DEVICE" shell pm grant "$APP" android.permission.CAMERA
    "$ADB" -s "$DEVICE" shell pm grant "$APP" android.permission.RECORD_AUDIO
    ;;
  ios)
    DEVICE=$(xcrun simctl list devices booted -j | python3 -c 'import sys,json;d=json.load(sys.stdin);print(next((x["udid"] for v in d["devices"].values() for x in v if x["state"]=="Booted"),""))')
    if [ -z "$DEVICE" ]; then
      DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import sys,json;d=json.load(sys.stdin);print(next(x["udid"] for k,v in d["devices"].items() if "iOS" in k for x in v if "iPhone" in x["name"]))')
      xcrun simctl boot "$DEVICE"
      bounded 120 ios-boot xcrun simctl bootstatus "$DEVICE" -b
    fi
    bounded 900 ios-build flutter build ios --simulator --debug
    python3 tool/dev_identity.py build/ios/iphonesimulator/Runner.app
    bounded 120 ios-install xcrun simctl install "$DEVICE" build/ios/iphonesimulator/Runner.app
    xcrun simctl privacy "$DEVICE" grant camera "$APP" || true
    xcrun simctl privacy "$DEVICE" grant microphone "$APP" || true
    ;;
  *)
    # Any adb device id (a real phone): same build, install and grants as the emulator.
    DEVICE="$TARGET"
    ADB="$SDK/platform-tools/adb"
    if "$ADB" devices | grep -q "^$DEVICE[[:space:]]*device"; then
      # USB data can accompany AC-reported charging (e.g. Samsung). Cover both.
      ORIGINAL_STAY_ON=$("$ADB" -s "$DEVICE" shell settings get global stay_on_while_plugged_in | tr -d '\r')
      restore_stay_awake() {
        local test_status=$?
        trap - EXIT
        "$ADB" -s "$DEVICE" shell settings put global stay_on_while_plugged_in "$ORIGINAL_STAY_ON" >/dev/null || true
        exit "$test_status"
      }
      trap restore_stay_awake EXIT
      "$ADB" -s "$DEVICE" shell svc power stayon true
      "$ADB" -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP
      bounded 900 android-build flutter build apk --debug
      python3 tool/dev_identity.py build/app/outputs/flutter-apk/app-debug.apk
      bounded 120 android-install "$ADB" -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk
      # OEM builds (OxygenOS) refuse shell grants unless "USB debugging (Security
      # settings)" is on; then the first launch must answer the dialogs once and
      # --no-uninstall keeps the grants afterwards. tool/grant-on-phone.sh does that.
      "$ADB" -s "$DEVICE" shell pm grant "$APP" android.permission.CAMERA 2>/dev/null ||
        echo "note: shell cannot grant permissions on $DEVICE; run tool/grant-on-phone.sh $DEVICE first"
      "$ADB" -s "$DEVICE" shell pm grant "$APP" android.permission.RECORD_AUDIO 2>/dev/null || true
    fi
    ;;
esac

# --no-uninstall: a reinstall between test files would wipe the granted permissions.
# Flutter's native directory dispatcher can continue after a load failure even
# with --fail-fast. Separate files so set -e stops before the next native build.
for test_file in "${TEST_FILES[@]}"; do
  bounded 300 "$test_file" flutter test "$test_file" -d "$DEVICE" --no-uninstall --fail-fast --reporter expanded
done
