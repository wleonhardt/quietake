#!/usr/bin/env bash
# End-to-end run on a simulator or device. Grants the camera and microphone
# permissions first so the integration tests never hit a native dialog.
#
#   tool/e2e.sh android          # boots the "quietake" AVD headless if needed
#   tool/e2e.sh ios              # boots an iPhone simulator if needed
#   tool/e2e.sh <flutter-device-id>
set -euo pipefail
cd "$(dirname "$0")/.."

APP=cam.quietake.app.dev
SDK="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export JAVA_HOME="${JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"

case "${1:-android}" in
  android)
    ADB="$SDK/platform-tools/adb"
    if ! "$ADB" devices | grep -q "emulator-.*device"; then
      nohup "$SDK/emulator/emulator" -avd quietake -port 5554 -no-window -no-audio -no-boot-anim \
        -gpu swiftshader_indirect >/tmp/quietake-emulator.log 2>&1 &
      "$ADB" -s emulator-5554 wait-for-device
      until [ "$("$ADB" -s emulator-5554 shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ]; do sleep 2; done
    fi
    DEVICE=$("$ADB" devices | awk '/emulator-.*device/{print $1; exit}')
    flutter build apk --debug >/dev/null
    python3 tool/dev_identity.py build/app/outputs/flutter-apk/app-debug.apk
    "$ADB" -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk >/dev/null
    "$ADB" -s "$DEVICE" shell pm grant "$APP" android.permission.CAMERA
    "$ADB" -s "$DEVICE" shell pm grant "$APP" android.permission.RECORD_AUDIO
    ;;
  ios)
    DEVICE=$(xcrun simctl list devices booted -j | python3 -c 'import sys,json;d=json.load(sys.stdin);print(next((x["udid"] for v in d["devices"].values() for x in v if x["state"]=="Booted"),""))')
    if [ -z "$DEVICE" ]; then
      DEVICE=$(xcrun simctl list devices available -j | python3 -c 'import sys,json;d=json.load(sys.stdin);print(next(x["udid"] for k,v in d["devices"].items() if "iOS" in k for x in v if "iPhone" in x["name"]))')
      xcrun simctl boot "$DEVICE"
      xcrun simctl bootstatus "$DEVICE" -b
    fi
    flutter build ios --simulator --debug >/dev/null
    python3 tool/dev_identity.py build/ios/iphonesimulator/Runner.app
    xcrun simctl install "$DEVICE" build/ios/iphonesimulator/Runner.app
    xcrun simctl privacy "$DEVICE" grant camera "$APP" || true
    xcrun simctl privacy "$DEVICE" grant microphone "$APP" || true
    ;;
  *)
    # Any adb device id (a real phone): same build, install and grants as the emulator.
    DEVICE="$1"
    ADB="$SDK/platform-tools/adb"
    if "$ADB" devices | grep -q "^$DEVICE[[:space:]]*device"; then
      # A sleeping screen kills the camera preview mid-test: stay on while plugged in.
      "$ADB" -s "$DEVICE" shell svc power stayon usb
      "$ADB" -s "$DEVICE" shell input keyevent KEYCODE_WAKEUP
      flutter build apk --debug >/dev/null
      python3 tool/dev_identity.py build/app/outputs/flutter-apk/app-debug.apk
      "$ADB" -s "$DEVICE" install -r build/app/outputs/flutter-apk/app-debug.apk >/dev/null
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
flutter test integration_test -d "$DEVICE" --no-uninstall
