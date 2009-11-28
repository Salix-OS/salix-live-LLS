#!/bin/sh
cd $(dirname $0)
VER=$(cat version)
RLZ=$(cat release)
cd root
/sbin/makepkg -l y -c n ../../liveenv-$VER-noarch-$RLZ.txz
