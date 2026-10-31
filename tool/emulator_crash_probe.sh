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
# Replay the observed failing prefix with unchanged per-file deadlines.
python3 tool/run_bounded.py --seconds 1500 --label probe-observed-prefix -- \
  tool/e2e.sh android integration_test/appearance_test.dart \
    integration_test/background_test.dart \
    integration_test/backup_test.dart \
    integration_test/camera_lifecycle_test.dart \
    integration_test/capture_failure_test.dart \
    integration_test/capture_test.dart \
    integration_test/cast_test.dart \
    integration_test/crypto_bench_test.dart \
    integration_test/delete_test.dart \
    integration_test/gallery_preview_test.dart \
    integration_test/import_test.dart \
    integration_test/library_layout_test.dart \
    integration_test/library_recovery_test.dart
if grep -Eq 'received signal SIG(SEGV|BUS|ABRT)' "$RUNNER_TEMP/quietake-native-stack.log"; then
  exit 1
fi
"$ADB" -s "$DEVICE" shell getprop sys.boot_completed
echo 'QUIETAKE_PROBE_COMPLETE result=not-reproduced acceptance=false'
