/* main.vala
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

using Evdevhook;

extern const string EV_VERSION;

[SingleInstance]
class EVApplication : Application {
	private bool exit_scheduled = false;
	private Config config;

	public Server? server;

	construct {
		application_id = "org.v1993.evdevhook2";
		flags = ApplicationFlags.NON_UNIQUE | ApplicationFlags.HANDLES_OPEN;

		config = new Config();

		OptionEntry[] options = {
			{ "version", 'v', NONE, NONE, null, "Print application version and exit" },
			{null}
		};

		add_main_option_entries(options);
		set_option_context_parameter_string("[config-file.ini]");
		set_option_context_summary("""Summary:
Cemuhook UDP motion server for devices with modern drivers on Linux.""");
		set_option_context_description("""
Copyright 2023 v1993 <v19930312@gmail.com>
This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.""");
	}
	
	public override void startup() {
		base.startup();
		try {
			config.init_device_types();
		} catch(Error e) {
			print("Failed to load config for device types! %s\n", e.message);
			Process.exit(1);
		}
	}

	public override void activate() {
		try {
			hold();
			server = new Server(config.port);
		} catch(Error e) {
			print("Failed to start server: %s\n", e.message);
			return;
		}
	}

	public override void open(File[] files, string hint) {
		if (files.length != 1) {
			print("Zero or one config files must be provided.\n");
			Process.exit(1);
		}

		try {
			config.load_device_config(files[0].get_path());
		} catch (Error e) {
			print("Error lodaing config file: %s\n", e.message);
			return;
		}

		if (config.allowlist_mode) {
			print("Allowlist mode enabled - only devices with a section in config will be served.\n");
		}

		activate();
	}

	public override int handle_local_options(VariantDict opt) {
		if (opt.lookup("version", "b", null)) {
			print("Evdevhook %s\n", EV_VERSION);
			return 0;
		}

		return -1;
	}

	public bool handle_shutdown_signal() {
		if (!exit_scheduled) {
			exit_scheduled = true;
			print("Exiting (press Ctrl+C again to force-exit)\n");
			server = null;
			release();
			return true;
		} else {
			print("Force quitting!\n");
			quit();
			return false;
		}
	}

	public static int main(string[] args) {
		var app = new EVApplication();

		GLib.Unix.signal_add(1, app.handle_shutdown_signal);
		GLib.Unix.signal_add(2, app.handle_shutdown_signal);
		GLib.Unix.signal_add(15, app.handle_shutdown_signal);
		app.run(args);

		return 0;
	}
}

