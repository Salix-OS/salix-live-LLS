#!/bin/sh
if [ $UID -ne 0 ]; then
  echo "you need to be root"
  exit 1
fi
cd $(dirname "$0")
root=../root
for po in `ls po/*.po`;do
  echo "Compiling `echo $po|sed "s|po/||"`"
  l=$(echo $po|sed 's|po/\(.*\)\.po|\1|')
  if [ ! -e $root/usr/share/locale/$l/LC_MESSAGES ]; then
    mkdir -p $root/usr/share/locale/$l/LC_MESSAGES
  fi
  msgfmt $po -o $root/usr/share/locale/$l/LC_MESSAGES/create-slxsave-xfs.mo
done
intltool-merge po/ -d -u persistence-wizard.desktop.in persistence-wizard.desktop
intltool-merge po/ -d -u persistence-wizard-kde.desktop.in persistence-wizard-kde.desktop
cp *.desktop $root/usr/share/applications/
cp *.desktop $root/home/one/Desktop/
