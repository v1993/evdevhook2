# evdevhook2 configs

The idea is to split config into two files.

## Device class settings

Configures what devices are supported and how their axles map to standard orientation. Ships with application, is not supposed to be edited by end users unless they want to configure a new kind of device (which they should PR upstream anyways).

### Proposed syntax

```ini
# Nintendo Switch Pro Controller
[057e:2009]
AccelMapping=y+z-x+
GyroMapping=y-z-x+
GyroSensitivity=0.858
```

Section name corresponds to VID:PID pair in hexadecimal form while other options are described below:

* `AccelMapping` string - how accelerometer maps from evdev axles to DSU ones
* `GyroMapping` string (optional but recommended) - how gyroscope maps from evdev axles to DSU ones
* `GyroSensitivity` double (optional) - multiplier for gyrocope inputs, fixes issues faced by some drivers (notably hid_nintendo)

## Per-device settings

This is an optional file that can be supplied by users to further configure their devices. It closely corresponds to config file of linuxmotehook2.

### Proposed syntax

```ini
# Main section
[Evdevhook]
Port=26761
AllowlistMode=true

# Section for my left joycon when playing Citra
[D4:F0:57:3E:25:C1]
Orientation=sideways-left
```

Main section, named `Evdevhook`, contains the following options:

* `Port` integer (defaults to `26760`) - port to run server on
* `AllowlistMode` boolean (defaults to `false`) - only provide devices provided in config file; useful if >4 devices are present and multiple servers are required

Per-device sections, each named after device's `uniq` string (typically its MAC):

* `Orientation` enum - a final transformation to apply to device input, identical to that of linuxmotehook2 (copy description from its wiki)

## To consider - button/axis inputs?

With this rewrite it might be possible to supply button inputs in addition to motion data. How good of an idea it is is still debatable - unlike wiimotes, those devices have modern-day drivers and don't have associated issues, thus I'll only work on it if a good enough usecase is demonstrated. Required extensions to config files:

* Device class settings
* * `MainNodeName` string (optional) - name of node that provides button inputs
* * Possibly some sort of config to map buttons?
* Per-device settings, main section
* * `SendButtons` boolean (defaults to `false`) - if buttons should be sent for supported devices; deprecated due to latency issues

If this is to be implemented, an issue arises when it comes to combining data from two devices. As such, button data and motion data should be stored in temporary buffers (as part of a class). On their respective SYN packets data from that interface is copied into main field and DSU packet is generated.

## Further considerations - touchscreen inputs?

I don't own nor plan to get DS4/5 controllers, so this is unlikely to be implemented unless someone interested in such support shows up and is willing to collaborate. I'd be far more willing to implement this compared to button inputs, though, due to uniqueness of this interface.