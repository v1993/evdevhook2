namespace UPower {

	[DBus (name = "org.freedesktop.UPower", timeout = 5000)]
	public interface Core : GLib.Object {

		[DBus (name = "EnumerateDevices")]
		public abstract async GLib.ObjectPath[] enumerate_devices() throws DBusError, IOError;

		[DBus (name = "GetDisplayDevice")]
		public abstract async GLib.ObjectPath get_display_device() throws DBusError, IOError;

		[DBus (name = "GetCriticalAction")]
		public abstract async string get_critical_action() throws DBusError, IOError;

		[DBus (name = "DeviceAdded")]
		public signal void device_added(GLib.ObjectPath device);

		[DBus (name = "DeviceRemoved")]
		public signal void device_removed(GLib.ObjectPath device);

		[DBus (name = "DaemonVersion")]
		public abstract string daemon_version { owned get; }

		[DBus (name = "OnBattery")]
		public abstract bool on_battery {  get; }

		[DBus (name = "LidIsClosed")]
		public abstract bool lid_is_closed {  get; }

		[DBus (name = "LidIsPresent")]
		public abstract bool lid_is_present {  get; }
	}
}
