#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

compile_bootloader()
{
	compile_bootloader_$BOOTLOADER
}

compile_bootloader_uboot()
{
	build_info "Preparing to compile U-Boot bootloader ..."
	prepare_uboot
	
	if [ ! -d $UBOOT_BIN ]; then
		mkdir -p $UBOOT_BIN
	fi

	if [ ! -d $UBOOT ]; then
		build_error "u-boot directory ${UBOOT} doesn't exist."
	fi

	cd $UBOOT
	build_info "Build U-boot ..."

	./make.sh rk3399-orangerigol
	cp -rf uboot.img $UBOOT_BIN
	cp -rf trust.img $UBOOT_BIN
	cp -rf rk3399_loader_v1.22.119.bin $UBOOT_BIN
	cp -rf idbloader.img $UBOOT_BIN
	
	cd - > /dev/null

	build_info "Complete U-Boot compile."
}

# Usage: compile_bootloader_grub efi prefix_path
# Usage: compile_bootloader_grub bios prefix_path
compile_bootloader_grub()
{
	build_info "Preparing to compile GRUB bootloader ..."
	
	if [ "$1" != "efi" ] && [ "$1" != "bios" ] || [ "$2" == "" ] ; then
		build_error "${FUNCNAME}: bad usage. Called with args: $@"
	fi
	
	build_info "GRUB platform: ${1} Path prefix: ${2}"
	
	prepare_grub
	
	cd $GRUB
	
	if [ ! -e grub-core/lib/gnulib/stdlib.in.h ] ; then
		./bootstrap
	fi
	if [ ! -e configure ] ; then
		./autogen.sh
	fi
	if [ "${ARCH}" == "amd64" ] ; then
		if [ "$1" == "efi" ] ; then
			./configure --prefix="${2}" --target=x86_64 --with-platform=efi
		else
			./configure --prefix="${2}" --target=x86_64
		fi
	else
		if [ "$1" == "efi" ] ; then
			./configure --prefix="${2}" --target=i686 --with-platform=efi
		else
			./configure --prefix="${2}" --target=i686
		fi
	fi
	
	build_info "Build GRUB ..."
	make clean
	make -j${CORES}
	
	cd - > /dev/null
}

compile_kernel()
{
	build_info "Preparing to compile Linux kernel ..."
	prepare_kernel
	
	if [ ! -d $BUILD ]; then
		mkdir -p $BUILD
	fi

	if [ ! -d $BUILD/kernel ]; then
		mkdir -p $BUILD/kernel
	fi

	KERNEL_CONFIG_NAME="orangerigol_defconfig"
	
	build_info "Compiling Linux kernel with config $KERNEL_CONFIG_NAME"
	
	make -C $LINUX ARCH=${ARCH} CROSS_COMPILE=$TOOLS $KERNEL_CONFIG_NAME
	make -C $LINUX ARCH=${ARCH} CROSS_COMPILE=$TOOLS -j${CORES} rk3399-rigol.img
			
	build_info "Kernel compiled. Instaling modules in ${BUILD} ..."
	
	rm -rf $BUILD/lib/modules/*
	
	make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES} modules_install INSTALL_MOD_PATH=$BUILD
	
	build_info "Building kernel boot image ..."
	
	rm -f $LINUX/boot.img || true
	rm -f $LINUX/resource.img || true

	cd $LINUX/
	$EXTER/resource_tool $LINUX/arch/arm64/boot/dts/rockchip/rk3399-rigol.dtb $LINUX/logo.bmp $LINUX/logo_kernel.bmp
	#$EXTER/resource_tool $EXTER/rk3399-rigol.dtb $LINUX/logo.bmp $LINUX/logo_kernel.bmp
	mkbootimg --kernel $LINUX/arch/arm64/boot/Image --second $LINUX/resource.img -o $LINUX/boot.img
	cp $LINUX/boot.img $BUILD/kernel

	build_info "Complete kernel compilation."
}

compile_module()
{
	build_info "Preparing to compile Linux kernel modules ..."
	prepare_kernel
	
	if [ ! -d $BUILD/lib ]; then
	        mkdir -p $BUILD/lib
	else
	        rm -rf $BUILD/lib/*
	fi

	# install module
	build_info "Compiling kernel modules ..."
	make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES} modules
	build_info "Installing kernel modules in ${BUILD} ..."
	make -C $LINUX ARCH="${ARCH}" CROSS_COMPILE=$TOOLS -j${CORES} modules_install INSTALL_MOD_PATH=$BUILD
	build_info "Complete kernel module compilation and installation ..."
}
