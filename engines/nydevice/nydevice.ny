# ============================================================
# NYDEVICE - Nyx Hardware Access Engine
# ============================================================
# Production-grade hardware abstraction for USB, serial,
# Bluetooth, GPIO, GPU compute, sensor fusion, HID devices,
# and system hardware enumeration. Cross-platform native access.

let VERSION = "1.0.0";

# ============================================================
# DEVICE ENUMERATION
# ============================================================

pub mod enumeration {
    pub class DeviceInfo {
        pub let id: String;
        pub let name: String;
        pub let vendor_id: Int;
        pub let product_id: Int;
        pub let serial_number: String;
        pub let device_type: String;
        pub let bus: String;
        pub let connected: Bool;
        pub let driver: String;

        pub fn display(self) -> String {
            return self.name + " [" + self.id + "] (" + self.bus + ")";
        }
    }

    pub class DeviceManager {
        pub let devices: Map<String, DeviceInfo>;
        pub let on_connect: Fn?;
        pub let on_disconnect: Fn?;
        pub let watching: Bool;

        pub fn new() -> Self {
            return Self {
                devices: {},
                on_connect: null,
                on_disconnect: null,
                watching: false
            };
        }

        pub fn enumerate(self) -> List<DeviceInfo> {
            let raw = native_device_enumerate();
            self.devices = {};
            for d in raw {
                self.devices[d.id] = d;
            }
            let result = [];
            for entry in self.devices.entries() {
                result.push(entry.value);
            }
            return result;
        }

        pub fn find_by_type(self, device_type: String) -> List<DeviceInfo> {
            let results = [];
            for entry in self.devices.entries() {
                if entry.value.device_type == device_type {
                    results.push(entry.value);
                }
            }
            return results;
        }

        pub fn find_by_vendor(self, vendor_id: Int) -> List<DeviceInfo> {
            let results = [];
            for entry in self.devices.entries() {
                if entry.value.vendor_id == vendor_id {
                    results.push(entry.value);
                }
            }
            return results;
        }

        pub fn find_by_id(self, id: String) -> DeviceInfo? {
            return self.devices[id];
        }

        pub fn watch(self) {
            self.watching = true;
            native_device_watch(|event_type, device| {
                if event_type == "connect" {
                    self.devices[device.id] = device;
                    if self.on_connect != null {
                        self.on_connect(device);
                    }
                } else if event_type == "disconnect" {
                    self.devices.remove(device.id);
                    if self.on_disconnect != null {
                        self.on_disconnect(device);
                    }
                }
            });
        }

        pub fn stop_watching(self) {
            self.watching = false;
            native_device_stop_watch();
        }
    }
}

# ============================================================
# USB
# ============================================================

pub mod usb {
    pub class USBDevice {
        pub let handle: Int;
        pub let vendor_id: Int;
        pub let product_id: Int;
        pub let manufacturer: String;
        pub let product: String;
        pub let serial: String;
        pub let class_code: Int;
        pub let subclass_code: Int;

        pub fn open(vendor_id: Int, product_id: Int) -> Self? {
            let handle = native_usb_open(vendor_id, product_id);
            if handle < 0 { return null; }
            let info = native_usb_device_info(handle);
            return Self {
                handle: handle,
                vendor_id: vendor_id,
                product_id: product_id,
                manufacturer: info.manufacturer,
                product: info.product,
                serial: info.serial,
                class_code: info.class_code,
                subclass_code: info.subclass_code
            };
        }

        pub fn open_by_serial(serial: String) -> Self? {
            let handle = native_usb_open_serial(serial);
            if handle < 0 { return null; }
            let info = native_usb_device_info(handle);
            return Self {
                handle: handle,
                vendor_id: info.vendor_id,
                product_id: info.product_id,
                manufacturer: info.manufacturer,
                product: info.product,
                serial: serial,
                class_code: info.class_code,
                subclass_code: info.subclass_code
            };
        }

        pub fn claim_interface(self, interface_num: Int) -> Bool {
            return native_usb_claim_interface(self.handle, interface_num);
        }

        pub fn release_interface(self, interface_num: Int) {
            native_usb_release_interface(self.handle, interface_num);
        }

        pub fn bulk_transfer_out(self, endpoint: Int, data: Bytes, timeout_ms: Int) -> Int {
            return native_usb_bulk_out(self.handle, endpoint, data, timeout_ms);
        }

        pub fn bulk_transfer_in(self, endpoint: Int, length: Int, timeout_ms: Int) -> Bytes {
            return native_usb_bulk_in(self.handle, endpoint, length, timeout_ms);
        }

        pub fn control_transfer(self, request_type: Int, request: Int, value: Int, index: Int, data: Bytes, timeout_ms: Int) -> Int {
            return native_usb_control_transfer(self.handle, request_type, request, value, index, data, timeout_ms);
        }

        pub fn interrupt_transfer_in(self, endpoint: Int, length: Int, timeout_ms: Int) -> Bytes {
            return native_usb_interrupt_in(self.handle, endpoint, length, timeout_ms);
        }

        pub fn interrupt_transfer_out(self, endpoint: Int, data: Bytes, timeout_ms: Int) -> Int {
            return native_usb_interrupt_out(self.handle, endpoint, data, timeout_ms);
        }

        pub fn set_configuration(self, config: Int) -> Bool {
            return native_usb_set_configuration(self.handle, config);
        }

        pub fn reset(self) {
            native_usb_reset(self.handle);
        }

        pub fn close(self) {
            native_usb_close(self.handle);
        }
    }

