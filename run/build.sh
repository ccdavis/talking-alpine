#!/usr/bin/env bash
# Build the container image, then libdectalk.a, tdsr (musl, dectalk feature)
# and espeakup inside it. Outputs: dist/x86_64/tdsr, dist/x86_64/espeakup (ARCH=x86_64,
# the default) or dist/x86/tdsr, dist/x86/espeakup (ARCH=x86, built in the 32-bit
# Alpine container).
# Env: RUST_TDSR (checkout of github.com/ccdavis/rust-tdsr, default ~/rust-tdsr),
#      PODMAN (podman or docker, default podman), ARCH.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PODMAN="${PODMAN:-podman}"
RUST_TDSR="${RUST_TDSR:-$HOME/rust-tdsr}"
ARCH="${ARCH:-x86_64}"
source "$ROOT/build/arch.sh"
[ -d "$RUST_TDSR" ] || { echo "rust-tdsr not found at $RUST_TDSR (git clone https://github.com/ccdavis/rust-tdsr, or set RUST_TDSR)"; exit 1; }
$PODMAN image exists "$IMAGE" 2>/dev/null || $PODMAN build $PLATFORM --build-arg BASE="$BASE" -f "$ROOT/build/Containerfile" -t "$IMAGE" "$ROOT/build"
mkdir -p "$HOME/.cache/a11y-cargo-$ARCH" "$ROOT/$DISTDIR"
$PODMAN run --rm $PLATFORM -e ARCH="$ARCH" -e DISTDIR="$DISTDIR" -v "$ROOT:/work/alpine:Z" -v "$RUST_TDSR:/work/rust-tdsr:Z" \
  -v "$HOME/.cache/a11y-cargo-$ARCH:/cargo-home:Z" "$IMAGE" sh /work/alpine/build/build-tdsr.sh
$PODMAN run --rm $PLATFORM -e DISTDIR="$DISTDIR" -v "$ROOT:/work/alpine:Z" "$IMAGE" sh /work/alpine/build/build-espeakup.sh
