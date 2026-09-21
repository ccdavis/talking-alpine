#!/usr/bin/env bash
# Build the image and the binaries, zip the image, and (with --publish) create a GitHub
# release with them. Needs: podman (or PODMAN=docker), zip, a rust-tdsr checkout
# (RUST_TDSR). Publishes to REPO (default ccdavis/talking-alpine).
set -e
D="$(cd "$(dirname "$0")" && pwd)"; cd "$D"
bash run/get-alpine.sh
bash run/build.sh
bash run/mkimage.sh
rm -f dist/talkalpine.img.zip dist/SHA256SUMS
( cd dist && zip -q -9 talkalpine.img.zip talkalpine.img && sha256sum talkalpine.img talkalpine.img.zip tdsr espeakup > SHA256SUMS )
ls -la dist/talkalpine.img.zip dist/tdsr dist/espeakup; cat dist/SHA256SUMS
if [ "${1:-}" = "--publish" ]; then
  tag="${2:-v$(date +%Y.%m.%d)}"
  gh release create -R "${REPO:-ccdavis/talking-alpine}" "$tag" dist/talkalpine.img.zip dist/tdsr dist/espeakup dist/SHA256SUMS \
    --title "Talking Alpine $tag" --notes "Built from $(git rev-parse --short HEAD). Unzip talkalpine.img.zip and write talkalpine.img to a USB stick of 2 GB or more (see README.md). tdsr and espeakup are the x86_64 musl binaries inside the image, for anyone assembling their own Alpine system."
fi
