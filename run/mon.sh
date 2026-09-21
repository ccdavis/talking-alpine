#!/usr/bin/env bash
# QEMU monitor command: run/mon.sh 'sendkey alt-s' | 'screendump run/x.ppm' | 'info registers'
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
printf '%s\n' "$*" | socat -T 2 - UNIX-CONNECT:"$ROOT/run/talk-mon.sock" 2>/dev/null | grep -v '^QEMU\|^(qemu)' || true
