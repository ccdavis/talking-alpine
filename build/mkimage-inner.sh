#!/bin/sh
# Runs inside the a11y-alpine-build container (see run/mkimage.sh). Builds
# dist/x86_64/talkalpine.img (dist/x86/talkalpine-x86.img), a BIOS+UEFI bootable USB image, without root:
#   partition 1  FAT32 "ALPINE"     kernel, initramfs, modloop, signed apk repo,
#                                   cache dir, the apkovl (mtools + syslinux)
#   partition 2  ext4 "SPEECHDATA"  /home/user                (mkfs.ext4 -d)
# Env: TEST=1 adds a serial getty for the QEMU harness; P1_MB, P2_MB sizes.
set -eu
A=/work/alpine
ARCH=${ARCH:-x86_64}
IMAGES_DIR=${IMAGES_DIR:-$A/images}
ISO=$IMAGES_DIR/$(basename "${ISODIR:-iso}")
DIST=$A/${DISTDIR:-dist}
IMGNAME=talkalpine.img; [ "$ARCH" = x86_64 ] || IMGNAME=talkalpine-$ARCH.img
W=/tmp/mk
P1_MB=${P1_MB:-1200}
P2_MB=${P2_MB:-160}
rm -rf $W; mkdir -p $W/p1 $W/p2 $W/ovl $DIST
EXTRA_PKG_DIR=$W/pkgs; mkdir -p $EXTRA_PKG_DIR
printf '%s\n' "$ISO/apks" https://dl-cdn.alpinelinux.org/alpine/v3.24/main https://dl-cdn.alpinelinux.org/alpine/v3.24/community > $W/repos
# the world list, minus the packages build/world-drop-$ARCH.txt leaves out of this image
WORLD=$W/world; grep -v '^#' $A/overlay/etc/apk/world > $WORLD
if [ -f $A/build/world-drop-$ARCH.txt ]; then grep -v '^#' $A/build/world-drop-$ARCH.txt | grep -v -x -F -f - $WORLD > $WORLD.t && mv $WORLD.t $WORLD; fi
if [ -f $A/build/world-add-$ARCH.txt ]; then grep -v '^#' $A/build/world-add-$ARCH.txt >> $WORLD; fi
KEY=$A/keys/talkalpine.rsa

echo "== talkalpine package"
# pkg/ (tdsr, espeakup, the speech-* scripts, the chime, the init scripts)
# as an apk built with abuild (v2 format, which apk index accepts), signed
# with the same key as the repository index. The apkovl then carries only
# configuration under /etc: lbu does not back up /etc/init.d (apk protected
# paths), so the init scripts have to be package files.
PKG=$W/pkgroot; rm -rf $PKG; mkdir -p $PKG/usr/bin $PKG/usr/share/talkalpine
cp -a $A/pkg/. $PKG/
install -m 755 $DIST/tdsr $PKG/usr/bin/tdsr
install -m 755 $DIST/espeakup $PKG/usr/bin/espeakup
# MBROLA: the program in the package, the voices on partition 1 (read in place, not copied
# into the RAM root); espeak-ng and tdsr look for them in /usr/share/mbrola/<voice>/<voice>,
# which speech-session links to the stick at boot
install -m 755 $DIST/mbrola $PKG/usr/bin/mbrola
# RHVoice: the libraries in the package, the English data and voices on partition 1 (tdsr's
# rhvoice_data points there, then at /usr/share/RHVoice for a disk install)
mkdir -p $PKG/usr/lib
install -m 755 $DIST/rhvoice/libRHVoice.so.1 $DIST/rhvoice/libRHVoice_core.so.1 $PKG/usr/lib/
if [ "$ARCH" = x86 ]; then
    # Only the Core Duo era Intel wireless firmware, out of the 100+ MB linux-firmware-intel
    FW=$IMAGES_DIR/fw-cache; mkdir -p $FW
    ls $FW/linux-firmware-intel-*.apk >/dev/null 2>&1 || apk --repositories-file $W/repos --keys-dir /etc/apk/keys --arch $ARCH fetch --output $FW linux-firmware-intel >/dev/null
    mkdir -p $PKG/lib/firmware
    tar -xzf $FW/linux-firmware-intel-*.apk -C $PKG --wildcards 'lib/firmware/iwlwifi-3945-*' 'lib/firmware/iwlwifi-4965-*' 2>/dev/null
    ls $PKG/lib/firmware/
fi
mkdir -p $W/abuild/talkalpine && sed "s/^arch=.*/arch=\"$ARCH\"/" $A/build/talkalpine/APKBUILD > $W/abuild/talkalpine/APKBUILD
cp $A/overlay/etc/apk/keys/talkalpine.rsa.pub /etc/apk/keys/   # so abuild and apk index trust the package
( cd $W/abuild/talkalpine && TALKALPINE_ROOT=$PKG PACKAGER_PRIVKEY=$KEY PACKAGER="Talking Alpine" \
  abuild -F -d -P $W/repo > $W/abuild.log 2>&1 || { tail -8 $W/abuild.log; exit 1; } )
