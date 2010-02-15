#!/bin/bash
# Maintainer: JRD <jrd@enialis.net>
# Contributors: Shador <futur.andy@googlemail.com>, Akuna <akuna@free.fr>
#
# Used to build the live ISO
# Linux-Live-Script: the most innovative scripts available.
# AuFS provides better stability compared to old unionfs, squashfs with LZMA support provides great compression ratio and amazing decompression speed.
# funionfs (unionfs with fuse) is still used for building the modules because it is simpler and easier than aufs which may not be compiled in your kernel and which is not available in FUSE. The 0.4.2 version is used in time of writing, instead of 0.4.3 because this one is buggy. Later versions must be checked to see if it's ok with "cp" and "mkfifo" for example.
# url: http://www.linux-live.org/
#
# See INSTALL
#

cd $(dirname $0)
startdir=$(pwd)
if [ "$UID" -ne "0" ]; then
  echo "You need to be root to build the ISO because some commands need it."
  exit 1
fi
export KVER=$(uname -r)
export DISTRO=salix
export VER=13.0
#export RLZ=$(date +%Y%m%d)
export RLZ=rc2
export LLVER=6.3.0
export LLURL=ftp://ftp.slax.org/Linux-Live/linux-live-$LLVER.tar.gz
export BBVER=1.15.2
export BBURL=http://busybox.net/downloads/busybox-$BBVER.tar.bz2
export FUFSVER=0.4.2
export FUFSURL=http://funionfs.apiou.org/file/funionfs-$FUFSVER.tar.gz
export ISO_NAME=${DISTRO}live-$VER-$RLZ.iso
export KERNELPKGNAME=kernelive
echo3() {
  echo ''
  echo "############################################################"
  echo "$1"
  echo "############################################################"
}
quit() {
  echo "$1"
  [ "$modules" != "" ] && rm -f $modules
}
exec 5<&0
echo3 "Building $DISTRO live v.$VER for kernel $KVER"
if [ ! -e $startdir/MODULES_INFOS ]; then
  cat << EOF
ERROR: $startdir/MODULES_INFOS not found
This file must describe the modules to build for the live CD like this:
module=name,package_list_file
“package_list_file” is a list of package names to include, one per line.
The packages must reside in $startdir/PKGS/
The “kernel” special module must provide the kernelive package
EOF
  exit 1
fi
if [ ! -x $startdir/funionfs ]; then
  wget $FUFSURL -O - | tar xzf - || exit 1
  (
    cd $startdir/funionfs-$FUFSVER
    ./configure && make || exit 1
    cp funionfs ..
  )
  rm -rf funionfs-$FUFSVER
