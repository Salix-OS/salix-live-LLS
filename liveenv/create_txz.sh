#!/bin/sh
cd $(dirname $0)
VER=$(cat version)
RLZ=$(cat release)
T=$(mktemp -d)
HERE=$PWD
cp -ar root/* $T/
cd $T
find . -type d -name '.svn' | xargs -i@ rm -rf @
/sbin/makepkg -l y -c n $HERE/../liveenv-$VER-noarch-$RLZ.txz
cd $HERE
rm -rf $T
