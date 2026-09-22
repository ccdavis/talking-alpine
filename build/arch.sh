# Per-architecture settings, sourced by run/build.sh and run/mkimage.sh with ARCH set.
case "$ARCH" in
  x86_64) IMAGE=a11y-alpine-build; BASE=docker.io/library/alpine:3.24; PLATFORM=""; DISTDIR=dist/x86_64; ISODIR=images/iso;;
  x86)    IMAGE=a11y-alpine-build-x86; BASE=docker.io/i386/alpine:3.24; PLATFORM="--platform linux/386"; DISTDIR=dist/x86; ISODIR=images/iso-x86;;
  *) echo "ARCH must be x86_64 or x86"; exit 1;;
esac
