#!/bin/bash
cd -P $(dirname $0)

set -e
TARGET=""
MBR=""

# If grub2 is available, tell that it should be used instead.
which grub-install > /dev/null 2>&1
if [ $? -eq 0 ]; then
  echo "WARNING: grub2 is available on this running system."
  echo "You should preferably run /install-on-USB script instead."
  echo ""
  echo "Press any key to continue, or Ctrl+C to abort."
  read junk
fi

# Find out which partition or disk are we using
MYMNT=$(pwd)
while [ "$MYMNT" != "" -a "$MYMNT" != "." -a "$MYMNT" != "/" ]; do
  TARGET=$(egrep "[^[:space:]]+[[:space:]]+$MYMNT[[:space:]]+" /proc/mounts | tail -n 1 | cut -d " " -f 1)
  if [ "$TARGET" != "" ]; then break; fi
  MYMNT=$(dirname "$MYMNT")
done

if [ "$TARGET" = "" ]; then
  echo "Can't find device to install to."
  echo "Make sure you run this script from a mounted device."
  exit 1
fi

if [ "$(cat /proc/mounts | grep "^$TARGET" | grep noexec)" ]; then
  echo "The disk $TARGET is mounted with noexec parameter, trying to remount..."
  mount -o remount,exec "$TARGET"
fi

MBR=$(echo "$TARGET" | sed -r "s/[0-9]+\$//g")
NUM=${TARGET:${#MBR}}
cd "$MYMNT"

clear
echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
echo "                        Welcome to salixlive boot installer                         "
echo "-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-"
echo
echo "This installer will setup disk $TARGET to boot only salixlive."
if [ "$MBR" != "$TARGET" ]; then
  echo
  echo "Warning! Master boot record (MBR) of $MBR will be overwritten."
  echo "If you use $MBR to boot any existing operating system, it will not work"
  echo "anymore. Only salixlive will boot from this device. Be careful!"
fi
echo
echo "Press any key to continue, or Ctrl+C to abort..."
read junk
clear

echo "Flushing filesystem buffers, this may take a while..."
sync

# determine is this is a 32 or 64 bits system
ARCH=32
[ "$(uname -m|grep 64)" ] && ARCH=64

# setup MBR if the device is not in superfloppy format
if [ "$MBR" != "$TARGET" ]; then
  which fdisk > /dev/null 2>&1 && which parted > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    GAP=$(fdisk -l -u $MBR | grep "^${MBR}1" | awk '{print $3}')
    if [ "$GAP" -lt 63 ]; then
      maxs=$(parted $MBR unit s print |grep '^ 1'|awk '{print $3}')
      echo "Error : the post MBR gap is missing or not large enough (63 sectors)."
      echo "Suggestion : slightly move the first partition (${MBR}1) to reach the gap size."
      echo ""
      echo "Do you want to slightly reduce this partition to free some space for the required post-MBR-gap?"
      echo "  parted ${MBR} resize 1 63s $maxs"
      read -p "y/N ? " R
      if [ "$R" = "y" -o "$R" = "Y" ]; then
        umount -f ${MBR}1
        parted ${MBR} resize 1 63s $maxs
        ret=$?
        echo "Please unplug the USB key, re-plug in and re-run this script"
        exit $ret
      else
        exit 2
      fi
    fi
  fi
  echo "Setting up MBR on $MBR..."
  ./boot/syslinux/lilo_$ARCH -S /dev/null -M $MBR ext # this must be here to support -A for extended partitions
  echo "Activating partition $TARGET..."
  ./boot/syslinux/lilo_$ARCH -S /dev/null -A $MBR $NUM
  echo "Updating MBR on $MBR..." # this must be here because LILO mbr is bad. mbr.bin is from syslinux
  cat ./boot/syslinux/mbr.bin > $MBR
fi

echo "Setting up boot record for $TARGET..."
./boot/syslinux/syslinux_$ARCH -d boot/syslinux $TARGET

echo "Disk $TARGET should be bootable now. Installation finished."

echo
echo "Read the information above and then press any key to exit..."
read junk