    pub fn list_devices() -> List<enumeration.DeviceInfo> {
        return native_usb_list();
    }
}

# ============================================================
# SERIAL PORT
# ============================================================

pub mod serial {
    pub let PARITY_NONE = "none";
    pub let PARITY_ODD = "odd";
    pub let PARITY_EVEN = "even";
    pub let STOP_BITS_ONE = 1;
    pub let STOP_BITS_TWO = 2;
    pub let FLOW_NONE = "none";
    pub let FLOW_HARDWARE = "hardware";
    pub let FLOW_SOFTWARE = "software";

    pub class SerialConfig {
        pub let baud_rate: Int;
        pub let data_bits: Int;
        pub let parity: String;
        pub let stop_bits: Int;
        pub let flow_control: String;
        pub let timeout_ms: Int;

        pub fn new(baud_rate: Int) -> Self {
            return Self {
                baud_rate: baud_rate,
                data_bits: 8,
                parity: PARITY_NONE,
                stop_bits: STOP_BITS_ONE,
                flow_control: FLOW_NONE,
                timeout_ms: 1000
            };
        }

        pub fn with_parity(self, parity: String) -> Self {
            self.parity = parity;
            return self;
        }

        pub fn with_flow(self, flow: String) -> Self {
            self.flow_control = flow;
            return self;
        }
    }

    pub class SerialPort {
        pub let handle: Int;
        pub let port_name: String;
        pub let config: SerialConfig;
        pub let open_state: Bool;

        pub fn open(port_name: String, config: SerialConfig) -> Self? {
            let handle = native_serial_open(port_name, config);
            if handle < 0 { return null; }
            return Self {
                handle: handle,
                port_name: port_name,
                config: config,
                open_state: true
            };
        }

        pub fn write(self, data: Bytes) -> Int {
            return native_serial_write(self.handle, data);
        }

        pub fn write_string(self, text: String) -> Int {
            return native_serial_write(self.handle, Bytes::from_string(text));
        }

        pub fn read(self, max_bytes: Int) -> Bytes {
            return native_serial_read(self.handle, max_bytes);
        }

        pub fn read_line(self) -> String {
            return native_serial_read_line(self.handle);
        }

        pub fn read_until(self, delimiter: Int) -> Bytes {
            return native_serial_read_until(self.handle, delimiter);
        }

        pub fn available(self) -> Int {
            return native_serial_available(self.handle);
        }

        pub fn flush(self) {
            native_serial_flush(self.handle);
        }

        pub fn set_dtr(self, enabled: Bool) {
            native_serial_set_dtr(self.handle, enabled);
        }

        pub fn set_rts(self, enabled: Bool) {
            native_serial_set_rts(self.handle, enabled);
        }

        pub fn get_cts(self) -> Bool {
            return native_serial_get_cts(self.handle);
        }

        pub fn get_dsr(self) -> Bool {
            return native_serial_get_dsr(self.handle);
        }

        pub fn on_data(self, callback: Fn) {
            native_serial_on_data(self.handle, callback);
        }

        pub fn close(self) {
            native_serial_close(self.handle);
            self.open_state = false;
        }
    }

    pub fn list_ports() -> List<String> {
        return native_serial_list_ports();
    }
}

# ============================================================
# BLUETOOTH
# ============================================================

pub mod bluetooth {
    pub let STATE_OFF = "off";
    pub let STATE_ON = "on";
    pub let STATE_SCANNING = "scanning";

    pub class BluetoothDevice {
        pub let address: String;
        pub let name: String;
        pub let rssi: Int;
        pub let paired: Bool;
        pub let connected: Bool;
        pub let device_type: String;
        pub let services: List<String>;

        pub fn connect(self) -> Bool {
            return native_bt_connect(self.address);
        }

        pub fn disconnect(self) {
            native_bt_disconnect(self.address);
            self.connected = false;
        }

        pub fn pair(self) -> Bool {
            return native_bt_pair(self.address);
        }
    }

    pub class BluetoothAdapter {
        pub let state: String;
        pub let name: String;
        pub let address: String;

        pub fn new() -> Self {
            let info = native_bt_adapter_info();
            return Self {
                state: info.state,
                name: info.name,
                address: info.address
            };
        }

        pub fn is_available(self) -> Bool {
            return self.state != STATE_OFF;
        }

        pub fn enable(self) -> Bool {
            return native_bt_enable();
        }

        pub fn scan(self, duration_ms: Int, callback: Fn) {
            self.state = STATE_SCANNING;
            native_bt_scan(duration_ms, |device| {
                callback(device);
            });
            self.state = STATE_ON;
        }

        pub fn stop_scan(self) {
            native_bt_stop_scan();
            self.state = STATE_ON;
        }

        pub fn paired_devices(self) -> List<BluetoothDevice> {
            return native_bt_paired_devices();
        }
    }

    pub class BLECharacteristic {
        pub let uuid: String;
        pub let service_uuid: String;
        pub let properties: List<String>;

        pub fn read(self, device_address: String) -> Bytes {
            return native_ble_read(device_address, self.service_uuid, self.uuid);
        }

        pub fn write(self, device_address: String, data: Bytes) -> Bool {
            return native_ble_write(device_address, self.service_uuid, self.uuid, data);
        }

        pub fn subscribe(self, device_address: String, callback: Fn) {
            native_ble_subscribe(device_address, self.service_uuid, self.uuid, callback);
        }

        pub fn unsubscribe(self, device_address: String) {
            native_ble_unsubscribe(device_address, self.service_uuid, self.uuid);
        }
    }

