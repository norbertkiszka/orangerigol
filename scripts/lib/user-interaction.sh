#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

__USER_INTERACTION_MAIN_MENU_PREVIOUS_ITEM=""

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

select_distro()
{
	build_info "Asking for a build type ..."
	
	[ "$DEVICE_CATEGORY" == "Rigol DHO800/900" ] && whiptail_menu_option_add "" "Desktop with oscilloscope app"
	whiptail_menu_option_add "" "Desktop"
	whiptail_menu_option_add "" "Server (no gui, only text console)"
	
	whiptail_menu_execute "Build type menu" "Please select build option"
	
	case "${WHIPTAIL_MENU_OPTION_NAME}" in
		*oscilloscope*)
			IMAGETYPE="desktop-oscilloscope"
			whiptail --title "Orange Rigol Build System" --msgbox "Oscilloscope app is not ported yet!!! Only desktop will be installed." 10 40 0
			;;
		*Desktop*)
			IMAGETYPE="desktop" ;;
		*Server*)
			IMAGETYPE="server" ;;
		*)
			build_error "Oopsie"
		;;
	esac
	
	DISTRO="bookworm"
}

startup_selections()
{
	select_device_category
	select_board
	select_distro
}

select_device_category()
{
	build_info "Asking for a device category ..."
	
	whiptail_menu_dont_add_dot_in_key
	
	whiptail_menu_option_add "Rigol DHO800/900" ""
	whiptail_menu_option_add "PC AMD64" ""
	whiptail_menu_option_add "PC i686" ""
	whiptail_menu_execute "Device category menu" "Please choose Your device category:" 15 50 5
	DEVICE_CATEGORY="$WHIPTAIL_MENU_OPTION_ID"
}

select_board()
{
	case "${DEVICE_CATEGORY}" in 
		"Rigol DHO800/900")
			CPU="RK3399"
			ARCH="arm64"
			# We need very old gcc for compatilibity with old U-Boot, old kernel and Rigol software
			TOOLS=$ROOT/toolchain/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-
			export CC="${TOOLS}gcc -I/usr/include/aarch64-linux-gnu -I/usr/include"
			export PATH="${ROOT}/toolchain/gcc-linaro-6.3.1-2017.05-x86_64_aarch64-linux-gnu/bin:${PATH}"
			select_board_rigol
			OUTPUT_DEVICE_NAME_FOR_HUMAN="SD card"
			;;
		"PC AMD64")
			BOARD="PC-AMD64"
			ARCH="amd64"
			OUTPUT_DEVICE_NAME_FOR_HUMAN="disk"
			;;
		"PC i686")
			BOARD="PC-x86"
			ARCH="i386"
			OUTPUT_DEVICE_NAME_FOR_HUMAN="disk"
			;;
	esac
}

select_board_rigol()
{
	build_info "Asking for a Rigol device ..."
	whiptail_menu_dont_add_dot_in_key
	whiptail_menu_option_add "DHO924S" ""
	whiptail_menu_option_add "DHO924" ""
	whiptail_menu_option_add "DHO914S" ""
	whiptail_menu_option_add "DHO814" ""
	whiptail_menu_option_add "DHO812" ""
	whiptail_menu_option_add "DHO804" ""
	whiptail_menu_option_add "DHO802" ""
	whiptail_menu_execute "Device menu" "Please choose Your Rigol device:" 20 60 10
	BOARD="$WHIPTAIL_MENU_OPTION_ID"
	build_info "Selected board: ${BOARD}"
	[ "${BOARD}" != "" ] || build_error "\$BOARD cant be empty..."
}

