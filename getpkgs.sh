#!/bin/sh
trap "{if [ -e /var/log/packages.ok ]; then rm -rf /var/log/packages; mv /var/log/packages.ok /var/log/packages; fi; exit 1}" SIGINT SIGTERM
mkdir -p slapt-get
cat <<EOF > slapt-getrc
WORKINGDIR=$PWD/slapt-get
EXCLUDE=.*-[0-9]+dl$,x86_64
SOURCE=http://salix.enialis.net/i486/slackware-13.0/
SOURCE=http://salix.enialis.net/i486/slackware-13.0/extra/
SOURCE=http://salix.enialis.net/i486/slackware-13.0/patches/:OFFICIAL
SOURCE=http://salix.enialis.net/i486/13.0/:PREFERRED
EOF
mv /var/log/packages /var/log/packages.ok
mkdir /var/log/packages
/usr/sbin/slapt-get -c $PWD/slapt-getrc -u
echo "ready ?"
read pause
cat packages-* | sort > PKGSLIST
cat PKGSLIST | while read p; do
  /usr/sbin/slapt-get -c $PWD/slapt-getrc -i -d -y --no-dep $p
done
rmdir /var/log/packages
mv /var/log/packages.ok /var/log/packages
rm -f PKGSLIST
mkdir -p PKGS
find slapt-get -name '*.t[gx]z' -exec mv '{}' PKGS/ \; && rm -rf slapt-get*