    pub class BLEService {
        pub let uuid: String;
        pub let characteristics: List<BLECharacteristic>;

        pub fn discover(device_address: String) -> List<BLEService> {
            return native_ble_discover_services(device_address);
        }
    }
}

# ============================================================
# HID (Human Interface Devices)
# ============================================================

pub mod hid {
    pub class HIDDevice {
        pub let handle: Int;
        pub let vendor_id: Int;
        pub let product_id: Int;
        pub let product_name: String;
        pub let usage_page: Int;
        pub let usage: Int;

        pub fn open(vendor_id: Int, product_id: Int) -> Self? {
            let handle = native_hid_open(vendor_id, product_id);
            if handle < 0 { return null; }
            let info = native_hid_device_info(handle);
            return Self {
                handle: handle,
                vendor_id: vendor_id,
                product_id: product_id,
                product_name: info.product_name,
                usage_page: info.usage_page,
                usage: info.usage
            };
        }

        pub fn write(self, data: Bytes) -> Int {
            return native_hid_write(self.handle, data);
        }

        pub fn read(self, max_length: Int) -> Bytes {
            return native_hid_read(self.handle, max_length);
        }

        pub fn read_timeout(self, max_length: Int, timeout_ms: Int) -> Bytes {
            return native_hid_read_timeout(self.handle, max_length, timeout_ms);
        }

        pub fn get_feature_report(self, report_id: Int, length: Int) -> Bytes {
            return native_hid_get_feature_report(self.handle, report_id, length);
        }

        pub fn send_feature_report(self, data: Bytes) -> Int {
            return native_hid_send_feature_report(self.handle, data);
        }

        pub fn set_nonblocking(self, nonblocking: Bool) {
            native_hid_set_nonblocking(self.handle, nonblocking);
        }

        pub fn close(self) {
            native_hid_close(self.handle);
        }
    }

    pub fn list_devices() -> List<enumeration.DeviceInfo> {
        return native_hid_list();
    }
}

# ============================================================
# GPU COMPUTE
# ============================================================

pub mod gpu_compute {
    pub class ComputeDevice {
        pub let id: Int;
        pub let name: String;
        pub let vendor: String;
        pub let vram_mb: Int;
        pub let compute_units: Int;
        pub let max_workgroup_size: Int;

        pub fn list() -> List<ComputeDevice> {
            return native_gpu_compute_list_devices();
        }

        pub fn default_device() -> ComputeDevice? {
            let devices = Self::list();
            if devices.len() == 0 { return null; }
            return devices[0];
        }
    }

    pub class ComputeBuffer {
        pub let id: Int;
        pub let size_bytes: Int;
        pub let usage: String;

        pub fn new(device_id: Int, size_bytes: Int, usage: String) -> Self {
            let id = native_gpu_buffer_create(device_id, size_bytes, usage);
            return Self { id: id, size_bytes: size_bytes, usage: usage };
        }

        pub fn upload(self, data: Bytes) {
            native_gpu_buffer_upload(self.id, data);
        }

        pub fn download(self) -> Bytes {
            return native_gpu_buffer_download(self.id);
        }

        pub fn destroy(self) {
            native_gpu_buffer_destroy(self.id);
        }
    }

    pub class ComputeShader {
        pub let id: Int;
        pub let name: String;

        pub fn from_source(device_id: Int, name: String, source: String) -> Self {
            let id = native_gpu_shader_compile(device_id, source);
            return Self { id: id, name: name };
        }

        pub fn destroy(self) {
            native_gpu_shader_destroy(self.id);
        }
    }

    pub class ComputePipeline {
        pub let device_id: Int;
        pub let shader: ComputeShader;
        pub let bindings: Map<Int, ComputeBuffer>;

        pub fn new(device_id: Int, shader: ComputeShader) -> Self {
            return Self {
                device_id: device_id,
                shader: shader,
                bindings: {}
            };
        }

        pub fn bind(self, slot: Int, buffer: ComputeBuffer) -> Self {
            self.bindings[slot] = buffer;
            return self;
        }

        pub fn dispatch(self, x: Int, y: Int, z: Int) {
            let binding_ids = {};
            for entry in self.bindings.entries() {
                binding_ids[entry.key] = entry.value.id;
            }
            native_gpu_dispatch(self.device_id, self.shader.id, binding_ids, x, y, z);
        }

        pub fn dispatch_indirect(self, buffer: ComputeBuffer) {
            native_gpu_dispatch_indirect(self.device_id, self.shader.id, buffer.id);
        }
    }
}

# ============================================================
# SENSORS
# ============================================================

pub mod sensors {
    pub class Accelerometer {
        pub let x: Float;
        pub let y: Float;
        pub let z: Float;

        pub fn read() -> Self {
            let data = native_sensor_accel_read();
            return Self { x: data.x, y: data.y, z: data.z };
        }

        pub fn on_change(interval_ms: Int, callback: Fn) {
            native_sensor_accel_subscribe(interval_ms, callback);
        }

        pub fn stop() {
            native_sensor_accel_unsubscribe();
        }
    }

    pub class Gyroscope {
        pub let x: Float;
        pub let y: Float;
        pub let z: Float;

        pub fn read() -> Self {
            let data = native_sensor_gyro_read();
            return Self { x: data.x, y: data.y, z: data.z };
        }

        pub fn on_change(interval_ms: Int, callback: Fn) {
            native_sensor_gyro_subscribe(interval_ms, callback);
        }

        pub fn stop() {
            native_sensor_gyro_unsubscribe();
        }
    }

    pub class AmbientLight {
        pub let lux: Float;

