#!/usr/bin/env bash
# Send a line to the guest's serial console (the TEST=1 image has a getty there).
#   run/serial.sh 'echo hello'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
printf '%s\r' "$*" | socat -T 1 - UNIX-CONNECT:"$ROOT/run/talk-serial.sock" >/dev/null 2>&1 || true
