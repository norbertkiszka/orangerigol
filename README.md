## What is this?

This is a build script to create Debian/Linux (version 12 currently which is newest stable) based system to work on a Rigol oscilloscopes based on a RK3399 CPU (arm64).

Uses user friendly menus and messages.

It can install desktop system based on Mate enviroment (supported and popular fork of a Gnome 2).

Its possible to flash SD card directly from this script.

## Currently supported boards (devices)

Soc | Boards |
|:--|:--|
| Rockchip RK3399 | Rigol DHO800 series |
| Rockchip RK3399 | Rigol DHO900 series |

## Screenshots and videos

![Platform menu](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-1.png)

![Build options](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-2.png)

![Build type](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-3.png)

![Text input - SD card path](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-4.png)

![SD card flashing confirmation](https://raw.githubusercontent.com/norbertkiszka/rigol-orangerigol-build/master/screenshots/screenshot-5.png)

[![Rigol DHO924S - Debian Linux 3D acceleration proof (Tux Racer)](https://img.youtube.com/vi/ca_y4zmKaQc/0.jpg)](https://www.youtube.com/watch?v=ca_y4zmKaQc)

## Current status

- Its stable - no crashes, except reboot (see below).
- Does reboot instead of shutdown and sometimes makes kernel panic when tried to reset board.
- Oscilloscope app is not fully ported.
- As for now, it does support only Debian 12 "bookworm".
- Currently tested only on a Rigol DHO924S.
- Boot time ~33 seconds.
