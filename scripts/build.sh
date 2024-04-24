#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

set -ea

LIB_BASH="$(pwd)/scripts/lib-bash/lib-bash.sh"

if [ ! -e "${LIB_BASH}" ] ; then
	echo "Cloning missing lib-bash"
	git clone https://github.com/norbertkiszka/lib-bash.git $(dirname $LIB_BASH)
fi

readonly REQUIRED_LIB_BASH_VERSION_AT_LEAST="0.2.3"
source "${LIB_BASH}"
#info "lib-bash version: ${LIB_BASH_VERSION}"
show_stacktrace_for_warnings
forbidden_warning

export PATH="${PATH}:/bin:/usr/bin:/sbin:/usr/sbin"

readonly BUILD_VERSION_MAJOR=0
readonly BUILD_VERSION_MINOR=3
readonly BUILD_VERSION_PATCH=7
readonly BUILD_EXTRAVERSION=0
readonly BUILD_VERSION_TEXT="${BUILD_VERSION_MAJOR}.${BUILD_VERSION_MINOR}.${BUILD_VERSION_PATCH}.${BUILD_EXTRAVERSION}"
BUILD_GIT_SHORT=$(git_last_commit_hash_short)
[ "$(git_list_modified_files)" == "" ] || BUILD_GIT_SHORT="${BUILD_GIT_SHORT}-dirty"
readonly BUILD_GIT_SHORT="${BUILD_GIT_SHORT}"

echo -en "\033[0;33m[ Orange Rigol Build System version ${BUILD_VERSION_TEXT}"
[ "${BUILD_GIT_SHORT}" == "" ] || echo -en " git ${BUILD_GIT_SHORT}"
echo -e " ]\033[0m"

# Original variables:
source "$(pwd)/scripts/lib/vars.sh"
# User private vars (wont be commited, its in .gitignore):
[ ! -e "$(pwd)/vars-user.sh" ] || source "$(pwd)/vars-user.sh"

source "${SCRIPTS}"/lib/general.sh
source "${SCRIPTS}"/lib/user-interaction.sh
source "${SCRIPTS}"/lib/compilation.sh
source "${SCRIPTS}"/lib/distributions.sh
source "${SCRIPTS}"/lib/build_image.sh
source "${SCRIPTS}"/lib/flash_image.sh

if [ "${EUID}" != 0 ]; then
	build_warning "This script requires root privileges, trying to use sudo..."
	set +e
	set +a
	sudo $0 $*
	exit $?
fi

host_requirements_check

export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_CTYPE="en_US.UTF-8" 2> /dev/null
export LC_ALL="en_US.UTF-8" 2> /dev/null

build_info "Difficulty: ${DIFFICULTY}"

[ -d "${OUTPUT}" ] || mkdir -p "${OUTPUT}"

if [ ! -f $OUTPUT/.prepare_host ] || [ "$(cat "$OUTPUT/.prepare_host" | grep "$BUILD_GIT_SHORT")" == "" ] ; then
	prepare_host
	echo "$BUILD_GIT_SHORT" > "${OUTPUT}/.prepare_host"
fi

sys_chroot_add_bind "${BUILD_APT_ARCHIVES_CACHE}" /var/cache/apt/archives

startup_selections
[ "$DEVICE_CATEGORY" == "Rigol DHO800/900" ] && prepare_toolchains

BUILD_OUTPUT="${BOARD}_Debian_${DISTRO}_${IMAGETYPE}"
BUILD="${ROOT}/output/${BUILD_OUTPUT}"
DEST="${BUILD}/rootfs"
UBOOT_BIN="$BUILD/uboot"

if [ "$ARCH" == "arm64" ] || [ "$ARCH" == "arm" ] ; then
	BOOTLOADER="uboot"
	KERNEL_METHOD="compile"
else
	BOOTLOADER="grub"
	KERNEL_METHOD="distro"
fi

[ -e "${BUILD}" ] || mkdir -p "$BUILD"

whiptail_menu_set_default_backtitle "$BUILD_OUTPUT"

while true
do
	main_menu
done
