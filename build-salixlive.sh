#!/bin/bash
# Maintainer: JRD <jrd@enialis.net>
# Contributors: Shador <futur.andy@googlemail.com>
#
# Used to build the live ISO
# Linux-Live-Script: the most innovative scripts available.
# AuFS provides better stability compared to old unionfs, squashfs with LZMA support provides great compression ratio and amazing decompression speed.
# funionfs (unionfs with fuse) is still used for building the modules because it is simpler and easier than aufs which may not be compiled in your kernel and which is not available in FUSE. The 0.4.2 version is used in time of writing, instead of 0.4.3 because this one is buggy. Later versions must be checked to see if it's ok with "cp" and "mkfifo" for example.
# url: http://www.linux-live.org/
#
# What needs to be installed to compile:
# - pkgtools or spkg-pkgtools
# - sed, grep, cat, tr, head, gzip, bzip2, xz
# - glibc, sysfsutils, gcc, glib2
# - wget
# - fuse
# - linux-live
# - cdrtools

startdir=$(pwd)
export KVER=$(uname -r)
export DISTRO=salix
export VER=13.0
export RLZ=beta1
export LLVER=6.3.0
export LLURL=ftp://ftp.slax.org/Linux-Live/linux-live-$LLVER.tar.gz
export FUFSVER=0.4.2
export FUFSURL=http://funionfs.apiou.org/file/funionfs-$FUFSVER.tar.gz
export ISO_NAME=${DISTRO}live-$VER-$RLZ.iso
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
    cd funionfs-$FUFSVER
    ./configure && make || exit 1
    cp funionfs ..
  )
  rm -rf funionfs-$FUFSVER
