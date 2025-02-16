## What is this?

This is a build script to create Debian or Ubuntu based system to work on a Rigol oscilloscopes based on a RK3399 CPU (arm64) and x86 based machines (home computers, laptops, other PC).

Disk, pendrive and SD card can be flashed directly from main menu. Of course only when image was build.

User friendly menus - no need to be a sys expert. Especially in a mode for beginners.

## What it can do? Why it can be better than other build scripts?

Two modes - for beginners and for experts.

When target system is under build progress (chroot), it uses host system apt cache (/var/cache/apt/archives/) to make it faster, less network usage and less disk space used. Downside is, You can't install or remove host system packages, when this script is making build progress.

If target architecture is AMD64 (modern PC), it can run virtual machine from main menu from image that was built previously. KVM is required for that, but most likely You already have it. For efficiency and safety, it's better to have virtualization enabled in Your BIOS menu, which most likely is already enabled.

Self update from main menu.

Main menu can put You into chroot at built system.

In case of oscilloscopes, it can update, recompile and reinstall bootloader & kernel from main menu. No need to read any manuals for that.

It automatically detects drives to work with and ignores system disk in order to prevent lost data - in case of user error.

Current progress is saved, so in case of error or interruption, at Your choice, You can restart build progress from (almost) same point as it was interrupted.

Target graphical environment is Mate with some initial configuration (theme and applets), to make it better both for Linux and Windows users.

Target system has some basic apps, games and engineering software for better experience at beginning of using it.

It creates Debian system with some changes to make it more lightweight, which means faster boot and faster desktop in most cases.

In case of x86 and AMD64 it can boot both from EFI and non-EFI (BIOS) systems without need of any change. Out of the box after switching disk into another computer or laptop.

To make a more universal PC image, You can chose i686 as a target architecture - You will be prompted for that.

When built is completed, You can flash target device (disk) from main menu. After flashing, it will resize FS, so disk will be ready to use after first boot.

## Currently supported boards (devices)

