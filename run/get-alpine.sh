#!/usr/bin/env bash
# Fetch the Alpine 3.24 standard ISO for ARCH (x86_64, or x86 for the 32-bit image) and
# extract it to images/iso (x86_64) or images/iso-x86; clone espeakup into src/upstream and
# (run/get-dectalk.sh) the DECtalk engine source.
set -euo pipefail
cd "$(dirname "$0")/.."
V=3.24.2
ARCH="${ARCH:-x86_64}"
case "$ARCH" in x86_64) ISODIR=images/iso;; x86) ISODIR=images/iso-x86;; *) echo "ARCH must be x86_64 or x86"; exit 1;; esac
mkdir -p images src/upstream
ISO=images/alpine-standard-$V-$ARCH.iso
[ -f "$ISO" ] || curl -L -o "$ISO" "https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/$ARCH/alpine-standard-$V-$ARCH.iso"
[ -d $ISODIR/boot ] || { mkdir -p $ISODIR; xorriso -osirrox on -indev "$ISO" -extract / $ISODIR; }
[ -d src/upstream/espeakup ] || git clone -q --depth 1 https://github.com/linux-speakup/espeakup.git src/upstream/espeakup
bash run/get-dectalk.sh
