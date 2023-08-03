/* MainDevice.vala
 *
 * Copyright 2022 v1993 <v19930312@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Evdevhook {
	private uint64 uniq_to_mac(string uniq) {
		var regex = /^([[:xdigit:]][[:xdigit:]]):([[:xdigit:]][[:xdigit:]]):([[:xdigit:]][[:xdigit:]]):([[:xdigit:]][[:xdigit:]]):([[:xdigit:]][[:xdigit:]]):([[:xdigit:]][[:xdigit:]])$/;
		GLib.MatchInfo reginfo = null;
		if (!regex.match(uniq, 0, out reginfo) || reginfo == null) {
			// This is rather atypical but technically valid
			warning("Unable to parse uniq '%s' as mac - file a bug if it looks like one; using string hash as a fallback", uniq);
			return (0xACE0ull << 32) | uniq.hash();
		}

		var builder = new GLib.StringBuilder.sized(12);
		var matches = reginfo.fetch_all()[1:];

		foreach (unowned var substr in matches) {
			builder.append(substr);
		}

		return uint64.parse(builder.str, 16);
	}

	private Cemuhook.ConnectionType bus_type_to_cemuhook(int id_bustype) {
		switch(id_bustype) {
			case Linux.Input.BUS_USB:
				return USB;
			case Linux.Input.BUS_BLUETOOTH:
				return BLUETOOTH;
			default:
				return OTHER;
		}
	}

	private Cemuhook.BatteryStatus battery_state_to_cemuhook(uint state) {
		switch(state) {
			case 1:
				return CHARGING;
			case 4:
				return CHARGED;
			default:
				return NA;
		}
	}

	private Cemuhook.BatteryStatus battery_level_to_cemuhook(uint level) {
		switch(level) {
			case 3:
				return LOW;
			case 4:
				return DYING;
			case 6:
				return MEDIUM;
			case 7:
				return HIGH;
			case 8:
				return FULL;
			default:
				return NA;
		}
	}

	private Cemuhook.BatteryStatus battery_percentage_to_cemuhook(double percentage) {
		if (percentage == 0.0) {
			return NA;
		}

		if (percentage > 90.0) {
			return FULL;
		}

		if (percentage > 60.0) {
			return HIGH;
		}

		if (percentage > 30.0) {
			return MEDIUM;
		}

		if (percentage > 10.0) {
			return LOW;
		}

		return DYING;
	}

	sealed class EvdevCemuhookDevice: Object, Cemuhook.AbstractPhysicalDevice {
		private Evdev.Device dev;
		private IOChannel dev_iochan;
		private DeviceTypeConfig devtypeconf;
		private DeviceConfig devconf;

		private Cancellable cancellable = new Cancellable();

		private Cemuhook.DeviceType devtype = NO_MOTION;
		private Cemuhook.ConnectionType connection_type = OTHER;
		private Cemuhook.BatteryStatus battery_status = NA;
		private bool has_timestamp_event = false;
		private uint64 motion_timestamp = 0;
		private uint64 mac = 0;

		private int32 axis_center[Linux.Input.ABS_RZ + 1];
		private int32 axis_resolution[Linux.Input.ABS_RZ + 1];

		private float axis_state[Linux.Input.ABS_RZ + 1];

		public Cemuhook.DeviceOrientation orientation { get { return devconf.orientation; } }

		public EvdevCemuhookDevice(owned Evdev.Device _dev, owned IOChannel _dev_iochan, owned DeviceTypeConfig _devtypeconf, owned DeviceConfig _devconf) throws Error {
			dev = (owned)_dev;
			dev_iochan = (owned)_dev_iochan;
			devtypeconf = (owned)_devtypeconf;
			devconf = (owned)_devconf;
			axis_state = {0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f};

			mac = uniq_to_mac(dev.uniq);
			connection_type = bus_type_to_cemuhook(dev.id_bustype);
			has_timestamp_event = dev.has_event_code(Linux.Input.EV_MSC, Linux.Input.MSC_TIMESTAMP);
			
			{
				bool has_gyro = true;
				for (int code = Linux.Input.ABS_RX; code <= Linux.Input.ABS_RZ; ++code) {
					has_gyro = has_gyro && dev.has_event_code(Linux.Input.EV_ABS, code);
				}
				devtype = has_gyro ? Cemuhook.DeviceType.GYRO_FULL : Cemuhook.DeviceType.ACCELEROMETER_ONLY;
				var max_code = has_gyro ? Linux.Input.ABS_RZ : Linux.Input.ABS_Z;
				
				for (int code = Linux.Input.ABS_X; code <= max_code; ++code) {
					axis_center[code] = (int32)(((int64)dev.get_abs_minimum(code) + (int64)dev.get_abs_maximum(code)) / 2);
					axis_resolution[code] = dev.get_abs_resolution(code);
				}
			}

			IOFunc cb = process_incoming;
			dev_iochan.add_watch(IN | HUP, cb);
			if (new Config().use_upower) {
				battery_reader.begin();
			}
		}

		private bool process_incoming(IOChannel source, IOCondition condition) {
			if (HUP in condition) {
				destroy();
				return Source.REMOVE;
			}

			try {
				bool sync_mode = false;
				while(true) {
					Evdev.ReadStatus status;
					var? event = dev.next_event(sync_mode ? Evdev.ReadFlag.SYNC : Evdev.ReadFlag.NORMAL, out status);

					if (event == null) {
						if (sync_mode) {
							// We're done syncing; switch to normal mode
							sync_mode = false;
							continue;
						} else {
							// All events processed
							break;
						}
					}

					if (status == SYNC) {
						// Got SYN_DROPPED; use libevdev's sync mode to compensate
						sync_mode = true;
						continue;
					}
					
					switch(event.type) {
						case Linux.Input.EV_ABS:
							process_axis(event.code, event.value);
							break;
						case Linux.Input.EV_MSC:
							if (event.code == Linux.Input.MSC_TIMESTAMP) {
								// All of this code just to handle wrapping
								int32 new_timestamp = event.value;
								const uint64 sign_bit = 1ull << 31;
								int32 short_old_value = (int32)(motion_timestamp & ~sign_bit);
								if (short_old_value > new_timestamp) {
									// Wrapping has happened; add value of first lost bit
									motion_timestamp += sign_bit;
								}
								motion_timestamp = (motion_timestamp & ~(sign_bit - 1)) | (uint64)new_timestamp;
							}
							break;
						case Linux.Input.EV_SYN:
							if (event.code == Linux.Input.SYN_REPORT) {
								if (!has_timestamp_event) {
									motion_timestamp = (uint64)event.input_event_sec * 1000000 + (uint64)event.input_event_usec;
								}
								updated();
							}
							break;
					}
				};
			} catch (Error e) {
				warning("Error when reading event: %s, disconnecting!\n", e.message);
				destroy();
				return Source.REMOVE;
			}

			return Source.CONTINUE;
		}

		private void process_axis(uint16 axis, int32 value_raw) {
			if (axis <= Linux.Input.ABS_RZ) {
				var idx = devtypeconf.axis_map[axis];
				if (idx != -1) {
					int64 value_fixed = (int64)value_raw - (int64)axis_center[axis];
					if (devtypeconf.axis_inversion[axis]) {
						value_fixed *= -1ll;
					}

					axis_state[idx] = (float)value_fixed / axis_resolution[axis];
					if (axis >= Linux.Input.ABS_RX) {
						axis_state[idx] *= devtypeconf.gyro_sensitivity;
					}
				}
			}
		}

		private void destroy() {
			print("Device %s disconnected\n", dev.uniq);
			cancellable.cancel();
			disconnected();
		}

		/*
		 * It's worth mentioning that access to members of proxy objects results in synchronous dbus calls.
		 * While this does not seem to cause issues in practice, it theoretically might. If it does,
		 * use org.freedesktop.DBus.Properties interface directly instead of relying on wrappers.
		 */
		private async void battery_reader() {
			try {
				UPower.Device battery = null;
				var core = yield Bus.get_proxy<UPower.Core>(SYSTEM, "org.freedesktop.UPower", "/org/freedesktop/UPower", NONE, cancellable);
				// Retry a few times with a pause to ensure that UPower has time to initialize the device
				for (int i = 0; battery == null && i < 4; ++i) {
					cancellable.set_error_if_cancelled();
					foreach (var devpath in yield core.enumerate_devices()) {
						var upower_dev = yield Bus.get_proxy<UPower.Device>(SYSTEM, "org.freedesktop.UPower", devpath, NONE, cancellable);
						if (upower_dev.serial == dev.uniq) {
							battery = (owned)upower_dev;
							break;
						}
					}
					GLib.Timeout.add_once(500, () => { battery_reader.callback(); });
					yield;
				}

				if (battery == null) {
					return;
				}

				while(!cancellable.is_cancelled()) {
					battery_status = battery_state_to_cemuhook(battery.state);
					if (battery_status == NA) {
						battery_status = battery_level_to_cemuhook(battery.battery_level);
					}
					if (battery_status == NA) {
						battery_status = battery_percentage_to_cemuhook(battery.percentage);
					}
					GLib.Timeout.add_once(5000, () => { battery_reader.callback(); });
					yield;
				}
			} catch(IOError.CANCELLED e) {
				// Expected
			} catch(Error e) {
				warning("Error in battery reader: %s\n", e.message);
			} finally {
				battery_status = NA;
			}
		}

		public Cemuhook.DeviceType get_device_type() { return devtype; }
		public Cemuhook.ConnectionType get_connection_type() { return connection_type; }
		public Cemuhook.BatteryStatus get_battery() { return battery_status; }

		public uint64 get_mac() { return mac; }

		public Cemuhook.BaseData get_base_inputs() {
			return Cemuhook.BaseData() {
				buttons = 0,
				left_x = Cemuhook.STICK_NEUTRAL,
				left_y = Cemuhook.STICK_NEUTRAL,
				right_x = Cemuhook.STICK_NEUTRAL,
				right_y = Cemuhook.STICK_NEUTRAL
			};
		}

		public uint64 get_motion_timestamp() {
			return motion_timestamp;
		}

		public Cemuhook.MotionData get_accelerometer() {
			return Cemuhook.MotionData() {
				x = axis_state[0],
				y = axis_state[1],
				z = axis_state[2],
			};
		}

		public Cemuhook.MotionData get_gyro() {
			return Cemuhook.MotionData() {
				x = axis_state[3],
				y = axis_state[4],
				z = axis_state[5],
			};
		}
	}
}