cp $W/repo/abuild/$ARCH/talkalpine-*.apk $EXTRA_PKG_DIR/
ls -la $EXTRA_PKG_DIR/

echo "== packages"
# Every package in /etc/apk/world with its dependencies, from the ISO's own
# repository first and the 3.24 mirror for the rest, into a repository on the
# stick. Downloads are kept in images/apks-extra between builds.
EXTRA=$IMAGES_DIR/apks-extra; [ "$ARCH" = x86_64 ] || EXTRA=$IMAGES_DIR/apks-extra-$ARCH; mkdir -p $EXTRA
apk --repositories-file $W/repos --keys-dir /etc/apk/keys --arch $ARCH fetch --recursive --output $EXTRA \
    $(grep -v '^talkalpine$' $WORLD) linux-lts $(grep -v '^#' $A/build/repo-extra.txt) > $W/fetch.log 2>&1 || { tail -5 $W/fetch.log; exit 1; }
# The cache keeps every version fetched so far (a new kernel on the mirror left the old
# one beside it, 146 MB): keep only the newest file of each package.
seen=" "
for f in $(ls -t $EXTRA/*.apk); do
    n=$(basename "$f" | sed 's/-[0-9][^-]*-r[0-9]*\.apk$//')
    case "$seen" in *" $n "*) echo "   dropping superseded $(basename "$f")"; rm -f "$f";; *) seen="$seen$n ";; esac
done
mkdir -p $W/p1/apks/$ARCH
cp $ISO/apks/$ARCH/*.apk $W/p1/apks/$ARCH/
cp $EXTRA/*.apk $EXTRA_PKG_DIR/*.apk $W/p1/apks/$ARCH/
cp $ISO/apks/.boot_repository $W/p1/apks/.boot_repository
( cd $W/p1/apks/$ARCH && apk index --rewrite-arch $ARCH -o APKINDEX.unsigned.tar.gz *.apk 2>&1 | { grep -v '^Index has' || true; }
  # sign like abuild-sign: a tar of the signature spliced before the index
  openssl dgst -sha1 -sign $KEY -out .SIGN.RSA.talkalpine.rsa.pub APKINDEX.unsigned.tar.gz
  tar -c .SIGN.RSA.talkalpine.rsa.pub | abuild-tar --cut | gzip -9 > .sig.tar.gz
  cat .sig.tar.gz APKINDEX.unsigned.tar.gz > APKINDEX.tar.gz
  rm -f .sig.tar.gz APKINDEX.unsigned.tar.gz .SIGN.RSA.talkalpine.rsa.pub )
echo "   $(ls $W/p1/apks/$ARCH/*.apk | wc -l) packages, $(du -sh $W/p1/apks | cut -f1)"
# check: does apk accept the repository with our key, offline?
mkdir -p $W/chk/etc/apk/keys && cp $A/overlay/etc/apk/keys/talkalpine.rsa.pub $W/chk/etc/apk/keys/
apk --root $W/chk --keys-dir $W/chk/etc/apk/keys --repository $W/p1/apks --no-network --no-scripts --arch $ARCH add --initdb $(cat $WORLD) > $W/chk.log 2>&1 || { tail -5 $W/chk.log; exit 1; }
echo "   repository verified: $(tail -1 $W/chk.log)"
rm -rf $W/chk

echo "== apkovl"
cp -a $A/overlay/etc $W/ovl/
cp $WORLD $W/ovl/etc/apk/world
if [ "${TEST:-0}" = 1 ]; then
    echo 'ttyS0::respawn:/sbin/getty -L 115200 ttyS0 vt100' >> $W/ovl/etc/inittab
    touch $W/ovl/etc/speech/debug
fi
chmod 600 $W/ovl/etc/shadow
( cd $W/ovl && tar --owner=0 --group=0 --numeric-owner -czf $W/p1/talkalpine.apkovl.tar.gz etc )
echo "   $(du -h $W/p1/talkalpine.apkovl.tar.gz | cut -f1)"

echo "== boot files"
mkdir -p $W/p1/boot/syslinux $W/p1/boot/grub $W/p1/efi/boot $W/p1/cache
cp $ISO/boot/vmlinuz-lts $ISO/boot/initramfs-lts $ISO/boot/modloop-lts $W/p1/boot/
cp $A/boot/syslinux.cfg $W/p1/boot/syslinux/syslinux.cfg
cp /usr/share/syslinux/ldlinux.c32 $W/p1/boot/syslinux/
if ls $ISO/efi/boot/*.efi >/dev/null 2>&1; then   # UEFI loader from the ISO (bootx64.efi, or bootia32.efi on x86)
    cp $A/boot/grub.cfg $W/p1/boot/grub/grub.cfg
    cp $ISO/efi/boot/*.efi $W/p1/efi/boot/
else
    rm -rf $W/p1/boot/grub $W/p1/efi
fi
cp $A/boot/README.txt $W/p1/README.txt
# RHVoice data: languages/English and the four voices, with the licence notes
RH=$A/src/upstream/RHVoice
for f in languages/English/language.info voices/alan/voice.info voices/bdl/voice.info voices/clb/voice.info voices/slt/voice.info; do
    [ -f $RH/data/$f ] || { echo "RHVoice data missing ($f): rerun run/get-alpine.sh"; exit 1; }
done
mkdir -p $W/p1/rhvoice/languages $W/p1/rhvoice/voices
cp -a $RH/data/languages/English $W/p1/rhvoice/languages/
for v in alan bdl clb slt; do cp -a $RH/data/voices/$v $W/p1/rhvoice/voices/; done
find $W/p1/rhvoice \( -name '.git' -o -name 'CMakeLists.txt' -o -name 'SConscript' \) -exec rm -rf {} +
cp $RH/LICENSE.md $W/p1/rhvoice/LICENSE-data-GPL-2.0.md
cp $A/build/licenses/LGPL-2.1.txt $W/p1/rhvoice/LICENSE-engine-LGPL-2.1.txt
cp $RH/external/libs/sonic/COPYING $W/p1/rhvoice/LICENSE-sonic-Apache-2.0.txt
for v in bdl clb slt; do cp $A/build/licenses/CMU-ARCTIC-$v.txt $W/p1/rhvoice/voices/$v/COPYING-CMU-ARCTIC.txt; done
cat > $W/p1/rhvoice/README.txt <<'TXT'
RHVoice for the talking stick, built from github.com/RHVoice/RHVoice tag 1.18.4 (commit
fa9dd196fd2dac3b0bf089a2d80fc8477c2380e3): the English language files and the voices alan,
bdl, clb and slt. The engine (libRHVoice, in the talkalpine package) is LGPL-2.1-or-later
(LICENSE-engine-LGPL-2.1.txt) and includes the sonic library (Apache-2.0,
LICENSE-sonic-Apache-2.0.txt); the language and voice data is GPL (LICENSE-data-GPL-2.0.md).
The bdl, clb and slt voices are trained on the CMU ARCTIC recordings, whose notice is in
voices/<voice>/COPYING-CMU-ARCTIC.txt.
TXT
# MBROLA voices (run/get-mbrola-voices.sh), behind the /usr/share/mbrola link
cp -a $IMAGES_DIR/mbrola-voices $W/p1/mbrola
cp $A/src/upstream/MBROLA/LICENSE $W/p1/mbrola/LICENSE-mbrola-program-AGPL-3.0.txt
# Piper voices (run/get-piper-voices.sh): read by tdsr from /media/usb/piper-voices
mkdir -p $W/p1/piper-voices
cp $IMAGES_DIR/piper-voices/*.onnx $IMAGES_DIR/piper-voices/*.onnx.json $IMAGES_DIR/piper-voices/*.MODEL_CARD.txt $W/p1/piper-voices/
touch $W/p1/cache/.keep

echo "== partition 1 (FAT32, ${P1_MB} MB)"
rm -f $W/p1.img
mkfs.vfat -F 32 -n ALPINE -C $W/p1.img $((P1_MB * 1024)) >/dev/null
( cd $W/p1 && mcopy -i $W/p1.img -s -o -Q ./* :: )
syslinux -i -d /boot/syslinux $W/p1.img
echo "   used: $(mdir -i $W/p1.img :: | tail -1)"

echo "== partition 2 (ext4, ${P2_MB} MB)"
cp $A/overlay/etc/speech/tdsr.cfg $W/p2/.tdsr.cfg
cat > $W/p2/README.txt <<'TXT'
This is /home/user on the talking stick. Files here survive reboots; the
system itself is reloaded from partition 1 every boot.
TXT
# the files as well as the top directory belong to user (root_owner only sets the latter):
# tdsr rewrites ~/.tdsr.cfg whenever a setting changes
chown -R 1000:1000 $W/p2
rm -f $W/p2.img; truncate -s ${P2_MB}M $W/p2.img
mkfs.ext4 -q -L SPEECHDATA -d $W/p2 -E root_owner=1000:1000 $W/p2.img

echo "== disk image"
IMG=$DIST/$IMGNAME
P1_START=2048
P1_SECT=$((P1_MB * 2048))
P2_START=$((P1_START + P1_SECT))
P2_SECT=$((P2_MB * 2048))
TOTAL=$((P2_START + P2_SECT + 2048))
rm -f $IMG; truncate -s $((TOTAL * 512)) $IMG
printf 'label: dos\nstart=%d, size=%d, type=c, bootable\nstart=%d, size=%d, type=83\n' $P1_START $P1_SECT $P2_START $P2_SECT | sfdisk -q $IMG
dd if=/usr/share/syslinux/mbr.bin of=$IMG bs=440 count=1 conv=notrunc status=none
dd if=$W/p1.img of=$IMG bs=1M seek=1 conv=notrunc status=none
dd if=$W/p2.img of=$IMG bs=1M seek=$((1 + P1_MB)) conv=notrunc status=none
sfdisk -l $IMG | tail -3
ls -la $IMG
