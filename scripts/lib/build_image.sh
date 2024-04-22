#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

generate_image_filename()
{
	IMAGENAME="OrangeRigol-v${BUILD_VERSION_TEXT}"
	[ "${BUILD_GIT_SHORT}" == "" ] || IMAGENAME="${IMAGENAME}-${BUILD_GIT_SHORT}"
	IMAGENAME="${IMAGENAME}_${BOARD}_Debian_${DISTRO}"
	IMAGENAME="${IMAGENAME}_${IMAGETYPE}"
	[ "${KERNEL_METHOD}" == "compile" ] && IMAGENAME="${IMAGENAME}_${KERNEL_NAME}"
	IMAGE="$BUILD/images/$IMAGENAME.img"
	
	if [ ! -d $BUILD/images ] ; then
		mkdir -p $BUILD/images
	fi
}

build_image()
{
	build_info "Building image ..."
	generate_image_filename
	build_image_with_$BOOTLOADER
}

build_image_with_grub()
{
	compile_bootloader
#	if [ "$ARCH" == "i686" ] ; then
#		build_image_grub
#	else
		build_image_grub_efi
#	fi
}

build_image_grub_efi()
{
	local TEMP
	local IMG_ROOTFS_SIZE=$(expr `du -s $DEST | awk 'END {print $1}'` + 1500 \* 1024)
	local GPTIMG_MIN_SIZE=$(expr $IMG_ROOTFS_SIZE \* 1024 + 101 \* 1024)
	local GPT_IMAGE_SIZE=$(expr $GPTIMG_MIN_SIZE \/ 1024 \/ 1024 + 2)
	local offset
	local sectors
	local fs_size_sectors
	local fs_size_bytes
	
	TMPIMAGE="${IMAGE}_temp"
	
	truncate --size "${GPT_IMAGE_SIZE}"M "${TMPIMAGE}"
	
	build_info "Creating partitions ..."
	
	sgdisk --clear \
	--new 1::+1M --typecode=1:ef02 --change-name=1:'BIOS boot partition' \
	--new 2::+100M --typecode=2:ef00 --change-name=2:'EFI System' \
	--new 3::-0 --typecode=3:8300 --change-name=3:'rootfs' \
	"${TMPIMAGE}"
	
	offset=$(sys_partition_get_offset_in_bytes "${TMPIMAGE}" 3)
	sectors=$(sys_partition_get_size "${TMPIMAGE}" 3)
	fs_size_sectors=$((${sectors}/2-2))
	fs_size_bytes=$((fs_size_sectors*1024))
	build_info "Partition rootfs offset: ${offset} bytes"
	build_info "Partition rootfs size: ${sectors} sectors"
	build_info "FS rootfs size: ${fs_size_sectors} 1k sectors"
	build_info "FS rootfs size: ${fs_size_bytes} bytes"
	build_info "Creating file system ..."
	mkfs.ext4 -F -L "rootfs" -b 1024 -U "${ROOT_UUID}" "${TMPIMAGE}" "${fs_size_sectors}" -E offset=${offset}
	sync
	TEMP=$(sys_mktempdir)
	[ "${TEMP}" != "" ] || error oops # never be too shure
	sys_mount_tmp "${TMPIMAGE}" "${TEMP}" -o loop,offset=${offset},sizelimit=${fs_size_bytes}
	build_info "Copying rootfs files into created file system ..."
	build_info "Rootfs calculated dir size: $(du -hs "${DEST}" | awk '{print $1}')"
	# Copying files in fs mounted like that is somehow significantly faster than using loop to whole image.
	# Using sync mount option will make this increadible slow... somehow.
	sys_cpdir "${DEST}/" "${TEMP}/"
	sync
	sys_umount "${TEMP}"
	
	modprobe loop || true
	LOOPDEV=$(losetup --find --show "${TMPIMAGE}")
	build_info "Using loop device ${LOOPDEV}"
	partprobe ${LOOPDEV}
	sleep 3 # give kernel some time, otherwise we are screwed
	mkfs.fat -F32 ${LOOPDEV}p2
	partprobe ${LOOPDEV}
	sleep 3
	
	sys_mount_tmp ${LOOPDEV}p3 "${TEMP}"
	
	if [ ! -e "${TEMP}/usr/sbin/grub-install" ] && [ ! -e "${TEMP}/usr/local/sbin/grub-install" ] ; then
		build_info "Installing compiled GRUB executables"
		cd "${GRUB}"
		make DESTDIR="${TEMP}/" install
		cd - > /dev/null
	fi
	
	if [ "${KERNEL_METHOD}" == "distro" ] ; then
		build_info "Installing Linux kernel inside mounted image"
		cat > "${TEMP}/install_kernel" <<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y install linux-image-amd64
EOF
		chmod +x "${TEMP}/install_kernel"
		build_chroot "${TEMP}" /install_kernel
		rm -f "${TEMP}/install_kernel"
	fi
	
	build_info "Installing GRUB bootloader on a image"
	
	mkdir -p "${TEMP}/boot/efi"
	sys_mount_tmp ${LOOPDEV}p2 "${TEMP}/boot/efi"
	
	cat > "${TEMP}/install_grub" <<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
export LANG=C
export LANGUAGE=C
export LC_CTYPE=C 2> /dev/null
export LC_ALL=C 2> /dev/null
mkdir -p /boot/grub
ln -s /boot/grub /boot/grub2
grub-mkconfig -o /boot/grub/grub.cfg
grub-install --modules="ext2 part_gpt video_fb all_video boot part_gpt ntfs exfat fat" "${LOOPDEV}"
# efi
mkdir -p /boot/efi/EFI/BOOT
# grub-mkimage \
#   -d /usr/local/lib/grub/i386-pc \
#   -o /boot/efi/EFI/BOOT/bootx64.efi \
#   -p /efi/boot \
#   -O i386-pc \
#     fat iso9660 part_gpt part_msdos normal boot linux configfile loopback chain efifwsetup efi_gop \
#     efi_uga ls search search_label search_fs_uuid search_fs_file gfxterm gfxterm_background \
#     gfxterm_menu test all_video loadenv exfat ext2 ntfs btrfs hfsplus udf
EOF
		chmod +x "${TEMP}/install_grub"
		build_chroot "${TEMP}" /install_grub
		mkdir -p "${TEMP}/boot/grub/fonts"
		cp "${EXTER}/grub_fonts/unicode.pf2" "${TEMP}/boot/grub/fonts/"
		rm -f "${TEMP}/install_grub"
	
	#build_chroot "${TEMP}/" grub-install --target=x86_64-efi --modules=\"ext2 part_gpt video_fb\" "${LOOPDEV}"
	#build_chroot "${TEMP}/" update-grub
	#grub2-mkconfig -o /boot/grub2/grub.cfg
	sync
	sys_umount "${TEMP}/boot/efi"
	sys_umount "${TEMP}"
	
	losetup -d "${LOOPDEV}"
	LOOPDEV=""
	
	mv "${TMPIMAGE}" "${IMAGE}" -f
}

