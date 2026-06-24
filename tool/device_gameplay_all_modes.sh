#!/usr/bin/env bash
set -euo pipefail

serial="${1:?usage: $0 <adb-serial>  (QUICK=1 for entry-only smoke)}"
pkg="${PKG:-com.galaxyjoy.neon_jewels}"
activity="${ACTIVITY:-.MainActivity}"
out_dir="${OUT_DIR:-/private/tmp/neon_gameplay_all_modes_${serial}}"
fatal_pattern='FATAL EXCEPTION|AndroidRuntime|ANR in|E/flutter|Failed assertion|RenderFlex overflowed|Fatal signal|crash_dump'

# QUICK=1 → entry-only smoke (enter mode, validate screen, screenshot, logcat scan)
# without driving board swipes. Replaces the old tool/device_mode_smoke.sh.
quick="${QUICK:-0}"

mkdir -p "$out_dir"

# Home taps are resolved from Flutter semantics/content-desc. Board swipes are
# scaled from the verified 1080x2340 reference viewport.
modes=(
  "campaign:PLAY NOW"
  "daily:DAILY"
  "endless:ENDLESS"
  "boss:NEON BOSS"
  "color_rush:COLOR RUSH"
  "gravity:GRAVITY"
  "zen:ZEN"
  "rhythm:RHYTHM"
  "versus:2 PLAYERS"
  "soda:SODA"
  "survival:SURVIVAL"
  "labyrinth:LABYRINTH"
  "puzzle:PUZZLE"
  "rush:RUSH"
)

echo "== Device gameplay automation =="
echo "device: $serial"
echo "package: $pkg"
echo "mode: $([[ "$quick" == "1" ]] && echo 'QUICK (entry-only)' || echo 'FULL (gameplay swipes)')"
echo "screenshots: $out_dir"

failures=0
screen_size="$(adb -s "$serial" shell wm size | grep -Eo '[0-9]+x[0-9]+' | tail -n1)"
screen_w="${screen_size%x*}"
screen_h="${screen_size#*x}"
echo "screen: ${screen_w}x${screen_h}"

adb_shell() {
  adb -s "$serial" shell "$@"
}

check_foreground() {
  adb_shell dumpsys window | grep -E 'mCurrentFocus|mFocusedApp' | grep "$pkg" >/dev/null
}

start_home() {
  adb_shell am force-stop "$pkg"
  adb_shell am start -n "$pkg/$activity" >/dev/null
  sleep 6
  check_foreground
}

tap() {
  adb_shell input tap "$1" "$2"
}

scale_x() {
  echo $(( $1 * screen_w / 1080 ))
}

scale_y() {
  echo $(( $1 * screen_h / 2340 ))
}

tap_ref() {
  tap "$(scale_x "$1")" "$(scale_y "$2")"
}

swipe() {
  adb_shell input swipe "$(scale_x "$1")" "$(scale_y "$2")" "$(scale_x "$3")" "$(scale_y "$4")" 130
}

dump_current_ui() {
  local path="$1"
  : >"$path"
  for _ in 1 2 3 4; do
    adb_shell rm -f /sdcard/window.xml || true
    adb_shell uiautomator dump --compressed /sdcard/window.xml >/dev/null || true
    if adb -s "$serial" exec-out cat /sdcard/window.xml >"$path" 2>/dev/null &&
      [[ -s "$path" ]] &&
      grep '<hierarchy' "$path" >/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

center_from_desc() {
  local desc="$1"
  local file="$2"
  perl -0777 -e '
    my $desc = quotemeta(shift @ARGV);
    my $xml = <>;
    if ($xml =~ /content-desc="$desc"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"/) {
      print int(($1 + $3) / 2), " ", int(($2 + $4) / 2);
    }
  ' "$desc" "$file"
}

tap_desc() {
  local desc="$1"
  local xml="$out_dir/home_${desc//[^A-Za-z0-9_]/_}.xml"
  local center
  dump_current_ui "$xml" || true
  center="$(center_from_desc "$desc" "$xml")"
  if [[ -z "$center" ]]; then
    echo "FAIL: could not resolve tappable content-desc '$desc'"
    return 1
  fi
  tap ${center}
}

play_board_swipes() {
  # Dense center-board swaps. Repeated across all modes to exercise actual board
  # input, cascades, HUD updates, timers, mode overlays, and result-path guards.
  local rounds="${1:-3}"
  for _ in $(seq 1 "$rounds"); do
    swipe 325 940 455 940
    sleep 0.12
    swipe 455 1065 585 1065
    sleep 0.12
    swipe 585 1190 715 1190
    sleep 0.12
    swipe 715 1315 845 1315
    sleep 0.12
    swipe 845 1440 715 1440
    sleep 0.12
    swipe 715 1565 585 1565
    sleep 0.12
    swipe 585 1690 455 1690
    sleep 0.12
    swipe 455 1565 455 1440
    sleep 0.12
    swipe 585 1440 585 1315
    sleep 0.12
    swipe 715 1315 715 1190
    sleep 0.12
  done
}

enter_mode() {
  local name="$1"
  local label="$2"

  case "$name" in
    campaign)
      tap_desc "$label"   # Home -> World Map
      sleep 2
      tap_ref 577 575     # Level 1 node
      sleep 1
      tap_ref 340 1747    # Story Skip, harmless if absent
      sleep 0.5
      tap_ref 540 1747    # Story Continue, harmless if absent
      sleep 0.7
      tap_ref 750 1747    # Pregame Play Now
      sleep 2
      ;;
    puzzle)
      tap_desc "$label"   # Home -> Puzzle select
      sleep 2
      tap_ref 165 430     # Puzzle 1 tile
      sleep 2
      ;;
    versus)
      tap_desc "$label"   # Home -> Versus select
      sleep 2
      tap_ref 540 760     # Pick Versus
      sleep 5             # Countdown
      ;;
    *)
      tap_desc "$label"
      sleep 2
      ;;
  esac
}

