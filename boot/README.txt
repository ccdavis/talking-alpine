Talking Alpine: a bootable USB stick that speaks.

Partition 1 (this one, ALPINE): the system. Read-only while running.
  boot/            kernel, initramfs, modloop (Alpine Linux 3.24, linux-lts)
  apks/            every package the system installs at boot (no network needed)
  cache/           packages added later with apk, kept by speech-save
  *.apkovl.tar.gz  the saved configuration (speech-save rewrites it)
  piper-voices/    the Piper neural voices (joe, kristin, cori) and their model cards
  mbrola/          the MBROLA English voices (us1, us2, us3, en1) with their licence
  rhvoice/         RHVoice's English data and voices (alan, bdl, clb, slt), with licences

Sources: the programs are built from github.com/ccdavis/rust-tdsr (tdsr),
github.com/numediart/MBROLA commit 274dead162f2826dc38c208fba92efeddb724c33 (mbrola, AGPL-3.0),
github.com/RHVoice/RHVoice tag 1.18.4 (libRHVoice, LGPL-2.1), github.com/dectalk/dectalk
(DECtalk) and github.com/linux-speakup/espeakup; the build scripts are at
github.com/ccdavis/talking-alpine.
Partition 2 (SPEECHDATA, ext4): /home/user, your files. Grown to fill the
  stick on the first boot.

Boot from the stick (BIOS or UEFI). A short chime plays when the sound card
is ready, then the screen reader says "TDSR" and you are at a bash prompt as
"user". Type speech-help for the keys and commands.
