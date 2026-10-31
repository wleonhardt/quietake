#!/usr/bin/env bash
# Disposable diagnostic branch only. Never supplies acceptance status.
set -euo pipefail
ulimit -c 0
[ "${GITHUB_ACTIONS:-}" = true ] && [ "${RUNNER_OS:-}" = Linux ] || exit 2
SDK="${ANDROID_HOME:?}"
ADB="$SDK/platform-tools/adb"
DEVICE=emulator-5554
APP=cam.quietake.app.dev
[ "$("$ADB" -s "$DEVICE" shell getprop ro.kernel.qemu | tr -d '\r')" = 1 ]
[ "$("$ADB" -s "$DEVICE" emu avd name | head -n 1 | tr -d '\r')" = quietake ]
for protected in cam.quietake.app club.hubner.shuttered club.hubner.shuttered.dev; do
  [ -z "$("$ADB" -s "$DEVICE" shell pm path "$protected")" ] || exit 2
done
pid=$(cat "$RUNNER_TEMP/quietake-emulator-logs/emulator.pid")
[[ "$pid" =~ ^[0-9]+$ ]]
case "$(readlink "/proc/$pid/exe")" in
  "$SDK/emulator/qemu/linux-x86_64/qemu-system-x86_64"|"$SDK/emulator/qemu/linux-x86_64/qemu-system-x86_64-headless") ;;
  *) exit 2 ;;
esac
# GDB prints function stacks/mapping metadata only; never values, locals or cores.
timeout --signal=TERM --kill-after=5s 1500s sudo -n gdb -nx --batch \
  -iex 'set pagination off' -iex 'set confirm off' \
  -iex 'set debuginfod enabled off' -iex 'set print frame-arguments none' \
  -iex 'set print entry-values no' -p "$pid" \
  -ex 'handle SIGPIPE SIGUSR1 SIGUSR2 nostop noprint pass' \
  -ex 'echo QUIETAKE_GDB_ATTACHED\n' -ex continue \
  -ex 'thread apply all backtrace 8' -ex 'info proc mappings' \
  -ex kill > "$RUNNER_TEMP/quietake-native-stack.log" 2>&1 &
trace_pid=$!
trap 'kill "$trace_pid" 2>/dev/null || true' EXIT
# Do not run workload until attachment succeeds. A dead debugger fails immediately.
for attempt in $(seq 1 20); do
  grep -q QUIETAKE_GDB_ATTACHED "$RUNNER_TEMP/quietake-native-stack.log" && break
  kill -0 "$trace_pid"
  sleep 1
done
grep -q QUIETAKE_GDB_ATTACHED "$RUNNER_TEMP/quietake-native-stack.log"
[ "$(awk '/^TracerPid:/{print $2}' "/proc/$pid/status")" -gt 0 ]
python3 tool/run_bounded.py --seconds 900 --label probe-normal-build -- flutter build apk --debug
python3 tool/dev_identity.py build/app/outputs/flutter-apk/app-debug.apk
cp build/app/outputs/flutter-apk/app-debug.apk "$RUNNER_TEMP/quietake-probe-normal.apk"
# Preserve the transition immediately preceding the observed crash.
python3 tool/run_bounded.py --seconds 900 --label probe-focused-files -- \
  tool/e2e.sh android integration_test/nas_recovery_test.dart integration_test/portable_test.dart
python3 tool/run_bounded.py --seconds 120 --label probe-normal-install -- \
  "$ADB" -s "$DEVICE" install -r "$RUNNER_TEMP/quietake-probe-normal.apk"
# This is a fresh disposable development sandbox, not an existing installation.
"$ADB" -s "$DEVICE" shell pm clear "$APP"
python3 tool/run_bounded.py --seconds 600 --label probe-cold-launches -- bash -c '
  set -euo pipefail
  for cycle in $(seq 1 120); do
    timeout 10 "$1" -s emulator-5554 shell am force-stop cam.quietake.app.dev
    timeout 15 "$1" -s emulator-5554 shell am start -W -n cam.quietake.app.dev/cam.quietake.app.MainActivity > "$2/quietake-last-launch.log"
    grep -q "Status: ok" "$2/quietake-last-launch.log"
    sleep 2
    echo "QUIETAKE_PROBE_CYCLE completed=$cycle"
  done
' _ "$ADB" "$RUNNER_TEMP"
if grep -Eq 'received signal SIG(SEGV|BUS|ABRT)' "$RUNNER_TEMP/quietake-native-stack.log"; then
  exit 1
fi
"$ADB" -s "$DEVICE" shell getprop sys.boot_completed
echo 'QUIETAKE_PROBE_COMPLETE result=not-reproduced acceptance=false'