SoC | Boards | Bootloader
|:--|:--|:--|
| **[Rockchip RK3399](https://opensource.rock-chips.com/wiki_RK3399)** (ARM64) | Rigol DHO800 series | **[U-Boot](https://github.com/norbertkiszka/rigol-orangerigol-uboot_2017.09_light)** |
| **[Rockchip RK3399](https://opensource.rock-chips.com/wiki_RK3399)** (ARM64) | Rigol DHO900 series | **[U-Boot](https://github.com/norbertkiszka/rigol-orangerigol-uboot_2017.09_light)** |
| x86 i686 (32 & 64 bit) | EFI, BIOS (older and modern PC) | **[Grub](https://git.savannah.gnu.org/cgit/grub.git/tag/?h=grub-2.12)** |
| AMD64 (x86 64 bit) | EFI, BIOS (modern PC) | **[Grub](https://git.savannah.gnu.org/cgit/grub.git/tag/?h=grub-2.12)** |

More devices are planned.

Currently Ubuntu is unavailable on x86 32 bit version (x86 64 bit and arm64 only).

Detailed oscilloscopes list for SEO:

- Rigol DHO924S
- Rigol DHO924
- Rigol DHO914S
- Rigol DHO824
- Rigol DHO814
- Rigol DHO812
- Rigol DHO804
- Rigol DHO802

## Requirements

This build script currently only works on a Debian 12 "bookworm" as a host system.

## How to use it?

Clone repository:

```bash
git clone --recurse-submodules https://github.com/norbertkiszka/orangerigol.git
cd orangerigol
```

After that, execute one of those scripts:

- build-for-begginners.sh
- build-for-experts.sh

Names of those are of course self explanatory.

Example:

```bash
sudo ./build-for-begginners.sh
```

At the beginning of first run, it will prepare Your system with installing necessary packages. However its easy to forget about adding something to that list, so if You encounter any problems with missing something - please let me know. If newer commit will be detected (after update), it will run preparation again to make sure that we have all necessary packages.

After eventual preparation, You will see target device choice. Currently it will only change generated image filename, so its safe just to press enter here.

Next menu is a "main menu". To start build process, enter first option (press enter). It will grab all necessary information from You and at the end fully working image should be generated.

Build process will take some time, especially if it's first time.

After that, it will go back to main menu and You should see one more option (last one) to flash image into disk or SD card. After flashing, it will resize filesystem in order to use full disk capacity.

If given disk or card is mounted in Your host, it will ask for Your permission to umount it. If You don't use its contents, it's safe to press enter here.

Naturally, If You have some important data on target disk before flashing, make a backup, because flashing will overwrite all data on it.

Finally You can remove card from a card reader (or unplug disk) and put it into target device.

## Features

- Choice of installing base system (server) or a user friendly desktop (graphical interface) with a bunch of a desktop software (browser, video player, document viewers, etc).
- When interrupted by user or due to error, it will ask to continue or to delete rootfs and start from the beginning. It works by saving current progress and not doing works that was already done.
- Preinstalled desktop setup with Mate environment (supported and popular fork of a Gnome 2) - ready to use from first start. Since it's Debian or Ubuntu (at Your choice), later You can install another graphical environment by Apt or graphical Synaptic.
- Possibility to flash SD card, disk or USB pendrive directly from a menu in this script. After flashing, it will resize fs to fullfil whole disk size.

## Videos and screenshots

[![Orange Rigol v0.2.0.1](https://img.youtube.com/vi/2y0E4PasLPY/0.jpg)](https://www.youtube.com/watch?v=2y0E4PasLPY)

[![Rigol DHO924S - Debian Linux 3D acceleration proof (Tux Racer)](https://img.youtube.com/vi/ca_y4zmKaQc/0.jpg)](https://www.youtube.com/watch?v=ca_y4zmKaQc)

![Platform menu](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-1.png)

![Build options](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-2.png)

![Build type](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-3.png)

![Text input - SD card path](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-4.png)

![SD card flashing confirmation](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-5.png)

## Current status on a Rigol oscilloscopes

- It's stable - no crashes, except reboot (see below).
- Does reboot instead of shutdown and sometimes makes kernel panic when tried to reset (reboot) board.
- Oscilloscope app is not fully ported (its not here yet).
- Currently tested only on a Rigol DHO924S.
- Boot time ~33 seconds to a GDM3 graphical login manager. After ~6 seconds autologin will be performed.

## Current work progress / TODO

- For oscilloscopes, change kernel from **[4.4.179](https://github.com/norbertkiszka/rigol-orangerigol-linux_4.4.179)** to **[5.10.209](https://github.com/norbertkiszka/Linux-5.10-Rockchip)**.
- Change gdm3 (login manager) into nodm (fast autologin). That and newer kernel drops boot time to the ~28 seconds (DHO924S) into fullly working graphical environment, instead of about 50 seconds.
- Propmt for login manager or autologin.
- Run original Rigol app with **[Anbox ARM64](https://github.com/norbertkiszka/anbox-arm64)**.
- Reverse engineer libscope-auklet.so (Rigol app) in order to hack it and/or make a better app.
- Make menus less time consuming and group options into smaller menus.
- Change required packages names in order to run this build script under Ubuntu. Currently this works only on Debian.
- Make it run on other popular Linux distributions.
- Chroot also into image or disk. Prompt user to rebuild image or reflash disk after that.

## How much resources it uses?

After full boot and login into Mate desktop environment, by defult it will use less than 500 MiB RAM.
CPU usage when not doing anything (like a using browser or anything) is almost zero.

Space used: base system takes around 2 - 2.5 GiB and with desktop environment it takes around 8-9 GiB.

## Default password

Password for root user is: rigol.
Script asks for a username which will be also default password.
Every user can change his/her password via passwd command or within graphical program mate-about-me (system -> personal -> about me).
