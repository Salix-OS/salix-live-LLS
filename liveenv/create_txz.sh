#!/bin/sh
if [ $UID -ne 0 ]; then
  echo "you need to be root"
  exit 1
fi
cd $(dirname $0)
VER=$(cat version)
RLZ=$(cat release)
T=$(mktemp -d)
HERE=$PWD
cp -ar root/* $T/
cd $T
find . -type d -name '.svn' | xargs -i@ rm -rf @
chown -R 0:0 .
chown -R 1000:100 home/*
chown -R 0:100 etc/ssh
chmod u=rwx,g=rs,o=rw etc/ssh
chmod go-r etc/ssh/*_key
chown :43 etc/shadow
chmod +x etc/profile.d/* etc/rc.d/* home/one/.xinitrc usr/libexec/* usr/sbin/*
/sbin/makepkg -l y -c n $HERE/../liveenv-$VER-noarch-$RLZ.txz
cd $HERE
rm -rf $T
