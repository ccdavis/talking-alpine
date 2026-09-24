# Talking Alpine: a USB stick that boots any x86 PC into a screen-reader shell

Date: 2026-09-20. Status: image builds and boots in QEMU (BIOS and UEFI); real hardware untested.

## Goal

A bootable USB stick for post-2002 PCs and laptops (BIOS or UEFI) that comes up talking without
touching the machine's disks: Alpine Linux diskless (everything loads into RAM), rust-tdsr as the
screen reader with espeak-ng and DECtalk built in, Speakup for the other consoles and the end of
boot, and a persistent second partition for the user's files. Packages the user installs are kept
on the stick with Alpine's `lbu`.

## Layout of the stick

| Partition | FS | Label | Contents |
|---|---|---|---|
| 1 | FAT32, bootable (type 0c) | `ALPINE` | `boot/` kernel + initramfs + modloop, `boot/syslinux/` (BIOS), `efi/boot/bootx64.efi` + `boot/grub/grub.cfg` (UEFI), `apks/` a signed repository with every package in `/etc/apk/world` and its dependencies, `cache/` for packages added later, `talkalpine.apkovl.tar.gz` the configuration, `piper-voices/` the Piper voices (190 MB, read in place), `mbrola/` the English MBROLA voices (28 MB, behind a `/usr/share/mbrola` link), `rhvoice/` RHVoice's English data and four voices (38 MB) |
| 2 | ext4 | `SPEECHDATA` | `/home/user`; grown to the end of the stick on first boot (`speech-grow`) |

The MBR carries syslinux's boot code. UEFI firmware finds `efi/boot/bootx64.efi` (the grub from
the Alpine ISO). Both loaders boot the same kernel with
`modules=loop,squashfs,sd-mod,usb-storage,vfat,ext4 quiet` (no `console=`: the initramfs adds a getty for every console it names, which would fight tdsr for tty1).

