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
./src-create-slxsave-xfs/compile.sh
cp -ar root/* $T/
cd $T
find . -type d -name '.svn' | xargs -i@ rm -rf @
mkdir -p home/one/docs
cp "$HERE/../HOW_TO.html" "$HERE"/../howto*.gif home/one/docs/
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
