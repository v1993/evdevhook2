/*
 * Copyright (c) 2023 Valeri Ochinski <v19930312@gmail.com>
 *
 * This work is free software available under MIT License.
 *
 * Please note that this file is extremely incomplete - only stuff used by us is bound.
 */

[CCode (cheader_filename = "libevdev/libevdev.h", cprefix = "libevdev_", lower_case_cprefix = "libevdev_")]
namespace Evdev {
	namespace Utils {
		// This is pretty stupid
		private int error_check(int ret) throws GLib.IOError {
			if (ret >= 0) return ret;
			throw new GLib.IOError.FAILED(GLib.strerror(-ret));
		}
	}

	[Flags]
	[CCode (cname = "enum libevdev_read_flag", has_type_id = false)]
	enum ReadFlag {
		SYNC,
		NORMAL,
		FORCE_SYNC,
		BLOCKING
	}

	[CCode (cname = "enum libevdev_read_status", has_type_id = false)]
	enum ReadStatus {
		SUCCESS,
		SYNC
	}

	[CCode (cname = "struct libevdev", free_function = "libevdev_free", cprefix = "libevdev_", lower_case_cprefix = "libevdev_")]
	[Compact]
	class Device {
		public Device();
		[CCode (cname = "libevdev_new_from_fd_vala")]
		public Device.from_fd(int fd) throws GLib.IOError {
			this();
			set_fd(fd);
		}

		[CCode (cname = "libevdev_set_fd")]
		private int _set_fd(int fd);

		[CCode (cname = "libevdev_set_fd_vala")]
		public void set_fd(int fd) throws GLib.IOError {
			Utils.error_check(_set_fd(fd));
		}
		
		int get_fd();

		public string name { get; }
		public int id_product { get; }
		public int id_vendor { get; }
		public string uniq { get; }
		public string phys { get; }
		public int id_bustype { get; }

		public bool has_property(uint prop);
		public bool has_event_code(uint type, uint code);

		// Goes unused in favor of individual fetchers below
		public unowned Linux.Input.AbsInfo? get_abs_info(uint code);
		
		public int get_abs_maximum(uint code);
		public int get_abs_minimum(uint code);
		public int get_abs_resolution(uint code);

		[CCode (cname = "libevdev_next_event")]
		private int _next_event(uint flags, out Linux.Input.Event ev);
		
		[CCode (cname = "libevdev_next_event_vala")]
		public Linux.Input.Event? next_event(ReadFlag flags, out ReadStatus status) throws GLib.IOError {
			Linux.Input.Event ev;
			int res = _next_event(flags, out ev);
			if (res == -Posix.EAGAIN) {
				status = SUCCESS; // To make Vala happy
				return null;
			}
			status = (ReadStatus)Utils.error_check(res);
			return ev;
		}
	}
}