main_menu()
{
	whiptail_menu_option_add "1" "Build Release image (${OUTPUT_DEVICE_NAME_FOR_HUMAN} image)"
	if [ "$DIFFICULTY" == "expert" ] ; then
		whiptail_menu_option_add "2" "Build Rootfs only"
		[ "${BOOTLOADER}" != "grub" ] && whiptail_menu_option_add "3" "Compile ${BOOTLOADER} bootloader"
		if [ "$KERNEL_METHOD" == "compile" ] ; then
			whiptail_menu_option_add "4" "Compile Linux kernel with modules"
			whiptail_menu_option_add "5" "Compile Linux kernel modules only"
			[ ! -e "$BUILD/kernel/boot.img" ] || whiptail_menu_option_add "6" "Update Linux kernel image on a ${OUTPUT_DEVICE_NAME_FOR_HUMAN}"
			[ ! -d "$BUILD/lib/modules" ] || [ "$(ls $BUILD/lib/modules 2> /dev/null)" == "" ] || whiptail_menu_option_add "7" "Update Linux kernel modules on a ${OUTPUT_DEVICE_NAME_FOR_HUMAN}"
		fi
		if [ "$BOOTLOADER" == "uboot" ] ; then
			[ ! -e "$BUILD/uboot/idbloader.img" ] || [ ! -e "$BUILD/uboot/uboot.img" ] || [ ! -e "$BUILD/uboot/trust.img" ] \
			|| whiptail_menu_option_add "8" "Update Uboot bootloader on a ${OUTPUT_DEVICE_NAME_FOR_HUMAN}"
		fi
	fi
	
	[ "${BUILD_GIT_SHORT}" == "" ] || whiptail_menu_option_add "9" "Update this app (via git pull)"

	if [ "$DIFFICULTY" == "expert" ] && [ -e $DEST/etc/orangerigol/buildstage ] && [ "$(cat $DEST/etc/orangerigol/buildstage | grep "user_setup")" != "" ] ; then
		whiptail_menu_option_add "10" "Add additional user into existing rootfs"
	fi
	
	if [ "$DIFFICULTY" == "expert" ] ; then
		if [ -e "$DEST/bin/bash" ] && [ -e $DEST/etc/orangerigol/buildstage ] && [ "$(cat $DEST/etc/orangerigol/buildstage | grep "build_ready")" != "" ] ; then
			if [ "$BOOTLOADER" == "uboot" ] ; then
				[ -e "$BUILD/uboot/idbloader.img" ] && \
				[ -e "$BUILD/uboot/uboot.img" ] && \
				[ -e "$BUILD/uboot/trust.img" ] && \
				[ -e "$BUILD/kernel/boot.img" ] && \
					whiptail_menu_option_add "11" "Build image from a current files"
			else
				whiptail_menu_option_add "11" "Build image from a current files"
			fi
		fi
	fi
	
	if [ "$DIFFICULTY" == "expert" ] && [ -e "$DEST/etc/orangerigol/buildstage" ] && [ "$(cat "$DEST/etc/orangerigol/buildstage" | grep "overlays_preinstall")" != "" ] ; then
		whiptail_menu_option_add "12" "Manually add overlay"
	fi

	if [ "$DIFFICULTY" == "expert" ] && [ -e "$DEST/bin/bash" ] && [ -e "$DEST/usr/bin/bash" ] ; then
		whiptail_menu_option_add "13" "Chroot into rootfs"
	fi

	# NOTE: Flash option should be always as a last one
	OPTION_ID_FLASH_IMAGE="15"
	if [ "$DIFFICULTY" == "expert" ] ; then
		if [ "$(ls $BUILD/images/*.img 2> /dev/null)" != "" ] ; then
			if [ "$(uname -m)" == "x86_64" ] && modprobe kvm 2> /dev/null && which kvm > /dev/null && [[ "${ARCH}" == "amd64" || "${ARCH}" == "i386" ]] ; then
				whiptail_menu_option_add "14" "Run VM on image"
			fi
			whiptail_menu_option_add "$OPTION_ID_FLASH_IMAGE" "Flash image on a ${OUTPUT_DEVICE_NAME_FOR_HUMAN}"
		fi
	else
		[ "$(ls $BUILD/images/*.img 2> /dev/null | grep "_${BOARD}_")" != "" ] && whiptail_menu_option_add "$OPTION_ID_FLASH_IMAGE" "Flash (write) image on a ${OUTPUT_DEVICE_NAME_FOR_HUMAN}"
	fi

	if [ "$DIFFICULTY" == "expert" ] && [ "${__USER_INTERACTION_MAIN_MENU_PREVIOUS_ITEM}" != "" ] ; then
		whiptail_menu_set_default_item "${__USER_INTERACTION_MAIN_MENU_PREVIOUS_ITEM}"
	elif [ "${__USER_INTERACTION_MAIN_MENU_PREVIOUS_ITEM}" == "1" ] ; then
		whiptail_menu_set_default_item "${OPTION_ID_FLASH_IMAGE}"
	fi
	
	whiptail_menu_execute "Main menu" "Please select build option"
	__USER_INTERACTION_MAIN_MENU_PREVIOUS_ITEM=$WHIPTAIL_MENU_OPTION_ID
	
	local default_flash_device=""
	[ "${OUTPUT_DEVICE_NAME_FOR_HUMAN}" == "SD card" ] && default_flash_device="mmcblk0"
	case "${WHIPTAIL_MENU_OPTION_ID}" in 
		"1")
			chose_username
			[ "${BOOTLOADER}" != "grub" ] && compile_bootloader
			[ "$KERNEL_METHOD" == "compile" ] && compile_kernel
			build_rootfs
			build_image
			build_success "Succeed to build release image in a file:\n\n${IMAGE}"
			;;
		"2")
			chose_username
			[ "${BOOTLOADER}" != "grub" ] && compile_bootloader
			[ "$KERNEL_METHOD" == "compile" ] && compile_kernel
			build_rootfs
			build_success "Succeed to build rootfs."
			;;
		"3")
			compile_bootloader
			build_success "Succeed to compile bootloader."
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
			select_disk_device "Select device to update kernel" "Input device path to update kernel" "${default_flash_device}" || return
			check_before_flash || return
			confirm_flash || return
			kernel_update
			build_success "Succeed to update kernel in:\n${INPUT_PATH}."
			;;
		"7")
			rootfs_check
			modules_update
			build_success "Succeed to update Linux kernel modules in:\n${ROOTFS_PATH}."
			;;
		"8")
			select_disk_device "Select device to update bootloader" "Input device path to update bootloader" "${default_flash_device}" || return
			check_before_flash || return
			confirm_flash || return
			uboot_update
			build_success "Succeed to update U-Boot bootloader in ${INPUT_PATH}."
			;;
		"9")
			pull
			if [ "$(echo $BUILD_GIT_SHORT | grep -F `git_last_commit_hash_short`)" ] ; then
				build_success "Current version is already latest"
			else
				build_success "Build was updated. Old hash: ${BUILD_GIT_SHORT}. New hash: $(git_last_commit_hash_short)."
				set +e
				set +a
				export -n LIB_BASH_VERSION
				$0 $*
				exit $?
			fi
			;;
		"10")
			add_overlays_always
			chose_username_for_additional_user
			add_user "${CHOSEN_USERNAME}"
			build_success "User ${CHOSEN_USERNAME} was added into system in rootfs."
			;;
		"11")
			#extract_imagetype_from_rootfs
			build_image
			build_success "Image on current files was build in ${IMAGE}."
			;;
		"12")
			select_overlay_to_manuall_add
			add_overlay "${CHOSEN_OVERLAY}"
			build_success "Overlay ${CHOSEN_OVERLAY} was added"
			;;
		"13")
			add_overlays_always
			build_info "Press CTRL+D or type exit[enter] to exit." # Sometimes users are very good random number generators.
			build_chroot "${DEST}" /bin/bash
			build_info "Back in build script..."
			;;
		"14")
			select_image "Please select image to run virtual machine."
			kvm -drive format=raw,file="${BUILD}/images/${SELECTED_IMAGE}" -serial stdio -m 4G -cpu host -smp 2
			;;
		"15")
			local menustr="Please select image to flash into SD card."
			[ "$DIFFICULTY" == "expert" ] || menustr+="\n\nIf not sure, select first (press enter)." # Since files are sorted by time and we filtered other devices, first option should be most appropriate.
			select_image "${menustr}"
			select_disk_device "Select device to flash image" "Input file path to flash image into" "${default_flash_device}"
			check_before_flash || return
			confirm_flash || return
			flash_image
			build_success "Succeed to flash image."
			;;
		"*")
			whiptail --title "Orange Rigol Build System" \
			--msgbox "Please select correct option" 10 50 0
			;;
	esac
}

