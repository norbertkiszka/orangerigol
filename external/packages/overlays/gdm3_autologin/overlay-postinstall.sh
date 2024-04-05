#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

GDM3_AUTOLOGIN_USERNAME=$(awk -F: '$3 == 1000 {print $1}' "${DEST}/etc/passwd")

if [ "$GDM3_AUTOLOGIN_USERNAME" = "" ] ; then 
	echo -e "$0\nError: There is no user with id 1000"
	exit 1
fi
	
sed -i "s/TimedLogin_username/${GDM3_AUTOLOGIN_USERNAME}/g" "${DEST}/etc/gdm3/daemon.conf"
