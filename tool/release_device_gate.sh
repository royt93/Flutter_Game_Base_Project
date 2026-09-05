#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

PKG="${PKG:-com.galaxyjoy.roybasegame}"
ACTIVITY="${ACTIVITY:-.MainActivity}"
SERIAL="${1:-${ANDROID_SERIAL:-}}"
WAIT_SECONDS="${WAIT_SECONDS:-8}"
APK_PATH="${APK_PATH:-build/app/outputs/flutter-apk/app-debug.apk}"

if [[ -z "$SERIAL" ]]; then
  SERIAL="$(adb devices | awk 'NR > 1 && $2 == "device" {print $1; exit}')"
fi

if [[ -z "$SERIAL" ]]; then
  echo "ERROR: no online adb device. Connect a device or pass serial as arg." >&2
  exit 2
fi

LOG_FILE="${TMPDIR:-/tmp}/roybasegame_device_gate_${SERIAL}_$(date +%Y%m%d_%H%M%S).log"

echo "== Device gate =="
echo "device: $SERIAL"
echo "package: $PKG"
echo "apk: $APK_PATH"

flutter build apk --debug

adb -s "$SERIAL" logcat -c
adb -s "$SERIAL" install -r "$APK_PATH"
adb -s "$SERIAL" shell am force-stop "$PKG" >/dev/null 2>&1 || true
adb -s "$SERIAL" shell am start -n "$PKG/$ACTIVITY"
sleep "$WAIT_SECONDS"

if ! adb -s "$SERIAL" shell pidof "$PKG" >/dev/null 2>&1; then
  adb -s "$SERIAL" logcat -d >"$LOG_FILE" || true
  echo "ERROR: app process is not running after launch. Log: $LOG_FILE" >&2
  exit 1
fi

adb -s "$SERIAL" logcat -d >"$LOG_FILE"

APP_PID="$(adb -s "$SERIAL" shell pidof "$PKG" | tr -d '\r' || true)"
echo "pid: ${APP_PID:-unknown}"
echo "log: $LOG_FILE"

ERROR_PATTERN='FATAL EXCEPTION|AndroidRuntime|ANR in|E/flutter|Failed assertion|RenderFlex overflowed|Process .*crashed|Fatal signal|crash_dump.*com\.galaxyjoy\.roybasegame'

if grep -E "$ERROR_PATTERN" "$LOG_FILE" >/tmp/roybasegame_device_gate_matches.txt; then
  echo "ERROR: device gate found fatal log lines:" >&2
  cat /tmp/roybasegame_device_gate_matches.txt >&2
  exit 1
fi

echo "PASS: install + launch + logcat fatal scan clean"
