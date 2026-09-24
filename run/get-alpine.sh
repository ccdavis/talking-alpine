#!/usr/bin/env bash
# Fetch the Alpine 3.24 standard ISO for ARCH (x86_64, or x86 for the 32-bit image) and
# extract it to images/iso (x86_64) or images/iso-x86; clone espeakup into src/upstream and
# (run/get-dectalk.sh) the DECtalk engine source, the MBROLA program source, and the Piper and
# MBROLA voices (run/get-piper-voices.sh, run/get-mbrola-voices.sh), and RHVoice with its English data.
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
MBROLA_REV=274dead162f2826dc38c208fba92efeddb724c33
[ -d src/upstream/MBROLA ] || git clone -q https://github.com/numediart/MBROLA.git src/upstream/MBROLA
git -C src/upstream/MBROLA checkout -q $MBROLA_REV
# RHVoice 1.18.4 with only the submodules the build needs, the English data and four voices
# (alan, bdl, clb, slt: native English speakers with licences that allow passing them on)
[ -d src/upstream/RHVoice ] || git -c advice.detachedHead=false clone -q --depth 1 --branch 1.18.4 https://github.com/RHVoice/RHVoice.git src/upstream/RHVoice
# every run, so an interrupted first fetch is completed
git -C src/upstream/RHVoice submodule update --init --depth 1 -q external/libs/sonic cmake/thirdParty/sanitizers \
    cmake/thirdParty/CCache data/languages/English data/voices/alan data/voices/bdl data/voices/clb data/voices/slt
bash run/get-piper-voices.sh
bash run/get-mbrola-voices.sh
