#!/bin/sh
# Runs inside the a11y-alpine-build container: build libdectalk.a and a
# rust-tdsr with the dectalk feature for x86_64 musl. Output: dist/tdsr
set -e
A=/work/alpine
DIST=$A/${DISTDIR:-dist}
ARCH=${ARCH:-x86_64}
make -C $A/src/dectalk -j"$(nproc)" ARCH=$ARCH out-$ARCH/libdectalk.a
cd /work/rust-tdsr
export CARGO_HOME=/cargo-home CARGO_TARGET_DIR=/work/rust-tdsr/target-musl-$ARCH
export DECTALK_LIB_DIR=$A/src/dectalk/out-$ARCH
cargo build --release --no-default-features --features dectalk
mkdir -p $DIST
cp target-musl-$ARCH/release/tdsr $DIST/tdsr
strip $DIST/tdsr
ls -la $DIST/tdsr
file $DIST/tdsr
