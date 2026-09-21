#!/usr/bin/env bash
# A blank virtual hard disk for install tests: run/mkdisk.sh [size, default 8G] -> run/talk-disk.qcow2
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
rm -f "$ROOT/run/talk-disk.qcow2" && qemu-img create -q -f qcow2 "$ROOT/run/talk-disk.qcow2" "${1:-8G}" && echo "$ROOT/run/talk-disk.qcow2"
