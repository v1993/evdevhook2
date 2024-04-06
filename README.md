# Cemuhook UDP server for devices with modern Linux drivers - successor to original evdevhook
![GitHub Actions - Build Status](https://img.shields.io/github/actions/workflow/status/v1993/evdevhook2/meson.yml)

[![Static Badge](https://img.shields.io/badge/AppImage-x86__64%2FARM64-blue)](https://github.com/v1993/evdevhook2/releases/latest)
[![AUR git package](https://img.shields.io/badge/aur-evdevhook2--git-blue)](https://aur.archlinux.org/packages/evdevhook2-git)

## Supported devices

* Nintendo Switch Joy-Cons
* Nintendo Switch Pro Controller
* DualShock 3 controller (currently untested, feedback welcome)
* DualShock 4 controller
* DualSense controller
* DualSense Edge controller

## Configuration

No configuration is required to get started - just run the resulting binary and
it will expose all supported controllers!

However, if you want to tweak controller orientations, run server on a different
port, or use over four controllers at once by running multiple servers on
different ports, it's possible to do so by providing a config file. See
[example config](ExampleConfig.ini) for syntax and full list of supported options.

## Quick build guide

```bash
git clone https://github.com/v1993/evdevhook2.git
cd evdevhook2
meson setup --buildtype=release -Db_lto=true --prefix=/usr build
meson compile -C build
# Optional
meson install -C build
```

### Updating
```bash
cd evdevhook2
git pull
meson subprojects update
meson compile -C build
# Optional
meson install -C build
```

## Dependencies
* libudev
* libevdev
* GLib 2.50+
* zlib
* Vala 0.56+ and libgee-0.8
* meson
* GCC/Clang

Optional:
* UPower (runtime-only) - battery status reporting

On Ubuntu and derivative the following should do:

```bash
sudo apt-get install build-essential \
    libudev-dev libevdev-dev zlib1g-dev \
    valac libgee-0.8-dev \
    meson
```
