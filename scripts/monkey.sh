#!/usr/bin/env bash
# Usage: scripts/monkey.sh [-p package] [-n events] [-s seed] [-t throttle_ms] [-d adb_serial]
# Exit 0 = no crash/ANR; 1 = crash/ANR found; 2 = usage/adb error.
# WARNING: monkey taps the real app on the device: it can clear high scores (Settings), send real
# telemetry to production and open links. Use a test device/emulator, not a phone with data you keep.
set -u
PKG=com.sentientbeingsoftware.gridmindapp EVENTS=5000 SEED=$RANDOM THROTTLE=50 SERIAL=""
while getopts "p:n:s:t:d:" o; do case $o in
  p) PKG=$OPTARG;; n) EVENTS=$OPTARG;; s) SEED=$OPTARG;; t) THROTTLE=$OPTARG;; d) SERIAL=$OPTARG;;
  *) sed -n '2p' "$0"; exit 2;; esac; done
[[ $EVENTS =~ ^[0-9]+$ && $THROTTLE =~ ^[0-9]+$ && $SEED =~ ^[0-9]+$ ]] || { echo "n/s/t must be integers" >&2; exit 2; }
ADB=(adb ${SERIAL:+-s "$SERIAL"})
"${ADB[@]}" get-state >/dev/null 2>&1 || { echo "no adb device" >&2; exit 2; }
"${ADB[@]}" shell pm list packages "$PKG" | tr -d '\r' | grep -qx "package:$PKG" || { echo "$PKG not installed" >&2; exit 2; }
LOG=$(mktemp "${TMPDIR:-/tmp}/monkey.XXXXXX.log")
echo "pkg=$PKG events=$EVENTS seed=$SEED throttle=${THROTTLE}ms log=$LOG"
"${ADB[@]}" logcat -c
"${ADB[@]}" shell monkey -p "$PKG" -s "$SEED" --throttle "$THROTTLE" \
  --ignore-crashes --ignore-timeouts --monitor-native-crashes -v "$EVENTS" 2>&1 | tee "$LOG"
if grep -qE "^// CRASH|^// NOT RESPONDING|Abort|FATAL EXCEPTION|StackOverflowError|OutOfMemoryError" "$LOG"; then
  "${ADB[@]}" logcat -d -b crash > "$LOG.crash"; echo "FAIL: crash/ANR found (seed=$SEED); crash buffer: $LOG.crash"; exit 1
fi
echo "PASS"
