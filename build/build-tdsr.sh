#!/bin/sh
# Runs inside the a11y-alpine-build container: build libdectalk.a and a
# rust-tdsr with the dectalk feature for x86_64 musl. Output: dist/tdsr
set -e
A=/work/alpine
make -C $A/src/dectalk -j"$(nproc)" libdectalk.a
cd /work/rust-tdsr
export CARGO_HOME=/cargo-home CARGO_TARGET_DIR=/work/rust-tdsr/target-musl
export DECTALK_LIB_DIR=$A/src/dectalk
cargo build --release --no-default-features --features dectalk
mkdir -p $A/dist
cp target-musl/release/tdsr $A/dist/tdsr
strip $A/dist/tdsr
ls -la $A/dist/tdsr
file $A/dist/tdsr
