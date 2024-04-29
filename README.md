## What is this?

This is a build script to create Debian or Ubuntu based system to work on a Rigol oscilloscopes based on a RK3399 CPU (arm64) and x86 based machines.

Disk, pendrive and SD card can be flashed directly from main menu (ofc. only when image was build).

User friendly menus - no need to be sys expert.

## Currently supported boards (devices)

SoC | Boards |
|:--|:--|
| Rockchip RK3399 | Rigol DHO800 series |
| Rockchip RK3399 | Rigol DHO900 series |
| x86 i686 | EFI, BIOS |
| AMD64 | EFI, BIOS |

More devices are planned.

Currently Ubuntu is unavailable on x86 32 bit version (x86 64 bit and arm64 only).

Detailed oscilloscopes list for SEO:

- Rigol DHO924S
- Rigol DHO924
- Rigol DHO914S
- Rigol DHO814
- Rigol DHO812
- Rigol DHO804
- Rigol DHO802

## Requirements

This build script currenty only works on a Debian 12 "bookworm" as a host system.

## How to use it?

Clone repository:

```bash
git clone --recurse-submodules https://github.com/norbertkiszka/rigol-orangerigol-build.git
cd rigol-orangerigol-build
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

Build process will take some time, especially if its first time.

After that, it will go back to main menu and You should see one more option (last one) to flash image into disk or SD card. After flashing, it will resize filesystem in order to use full disk capacity.

If given disk or card is mounted in Your host, it will ask for Your permission to umount it. If You dont use its contents, its safe to press enter here.

Naturally, If You have some important data on target disk before flashing, make a backup, because flashing will overwrite it.

Finally You can remove card from a card reader (or unplug disk) and put it into target device.

## Features

- Choice of installing base system (server) or a user friendly desktop (graphical interface) with a bunch of a desktop software (browser, video player, document viewers, etc).
- When interrupted by user or due to error, it will ask to continue or to delete rootfs and start from the beginning.
- Preinstalled desktop setup with Mate enviroment (supported and popular fork of a Gnome 2) - ready to use from first start.
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

- Its stable - no crashes, except reboot (see below).
- Does reboot instead of shutdown and sometimes makes kernel panic when tried to reset board.
- Oscilloscope app is not fully ported (its not here yet).
- Currently tested only on a Rigol DHO924S.
- Boot time ~33 seconds to a GDM3 graphical login manager. After ~6 seconds autologin will be performed.

## How much resources it uses?

After full boot and login into Mate desktop enviroment, by deafult it will use less than 500 MiB RAM.
CPU usage when not doing anything is almost zero.

Space used: base system takes around 2.2 GiB and with desktop enviroment it will take around 8 GiB.

## Default password

Password for root user is: rigol.
Script asks for a username which will be also default password.
Every user can change his/her password via passwd command or within gui program mate-about-me (system -> personal -> about me).