        pub fn read() -> Self {
            return Self { lux: native_sensor_light_read() };
        }

        pub fn on_change(callback: Fn) {
            native_sensor_light_subscribe(callback);
        }

        pub fn stop() {
            native_sensor_light_unsubscribe();
        }
    }

    pub class Battery {
        pub let level: Float;
        pub let charging: Bool;
        pub let time_remaining_min: Int;

        pub fn read() -> Self {
            let data = native_sensor_battery_read();
            return Self {
                level: data.level,
                charging: data.charging,
                time_remaining_min: data.time_remaining
            };
        }

        pub fn on_change(callback: Fn) {
            native_sensor_battery_subscribe(callback);
        }
    }

    pub class GeoLocation {
        pub let latitude: Float;
        pub let longitude: Float;
        pub let altitude: Float;
        pub let accuracy: Float;

        pub fn request() -> Self? {
            let data = native_sensor_geo_read();
            if data == null { return null; }
            return Self {
                latitude: data.latitude,
                longitude: data.longitude,
                altitude: data.altitude,
                accuracy: data.accuracy
            };
        }

        pub fn watch(callback: Fn) {
            native_sensor_geo_subscribe(callback);
        }

        pub fn stop() {
            native_sensor_geo_unsubscribe();
        }
    }
}

# ============================================================
# SYSTEM HARDWARE INFO
# ============================================================

pub mod system {
    pub class CPUInfo {
        pub let model: String;
        pub let cores: Int;
        pub let threads: Int;
        pub let frequency_mhz: Int;
        pub let architecture: String;
        pub let features: List<String>;

        pub fn read() -> Self {
            return native_system_cpu_info();
        }

        pub fn usage_per_core() -> List<Float> {
            return native_system_cpu_usage();
        }

        pub fn temperature() -> Float {
            return native_system_cpu_temp();
        }
    }

    pub class MemoryInfo {
        pub let total_mb: Int;
        pub let available_mb: Int;
        pub let used_mb: Int;
        pub let swap_total_mb: Int;
        pub let swap_used_mb: Int;

        pub fn read() -> Self {
            return native_system_memory_info();
        }

        pub fn usage_percent(self) -> Float {
            return (self.used_mb as Float / self.total_mb as Float) * 100.0;
        }
    }

    pub class DiskInfo {
        pub let mount_point: String;
        pub let total_gb: Float;
        pub let free_gb: Float;
        pub let filesystem: String;

        pub fn list() -> List<DiskInfo> {
            return native_system_disk_list();
        }
    }

    pub class DisplayInfo {
        pub let id: Int;
        pub let name: String;
        pub let width: Int;
        pub let height: Int;
        pub let refresh_rate: Int;
        pub let dpi: Float;
        pub let color_depth: Int;
        pub let primary: Bool;

        pub fn list() -> List<DisplayInfo> {
            return native_system_display_list();
        }
    }

    pub class NetworkInterface {
        pub let name: String;
        pub let mac_address: String;
        pub let ipv4: String;
        pub let ipv6: String;
        pub let is_up: Bool;
        pub let speed_mbps: Int;

        pub fn list() -> List<NetworkInterface> {
            return native_system_network_list();
        }
    }

    pub class PowerInfo {
        pub let on_battery: Bool;
        pub let battery_percent: Float;
        pub let charging: Bool;
        pub let power_saving_mode: Bool;

        pub fn read() -> Self {
            return native_system_power_info();
        }
    }
}

# ============================================================
# DEVICE ORCHESTRATOR
# ============================================================

pub class DeviceHub {
    pub let manager: enumeration.DeviceManager;
    pub let bt_adapter: bluetooth.BluetoothAdapter?;

    pub fn new() -> Self {
        return Self {
            manager: enumeration.DeviceManager::new(),
            bt_adapter: null
        };
    }

    pub fn scan_all(self) -> List<enumeration.DeviceInfo> {
        return self.manager.enumerate();
    }

    pub fn open_serial(self, port: String, baud: Int) -> serial.SerialPort? {
        return serial.SerialPort::open(port, serial.SerialConfig::new(baud));
    }

    pub fn open_usb(self, vendor_id: Int, product_id: Int) -> usb.USBDevice? {
        return usb.USBDevice::open(vendor_id, product_id);
    }

    pub fn open_hid(self, vendor_id: Int, product_id: Int) -> hid.HIDDevice? {
        return hid.HIDDevice::open(vendor_id, product_id);
    }

    pub fn bluetooth(self) -> bluetooth.BluetoothAdapter {
        if self.bt_adapter == null {
            self.bt_adapter = bluetooth.BluetoothAdapter::new();
        }
        return self.bt_adapter;
    }

    pub fn gpu_compute(self) -> gpu_compute.ComputeDevice? {
        return gpu_compute.ComputeDevice::default_device();
    }

    pub fn system_info(self) -> Map<String, Any> {
        return {
            "cpu": system.CPUInfo::read(),
            "memory": system.MemoryInfo::read(),
            "disks": system.DiskInfo::list(),
            "displays": system.DisplayInfo::list(),
            "network": system.NetworkInterface::list(),
            "power": system.PowerInfo::read()
        };
    }

    pub fn watch_devices(self) {
        self.manager.watch();
    }

    pub fn stop_watching(self) {
        self.manager.stop_watching();
    }
}

pub fn create_device_hub() -> DeviceHub {
    return DeviceHub::new();
}

# ============================================================
# NATIVE HOOKS
# ============================================================

# Enumeration
native_device_enumerate() -> List;
native_device_watch(callback: Fn);
native_device_stop_watch();

