#!/usr/bin/env bash
# Build the container image, then libdectalk.a, tdsr (musl, dectalk feature)
# and espeakup inside it. Outputs: dist/tdsr, dist/espeakup.
# Env: RUST_TDSR (checkout of github.com/ccdavis/rust-tdsr, default ~/rust-tdsr),
#      PODMAN (podman or docker, default podman).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PODMAN="${PODMAN:-podman}"
RUST_TDSR="${RUST_TDSR:-$HOME/rust-tdsr}"
[ -d "$RUST_TDSR" ] || { echo "rust-tdsr not found at $RUST_TDSR (git clone https://github.com/ccdavis/rust-tdsr, or set RUST_TDSR)"; exit 1; }
$PODMAN image exists a11y-alpine-build 2>/dev/null || $PODMAN build -t a11y-alpine-build "$ROOT/build"
mkdir -p "$HOME/.cache/a11y-cargo" "$ROOT/dist"
$PODMAN run --rm -v "$ROOT:/work/alpine:Z" -v "$RUST_TDSR:/work/rust-tdsr:Z" -v "$HOME/.cache/a11y-cargo:/cargo-home:Z" \
  a11y-alpine-build sh /work/alpine/build/build-tdsr.sh
$PODMAN run --rm -v "$ROOT:/work/alpine:Z" a11y-alpine-build sh /work/alpine/build/build-espeakup.sh
