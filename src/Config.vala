/* Config.vala
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

using Gee;

namespace Evdevhook {
	errordomain ConfigError {
		INVALID_DEVICE_TYPE_CONFIG
	}

	class DeviceTypeConfig: Object {
		public int axis_map[Linux.Input.ABS_RZ + 1];
		public bool axis_inversion[Linux.Input.ABS_RZ + 1];
		public float gyro_sensitivity;

		public void read_orientation(string str, int base_idx) throws Error {
			if (str.length != 6) throw new ConfigError.INVALID_DEVICE_TYPE_CONFIG("orientation string must be 6 characters long");

			for (uint8 i = 0; i < 3; ++i) {
				int evdev_axis;
				bool invert;

				switch (str[2 * i]) {
					case 'x':
					case 'X':
						evdev_axis = base_idx;
						break;
					case 'y':
					case 'Y':
						evdev_axis = base_idx + 1;
						break;
					case 'z':
					case 'Z':
						evdev_axis = base_idx + 2;
						break;
					default:
						throw new ConfigError.INVALID_DEVICE_TYPE_CONFIG("invalid letter in orientation specifier");
				}

				switch (str[2 * i + 1]) {
					case '+':
						invert = false;
						break;
					case '-':
						invert = true;
						break;
					default:
						throw new ConfigError.INVALID_DEVICE_TYPE_CONFIG("invalid sign in orientation specifier");
				}

				if (axis_map[evdev_axis] != -1)
					throw new ConfigError.INVALID_DEVICE_TYPE_CONFIG("trying to map same evdev device axis (%i) to multiple DSU ones", evdev_axis);

				axis_map[evdev_axis] = base_idx + i;
				axis_inversion[evdev_axis] = invert;
			}
		}

		construct {
			axis_map = {-1, -1, -1, -1, -1, -1};
			axis_inversion = {false, false, false, false, false, false};
			gyro_sensitivity = 1.0f;
		}
	}

	private class DeviceTypeIdentifier: Object, Hashable<DeviceTypeIdentifier> {
		public uint16 vid;
		public uint16 pid;

		public DeviceTypeIdentifier(uint16 vid, uint16 pid) {
			this.vid = vid;
			this.pid = pid;
		}

		public bool equal_to(DeviceTypeIdentifier o) {
			return vid == o.vid && pid == o.pid;
		}

		public uint hash() {
			return (((uint)vid) << 16) | (uint)pid;
		}
	}
	
	class DeviceConfig: Object {
		public Cemuhook.DeviceOrientation orientation = NORMAL;
	}

	[SingleInstance]
	class Config: Object {
		private const string MAIN_GROUP = "Evdevhook";

		private HashMap<DeviceTypeIdentifier, DeviceTypeConfig> device_type_configs;
		private HashMap<string, DeviceConfig> device_configs;

		public uint16 port { get; private set; default = 26760; }
		public bool allowlist_mode { get; private set; default = false; }

		construct {
			device_type_configs = new HashMap<DeviceTypeIdentifier, DeviceTypeConfig>();
			device_configs = new HashMap<string, DeviceConfig>();
		}

		public void init_device_types() throws Error {
			var kfile = new KeyFile();
			kfile.load_from_bytes(resources_lookup_data("/org/v1993/evdevhook2/DeviceTypes.ini", NONE), NONE);
			
			// There's no main config group in this file.
			// This config is not meant to be modified, so we terminate on errors.

			foreach (unowned string group in kfile.get_groups()) {
				var regex = /^([[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]]):([[:xdigit:]][[:xdigit:]][[:xdigit:]][[:xdigit:]])$/;
				MatchInfo minfo;
				if (!regex.match(group, 0, out minfo)) {
					throw new ConfigError.INVALID_DEVICE_TYPE_CONFIG("Unidentified device type configuration group %s", group);
				}

				var vid = (uint16)uint64.parse(minfo.fetch(1), 16);
				var pid = (uint16)uint64.parse(minfo.fetch(2), 16);
				var devtypeid = new DeviceTypeIdentifier(vid, pid);
				var devtypeconf = new DeviceTypeConfig();

				foreach (unowned string key in kfile.get_keys(group)) {
					switch(key) {
						case "AccelMapping":
							devtypeconf.read_orientation(kfile.get_string(group, key), Linux.Input.ABS_X);
							break;
						case "GyroMapping":
							devtypeconf.read_orientation(kfile.get_string(group, key), Linux.Input.ABS_RX);
							break;
						case "GyroSensitivity":
							devtypeconf.gyro_sensitivity = (float)kfile.get_double(group, key);
							break;
						default:
							throw new ConfigError.INVALID_DEVICE_TYPE_CONFIG("Unknown device type configuration key %s", key);
					}
				}

				device_type_configs[devtypeid] = devtypeconf;
			}
		}

		public void load_device_config(string path) throws Error {
			var kfile = new KeyFile();
			kfile.load_from_file(path, NONE);

			if (kfile.has_group(MAIN_GROUP)) {
				foreach (unowned string key in kfile.get_keys(MAIN_GROUP)) {
					switch(key) {
						case "Port":
							port = (uint16)kfile.get_uint64(MAIN_GROUP, key);
							break;
						case "AllowlistMode":
							allowlist_mode = kfile.get_boolean(MAIN_GROUP, key);
							break;
						default:
							warning("Unknown configuration key %s", key);
							break;
					}
				}
			}

			foreach (unowned string group in kfile.get_groups()) {
				if (group == MAIN_GROUP) {
					// Main configuration - already handled
					continue;
				}

				var devconf = new DeviceConfig();

				foreach (unowned string key in kfile.get_keys(group)) {
					switch(key) {
						case "Orientation":
							var orient = kfile.get_string(group, key);
							if (!Cemuhook.DeviceOrientation.try_parse(orient, out devconf.orientation)) {
								warning("Unknown orientation %s", orient);
							}
							break;
						default:
							warning("Unknown configuration key %s", key);
							break;
					}
				}

				device_configs[group] = (owned)devconf;
			}
		}

		public DeviceTypeConfig? get_device_type_config(uint16 vid, uint16 pid) {
			var devtypeid = new DeviceTypeIdentifier(vid, pid);
			return device_type_configs.has_key(devtypeid) ? device_type_configs[devtypeid] : null;
		}

		public DeviceConfig? get_device_config(string uniq) {
			if (device_configs.has_key(uniq)) {
				return device_configs[uniq];
			}

			return allowlist_mode ? null : new DeviceConfig();
		}
	}
}
