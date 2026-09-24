#!/bin/sh
# Inside the container: the mbrola diphone synthesiser (numediart/MBROLA, AGPL-3.0, fetched by
# run/get-alpine.sh into src/upstream/MBROLA), which espeak-ng runs for its mb-* voices.
# Alpine packages the voice data but not the program. Output: $DIST/mbrola
set -e
S=/work/alpine/src/upstream/MBROLA
rm -rf /tmp/mb && cp -a $S /tmp/mb
# (musl has no __GLIBC__ and x86_64 is not __i386, so Misc/common.h cannot tell the byte
# order; both targets are little-endian)
CFLAGS=-DLITTLE_ENDIAN make -C /tmp/mb -s >/tmp/mb/build.log 2>&1 || { tail -20 /tmp/mb/build.log; exit 1; }
strip /tmp/mb/Bin/mbrola
DIST=/work/alpine/${DISTDIR:-dist}; mkdir -p $DIST
cp /tmp/mb/Bin/mbrola $DIST/mbrola
ls -la $DIST/mbrola
