/* Server.vala
 *
 * Copyright 2023 v1993 <v19930312@gmail.com>
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
	sealed class Server: Cemuhook.Server {
		private Udev.Context uctx;
		private Udev.Monitor monitor;

		private IOSource monitor_source;

		public Server(uint16 port = 26760, MainContext? context = null) throws GLib.Error {
			base(port, context);
			uctx = new Udev.Context();
			new EVApplication().hold();

			monitor = new Udev.Monitor(uctx, "udev");
			assert_nonnull(monitor);
			monitor.filter_add_match_subsystem_devtype("input", null);
			monitor_source = new IOSource(new IOChannel.unix_new(monitor.fd), IN);
			// The following produces a warning, and it is intended
			IOFunc cb = monitor_callback;
			monitor_source.set_callback(cb);
			monitor_source.attach(context);

			// Add devices connected on startup
			var uenum = new Udev.Enumerate(uctx);
			uenum.add_match_subsystem("input");
			uenum.scan_devices();
			// Do this here to minimize chances of missing a device
			monitor.enable_receiving();

			for (unowned var? entry = uenum.list_entry; entry != null; entry = entry.next) {
				var udevdev = new Udev.Device.from_syspath(uctx, entry.name);
				if (udevdev != null) {
					process_new_device(udevdev);
				}
			}
		}

		~Server() {
			new EVApplication().release();
		}

		private bool monitor_callback() {
			for (var? udevdev = monitor.receive_device(); udevdev != null; udevdev = monitor.receive_device()) {
				process_new_device(udevdev);
			}

			return Source.CONTINUE;
		}

		private void process_new_device(Udev.Device udevdev) {
			try {
				if (udevdev.get_property_value("ID_INPUT_ACCELEROMETER") != "1") {
					return;
				}

				// DualSense for some reason creates a js device for accelerometer
				// So only open eventXX devices and avoid a warning when evdev fails
				if (udevdev.sysname == null || !udevdev.sysname.has_prefix("event")) {
					return;
				}

				if (udevdev.devnode == null) {
					return;
				}

				// We wrap fd into IOChannel both for watching and closing it
				IOChannel iochan;
				{
					int fd = Posix.open(udevdev.devnode, Posix.O_RDONLY | Posix.O_NONBLOCK);
					if (fd == -1) return;

					iochan = new IOChannel.unix_new(fd);
					iochan.set_close_on_unref(true);
				}

				var dev = new Evdev.Device.from_fd(iochan.unix_get_fd());
				if (!dev.has_property(Linux.Input.INPUT_PROP_ACCELEROMETER)) {
					warning("Device %s reported as accelerometer by udev but not evdev - ignoring", dev.name);
					return;
				}

				var conf = new Config();
				var? devtypeconf = conf.get_device_type_config((uint16)dev.id_vendor, (uint16)dev.id_product);
				var? devconf = conf.get_device_config(dev.uniq);

				if (devtypeconf != null && devconf != null) {
					for (int code = Linux.Input.ABS_X; code <= Linux.Input.ABS_Z; ++code) {
						if (!dev.has_event_code(Linux.Input.EV_ABS, code)) {
							warning("Device %s reported as accelerometer but lacks required event codes - ignoring", dev.name);
							return;
						}
					}

					print("Found device %s (unique identifier '%s') - connecting... ", dev.name, dev.uniq);
					add_device(new EvdevCemuhookDevice((owned)dev, (owned)iochan, (owned)devtypeconf, (owned)devconf));
					print("done!\n");
				}
			} catch(Cemuhook.ServerError.SERVER_FULL e) {
				warning("Unable to add device - server full. If you need over four devices at once you can run two servers on different ports in allowlist mode.");
			} catch(Error e) {
				warning("Error when opening device: %s", e.message);
			}
		}
	}
}
