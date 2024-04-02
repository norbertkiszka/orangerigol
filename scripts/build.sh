#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

set -e

export PATH="${ROOT}/toolchain/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin:$PATH:/bin:/usr/bin"

echo -e "\033[0;33m[ Orange Rigol Build System ]\033[0m"

ROOT=`pwd`
UBOOT="${ROOT}/uboot-2017.09_light"
BUILD="${ROOT}/output"
LINUX="${ROOT}/kernel-4.4.179"
EXTER="${ROOT}/external"
SCRIPTS="${ROOT}/scripts"
DEST="${BUILD}/rootfs"
UBOOT_BIN="$BUILD/uboot"
export EXTER_ORANGEPI="$EXTER/orangepi-rk3399_v1.4"
export BUILD_APT_ARCHIVES_CACHE="/var/cache/apt/archives/"

OS=""
BT=""
CHIP="RK3399"
ARCH="arm64"
DISTRO="bookworm"
ROOTFS=""
BOOT_PATH=""
UBOOT_PATH=""
ROOTFS_PATH=""
BUILD_KERNEL=""
BUILD_MODULE=""

TOOLS=$ROOT/toolchain/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-

export CC="${TOOLS}gcc -I/usr/include/aarch64-linux-gnu -I/usr/include"

SOURCES="http://ftp.de.debian.org/debian/"
METHOD="download"
KERNEL_NAME="linux4.4.179"
UNTAR="tar -xpf"
CORES=$(nproc --ignore=1)
PLATFORM="DHO924S"

if [ "${EUID}" != 0 ]; then
	build_warning "This script requires root privileges, trying to use sudo..."
	sudo "${ROOT}/build.sh"
	exit $?
fi

source "${SCRIPTS}"/lib/general.sh
source "${SCRIPTS}"/lib/compilation.sh
source "${SCRIPTS}"/lib/distributions.sh
source "${SCRIPTS}"/lib/build_image.sh
source "${SCRIPTS}"/lib/flash_image.sh

if [ ! -f $BUILD/.prepare_host ]; then
	prepare_host
	touch $BUILD/.prepare_host
fi

MENUSTR="Welcome to Orange Rigol Build System. Please choose Platform."
#################################################################

BOARD=$(whiptail --title "Orange Rigol Build System" \
	--menu "$MENUSTR" 15 60 5 --cancel-button Exit --ok-button Select \
	"DHO924S" "" \
	"DHO924" "" \
	"DHO914S" "" \
	"DHO814" "" \
	"DHO812" "" \
	"DHO804" "" \
	"DHO802" "" \
	3>&1 1>&2 2>&3)

build_info "Selected board: ${BOARD}"

OPTIONS=("1" "Build Release image (SD card image)")
OPTIONS+=("2" "Build Rootfs")
OPTIONS+=("3" "Build Uboot bootloader")
OPTIONS+=("4" "Build Linux kernel with modules")
OPTIONS+=("5" "Build Linux kernel modules only")
OPTIONS+=("6" "Update Linux kernel image on a SD card")
OPTIONS+=("7" "Update Linux kernel modules on a SD card")
OPTIONS+=("8" "Update Uboot bootloader on a SD card")

if [ -e "$BUILD/uboot/idbloader.img" ] && \
[ -e "$BUILD/uboot/uboot.img" ] && \
[ -e "$BUILD/uboot/trust.img" ] && \
[ -e "$BUILD/kernel/boot.img" ] && \
[ -e "$DEST/bin/bash" ] \
; then
	OPTIONS+=("9" "Build image from a current files")
fi

[ "$(ls $BUILD/images/*.img 2> /dev/null)" != "" ] && OPTIONS+=("10" "Flash image on a SD card")

OPTION=$(whiptail --title "Orange Rigol Build System" --menu "Please select build option" --cancel-button Exit --ok-button Select 20 60 10 "${OPTIONS[@]}" 3>&1 1>&2 2>&3)


case "${OPTION}" in 
	"1")
		build_info "Selected option: ${OPTIONS[1]}"
		select_distro
		compile_uboot
		compile_kernel
		build_rootfs
		build_image
		build_success "Succeed to build Release image in a file ${IMAGE}"
		;;
	"2")
		build_info "Selected option: ${OPTIONS[3]}"
		select_distro
		#compile_uboot
		compile_kernel
		build_rootfs
		build_success "Succeed to build rootfs"
		;;
	"3")
		build_info "Selected option: ${OPTIONS[5]}"
		compile_uboot
		build_success
		build_success "Succeed to compile U-Boot"
		;;
	"4")
		build_info "Selected option: ${OPTIONS[7]}"
		compile_kernel
		#compile_module
		build_success "Succeed to compile Linux kernel with modules"
		;;
	"5")
		build_info "Selected option: ${OPTIONS[9]}"
		compile_module
		build_success "Succeed to compile Linux kernel modules"
		;;
	"6")
		build_info "Selected option: ${OPTIONS[11]}"
		sdcard_check
		kernel_update
		build_success "Succeed to update kernel in:\n${SDCARD_PATH}"
		;;
	"7")
		build_info "Selected option: ${OPTIONS[13]}"
		rootfs_check
		modules_update
		build_success "Succeed to update Linux kernel modules in:\n${ROOTFS_PATH}"
		;;
	"8")
		build_info "Selected option: ${OPTIONS[15]}"
		sdcard_check
		uboot_update
		build_success "Succeed to update U-Boot bootloader in ${SDCARD_PATH}"
		;;
	"9")
		build_info "Selected option: Build image from a current files"
		build_image
		build_success "Image on current files was build in ${IMAGE}"
		;;
	"10")
		build_info "Selected option: Flash image on a SD card"
		select_image
		sdcard_check
		flash_image
		build_success "Succeed to flash image."
		;;
	*)
		whiptail --title "Orange Rigol Build System" \
		--msgbox "Please select correct option" 10 50 0
		;;
esac
