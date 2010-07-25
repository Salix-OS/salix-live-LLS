#!/bin/sh
cd $(dirname $0)
SEARCH=/etc/rc.d
for rc in root/etc/rc.d/*; do
  rc=$(basename $rc)
  if [ -e $SEARCH/$rc ]; then
    diff -u $SEARCH/$rc root/etc/rc.d/$rc > $rc.diff
  fi
done
