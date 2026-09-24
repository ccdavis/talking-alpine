#!/bin/sh
# Inside the container: the RHVoice libraries (github.com/RHVoice/RHVoice, LGPL-2.1+, fetched by
# run/get-alpine.sh into src/upstream/RHVoice with only the submodules the build needs, the
# English language data and the alan, bdl, clb and slt voices). Alpine does not package RHVoice.
# tdsr loads libRHVoice.so.1 at run time. Output: $DIST/rhvoice/libRHVoice.so.1, libRHVoice_core.so.1
set -e
# (in build/Containerfile too; an image built before that needs them here)
apk add -q cmake samurai boost-dev >/dev/null
S=/work/alpine/src/upstream/RHVoice
rm -rf /tmp/rh && cp -a $S /tmp/rh
cd /tmp/rh
# the data is copied onto the stick by mkimage, not installed by cmake (WITH_DATA=OFF);
# CMAKE_POLICY_VERSION_MINIMUM for the old cmake_minimum_required in its bundled CCache module
cmake -B b -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DWITH_DATA=OFF >/tmp/rh-cfg.log 2>&1 || { tail -20 /tmp/rh-cfg.log; exit 1; }
ninja -C b RHVoice >/tmp/rh-build.log 2>&1 || { grep -i "error" /tmp/rh-build.log | head; exit 1; }
DIST=/work/alpine/${DISTDIR:-dist}; mkdir -p $DIST/rhvoice
cp -L b/src/lib/libRHVoice.so.1 b/src/core/libRHVoice_core.so.1 $DIST/rhvoice/
strip $DIST/rhvoice/*.so.1
ls -la $DIST/rhvoice/
