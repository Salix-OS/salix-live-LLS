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
export ARCH64=$(uname -m|grep 64 >/dev/null && echo 1 || echo 0)
export DISTRO=salix
export VER=13.1.1
#export RLZ=64_$(date +%Y%m%d,%H:%M)
export RLZ=
export LLVER=6.3.0
export LLURL=ftp://ftp.slax.org/Linux-Live/linux-live-$LLVER.tar.gz
export BBVER=1.17.2
export BBURL=http://busybox.net/downloads/busybox-$BBVER.tar.bz2
export FUFSVER=0.4.2
export FUFSURL=http://funionfs.apiou.org/file/funionfs-$FUFSVER.tar.gz
export ISO_NAME=${DISTRO}live-$VER${RLZ:+-$RLZ}.iso
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
#export RDEF=''
#export kmodule=''
#export lastmodule=''
export RDEF=C
export kmodule=05-kernel
export lastmodule=07-live
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
      file=$(find -L $startdir/PKGS -name "$p-*"|grep "$p-[^-]\+-[^-]\+-[^-]\+.t[gblx]z"|head -n 1)
      if [ ! -e "$file" ]; then
        quit "$p, referenced by module $m, is not available in $startdir/PKGS/"
        exit 1
      fi
      if [ $p = $KERNELPKGNAME ]; then
        filekernel=$(find -L $startdir/PKGS -name "$p-$(uname -r|sed 's/-/./g')-*"|grep "$p-[^-]\+-[^-]\+-[^-]\+.t[gblx]z"|head -n 1)
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
      file=$(find -L $startdir/PKGS -name "$p-*"|grep "$p-[^-]\+-[^-]\+-[^-]\+.t[gblx]z"|head -n 1)
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
    if [ $kmodule = $m ]; then
      (
        cd $ROOT
        mkdir -p usr/src/kernelive usr/sbin
        cp usr/src/linux-*/.config usr/src/linux-*/Module.symvers usr/src/kernelive/
        cat <<EOF > usr/sbin/init-live-kernel-compilation
#!/bin/sh
cp /usr/src/kernelive/.config /usr/src/kernelive/Module.symvers /usr/src/linux-2.*/
EOF
        chmod ug+x usr/sbin/init-live-kernel-compilation
      )
    fi
    # /var/log/setup
    if [ $lastmodule = $m ]; then
      (
        cd $ROOT
        # /dev/null could be needed and will not be usable, so the trick is to delete it, and then delete the "deletion".
        rm ./dev/null
        for s in 04.mkfontdir 07.update-desktop-database 07.update-mime-database 08.gtk-update-icon-cache htmlview services; do
          echo "Running '/var/log/setup/setup.$s $ROOT'"
          echo ""
          ./var/log/setup/setup.$s $ROOT
        done
        echo "Running 'chroot . /usr/bin/update-gtk-immodules'"
        chroot . /usr/bin/update-gtk-immodules
        echo "Running 'chroot . /usr/bin/update-gdk-pixbuf-loaders'"
        chroot . /usr/bin/update-gdk-pixbuf-loaders
        echo "Running 'chroot . /usr/bin/update-pango-querymodules'"
        chroot . /usr/bin/update-pango-querymodules
        chmod a+r-x+X -R etc/gtk-2.0 etc/pango
      )
    fi
    umount $ROOT
    if [ $lastmodule = $m ]; then
      # delete the deletion of /dev/null
      rm -rf $m/dev
    fi
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
sed -e "s/__LIVECDNAME__/$DISTRO Live v.$VER${RLZ:+-$RLZ}/" $startdir/linuxrc.patch > linuxrc.patch
# patch liblinuxlive, linuxrc and cleanup.
cat $startdir/liblinuxlive.patch linuxrc.patch $startdir/cleanup.patch | patch -p1
if [ $ARCH64 = 1 ]; then
  cat $startdir/linuxlive64.patch | patch -p1
  rm -rf initrd/rootfs/lib initrd/rootfs/usr/lib initrd/rootfs/bin/{blkid,blockdev}
  tar xf $startdir/linuxlive64libs.tar.xz