build_image_grub()
{
	build_error todo
}

# TODO: this should be rewrited
build_image_with_uboot()
{
	local UBOOT_START=24576
	local UBOOT_END=32767
	local TRUST_START=32768
	local TRUST_END=40959
	local BOOT_START=49152
	local BOOT_END=114687
	local ROOTFS_START=376832
	local LOADER1_START=64
	local IMG_ROOTFS_SIZE=$(expr `du -s $DEST | awk 'END {print $1}'` + 800 \* 1024)
	local GPTIMG_MIN_SIZE=$(expr $IMG_ROOTFS_SIZE \* 1024 + \( $(((${ROOTFS_START}))) \) \* 512)
	local GPT_IMAGE_SIZE=$(expr $GPTIMG_MIN_SIZE \/ 1024 \/ 1024 + 2)

	build_info "Preparing empty image ..."
	
	dd if=/dev/zero of=${IMAGE}2 bs=1M count=$(expr $IMG_ROOTFS_SIZE  \/ 1024 )
	
	build_info "Creating file system ..."
	
	build_info "ROOT_UUID: ${ROOT_UUID}"
	
	mkfs.ext4 -O ^metadata_csum -F -b 1024 -L rootfs -U ${ROOT_UUID} ${IMAGE}2
	
	if [ ! -d /tmp/tmp ]; then
		mkdir -p /tmp/tmp
	fi
	
	build_info "Copying rootfs files into created file system ..."

	sys_mount_tmp ${IMAGE}2 /tmp/tmp -t ext4
	# Add rootfs into Image
	#cp -rfa $DEST/* /tmp/tmp
	sys_cpdir $DEST/ /tmp/tmp

	sys_umount /tmp/tmp

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
