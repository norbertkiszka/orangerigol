#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

# TODO: backup from (main?) menu

select_image()
{
	if [ "$DIFFICULTY" == "expert" ] ; then
		#IMAGES=($BUILD/images/*.img)
		IMAGES=($(ls -t $BUILD/images/*.img))
	else
		IMAGES=($(ls -t $BUILD/images/*.img | grep "_${BOARD}_"))
	fi
	
	if [ ${#IMAGES[@]} -lt 1 ] ; then # Cannot happen since flash option in main menu should be unavailable.
		build_error "${FUNCNAME} no images in ${BUILD}/images/"
	fi
	
	for key in "${!IMAGES[@]}" ; do
		IMAGES[$key]=$(basename ${IMAGES[$key]})
	done
	
	if [ ${#IMAGES[@]} -eq 1 ] ; then
		SELECTED_IMAGE=${IMAGES[@]}
		build_info "Only one image (${SELECTED_IMAGE}), so selecting it."
		return
	fi
	
	build_info "Found ${#IMAGES[@]} images."
	
	for key in "${!IMAGES[@]}" ; do
		whiptail_menu_options_add "$key" "${IMAGES[$key]}"
	done
	
	MENUSTR="Please select image to flash into SD card."
	[ "$DIFFICULTY" == "expert" ] || MENUSTR+="\n\nIf not sure, select first (press enter)." # Since files are sorted by time and we filtered other devices, first option should be most appropriate.
	whiptail_menu_execute "Flash menu" "$MENUSTR"
	
	SELECTED_IMAGE="${WHIPTAIL_MENU_OPTION_NAME}"
	
	build_info "Selected image to flash: $SELECTED_IMAGE"
}

flash_image()
{
	local partition
	build_info "Flashing ${SDCARD_PATH} using ${SELECTED_IMAGE} ..."
	IMAGE_SIZE=$(wc -c < "${BUILD}/images/${SELECTED_IMAGE}")
	if [ "$IMAGE_SIZE" -lt 376832 ] ; then
		build_error "${BUILD}/images/${SELECTED_IMAGE} doestn look like a proper image..."
	fi
	# not a dev null && big enough
	local is_dev_null=""
	if [ "$(stat -Lc %t:%T ${SDCARD_PATH})" == "1:3" ] ; then
		is_dev_null="y"
		notice "Null device as a sd card"
	fi
	if [ "$is_dev_null" == "" ] && [ "$IMAGE_SIZE" -gt "$(blockdev --getsize64 "${SDCARD_PATH}")" ] ; then
		build_error "${SELECTED_IMAGE} is bigger than SD card size..."
	fi
	pv "${BUILD}/images/${SELECTED_IMAGE}" | dd of="${SDCARD_PATH}"
	build_info "SD card is flashed"
	if [ "$is_dev_null" != "" ] ; then
		notice "Ommiting resizing since its a /dev/null"
		return
	fi
	# TODO: compare flashed contents with image file with user choice
	build_info "Forcing host kernel to probe partition table in ${SDCARD_PATH}"
	partprobe "$SDCARD_PATH" 2> /dev/null
	sleep 3 # partprobe takes some time. 3 seconds should be more than enough for most systems
	partition="/dev/$(sys_get_last_partition_name "${SDCARD_PATH}")"
	build_info "Checking filesystem in ${partition}"
	fsck.ext4 -fy "${partition}"
	build_info "Resizing ${SDCARD_PATH} partition table to fulfill whole SD card"
	sgdisk "${SDCARD_PATH}" -e
	build_info "Forcing host kernel to probe partition table in ${SDCARD_PATH} again"
	partprobe "$SDCARD_PATH" 2> /dev/null
	sleep 3
	build_info "Resizing ${partition} to fulfill whole empty space"
	echo "- +" | sfdisk -N $(sys_get_last_partition_num "${SDCARD_PATH}") "${SDCARD_PATH}"
	sleep 1
	build_info "Forcing host kernel to probe partition table in ${SDCARD_PATH} again"
	partprobe "$SDCARD_PATH" 2> /dev/null
	sleep 3
	build_info "Resizing ${partition} filesystem to fulfill whole partition"
	resize2fs -p "${partition}"
	partprobe "$SDCARD_PATH" 2> /dev/null # just to be safe
	sleep 3
	build_info "Checking filesystem in ${partition} again"
	fsck.ext4 -fy "${partition}"
	build_info "SD card is ready to use."
}
