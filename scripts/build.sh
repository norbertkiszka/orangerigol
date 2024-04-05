#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

set -ea

export PATH="${ROOT}/toolchain/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin:$PATH:/bin:/usr/bin:/sbin:/usr/sbin"

export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_CTYPE="en_US.UTF-8" 2> /dev/null
export LC_ALL="en_US.UTF-8" 2> /dev/null

BUILD_VERSION_MAJOR=0
BUILD_VERSION_MINOR=2
BUILD_VERSION_PATCH=0
BUILD_EXTRAVERSION=0
BUILD_VERSION_TEXT="${BUILD_VERSION_MAJOR}.${BUILD_VERSION_MINOR}.${BUILD_VERSION_PATCH}.${BUILD_EXTRAVERSION}"
BUILD_GIT_SHORT=$(git log --pretty=format:'%h' -n 1 2> /dev/null)
[ "$(git diff-index --name-only HEAD)" == "" ] || BUILD_GIT_SHORT="${BUILD_GIT_SHORT}-dirty"

echo -en "\033[0;33m[ Orange Rigol Build System version ${BUILD_VERSION_TEXT}"
[ "${BUILD_GIT_SHORT}" == "" ] || echo -en " git ${BUILD_GIT_SHORT}"
echo -e " ]\033[0m"

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

# Most of it is for backward and forward compatilibity
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

# We need very old gcc for compatilibity with old U-Boot, old kernel and Rigol software
TOOLS=$ROOT/toolchain/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-

export CC="${TOOLS}gcc -I/usr/include/aarch64-linux-gnu -I/usr/include"

# TODO: Auto/manual sources change - maybe take it from host?
SOURCES="http://ftp.de.debian.org/debian/"
METHOD="download"
KERNEL_NAME="linux4.4.179"
UNTAR="tar -xpf"
CORES=$(nproc --ignore=1)
HOST_USER_REAL=$(who | awk '{print $1}')

source "${SCRIPTS}"/lib/general.sh
source "${SCRIPTS}"/lib/compilation.sh
source "${SCRIPTS}"/lib/distributions.sh
source "${SCRIPTS}"/lib/build_image.sh
source "${SCRIPTS}"/lib/flash_image.sh

if [ "${EUID}" != 0 ]; then
	build_warning "This script requires root privileges, trying to use sudo..."
	sudo $0 $*
	exit $?
fi

build_info "Difficulty: ${DIFFICULTY}"

if [ ! -f $BUILD/.prepare_host ] || [ "$(cat "$BUILD/.prepare_host" | grep "$BUILD_GIT_SHORT")" == "" ] ; then
	prepare_host
	echo "$BUILD_GIT_SHORT" > $BUILD/.prepare_host
fi

MENUSTR="Welcome to Orange Rigol Build System.\n\nPlease choose platform (device, board):"
BOARD=$(whiptail --title "Orange Rigol Build System" \
	--menu "$MENUSTR" 20 60 10 --cancel-button Exit --ok-button Select \
	"DHO924S" "" \
	"DHO924" "" \
	"DHO914S" "" \
	"DHO814" "" \
	"DHO812" "" \
	"DHO804" "" \
	"DHO802" "" \
	3>&1 1>&2 2>&3)

build_info "Selected board: ${BOARD}"

whiptail_menu_options_reset

whiptail_menu_options_add "1" "Build Release image (SD card image)"
if [ "$DIFFICULTY" == "expert" ] ; then
	whiptail_menu_options_add "2" "Build Rootfs only"
	whiptail_menu_options_add "3" "Build Uboot bootloader"
	whiptail_menu_options_add "4" "Build Linux kernel with modules"
	whiptail_menu_options_add "5" "Build Linux kernel modules only"
	[ ! -e "$BUILD/kernel/boot.img" ] || whiptail_menu_options_add "6" "Update Linux kernel image on a SD card"
	[ ! -d "$BUILD/lib/modules" ] || [ "$(ls $BUILD/lib/modules 2> /dev/null)" == "" ] \
	|| whiptail_menu_options_add "7" "Update Linux kernel modules on a SD card"
	[ ! -e "$BUILD/uboot/idbloader.img" ] || [ ! -e "$BUILD/uboot/uboot.img" ] || [ ! -e "$BUILD/uboot/trust.img" ] \
	|| whiptail_menu_options_add "8" "Update Uboot bootloader on a SD card"
fi
[ "${BUILD_GIT_SHORT}" == "" ] || whiptail_menu_options_add "9" "Update this script (via git pull)"

