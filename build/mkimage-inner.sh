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
