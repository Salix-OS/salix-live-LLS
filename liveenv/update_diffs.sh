#!/bin/sh
cd $(dirname $0)
for rc in root/etc/rc.d/*; do
  rc=$(basename $rc)
  if [ -e /etc/rc.d/$rc ]; then
    diff -u /etc/rc.d/$rc root/etc/rc.d/$rc > $rc.diff
  fi
done
