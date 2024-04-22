#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

UBOOT="${ROOT}/uboot-2017.09_light"
GRUB="${ROOT}/grub-2.12"
OUTPUT="${ROOT}/output"
LINUX="${ROOT}/kernel-4.4.179"
EXTER="${ROOT}/external"
OVERLAYS="${EXTER}/packages/overlays"
SCRIPTS="${ROOT}/scripts"
export EXTER_ORANGEPI="$EXTER/orangepi-rk3399_v1.4"
export BUILD_APT_ARCHIVES_CACHE="/var/cache/apt/archives/"

OS=""
BT=""
ROOTFS=""
BOOT_PATH=""
UBOOT_PATH=""
ROOTFS_PATH=""
BUILD_KERNEL=""
BUILD_MODULE=""

# TODO: Auto/manual sources change - maybe take it from host?
SOURCES="http://ftp.de.debian.org/debian/"
METHOD="download"
KERNEL_NAME="linux4.4.179"
UNTAR="tar -xpf"
CORES=$(nproc --ignore=1)
HOST_USER_REAL=$(who | awk '{print $1}')

TITLE="Orange Rigol v${BUILD_VERSION_TEXT}"
[ "${BUILD_GIT_SHORT}" == "" ] || TITLE+=" ${BUILD_GIT_SHORT}"

whiptail_menu_title_set_prefix "${TITLE} | "

ROOT_UUID="614e0000-0000-4b53-8000-1d28000054a9"
