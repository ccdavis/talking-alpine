#!/usr/bin/env bash
# Boot the stick image in QEMU as a USB disk, headless.
#   serial  -> run/talk-serial.sock + run/talk-serial.log (kernel console, and a getty with TEST=1 images)
#   monitor -> run/talk-mon.sock  (sendkey, screendump)      VNC :8
#   audio   -> run/talk-audio.wav (Intel HD Audio output: the "did it speak" oracle)
# Env: IMG (default dist/talkalpine.img, or dist/x86/talkalpine-x86.img with ARCH=x86; boots a
#      COPY unless KEEP=1 so first-boot writes do not touch the build), UEFI=1 boots with OVMF,
#      NONET=1 boots without a network card (offline persistence tests), MEM (MB, default 1024),
#      CPUS, CPU (QEMU model, e.g. pentium3 or coreduo for a 32-bit-only machine, default host),
#      DISK=path.qcow2 attaches a hard disk (SATA) for install tests; BOOTDISK=1 boots from it
#      with no stick attached (run/mkdisk.sh makes a blank one).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="${ARCH:-x86_64}"
DEFIMG="$ROOT/dist/talkalpine.img"; [ "$ARCH" = x86_64 ] || DEFIMG="$ROOT/dist/$ARCH/talkalpine-$ARCH.img"
IMG="${IMG:-$DEFIMG}"
RUNIMG="$ROOT/run/talk-test.img"
if [ "${KEEP:-0}" = 1 ]; then RUNIMG="$IMG"; else cp --reflink=auto "$IMG" "$RUNIMG"; fi
if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then ACCEL=(-enable-kvm -cpu "${CPU:-host}"); else ACCEL=(-accel tcg,thread=multi -cpu "${CPU:-max}"); fi
FW=()
if [ "${UEFI:-0}" = 1 ]; then
  cp /usr/share/OVMF/OVMF_VARS_4M.fd "$ROOT/run/ovmf_vars.fd"
  FW=(-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd -drive if=pflash,format=raw,file="$ROOT/run/ovmf_vars.fd")
fi
NET=(-netdev user,id=n0 -device e1000,netdev=n0); [ "${NONET:-0}" = 1 ] && NET=(-nic none)
STICK=(-device qemu-xhci,id=xhci -drive if=none,id=stick,file="$RUNIMG",format=raw -device usb-storage,bus=xhci.0,drive=stick,removable=on,bootindex=0)
HD=()
[ -n "${DISK:-}" ] && HD=(-drive if=none,id=hd0,file="$DISK",format=qcow2 -device ide-hd,drive=hd0,bootindex=1)
if [ "${BOOTDISK:-0}" = 1 ]; then STICK=(); HD=(-drive if=none,id=hd0,file="$DISK",format=qcow2 -device ide-hd,drive=hd0,bootindex=0); fi
rm -f "$ROOT/run/talk-serial.sock" "$ROOT/run/talk-mon.sock"
exec qemu-system-x86_64 "${ACCEL[@]}" -m "${MEM:-1024}" -smp "${CPUS:-2}" -machine q35,pcspk-audiodev=snd0 "${FW[@]}" \
  "${STICK[@]}" "${HD[@]}" \
  -audiodev wav,id=snd0,path="$ROOT/run/talk-audio.wav" -device ich9-intel-hda,id=hda0 -device hda-duplex,bus=hda0.0,audiodev=snd0 \
  "${NET[@]}" \
  -chardev socket,id=ser0,path="$ROOT/run/talk-serial.sock",server=on,wait=off,logfile="$ROOT/run/talk-serial.log" -serial chardev:ser0 \
  -monitor unix:"$ROOT/run/talk-mon.sock",server,nowait \
  -display none -vnc :8 "$@"
