#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

# This is a helper to install many packages in nicer way with messages like: Installing packages part 6/23

# Example:
# pkg_option_yes=1 ; pkg_option_norecommends=1 ; packages_add pkg1 pkg2 pkg3
# pkg_option_yes=1 ; pkg_option_norecommends=0 ; packages_add pkg4 pkg5 pkg6
# packages_install_all

set -e

export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_CTYPE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

ARCH=$(dpkg --print-architecture)

packages_reset()
{
	unset PACKAGES_LISTS
	unset PACKAGES_OPTIONS
	PACKAGES_LISTS=()
	PACKAGES_OPTIONS=()
}

# This function takes following input:
# $1 - string with packages names
# pkg_option_norecommends (when 1, it will be installed without recommended packages)
# pkg_option_yes (when 1, it will pass yes option to pkg manager)
packages_add()
{
	unset OPTIONS
	OPTIONS=""
	PACKAGES_LISTS+=("`echo -n ${*}`")
	[ "$pkg_option_norecommends" != "1" ] || OPTIONS+="norecommends "
	[ "$pkg_option_yes" != "1" ] || OPTIONS+="yes "
	PACKAGES_OPTIONS+=("$OPTIONS")
}

package_install_key()
{
	KEY=$1
	
	if [ "$PACKAGES_LISTS[${KEY}]" == "" ] ; then
		echo "ERROR: Empty packages list"
		exit 1
	fi
	
	unset COMMAND
	COMMAND="apt-get install "
	[ "$(echo ${PACKAGES_OPTIONS[${KEY}]} | grep "yes")" == "" ] || COMMAND+=" -y "
	[ "$(echo ${PACKAGES_OPTIONS[${KEY}]} | grep "norecommends")" == "" ] || COMMAND+=" --no-install-recommends "
	COMMAND+="${PACKAGES_LISTS[$KEY]}"
	
	((NUM=KEY+1))
	echo -e "\033[0;32mInstalling packages part ${NUM}/${#PACKAGES_LISTS[@]}\033[0m"
	echo -e "\033[0;32mPackages to install: ${PACKAGES_LISTS[$KEY]}\033[0m"
	$COMMAND
}

packages_install_all()
{
	apt-get update
	for key in "${!PACKAGES_LISTS[@]}"
	do
		package_install_key $key
	done
}

packages_reset