At boot Alpine's initramfs finds the apkovl and the `.boot_repository` marker on the stick,
installs `/etc/apk/world` from the stick's repository into a tmpfs root, and unpacks the overlay
over it. The overlay's `/etc/apk/keys/talkalpine.rsa.pub` is what makes the repository index
trusted (the initramfs merges its own keys into the overlay's directory, so both remain).

## What is in the package (`pkg/`) and the overlay (`overlay/`)

`pkg/` becomes `talkalpine-*.apk`: the tools in `usr/bin`, the chime in `usr/share/talkalpine`,
the three init scripts and `etc/local.d/speech.start`. `overlay/` is the apkovl: only
configuration under `/etc`. The split matters because `lbu commit` never backs up
`/etc/init.d` (it is excluded in apk's protected paths), so anything there must come from a
package or it is lost at the first `speech-save`.

- `etc/inittab`: tty1 runs `speech-session`, which ends in `login -f user`; the user's login shell `speech-shell` is tdsr around bash on tty1 and plain bash elsewhere;
  it exports the standard PATH first, because busybox login gives a non-root user only
  /bin:/usr/bin and the tty1 shell is not a login shell (ip, iw, wpa_supplicant, udhcpc, apk,
  rc-service are in /sbin or /usr/sbin); doas sets the same PATH (`etc/doas.d/speech.conf`).
  tty2-4 are ordinary logins, read by Speakup. `TEST=1` images add a getty on ttyS0.
- `etc/init.d/speech-audio` (boot runlevel): waits for a sound card, runs `speech-unmute`
  (`alsactl init` on every card, then unmutes the usual controls at 85 %), loads `speakup_soft`.
- `etc/init.d/espeakup` (default): Speakup's software synth through espeak-ng (the binary is
  built from source in `build/build-espeakup.sh` because Alpine only packages it in testing).
- `etc/init.d/speech-vtwatch` (default): polls the active console and silences Speakup on tty1,
  so tdsr and Speakup never read the same screen.
- The package is built with `abuild -F -d` at image build time (`build/talkalpine/APKBUILD`; apk
  mkpkg only writes the v3 format, which `apk index` cannot read), signed with the repository key
  and listed in `world`.
- `speech-session`: mounts `SPEECHDATA` on `/home/user` (`speech-grow` first extends the
  partition with sfdisk + resizepart, then the filesystem is grown online with resize2fs from
  e2fsprogs-extra; verified on a 3 GB virtual stick), plays the ready chime through ALSA, then `login -f user` on tty1.
- `speech-save`: `lbu commit -d` (as root through doas); `speech-install pkg...` is
  apk update + add + save. `apk` remounts the stick read-write itself for the cache.
- `speech-audio-next`: rewrites `/etc/asound.conf` to the next card.
- `speech-wifi`: scan, pick a network, wpa_supplicant + udhcpc.
- `speech-help`: keys and commands.
- `etc/speech/tdsr.cfg` is copied to `/home/user/.tdsr.cfg` when the data partition has none.
- Accounts: `user` (uid 1000, no password, groups audio/input/video/wheel/netdev/...), root locked,
  `doas` without password for `user`.
- `etc/apk/world`: alpine-base, alsa, espeak-ng, bash, nano, tmux, links, htop, mc, openssh,
  wpa_supplicant, iw, wireless-regdb, sof-firmware, alsa-ucm-conf and the wifi/ethernet firmware
  packages (iwlwifi, ath9k_htc, ath10k, brcm, mediatek, rtlwifi, rtw88, rtw89, rtl_nic).

## rust-tdsr changes (in ~/rust-tdsr)

- New backend `src/speech/backends/alsa.rs`, `[speech] backend = alsa` (or `TDSR_BACKEND=alsa`):
  one audio thread owns libasound (dlopen) and the engines; `snd_pcm_set_params` with a 50 ms
  buffer; every utterance is written as the engine produces it, `snd_pcm_drain` after the last
  queued utterance so short ones (letters) play at once, `snd_pcm_drop` on cancel. Cancel is an
  epoch counter checked per chunk. Engines are behind a small trait: espeak-ng (the existing
  `Espeak` dlopen wrapper, with a new `synth_to` chunk sink) and DECtalk (feature `dectalk`,
  static link of `libdectalk.a` from `src/dectalk/`, the same ARM7 single-threaded configuration
  as the DOS port). DECtalk gets each utterance whole (its intonation spans the sentence and it
  handles the punctuation inside one call); only text over 400 characters is split, preferring
  sentence ends, so a cancel discards little; it must never be told to halt (the DOS work showed
  that hangs the next utterance). `[:say letter]` spells typed characters. The engine is built
  with `CHEESY_DICT_COMPRESSION` (the dictionary layout the ARM7 code reads) and the full US
  dictionary, compiled from upstream's `Dic_us.txt` (`src/dectalk/Makefile`, `glue/dic2c.py`).
  Until 2026-09-23 the define was missing: dictionary lookups missed, function words were
  stressed and every word got its own pitch accent. Output is now sample-identical to
  upstream's Linux build.
- Piper (feature `piper`, added 2026-09-23): neural voices run in-process with rten, a pure
  Rust ONNX runtime (Alpine has no onnxruntime for x86; rten gives one code path for both
  images). espeak-ng phonemises with `espeak_TextToPhonemesWithTerminator` as Piper does
  (Alpine patches it into 1.52). One model run per sentence on a helper thread, the next
  sentence synthesised while one plays; a cancel returns at once (2 ms measured) and the
  helper drops the sentence it is on. Voices: joe (CC0), kristin and cori (public domain),
  medium quality, 22050 Hz, fetched by `run/get-piper-voices.sh` from a pinned revision with
  SHA256 checks, kept on partition 1 and read from `/media/usb/piper-voices`;
  `speech-install-disk` copies them to `/usr/share/piper-voices`. A voice loads on first use:
  about 100 MB of RAM, 240 MB peak while loading (fits the 32-bit image in 512 MB, tested).
  Speed on one core of an i7-14700: about 12x real time (x86_64), 4x (32-bit: rten's fast
  kernels are AVX2/x86_64 only), so old 32-bit machines may be near real time.
- MBROLA (added 2026-09-23): espeak-ng's mb-us1/us2/us3/en1 voices, which tdsr already lists
  and selects like any espeak-ng voice (alt+c V; `tdsr --list-voices`). Alpine packages the
  voice data but not the program, so `build/build-mbrola.sh` compiles numediart/MBROLA (pinned
  in `run/get-alpine.sh`; `-DLITTLE_ENDIAN`, which musl's headers do not let it work out) into
  the talkalpine package; `run/get-mbrola-voices.sh` fetches the four English databases with
  their licence (free distribution without charge, notice included) onto partition 1, and
  `speech-session` links `/usr/share/mbrola` there at boot so they stay out of the RAM root;
  `speech-install-disk` copies them. tdsr also offers them as an engine of their own
  (`mbrola`, after eSpeak on alt+s, voices `mbrola:us1` etc., its own `mbrola_rate`: 80 wpm
  at 0, 190 at 50, 300 at 100), since eSpeak's rate is far too fast for diphone voices; the
  two engines share one espeak-ng and each sets its voice, rate and volume before speaking.
- RHVoice and Pico (added 2026-09-23, after comparing samples of MBROLA, Pico, Flite and
  RHVoice; Flite brought nothing over the others). tdsr loads `libRHVoice.so.1` and
  `libttspico.so.0` at run time (no build feature); each is an engine with its own rate.
  RHVoice is not packaged by Alpine: `build/build-rhvoice.sh` builds 1.18.4 (cmake,
  `WITH_DATA=OFF`, Alpine's boost headers) from a minimal clone made by `run/get-alpine.sh`;
  its libraries go in the talkalpine package (needs libstdc++), its English data and the
  voices alan, bdl, clb, slt (native speakers, licences that allow passing them on; lyubov
  is CC BY-NC-ND and non-native, evgeniy-eng needs the authors' permission) on partition 1,
  read from `/media/usb/rhvoice` (`rhvoice_data`). Pico is Alpine's `picotts` (en-US, en-GB
  and four other languages, 6 MB in the RAM root). RHVoice plays at 24000 Hz, which
  alsa-lib's snd_pcm_set_params refuses on the 48000 Hz dmix at any latency ("Unable to get
  period size"); tdsr then opens the device at twice the rate and upsamples.
- `alt+s` (`KeyAction::SwitchEngine`) steps through the loaded engines (espeak-ng, MBROLA,
  DECtalk, Piper, RHVoice, Pico) and announces the new one; each engine keeps its own rate
  (`rate`, `mbrola_rate`, `dectalk_rate`, `piper_rate`, `rhvoice_rate`, `pico_rate`), and
  alt+c r sets the one speaking.
- Config keys: `engine`, `alsa_device`, `alsa_buffer`, `dectalk_rate`, `dectalk_voice`,
  `piper_rate`, `piper_voice`, `piper_voices`, `mbrola_rate`, `mbrola_voice`, `rhvoice_rate`, `rhvoice_voice`,
  `rhvoice_data`, `pico_rate`, `pico_voice`, `pico_lang`; voices `dectalk:paul`,
  `piper:en_US-joe-medium`, `rhvoice:slt`, `pico:en-GB` appear after the espeak-ng voices in
  the config menu.

## Publishing

The public repository https://github.com/ccdavis/talking-alpine is a mirror of this directory
(`run/sync-public.sh`, which keeps the public README and renames ours to DEVELOPING.md). Its CI
builds the image with docker; `release.sh --publish` builds locally and uploads
`talkalpine.img.zip`, `tdsr`, `espeakup` and `SHA256SUMS` as a GitHub release.

## Build

    bash run/get-alpine.sh      # ISO (3.24.2), espeakup, DECtalk, MBROLA and RHVoice sources, Piper and MBROLA voices
    bash run/build.sh           # container image, libdectalk.a, tdsr, espeakup
    bash run/mkimage.sh         # dist/x86_64/talkalpine.img   (TEST=1 for the QEMU harness)
    bash run/boot.sh            # QEMU, BIOS; UEFI=1 for OVMF

Everything runs rootless in a podman container (`build/Containerfile`): the FAT partition is
filled with mtools and gets syslinux from the Linux installer on the image file, the ext4
partition with `mkfs.ext4 -d`, and the two are concatenated behind an sfdisk MBR.

## Installing to a disk (optional)

`speech-install-disk` (in the package) wraps Alpine's `setup-disk -m sys -k lts -s 0`: it lists
the disks minus the stick's, asks for the disk, the word ERASE and a password, answers the
installer's own erase question on stdin, and afterwards mounts the new root to adjust it:
`/etc/speech/installed` marker (the speech scripts then skip the data partition, lbu and the
stick), stick repository and cache removed from apk's configuration, stick lines out of
fstab, `/home/user` copied from the data partition, password via chpasswd. The boot-loader
packages (syslinux, grub-bios, grub-efi, dosfstools, mkinitfs, lsblk) sit in the stick's
repository without being installed on the stick (`build/repo-extra.txt`), so the install works
offline. If the mirror answers a 5 s probe, the script offers (default no) to keep the network
repositories, which adds package updates and firmware packages for the machine's devices;
otherwise /etc/apk/repositories holds only the stick's repository while setup-disk runs, so
apk never waits on the network (the full list is put back on the stick and on the disk).
`ERASE_DISKS` is deliberately not used: setup-disk then takes the boot medium's disk to
be the first SCSI disk, and when that is the target (stick sdb, target sda) it copies the
module tree into RAM first, which fills it. QEMU tests: BIOS with network and UEFI without,
each booted from the installed disk with the stick removed (`DISK=`, `BOOTDISK=1` in
run/boot.sh, `run/mkdisk.sh`).

## Decisions

- Alpine diskless rather than Debian live: boots to RAM in seconds, stick read-only while
  running, `lbu` persistence, and the stock `linux-lts` kernel has Speakup, pcspkr and snd-pcsp.
- Speakup + espeakup in addition to tdsr: tdsr only hears its own pty; Speakup speaks the end
  of the boot, login prompts and the other consoles.
- No grub `play` chime: it only exists in BIOS grub and most machines after 2008 have no
  speaker. syslinux beeps through the BIOS (a BEL in its message) on BIOS boots; the first
  reliable sound everywhere is the ALSA chime once the sound card is up.
- `alsactl init` for unmuting, not a hand-written control list.
- `default` ALSA device through dmix so tdsr and espeakup can play at the same time.
- Direct ALSA from tdsr, no speech-dispatcher: cancel latency is the device buffer (50 ms).
- A 32-bit image (`ARCH=x86`: the Alpine x86 ISO, tdsr and DECtalk built in the
  `i386/alpine` container, `dist/x86/talkalpine-x86.img`) for Pentium M, Core Duo, early Atom
  and older machines. Alpine's x86 kernel is built for i586 without PAE, so nothing after
  the original Pentium is excluded. It drops the firmware for wireless chips that only exist
  in 64-bit-era machines (`build/world-drop-x86.txt`) to keep the RAM root small; the x86 ISO
  also carries a 32-bit UEFI loader (bootia32.efi), which is copied when present.