fi
mkdir -p src
cd src
echo3 "Reading modules"
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
export RDEF=K
export kmodule=04-kernel
if [ -z "$kmodule" ]; then
  while read m; do
    list=($(echo "$m"|cut -d\| -f3-))
    m=$(echo "$m"|cut -d\| -f1-2|sed 's/|/-/')
    echo3 "Verifying packages for $m..."
    for p in "${list[@]}"; do
      if [ "$p" = "kernelive" ]; then
        # module where the kernelive is
        kmodule=$m
      fi
      file=$(find $startdir/PKGS -name "$p-*"|grep "$p-[^-]\+-[^-]\+-[^-]\+.t[gblx]z"|head -n 1)
      if [ ! -e "$file" ]; then
        quit "$p, referenced by module $m, is not available in $startdir/PKGS/"
        exit 1
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
  if [ ! -e $m ]; then
    mkdir $m
    export ROOT=$startdir/src/module
    $startdir/funionfs -o "dirs=$funionfsopts:$startdir/src/$m" none $ROOT
    funionfsopts="$funionfsopts:$startdir/src/$m=ro"
    for p in "${list[@]}"; do
      file=$(find $startdir/PKGS -name "$p-*"|grep "$p-[^-]\+-[^-]\+-[^-]\+.t[gblx]z"|head -n 1)
      installpkg $file
    done
    # dotnew
    find $ROOT/etc -name '*.new'|xargs -i@ bash -c '(N="$1"; F="$(dirname $N)/$(basename $N .new)"; if [ -e $F ]; then rm $N; else mv $N $F; fi)' -- @
    # kernel modules path
    if [ -e "$ROOT/lib/modules/$KVER" ]; then
      cp -r $ROOT/lib/modules/$KVER/* $ROOT/lib/modules/$KVER-live/
      rm -r $ROOT/lib/modules/$KVER
    fi
    umount $ROOT
    # remove any fakely deleted files in RO branches, default suffix is _DELETED~
    find "$startdir/src/$m" -name '*_DELETED~' -exec rm -rf '{}' \;
  fi
done < $modules
rm -r $startdir/src/{empty,module}
echo3 "Prepare the linux live scripts..."
if [ -e $startdir/linux-live-$LLVER.tar.gz ]; then
  cp $startdir/linux-live-$LLVER.tar.gz .
else
  wget $LLURL
fi
# install the linux live scripts binaries and libs for the Live distro
echo3 "Creating live structure and initrd..."
rm -rf linux-live-$LLVER
tar -xf linux-live-$LLVER.tar.gz
cd linux-live-$LLVER
# specify where to find the kernel and the modules to build the initrd.
export ROOT=$startdir/src/$kmodule
sed -i -e "s/^LIVECDNAME=.*/LIVECDNAME=\"${DISTRO}live\"/ ; s/^KERNEL=\$(uname -r)/\0-live/ ; s@^ROOT=.*@ROOT=$ROOT@ ; s/^MKMOD=.*/MKMOD=none/" .config
# CD Label
sed -i -e "s/CDLABEL=.*/CDLABEL=${DISTRO}live/" cd-root/linux/make_iso.*
# add runlevel parameter to init, and assure that /dev/initctl is correctly initialized
sed -i -e 's:^\(header "\)starting \(Linux Live.*\):header "Starting '$DISTRO' Live v.'$VER'-'$RLZ'..."\n\1...using \2: ; s:^.*cp -af $INIT /bin.*: rm -f /dev/initctl\n mkfifo -m 600 /dev/initctl\n runlevel=$(cmdline_parameter [0123456])\n\0: ; s:<dev/console:$runlevel \0:g' initrd/linuxrc
# remove the /usr/share/locale/locale.alias warning at boot when no iocharset is defined.
sed -i -e 's:.*cat /usr/share/locale/locale.alias.*:echo "utf8":' initrd/linuxrc
# remove the installation process of the linux live tools + patch for fake-uname
sed -i -e 's:.*\. \./install.*:echo "":' -e 's@:/usr/sbin:@:/sbin:/usr/sbin:@' -e 's/^read NEWLIVECDNAME/NEWLIVECDNAME=""/' -e 's/^read NEWKERNEL/NEWKERNEL=""/' -e 's/^read junk//' build
# remove the need to build aufs as a module for the initrd
sed -i 's:^rcopy \(.*/aufs .*\):rcopy_ex \1:' initrd/initrd_create
# install splashy and DirectDB in initrd
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
cp -L /lib/libm.so.6 initrd/rootfs/lib/
cp -L /lib/libsysfs.so.2 initrd/rootfs/lib/
cp -L /usr/lib/libgcc_s.so.1 initrd/rootfs/usr/lib/
cp -L /usr/lib/libglib-2.0.so.0 initrd/rootfs/usr/lib/
sed -i -e 's:.*Then load.*:[ -z "$DEBUG_IS_ENABLED" -a -x /usr/sbin/splashy ] \&\& /usr/sbin/splashy boot\n\n\0:' initrd/linuxrc
splashyup='[ ! -z "$(pidof splashy)" ] \&\& /usr/sbin/splashy_update "progress _P_"'
pct=0
for pat in "Find livecd" "setting up directory for changes" "store the xino" "DATA contains path to the base directory" "copying liblinuxlive library to union"; do
  pct=$(($pct + 5))
  spup=$(echo "$splashyup"|sed "s/_P_/$pct/")
  sed -i -e "s:.*$pat.*:$spup\\n\\n\\0:" initrd/linuxrc
done
sed -i -e 's:^.*cp -af $INIT /bin.*:[ ! -z "$(pidof splashy)" ] \&\& /usr/sbin/splashy_update "exit"\n\0:' initrd/linuxrc
# remove any files present
rm -rf /tmp/live_data_*
# create ISO structure and create initrd.gz
./build
cd ..
# move the structure to the final dest.
mkdir -p iso
cp -a /tmp/live_data_*/* iso/
rm -rf /tmp/live_data_*
# the initrd.gz contains a bad modules.dep file and must be corrected.
mkdir iso/boot/initrd
zcat iso/boot/initrd.gz > initrd
mount -o loop initrd iso/boot/initrd
sed -i "s:^:/lib/modules/$KVER-live/:" iso/boot/initrd/lib/modules/$KVER-live/modules.dep
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
    mksquashfs $startdir/src/$m iso/${DISTRO}live/base/$m.lzm -b 256K -lzmadic 256K
    chmod a+r-wx iso/${DISTRO}live/base/$m.lzm
  fi
done < $modules
rm -f $modules
# add grub2 menu
echo3 "Adding Grub2..."
cd iso
tar xf $startdir/grub2-base-*.txz
tar xf $startdir/grub2-live-*.txz
# create the iso
echo3 "Creating ISO..."
mkisofs -b boot/grub/grub_eltorito \
	-no-emul-boot -boot-load-size 4 -boot-info-table \
	-o "$startdir/$ISO_NAME" -r -J .
