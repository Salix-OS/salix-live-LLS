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
FIREFOXVER=$('ls' -1 ../PKGS/mozilla-firefox-*-*-*.txz | head -n 1 | sed 's/.*-.*-\([^-]*\)-[^-]*-[^-]*\.txz/\1/')
TFF=$(mktemp -d)
cd $TFF
tar xf $HERE/../PKGS/mozilla-firefox-$FIREFOXVER-*.txz
FIREFOXMILESTONE=$(grep Milestone /usr/lib/firefox-$FIREFOXVER/platform.ini | sed 's/^Milestone=\(.*\)/\1/')
cd -
rm -rf $TFF
GPARTED=$('ls' -1 ../PKGS/gparted-*.txz)
SALIXLIVEINSTALLER=$('ls' -1 ../PKGS/salix-live-installer-*.txz)
SALIXSTARTUPGUIDE=$('ls' -1 ../PKGS/salix-startup-guide-*.txz)
LIVECLONE=$('ls' -1 ../PKGS/liveclone-*.txz)
./src-create-slxsave-xfs/compile.sh
tar xf $GPARTED usr/share/applications
tar xf $SALIXLIVEINSTALLER usr/share/applications
tar xf $SALIXSTARTUPGUIDE usr/share/applications
tar xf $LIVECLONE usr/share/applications
cp usr/share/applications/*.desktop root/home/one/Desktop/
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
sed -i -e "s/__VER__/$FIREFOXVER/" home/one/.gconf/desktop/gnome/url-handlers/*/%gconf.xml
mkdir -p home/one/.mozilla/firefox/jb8obseq.default/
cat <<EOF > home/one/.mozilla/firefox/profiles.ini
[General]
StartWithLastProfile=1

[Profile0]
Name=default
IsRelative=1
Path=jb8obseq.default

EOF
cat <<EOF > home/one/.mozilla/firefox/jb8obseq.default/prefs.js
# Mozilla User Preferences

user_pref("browser.rights.3.shown", true);
user_pref("browser.startup.homepage_override.mstone", "rv:$FIREFOXMILESTONE");

EOF
chown -R 1000:100 home/one/.mozilla
/sbin/makepkg -l y -c n "$HERE/../PKGS/liveenv-$VER-noarch-$RLZ.txz"
cd "$HERE"
rm -rf $T
