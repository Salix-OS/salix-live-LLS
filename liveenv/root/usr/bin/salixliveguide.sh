#!/bin/sh
L=$(echo $LANG|sed 's/\..*//')
if [ ! -e /usr/doc/salixliveguide/SalixLiveGuide-$L.pdf ]; then
  L=en_US
fi
xdg-open /usr/doc/salixliveguide/SalixLiveGuide-$L.pdf