# USB
native_usb_open(vendor_id: Int, product_id: Int) -> Int;
native_usb_open_serial(serial: String) -> Int;
native_usb_device_info(handle: Int) -> Any;
native_usb_claim_interface(handle: Int, iface: Int) -> Bool;
native_usb_release_interface(handle: Int, iface: Int);
native_usb_bulk_out(handle: Int, ep: Int, data: Bytes, timeout: Int) -> Int;
native_usb_bulk_in(handle: Int, ep: Int, len: Int, timeout: Int) -> Bytes;
native_usb_control_transfer(handle: Int, rt: Int, req: Int, val: Int, idx: Int, data: Bytes, timeout: Int) -> Int;
native_usb_interrupt_in(handle: Int, ep: Int, len: Int, timeout: Int) -> Bytes;
native_usb_interrupt_out(handle: Int, ep: Int, data: Bytes, timeout: Int) -> Int;
native_usb_set_configuration(handle: Int, config: Int) -> Bool;
native_usb_reset(handle: Int);
native_usb_close(handle: Int);
native_usb_list() -> List;

# Serial
native_serial_open(port: String, config: Any) -> Int;
native_serial_write(handle: Int, data: Bytes) -> Int;
native_serial_read(handle: Int, max: Int) -> Bytes;
native_serial_read_line(handle: Int) -> String;
native_serial_read_until(handle: Int, delim: Int) -> Bytes;
native_serial_available(handle: Int) -> Int;
native_serial_flush(handle: Int);
native_serial_set_dtr(handle: Int, enabled: Bool);
native_serial_set_rts(handle: Int, enabled: Bool);
native_serial_get_cts(handle: Int) -> Bool;
native_serial_get_dsr(handle: Int) -> Bool;
native_serial_on_data(handle: Int, callback: Fn);
native_serial_close(handle: Int);
native_serial_list_ports() -> List;

# Bluetooth
native_bt_adapter_info() -> Any;
native_bt_enable() -> Bool;
native_bt_scan(duration: Int, callback: Fn);
native_bt_stop_scan();
native_bt_connect(address: String) -> Bool;
native_bt_disconnect(address: String);
native_bt_pair(address: String) -> Bool;
native_bt_paired_devices() -> List;
native_ble_read(addr: String, svc: String, char: String) -> Bytes;
native_ble_write(addr: String, svc: String, char: String, data: Bytes) -> Bool;
native_ble_subscribe(addr: String, svc: String, char: String, callback: Fn);
native_ble_unsubscribe(addr: String, svc: String, char: String);
native_ble_discover_services(addr: String) -> List;

# HID
native_hid_open(vendor_id: Int, product_id: Int) -> Int;
native_hid_device_info(handle: Int) -> Any;
native_hid_write(handle: Int, data: Bytes) -> Int;
native_hid_read(handle: Int, max: Int) -> Bytes;
native_hid_read_timeout(handle: Int, max: Int, timeout: Int) -> Bytes;
native_hid_get_feature_report(handle: Int, report_id: Int, len: Int) -> Bytes;
native_hid_send_feature_report(handle: Int, data: Bytes) -> Int;
native_hid_set_nonblocking(handle: Int, nonblocking: Bool);
native_hid_close(handle: Int);
native_hid_list() -> List;

# GPU Compute
native_gpu_compute_list_devices() -> List;
native_gpu_buffer_create(device_id: Int, size: Int, usage: String) -> Int;
native_gpu_buffer_upload(id: Int, data: Bytes);
native_gpu_buffer_download(id: Int) -> Bytes;
native_gpu_buffer_destroy(id: Int);
native_gpu_shader_compile(device_id: Int, source: String) -> Int;
native_gpu_shader_destroy(id: Int);
native_gpu_dispatch(device_id: Int, shader_id: Int, bindings: Map, x: Int, y: Int, z: Int);
native_gpu_dispatch_indirect(device_id: Int, shader_id: Int, buffer_id: Int);

# Sensors
native_sensor_accel_read() -> Any;
native_sensor_accel_subscribe(interval: Int, callback: Fn);
native_sensor_accel_unsubscribe();
native_sensor_gyro_read() -> Any;
native_sensor_gyro_subscribe(interval: Int, callback: Fn);
native_sensor_gyro_unsubscribe();
native_sensor_light_read() -> Float;
native_sensor_light_subscribe(callback: Fn);
native_sensor_light_unsubscribe();
native_sensor_battery_read() -> Any;
native_sensor_battery_subscribe(callback: Fn);
native_sensor_geo_read() -> Any;
native_sensor_geo_subscribe(callback: Fn);
native_sensor_geo_unsubscribe();

# System
native_system_cpu_info() -> Any;
native_system_cpu_usage() -> List;
native_system_cpu_temp() -> Float;
native_system_memory_info() -> Any;
native_system_disk_list() -> List;
native_system_display_list() -> List;
native_system_network_list() -> List;
native_system_power_info() -> Any;

# ============================================================
# PRODUCTION-READY INFRASTRUCTURE
# ============================================================

pub mod production {

    pub class HealthStatus {
        pub let status: String;
        pub let uptime_ms: Int;
        pub let checks: Map;
        pub let version: String;

        pub fn new() -> Self {
            return Self {
                status: "healthy",
                uptime_ms: 0,
                checks: {},
                version: VERSION
            };
        }

        pub fn is_healthy(self) -> Bool {
            return self.status == "healthy";
        }

        pub fn add_check(self, name: String, passed: Bool, detail: String) {
            self.checks[name] = { "passed": passed, "detail": detail };
            if !passed { self.status = "degraded"; }
        }
    }

