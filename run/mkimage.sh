#!/usr/bin/env bash
# Build dist/x86_64/talkalpine.img (ARCH=x86_64, default) or dist/x86/talkalpine-x86.img (ARCH=x86)
# in the build container (rootless podman, or docker with PODMAN=docker). Prerequisites:
# the ISO (run/get-alpine.sh with the same ARCH), the binaries (run/build.sh, same ARCH).
# Env: TEST=1 (serial getty + tdsr debug log for the QEMU harness), P1_MB, P2_MB.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PODMAN="${PODMAN:-podman}"
ARCH="${ARCH:-x86_64}"
source "$ROOT/build/arch.sh"
cd "$ROOT"
[ -f keys/talkalpine.rsa ] || { openssl genrsa -out keys/talkalpine.rsa 2048 2>/dev/null; openssl rsa -in keys/talkalpine.rsa -pubout -out keys/talkalpine.rsa.pub 2>/dev/null; cp keys/talkalpine.rsa.pub overlay/etc/apk/keys/; }
$PODMAN image exists "$IMAGE" 2>/dev/null || $PODMAN build $PLATFORM --build-arg BASE="$BASE" -f "$ROOT/build/Containerfile" -t "$IMAGE" "$ROOT/build"
# images/ may be a symlink to a shared download directory: its target is mounted separately
IMAGES="$(readlink -f "$ROOT/images")"
exec $PODMAN run --rm $PLATFORM -e TEST="${TEST:-0}" -e P1_MB="${P1_MB:-1200}" -e P2_MB="${P2_MB:-160}" -e IMAGES_DIR=/work/images \
  -e ARCH="$ARCH" -e DISTDIR="$DISTDIR" -e ISODIR="$ISODIR" \
  -v "$ROOT:/work/alpine:Z" -v "$IMAGES:/work/images:Z" "$IMAGE" sh /work/alpine/build/mkimage-inner.sh
