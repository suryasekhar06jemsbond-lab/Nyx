# ===========================================
# PCI Hotplug & Dynamic Devices — Production Grade
# ===========================================
# Runtime device add/remove, bus enumeration,
# driver unload/reload, device state preservation.

import systems
import hardware
import vm_devices

# ===========================================
# PCI Hotplug Device Slot
# ===========================================

class PCIHotplugSlot {
    fn init(self, slot_num) {
        self.slot = slot_num;
        self.device = null;
        self.enabled = false;
        self.presence_detected = false;
        self.power_fault = false;
        self.attention_button = false;
        self.attention_led = false;
        self.power_led = false;
        self.callbacks = {};
    }

    fn insert_device(self, device) {
        self.device = device;
        self.presence_detected = true;
        self.on_presence_change();
        return true;
    }

    fn remove_device(self) {
        self.device = null;
        self.presence_detected = false;
        self.on_presence_change();
        return true;
    }

    fn enable(self) {
        if self.device == null { return false; }
        self.enabled = true;
        self.power_led = true;
        return true;
    }

    fn disable(self) {
        self.enabled = false;
        self.power_led = false;
        return true;
    }

    fn on_presence_change(self) {
        if "on_presence_change" in self.callbacks {
            self.callbacks["on_presence_change"](self);
        }
    }

    fn register_callback(self, event_name, callback) {
        self.callbacks[event_name] = callback;
    }

    fn get_device(self) {
        if self.enabled { return self.device; }
        return null;
    }
}

# ===========================================
# PCI Hotplug Controller
# ===========================================

class PCIHotplugController: vm_devices.Device {
    fn init(self) {
        super.init("pci_hotplug");
        self.irq_line = 10;
        self.slots = [];
        self.pending_events = [];
        self.config = {
            "num_slots": 32,
            "auto_enable": false
        };
        
        # Initialize hotplug slots
        for i in 0..self.config["num_slots"] {
            push(self.slots, PCIHotplugSlot(i));
        }
    }

    fn io_read(self, req) {
        let offset = req.port & 0xFF;
        
        if offset == 0x00 {
            # Slot presence/power status registerreturn self.read_slot_status();
        }
        if offset == 0x04 {
            # Control register
            return self.read_control();
        }
        if offset == 0x08 {
            # Event register
            return self.read_event();
        }
        
        return 0xFF;
    }

    fn io_write(self, req) {
        let offset = req.port & 0xFF;
        let val = req.value & 0xFF;
        
        if offset == 0x04 {
            self.write_control(val);
            return;
        }
        if offset == 0x08 {
            self.clear_events(val);
            return;
        }
    }

    fn read_slot_status(self) {
        let status = 0;
        for slot in self.slots {
            if slot.presence_detected {
                status = status | (1 << slot.slot);
            }
        }
        return status & 0xFF;
    }

    fn read_control(self) {
        let ctrl = 0;
        for slot in self.slots {
            if slot.power_led {
                ctrl = ctrl | (1 << (slot.slot % 8));
            }
        }
        return ctrl & 0xFF;
    }

    fn read_event(self) {
        if len(self.pending_events) > 0 {
            return self.pending_events[0];
        }
        return 0;
    }

    fn write_control(self, val) {
        # Power on/off slots
        for i in 0..8 {
            if (val & (1 << i)) != 0 {
                if i < len(self.slots) {
                    self.slots[i].enable();
                }
            }
        }
    }

    fn clear_events(self, val) {
        if (val & 0x01) != 0 and len(self.pending_events) > 0 {
            self.pending_events = self.pending_events[1..];
        }
    }

    fn insert_device_into_slot(self, slot_num, device) {
        if slot_num >= len(self.slots) { return false; }
        
        return self.slots[slot_num].insert_device(device);
    }

    fn remove_device_from_slot(self, slot_num) {
        if slot_num >= len(self.slots) { return false; }
        
        return self.slots[slot_num].remove_device();
    }

