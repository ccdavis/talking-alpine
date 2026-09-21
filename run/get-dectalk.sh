#!/usr/bin/env bash
# Fetch the DECtalk source tree that src/dectalk builds against (git-ignored; Fonix
# proprietary licence, not part of this repository) and apply our patches.
set -e
D="$(cd "$(dirname "$0")/.." && pwd)"; U="$D/src/upstream/dectalk"; COMMIT=69ebb459137a7a8d92ed41da8362233eaa173efc
if [ ! -d "$U/.git" ]; then mkdir -p "$D/src/upstream"; git clone -q https://github.com/dectalk/dectalk.git "$U"; fi
git -C "$U" fetch -q origin "$COMMIT" 2>/dev/null || true
git -C "$U" checkout -q "$COMMIT"
if git -C "$U" apply --check "$D/src/dectalk/patches/upstream.diff" 2>/dev/null; then
  git -C "$U" apply "$D/src/dectalk/patches/upstream.diff" && echo "DECtalk $COMMIT fetched and patched"
else
  echo "DECtalk $COMMIT present; patches already applied (or do not apply cleanly: git -C $U status)"
fi