    pub class MetricsCollector {
        pub let counters: Map;
        pub let gauges: Map;
        pub let histograms: Map;
        pub let start_time: Int;

        pub fn new() -> Self {
            return Self {
                counters: {},
                gauges: {},
                histograms: {},
                start_time: native_production_time_ms()
            };
        }

        pub fn increment(self, name: String, value: Int) {
            self.counters[name] = (self.counters[name] or 0) + value;
        }

        pub fn gauge_set(self, name: String, value: Float) {
            self.gauges[name] = value;
        }

        pub fn histogram_observe(self, name: String, value: Float) {
            if self.histograms[name] == null { self.histograms[name] = []; }
            self.histograms[name].push(value);
        }

        pub fn snapshot(self) -> Map {
            return {
                "counters": self.counters,
                "gauges": self.gauges,
                "uptime_ms": native_production_time_ms() - self.start_time
            };
        }

        pub fn reset(self) {
            self.counters = {};
            self.gauges = {};
            self.histograms = {};
        }
    }

    pub class Logger {
        pub let level: String;
        pub let buffer: List;
        pub let max_buffer: Int;

        pub fn new(level: String) -> Self {
            return Self { level: level, buffer: [], max_buffer: 10000 };
        }

        pub fn debug(self, msg: String, context: Map?) {
            if self.level == "debug" { self._log("DEBUG", msg, context); }
        }

        pub fn info(self, msg: String, context: Map?) {
            if self.level != "error" and self.level != "warn" {
                self._log("INFO", msg, context);
            }
        }

        pub fn warn(self, msg: String, context: Map?) {
            if self.level != "error" { self._log("WARN", msg, context); }
        }

        pub fn error(self, msg: String, context: Map?) {
            self._log("ERROR", msg, context);
        }

        fn _log(self, lvl: String, msg: String, context: Map?) {
            let entry = {
                "ts": native_production_time_ms(),
                "level": lvl,
                "msg": msg,
                "ctx": context
            };
            self.buffer.push(entry);
            if self.buffer.len() > self.max_buffer {
                self.buffer = self.buffer[self.max_buffer / 2..];
            }
        }

        pub fn flush(self) -> List {
            let out = self.buffer;
            self.buffer = [];
            return out;
        }
    }

    pub class CircuitBreaker {
        pub let state: String;
        pub let failure_count: Int;
        pub let threshold: Int;
        pub let reset_timeout_ms: Int;
        pub let last_failure_time: Int;

        pub fn new(threshold: Int, reset_timeout_ms: Int) -> Self {
            return Self {
                state: "closed",
                failure_count: 0,
                threshold: threshold,
                reset_timeout_ms: reset_timeout_ms,
                last_failure_time: 0
            };
        }

        pub fn allow_request(self) -> Bool {
            if self.state == "closed" { return true; }
            if self.state == "open" {
                let elapsed = native_production_time_ms() - self.last_failure_time;
                if elapsed >= self.reset_timeout_ms {
                    self.state = "half-open";
                    return true;
                }
                return false;
            }
            return true;
        }

        pub fn record_success(self) {
            self.failure_count = 0;
            self.state = "closed";
        }

        pub fn record_failure(self) {
            self.failure_count = self.failure_count + 1;
            self.last_failure_time = native_production_time_ms();
            if self.failure_count >= self.threshold {
                self.state = "open";
            }
        }
    }

    pub class RetryPolicy {
        pub let max_retries: Int;
        pub let base_delay_ms: Int;
        pub let max_delay_ms: Int;
        pub let backoff_multiplier: Float;

        pub fn new(max_retries: Int) -> Self {
            return Self {
                max_retries: max_retries,
                base_delay_ms: 100,
                max_delay_ms: 30000,
                backoff_multiplier: 2.0
            };
        }

        pub fn get_delay(self, attempt: Int) -> Int {
            let delay = self.base_delay_ms;
            for _ in 0..attempt { delay = (delay * self.backoff_multiplier).to_int(); }
            if delay > self.max_delay_ms { delay = self.max_delay_ms; }
            return delay;
        }
    }

    pub class RateLimiter {
        pub let max_requests: Int;
        pub let window_ms: Int;
        pub let requests: List;

        pub fn new(max_requests: Int, window_ms: Int) -> Self {
            return Self { max_requests: max_requests, window_ms: window_ms, requests: [] };
        }

        pub fn allow(self) -> Bool {
            let now = native_production_time_ms();
            self.requests = self.requests.filter(fn(t) { t > now - self.window_ms });
            if self.requests.len() >= self.max_requests { return false; }
            self.requests.push(now);
            return true;
        }
    }

    pub class GracefulShutdown {
        pub let hooks: List;
        pub let timeout_ms: Int;
        pub let is_shutting_down: Bool;

        pub fn new(timeout_ms: Int) -> Self {
            return Self { hooks: [], timeout_ms: timeout_ms, is_shutting_down: false };
        }

        pub fn register(self, name: String, hook: Fn) {
            self.hooks.push({ "name": name, "hook": hook });
        }

        pub fn shutdown(self) {
            self.is_shutting_down = true;
            for entry in self.hooks {
                entry.hook();
            }
        }
    }

    pub class ProductionRuntime {
        pub let health: HealthStatus;
        pub let metrics: MetricsCollector;
        pub let logger: Logger;
        pub let circuit_breaker: CircuitBreaker;
        pub let rate_limiter: RateLimiter;
        pub let shutdown: GracefulShutdown;

