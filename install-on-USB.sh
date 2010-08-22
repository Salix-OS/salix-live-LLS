#!/bin/sh
cd $(dirname $0)

VER=1.3
AUTHOR='Pontvieux Cyrille - jrd@enialis.net'
LICENCE='GPL v3+'

version() {
  echo "install-on-USB v$VER by $AUTHOR"
  echo "Licence : $LICENCE"
  echo '-> Install grub2 on an USB key using an ISO or the USB key itself.'
}

usage() {
  version
  echo ''
  echo 'usage: install-on-USB.sh [-h/--help] [-v/--version]'
  exit 1
}

get_dev_part() {
  MNTDIR="$1"
  DEVPART=$(mount | grep "on $MNTDIR " | cut -d' ' -f1 | head -n 1)
  if [ -z "$DEVPART" ]; then
    echo "Error: $MNTDIR doesn't seem to be mounted" >&2
    exit 2
  elif ([ "$(echo $DEVPART | awk '{s=substr($1, 1, 1); print s;}')" != "/" ] || [ ! -r "$DEVPART" ]); then
    echo "Error: $DEVPART detected as a the device of" >&2
    echo "  $MNTDIR but seems invalid." >&2
    exit 2
  else
    echo $DEVPART
  fi
}

check_grub_files() {
  MNTDIR="$1"
  if ([ ! -f "$MNTDIR/boot/grub_mbr" ] || [ ! -f "$MNTDIR/boot/grub_post_mbr_gap" ]); then
    echo "Error: $MNTDIR/boot doesn't contain grub_mbr and grub_post_mbr_gap files" >&2
    exit 3
  fi
}

get_dev_root() {
  DEVPART=$1
  echo $DEVPART | awk -v l=${#DEVPART} '{s=substr($1, 1, l - 1); print s;}'
}

move_first_partition() {
  DEVICE=$1
  which parted >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    maxs=$(parted $DEVICE unit s print | grep '^ 1' | awk '{print $3}')
    echo "Do you want to slightly reduce this partition to free some space for"
    echo "  the required post-MBR-gap?"
    echo "Command to run: parted ${DEVICE} resize 1 63s $maxs"
    printf "Continue? [y/N] "
    read R
    if ([ "$R" = "y" ] || [ "$R" = "Y" ]); then
      umount -f ${DEVICE}1
      parted ${DEVICE} resize 1 63s $maxs
      ret=$?
      echo "Please unplug the USB key, re-plug in and re-run this script"
      exit $ret
    else
      echo "Ok, so do it with a partition tool of your choice." >&2
      exit 2
    fi
  else
    echo "Error: parted is not available on your system so I cannot propose you" >&2
    echo "  to slightly move your first partition. Please use a partition tool." >&2
    exit 2
  fi
}

check_post_mbr_gap() {
  DEVICE=$1
  # trying with 'dd' and 'od' to read the 4 LBA bytes of the first partition
  # 454 = 446 (bootloader) + 1 (active?) + 3 (CHS start address) + 1 (type) + 3 (CHS end address)
  GAP=$(dd if=$DEVICE count=4 bs=1 skip=454 2>/dev/null | od -td4 -An)
  if ([ -z "$GAP" ] || [ $GAP -lt 63 ]); then
    echo "Error: the post MBR gap is missing or not large enough (63 sectors)." >&2
    echo "  Yours appears to be of $GAP sectors." >&2
    echo "Suggestion: slightly move the first partition (${DEVICE}1) to reach the gap size." >&2
    echo ""
    move_first_partition $DEVICE
  fi
}

install_grub2() {
  DIR="$1"
  DEVICE="$2"
  echo "Warning: grub2 is about to be installed in $DEVICE"
  printf "Do you want to continue? [y/N] "
  read R
  if ([ "$R" = "y" ] || [ "$R" = "Y" ]); then
    dd if="$DIR/boot/grub_mbr" of=$DEVICE count=440 bs=1 conv=notrunc
    dd if="$DIR/boot/grub_post_mbr_gap" of=$DEVICE count=62 bs=512 seek=1 conv=notrunc
  fi
}

if ([ "$1" = "--version" ] || [ "$1" = "-v" ]); then
  version
  exit 0
fi
if ([ "$1" = "--help" ] || [ "$1" = "-h" ]); then
  usage
fi
if [ "$(id -ru)" -ne "0" ]; then
  echo "Error : you must run this script as root" >&2
  exit 2
fi
MNTDIR=$(cd ..; echo "$PWD")
DEVPART=$(get_dev_part "$MNTDIR"); [ $? -ne 0 ] && exit $?
check_grub_files "$MNTDIR"
DEVROOT=$(get_dev_root $DEVPART); [ $? -ne 0 ] && exit $?
check_post_mbr_gap $DEVROOT
install_grub2 "$MNTDIR" $DEVROOT
exit 0
