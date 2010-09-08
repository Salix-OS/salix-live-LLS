#!/bin/sh
if [ $UID -ne 0 ]; then
  echo "you need to be root"
  exit 1
fi
cd $(dirname "$0")
VER=$(cat version)
RLZ=$(cat release)
T=$(mktemp -d)
HERE="$PWD"
GPARTED=$('ls' -1 ../PKGS/gparted-*.txz)
SALIXLIVEINSTALLER=$('ls' -1 ../PKGS/salix-live-installer-*.txz)
SALIXSTARTUPGUIDE=$('ls' -1 ../PKGS/salix-startup-guide-*.txz)
./src-create-slxsave-xfs/compile.sh
tar xf $GPARTED usr/share/applications
tar xf $SALIXLIVEINSTALLER usr/share/applications
tar xf $SALIXSTARTUPGUIDE usr/share/applications
cp usr/share/applications/*.desktop root/home/one/Desktop/
# Remove *-kde.desktop files for liveuser "one", 
# they are not required for a lxde version
rm root/home/one/Desktop/*-kde.desktop
rm -rf usr
cp -ar root/* $T/
cd $T
find . -type d -name '.svn' | xargs -i@ rm -rf @
chown -R 0:0 .
chown -R 1000:100 home/*
chown -R 0:0 etc/ssh
chmod u=rwx,go=rx etc/ssh
chmod u=rw,go=r etc/ssh/*
chmod go-r etc/ssh/*_key
chown :43 etc/shadow
/sbin/makepkg -l y -c n "$HERE/../PKGS/liveenv-$VER-noarch-$RLZ.txz"
cd "$HERE"
rm -rf $T
