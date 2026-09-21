# Talking Alpine

A USB stick that boots a PC or laptop straight into a talking Linux shell, without touching
the machine's own disks. Plug it in, boot from it, and within about half a minute you hear a
chime and a screen reader at a bash prompt.

- **Alpine Linux 3.24** running from RAM (the stick is read-only while running, so it can be
  pulled at any time).
- **[rust-tdsr](https://github.com/ccdavis/rust-tdsr)** as the screen reader, with two speech
  engines built in: **espeak-ng** (fast, good for code and typing) and **DECtalk** (the classic
  formant voice, good for reading). `Alt+s` switches between them. Speech goes straight to the
  sound card; a keystroke stops it within about 50 ms.
- **Speakup** reads the other consoles (`Alt+F2` to `Alt+F4`) and the end of the boot.
- A second partition for your files, grown to fill the stick on the first boot.
- Packages you install and settings you change are kept on the stick (`speech-install`,
  `speech-save`).
- Boots on BIOS and UEFI machines (x86-64; Secure Boot must be off).

Status: built and exercised in QEMU (BIOS and UEFI, Intel HD Audio). **Not yet tested on real
hardware.** Reports welcome.

## Download and write the stick

1. Get `talkalpine.img.zip` from the [latest release](https://github.com/ccdavis/talking-alpine/releases/latest)
   and unzip it: `talkalpine.img` is a 1.4 GB raw disk image.
2. Write it to a USB stick of **2 GB or more**. Everything on the stick is erased.
   - Linux or macOS: find the stick's device (`lsblk` / `diskutil list`), then
     `sudo dd if=talkalpine.img of=/dev/sdX bs=4M status=progress conv=fsync`
     (`/dev/rdiskN` on macOS). Double-check the device name.
   - Windows: [Rufus](https://rufus.ie) in "DD Image" mode, or
     [balenaEtcher](https://etcher.balena.io). Both are screen-reader accessible.
3. Boot the PC from the stick. On most machines a key at power-on opens a boot menu
   (F12, F11, F8, Esc or F2 depending on the maker); otherwise set the USB stick first in the
   firmware's boot order. With UEFI, disable Secure Boot.

## What you hear

- On a BIOS machine, one beep from the PC speaker as soon as the boot loader runs (the stick
  was chosen). UEFI machines usually have no speaker; skip this.
- A three-note chime when the sound card is up (about 20 to 40 seconds in). If you never
  hear it, the sound card was not found or is muted: see below.
- The screen reader announces itself and you are at a bash prompt as `user`, no password.
  `doas` runs commands as root, also without a password.

Type `speech-help` for the keys and commands. The essentials, `Alt` plus a letter:

| Keys | Action |
|---|---|
| `u` `i` `o` | previous, current, next line |
| `j` `k` `l` | previous, current, next word (`k` twice spells it) |
| `m` `,` `.` | previous, current, next character |
| `U` `O` | top, bottom of the screen |
| `x` | silence |
| `s` | switch engine: espeak-ng / DECtalk |
| `c` | configuration menu (rate, volume, voice) |
| `q` | quiet mode (stop reading output automatically) |
| `t` | full-screen program mode |

Commands:

| Command | What it does |
|---|---|
| `speech-install irssi links` | install packages from the network and keep them on the stick |
| `speech-save` | keep changes under `/etc` (network, tdsr settings, added services) |
| `speech-wifi` | scan, pick a network, enter the password; remembered after `speech-save` |
| `speech-audio-next` | send speech to the next sound card (HDMI vs analogue); then type `exit` |
| `speech-help` | this list |

Your files live in `/home/user`, on the stick's second partition.

## If it does not talk

- The screen shows the boot; a sighted helper can read the last lines. `Alt+F2` gives a login
  console read by Speakup.
- No chime: the card may need firmware that is not on the stick, or the codec's mixer has a
  control the unmute script does not know. Log in on `Alt+F2` (`user`, no password), run
  `alsamixer` (`doas alsamixer`) and unmute with `m`, or `speech-audio-next` to try the next
  card. `doas dmesg | grep -i firmware` lists missing firmware.
- Chime but no speech: `Alt+F1`, then `Alt+i` to hear the current line. If tdsr died, the
  session restarts it; `cat ~/tdsr.log` after enabling debug logging (`doas touch
  /etc/speech/debug`, then `exit`).

## Build it yourself

    git clone https://github.com/ccdavis/rust-tdsr ~/rust-tdsr
    git clone https://github.com/ccdavis/talking-alpine && cd talking-alpine
    bash run/get-alpine.sh      # Alpine ISO, espeakup and DECtalk sources
    bash run/build.sh           # container image; libdectalk.a, tdsr (musl, dectalk), espeakup
    bash run/mkimage.sh         # dist/talkalpine.img   (TEST=1 adds a serial getty + tdsr debug log)
    bash run/boot.sh            # QEMU test boot (BIOS); UEFI=1 for OVMF; NONET=1 offline

Everything runs in a rootless podman container (`PODMAN=docker` works too); no loop devices.
`PLAN.md` explains the design and the decisions; `DEVELOPING.md` the QEMU harness.

## Licences

The scripts, configuration and rust-tdsr are GPL-3.0-or-later; Alpine Linux and its packages
under their own licences. The DECtalk engine in the image is Fonix's proprietary code from the
[dectalk/dectalk](https://github.com/dectalk/dectalk) repository, built as described in
`src/dectalk/`; it is not part of this repository and is fetched at build time. The image is
distributed for assistive use.
