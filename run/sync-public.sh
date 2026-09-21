#!/usr/bin/env bash
# Mirror this project (tracked files of alpine/ at git HEAD) into the public repository
# working tree (default ~/talking-alpine), which keeps its own README.md; the internal
# README becomes DEVELOPING.md. Commit and push there afterwards.
set -e
D="$(cd "$(dirname "$0")/.." && pwd)"; P="${1:-$HOME/talking-alpine}"
[ -d "$P/.git" ] || { echo "no git repo at $P"; exit 1; }
tmp=$(mktemp -d)
git -C "$D/.." archive --format=tar HEAD -- alpine | tar -x -C "$tmp"
# keys/ is overwritten, not removed: the mirror's private signing key (git-ignored) stays
for f in $(cd "$tmp/alpine" && ls -A); do case "$f" in README.md|keys) continue;; esac; rm -rf "$P/$f"; done
mv "$tmp/alpine/README.md" "$tmp/alpine/DEVELOPING.md"
cp -r "$tmp/alpine/." "$P/"
rm -rf "$tmp"
echo "synced to $P; now: cd $P && git add -A && git commit && git push"
