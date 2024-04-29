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
	PACKAGES_LISTS=()
	PACKAGES_OPTIONS=()
}

# This function takes following input:
# Args: packages names
# Var pkg_option_norecommends (when 1, it will be installed without recommended packages)
# Var pkg_option_yes (when 1, it will pass yes option to pkg manager)
packages_add()
{
	unset OPTIONS
	OPTIONS=""
	PACKAGES_LISTS+=("`echo -n ${*}`")
	[ "$pkg_option_norecommends" == "1" ] && OPTIONS+="norecommends "
	[ "$pkg_option_yes" == "1" ] && OPTIONS+="yes "
	[ "$pkg_option_ignoremissing" == "1" ] && OPTIONS+="ignoremissing "
	PACKAGES_OPTIONS+=("$OPTIONS")
}

packages_add_if_available()
{
	local request="${@}"
	local toadd=()
	
	for pkg in $request
	do
		#if apt-cache pkgnames | grep -F "$pkg" &> /dev/null ; then
		if [ "$(apt-cache showpkg "$pkg" | awk 'NR==3')" ] ; then
			toadd+=($pkg)
		fi
	done
	
	packages_add ${toadd[@]}
}

__package_install_key()
{
	KEY=$1
	
	if [ "$PACKAGES_LISTS[${KEY}]" == "" ] ; then
		echo "ERROR: Empty packages list"
		exit 1
	fi
	
	unset COMMAND
	COMMAND="apt-get install --show-progress "
	[ "$(echo ${PACKAGES_OPTIONS[${KEY}]} | grep -F "yes")" == "" ] || COMMAND+=" -y "
	[ "$(echo ${PACKAGES_OPTIONS[${KEY}]} | grep -F "norecommends")" == "" ] || COMMAND+=" --no-install-recommends "
	[ "$(echo ${PACKAGES_OPTIONS[${KEY}]} | grep -F "ignoremissing")" == "" ] || COMMAND+=" --ignore-missing "
	COMMAND+="${PACKAGES_LISTS[$KEY]}"
	
	((NUM=KEY+1))
	echo -e "\033[0;32mInstalling packages part ${NUM}/${#PACKAGES_LISTS[@]}\033[0m"
	echo -e "\033[0;32m${COMMAND}\033[0m"
	$COMMAND
}

packages_install_all()
{
	apt-get update
	for key in "${!PACKAGES_LISTS[@]}"
	do
		[ "$PACKAGES_LISTS[${KEY}]" == "" ] || __package_install_key $key
	done
	packages_reset
}

packages_reset
