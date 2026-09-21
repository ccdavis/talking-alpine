#!/bin/sh
# Inside the container: espeakup from src/upstream/espeakup (meson wants
# systemd for its service files, so it is compiled directly).
set -e
S=/work/alpine/src/upstream/espeakup
mkdir -p /tmp/eb
sed "s/@VCS_TAG@/0.90-talkalpine/" $S/src/version.h.in > /tmp/eb/version.h
cc -O2 -std=gnu11 -I/tmp/eb -I$S/src $S/src/cli.c $S/src/espeak.c $S/src/espeakup.c $S/src/queue.c $S/src/signal.c $S/src/softsynth.c $S/src/stringhandling.c \
   -o /tmp/eb/espeakup $(pkg-config --cflags --libs espeak-ng alsa) -lpthread -lm 2>&1 | grep -v warning || true
strip /tmp/eb/espeakup
DIST=/work/alpine/${DISTDIR:-dist}; mkdir -p $DIST
cp /tmp/eb/espeakup $DIST/espeakup
ls -la $DIST/espeakup
