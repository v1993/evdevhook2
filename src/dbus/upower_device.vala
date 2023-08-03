namespace UPower {

	[DBus (name = "org.freedesktop.UPower.Device", timeout = 5000)]
	public interface Device : GLib.Object {

		[DBus (name = "Refresh")]
		public abstract async void refresh() throws DBusError, IOError;

		[DBus (name = "GetHistory")]
		public abstract async DeviceDataStruct[] get_history(string type, uint timespan, uint resolution) throws DBusError, IOError;

		[DBus (name = "GetStatistics")]
		public abstract async DeviceDataStruct2[] get_statistics(string type) throws DBusError, IOError;

		[DBus (name = "NativePath")]
		public abstract string native_path { owned get; }

		[DBus (name = "Vendor")]
		public abstract string vendor { owned get; }

		[DBus (name = "Model")]
		public abstract string model { owned get; }

		[DBus (name = "Serial")]
		public abstract string serial { owned get; }

		[DBus (name = "UpdateTime")]
		public abstract uint64 update_time {  get; }

		//[DBus (name = "Type")]
		//public abstract uint type {  get; }

		[DBus (name = "PowerSupply")]
		public abstract bool power_supply {  get; }

		[DBus (name = "HasHistory")]
		public abstract bool has_history {  get; }

		[DBus (name = "HasStatistics")]
		public abstract bool has_statistics {  get; }

		[DBus (name = "Online")]
		public abstract bool online {  get; }

		[DBus (name = "Energy")]
		public abstract double energy {  get; }

		[DBus (name = "EnergyEmpty")]
		public abstract double energy_empty {  get; }

		[DBus (name = "EnergyFull")]
		public abstract double energy_full {  get; }

		[DBus (name = "EnergyFullDesign")]
		public abstract double energy_full_design {  get; }

		[DBus (name = "EnergyRate")]
		public abstract double energy_rate {  get; }

		[DBus (name = "Voltage")]
		public abstract double voltage {  get; }

		[DBus (name = "ChargeCycles")]
		public abstract int charge_cycles {  get; }

		[DBus (name = "Luminosity")]
		public abstract double luminosity {  get; }

		[DBus (name = "TimeToEmpty")]
		public abstract int64 time_to_empty {  get; }

		[DBus (name = "TimeToFull")]
		public abstract int64 time_to_full {  get; }

		[DBus (name = "Percentage")]
		public abstract double percentage {  get; }

		[DBus (name = "Temperature")]
		public abstract double temperature {  get; }

		[DBus (name = "IsPresent")]
		public abstract bool is_present {  get; }

		[DBus (name = "State")]
		public abstract uint state {  get; }

		[DBus (name = "IsRechargeable")]
		public abstract bool is_rechargeable {  get; }

		[DBus (name = "Capacity")]
		public abstract double capacity {  get; }

		[DBus (name = "Technology")]
		public abstract uint technology {  get; }

		[DBus (name = "WarningLevel")]
		public abstract uint warning_level {  get; }

		[DBus (name = "BatteryLevel")]
		public abstract uint battery_level {  get; }

		[DBus (name = "IconName")]
		public abstract string icon_name { owned get; }
	}

	public struct DeviceDataStruct2 {
		public double attr1;
		public double attr2;
	}

	public struct DeviceDataStruct {
		public uint attr1;
		public double attr2;
		public uint attr3;
	}
}
