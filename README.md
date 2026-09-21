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
- Boots on BIOS and UEFI machines (Secure Boot must be off). Two images: 64-bit for any PC
  since about 2007, and 32-bit for Pentium M, Core Duo, early Atom and older machines.

Status: built and exercised in QEMU (BIOS and UEFI, Intel HD Audio). **Not yet tested on real
hardware.** Reports welcome.

## Download and write the stick

1. Get the image from the [latest release](https://github.com/ccdavis/talking-alpine/releases/latest)
   and unzip it:
   - `talkalpine.img.zip` for any 64-bit PC (everything sold since about 2007, and many from
     2004 on). Unzips to `talkalpine.img`, a raw disk image of about 1.4 GB.
   - `talkalpine-x86.img.zip` for a 32-bit-only machine: see "Which image: 64-bit or
     32-bit?" below. Unzips to `talkalpine-x86.img`.
2. Write it to a USB stick of **2 GB or more**, following the steps for your system below.
   Writing erases everything on the stick. The image must be written as a raw disk image
   (sector by sector), not copied onto the stick as a file.
3. Boot the PC from the stick (see "Booting from the stick").

`SHA256SUMS` in the release lists the checksums if you want to verify the download
(`sha256sum talkalpine.img.zip` on Linux, `shasum -a 256 talkalpine.img.zip` on macOS,
`certutil -hashfile talkalpine.img.zip SHA256` on Windows).

### Linux

1. Plug the stick in and find its device name. `lsblk` lists disks with their sizes; the
   stick is the one whose size matches and that appeared when you plugged it in, for example
   `sdb`. Use the whole disk (`/dev/sdb`), not a partition (`/dev/sdb1`).
2. If your desktop mounted the stick, unmount it: `udisksctl unmount -b /dev/sdb1` or
   `sudo umount /dev/sdb*`.
3. Write the image:

       sudo dd if=talkalpine.img of=/dev/sdb bs=4M status=progress conv=fsync

   `status=progress` reports progress; `conv=fsync` makes dd wait until everything is
   really on the stick. It takes one to five minutes depending on the stick.
4. When dd has finished, run `sync` and remove the stick.

Getting the device name wrong overwrites another disk, so check `lsblk` twice.

### macOS

1. Plug the stick in and find its disk number: `diskutil list` shows every disk; the stick
   is an "external, physical" disk whose size matches, for example `/dev/disk4`.
2. Unmount it (unmount, not eject): `diskutil unmountDisk /dev/disk4`.
3. Write the image, using the raw device (`rdisk`, which is much faster than `disk`):

       sudo dd if=talkalpine.img of=/dev/rdisk4 bs=4m status=progress

   (macOS dd wants a lowercase `m`; on older macOS versions without `status=progress`, press
   Control-T to see how far it has got.)
4. macOS may say the disk is not readable when dd finishes; choose Ignore. Then
   `diskutil eject /dev/disk4` and remove the stick.

Alternatively, [balenaEtcher](https://etcher.balena.io) does the same from a window: Flash
from file, pick `talkalpine.img`, Select target, Flash.

### Windows

Either tool below works with a screen reader.

**Rufus** ([rufus.ie](https://rufus.ie), a single .exe, no installation):

1. Plug the stick in and start Rufus. It asks to check for updates; No is fine.
2. Device: choose the stick (Rufus only lists removable drives).
3. Boot selection: press Select and open `talkalpine.img`. Rufus recognises it as a disk
   image; if it asks for a mode, choose **DD Image** mode, not ISO mode.
4. Leave the other options as they are and press Start. Confirm the warning that the stick
   will be erased. When the status bar says Ready, close Rufus and remove the stick.

**balenaEtcher** ([etcher.balena.io](https://etcher.balena.io)):

1. Flash from file, open `talkalpine.img`.
2. Select target, tick the stick.
3. Flash. Windows asks for administrator permission. Etcher verifies the write afterwards.

Windows may report that the stick needs to be formatted after writing, because it cannot
read the Linux partition. Choose Cancel; the stick is fine.

### Which image: 64-bit or 32-bit?

The 64-bit image needs a CPU with the x86-64 instructions. Almost every PC made since 2007
has one, and so do many from 2004 to 2006. If you boot it on an older machine, the kernel
stops at once with a message on the screen and you hear nothing after the BIOS beep: that is
the sign to use the 32-bit image, which runs on any Pentium-class or newer CPU with 512 MB of
RAM or more (the system itself takes about 90 MB of RAM plus the kernel; 256 MB is too
little for the RAM disk it runs from). Machines that need the 32-bit image include:

- **Pentium M and Celeron M laptops** (2003 to 2008): the Centrino era. IBM/Lenovo ThinkPad
  T40, T41, T42, T43, R50, R51, R52, X31, X32, X40, X41; Dell Latitude D400, D410, D505,
  D600, D610, D800, D810, Inspiron 600m, 700m, 8600; HP/Compaq nc4000, nc6000, nc6220,
  nx6110, nc8230; Toshiba Portege M200, R100, Tecra M2, M3, Satellite A/M series; Fujitsu
  LifeBook P and S series; Sony VAIO of the period; Acer TravelMate and Aspire of the period.
- **Core Duo and Core Solo laptops** (2006 to early 2007, "Yonah"): the first Intel Macs
  (MacBook and MacBook Pro of early 2006, iMac and Mac mini of 2006; they boot USB sticks
  with the Option key), ThinkPad T60 and X60 with a Core Duo (the Core 2 Duo versions are
  64-bit), Dell Latitude D620 and Inspiron 6400 with Core Duo, many early 2006 laptops. The
  CPU name "Core Duo" or "Core Solo" without the "2" is the tell.
- **Intel Atom netbooks** with the N270, N280, Z5xx or the original 230 (2008 to 2010): Asus
  Eee PC 901, 1000, 1000H, 1005HA; Acer Aspire One D150, D250; Dell Mini 9, 10, 10v; HP Mini
  1000, 110, 210; MSI Wind U100; Samsung NC10; Lenovo IdeaPad S10. (Atom N450, N455, N550,
  D510 and later are 64-bit.)
- **Pentium 4 and Celeron desktops before 2005** (Willamette and Northwood cores, and every
  Pentium III, Pentium II, Celeron of the 1990s), and AMD **Athlon XP, Duron, Sempron (socket
  A)** and **Athlon/K6** desktops. A Pentium 4 from 2005 on (Prescott with EM64T) and any
  Athlon 64 are 64-bit.
- **Thin clients and small-board PCs** with VIA C3, C7 or Eden, AMD Geode LX or NX, or Intel
  Atom Z5xx: Wyse, HP t5xxx and Neoware thin clients, Fit-PC 1, and industrial boards.

How to tell on a machine you can still run: on Linux `grep -c lm /proc/cpuinfo` prints 0 on a
32-bit-only CPU; on Windows the System information page says "x64-based PC" for a 64-bit
one; a CPU name can be looked up at ark.intel.com, where "Instruction Set 64-bit" is listed.
When in doubt, try the 64-bit image first, then the 32-bit one.

The 32-bit image is the same system: 32-bit Alpine, kernel built for Pentium-class CPUs (no
PAE needed), tdsr with both engines, tested in QEMU on a Pentium III with 512 MB. It carries
only the wireless firmware such machines can use (Intel 3945 and 4965, Ralink, Realtek,
Atheros USB) instead of the 100 MB of modern firmware in the 64-bit image, to keep the RAM
disk small. Intel PRO/Wireless 2100 and 2200 cards need firmware Alpine does not ship;
Broadcom cards of the period need firmware extracted from Windows drivers. Wired Ethernet
always works. The USB stick must be bootable from the BIOS, which most machines from
about 2002 on can do; older ones may need a BIOS update or a boot floppy such as Plop Boot
Manager to chain-load USB.

### Booting from the stick

Most machines open a boot menu with a key at power-on: F12 on Dell, Lenovo and many others,
F11 or F8 on many desktops, Esc or F9 on HP, Option (Alt) on Intel Macs, F2 or Delete opens
the firmware settings where the boot order can be changed instead. Choose the USB stick;
on a UEFI machine pick the entry that says UEFI if there are two. Secure Boot has to be
turned off in the firmware settings, since the stick's boot loader is not signed for it.

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

`ARCH=x86` in front of each of those builds the 32-bit image (`dist/x86/talkalpine-x86.img`)
in a 32-bit Alpine container; `ARCH=x86 CPU=pentium3 bash run/boot.sh` boots it on a
32-bit-only virtual CPU.

Everything runs in a rootless podman container (`PODMAN=docker` works too); no loop devices.
`PLAN.md` explains the design and the decisions; `DEVELOPING.md` the QEMU harness.

## Licences

The scripts, configuration and rust-tdsr are GPL-3.0-or-later; Alpine Linux and its packages
under their own licences. The DECtalk engine in the image is Fonix's proprietary code from the
[dectalk/dectalk](https://github.com/dectalk/dectalk) repository, built as described in
`src/dectalk/`; it is not part of this repository and is fetched at build time. The image is
distributed for assistive use.
