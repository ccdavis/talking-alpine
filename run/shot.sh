#!/usr/bin/env bash
# Screenshot the guest: run/shot.sh name  -> run/talk-name.png
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
"$ROOT/run/mon.sh" "screendump $ROOT/run/talk-$1.ppm" >/dev/null
sleep 0.5
command -v convert >/dev/null && convert "$ROOT/run/talk-$1.ppm" "$ROOT/run/talk-$1.png" && echo "$ROOT/run/talk-$1.png"