chose_username()
{
	# Dont ask for username 5000 times
	[ "${CHOSEN_USERNAME}" == "" ] || return
	if [ -e $DEST/etc/orangerigol/buildstage ] && [ "$(cat $DEST/etc/orangerigol/buildstage | grep "user_setup")" != "" ] ; then
		build_info "Stage user_setup already done. Not asking for username again."
		return
	fi
	
	build_info "Asking for a username ..."
	CHOSEN_USERNAME=$(whiptail --title "Orange Rigol Build System" \
		--inputbox "Please input Your desired (short) username.\n\nIt will be also Your password, which You can change it later.\n\nLeave it empty for no user (root only)." \
		10 80 "rigol" 3>&1 1>&2 2>&3)
	if [ "${CHOSEN_USERNAME}" == "" ] ; then
		build_info "Chosen username is: null. No user will be added."
	else
		build_info "Chosen username is: ${CHOSEN_USERNAME}"
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

confirm_flash()
{
	if ! whiptail --title "Orange Rigol Build System" --yesno "This will overwrite contents on a ${OUTPUT_DEVICE_NAME_FOR_HUMAN} located at ${INPUT_PATH}.\n\nContinue?" 10 80 ; then
		build_notice "User declined from flashing"
		return 1
	fi
	return 0
}

check_before_flash()
{
	MOUNT_POINTS="$(mount | grep "${INPUT_PATH}" | awk '{print $1}')"
	if [ "$MOUNT_POINTS" == "" ] ; then
		return 0
	fi
	
	if ! whiptail --title "Orange Rigol Build System" --yesno "Device is mounted via point(s): ${MOUNT_POINTS}.\n\nTo flash it, we need to unmount it first.\n\nUmount and continue?" 12 80 ; then
		build_notice "User declined to umount device before flashing. Device is untouch."
		return 1
	fi
	
	build_notice "Unmounting disk point(s): $MOUNT_POINTS"
	umount $MOUNT_POINTS
	build_info "Disk partitions unmounted"
	return 0
}

select_overlay_to_manuall_add()
{
	OVERLAYS_NAMES=($(ls $OVERLAYS/))
	if [ ${#OVERLAYS_NAMES[@]} -lt 1 ] ; then # Cannot happen since add overlay option in main menu should be unavailable.
		build_error "${FUNCNAME} no overlays in $OVERLAYS/"
	fi
	build_info "Found ${#OVERLAYS_NAMES[@]} overlays"

	whiptail_menu_dont_add_dot_in_key

	for name in "${OVERLAYS_NAMES[@]}"
	do
  		whiptail_menu_option_add "${name}" ""
	done

	whiptail_menu_execute "Overlay menu" "Please select overlay to manuall add:"
	CHOSEN_OVERLAY=$WHIPTAIL_MENU_OPTION_ID
}

# Arg1: menu text
# Arg2: manual input text
# Arg3: default device
select_disk_device()
{
	local lsblk
	local lsblk2
	local type
	local name
	local size
	local root_device=$(sys_get_root_device_name)
	local old_ifs="$IFS"
	local menu_text="${1}"
	local manually_input_text="${2}"
	local defaul_device
	local menu_input_manually_text="input manually"
	
	[ "${menu_text}" == "" ] && menu_text="Please select device"
	
	while true
	do
		IFS=$'\n'
		lsblk=($(lsblk -d -o NAME,TYPE,SIZE | tail -n +2))
		
		# Make sure real disks are first
		lsblk2=()
		for line in ${lsblk[@]}
		do
			type=$(echo "${line}" | awk '{print $2}')
			[ "$type" == "disk" ] && lsblk2+=($line)
		done
		for line in ${lsblk[@]}
		do
			type=$(echo "${line}" | awk '{print $2}')
			[ "$type" != "disk" ] && lsblk2+=($line)
		done
		
		for line in ${lsblk2[@]}
		do
			name=$(echo "${line}" | awk '{print $1}')
			type=$(echo "${line}" | awk '{print $2}')
			size=$(echo "${line}" | awk '{print $3}')
			
			[ "$name" != "$root_device" ] && whiptail_menu_option_add "${name}" "${type}  ${size}"
			if [ "${3}" == "$name" ] ; then
				defaul_device="$name"
				whiptail_menu_set_default_item "$defaul_device"
			fi
		done
		IFS="$old_ifs"
		
		#whiptail_menu_option_add "${menu_input_manually_text}" ""
		
		whiptail_menu_dont_add_dot_in_key
		whiptail_menu_execute "Device selection" "${menu_text}"
		INPUT_PATH="${WHIPTAIL_MENU_OPTION_ID}"
		
		if [ "${INPUT_PATH}" == "${menu_input_manually_text}" ] ; then
			if ! input_path "${manually_input_text}" "${defaul_device}" ; then
				continue
			fi
		else
			INPUT_PATH="$(sys_get_udev_path)/${INPUT_PATH}"
		fi
		
		break
	done

}

# Arg1: inputbox text
# Arg2: default value
input_path()
{
	local inputbox_text
	
	if [ "${1}" == "" ] ; then
		inputbox_text="Please input path"
	else
		inputbox_text="${1}"
	fi
	
	local PREVIOUS_INPUT="${2}"
	for ((i = 0; i < 10; i++))
	do
		INPUT_PATH=$(whiptail --title "Orange Rigol Build System" \
		--cancel-button Back --ok-button OK \
		--inputbox "${inputbox_text}" \
		10 80 "${PREVIOUS_INPUT}" 3>&1 1>&2 2>&3) || return 1
		
		if [ -a "$INPUT_PATH" ]; then
			return 0
		elif [ $i == "8" ]; then
			local message="Given file path does not exist: ${INPUT_PATH}"
			notice "$message"
			whiptail_display_warning "$message"
			return 1
		else
			whiptail --title "Orange Rigol Build System" --msgbox \
			"The input path is invalid! Please input correct path!" \
			--ok-button Continue 10 40 0
		fi
		PREVIOUS_INPUT="${INPUT_PATH}"
	done
	return 1
}
