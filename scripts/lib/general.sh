#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

# Remove all previously added options.
whiptail_menu_options_reset()
{
	unset WHIPTAIL_MENU_OPTIONS # used to give it for whiptail
	unset WHIPTAIL_MENU_OPTIONS_KEY_TO_STRING # used internally
	declare -A WHIPTAIL_MENU_OPTIONS
	declare -A WHIPTAIL_MENU_OPTIONS_KEY_TO_STRING
}

# Add one option.
# Usage: whiptail_menu_options_add key name
whiptail_menu_options_add()
{
	WHIPTAIL_MENU_OPTIONS_KEY_TO_STRING["${1}"]=${2}
	WHIPTAIL_MENU_OPTIONS+=("${1}." "   ${2}")
}

whiptail_menu_execute()
{
	TEMP_STRING=$(whiptail --title "${1}" --menu "${2}" --cancel-button Exit --ok-button Select 22 110 15 "${WHIPTAIL_MENU_OPTIONS[@]}" 3>&1 1>&2 2>&3)
	echo "${TEMP_STRING}" | sed 's/.\{1\}$//'
}

# Taken from https://www.delftstack.com/howto/linux/bash-goto/
# Added requiment for a label name: it must begin with label_
# Changed $0 into ${BASH_SOURCE[1]}
# function goto
# {
# 	label=$1
# 	if [ "${label:0:6}" != "label_" ] || [ "${#label}" -lt "7" ] ; then
# 		build_error "Goto syntax error. Bad label name ${label}. All labels must begin with label_ and must have at least 7 chars in total."
# 	fi
# 	cmd=$(sed -n "/$label:/{:a;n;p;ba};" ${BASH_SOURCE[1]} | grep -v ':$') || build_error "Tried to goto into unexistent label $label or no code after label or other error..."
# 	eval "$cmd"
# 	exit
# }

sdcard_check()
{
	build_info "Asking for a sd card path ..."
	PREVIOUS_INPUT="/dev/mmcblk0"
	for ((i = 0; i < 10; i++)); do
		SDCARD_PATH=$(whiptail --title "Orange Rigol Build System" \
		--cancel-button Exit --ok-button OK \
		--inputbox "Please input device node of SD card (eg.: /dev/mmcblk0):" \
		10 80 "${PREVIOUS_INPUT}" 3>&1 1>&2 2>&3)

		if [ "$SDCARD_PATH" == "" ] ; then
			exit 1
		fi
		
		if [ $i = "8" ]; then
			build_error "Error, Invalid Path: ${SDCARD_PATH}"
		fi

		#if [ -b "$SDCARD_PATH" ]; then
		if [ -a "$SDCARD_PATH" ]; then
			i=200
		else
			whiptail --title "Orange Rigol Build System" --msgbox \
			"The input path is invalid! Please input correct path!" \
			--ok-button Continue 10 40 0
		fi
		PREVIOUS_INPUT="${SDCARD_PATH}"
	done
}

rootfs_check()
{
	build_info "Asking for a rootfs path ..."
	PREVIOUS_INPUT="/media/$HOST_USER_REAL/rootfs"
	for ((i = 0; i < 10; i++)); do
		ROOTFS_PATH=$(whiptail --title "Orange Rigol Build System" \
		--inputbox "Please input mount path of rootfs (eg.: /media/$HOST_USER_REAL/rootfs):" \
		10 60 "${PREVIOUS_INPUT}" 3>&1 1>&2 2>&3)

		if [ $i = "8" ]; then
			build_error "Error, Invalid Path: ${ROOTFS_PATH}"
		fi

		if [ ! -d "$ROOTFS_PATH" ]; then
			whiptail --title "Orange Rigol Build System" --msgbox \
			"The input path is invalid! Please input correct path!" \
			--ok-button Continue 10 40 0
		else
			i=200
		fi
		PREVIOUS_INPUT="${ROOTFS_PATH}"
	done
}