if [ "$DIFFICULTY" == "expert" ] && [ -e $DEST/etc/orangerigol/buildstage ] && [ "$(cat $DEST/etc/orangerigol/buildstage | grep "user_setup")" != "" ] ; then
	whiptail_menu_options_add "10" "Add additional user into existing rootfs"
fi

if [ "$DIFFICULTY" == "expert" ] && \
[ -e "$BUILD/uboot/idbloader.img" ] && \
[ -e "$BUILD/uboot/uboot.img" ] && \
[ -e "$BUILD/uboot/trust.img" ] && \
[ -e "$BUILD/kernel/boot.img" ] && \
[ -e "$DEST/bin/bash" ] && \
[ -e $DEST/etc/orangerigol/buildstage ] && \
[ "$(cat $DEST/etc/orangerigol/buildstage | grep "build_ready")" != "" ] \
; then
	whiptail_menu_options_add "11" "Build image from a current files (without making any changes)"
fi

if [ "$DIFFICULTY" == "expert" ] && [ -e "$DEST/bin/bash" ] && [ -e "$DEST/usr/bin/bash" ] ; then
	whiptail_menu_options_add "12" "Chroot into rootfs"
fi

OPTION_ID_FLASH_IMAGE="13"
if [ "$DIFFICULTY" == "expert" ] ; then
	[ "$(ls $BUILD/images/*.img 2> /dev/null)" != "" ] && whiptail_menu_options_add "$OPTION_ID_FLASH_IMAGE" "Flash image on a SD card"
else
	[ "$(ls $BUILD/images/*.img 2> /dev/null | grep "_${BOARD}_")" != "" ] && whiptail_menu_options_add "$OPTION_ID_FLASH_IMAGE" "Flash (write) image on a SD card"
fi

BUILD_OPTION=$(whiptail_menu_execute "Orange Rigol Build System | Main menu" "Please select build option")
build_info "Selected option $BUILD_OPTION: ${WHIPTAIL_MENU_OPTIONS_KEY_TO_STRING[$BUILD_OPTION]}"

case "${BUILD_OPTION}" in 
	"1")
		chose_username
		select_distro
		compile_uboot
		compile_kernel
		build_rootfs
		build_image
		build_success "Succeed to build Release image in a file:\n\n${IMAGE}"
		/usr/games/cowsay "Now You can run this script again and chose last option (${OPTION_ID_FLASH_IMAGE}.) to flash SD card in order to use this system." 2> /dev/null || true
		;;
	"2")
		chose_username
		select_distro
		#compile_uboot
		compile_kernel
		build_rootfs
		build_success "Succeed to build rootfs."
		;;
	"3")
		compile_uboot
		build_success "Succeed to compile U-Boot."
		;;
	"4")
		compile_kernel
		#compile_module
		build_success "Succeed to compile Linux kernel with modules."
		;;
	"5")
		compile_module
		build_success "Succeed to compile Linux kernel modules."
		;;
	"6")
		sdcard_check
		check_before_flash
		confirm_flash
		kernel_update
		build_success "Succeed to update kernel in:\n${SDCARD_PATH}."
		;;
	"7")
		rootfs_check
		modules_update
		build_success "Succeed to update Linux kernel modules in:\n${ROOTFS_PATH}."
		;;
	"8")
		sdcard_check
		check_before_flash
		confirm_flash
		uboot_update
		build_success "Succeed to update U-Boot bootloader in ${SDCARD_PATH}."
		;;
	"9")
		git pull
		build_success "Build version is latest. Short hash: ($(git log --pretty=format:'%h' -n 1 2> /dev/null))."
		;;
	"10")
		add_overlays_always
		chose_username_for_additional_user
		add_user "${CHOSEN_USERNAME}"
		build_success "User ${CHOSEN_USERNAME} was added into system in rootfs."
		;;
	"11")
		extract_imagetype_from_rootfs
		build_image
		build_success "Image on current files was build in ${IMAGE}."
		;;
	"12")
		add_overlays_always
		build_info "Press CTRL+D or type exit[enter] to exit." # Sometimes users are very good random number generators.
		do_chroot /bin/bash
		build_info "Back in build script..."
		;;
	"13")
		select_image
		sdcard_check
		check_before_flash
		confirm_flash
		flash_image
		build_success "Succeed to flash image."
		/usr/games/cowsay "Enjoy using Orange Rigol system" 2> /dev/null || true
		;;
	"")
		build_notice "User exit from main menu."
		exit 1
		;;
	"*")
		whiptail --title "Orange Rigol Build System" \
		--msgbox "Please select correct option" 10 50 0
		;;
esac
