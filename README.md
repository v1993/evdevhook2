# Cemuhook UDP server for devices with modern Linux drivers - successor to original evdevhook

## Supported devices

* Nintendo Switch Joy-Cons
* Nintendo Switch Pro Controller
* DualShock 3 controller
* DualShock 4 controller
* DualSense controller

Please note that as of right now only Nintendo controllers were tested. DualShock
and DualSense *should* work - feedback would be very welcome.

## Configuration

No configuration is required to get started - just run the resulting binary and
it will expose all supported controllers!

However, if you want to tweak controller orientations, run server on a different
port, or use over four controllers at once by running multiple servers on
different ports, it's possible to do so by providing a config file. See
[example config](ExampleConfig.ini) for syntax and full list of supported options.

## Quick build guide

```bash
git clone --recursive https://github.com/v1993/evdevhook2.git
cd evdevhook2
meson --buildtype=release -Db_lto=true --prefix=/usr build
ninja -C build
# Optional
ninja -C build install
```

### Updating
```bash
cd evdevhook2
git pull
git submodule update --recursive --init
ninja -C build
# Optional
ninja -C build install
```

## Dependencies
* libudev
* libevdev
* GLib 2.50+
* zlib
* Vala 0.56+ and libgee-0.8 (Ubuntu and derivatives should use [Vala Next PPA](https://launchpad.net/~vala-team/+archive/ubuntu/next))
* meson and ninja
* GCC/Clang