prepare_host()
{
	if ! hash apt-get 2>/dev/null; then
		build_error "This scripts requires a Debian based distrbution."
	fi
	
	build_info "Adding foreign architecture arm64 (aarch64) into Your system."
	dpkg --add-architecture arm64 || build_error "Failed to add foreign architecture arm64 into Your system. Check error(s) message(s) and try again."
	
	build_info "Retrieving/updating packages information."
	apt-get -y update
	
	build_info "Installing/updating necessary packages."
	apt-get -y --no-install-recommends --fix-missing install \
		        tar mtools u-boot-tools pv bc git sed gawk coreutils \
		        gcc automake make curl binfmt-support flex whiptail \
		        lib32z1 lib32z1-dev qemu-user-static bison \
		        figlet dosfstools libncurses5-dev debootstrap \
		        swig libpython2.7-dev libssl-dev python2-minimal \
		        dos2unix libc6:arm64 libssl-dev build-essential \
		        libncurses-dev bison flex libssl-dev libelf-dev \
		        libssl-dev:arm64 libssl3:arm64 python-dev libxml2-dev \
		        libxslt-dev libpython3.11-dev:arm64 device-tree-compiler \
		        mkbootimg libunwind8 libunwind8:arm64 libc6-dev libc6-dev:arm64 \
		        libgcc-12-dev-arm64-cross debootstrap qemu-user-static rsync \
		        || build_error "Failed to install required packages. Check error(s) message(s) and try again."
	
	build_info "Installing optional package(s)."
	apt-get -y --no-install-recommends --fix-missing install cowsay || true

	if [ ! -d "${BUILD}" ]; then
		mkdir -p "${BUILD}"
	fi
	prepare_toolchains
	build_info "Host is prepared."
}

