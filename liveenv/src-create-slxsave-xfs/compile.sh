#!/bin/sh
cd $(dirname "$0")
root=../root
cp *.desktop $root/usr/share/applications/
cp persistence-wizard.desktop $root/home/one/Desktop/
for po in *.po; do
  l=$(echo $po|sed 's/create-slxsave-xfs-\(.*\)\.po/\1/')
  if [ ! -e $root/usr/share/locale/$l/LC_MESSAGES ]; then
    mkdir -p $root/usr/share/locale/$l/LC_MESSAGES
  fi
  msgfmt $po -o $root/usr/share/locale/$l/LC_MESSAGES/create-slxsave-xfs.mo
done
