#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

# Arg1: menu string
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
	
	whiptail_menu_execute "Image menu" "${1}"
	
	SELECTED_IMAGE="${WHIPTAIL_MENU_OPTION_NAME}"
	
	build_info "Selected image: $SELECTED_IMAGE"
}

flash_image()
{
	build_info "Flashing ${INPUT_PATH} using ${SELECTED_IMAGE} ..."
	
	local partition
	local is_dev_null
	local IMAGE_SIZE=$(wc -c < "${BUILD}/images/${SELECTED_IMAGE}")
	if [ "$IMAGE_SIZE" -lt 376832 ] ; then
		build_error "${BUILD}/images/${SELECTED_IMAGE} does not look like a proper image..."
	fi
	local is_dev_null=""
	if [ "$(stat -Lc %t:%T ${INPUT_PATH})" == "1:3" ] ; then
		is_dev_null="y"
		build_notice "Null device as a target device"
	fi
	# not a dev null && big enough
	if [ "$is_dev_null" == "" ] && [ "$IMAGE_SIZE" -gt "$(blockdev --getsize64 "${INPUT_PATH}")" ] ; then
		build_error "${SELECTED_IMAGE} is bigger than target ${OUTPUT_DEVICE_NAME_FOR_HUMAN} size..."
	fi
	pv "${BUILD}/images/${SELECTED_IMAGE}" | dd of="${INPUT_PATH}"
	sync
	build_info "${OUTPUT_DEVICE_NAME_FOR_HUMAN} is flashed"
	if [ "$is_dev_null" != "" ] ; then
		notice "Ommiting resizing since its a /dev/null"
		return
	fi
	# TODO: compare flashed contents with image file with user choice
	build_info "Forcing host kernel to probe partition table in ${INPUT_PATH}"
	partprobe "$INPUT_PATH" 2> /dev/null
	sleep 3 # partprobe takes some time. 3 seconds should be more than enough for most systems
	partition="$(sys_get_udev_path)/$(sys_get_last_partition_name "${INPUT_PATH}")"
	build_info "Checking filesystem in ${partition}"
	fsck.ext4 -fy "${partition}"
	build_info "Resizing ${INPUT_PATH} partition table to fulfill whole ${OUTPUT_DEVICE_NAME_FOR_HUMAN}"
	sgdisk "${INPUT_PATH}" -e
	build_info "Forcing host kernel to probe partition table in ${INPUT_PATH} again"
	partprobe "$INPUT_PATH" 2> /dev/null
	sleep 3
	build_info "Resizing ${partition} to fulfill whole empty space"
	echo "- +" | sfdisk -N $(sys_get_last_partition_num "${INPUT_PATH}") "${INPUT_PATH}"
	sleep 1
	build_info "Forcing host kernel to probe partition table in ${INPUT_PATH} again"
	partprobe "$INPUT_PATH" 2> /dev/null
	sleep 3
	build_info "Resizing ${partition} filesystem to fulfill whole partition"
	resize2fs -p "${partition}"
	partprobe "$INPUT_PATH" 2> /dev/null # just to be safe
	sleep 3
	build_info "Checking filesystem in ${partition} after resizing"
	fsck.ext4 -fy "${partition}"
	build_info "${OUTPUT_DEVICE_NAME_FOR_HUMAN} is ready to use."
}
