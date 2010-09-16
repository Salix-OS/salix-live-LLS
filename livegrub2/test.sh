#!/bin/bash
if [ $UID -ne 0 ]; then
  echo "you must be root"
  exit 1
fi
qemu --version >/dev/null 2>&1
if [ $? -ne 0 ]; then
  echo ""
  echo "WARNING: qemu not installed!"
  echo ""
fi
cd $(dirname $0)
startdir=$PWD
# generate grub config
echo "Generating Grub2 config..."
cd genlocale
# compile mo files, create locale dir containg translations
make install
./genlocale ${startdir}/build/boot/grub/locale ${startdir}/build/boot/grub
# now livegrub2/build/* should be ready for installation
# add grub2 menu
echo "Adding Grub2..."
isodir=$(mktemp -d)
cd $isodir
# prepare the grub2 initial tree
mkdir -p boot
# ask grub2 to build the rescue ISO to get the initial tree
grub-mkrescue --output=rescue.iso
mkdir rescue
mount -o loop rescue.iso rescue
cp -r rescue/boot/* boot/
chmod u+w -R boot
umount rescue
rm -r rescue*
grub-mkimage -o boot/grub/core.img
cp -ar ${startdir}/build/* .
find . -type d -name '.svn' | xargs -i@ rm -rf @
cat ${startdir}/grub.cfg >> boot/grub/grub.cfg
# remove uneeded/unwanted files
rm -r boot/dos boot/isolinux boot/pxelinux.cfg boot/syslinux boot/bootinst.* boot/*.c32 boot/liloinst.sh salixlive/make_iso.*
# copy the mod files and lst files to the grub directory too for USB support.
find boot/grub -name '*.mod' -exec cp -v '{}' boot/grub/ \;
find boot/grub -name '*.lst' -exec cp -v '{}' boot/grub/ \;
# create the iso
echo "Creating ISO..."
find . -name '.svn' -exec rm -rf '{}' \; 2>/dev/null
mkisofs -b boot/grub/i386-pc/eltorito.img \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-o "$startdir/grub2menu.iso" -r -J .
cd $startdir
rm -rf $isodir
qemu -cdrom grub2menu.iso
read R
rm grub2menu.iso