fi
cp tools/liblinuxlive $startdir/src/$lastmodule/usr/lib/
# remove the installation process of the linux live tools + patch for fake-uname
sed -i -e 's:.*\. \./install.*:echo "":' -e 's@:/usr/sbin:@:/sbin:/usr/sbin:@' -e 's/^read NEWLIVECDNAME/NEWLIVECDNAME=""/' -e 's/^read NEWKERNEL/NEWKERNEL=""/' -e 's/^read junk//' build
# remove the need to build aufs as a module for the initrd
sed -i 's:^rcopy \(.*/aufs .*\):rcopy_ex \1:' initrd/initrd_create
# increase the size of the initrd
sed -i 's:RAM0SIZE=.*:RAM0SIZE=10000:' .config
echo3 "Install BusyBox..."
rm -rf initrd/rootfs/bin/{busybox,eject}
cp -rf ../busybox-$BBVER/_install/{bin,sbin}/* initrd/rootfs/bin/
# remove the busybox symlinks creation in the initrd_create process.
sed -i -e 's/ln -s busybox .*/echo -n/' initrd/initrd_create
# TODO: to remove, and use either a .tar.xz with all the libs or dynamically find the needed libs in the system.
if [ $ARCH64 = 0 ]; then
  cp $startdir/libs/32/libm.so.6 initrd/rootfs/lib/
  cp $startdir/libs/32/libsysfs.so.2 initrd/rootfs/lib/
  cp $startdir/libs/32/libblkid.so.1.0 initrd/rootfs/lib/
  cp $startdir/libs/32/libuuid.so.1 initrd/rootfs/lib/
  mkdir -p initrd/rootfs/usr/lib
  cp $startdir/libs/32/libgcc_s.so.1 initrd/rootfs/usr/lib/
  cp $startdir/libs/32/libglib-2.0.so.0 initrd/rootfs/usr/lib/
fi
# remove any files present
rm -rf /tmp/live_data_*
# hack for fake_uname support
ln -s $(which uname) .
# remove the mksquashfs that is in tools and that is old and only for 32 bits
rm tools/mksquashfs
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
    dir2lzm $startdir/src/$m iso/${DISTRO}live/base/$m.lzm
    chmod a+r-wx iso/${DISTRO}live/base/$m.lzm
  fi
done < $modules
rm -f $modules
# generate grub config
echo3 "Generating Grub2 config..."
cd $startdir/livegrub2/genlocale
# compile mo files, create locale dir containg translations
make install
./genlocale \
    $startdir/livegrub2/build/boot/grub/locale \
    $startdir/livegrub2/build/boot/grub
# now livegrub2/build/* should be ready for installation
# add grub2 menu
echo3 "Adding Grub2..."
cd $startdir/src/iso
# prepare the grub2 initial tree
rm -rf boot/grub # just for sure
# ask grub2 to build the rescue ISO to get the initial tree
grub-mkrescue --output=rescue.iso
mkdir rescue
mount -o loop rescue.iso rescue
cp -r rescue/boot/* boot/
chmod u+w -R boot
umount rescue
rm -r rescue*
grub-mkimage -o boot/grub/core.img
cp -ar ${startdir}/livegrub2/build/* .
find . -type d -name '.svn' | xargs -i@ rm -rf @
cat ${startdir}/livegrub2/grub.cfg >> boot/grub/grub.cfg
# remove uneeded/unwanted files
rm -r boot/dos boot/isolinux boot/pxelinux.cfg boot/syslinux boot/bootinst.* boot/*.c32 boot/liloinst.sh salixlive/make_iso.*
# copy the mod files and lst files to the grub directory too for USB support.
find boot/grub -name '*.mod' -exec cp -v '{}' boot/grub/ \;
find boot/grub -name '*.lst' -exec cp -v '{}' boot/grub/ \;
# add the unix script for installing grub2 on USB under Unix
echo3 "Adding install-on-USB.sh"
cp $startdir/install-on-USB.sh boot/
# add the batch script and utilities for installing grub2 on USB under Windows
echo3 "Adding install-on-USB.cmd"
cp $startdir/install-on-USB.cmd $startdir/4windows/* boot/
# add grub2 MBR stage and post-MBR stage
echo3 "Adding grub2 stages"
cp -r $startdir/grub_* boot/
# add the standard kernel
echo3 "Adding the standard kernel too"
mkdir -p packages/std-kernel
cp $startdir/std-kernel/kernel-* packages/std-kernel/
# add the packages lists
echo3 "Adding packages lists"
cp $startdir/packages-* packages/
# create the iso
echo3 "Creating ISO..."
find . -name '.svn' -exec rm -rf '{}' \; 2>/dev/null
CDNAME="${DISTRO}Live_${VER}"
echo $CDNAME
mkisofs -b boot/grub/i386-pc/eltorito.img \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-o "$startdir/$ISO_NAME" -r -J -A "$CDNAME" -V "$CDNAME" .
( cd "$startdir" && md5sum "$ISO_NAME" > "$ISO_NAME.md5" )