prepare_toolchains()
{
	TOOLCHAIN_BRANCH="aarch64-linux-gnu-6.3"
	if [ ! -d "$ROOT/toolchain" ]; then
		build_info "Cloning orangepi toolchain"
		FAIL=''
		git clone --depth=1 https://github.com/orangepi-xunlong/toolchain.git -b $TOOLCHAIN_BRANCH || FAIL='1'
		if [ $FAIL ] ; then
			# Something failed, so remove it for next try
			[ -d "$ROOT/toolchain" ] || rm -r "$ROOT/toolchain" || build_warning "Failed to delete directory $ROOT/toolchain"
			build_error "Failed to clone toolchain repository."
		fi
	fi
	chmod 755 -R $ROOT/toolchain/*
}

prepare_kernel()
{
	build_info "Preparing sources of a Linux kernel ..."
	if [ ! -d "$LINUX" ]; then
		FAIL=''
		git clone https://github.com/norbertkiszka/rigol-orangerigol-linux_4.4.179.git "$LINUX" || FAIL='1'
		if [ $FAIL ] ; then
			# Something failed, so remove it for next try
			[ -d "$LINUX" ] || rm -r "$LINUX" || build_warning "Failed to delete directory $LINUX"
			build_error "Failed to clone Linux kernel repository."
		fi
	else
		cd "$LINUX"
		git pull || build_warning "Failed to update Linux kernel sources"
		cd -
	fi
	build_info "Sources of a Linux kernel are prepared."
}

prepare_uboot_rkbin()
{
	if [ ! -d "$EXTER_ORANGEPI" ]; then
		build_info "Preparing rkbin for a U-Boot bootloader ..."
		FAIL=''
		git clone https://github.com/orangepi-xunlong/OrangePiRK3399_external.git -b orangepi-rk3399_v1.4 --depth 1 "$EXTER_ORANGEPI" || FAIL='1'
		if [ $FAIL ] ; then
			# Something failed, so remove it for next try
			[ -d "$EXTER_ORANGEPI" ] || rm -r "$EXTER_ORANGEPI" || build_warning "Failed to delete directory $EXTER_ORANGEPI"
			build_error "Failed to clone U-Boot repository."
		fi
		build_info "rkbin is ready."
	fi
}

prepare_uboot()
{
	build_info "Preparing sources of a U-Boot bootloader ..."
	if [ ! -d "$UBOOT" ]; then
		FAIL=''
		git clone https://github.com/norbertkiszka/rigol-orangerigol-uboot_2017.09_light.git "$UBOOT" || FAIL='1'
		if [ $FAIL ] ; then
			# Something failed, so remove it for next try
			[ -d "$LINUX" ] || rm -r "$UBOOT" || build_warning "Failed to delete directory $UBOOT"
			build_error "Failed to clone U-Boot repository."
		fi
	else
		cd "$UBOOT"
		git pull || build_warning "Failed to update U-Boot bootloader sources"
		cd -
	fi
	
	build_info "Sources of a U-Boot bootloader are prepared."
	
	prepare_uboot_rkbin
}

kernel_update()
{
	build_info "Updating Linux kernel image in $SDCARD_PATH ..."
	pv $BUILD/kernel/boot.img  | dd of=$SDCARD_PATH seek=49152 conv=notrunc
	sync
}

modules_update()
{
	build_info "Updating Linux kernel modules in $SDCARD_PATH ..."
	
	# Remove old modules
	rm -rf $ROOTFS_PATH/lib/modules
	
	cp -rfa $BUILD/lib/modules $ROOTFS_PATH/lib/
	sync
}

uboot_update()
{
	build_info "Updating U-Boot bootloader in $SDCARD_PATH ..."
	dd if=$BUILD/uboot/idbloader.img of=$SDCARD_PATH seek=64
	dd if=$BUILD/uboot/uboot.img of=$SDCARD_PATH seek=24576
	dd if=$BUILD/uboot/trust.img of=$SDCARD_PATH seek=32768
	sync
}

select_distro()
{
	build_info "Asking for a build type ..."
	TYPE=$(whiptail --title "Orange Rigol Build System" \
	--menu "Please chose build type" 20 60 3 --cancel-button Exit --ok-button Select \
		"0"   "Desktop with oscilloscope app" \
		"1"   "Desktop" \
		"2"   "Server (no gui, only text console)" \
	3>&1 1>&2 2>&3)

	case "${TYPE}" in
		"0")
			#IMAGETYPE="desktop-oscilloscope"
			IMAGETYPE="desktop"
			build_info "Selected option: Desktop with oscilloscope app"
			whiptail --title "Orange Rigol Build System" --msgbox "Oscilloscope app is not ported yet!!! Only desktop will be installed." 10 40 0
			;;
		"1")
			build_info "Selected option: Desktop"
			IMAGETYPE="desktop" ;;
		"2")
			build_info "Selected option: Server"
			IMAGETYPE="server" ;;
		"*") 
		;;
	esac
}

chose_username()
{
	# Dont ask for username 5000 times
	[ "${CHOSEN_USERNAME}" == "" ] || return
	if [ -e $DEST/etc/orangerigol/buildstage ] && [ "$(cat $DEST/etc/orangerigol/buildstage | grep "user_setup")" != "" ] ; then
		build_info "Stage user_setup already done. Dont asking for username again."
		return
	fi
	
	build_info "Asking for a username ..."
	CHOSEN_USERNAME=$(whiptail --title "Orange Rigol Build System" \
		--inputbox "Please input Your desired (short) username.\n\nIt will be also Your password, which You can change it later.\n\nLeave it empty for no user (root only)." \
		10 80 "rigol" 3>&1 1>&2 2>&3)
	if [ "${CHOSEN_USERNAME}" == "" ] ; then
		build_info "Chosen username is null. No user will be added."
	else
		build_info "Chosen username is ${CHOSEN_USERNAME}."
	fi
}

chose_username_for_additional_user()
{
	build_info "Asking for a additional username ..."
	CHOSEN_USERNAME=$(whiptail --title "Orange Rigol Build System" \
		--inputbox "Please input Your desired (short) username.\n\nIt will be also Your password, which You can change it later.\n\nLeave it empty to exit." \
		10 80 "" 3>&1 1>&2 2>&3)
	if [ "${CHOSEN_USERNAME}" == "" ] ; then
		build_info "No username provided. No user will be added."
	else
		build_info "Chosen username is ${CHOSEN_USERNAME}."
	fi
}

# We shouldnt ask user for what is (should be?) inside rootfs, because we can check it now.
extract_imagetype_from_rootfs()
{
	build_info "Extracting imagetype from rootfs"
	[ -e "${DEST}/etc/orangerigol/buildstage" ] || build_error "Cannot happen. File ${DEST}/etc/orangerigol/buildstage doesnt exist. Please remove directory '${DEST}' and try again."
	IMAGETYPE="server"
	[ "$(cat "${DEST}/etc/orangerigol/buildstage" | grep "desktop")" == "" ] || IMAGETYPE="desktop"
}

confirm_flash()
{
	if ! whiptail --title "Orange Rigol Build System" --yesno "This will overwrite contents on a SD card located at ${SDCARD_PATH}.\n\nContinue?" 10 80 ; then
		build_notice "User declined from flashing SD card."
		exit 0
	fi
}

check_before_flash()
{
	MOUNT_POINTS="$(mount | grep "${SDCARD_PATH}" | awk '{print $1}')"
	if [ "$MOUNT_POINTS" == "" ] ; then
		return
	fi
	
	if ! whiptail --title "Orange Rigol Build System" --yesno "SD card is mounted via point(s): ${MOUNT_POINTS}.\n\nTo flash it, we need to unmount it first.\n\nUmount and continue?" 12 80 ; then
		build_notice "User declined to umount SD card before flashing. SD card is untouch."
		exit 0
	fi
	
	build_notice "Unmounting SD card point(s): $MOUNT_POINTS"
	umount $MOUNT_POINTS
	build_info "SD card unmounted."
}

pack_error()
{
	echo -e "\033[47;31mERROR: $*\033[0m"
}

pack_warn()
{
	echo -e "\033[47;34mWARN: $*\033[0m"
}

pack_info()
{
	echo -e "\033[47;30mINFO: $*\033[0m"
}

build_info()
{
	echo -e "\e[1;32m INFO: ${*} \e[0m"
}

build_notice()
{
	echo -e "\033[0;33m NOTICE: ${*} \033[0m"
}

build_warning()
{
	echo -e "\e[1;31m WARNING: ${*} \e[0m"
	
# 	for i in {15..01}
# 	do
# 		echo -ne "\rContinue in $i seconds..."
# 		sleep 1
# 	done
# 	echo ""
	PREVIOUS_NEWT_COLORS=$NEWT_COLORS
	export NEWT_COLORS='
border=red,
'
	whiptail --title "Orange Rigol Build System [WARNING]" --msgbox "WARNING: ${*}" --ok-button "Continue" 15 80 0
	NEWT_COLORS=$PREVIOUS_NEWT_COLORS
}

build_error()
{
	echo -e "\e[1;31m ERROR: ${*} \e[0m"
	PREVIOUS_NEWT_COLORS=$NEWT_COLORS
	export NEWT_COLORS='
window=,red
border=white,red
textbox=white,red
button=black,white
'
	whiptail --title "Orange Rigol Build System" --msgbox "${*}" --ok-button "Exit" 15 80 0
	NEWT_COLORS=$PREVIOUS_NEWT_COLORS
	exit 1
}

build_success_text_only()
{
	echo -e "\e[1;32m SUCCESS: ${*} \e[0m"
}

build_success()
{
	build_success_text_only ${*}
	PREVIOUS_NEWT_COLORS=$NEWT_COLORS
	export NEWT_COLORS='
window=,green
border=white,green
textbox=white,green
button=black,white
'
	whiptail --title "Orange Rigol Build System" --msgbox "${*}" --ok-button "OK" 15 80 0
	NEWT_COLORS=$PREVIOUS_NEWT_COLORS
	#exit 0
}
