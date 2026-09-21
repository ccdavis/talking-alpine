#!/usr/bin/env bash
# Build dist/talkalpine.img in the a11y-alpine-build container (rootless podman, or
# docker with PODMAN=docker). Prerequisites: images/iso (run/get-alpine.sh), dist/tdsr
# and dist/espeakup (run/build.sh). Env: TEST=1 (serial getty + tdsr debug log for the
# QEMU harness), P1_MB, P2_MB.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PODMAN="${PODMAN:-podman}"
cd "$ROOT"
[ -f keys/talkalpine.rsa ] || { openssl genrsa -out keys/talkalpine.rsa 2048 2>/dev/null; openssl rsa -in keys/talkalpine.rsa -pubout -out keys/talkalpine.rsa.pub 2>/dev/null; cp keys/talkalpine.rsa.pub overlay/etc/apk/keys/; }
$PODMAN image exists a11y-alpine-build 2>/dev/null || $PODMAN build -f "$ROOT/build/Containerfile" -t a11y-alpine-build "$ROOT/build"
# images/ may be a symlink to a shared download directory: its target is mounted separately
IMAGES="$(readlink -f "$ROOT/images")"
exec $PODMAN run --rm -e TEST="${TEST:-0}" -e P1_MB="${P1_MB:-1200}" -e P2_MB="${P2_MB:-160}" -e IMAGES_DIR=/work/images \
  -v "$ROOT:/work/alpine:Z" -v "$IMAGES:/work/images:Z" a11y-alpine-build sh /work/alpine/build/mkimage-inner.sh
