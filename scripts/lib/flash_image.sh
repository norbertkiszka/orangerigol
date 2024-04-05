#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

select_image()
{
	if [ "$DIFFICULTY" == "expert" ] ; then
		#IMAGES=($BUILD/images/*.img)
		IMAGES=($(ls -t $BUILD/images/*.img))
	else
		IMAGES=($(ls -t $BUILD/images/*.img | grep "_${BOARD}_"))
	fi
	
	if [ ${#IMAGES[@]} -lt 1 ] ; then # Cannot happen since flash option in main menu should be unavailable.
		build_error "select_image() no images in ${BUILD}/images/"
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
	
	unset OPTIONS
	OPTIONS=""
	for key in "${!IMAGES[@]}" ; do
		OPTIONS="${OPTIONS} $key ${IMAGES[$key]}"
	done
	
	MENUSTR="Please select image to flash into SD card."
	[ "$DIFFICULTY" == "expert" ] || MENUSTR+="\n\nIf not sure, select first (press enter)." # Since files are sorted by time and we filtered other devices, first option should be most appropriate.
	
	whiptail_menu_options_reset
	for key in "${!IMAGES[@]}" ; do
		whiptail_menu_options_add "$key" "${IMAGES[$key]}"
	done
	
	OPTION=$(whiptail_menu_execute "Orange Rigol Build System | Flash menu" "Please select build option")
	
	if [ "$OPTION" == "" ] ; then
		build_notice "User exit from flash menu"
		exit 1
	fi
	
	SELECTED_IMAGE=${IMAGES[$OPTION]}
	
	build_info "Selected image to flash: $SELECTED_IMAGE"
}

flash_image()
{
	build_info "Flashing ${SDCARD_PATH} with ${SELECTED_IMAGE} ..."
	IMAGE_SIZE=$(wc -c < "${BUILD}/images/${SELECTED_IMAGE}")
	if [ "$IMAGE_SIZE" -lt 376832 ] ; then
		build_error "${BUILD}/images/${SELECTED_IMAGE} doestn look like a proper image..."
	fi
	if [  "$IMAGE_SIZE" -gt "$(blockdev --getsize64 "${SDCARD_PATH}")" ] ; then
		build_error "${SELECTED_IMAGE} is bigger than SD card size..."
	fi
	pv "${BUILD}/images/${SELECTED_IMAGE}" | dd of="${SDCARD_PATH}"
	# TODO: compare flashed contents with image file with user choice
	build_info "SD card is flashed"
	build_info "Forcing host kernel to probe partition table in ${SDCARD_PATH}"
	partprobe "$SDCARD_PATH" 2> /dev/null
	sleep 3 # partprobe takes some time. 3 seconds should be more than enough for most systems
	build_info "Checking filesystem in ${SDCARD_PATH}p4"
	fsck.ext4 -fy /dev/mmcblk0p4
	build_info "Resizing ${SDCARD_PATH} partition table to fulfill whole SD card"
	sgdisk "${SDCARD_PATH}" -e
	build_info "Forcing host kernel to probe partition table in ${SDCARD_PATH} again"
	partprobe "$SDCARD_PATH" 2> /dev/null
	sleep 3
	build_info "Resizing ${SDCARD_PATH}p4 partition to fulfill whole empty space"
	echo "- +" | sfdisk -N 4 "${SDCARD_PATH}"
	sleep 1
	build_info "Forcing host kernel to probe partition table in ${SDCARD_PATH} again"
	partprobe "$SDCARD_PATH" 2> /dev/null
	sleep 3
	build_info "Resizing ${SDCARD_PATH}p4 filesystem to fulfill whole partition"
	resize2fs -p "${SDCARD_PATH}p4"
	build_info "Checking filesystem in ${SDCARD_PATH}p4 again"
	fsck.ext4 -fy "${SDCARD_PATH}p4"
	build_info "SD card is ready to use."
}
