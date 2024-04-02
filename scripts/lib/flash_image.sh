#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

select_image()
{
	IMAGES=($BUILD/images/*.img)
	if [ ${#IMAGES[@]} -lt 1 ] ; then
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
	
	OPTION=$(whiptail --title "Orange Rigol Build System" --menu "Please select image to flash" 20 100 10 ${OPTIONS} 3>&1 1>&2 2>&3)
	
	SELECTED_IMAGE=${IMAGES[$OPTION]}
	
	build_info "Selected image to flash: $SELECTED_IMAGE"
}

flash_image()
{
	if ! whiptail --title "Orange Rigol Build System" --yesno "This will erase contents on a SD card located at ${SDCARD_PATH}.\n\nContinue?" 10 80 ; then
		build_notice "User resigned from flashing SD card."
		exit 0
	fi
	build_info "Flashing ${SDCARD_PATH} with ${SELECTED_IMAGE} ..."
	pv "${BUILD}/images/${SELECTED_IMAGE}" | dd of=$SDCARD_PATH
}
