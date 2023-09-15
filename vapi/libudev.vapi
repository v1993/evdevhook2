/*
 * Copyright (c) 2023 Valeri Ochinski <v19930312@gmail.com>
 *
 * This work is free software available under MIT License.
 *
 * Please note that this file is extremely incomplete - only stuff used by us is bound.
 */ 

[CCode (cheader_filename = "libudev.h", cprefix = "udev_", lower_case_cprefix = "udev_")]
namespace Udev {
	[CCode (cname = "struct udev", ref_function = "udev_ref", unref_function = "udev_unref", cprefix = "udev_", lower_case_cprefix = "udev_")]
	[Compact]
	class Context {
		public Context();
	}

	[CCode (cname = "struct udev_list_entry", free_function = "")]
	[Compact]
	class ListEntry {
		private ListEntry();

		public ListEntry? next { get; }
		public string? name { get; }
		public string? value { get; }
	}

	[CCode (cname = "struct udev_device", ref_function = "udev_device_ref", unref_function = "udev_device_unref")]
	[Compact]
	class Device {
		private Device();
		public Device.from_syspath(Context ctx, string syspath);

		public string? devnode { get; }
		public string? sysname { get; }
		public ListEntry? properties_list_entry { get; }
		public ListEntry? tags_list_entry { get; }

		public unowned string? get_property_value(string key);
		public unowned string? get_sysattr_value(string key);
		public unowned Device? get_parent_with_subsystem_devtype(string? subsystem, string? devtype);
	}

	[CCode (cname = "struct udev_enumerate", ref_function = "udev_enumerate_ref", unref_function = "udev_enumerate_unref")]
	[Compact]
	class Enumerate {
		public Enumerate(Context ctx);

		public int add_match_subsystem(string subsystem);
		public int scan_devices();
		public ListEntry? list_entry { get; }
	}

	[CCode (cname = "struct udev_monitor", ref_function = "udev_monitor_ref", unref_function = "udev_monitor_unref")]
	[Compact]
	class Monitor {
		[CCode (cname = "udev_monitor_new_from_netlink")]
		public Monitor(Context ctx, string name);

		public int fd { get; }

		public int filter_add_match_subsystem_devtype(string? subsystem, string? devtype);
		public int enable_receiving();
		public Device? receive_device();
	}
}