        pub fn new() -> Self {
            return Self {
                health: HealthStatus::new(),
                metrics: MetricsCollector::new(),
                logger: Logger::new("info"),
                circuit_breaker: CircuitBreaker::new(5, 30000),
                rate_limiter: RateLimiter::new(1000, 60000),
                shutdown: GracefulShutdown::new(30000)
            };
        }

        pub fn check_health(self) -> HealthStatus {
            self.health.uptime_ms = native_production_time_ms() - self.metrics.start_time;
            return self.health;
        }

        pub fn get_metrics(self) -> Map {
            return self.metrics.snapshot();
        }

        pub fn is_ready(self) -> Bool {
            return self.health.is_healthy() and !self.shutdown.is_shutting_down;
        }
    }
}

native_production_time_ms() -> Int;

# ============================================================
# OBSERVABILITY & ERROR HANDLING
# ============================================================

pub mod observability {

    pub class Span {
        pub let trace_id: String;
        pub let span_id: String;
        pub let parent_id: String?;
        pub let operation: String;
        pub let start_time: Int;
        pub let end_time: Int?;
        pub let tags: Map;
        pub let status: String;

        pub fn new(operation: String, parent_id: String?) -> Self {
            return Self {
                trace_id: native_production_time_ms().to_string(),
                span_id: native_production_time_ms().to_string(),
                parent_id: parent_id,
                operation: operation,
                start_time: native_production_time_ms(),
                end_time: null,
                tags: {},
                status: "ok"
            };
        }

        pub fn set_tag(self, key: String, value: String) {
            self.tags[key] = value;
        }

        pub fn finish(self) {
            self.end_time = native_production_time_ms();
        }

        pub fn finish_with_error(self, error: String) {
            self.end_time = native_production_time_ms();
            self.status = "error";
            self.tags["error"] = error;
        }

        pub fn duration_ms(self) -> Int {
            if self.end_time == null { return 0; }
            return self.end_time - self.start_time;
        }
    }

    pub class Tracer {
        pub let spans: List;
        pub let active_span: Span?;
        pub let service_name: String;

        pub fn new(service_name: String) -> Self {
            return Self { spans: [], active_span: null, service_name: service_name };
        }

        pub fn start_span(self, operation: String) -> Span {
            let parent = if self.active_span != null { self.active_span.span_id } else { null };
            let span = Span::new(operation, parent);
            span.set_tag("service", self.service_name);
            self.active_span = span;
            return span;
        }

        pub fn finish_span(self, span: Span) {
            span.finish();
            self.spans.push(span);
            self.active_span = null;
        }

        pub fn get_traces(self) -> List {
            return self.spans;
        }
    }

    pub class AlertRule {
        pub let name: String;
        pub let condition: Fn;
        pub let severity: String;
        pub let cooldown_ms: Int;
        pub let last_fired: Int;

        pub fn new(name: String, condition: Fn, severity: String) -> Self {
            return Self {
                name: name,
                condition: condition,
                severity: severity,
                cooldown_ms: 60000,
                last_fired: 0
            };
        }

        pub fn evaluate(self, metrics: Map) -> Bool {
            let now = native_production_time_ms();
            if now - self.last_fired < self.cooldown_ms { return false; }
            if self.condition(metrics) {
                self.last_fired = now;
                return true;
            }
            return false;
        }
    }

    pub class AlertManager {
        pub let rules: List;
        pub let alerts: List;

        pub fn new() -> Self {
            return Self { rules: [], alerts: [] };
        }

        pub fn add_rule(self, rule: AlertRule) {
            self.rules.push(rule);
        }

        pub fn evaluate_all(self, metrics: Map) -> List {
            let fired = [];
            for rule in self.rules {
                if rule.evaluate(metrics) {
                    let alert = {
                        "name": rule.name,
                        "severity": rule.severity,
                        "time": native_production_time_ms()
                    };
                    self.alerts.push(alert);
                    fired.push(alert);
                }
            }
            return fired;
        }
    }
}

pub mod error_handling {

    pub class EngineError {
        pub let code: String;
        pub let message: String;
        pub let context: Map;
        pub let timestamp: Int;
        pub let recoverable: Bool;

        pub fn new(code: String, message: String, recoverable: Bool) -> Self {
            return Self {
                code: code,
                message: message,
                context: {},
                timestamp: native_production_time_ms(),
                recoverable: recoverable
            };
        }

        pub fn with_context(self, key: String, value: Any) -> Self {
            self.context[key] = value;
            return self;
        }
    }

    pub class ErrorRegistry {
        pub let errors: List;
        pub let max_errors: Int;

        pub fn new(max_errors: Int) -> Self {
            return Self { errors: [], max_errors: max_errors };
        }

        pub fn record(self, error: EngineError) {
            self.errors.push(error);
            if self.errors.len() > self.max_errors {
                self.errors = self.errors[self.errors.len() - self.max_errors..];
            }
        }

        pub fn get_recent(self, count: Int) -> List {
            let start = if self.errors.len() > count { self.errors.len() - count } else { 0 };
            return self.errors[start..];
        }

        pub fn count_by_code(self, code: String) -> Int {
            return self.errors.filter(fn(e) { e.code == code }).len();
        }
    }

    pub class RecoveryStrategy {
        pub let name: String;
        pub let max_attempts: Int;
        pub let handler: Fn;

        pub fn new(name: String, max_attempts: Int, handler: Fn) -> Self {
            return Self { name: name, max_attempts: max_attempts, handler: handler };
        }
    }

    pub class ErrorHandler {
        pub let registry: ErrorRegistry;
        pub let strategies: Map;
        pub let fallback: Fn?;

