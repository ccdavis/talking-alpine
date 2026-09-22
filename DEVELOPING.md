# Talking Alpine

Public repository with downloads and installation directions: https://github.com/ccdavis/talking-alpine
(`run/sync-public.sh` mirrors this directory there; `release.sh --publish` builds and uploads the image).

A USB stick image that boots a PC or laptop (BIOS or UEFI, x86_64) straight into a talking
shell: Alpine Linux 3.24 diskless, the rust-tdsr screen reader with espeak-ng and DECtalk built
in (alt+s switches), Speakup on the other consoles, and a second partition for the user's files.
Nothing on the machine's own disks is touched. See `PLAN.md` for the design.

## Use

Write `dist/x86_64/talkalpine.img` to a stick of 2 GB or more (`dd`, Rufus in "DD image" mode,
balenaEtcher), boot from it. On a BIOS machine the loader beeps at once; on every machine a
three-note chime plays when the sound card is ready, then the screen reader speaks and you are
at a bash prompt as `user` (no password; `doas` for root). `speech-help` lists the keys.

- `speech-install irssi links` installs packages from the network and keeps them on the stick.
- `speech-save` keeps any other change under `/etc` (the packages list, network settings, the tdsr defaults).
- `speech-wifi` joins a wireless network; `speech-audio-next` moves speech to the next sound card.
- Files in `/home/user` are on the stick's second partition, grown to fill the stick on the
  first boot.

## Build

    bash run/get-alpine.sh      # Alpine ISO, espeakup and DECtalk sources
    bash run/build.sh           # container image; libdectalk.a, tdsr (musl, dectalk), espeakup
    bash run/mkimage.sh         # dist/x86_64/talkalpine.img   (TEST=1: serial getty + tdsr debug log)
    bash run/boot.sh            # QEMU test boot (BIOS); UEFI=1 for OVMF

`ARCH=x86` before each command builds the 32-bit image (`dist/x86/talkalpine-x86.img`) in
the `i386/alpine` container; `ARCH=x86 CPU=pentium3 MEM=512 bash run/boot.sh` boots it on a
32-bit-only virtual CPU. `release.sh` builds both and puts the upload set (zips, binaries,
`SHA256SUMS`) in `dist/release`.

Rootless podman, no loop devices. `run/serial.sh`, `run/mon.sh`, `run/type.sh`, `run/shot.sh`
drive the guest; `run/segrms.py` finds sound in the captured wav.

rust-tdsr is expected at `~/rust-tdsr` (`RUST_TDSR=` to override); the ALSA backend and the
DECtalk feature live there. The DECtalk engine is Fonix's proprietary code from the
`dectalk/dectalk` repository (see `../freedos/research/05-dectalk-sources.md`); the built image
contains it.
