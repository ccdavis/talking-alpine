#!/usr/bin/env bash
# Fetch the Alpine 3.24 standard ISO and extract it to images/iso, clone espeakup
# into src/upstream, and (run/get-dectalk.sh) the DECtalk engine source.
set -euo pipefail
cd "$(dirname "$0")/.."
V=3.24.2
mkdir -p images src/upstream
ISO=images/alpine-standard-$V-x86_64.iso
[ -f "$ISO" ] || curl -L -o "$ISO" "https://dl-cdn.alpinelinux.org/alpine/v3.24/releases/x86_64/alpine-standard-$V-x86_64.iso"
[ -d images/iso/boot ] || { mkdir -p images/iso; xorriso -osirrox on -indev "$ISO" -extract / images/iso; }
[ -d src/upstream/espeakup ] || git clone -q --depth 1 https://github.com/linux-speakup/espeakup.git src/upstream/espeakup
bash run/get-dectalk.sh
