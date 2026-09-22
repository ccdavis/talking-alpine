#!/usr/bin/env bash
# Build both images (x86_64 and x86) and the binaries, zip the images, and (with --publish)
# create a GitHub release with them. Needs: podman (or PODMAN=docker), zip, a rust-tdsr
# checkout (RUST_TDSR). Publishes to REPO (default ccdavis/talking-alpine).
#   release.sh                 build everything: raw images and binaries in dist/x86_64 and
#                              dist/x86, the upload set (zips, binaries, SHA256SUMS) in dist/release
#   release.sh --publish [tag] build and create the release (tag defaults to today's date)
#   release.sh --upload tag    build and add the assets to an existing release
set -e
D="$(cd "$(dirname "$0")" && pwd)"; cd "$D"
for arch in x86_64 x86; do
  ARCH=$arch bash run/get-alpine.sh
  ARCH=$arch bash run/build.sh
  ARCH=$arch bash run/mkimage.sh
done
R=dist/release; rm -rf $R; mkdir -p $R
zip -q -9 -j $R/talkalpine.img.zip dist/x86_64/talkalpine.img
zip -q -9 -j $R/talkalpine-x86.img.zip dist/x86/talkalpine-x86.img
cp dist/x86_64/tdsr $R/tdsr; cp dist/x86_64/espeakup $R/espeakup
cp dist/x86/tdsr $R/tdsr-x86; cp dist/x86/espeakup $R/espeakup-x86
( cd $R && sha256sum talkalpine.img.zip talkalpine-x86.img.zip tdsr espeakup tdsr-x86 espeakup-x86 > SHA256SUMS )
( cd dist && sha256sum x86_64/talkalpine.img x86/talkalpine-x86.img >> release/SHA256SUMS )
ASSETS="$R/talkalpine.img.zip $R/talkalpine-x86.img.zip $R/tdsr $R/espeakup $R/tdsr-x86 $R/espeakup-x86 $R/SHA256SUMS"
ls -la $ASSETS; cat $R/SHA256SUMS
NOTES="Built from $(git rev-parse --short HEAD). Unzip talkalpine.img.zip (64-bit PCs) or talkalpine-x86.img.zip (32-bit-only machines: Pentium M, Core Duo, early Atom and older; see README.md) and write the image to a USB stick of 2 GB or more. tdsr and espeakup are the musl binaries inside the images, for anyone assembling their own Alpine system."
case "${1:-}" in
  --publish) tag="${2:-v$(date +%Y.%m.%d)}"; gh release create -R "${REPO:-ccdavis/talking-alpine}" "$tag" $ASSETS --title "Talking Alpine $tag" --notes "$NOTES";;
  --upload) tag="$2"; gh release upload -R "${REPO:-ccdavis/talking-alpine}" "$tag" $ASSETS --clobber && gh release edit -R "${REPO:-ccdavis/talking-alpine}" "$tag" --notes "$NOTES";;
esac
