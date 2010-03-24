#!/bin/sh
cd $(dirname $0)

intltool-extract --type="gettext/ini" persistence-wizard.desktop.in
intltool-extract --type="gettext/ini" persistence-wizard-kde.desktop.in
xgettext --from-code=utf-8 -L shell -o po/create-slxsave-xfs.pot ../root/usr/sbin/create-slxsave-xfs-gui
xgettext --from-code=utf-8 -j -L C -kN_ -o po/create-slxsave-xfs.pot persistence-wizard.desktop.in.h
xgettext --from-code=utf-8 -j -L C -kN_ -o po/create-slxsave-xfs.pot persistence-wizard-kde.desktop.in.h

rm persistence-wizard.desktop.in.h persistence-wizard-kde.desktop.in.h

cd po
for i in `ls *.po`; do
	msgmerge -U $i create-slxsave-xfs.pot
done
rm -f ./*~
