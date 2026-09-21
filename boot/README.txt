Talking Alpine: a bootable USB stick that speaks.

Partition 1 (this one, ALPINE): the system. Read-only while running.
  boot/            kernel, initramfs, modloop (Alpine Linux 3.24, linux-lts)
  apks/            every package the system installs at boot (no network needed)
  cache/           packages added later with apk, kept by speech-save
  *.apkovl.tar.gz  the saved configuration (speech-save rewrites it)
Partition 2 (SPEECHDATA, ext4): /home/user, your files. Grown to fill the
  stick on the first boot.

Boot from the stick (BIOS or UEFI). A short chime plays when the sound card
is ready, then the screen reader says "TDSR" and you are at a bash prompt as
"user". Type speech-help for the keys and commands.
