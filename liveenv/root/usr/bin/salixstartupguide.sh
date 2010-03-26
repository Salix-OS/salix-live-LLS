#!/bin/sh
L=$(echo $LANG|sed 's/\..*//')
if [ ! -e /usr/doc/salixstartupguide/SalixStartupGuide-$L.pdf ]; then
  L=$(echo $L|sed 's/_.*//')
  if [ ! -e /usr/doc/salixstartupguide/SalixStartupGuide-$L.pdf ]; then
    L=en
  fi
fi
xdg-open /usr/doc/salixstartupguide/SalixStartupGuide-$L.pdf