        pub fn new() -> Self {
            return Self {
                registry: ErrorRegistry::new(1000),
                strategies: {},
                fallback: null
            };
        }

        pub fn register_strategy(self, code: String, strategy: RecoveryStrategy) {
            self.strategies[code] = strategy;
        }

        pub fn set_fallback(self, handler: Fn) {
            self.fallback = handler;
        }

        pub fn handle(self, error: EngineError) -> Any? {
            self.registry.record(error);
            if error.recoverable and self.strategies[error.code] != null {
                let strategy = self.strategies[error.code];
                return strategy.handler(error);
            }
            if self.fallback != null { return self.fallback(error); }
            return null;
        }
    }
}

# ============================================================
# CONFIGURATION & LIFECYCLE MANAGEMENT
# ============================================================

pub mod config_management {

    pub class EnvConfig {
        pub let values: Map;
        pub let defaults: Map;
        pub let required_keys: List;

        pub fn new() -> Self {
            return Self { values: {}, defaults: {}, required_keys: [] };
        }

        pub fn set_default(self, key: String, value: Any) {
            self.defaults[key] = value;
        }

        pub fn set(self, key: String, value: Any) {
            self.values[key] = value;
        }

        pub fn require(self, key: String) {
            self.required_keys.push(key);
        }

        pub fn get(self, key: String) -> Any? {
            if self.values[key] != null { return self.values[key]; }
            return self.defaults[key];
        }

        pub fn get_int(self, key: String) -> Int {
            let v = self.get(key);
            if v == null { return 0; }
            return v.to_int();
        }

        pub fn get_bool(self, key: String) -> Bool {
            let v = self.get(key);
            if v == null { return false; }
            return v == true or v == "true" or v == "1";
        }

        pub fn validate(self) -> List {
            let missing = [];
            for key in self.required_keys {
                if self.get(key) == null { missing.push(key); }
            }
            return missing;
        }

        pub fn from_map(self, map: Map) {
            for key in map.keys() { self.values[key] = map[key]; }
        }
    }

    pub class FeatureFlag {
        pub let name: String;
        pub let enabled: Bool;
        pub let rollout_pct: Float;
        pub let metadata: Map;

        pub fn new(name: String, enabled: Bool) -> Self {
            return Self { name: name, enabled: enabled, rollout_pct: 100.0, metadata: {} };
        }

        pub fn is_enabled(self) -> Bool {
            return self.enabled;
        }

        pub fn is_enabled_for(self, user_id: String) -> Bool {
            if !self.enabled { return false; }
            if self.rollout_pct >= 100.0 { return true; }
            let hash = user_id.len() % 100;
            return hash < self.rollout_pct.to_int();
        }
    }

    pub class FeatureFlagManager {
        pub let flags: Map;

        pub fn new() -> Self {
            return Self { flags: {} };
        }

        pub fn register(self, flag: FeatureFlag) {
            self.flags[flag.name] = flag;
        }

        pub fn is_enabled(self, name: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled();
        }

        pub fn is_enabled_for(self, name: String, user_id: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled_for(user_id);
        }
    }
}

pub mod lifecycle {

    pub class Phase {
        pub let name: String;
        pub let order: Int;
        pub let handler: Fn;
        pub let completed: Bool;

        pub fn new(name: String, order: Int, handler: Fn) -> Self {
            return Self { name: name, order: order, handler: handler, completed: false };
        }
    }

    pub class LifecycleManager {
        pub let phases: List;
        pub let current_phase: String;
        pub let state: String;
        pub let hooks: Map;

        pub fn new() -> Self {
            return Self {
                phases: [],
                current_phase: "init",
                state: "created",
                hooks: {}
            };
        }

        pub fn add_phase(self, phase: Phase) {
            self.phases.push(phase);
            self.phases.sort_by(fn(a, b) { a.order - b.order });
        }

        pub fn on(self, event: String, handler: Fn) {
            if self.hooks[event] == null { self.hooks[event] = []; }
            self.hooks[event].push(handler);
        }

        pub fn start(self) {
            self.state = "starting";
            self._emit("before_start");
            for phase in self.phases {
                self.current_phase = phase.name;
                phase.handler();
                phase.completed = true;
            }
            self.state = "running";
            self._emit("after_start");
        }

        pub fn stop(self) {
            self.state = "stopping";
            self._emit("before_stop");
            for phase in self.phases.reverse() {
                self.current_phase = "teardown_" + phase.name;
            }
            self.state = "stopped";
            self._emit("after_stop");
        }

        fn _emit(self, event: String) {
            if self.hooks[event] != null {
                for handler in self.hooks[event] { handler(); }
            }
        }

        pub fn is_running(self) -> Bool {
            return self.state == "running";
        }
    }

    pub class ResourcePool {
        pub let name: String;
        pub let resources: List;
        pub let max_size: Int;
        pub let in_use: Int;

        pub fn new(name: String, max_size: Int) -> Self {
            return Self { name: name, resources: [], max_size: max_size, in_use: 0 };
        }

        pub fn acquire(self) -> Any? {
            if self.resources.len() > 0 {
                self.in_use = self.in_use + 1;
                return self.resources.pop();
            }
            if self.in_use < self.max_size {
                self.in_use = self.in_use + 1;
                return {};
            }
            return null;
        }

        pub fn release(self, resource: Any) {
            self.in_use = self.in_use - 1;
            self.resources.push(resource);
        }

        pub fn available(self) -> Int {
            return self.max_size - self.in_use;
        }
    }
}
