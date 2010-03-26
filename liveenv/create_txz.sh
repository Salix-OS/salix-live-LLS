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
FIREFOXVER=$('ls' -1 ../PKGS/mozilla-firefox-*.txz | sed 's/.*-.*-\([^-]*\)-[^-]*-[^-*]\.txz/\1/')
GPARTED=$('ls' -1 ../PKGS/gparted-*.txz)
SALIXLIVEINSTALLER=$('ls' -1 ../PKGS/salix-live-installer-*.txz)
./src-create-slxsave-xfs/compile.sh
tar xf $GPARTED usr/share/applications
tar xf $SALIXLIVEINSTALLER usr/share/applications
cp usr/share/applications/*.desktop root/home/one/Desktop/
rm -rf usr
mkdir -p root/usr/doc/salixstartupguide
cp ../SalixStartupGuide*.pdf root/usr/doc/salixstartupguide/
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
sed -i -e "s/__VER__/$FIREFOXVER/" home/one/.gconf/desktop/gnome/url-handlers/*/%gconf.xml
/sbin/makepkg -l y -c n "$HERE/../PKGS/liveenv-$VER-noarch-$RLZ.txz"
cd "$HERE"
rm -rf $T