fi
echo3 "Reading modules"
mkdir -p src
cd $startdir/src
modules=$(mktemp)
num=1
while read m; do
  line=$(echo $m | grep '^[\t ]*module=' 2>/dev/null)
  if [ ! -z "$line" ]; then
    name=$(echo $m|sed 's/^[\\t ]*module=\(.*\),.*/\1/')
    file=$(echo $m|sed 's/^[\\t ]*module=.*,\(.*\)/\1/')
    if [ ! -e $startdir/$file ]; then
      quit "$startdir/$file doesn't exist for module $name"
      exit 1
    fi
    list="$(cat $startdir/$file|tr '\n' ' ')"
    numstr=$num
    while [ ${#numstr} -lt 2 ]; do
      numstr="0$numstr"
    done
    echo "$numstr|$name|$list" >> $modules
    echo "  * Module $numstr-$name"
    num=$((num + 1))
  fi
done < $startdir/MODULES_INFOS
export RDEF=''
export kmodule=''
export lastmodule=''
#export RDEF=K
#export kmodule=05-kernel
#export lastmodule=07-live
if [ -z "$kmodule" ]; then
  while read m; do
    list=($(echo "$m"|cut -d\| -f3-))
    m=$(echo "$m"|cut -d\| -f1-2|sed 's/|/-/')
    echo3 "Verifying packages for $m..."
    lastmodule=$m
    for p in "${list[@]}"; do
      if [ $p = $KERNELPKGNAME ]; then
        # module where the kernel live is
        kmodule=$m
      fi
      file=$(find $startdir/PKGS -name "$p-*"|grep "$p-[^-]\+-[^-]\+-[^-]\+.t[gblx]z"|head -n 1)
      if [ ! -e "$file" ]; then
        quit "$p, referenced by module $m, is not available in $startdir/PKGS/"
        exit 1
      fi
      if [ $p = $KERNELPKGNAME ]; then
        filekernel=$(find $startdir/PKGS -name "$p-$(uname -r|sed 's/-/./g')-*"|grep "$p-[^-]\+-[^-]\+-[^-]\+.t[gblx]z"|head -n 1)
        if [ ! -e "$filekernel" ]; then
          quit "$file does not match you kernel version returned by 'uname -r'. Please install fake-uname to match it."
          exit 1
        fi
      fi
    done
  done < $modules
fi
mkdir -p $startdir/src/{empty,module}
# be sure that module is unmounted
umount $startdir/src/module >/dev/null 2>&1
# test of funionfs
$startdir/funionfs none $startdir/src/empty || exit 1
umount $startdir/src/empty
funionfsopts="$startdir/src/empty=ro" # the first readonly directory (will always be empty)
nmodule=0
inittabfile=$(find $startdir/PKGS -name "sysvinit-scripts-*"|grep "sysvinit-scripts-[^-]\+-[^-]\+-[^-]\+.t[gblx]z"|head -n 1)
while read m; do
  list=($(echo "$m"|cut -d\| -f3-))
  m=$(echo "$m"|cut -d\| -f1-2|sed 's/|/-/')
  echo3 "Installing packages for $m..."
  if [ -e $m ]; then
    R=$RDEF
    while [[ "$R" != "K" && "$R" != "C" ]]; do
      echo "$m exists, keep (K) or clean (C) ?"
      read -u 5 R
    done
    if [ "$R" = "C" ]; then
      rm -rf $m
    fi
  fi
  if [ -e $m ]; then
    funionfsopts="$funionfsopts:$startdir/src/$m=ro"
  else
    mkdir $m
    export ROOT=$startdir/src/module
    $startdir/funionfs -o "dirs=$funionfsopts:$startdir/src/$m" none $ROOT
    funionfsopts="$funionfsopts:$startdir/src/$m=ro"
    nb=${#list[@]}
    i=0
    d0=$(date +%s)
    for p in "${list[@]}"; do
      i=$(( $i + 1 ))
      clear
      echo "⋅⋅⋅---=== Installing packages for $m ===---⋅⋅⋅"
      echo ''
      echo -n 'Progression : ['
      perct=$(($i * 100 / $nb))
      nbSharp=$(($i * 50 / $nb))
      nbSpace=$((50 - $nbSharp))
      for j in $(seq $nbSharp); do echo -n '#'; done
      for j in $(seq $nbSpace); do echo -n '_'; done
      echo "] $i / $nb ($perct%)"
      offset=$(($(date +%s) - $d0))
      timeremain=$((($nb - $i) * $offset / $i))
      echo 'Remaining time (estimated) :' $(date -d "1970-01-01 UTC +$timeremain seconds" +%M:%S)
      echo ''
      file=$(find $startdir/PKGS -name "$p-*"|grep "$p-[^-]\+-[^-]\+-[^-]\+.t[gblx]z"|head -n 1)
      installpkg $file
    done
    # dotnew
    if [ -e $ROOT/etc ]; then
      find $ROOT/etc -name '*.new'|xargs -i@ bash -c '(N="$1"; F="$(dirname $N)/$(basename $N .new)"; if [ -e $F ]; then rm $N; else mv $N $F; fi)' -- @
    fi
    # inittab
    if [ "$inittabfile" ]; then
      if [ $nmodule -eq 0 ]; then
        (
          cd $ROOT
          tar -xf $inittabfile etc/inittab.new
          sed -e 's/^id:.:initdefault:/id:3:initdefault:/' etc/inittab.new > etc/inittab && rm etc/inittab.new
        )
      elif [ $nmodule -eq 1 ]; then
        sed -i -e 's/^id:.:initdefault:/id:4:initdefault:/' $ROOT/etc/inittab
      fi
    fi
    # /var/log/setup
    if [ $lastmodule = $m ]; then
      for s in 04.mkfontdir 07.update-desktop-database 07.update-mime-database 08.gtk-update-icon-cache htmlview services; do
        chroot $ROOT /bin/sh /var/log/setup/setup.$s
      done
      chmod -x $ROOT/etc/rc.d/rc.pcmcia
    fi
    umount $ROOT
    # remove any fakely deleted files in RO branches, default suffix is _DELETED~
    find "$startdir/src/$m" -name '*_DELETED~' -exec rm -rf '{}' \;
  fi
  nmodule=$(($nmodule + 1))
done < $modules
rm -r $startdir/src/{empty,module}
echo3 "Prepare the linux live scripts..."
if [ ! -e linux-live-$LLVER.tar.gz ]; then
  wget $LLURL
fi
echo3 "Prepare BusyBox..."
if [ ! -e busybox-$BBVER.tar.bz2 ]; then
  wget $BBURL
fi
# compile busybox
R=$RDEF
if [ -e busybox-$BBVER/_install/bin/busybox ]; then
  while [[ "$R" != "K" && "$R" != "C" ]]; do
    echo "busybox exists, keep (K) or compile (C) ?"
    read -u 5 R
  done
else
  R=C
fi
if [ "$R" = "C" ]; then
  echo3 "Compile BusyBox..."
  rm -rf busybox-$BBVER
  tar -xf busybox-$BBVER.tar.bz2
  (
    cd $startdir/src/busybox-$BBVER
    cp $startdir/bbconfig .config
    make
    make install
  )
fi
# install the linux live scripts binaries and libs for the Live distro
echo3 "Creating live structure and initrd..."
rm -rf linux-live-$LLVER
tar -xf linux-live-$LLVER.tar.gz
cd $startdir/src/linux-live-$LLVER
# specify where to find the kernel and the modules to build the initrd.
export ROOT=$startdir/src/$kmodule
sed -i -e "s/^LIVECDNAME=.*/LIVECDNAME=\"${DISTRO}live\"/ ; s@^ROOT=.*@ROOT=$ROOT@ ; s/^MKMOD=.*/MKMOD=none/" .config
# CD Label
sed -i -e "s/CDLABEL=.*/CDLABEL=${DISTRO}live/" cd-root/linux/make_iso.*
# Live CD name on boot
cp $startdir/liblinuxlive.patch $startdir/linuxrc.patch $startdir/cleanup.patch .
sed -i -e "s/__LIVECDNAME__/$DISTRO Live v.$VER-$RLZ/" linuxrc.patch
# patch liblinuxlive, linuxrc and cleanup in the initrd.
patch -p2 < liblinuxlive.patch
cp initrd/liblinuxlive tools/ $startdir/src/$lastmodule/usr/lib/
patch -p2 < linuxrc.patch
patch -p2 < cleanup.patch
# remove the installation process of the linux live tools + patch for fake-uname
sed -i -e 's:.*\. \./install.*:echo "":' -e 's@:/usr/sbin:@:/sbin:/usr/sbin:@' -e 's/^read NEWLIVECDNAME/NEWLIVECDNAME=""/' -e 's/^read NEWKERNEL/NEWKERNEL=""/' -e 's/^read junk//' build
# remove the need to build aufs as a module for the initrd
sed -i 's:^rcopy \(.*/aufs .*\):rcopy_ex \1:' initrd/initrd_create
echo3 "Install BusyBox..."
rm -rf initrd/rootfs/bin/{busybox,eject}
cp -rf ../busybox-$BBVER/_install/{bin,sbin}/* initrd/rootfs/bin/
# remove the busybox symlinks creation in the initrd_create process.
sed -i -e 's/ln -s busybox .*/echo -n/' initrd/initrd_create
echo3 "Install splashy and DirectDB in initrd..."
ROOT2=$ROOT
export ROOT=$PWD/initrd/rootfs
installpkg $startdir/PKGS/splashy-*.txz
installpkg $startdir/PKGS/DirectFB-*.txz
installpkg $startdir/PKGS/libpng-*.txz
export ROOT=$ROOT2
unset ROOT2
rm -rf initrd/rootfs/var \
       initrd/rootfs/usr/doc \
       initrd/rootfs/usr/include \
       initrd/rootfs/usr/lib/pkgconfig \
       initrd/rootfs/usr/man \
       initrd/rootfs/usr/share/locale/?? \
       initrd/rootfs/usr/src
rm -f  initrd/rootfs/usr/bin/libpng* \
       initrd/rootfs/usr/sbin/splashy_config
cp $startdir/libs/libm.so.6 initrd/rootfs/lib/
cp $startdir/libs/libsysfs.so.2 initrd/rootfs/lib/
cp $startdir/libs/libgcc_s.so.1 initrd/rootfs/usr/lib/
cp $startdir/libs/libglib-2.0.so.0 initrd/rootfs/usr/lib/
cp $startdir/libs/libblkid.so.1.0 initrd/rootfs/lib/
# remove any files present
rm -rf /tmp/live_data_*
# create ISO structure and create initrd.gz
./build
cd $startdir/src
# move the structure to the final dest.
mkdir -p iso
cp -a /tmp/live_data_*/* iso/
rm -rf /tmp/live_data_*
# the initrd.gz contains a bad modules.dep file and must be corrected.
mkdir iso/boot/initrd
zcat iso/boot/initrd.gz > initrd
mount -o loop initrd iso/boot/initrd
sed -i "s:^:/lib/modules/$KVER/:" iso/boot/initrd/lib/modules/$KVER/modules.dep
umount iso/boot/initrd
rmdir iso/boot/initrd
gzip initrd
mv initrd.gz iso/boot/
# create modules
while read m; do
  m=$(echo "$m"|cut -d\| -f1-2|sed 's/|/-/')
  echo3 "Creating module $m.lzm..."
  if [ -e iso/${DISTRO}live/base/$m.lzm ]; then
    R=$RDEF
    while [[ "$R" != "K" && "$R" != "C" ]]; do
      echo "$m exists, keep (K) or clean (C) ?"
      read -u 5 R
    done
    if [ "$R" = "C" ]; then
      rm -f iso/${DISTRO}live/base/$m.lzm
    fi
  fi
  if [ ! -e iso/${DISTRO}live/base/$m.lzm ]; then
    mksquashfs $startdir/src/$m iso/${DISTRO}live/base/$m.lzm -b 1M -lzmadic 1M -processors 1
    chmod a+r-wx iso/${DISTRO}live/base/$m.lzm
  fi
done < $modules
rm -f $modules
# add grub2 menu
echo3 "Adding Grub2..."
cd $startdir/src/iso
# prepare the grub2 initial tree
rm -rf boot/grub # just for sure
sed -e "s;aux_dir=\`mktemp -d\`;aux_dir=\"${PWD}\";" \
    -e "s/genisoimage/false/" \
    -e 's/\(rm -rf ${aux_dir}\)/# \1/' \
    /usr/bin/grub-mkrescue > grub-mkrescue
chmod +x grub-mkrescue
# ask grub2 to build the initial tree without making an ISO
./grub-mkrescue xy.iso
rm -f grub-mkrescue xy.iso
grub-mkimage -o boot/grub/core.img
cp /usr/lib/grub/i386-pc/boot.img boot/grub/
cp -ar ${startdir}/livegrub2/build/* .
find . -type d -name '.svn' | xargs -i@ rm -rf @
cat ${startdir}/livegrub2/grub.cfg >> boot/grub/grub.cfg
# patch the syslinux.cfg file for installing grub2 on USB if neeeded
sed -i -e "s/Slax/${DISTRO}live/" boot/bootinst.bat
sed -i -e "s/Slax/${DISTRO}live/" boot/bootinst.sh
sed -i -e 's/ rw$/\0 grub2=install nosplash 2/' boot/syslinux/syslinux.cfg
# add the unix script for installing grub2 on USB too
echo3 "Adding install-on-USB"
cp $startdir/install-on-USB boot/
# add our bootinst.sh
echo3 "Adding bootinst.sh"
cp $startdir/bootinst.sh boot/
# add the standard kernel
echo3 "Adding the standard kernel too"
mkdir -p packages/std-kernel
cp $startdir/std-kernel/*.txz packages/std-kernel/
# add the HOW TO
echo3 "Adding HOW TO"
cp $startdir/HOW_TO.html $startdir/howto*.gif ./
# add the packages lists
echo3 "Adding packages lists"
cp $startdir/packages-* packages/
# create the iso
echo3 "Creating ISO..."
mkisofs -b boot/grub/grub_eltorito \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-o "$startdir/$ISO_NAME" -r -J .
( cd "$startdir" && md5sum "$ISO_NAME" > "$ISO_NAME.md5" )
