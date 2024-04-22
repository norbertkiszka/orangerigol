#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

# Make sure kde apps will use gtk theme settings
echo "export QT_QPA_PLATFORMTHEME=gtk2" > ${DEST}/etc/skel/.profile
#echo "export QT_QPA_PLATFORMTHEME=gtk2" > ${DEST}/etc/profile
