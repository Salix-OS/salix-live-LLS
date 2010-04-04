#!/bin/sh
L=$(echo $LANG|sed 's/\..*//')
SEARCHPATH=/mnt/live$(cat /mnt/live/bootdev|gawk '{print $3}')/docs
if [ ! -e $SEARCHPATH/SalixStartupGuide-$L.pdf ]; then
  L=$(echo $L|sed 's/_.*//')
  if [ ! -e $SEARCHPATH/SalixStartupGuide-$L.pdf ]; then
    L=en
  fi
fi
xdg-open $SEARCHPATH/SalixStartupGuide-$L.pdf