dump_ui() {
  local name="$1"
  dump_current_ui "$out_dir/${name}_entered.xml"
}

validate_entered() {
  local name="$1"
  local xml="$out_dir/${name}_entered.xml"

  dump_ui "$name"
  adb -s "$serial" exec-out screencap -p >"$out_dir/${name}_entered.png"

  case "$name" in
    versus)
      grep -E 'content-desc="(PLAYER 1|Player 1|P1|1 NGƯỜI|NGƯỜI CHƠI 1|[0-9]+)"' "$xml" >/dev/null ||
        grep -E 'coop_goal|versus_p1|versus_p2|content-desc="[^"]*1[^"]*0' "$xml" >/dev/null
      ;;
    *)
      grep 'content-desc="SCORE"' "$xml" >/dev/null &&
        grep -E 'content-desc="(GOAL|STAGE|MOVES|TIME|ZEN|TIDE|MỤC TIÊU|NƯỚC|LƯỢT)"' "$xml" >/dev/null
      ;;
  esac
}

scan_logcat() {
  local name="$1"
  if adb -s "$serial" logcat -d -e "$fatal_pattern" | grep -E "$fatal_pattern" >"$out_dir/${name}_fatal.log"; then
    echo "FAIL: $name fatal logcat pattern found"
    cat "$out_dir/${name}_fatal.log"
    return 1
  fi
  return 0
}

for item in "${modes[@]}"; do
  IFS=: read -r name label <<<"$item"
  if [[ -n "${MODE_FILTER:-}" && "$name" != "$MODE_FILTER" ]]; then
    continue
  fi
  echo "-- $name"

  adb -s "$serial" logcat -c
  if ! start_home; then
    echo "FAIL: $name app did not become foreground"
    failures=$((failures + 1))
    continue
  fi

  enter_mode "$name" "$label"

  if ! check_foreground; then
    echo "FAIL: $name app lost foreground before gameplay"
    failures=$((failures + 1))
    continue
  fi

  if ! validate_entered "$name"; then
    echo "FAIL: $name did not reach a validated gameplay screen"
    failures=$((failures + 1))
    continue
  fi

  if [[ "$quick" != "1" ]]; then
    if [[ "$name" == "versus" ]]; then
      play_board_swipes 2
      # Exercise lower board too.
      swipe 325 1810 455 1810
      swipe 455 1935 585 1935
      swipe 585 2060 715 2060
    else
      play_board_swipes 3
    fi
  fi

  sleep 1
  if ! adb_shell pidof "$pkg" >/dev/null; then
    echo "FAIL: $name app process is not running after gameplay"
    failures=$((failures + 1))
    continue
  fi

  adb -s "$serial" exec-out screencap -p >"$out_dir/${name}.png"

  if scan_logcat "$name"; then
    echo "PASS: $name $([[ "$quick" == "1" ]] && echo 'entry smoke' || echo 'gameplay smoke')"
  else
    failures=$((failures + 1))
  fi
done

if (( failures > 0 )); then
  echo "FAIL: $failures gameplay automation failure(s)"
  exit 1
fi

echo "PASS: all automated gameplay mode checks clean"
