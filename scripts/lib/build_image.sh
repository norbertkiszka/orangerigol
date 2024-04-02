#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

build_image()
{
	build_info "Building image"
	VER="v0.1"
	IMAGENAME="OrangeRigol_${BOARD}_Debian_${DISTRO}_${IMAGETYPE}_${KERNEL_NAME}_${VER}"
	IMAGE="$BUILD/images/$IMAGENAME.img"

	if [ ! -d $BUILD/images ]; then
		mkdir -p $BUILD/images
	fi
	local UBOOT_START=24576
	local UBOOT_END=32767
	local TRUST_START=32768
	local TRUST_END=40959
	local BOOT_START=49152
	local BOOT_END=114687
	local ROOTFS_START=376832
	local LOADER1_START=64
	#local IMG_ROOTFS_SIZE=$(expr `du -s $DEST | awk 'END {print $1}'` + 400 \* 1024)
	local IMG_ROOTFS_SIZE=$(expr `du -s $DEST | awk 'END {print $1}'` + 800 \* 1024)
	local GPTIMG_MIN_SIZE=$(expr $IMG_ROOTFS_SIZE \* 1024 + \( $(((${ROOTFS_START}))) \) \* 512)
	local GPT_IMAGE_SIZE=$(expr $GPTIMG_MIN_SIZE \/ 1024 \/ 1024 + 2)

	build_info "Creating empty image ..."
	
	dd if=/dev/zero of=${IMAGE}2 bs=1M count=$(expr $IMG_ROOTFS_SIZE  \/ 1024 )
	
	build_info "Creating file system ..."
	
	ROOT_UUID="614e0000-0000-4b53-8000-1d28000054a9"
	build_info "ROOT_UUID: ${ROOT_UUID}"
	
	mkfs.ext4 -O ^metadata_csum -F -b 1024 -L rootfs -U ${ROOT_UUID} ${IMAGE}2
	
	if [ ! -d /tmp/tmp ]; then
		mkdir -p /tmp/tmp
	fi
	
	build_info "Copying rootfs files into created file system ..."

	mount -t ext4 ${IMAGE}2 /tmp/tmp
	# Add rootfs into Image
	cp -rfa $DEST/* /tmp/tmp

	umount /tmp/tmp

	if [ -d /tmp/tmp ]; then
		rm -rf /tmp/tmp
	fi

	build_info "Generate SD boot image : ${SDBOOTIMG} !"
	dd if=/dev/zero of=${IMAGE} bs=1M count=0 seek=$GPT_IMAGE_SIZE
	parted -s $IMAGE mklabel gpt
	parted -s $IMAGE unit s mkpart uboot ${UBOOT_START} ${UBOOT_END}
	parted -s $IMAGE unit s mkpart trust ${TRUST_START} ${TRUST_END}
	parted -s $IMAGE unit s mkpart boot ${BOOT_START} ${BOOT_END}
	parted -s $IMAGE -- unit s mkpart rootfs ${ROOTFS_START} -34s
	set +x
	
gdisk $IMAGE <<EOF
x
c
4
${ROOT_UUID}
w
y
EOF
	dd if=$BUILD/uboot/idbloader.img of=$IMAGE seek=$LOADER1_START conv=notrunc
	dd if=$BUILD/uboot/uboot.img of=$IMAGE seek=$UBOOT_START conv=notrunc,fsync
	dd if=$BUILD/uboot/trust.img of=$IMAGE seek=$TRUST_START conv=notrunc,fsync
	dd if=$BUILD/kernel/boot.img of=$IMAGE seek=$BOOT_START conv=notrunc,fsync
	dd if=${IMAGE}2 of=$IMAGE seek=$ROOTFS_START conv=notrunc,fsync
	rm -f ${IMAGE}2
	cd ${BUILD}/images/
	rm -f ${IMAGENAME}.tar.gz
	md5sum ${IMAGENAME}.img > ${IMAGENAME}.img.md5sum
	#tar czvf  ${IMAGENAME}.tar.gz $IMAGENAME.img*
	tar czvf  ${IMAGENAME}.tar.gz $IMAGENAME.img ${IMAGENAME}.img.md5sum
	rm -f *.md5sum

	sync
}
