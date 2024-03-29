#!/bin/sh
cd $(dirname $0)
trap "{ rm -rf slapt-get* var PKGSLIST; exit 255; }" SIGINT SIGTERM
mkdir -p slapt-get
cat <<EOF > slapt-getrc
WORKINGDIR=$PWD/slapt-get
EXCLUDE=.*-[0-9]+dl$,-x86_64-
SOURCE=http://salix.enialis.net/i486/slackware-13.1/:OFFICIAL
SOURCE=http://salix.enialis.net/i486/slackware-13.1/extra/:OFFICIAL
SOURCE=http://salix.enialis.net/i486/13.1/:PREFERRED
EOF
export ROOT=$PWD
mkdir -p var/log/packages
/usr/sbin/slapt-get -c $PWD/slapt-getrc -u
echo "ready ?"
read pause
nb=$(cat packages-* | wc -l)
i=0
d0=$(date +%s)
cat /dev/null > pkgs_in_errors
cat packages-* | sort | while read p; do
  i=$(( $i + 1 ))
  clear
  echo '⋅⋅⋅---=== getpkgs.sh ===---⋅⋅⋅'
  echo ''
  echo -n 'Progression : ['
  perct=$(($i * 100 / $nb))
  nbSharp=$(($i * 50 / $nb))
  nbSpace=$((50 - $nbSharp))
  for j in $(seq $nbSharp); do echo -n '#'; done
  for j in $(seq $nbSpace); do echo -n '_'; done
  echo "] $i / $nb ($perct%)"
  offset=$(($(date +%s) - $d0))
  timeremain=$((($nb - $i) * $offset / $i))
  echo 'Remaining time (estimated) :' $(date -d "1970-01-01 UTC +$timeremain seconds" +%M:%S)
  echo ''
  /usr/sbin/slapt-get -c $PWD/slapt-getrc -i -d -y --no-dep $p || echo $p >> pkgs_in_errors
done
mkdir -p PKGS
find slapt-get -name '*PACKAGES.TXT.gz' -exec mv '{}' PKGS/ \; && find slapt-get -name '*.t[gx]z' -exec mv '{}' PKGS/ \; && rm -rf slapt-get* var
