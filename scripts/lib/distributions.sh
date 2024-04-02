#!/bin/bash

# Author: Norbert Kiszka and others
# License: GPL v2

deboostrap_rootfs() {
	DIST="$1"
	TGZ="$(readlink -f "$2")"
	build_info "Preparing base system with debootstrap ..."
	TEMP=$(mktemp -d)

	touch $TEMP/test_file || build_error "Cannot write into temp directory: ${TEMP}"
	build_info "Entering directory ${TEMP}"
	cd $TEMP

	# this is updated very seldom, so is ok to hardcode
	#debian_archive_keyring_deb="${SOURCES}/pool/main/d/debian-archive-keyring/debian-archive-keyring_2019.1_all.deb"
	debian_archive_keyring_deb="http://ftp.de.debian.org/debian/pool/main/d/debian-archive-keyring/debian-archive-keyring_2023.4_all.deb"
	wget -O keyring.deb "$debian_archive_keyring_deb"
	ar -x keyring.deb && rm -f control.tar.gz debian-binary && rm -f keyring.deb
	DATA=$(ls data.tar.*) && compress=${DATA#data.tar.}

	KR=debian-archive-keyring.gpg
	tar --strip-components=4 -xvf "$DATA"
	ls "$DATA"
	rm -f "$DATA"

	debootstrap --include="locales,base-files,base-passwd,debian-keyring,apt-utils,gawk,adduser,tar,perl,bash" --arch=${ARCH} --keyring=$TEMP/$KR --foreign $DIST rootfs ${SOURCES}

	chroot rootfs /debootstrap/debootstrap --second-stage
	
	tar -C $TEMP/rootfs -a -cf $TGZ .
	rm -fr $TEMP/rootfs

	cd -
	build_info "Base system is prepared in ${TGZ}"
}

do_chroot()
{
	cp /usr/bin/qemu-aarch64-static "$DEST/usr/bin" || build_warning "Failed to copy qemu-aarch64-static. Please check if that file exists."
	
	qemu_dest="$DEST/usr/bin/qemu-aarch64-static"

	cmd="$@"
	
	build_info "Chroot $DEST with cmd: $cmd"
	
	chroot "$DEST" mount -t proc proc /proc || build_warning "Failed to mount /proc"
	#mount --bind /proc "$DEST/proc" || build_warning "Failed to mount --bind /proc"
	
	chroot "$DEST" mount -t sysfs sys /sys || build_warning "Failed to mount /sys"
	#mount --bind /sys "$DEST/sys" || build_warning "Failed to mount --bind /sys"
	
	chroot "$DEST" mount -t devtmpfs devtmpfs /dev || build_warning "Failed to mount /dev"
	#mount --rbind /dev "$DEST/dev" || build_warning "Failed to mount --rbind /dev"
	
	chroot "$DEST" mount devpts /dev/pts -t devpts || build_warning "Failed to mount /dev/pts"
	#mount --bind /dev/pts "$DEST/dev/pts" || build_warning "Failed to mount --bind /dev/pts"
	
	[ "$(mount | grep \"$DEST/var/cache/apt/archives\")" == "" ] && \
	mount --bind /var/cache/apt/archives "$DEST/var/cache/apt/archives" || build_warning "Failed to mount --bind /var/cache/apt/archives"
	
	chroot "$DEST" $cmd
	#chroot "$DEST" qemu-aarch64-static "$cmd"
	
	umount "$DEST/proc" || build_warning "Failed to umount /proc"
	umount "$DEST/sys" || build_warning "Failed to umount /sys"
	umount "$DEST/dev/pts" || build_warning "Failed to umount /dev/pts"
	umount "$DEST/dev" || build_warning "Failed to umount /dev"
	umount -l "$DEST/var/cache/apt/archives" || build_warning "Failed to umount /var/cache/apt/archives"

	# Clean up
	rm -f "$DEST/usr/bin/qemu-aarch64-static"
}

add_overlay()
{
	build_info "Adding overlay ${1} ..."
	[ "$(ls $EXTER/packages/overlays/$1/* 2> /dev/null)" != "" ] && cp -r --preserve=links $EXTER/packages/overlays/$1/* $DEST/ || ((i=i+1))
	[ "$(ls $EXTER/packages/overlays/$1/.* 2> /dev/null)" != "" ] && cp -r --preserve=links $EXTER/packages/overlays/$1/.* $DEST/ || ((i=i+1))
	[ "$i" -gt 0 ] || build_warning "Failed to add overlay ${1}."
}

add_overlays_preinstall()
{
	build_info "Adding overlays (preinstall) ..."
	add_overlay skel
	add_overlay firmware
	add_overlay images
	build_info "Overlays added (preinstall)."
}

add_overlays_postinstall()
{
	build_info "Adding overlays (postinstall) ..."
	add_overlay systemd
	add_overlay cpufrequtils
	rm -rf $DEST/etc/update-motd.d/*
	add_overlay motd
	#add_overlay mali-proprietary-driver
	add_overlay gdm3
	add_overlay mpv
	add_overlay dconf
	if [ "$IMAGETYPE" = "desktop" ] || [ "$IMAGETYPE" = "desktop-oscilloscope" ] ; then
		do_chroot "/usr/bin/dconf update" || build_warning "Failed to update dconf database. Please execute [# dconf update (enter)] and [$ dconf load / < /etc/dconf/db/local.d/00-orangerigol (enter)] after installing."
	fi
	build_info "Overlays added (postinstall)."
}

add_apt_sources()
{
	build_info "Adding apt sources ..."
	local release="$1"
	local aptsrcfile="$DEST/etc/apt/sources.list"
	cat > "$aptsrcfile" <<EOF
deb ${SOURCES} ${release} main contrib non-free non-free-firmware
# deb-src ${SOURCES} ${release} main contrib non-free 
deb http://security.debian.org/debian-security ${release}-security main contrib non-free non-free-firmware

# for older packages (oldstable):
#deb ${SOURCES} bullseye main non-free contrib
#deb http://security.debian.org/debian-security bullseye-security main contrib non-free
EOF
}

prepare_env()
{
	build_info "Preparing rootfs enviroment ..."
	cleanup()
	{
		if [ -e "$DEST/proc/cmdline" ]; then
			umount "$DEST/proc"
		fi
		if [ -d "$DEST/sys/kernel" ]; then
			umount "$DEST/sys"
		fi
		if [ -e "$DEST/dev/pts/ptmx" ]; then
			umount "$DEST/dev/pts" || true
		fi
		if [ -e "$DEST/dev/mem" ]; then
			umount "$DEST/dev" || true
		fi
		if [ "$(mount | grep \"$DEST/var/cache/apt/archives\")" != "" ]; then
			umount -l "$DEST/var/cache/apt/archives" || true
		fi
		if [ -d "$TEMP" ]; then
			rm -rf "$TEMP"
		fi
	}
	trap cleanup EXIT
	
	# TODO: user choice of optional deleting
	if [ -d "$DEST" ]; then
		build_notice "Destination $DEST already exists. Continuing ..."
		return 0;
	fi
	
	build_info "Destination $DEST not found or not a directory."
	build_info "Create $DEST"
	mkdir -p $DEST
	
	# dirs workaround
	mkdir -p "$DEST/var/lib/alsa"
	mkdir -p "$DEST/etc/ssh"
	mkdir -p "$DEST/usr/local"
	
	ROOTFS="${DISTRO}-base-${ARCH}.tar.gz"
	METHOD="debootstrap"
	SOURCES="http://ftp.de.debian.org/debian/"

	TARBALL="$EXTER/$(basename $ROOTFS)"

	if [ ! -e "$TARBALL" ]; then
		if [ "$METHOD" = "download" ]; then
			build_info "Downloading $DISTRO rootfs tarball ..."
			wget -O "$TARBALL" "$ROOTFS"
		elif [ "$METHOD" = "debootstrap" ]; then
			deboostrap_rootfs "$DISTRO" "$TARBALL"
		else
			build_error "Unknown rootfs creation method"
		fi
	fi

	# Extract with tar
	build_info "Extracting base system from $TARBALL ..."
	mkdir -p $DEST
	$UNTAR "$TARBALL" -C "$DEST"
	build_info "Base system unpacked in ${DEST}"
}

ckeck_apt_archives_cache_lock()
{
	if [ -e "${BUILD_APT_ARCHIVES_CACHE}lock" ] && [ $(lsof "${BUILD_APT_ARCHIVES_CACHE}lock" | wc -l) -gt 0 ]; then
		build_error "Unable to lock directory ${BUILD_APT_ARCHIVES_CACHE}\n \
${BUILD_APT_ARCHIVES_CACHE}lock is held by process "`lsof ${BUILD_APT_ARCHIVES_CACHE}lock | grep "${BUILD_APT_ARCHIVES_CACHE}lock"  | awk '{ print $2 }'`" ("`lsof ${BUILD_APT_ARCHIVES_CACHE}lock | grep "${BUILD_APT_ARCHIVES_CACHE}lock"  | awk '{ print $1 }'`")"
	fi
}

prepare_rootfs_server()
{
	build_info "Installing base packages ..."
	rm "$DEST/etc/resolv.conf" || true
	cp /etc/resolv.conf "$DEST/etc/resolv.conf" || build_error "Cant continue wihout /etc/resolv.conf. Please check if that file exists on Your system."
	
	DEBUSER=rigol

	add_apt_sources $DISTRO
	rm -rf "$DEST/etc/apt/sources.list.d/proposed.list"
	cat > "$DEST/second-phase" <<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
sed -i '/en_US.UTF-8 UTF-8/s/^# //g' /etc/locale.gen
echo -e "LANG=\"en_US.UTF-8\"\nLANGUAGE=\"en_US:en\"\nLC_CTYPE=\"en_US.UTF-8\"\nLC_ALL=\"en_US.UTF-8\"" > /etc/default/locale
export LANG="en_US.UTF-8"
export LANGUAGE="en_US:en"
export LC_CTYPE="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"
locale-gen
apt-get -y update
apt-get -y dist-upgrade
echo -e "\033[0;32mPackages part 1\033[0m"
apt-get -y install base-files base-passwd debian-keyring
echo -e "\033[0;32mPackages part 2\033[0m"
apt-get -y install whiptail apt-utils gawk adduser tar
echo -e "\033[0;32mPackages part 3\033[0m"
apt-get -y install dialog coreutils linuxinfo bash bash-completion
echo -e "\033[0;32mPackages part 4\033[0m"
apt-get -y install base-files locales gpg gpgv apt-utils
echo -e "\033[0;32mPackages part 5\033[0m"
apt-get -y install dosfstools curl xz-utils iw rfkill ifupdown-ng wget logrotate
echo -e "\033[0;32mPackages part 6\033[0m"
apt-get -y install wpasupplicant openssh-server alsa-utils moc etherwake iputils-ping
echo -e "\033[0;32mPackages part 7\033[0m"
apt-get -y install rsync nano pv pipemeter sysstat iproute2 iptables
echo -e "\033[0;32mPackages part 8\033[0m"
apt-get -y install gpm vim parted git subversion autoconf gcc libtool traceroute
echo -e "\033[0;32mPackages part 9\033[0m"
apt-get -y install libsysfs-dev pkg-config libdrm-dev firmware-linux-free
echo -e "\033[0;32mPackages part 10\033[0m"
apt-get -y install man extundelete lzma openfpgaloader
echo -e "\033[0;32mPackages part 11\033[0m"
apt-get -y install imagemagick cmake bluez flashrom firmware-linux-nonfree
echo -e "\033[0;32mPackages part 12\033[0m"
apt-get -y install wireless-tools usbutils pciutils lsof mtd-utils htop ntfs-3g firmware-realtek
echo -e "\033[0;32mPackages part 13\033[0m"
apt-get -y install zip unzip wget xz-utils testdisk firmware-misc-nonfree
echo -e "\033[0;32mPackages part 14\033[0m"
apt-get -y install lm-sensors rkdeveloptool flashrom fdisk gpart abootimg firmware-zd1211 fancontrol read-edid i2c-tools
echo -e "\033[0;32mPackages part 15\033[0m"
apt-get -y install flex bison binutils libsvn1 gdb cgdb gdbserver aptitude
echo -e "\033[0;32mPackages part 16\033[0m"
apt-get -y install unrar arj genisoimage lynx odt2txt mc moc moc-ffmpeg-plugin
echo -e "\033[0;32mPackages part 17\033[0m"
apt-get -y install extrepo extrepo-offline-data eventstat hexcompare hexcurse
echo -e "\033[0;32mPackages part 18\033[0m"
apt-get -y install expect bc sed make cpufrequtils figlet toilet lsb-release
echo -e "\033[0;32mPackages part 19\033[0m"
apt-get -y install cowsay cowsay-off kmod dnsutils valgrind bind9-host
echo -e "\033[0;32mPackages part 20\033[0m"
apt-get -y install openfpgaloader ethtool tcpdump strace libelf-dev libdw1 libdw-dev
echo -e "\033[0;32mPackages part 21\033[0m"
apt-get -y install libdwarf++0 libdwarf-dev openssl ca-certificates libssl-dev
echo -e "\033[0;32mPackages part 22\033[0m"
# apt-get -y install pulseaudio libunwind-16 libunwind-16-dev
echo -e "\033[0;32mPackages part 23\033[0m"
apt-get -y install sudo net-tools g++ libjpeg-dev unrar sshfs avrdude dfu-programmer emu8051
echo -e "\033[0;32mPackages part 24\033[0m"
apt-get -y install esptool gputils simavr avrp net-tools ntp ntpdate
apt-get -y update
apt-get -y dist-upgrade

#apt-get install -f -y
apt-get install -y

mkdir -p /root
cp /etc/skel/.bashrc /root
mkdir -p /home/$DEBUSER
chmod 755 /home
useradd -p $DEBUSER -s /bin/bash -u 1000 -U $DEBUSER -d /home/$DEBUSER || echo "User $DEBUSER already exists."
cp -R /etc/skel/.* /home/$DEBUSER
chown -R 1000:1000 /home/$DEBUSER
chmod 700 /home/$DEBUSER
chmod 700 /root
echo "$DEBUSER:$DEBUSER" | chpasswd
echo root:$DEBUSER | chpasswd
adduser $DEBUSER sudo || true
adduser $DEBUSER adm || true
adduser $DEBUSER video || true
adduser $DEBUSER plugdev || true
adduser $DEBUSER dialout || true
adduser $DEBUSER audio || true
adduser $DEBUSER netdev || true
adduser $DEBUSER bluetooth || true
#apt-get -y autoremove

update-alternatives --set editor /bin/nano
update-alternatives  --auto editor

mkdir -p /etc/sudoers.d
echo "%sudo	ALL=NOPASSWD: ALL" > /etc/sudoers.d/nopasswd-sudoers
EOF
	chmod +x "$DEST/second-phase"
	ckeck_apt_archives_cache_lock
	do_chroot /second-phase
	rm -f "$DEST/second-phase"
	rm -f "$DEST/etc/resolv.conf"

	#cd $BUILD
	#tar czf ${DISTRO}_server_rootfs.tar.gz rootfs
	#cd -
	
	build_info "Base packages installed."
}

server_setup()
{
	build_info "Configuring system ..."

	cat > "$DEST/etc/hostname" <<EOF
orangerigol
EOF
	cat > "$DEST/etc/hosts" <<EOF
127.0.0.1 localhost
127.0.1.1 orangerigol

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF
	cat > "$DEST/etc/resolv.conf" <<EOF
nameserver 8.8.8.8
EOF

	sed -i 's|After=rc.local.service|#\0|;' "$DEST/lib/systemd/system/serial-getty@.service"

	# Bring back folders
	mkdir -p "$DEST/lib"
	mkdir -p "$DEST/usr"

	# Create fstab
	cat  > "$DEST/etc/fstab" <<EOF
# <file system>	<dir>	<type>	<options>				<dump>	<pass>

/dev/mmcblk0p4	/	ext4	defaults,noatime			0		1
EOF
	if [ ! -d $DEST/lib/modules ]; then
		mkdir "$DEST/lib/modules"
	else
		rm -rf $DEST/lib/modules
		mkdir "$DEST/lib/modules"
	fi
	
	build_info "Installing Linux kernel modules ..."
	make -C $LINUX ARCH=${ARCH} CROSS_COMPILE=$TOOLS modules_install INSTALL_MOD_PATH="$DEST"

	build_info "Installing Linux kernel headers ..."
	make -C $LINUX ARCH=${ARCH} CROSS_COMPILE=$TOOLS headers_install INSTALL_HDR_PATH="$DEST/usr/local"
}

install_mate_desktop()
{
	cat > "$DEST/type-phase" <<EOF
#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
apt-get -y install xinit xserver-xorg xserver-xorg-input-all xserver-xorg-input-libinput xcvt xserver-xorg-legacy xserver-xorg-video-fbdev --no-install-recommends
apt-get -y install mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers libgl1-mesa-dri
apt-get -y install libvulkan1 libvulkan-dev libdrm2 libdrm-dev libwayland-server0 
apt-get -y install libwayland-client0 libwayland-dev
apt-get -y install xserver-xorg-video-cirrus xserver-xorg-video-neomagic 
apt-get -y install xserver-xorg-video-vesa xserver-xorg-video-qxl
apt-get -y install metacity shiki-wine-theme shiki-human-theme gnome-themes-extra gnome-themes-extra-data xutils xutils-dev mate-desktop mate-desktop-environment mesa-utils --no-install-recommends
apt-get -y install desktop-base fontconfig fontconfig-config fonts-dejavu-core fonts-quicksand --no-install-recommends
apt-get -y install atril eom ffmpegthumbnailer mate-calc mate-applets mate-notification-daemon mate-system-monitor mate-terminal mate-utils pluma
# apt-get -y install mate-power-manager
apt-get -y install network-manager network-manager-gnome smplayer smtube snake4 kpat krusader clementine
apt-get -y install fische mesa-utils mesa-utils-bin audacity kwave mhwaveedit totem ark cups
apt-get -y install caja-mediainfo gparted simplescreenrecorder kompare
apt-get -y install android-libunwind firefox-esr gpsim gtkwave
apt-get -y install chromium kate supertux supertuxkart nexuiz nexuiz-music hedgewars
apt-get -y install yt-dlp s51dude evolution gdm3 synaptic kdeconnect --no-install-recommends

#apt-get -y autoremove

update-alternatives  --set x-session-manager /usr/bin/mate-session
update-alternatives  --auto x-session-manager

update-alternatives --install /usr/share/images/desktop-base/desktop-background desktop-background /usr/share/images/microscope.png 80
update-alternatives  --set desktop-background /usr/share/images/microscope.png
update-alternatives  --auto desktop-background

systemctl mask lm-sensors.service || true
systemctl mask e2scrub_reap.service || true
systemctl mask ModemManager.service || true
#systemctl mask accounts-daemon.service || true
systemctl mask avahi-daemon.service || true
systemctl mask brltty.service || true
systemctl mask debug-shell.service || true
systemctl mask pppd-dns.service || true
systemctl mask upower.service || true
systemctl mask sysstat.service || true
systemctl mask getty@tty1.service || true
EOF

	chmod +x "$DEST/type-phase"
	ckeck_apt_archives_cache_lock
	do_chroot /type-phase
	sync
	rm -f "$DEST/type-phase"
}

build_rootfs()
{
	prepare_env
	add_overlays_preinstall
	prepare_rootfs_server
	server_setup
	build_info "Base system is prepared."
	
	if [ "$IMAGETYPE" = "desktop" ] || [ "$IMAGETYPE" = "desktop-oscilloscope" ] ; then
		install_mate_desktop
	fi
	
	add_overlays_postinstall
	build_info "Rootfs (system) is ready."
}