    fn enable_slot(self, slot_num) {
        if slot_num >= len(self.slots) { return false; }
        
        let result = self.slots[slot_num].enable();
        if result {
            push(self.pending_events, (1 << slot_num));  # Signal enable event
            self.raise_irq();
        }
        return result;
    }

    fn get_device_from_slot(self, slot_num) {
        if slot_num >= len(self.slots) { return null; }
        
        return self.slots[slot_num].get_device();
    }

    fn snapshot(self) {
        return {
            "slot_count": len(self.slots),
            "pending_events": self.pending_events
        };
    }
}

# ===========================================
# Dynamic Device Manager
# ===========================================

class DynamicDeviceManager {
    fn init(self, vm) {
        self.vm = vm;
        self.hotplug_ctrl = null;
        self.pci_hotplug_enabled = false;
        self.device_queue = [];
        self.max_pci_slot = 10;
        self.current_pci_slot = 5;
    }

    fn enable_pci_hotplug(self) {
        self.hotplug_ctrl = PCIHotplugController();
        self.hotplug_ctrl.irq_callback = self.vm.bus.irq_router.make_irq_callback();
        self.vm.bus.register_mmio_device(0xAE00, 0x100, self.hotplug_ctrl);
        self.pci_hotplug_enabled = true;
        return true;
    }

    fn queue_device_add(self, device, device_type) {
        push(self.device_queue, {
            "device": device,
            "type": device_type,
            "operation": "add",
            "status": "pending"
        });
    }

    fn queue_device_remove(self, device_id, device_type) {
        push(self.device_queue, {
            "device_id": device_id,
            "type": device_type,
            "operation": "remove",
            "status": "pending"
        });
    }

    fn add_pci_device(self, device) {
        # Find available PCI slot
        if self.current_pci_slot >= self.max_pci_slot { return false; }
        
        device.pci_bus = 0;
        device.pci_device = self.current_pci_slot;
        device.pci_function = 0;
        device.interrupt_line = 10 + self.current_pci_slot;
        
        self.vm.pci.register_device(device);
        push(self.vm.pci_devices, device);
        
        # For specific device types
        if "network" in device.name {
            push(self.vm.nic_devices, device);
        } else if "storage" in device.name or "virtio_blk" in device.name {
            push(self.vm.storage_devices, device);
        }
        
        self.current_pci_slot = self.current_pci_slot + 1;
        
        # Notify hotplug controller
        if self.hotplug_ctrl != null {
            self.hotplug_ctrl.insert_device_into_slot(device.pci_device, device);
            self.hotplug_ctrl.enable_slot(device.pci_device);
        }
        
        return true;
    }

    fn remove_pci_device(self, pci_device_num) {
        # Remove PCI device from given slot
        if self.hotplug_ctrl != null {
            self.hotplug_ctrl.remove_device_from_slot(pci_device_num);
        }
        
        # Remove from VM's device lists
        for i in 0..len(self.vm.pci_devices) {
            let dev = self.vm.pci_devices[i];
            if dev.pci_device == pci_device_num {
                self.vm.pci_devices = self.vm.pci_devices[0..i] + self.vm.pci_devices[i+1..];
                break;
            }
        }
        
        return true;
    }

    fn process_device_queue(self) {
        # Process pending device add/remove operations
        while len(self.device_queue) > 0 {
            let op = self.device_queue[0];
            
            if op["operation"] == "add" {
                self.add_pci_device(op["device"]);
                op["status"] = "completed";
            } else if op["operation"] == "remove" {
                self.remove_pci_device(op["device_id"]);
                op["status"] = "completed";
            }
            
            self.device_queue = self.device_queue[1..];
        }
    }

    fn get_hotplug_status(self) {
        if self.hotplug_ctrl == null { return null; }
        
        return {
            "enabled": self.pci_hotplug_enabled,
            "slots": len(self.hotplug_ctrl.slots),
            "pending_events": len(self.hotplug_ctrl.pending_events)
        };
    }
}
