# ===========================================
# Nyx Virtual Machine Device Model — Production
# ===========================================
# Full register-level device emulation for Windows/Linux guests.
# PCI host bridge, ISA chipset (PIC/PIT/RTC/PS2/DMA/UART),
# APIC complex (LAPIC/IOAPIC/HPET), MSI/MSI-X,
# virtio-blk, AHCI, E1000, virtio-net, Bochs VGA,
# ACPI power management, CMOS, DMA 8237, UART 16550A.

import systems
import hardware

# ===========================================
# Core Device Interfaces
# ===========================================

class IORequest {
    fn init(self, port, size, is_write, value) {
        self.port = port;
        self.size = size;
        self.is_write = is_write;
        self.value = value;
    }
}

class MMIORequest {
    fn init(self, addr, size, is_write, value) {
        self.addr = addr;
        self.size = size;
        self.is_write = is_write;
        self.value = value;
    }
}

class Device {
    fn init(self, name) {
        self.name = name;
        self.irq_line = -1;
        self.irq_callback = null;
    }

    fn io_read(self, req) { return 0xFF; }
    fn io_write(self, req) { }
    fn mmio_read(self, req) { return 0; }
    fn mmio_write(self, req) { }
    fn reset(self) { }

    fn raise_irq(self) {
        if self.irq_callback != null {
            self.irq_callback(self.irq_line, true);
        }
    }

    fn lower_irq(self) {
        if self.irq_callback != null {
            self.irq_callback(self.irq_line, false);
        }
    }

    fn snapshot(self) { return {}; }
    fn restore(self, state) { }
}

# ===========================================
# Interrupt Controller Interface
# ===========================================

class InterruptRouter {
    fn init(self) {
        self.pic = null;
        self.ioapic = null;
        self.lapics = [];
        self.msi_enabled = false;
    }

    fn route_irq(self, irq, assert) {
        if self.ioapic != null {
            self.ioapic.set_irq(irq, assert);
        }
        if self.pic != null {
            self.pic.set_irq(irq, assert);
        }
    }

    fn route_msi(self, addr, data) {
        let dest_id = (addr >> 12) & 0xFF;
        let vector = data & 0xFF;
        let delivery = (data >> 8) & 0x7;
        for lapic in self.lapics {
            if lapic.id == dest_id or dest_id == 0xFF {
                lapic.deliver_interrupt(vector, delivery);
            }
        }
    }

    fn make_irq_callback(self) {
        let router = self;
        return fn(irq, assert) {
            router.route_irq(irq, assert);
        };
    }
}

# ===========================================
# Device Bus
# ===========================================

class DeviceBus {
    fn init(self) {
        self.io_ranges = [];
        self.mmio_ranges = [];
        self.irq_router = InterruptRouter();
    }

    fn register_io_device(self, start_port, end_port, device) {
        push(self.io_ranges, {
            "start": start_port,
            "end": end_port,
            "device": device
        });
    }

    fn register_mmio_device(self, base_addr, size, device) {
        push(self.mmio_ranges, {
            "start": base_addr,
            "end": base_addr + size - 1,
            "device": device
        });
    }

    fn handle_io(self, req) {
        for entry in self.io_ranges {
            if req.port >= entry["start"] and req.port <= entry["end"] {
                if req.is_write {
                    entry["device"].io_write(req);
                    return 0;
                }
                return entry["device"].io_read(req);
            }
        }
        return 0xFF;
    }

    fn handle_mmio(self, req) {
        for entry in self.mmio_ranges {
            if req.addr >= entry["start"] and req.addr <= entry["end"] {
                if req.is_write {
                    entry["device"].mmio_write(req);
                    return 0;
                }
                return entry["device"].mmio_read(req);
            }
        }
        return 0xFFFFFFFF;
    }

    fn reset_all(self) {
        for entry in self.io_ranges {
            entry["device"].reset();
        }
        for entry in self.mmio_ranges {
            entry["device"].reset();
        }
    }
}

# ===========================================
# 8259A PIC (Programmable Interrupt Controller)
# ===========================================

class PIC8259: Device {
    fn init(self, name, is_master) {
        super.init(name);
        self.is_master = is_master;
        self.slave = null;
        self.reset();
    }

    fn reset(self) {
        self.irr = 0;           # Interrupt Request Register
        self.isr = 0;           # In-Service Register
        self.imr = 0xFF;        # Interrupt Mask Register (all masked)
        self.icw_step = 0;      # ICW initialization step
        self.icw1 = 0;
        self.icw2 = 0;          # Vector base offset
        self.icw3 = 0;
        self.icw4 = 0;
        self.ocw3 = 0x02;       # Read IRR by default
        self.auto_eoi = false;
        self.rotate_priority = false;
        self.special_mask = false;
        self.poll_mode = false;
        self.elcr = 0;          # Edge/Level Control Register
    }

    fn io_read(self, req) {
        let port_offset = req.port & 1;
        if port_offset == 0 {
            # Command port read
            if (self.ocw3 & 0x03) == 0x03 {
                return self.isr;
            }
            return self.irr;
        }
        # Data port: read IMR
        return self.imr;
    }

    fn io_write(self, req) {
        let port_offset = req.port & 1;
        let val = req.value & 0xFF;

        if port_offset == 0 {
            if (val & 0x10) != 0 {
                # ICW1
                self.icw1 = val;
                self.icw_step = 1;
                self.imr = 0;
                self.isr = 0;
                self.irr = 0;
                self.auto_eoi = false;
                return;
            }
            if (val & 0x08) != 0 {
                # OCW3
                self.ocw3 = val;
                self.special_mask = ((val >> 5) & 0x3) == 0x3;
                return;
            }
            # OCW2 (EOI commands)
            self.handle_ocw2(val);
            return;
        }

        # Data port writes — ICW2/3/4 or OCW1 (IMR)
        if self.icw_step == 1 {
            self.icw2 = val;  # Vector base
            self.icw_step = 2;
            return;
        }
        if self.icw_step == 2 {
            self.icw3 = val;
            if (self.icw1 & 0x01) != 0 {
                self.icw_step = 3;
            } else {
                self.icw_step = 0;
            }
            return;
        }
        if self.icw_step == 3 {
            self.icw4 = val;
            self.auto_eoi = ((val & 0x02) != 0);
            self.icw_step = 0;
            return;
        }
        # OCW1 — set IMR
        self.imr = val;
    }

    fn handle_ocw2(self, val) {
        let cmd = (val >> 5) & 0x7;
        if cmd == 0x01 {
            # Non-specific EOI
            let highest = self.find_highest_isr();
            if highest >= 0 {
                self.isr = self.isr & ~(1 << highest);
            }
        } else if cmd == 0x03 {
            # Specific EOI
            let level = val & 0x07;
            self.isr = self.isr & ~(1 << level);
        } else if cmd == 0x05 {
            # Rotate on non-specific EOI
            let highest = self.find_highest_isr();
            if highest >= 0 {
                self.isr = self.isr & ~(1 << highest);
            }
        }
    }

    fn set_irq(self, irq, assert) {
        let bit = 1 << (irq & 7);
        if assert {
            if (self.elcr & bit) != 0 {
                # Level triggered
                self.irr = self.irr | bit;
            } else {
                # Edge triggered: only on rising edge
                if (self.irr & bit) == 0 {
                    self.irr = self.irr | bit;
                }
            }
        } else {
            if (self.elcr & bit) != 0 {
                self.irr = self.irr & ~bit;
            }
        }
    }

    fn get_pending_irq(self) {
        let pending = self.irr & ~self.imr;
        if pending == 0 { return -1; }
        for i in 0..8 {
            if (pending & (1 << i)) != 0 {
                if (self.isr & (1 << i)) == 0 or self.special_mask {
                    return i;
                }
            }
        }
        return -1;
    }

    fn acknowledge(self, irq) {
        let bit = 1 << (irq & 7);
        self.irr = self.irr & ~bit;
        if !self.auto_eoi {
            self.isr = self.isr | bit;
        }
        return self.icw2 + irq;  # Vector number
    }

    fn find_highest_isr(self) {
        for i in 0..8 {
            if (self.isr & (1 << i)) != 0 {
                return i;
            }
        }
        return -1;
    }

    fn snapshot(self) {
        return {
            "irr": self.irr, "isr": self.isr, "imr": self.imr,
            "icw2": self.icw2, "icw4": self.icw4, "auto_eoi": self.auto_eoi,
            "elcr": self.elcr
        };
    }
}

class PICController: Device {
    fn init(self) {
        super.init("pic");
        self.master = PIC8259("pic_master", true);
        self.slave = PIC8259("pic_slave", false);
        self.master.slave = self.slave;
    }

    fn set_irq(self, irq, assert) {
        if irq < 8 {
            self.master.set_irq(irq, assert);
        } else {
            self.slave.set_irq(irq - 8, assert);
            # Cascade on IRQ2
            self.master.set_irq(2, assert);
        }
    }

    fn get_vector(self) {
        let mirq = self.master.get_pending_irq();
        if mirq < 0 { return -1; }
        if mirq == 2 {
            # Cascade — check slave
            let sirq = self.slave.get_pending_irq();
            if sirq < 0 { return -1; }
            self.master.acknowledge(2);
            return self.slave.acknowledge(sirq);
        }
        return self.master.acknowledge(mirq);
    }

    fn has_interrupt(self) {
        return self.master.get_pending_irq() >= 0;
    }

    fn reset(self) {
        self.master.reset();
        self.slave.reset();
    }
}

# ===========================================
# 8254 PIT (Programmable Interval Timer)
# ===========================================

const PIT_FREQ = 1193182;   # PIT oscillator frequency (Hz)

class PITChannel {
    fn init(self, index) {
        self.index = index;
        self.mode = 0;
        self.bcd = false;
        self.rw_mode = 3;        # 0=latch, 1=LSB, 2=MSB, 3=LSB+MSB
        self.reload = 0;
        self.count = 0;
        self.output = false;
        self.gate = true;
        self.latched = false;
        self.latch_value = 0;
        self.write_lsb = true;   # Next write is LSB
        self.read_lsb = true;    # Next read is LSB
        self.null_count = true;
    }

    fn write_reload(self, val) {
        if self.rw_mode == 1 {
            self.reload = (self.reload & 0xFF00) | (val & 0xFF);
            self.load();
        } else if self.rw_mode == 2 {
            self.reload = (self.reload & 0x00FF) | ((val & 0xFF) << 8);
            self.load();
        } else if self.rw_mode == 3 {
            if self.write_lsb {
                self.reload = (self.reload & 0xFF00) | (val & 0xFF);
                self.write_lsb = false;
            } else {
                self.reload = (self.reload & 0x00FF) | ((val & 0xFF) << 8);
                self.write_lsb = true;
                self.load();
            }
        }
    }

    fn read_count(self) {
        let value = self.count;
        if self.latched {
            value = self.latch_value;
        }
        if self.rw_mode == 1 {
            self.latched = false;
            return value & 0xFF;
        }
        if self.rw_mode == 2 {
            self.latched = false;
            return (value >> 8) & 0xFF;
        }
        # LSB then MSB
        if self.read_lsb {
            self.read_lsb = false;
            return value & 0xFF;
        }
        self.read_lsb = true;
        self.latched = false;
        return (value >> 8) & 0xFF;
    }

    fn latch(self) {
        self.latched = true;
        self.latch_value = self.count;
        self.read_lsb = true;
    }

    fn load(self) {
        self.count = self.reload;
        if self.count == 0 { self.count = 0x10000; }
        self.null_count = false;
    }

    fn tick(self) {
        if !self.gate and (self.mode == 2 or self.mode == 3) {
            return false;
        }
        self.count = self.count - 1;
        if self.count <= 0 {
            self.count = self.reload;
            if self.count == 0 { self.count = 0x10000; }
            if self.mode == 0 {
                self.output = true;
                return true;
            }
            if self.mode == 2 or self.mode == 3 {
                return true;  # Periodic — fire IRQ
            }
        }
        return false;
    }
}

class PITDevice: Device {
    fn init(self) {
        super.init("pit");
        self.irq_line = 0;
        self.channels = [
            PITChannel(0),
            PITChannel(1),
            PITChannel(2)
        ];
        self.speaker_gate = false;
    }

    fn reset(self) {
        for ch in self.channels { ch = PITChannel(ch.index); }
    }

    fn io_read(self, req) {
        let port = req.port;
        if port >= 0x40 and port <= 0x42 {
            return self.channels[port - 0x40].read_count();
        }
        if port == 0x61 {
            # System control port B (speaker/gate/output)
            let val = 0;
            if self.speaker_gate { val = val | 0x01; }
            if self.channels[2].gate { val = val | 0x02; }
            if self.channels[2].output { val = val | 0x20; }
            return val;
        }
        return 0xFF;
    }

    fn io_write(self, req) {
        let port = req.port;
        let val = req.value & 0xFF;
        if port >= 0x40 and port <= 0x42 {
            self.channels[port - 0x40].write_reload(val);
            return;
        }
        if port == 0x43 {
            # Mode/Command register
            let channel = (val >> 6) & 0x3;
            if channel == 3 {
                # Read-back command
                return;
            }
            let rw = (val >> 4) & 0x3;
            let mode = (val >> 1) & 0x7;
            let bcd = (val & 1) != 0;
            if rw == 0 {
                # Latch command
                self.channels[channel].latch();
                return;
            }
            self.channels[channel].rw_mode = rw;
            self.channels[channel].mode = mode;
            self.channels[channel].bcd = bcd;
            self.channels[channel].write_lsb = true;
            self.channels[channel].read_lsb = true;
            return;
        }
        if port == 0x61 {
            self.speaker_gate = (val & 0x01) != 0;
            self.channels[2].gate = (val & 0x02) != 0;
        }
    }

    fn tick(self) {
        if self.channels[0].tick() {
            self.raise_irq();
        }
        self.channels[1].tick();
        self.channels[2].tick();
    }

    fn snapshot(self) {
        return {
            "ch0_count": self.channels[0].count,
            "ch0_reload": self.channels[0].reload,
            "ch0_mode": self.channels[0].mode
        };
    }
}

# ===========================================
# MC146818 RTC / CMOS
# ===========================================

class RTCDevice: Device {
    fn init(self) {
        super.init("rtc");
        self.irq_line = 8;
        self.index = 0;       # Currently selected CMOS register
        self.cmos = [];
        for i in 0..128 { push(self.cmos, 0); }
        self.reset();
    }

    fn reset(self) {
        # Status Register A: UIP=0, DV=010 (32.768kHz), RS=0110 (1024Hz)
        self.cmos[0x0A] = 0x26;
        # Status Register B: 24hr mode, BCD format
        self.cmos[0x0B] = 0x02;
        # Status Register C: interrupt flags (read-only, cleared on read)
        self.cmos[0x0C] = 0x00;
        # Status Register D: CMOS RAM valid
        self.cmos[0x0D] = 0x80;
        # CMOS diagnostic: no errors
        self.cmos[0x0E] = 0x00;
        # Shutdown status: normal
        self.cmos[0x0F] = 0x00;
        # Century register
        self.cmos[0x32] = 0x20;
        # Equipment byte (floppy + VGA)
        self.cmos[0x14] = 0x07;
        # Set initial time (midnight, 2026-01-01)
        self.cmos[0x00] = 0x00;  # Seconds
        self.cmos[0x02] = 0x00;  # Minutes
        self.cmos[0x04] = 0x00;  # Hours
        self.cmos[0x06] = 0x04;  # Day of week (Thursday)
        self.cmos[0x07] = 0x01;  # Day of month
        self.cmos[0x08] = 0x01;  # Month
        self.cmos[0x09] = 0x26;  # Year (BCD 26)
        # Base memory: 640KB
        self.cmos[0x15] = 0x80;  # Low byte
        self.cmos[0x16] = 0x02;  # High byte
        # Extended memory (in KB above 1MB, up to 64MB - capped to 0xFFFF)
        self.cmos[0x17] = 0xFF;
        self.cmos[0x18] = 0xFF;
        # Extended memory above 16MB (in 64KB blocks)
        self.cmos[0x34] = 0x00;
        self.cmos[0x35] = 0x00;
    }

    fn set_memory_size(self, total_bytes) {
        # Extended memory (1MB-65MB) in KB
        let ext_kb = 0;
        if total_bytes > 0x100000 {
            ext_kb = (total_bytes - 0x100000) / 1024;
        }
        if ext_kb > 0xFFFF { ext_kb = 0xFFFF; }
        self.cmos[0x17] = ext_kb & 0xFF;
        self.cmos[0x18] = (ext_kb >> 8) & 0xFF;
        self.cmos[0x30] = ext_kb & 0xFF;
        self.cmos[0x31] = (ext_kb >> 8) & 0xFF;

        # Memory above 16MB in 64KB blocks
        if total_bytes > 0x1000000 {
            let above_16m = (total_bytes - 0x1000000) / 65536;
            if above_16m > 0xFFFF { above_16m = 0xFFFF; }
            self.cmos[0x34] = above_16m & 0xFF;
            self.cmos[0x35] = (above_16m >> 8) & 0xFF;
        }
    }

    fn io_read(self, req) {
        if req.port == 0x70 {
            return self.index;
        }
        if req.port == 0x71 {
            let idx = self.index & 0x7F;
            if idx == 0x0C {
                # Reading Status C clears interrupt flags
                let val = self.cmos[0x0C];
                self.cmos[0x0C] = 0;
                return val;
            }
            return self.cmos[idx];
        }
        return 0xFF;
    }

    fn io_write(self, req) {
        let val = req.value & 0xFF;
        if req.port == 0x70 {
            self.index = val;
            return;
        }
        if req.port == 0x71 {
            let idx = self.index & 0x7F;
            # Protect read-only registers
            if idx == 0x0C or idx == 0x0D { return; }
            self.cmos[idx] = val;
            # If Register B changed, check for alarm/periodic IRQ enables
            if idx == 0x0B {
                self.update_interrupts();
            }
        }
    }

    fn update_interrupts(self) {
        let reg_b = self.cmos[0x0B];
        if (reg_b & 0x40) != 0 {
            # Periodic interrupt enabled
            self.cmos[0x0C] = self.cmos[0x0C] | 0xC0;
            self.raise_irq();
        }
    }

    fn tick_second(self) {
        # Advance RTC by one second (BCD mode)
        self.cmos[0x00] = self.bcd_inc(self.cmos[0x00], 0x59);
        if self.cmos[0x00] == 0 {
            self.cmos[0x02] = self.bcd_inc(self.cmos[0x02], 0x59);
            if self.cmos[0x02] == 0 {
                self.cmos[0x04] = self.bcd_inc(self.cmos[0x04], 0x23);
            }
        }
        # Set update-ended flag
        self.cmos[0x0C] = self.cmos[0x0C] | 0x10;
        if (self.cmos[0x0B] & 0x10) != 0 {
            self.cmos[0x0C] = self.cmos[0x0C] | 0x80;
            self.raise_irq();
        }
    }

    fn bcd_inc(self, val, max) {
        let lo = val & 0x0F;
        let hi = (val >> 4) & 0x0F;
        lo = lo + 1;
        if lo > 9 { lo = 0; hi = hi + 1; }
        let result = (hi << 4) | lo;
        if result > max { return 0; }
        return result;
    }

    fn snapshot(self) {
        return {"index": self.index, "cmos": self.cmos};
    }
}

# ===========================================
# PS/2 Controller (8042)
# ===========================================

class PS2Controller: Device {
    fn init(self) {
        super.init("ps2");
        self.irq_line = 1;
        self.reset();
    }

    fn reset(self) {
        self.status = 0x1C;        # System flag set, inhibit clear
        self.command_byte = 0x65;  # INT1 enabled, SYS flag, translate
        self.output_port = 0;
        self.data_buffer = [];
        self.mouse_buffer = [];
        self.expecting_data = 0;   # 0=none, 1=cmd byte write, 2=kbd cmd, 3=aux cmd
        self.port1_enabled = true;
        self.port2_enabled = true;
        self.self_test_passed = false;
    }

    fn io_read(self, req) {
        if req.port == 0x60 {
            # Data port
            self.status = self.status & ~0x21;  # Clear OBF and AUX OBF
            if len(self.data_buffer) > 0 {
                let val = self.data_buffer[0];
                self.data_buffer = self.data_buffer[1..];
                if len(self.data_buffer) > 0 {
                    self.status = self.status | 0x01;  # OBF
                }
                return val;
            }
            if len(self.mouse_buffer) > 0 {
                let val = self.mouse_buffer[0];
                self.mouse_buffer = self.mouse_buffer[1..];
                return val;
            }
            return 0;
        }
        if req.port == 0x64 {
            # Status port
            return self.status;
        }
        return 0xFF;
    }

    fn io_write(self, req) {
        let val = req.value & 0xFF;
        if req.port == 0x60 {
            # Data port write
            if self.expecting_data == 1 {
                # Writing command byte
                self.command_byte = val;
                self.expecting_data = 0;
                return;
            }
            if self.expecting_data == 2 {
                # Data for keyboard command
                self.expecting_data = 0;
                return;
            }
            if self.expecting_data == 3 {
                # Data for mouse (aux)
                self.expecting_data = 0;
                self.enqueue_mouse(0xFA);  # ACK
                return;
            }
            # Send to keyboard
            self.handle_keyboard_data(val);
            return;
        }
        if req.port == 0x64 {
            # Command port
            self.handle_command(val);
        }
    }

    fn handle_command(self, cmd) {
        if cmd == 0x20 {
            # Read command byte
            self.enqueue_data(self.command_byte);
        } else if cmd == 0x60 {
            # Write command byte
            self.expecting_data = 1;
        } else if cmd == 0xA7 {
            # Disable mouse port
            self.port2_enabled = false;
        } else if cmd == 0xA8 {
            # Enable mouse port
            self.port2_enabled = true;
        } else if cmd == 0xA9 {
            # Test mouse port
            self.enqueue_data(0x00);  # Pass
        } else if cmd == 0xAA {
            # Self test
            self.self_test_passed = true;
            self.enqueue_data(0x55);  # Pass
        } else if cmd == 0xAB {
            # Test keyboard port
            self.enqueue_data(0x00);  # Pass
        } else if cmd == 0xAD {
            # Disable keyboard port
            self.port1_enabled = false;
        } else if cmd == 0xAE {
            # Enable keyboard port
            self.port1_enabled = true;
        } else if cmd == 0xD0 {
            # Read output port
            self.enqueue_data(self.output_port);
        } else if cmd == 0xD1 {
            # Write output port
            self.expecting_data = 2;
        } else if cmd == 0xD3 {
            # Write to mouse output buffer
            self.expecting_data = 3;
        } else if cmd == 0xD4 {
            # Send to mouse
            self.expecting_data = 3;
        } else if cmd == 0xFE {
            # System reset (pulse reset line)
        }
    }

    fn handle_keyboard_data(self, val) {
        if val == 0xFF {
            # Reset keyboard
            self.enqueue_data(0xFA);  # ACK
            self.enqueue_data(0xAA);  # Self-test pass
        } else if val == 0xF4 {
            # Enable scanning
            self.enqueue_data(0xFA);
        } else if val == 0xF5 {
            # Disable scanning
            self.enqueue_data(0xFA);
        } else if val == 0xF2 {
            # Identify keyboard
            self.enqueue_data(0xFA);
            self.enqueue_data(0xAB);
            self.enqueue_data(0x83);
        } else if val == 0xED {
            # Set LEDs
            self.enqueue_data(0xFA);
            self.expecting_data = 2;
        } else if val == 0xF0 {
            # Set scancode set
            self.enqueue_data(0xFA);
            self.expecting_data = 2;
        } else {
            self.enqueue_data(0xFA);  # ACK for unknown
        }
    }

    fn enqueue_data(self, val) {
        push(self.data_buffer, val);
        self.status = self.status | 0x01;  # OBF
        if (self.command_byte & 0x01) != 0 {
            self.raise_irq();
        }
    }

    fn enqueue_mouse(self, val) {
        push(self.mouse_buffer, val);
        self.status = self.status | 0x21;  # OBF + AUX OBF
        if (self.command_byte & 0x02) != 0 {
            self.irq_line = 12;
            self.raise_irq();
            self.irq_line = 1;
        }
    }

    fn inject_scancode(self, code) {
        self.enqueue_data(code);
    }

    fn snapshot(self) {
        return {
            "status": self.status, "command_byte": self.command_byte,
            "data_buffer": self.data_buffer
        };
    }
}

# ===========================================
# UART 16550A (Serial Port)
# ===========================================

class UARTDevice: Device {
    fn init(self, base_port, irq) {
        super.init("uart");
        self.base = base_port;
        self.irq_line = irq;
        self.reset();
    }

    fn reset(self) {
        self.rbr = 0;          # Receive Buffer
        self.thr = 0;          # Transmit Holding
        self.ier = 0;          # Interrupt Enable
        self.iir = 0x01;       # Interrupt ID (no pending)
        self.fcr = 0;          # FIFO Control
        self.lcr = 0;          # Line Control
        self.mcr = 0;          # Modem Control
        self.lsr = 0x60;       # Line Status: THRE + TEMT
        self.msr = 0;          # Modem Status
        self.scr = 0;          # Scratch register
        self.dll = 0x0C;       # Divisor Latch Low (9600 baud)
        self.dlh = 0x00;       # Divisor Latch High
        self.fifo_enabled = false;
        self.rx_fifo = [];
        self.tx_fifo = [];
        self.rx_trigger = 1;
        self.output_callback = null;
    }

    fn io_read(self, req) {
        let offset = req.port - self.base;
        let dlab = (self.lcr & 0x80) != 0;

        if offset == 0 {
            if dlab { return self.dll; }
            # RBR — receive
            if len(self.rx_fifo) > 0 {
                let val = self.rx_fifo[0];
                self.rx_fifo = self.rx_fifo[1..];
                if len(self.rx_fifo) == 0 {
                    self.lsr = self.lsr & ~0x01;  # Clear DR
                }
                return val;
            }
            return 0;
        }
        if offset == 1 {
            if dlab { return self.dlh; }
            return self.ier;
        }
        if offset == 2 {
            let val = self.iir;
            self.iir = 0x01;  # Clear pending
            return val;
        }
        if offset == 3 { return self.lcr; }
        if offset == 4 { return self.mcr; }
        if offset == 5 { return self.lsr; }
        if offset == 6 { return self.msr; }
        if offset == 7 { return self.scr; }
        return 0xFF;
    }

    fn io_write(self, req) {
        let offset = req.port - self.base;
        let val = req.value & 0xFF;
        let dlab = (self.lcr & 0x80) != 0;

        if offset == 0 {
            if dlab { self.dll = val; return; }
            # THR — transmit
            self.thr = val;
            if self.output_callback != null {
                self.output_callback(val);
            }
            self.lsr = self.lsr | 0x60;  # THRE + TEMT
            if (self.ier & 0x02) != 0 {
                self.iir = 0x02;  # THRE interrupt
                self.raise_irq();
            }
            return;
        }
        if offset == 1 {
            if dlab { self.dlh = val; return; }
            self.ier = val & 0x0F;
            return;
        }
        if offset == 2 {
            # FCR
            self.fcr = val;
            self.fifo_enabled = (val & 0x01) != 0;
            if (val & 0x02) != 0 { self.rx_fifo = []; }
            if (val & 0x04) != 0 { self.tx_fifo = []; }
            let trigger = (val >> 6) & 0x3;
            if trigger == 0 { self.rx_trigger = 1; }
            else if trigger == 1 { self.rx_trigger = 4; }
            else if trigger == 2 { self.rx_trigger = 8; }
            else { self.rx_trigger = 14; }
            return;
        }
        if offset == 3 { self.lcr = val; return; }
        if offset == 4 {
            self.mcr = val;
            # Loopback mode: MCR bit 4
            if (val & 0x10) != 0 {
                self.msr = ((val & 0x03) << 4) | ((val & 0x0C) << 2);
            }
            return;
        }
        if offset == 7 { self.scr = val; return; }
    }

    fn receive_byte(self, b) {
        push(self.rx_fifo, b);
        self.lsr = self.lsr | 0x01;  # Data Ready
        if (self.ier & 0x01) != 0 and len(self.rx_fifo) >= self.rx_trigger {
            self.iir = 0x04;  # Received Data Available
            self.raise_irq();
        }
    }
}

# ===========================================
# DMA 8237 Controller
# ===========================================

class DMAController: Device {
    fn init(self, base_port) {
        super.init("dma");
        self.base = base_port;
        self.channels = [];
        for i in 0..4 {
            push(self.channels, {
                "base_addr": 0,
                "base_count": 0,
                "current_addr": 0,
                "current_count": 0,
                "mode": 0,
                "page": 0,
                "masked": true
            });
        }
        self.status = 0;
        self.command = 0;
        self.temp = 0;
        self.flip_flop = false;  # Low/high byte toggle
        self.mask = 0x0F;        # All channels masked
    }

    fn reset(self) {
        for ch in self.channels {
            ch["base_addr"] = 0;
            ch["base_count"] = 0;
            ch["current_addr"] = 0;
            ch["current_count"] = 0;
            ch["mode"] = 0;
            ch["masked"] = true;
        }
        self.flip_flop = false;
        self.mask = 0x0F;
    }

    fn io_read(self, req) {
        let port = req.port - self.base;
        # Current address/count reads
        if port < 8 {
            let ch = port / 2;
            let is_count = (port & 1) != 0;
            let val = 0;
            if is_count { val = self.channels[ch]["current_count"]; }
            else { val = self.channels[ch]["current_addr"]; }
            if self.flip_flop {
                self.flip_flop = false;
                return (val >> 8) & 0xFF;
            }
            self.flip_flop = true;
            return val & 0xFF;
        }
        if port == 8 { return self.status; }
        return 0xFF;
    }

    fn io_write(self, req) {
        let port = req.port - self.base;
        let val = req.value & 0xFF;

        if port < 8 {
            let ch = port / 2;
            let is_count = (port & 1) != 0;
            if self.flip_flop {
                if is_count {
                    self.channels[ch]["base_count"] = (self.channels[ch]["base_count"] & 0xFF) | (val << 8);
                    self.channels[ch]["current_count"] = self.channels[ch]["base_count"];
                } else {
                    self.channels[ch]["base_addr"] = (self.channels[ch]["base_addr"] & 0xFF) | (val << 8);
                    self.channels[ch]["current_addr"] = self.channels[ch]["base_addr"];
                }
                self.flip_flop = false;
            } else {
                if is_count {
                    self.channels[ch]["base_count"] = (self.channels[ch]["base_count"] & 0xFF00) | val;
                } else {
                    self.channels[ch]["base_addr"] = (self.channels[ch]["base_addr"] & 0xFF00) | val;
                }
                self.flip_flop = true;
            }
            return;
        }
        if port == 8 { self.command = val; return; }
        if port == 10 {
            # Single mask
            let ch = val & 0x03;
            self.channels[ch]["masked"] = ((val & 0x04) != 0);
            return;
        }
        if port == 11 {
            # Mode register
            let ch = val & 0x03;
            self.channels[ch]["mode"] = val;
            return;
        }
        if port == 12 {
            self.flip_flop = false;
            return;
        }
        if port == 13 {
            self.reset();
            return;
        }
        if port == 14 {
            self.mask = 0;
            return;
        }
        if port == 15 {
            self.mask = val & 0x0F;
            return;
        }
    }

    fn set_page(self, channel, page) {
        if channel < 4 {
            self.channels[channel]["page"] = page;
        }
    }
}

# DMA Page Register handler (ports 0x81-0x8F)
class DMAPageRegisters: Device {
    fn init(self, dma1, dma2) {
        super.init("dma_page");
        self.dma1 = dma1;
        self.dma2 = dma2;
        self.pages = [];
        for i in 0..16 { push(self.pages, 0); }
    }

    fn io_read(self, req) {
        let idx = req.port - 0x80;
        if idx >= 0 and idx < 16 {
            return self.pages[idx];
        }
        return 0xFF;
    }

    fn io_write(self, req) {
        let idx = req.port - 0x80;
        let val = req.value & 0xFF;
        if idx >= 0 and idx < 16 {
            self.pages[idx] = val;
        }
        # Map page registers to DMA channels
        if idx == 1 { self.dma1.set_page(2, val); }
        if idx == 2 { self.dma1.set_page(3, val); }
        if idx == 3 { self.dma1.set_page(1, val); }
        if idx == 7 { self.dma1.set_page(0, val); }
    }
}

# ===========================================
# ACPI Power Management
# ===========================================

const ACPI_PM_BASE_PORT = 0x600;

class ACPIPMDevice: Device {
    fn init(self) {
        super.init("acpi_pm");
        self.irq_line = 9;
        self.reset();
    }

    fn reset(self) {
        self.pm1_sts = 0;       # PM1 Status
        self.pm1_en = 0;        # PM1 Enable
        self.pm1_cnt = 0;       # PM1 Control
        self.pm_tmr = 0;        # PM Timer (24-bit, 3.579545 MHz)
        self.gpe0_sts = 0;      # GPE0 Status
        self.gpe0_en = 0;       # GPE0 Enable
        self.smi_cmd = 0;
        self.acpi_enabled = false;
        self.shutdown_callback = null;
    }

    fn io_read(self, req) {
        let offset = req.port - ACPI_PM_BASE_PORT;
        if offset == 0 { return self.pm1_sts; }                # PM1_STS
        if offset == 2 { return self.pm1_en; }                 # PM1_EN
        if offset == 4 { return self.pm1_cnt; }                # PM1_CNT
        if offset == 8 { return self.pm_tmr & 0xFFFFFF; }      # PM_TMR (24-bit)
        if offset == 0x20 { return self.gpe0_sts; }            # GPE0_STS
        if offset == 0x24 { return self.gpe0_en; }             # GPE0_EN
        return 0;
    }

    fn io_write(self, req) {
        let offset = req.port - ACPI_PM_BASE_PORT;
        let val = req.value;

        if offset == 0 {
            # PM1_STS — write-1-to-clear
            self.pm1_sts = self.pm1_sts & ~val;
            return;
        }
        if offset == 2 {
            self.pm1_en = val;
            return;
        }
        if offset == 4 {
            # PM1_CNT — SLP_EN(bit 13) + SLP_TYP(bits 10-12)
            self.pm1_cnt = val;
            if (val & (1 << 13)) != 0 {
                let slp_typ = (val >> 10) & 0x7;
                self.handle_sleep(slp_typ);
            }
            return;
        }
        if offset == 0x20 {
            self.gpe0_sts = self.gpe0_sts & ~val;
            return;
        }
        if offset == 0x24 {
            self.gpe0_en = val;
            return;
        }
    }

    fn handle_sleep(self, slp_typ) {
        if slp_typ == 5 {
            # S5 = Soft Off
            if self.shutdown_callback != null {
                self.shutdown_callback();
            }
        }
        # S3 = Suspend to RAM: freeze CPU, keep RAM powered
    }

    fn tick(self) {
        # PM Timer runs at 3.579545 MHz
        self.pm_tmr = (self.pm_tmr + 1) & 0xFFFFFF;
        if self.pm_tmr == 0 {
            # Timer overflow
            self.pm1_sts = self.pm1_sts | (1 << 0);  # TMR_STS
            if (self.pm1_en & (1 << 0)) != 0 {
                self.raise_irq();
            }
        }
    }
}

# SMI Command Port (0xB2)
class SMICommandPort: Device {
    fn init(self, acpi_pm) {
        super.init("smi_cmd");
        self.acpi_pm = acpi_pm;
    }

    fn io_write(self, req) {
        let val = req.value & 0xFF;
        if val == 0xF0 {
            # ACPI Enable
            self.acpi_pm.acpi_enabled = true;
        } else if val == 0xF1 {
            # ACPI Disable
            self.acpi_pm.acpi_enabled = false;
        }
    }
}

# Reset Control Register (0xCF9)
class ResetControlDevice: Device {
    fn init(self) {
        super.init("reset_ctrl");
        self.reset_callback = null;
    }

    fn io_write(self, req) {
        let val = req.value & 0xFF;
        if (val & 0x04) != 0 {
            # System reset requested
            if (val & 0x02) != 0 {
                # Hard reset
                if self.reset_callback != null {
                    self.reset_callback("hard");
                }
            } else {
                # Soft reset
                if self.reset_callback != null {
                    self.reset_callback("soft");
                }
            }
        }
    }
}

# ===========================================
# PCI Host Bridge (Config Space)
# ===========================================

class PCIConfigSpace: Device {
    fn init(self) {
        super.init("pci_config");
        self.config_addr = 0;
        self.devices = [];
    }

    fn register_device(self, device) {
        push(self.devices, device);
    }

    fn io_read(self, req) {
        if req.port >= 0xCF8 and req.port <= 0xCFB {
            # Read config address register
            let shift = (req.port - 0xCF8) * 8;
            return (self.config_addr >> shift) & 0xFF;
        }
        if req.port >= 0xCFC and req.port <= 0xCFF {
            if (self.config_addr & 0x80000000) == 0 {
                return 0xFF;
            }
            let dword = self.read_config();
            let byte_offset = req.port - 0xCFC;
            if req.size == 1 {
                return (dword >> (byte_offset * 8)) & 0xFF;
            }
            if req.size == 2 {
                return (dword >> (byte_offset * 8)) & 0xFFFF;
            }
            return dword;
        }
        return 0xFF;
    }

    fn io_write(self, req) {
        if req.port >= 0xCF8 and req.port <= 0xCFB {
            if req.size == 4 {
                self.config_addr = req.value;
            } else {
                let shift = (req.port - 0xCF8) * 8;
                let mask = 0;
                if req.size == 1 { mask = 0xFF << shift; }
                else { mask = 0xFFFF << shift; }
                self.config_addr = (self.config_addr & ~mask) | ((req.value << shift) & mask);
            }
            return;
        }
        if req.port >= 0xCFC and req.port <= 0xCFF {
            if (self.config_addr & 0x80000000) == 0 { return; }
            let byte_offset = req.port - 0xCFC;
            self.write_config(req.value, req.size, byte_offset);
        }
    }

    fn read_config(self) {
        let bus = (self.config_addr >> 16) & 0xFF;
        let slot = (self.config_addr >> 11) & 0x1F;
        let func = (self.config_addr >> 8) & 0x07;
        let offset = self.config_addr & 0xFC;
        for dev in self.devices {
            if dev.pci_bus == bus and dev.pci_device == slot and dev.pci_function == func {
                return dev.pci_read_config(offset);
            }
        }
        return 0xFFFFFFFF;
    }

    fn write_config(self, value, size, byte_offset) {
        let bus = (self.config_addr >> 16) & 0xFF;
        let slot = (self.config_addr >> 11) & 0x1F;
        let func = (self.config_addr >> 8) & 0x07;
        let offset = (self.config_addr & 0xFC) + byte_offset;
        for dev in self.devices {
            if dev.pci_bus == bus and dev.pci_device == slot and dev.pci_function == func {
                dev.pci_write_config(offset, value, size);
                return;
            }
        }
    }
}

# ===========================================
# PCI Device Base
# ===========================================

class PCIDevice: Device {
    fn init(self, name, vendor_id, device_id) {
        super.init(name);
        self.vendor_id = vendor_id;
        self.device_id = device_id;
        self.command = 0;
        self.status = 0x0010;   # Capabilities List
        self.class_code = 0;
        self.subclass = 0;
        self.prog_if = 0;
        self.revision = 1;
        self.header_type = 0;
        self.pci_bus = 0;
        self.pci_device = 0;
        self.pci_function = 0;
        self.subsystem_vendor = 0;
        self.subsystem_id = 0;
        self.interrupt_line = 0;
        self.interrupt_pin = 1;    # INTA#
        self.bars = [0, 0, 0, 0, 0, 0];
        self.bar_sizes = [0, 0, 0, 0, 0, 0];
        self.bar_types = [0, 0, 0, 0, 0, 0];  # 0=MMIO, 1=IO
        self.config_space = [];
        for i in 0..256 { push(self.config_space, 0); }
        # MSI capability
        self.msi_capable = false;
        self.msi_enabled = false;
        self.msi_addr = 0;
        self.msi_data = 0;
        self.msi_cap_offset = 0x40;
        # MSI-X capability
        self.msix_capable = false;
        self.msix_enabled = false;
        self.msix_table = [];
        self.msix_pba = [];
    }

    fn pci_read_config(self, offset) {
        if offset == 0x00 { return (self.device_id << 16) | self.vendor_id; }
        if offset == 0x04 { return (self.status << 16) | self.command; }
        if offset == 0x08 {
            return (self.class_code << 24) | (self.subclass << 16) |
                   (self.prog_if << 8) | self.revision;
        }
        if offset == 0x0C { return self.header_type << 16; }
        if offset >= 0x10 and offset <= 0x24 {
            let idx = (offset - 0x10) / 4;
            return self.bars[idx];
        }
        if offset == 0x2C {
            return (self.subsystem_id << 16) | self.subsystem_vendor;
        }
        if offset == 0x34 {
            # Capabilities pointer
            if self.msi_capable { return self.msi_cap_offset; }
            return 0;
        }
        if offset == 0x3C {
            return (self.interrupt_pin << 8) | self.interrupt_line;
        }
        # MSI capability registers
        if self.msi_capable and offset >= self.msi_cap_offset and offset < self.msi_cap_offset + 16 {
            return self.read_msi_cap(offset - self.msi_cap_offset);
        }
        return 0;
    }

    fn pci_write_config(self, offset, value, size) {
        if size == 0 { size = 4; }
        if offset == 0x04 {
            if size >= 2 { self.command = value & 0x0547; }
            return;
        }
        if offset >= 0x10 and offset <= 0x24 {
            let idx = (offset - 0x10) / 4;
            if value == 0xFFFFFFFF {
                # BAR sizing probe
                if self.bar_sizes[idx] > 0 {
                    let mask = ~(self.bar_sizes[idx] - 1) & 0xFFFFFFFF;
                    if self.bar_types[idx] == 1 {
                        self.bars[idx] = (mask & 0xFFFC) | 0x01;
                    } else {
                        self.bars[idx] = mask & 0xFFFFFFF0;
                    }
                } else {
                    self.bars[idx] = 0;
                }
            } else {
                if self.bar_types[idx] == 1 {
                    self.bars[idx] = (value & 0xFFFC) | 0x01;
                } else {
                    self.bars[idx] = value & 0xFFFFFFF0;
                }
            }
            return;
        }
        if offset == 0x3C {
            self.interrupt_line = value & 0xFF;
            return;
        }
        # MSI capability writes
        if self.msi_capable and offset >= self.msi_cap_offset and offset < self.msi_cap_offset + 16 {
            self.write_msi_cap(offset - self.msi_cap_offset, value);
        }
    }

    fn setup_bar(self, index, size, is_io) {
        self.bar_sizes[index] = size;
        self.bar_types[index] = 1 if is_io else 0;
        if is_io {
            self.bars[index] = 0x01;  # IO space indicator
        } else {
            self.bars[index] = 0x00;  # MMIO 32-bit non-prefetchable
        }
    }

    fn get_bar_addr(self, index) {
        if self.bar_types[index] == 1 {
            return self.bars[index] & 0xFFFC;
        }
        return self.bars[index] & 0xFFFFFFF0;
    }

    fn enable_msi(self) {
        self.msi_capable = true;
        self.status = self.status | 0x0010;  # Capabilities List bit
    }

    fn read_msi_cap(self, offset) {
        if offset == 0 {
            # Capability ID (0x05 = MSI) + Next Pointer + Message Control
            let msg_ctrl = 0;
            if self.msi_enabled { msg_ctrl = msg_ctrl | 0x01; }
            return 0x05 | (0x00 << 8) | (msg_ctrl << 16);
        }
        if offset == 4 { return self.msi_addr & 0xFFFFFFFF; }
        if offset == 8 { return (self.msi_addr >> 32) & 0xFFFFFFFF; }
        if offset == 12 { return self.msi_data; }
        return 0;
    }

    fn write_msi_cap(self, offset, value) {
        if offset == 0 {
            let msg_ctrl = (value >> 16) & 0xFFFF;
            self.msi_enabled = (msg_ctrl & 0x01) != 0;
            return;
        }
        if offset == 4 { self.msi_addr = (self.msi_addr & 0xFFFFFFFF00000000) | (value & 0xFFFFFFFF); }
        if offset == 8 { self.msi_addr = (self.msi_addr & 0xFFFFFFFF) | ((value & 0xFFFFFFFF) << 32); }
        if offset == 12 { self.msi_data = value & 0xFFFF; }
    }

    fn send_msi(self, irq_router) {
        if self.msi_enabled and irq_router != null {
            irq_router.route_msi(self.msi_addr, self.msi_data);
        }
    }
}

# ===========================================
# Virtio Block Device (virtio-blk)
# ===========================================

const VIRTIO_STATUS_ACKNOWLEDGE = 1;
const VIRTIO_STATUS_DRIVER      = 2;
const VIRTIO_STATUS_DRIVER_OK   = 4;
const VIRTIO_STATUS_FEATURES_OK = 8;
const VIRTIO_STATUS_FAILED      = 128;

const VIRTIO_BLK_T_IN   = 0;
const VIRTIO_BLK_T_OUT  = 1;
const VIRTIO_BLK_T_FLUSH = 4;

class VirtioBlockDevice: PCIDevice {
    fn init(self) {
        super.init("virtio_blk", 0x1AF4, 0x1042);  # virtio 1.0 PCI
        self.class_code = 0x01;
        self.subclass = 0x00;
        self.subsystem_vendor = 0x1AF4;
        self.subsystem_id = 0x0002;
        self.revision = 1;
        self.enable_msi();

        # BAR0: device config MMIO (4KB)
        self.setup_bar(0, 4096, false);
        # BAR4: notification area (4KB)
        self.setup_bar(4, 4096, false);

        self.disk_image = null;
        self.disk_data = null;
        self.capacity = 0;          # In 512-byte sectors
        self.reset();
    }

    fn reset(self) {
        self.device_status = 0;
        self.device_features = 0;
        self.driver_features = 0;
        self.queue_select = 0;
        self.queue_size = 256;
        self.queue_desc = 0;
        self.queue_avail = 0;
        self.queue_used = 0;
        self.queue_enable = false;
        self.isr_status = 0;
        self.config_gen = 0;
        # Feature bits: VIRTIO_BLK_F_SIZE_MAX, VIRTIO_BLK_F_SEG_MAX, VIRTIO_BLK_F_BLK_SIZE
        self.device_features = (1 << 6) | (1 << 2) | (1 << 1);
    }

    fn attach_disk(self, path) {
        self.disk_image = path;
        self.disk_data = systems.read_file(path);
        if self.disk_data != null {
            self.capacity = len(self.disk_data) / 512;
        }
    }

    fn mmio_read(self, req) {
        let offset = req.addr & 0xFFF;

        # Common config (offset 0x000-0x03F)
        if offset == 0x00 { return self.device_features; }
        if offset == 0x04 { return self.driver_features; }
        if offset == 0x08 { return self.queue_size; }
        if offset == 0x0C { return self.queue_select; }
        if offset == 0x14 { return self.device_status; }
        if offset == 0x18 { return self.config_gen; }
        if offset == 0x1C { return self.isr_status; }

        # Device-specific config (capacity)
        if offset == 0x100 { return self.capacity & 0xFFFFFFFF; }
        if offset == 0x104 { return (self.capacity >> 32) & 0xFFFFFFFF; }
        if offset == 0x108 { return 0x200; }  # blk_size = 512
        return 0;
    }

    fn mmio_write(self, req) {
        let offset = req.addr & 0xFFF;
        let val = req.value;

        if offset == 0x04 { self.driver_features = val; return; }
        if offset == 0x08 { self.queue_size = val & 0xFFFF; return; }
        if offset == 0x0C { self.queue_select = val; return; }
        if offset == 0x10 {
            self.queue_enable = (val != 0);
            return;
        }
        if offset == 0x14 {
            self.device_status = val & 0xFF;
            if val == 0 { self.reset(); }
            return;
        }
        if offset == 0x20 { self.queue_desc = val; return; }
        if offset == 0x28 { self.queue_avail = val; return; }
        if offset == 0x30 { self.queue_used = val; return; }

        # Notification (queue kick)
        if offset >= 0xF00 {
            self.process_queue();
        }
    }

    fn process_queue(self) {
        # Process virtqueue requests
        if !self.queue_enable or self.disk_data == null {
            return;
        }
        self.isr_status = self.isr_status | 0x01;
        self.raise_irq();
    }

    fn do_io(self, guest_mem, sector, count, buf_addr, is_write) {
        let offset = sector * 512;
        let length = count * 512;
        if is_write {
            for i in 0..length {
                let b = guest_mem.read(buf_addr + i, 1);
                if offset + i < len(self.disk_data) {
                    systems.poke_u8(self.disk_data + offset + i, b);
                }
            }
        } else {
            for i in 0..length {
                if offset + i < len(self.disk_data) {
                    let b = systems.peek_u8(self.disk_data + offset + i);
                    guest_mem.write(buf_addr + i, 1, b);
                }
            }
        }
    }

    fn snapshot(self) {
        return {
            "status": self.device_status, "capacity": self.capacity,
            "isr": self.isr_status
        };
    }
}

# ===========================================
# AHCI Controller (SATA)
# ===========================================

const AHCI_GHC_HR    = (1 << 0);   # HBA Reset
const AHCI_GHC_IE    = (1 << 1);   # Interrupt Enable
const AHCI_GHC_AE    = (1 << 31);  # AHCI Enable

class AHCIController: PCIDevice {
    fn init(self) {
        super.init("ahci", 0x8086, 0x2922);
        self.class_code = 0x01;
        self.subclass = 0x06;
        self.prog_if = 0x01;
        self.revision = 2;
        self.enable_msi();
        # BAR5: ABAR (AHCI Base Memory Register) — 4KB
        self.setup_bar(5, 4096, false);
        self.reset();
    }

    fn reset(self) {
        # Generic Host Control
        self.cap = 0x40141F05;     # 6 ports, NCQ, 64-bit, ISS=Gen3, 32 cmd slots
        self.ghc = AHCI_GHC_AE;   # AHCI mode enabled
        self.is_reg = 0;           # Interrupt Status
        self.pi = 0x3F;            # Ports Implemented (6 ports)
        self.vs = 0x00010301;      # Version 1.3.1
        self.cap2 = 0;
        # Port registers (6 ports)
        self.ports = [];
        for i in 0..6 {
            push(self.ports, {
                "clb": 0, "clbu": 0, "fb": 0, "fbu": 0,
                "is": 0, "ie": 0, "cmd": 0, "tfd": 0x7F,
                "sig": 0xFFFFFFFF, "ssts": 0, "sctl": 0,
                "serr": 0, "sact": 0, "ci": 0
            });
        }
        self.disks = [];
    }

    fn attach_disk(self, port, path) {
        if port < 6 {
            while len(self.disks) <= port { push(self.disks, null); }
            self.disks[port] = systems.read_file(path);
            # Device present: IPM=Active, DET=Device+Phy
            self.ports[port]["ssts"] = 0x113;
            self.ports[port]["sig"] = 0x00000101;  # SATA ATA
            self.ports[port]["tfd"] = 0x50;        # BSY=0, DRQ=0, DRDY=1
        }
    }

    fn mmio_read(self, req) {
        let offset = req.addr & 0xFFF;
        # GHC registers (0x00-0x2B)
        if offset == 0x00 { return self.cap; }
        if offset == 0x04 { return self.ghc; }
        if offset == 0x08 { return self.is_reg; }
        if offset == 0x0C { return self.pi; }
        if offset == 0x10 { return self.vs; }
        if offset == 0x24 { return self.cap2; }

        # Port registers (0x100 + port*0x80 + reg)
        if offset >= 0x100 {
            let port_offset = offset - 0x100;
            let port_num = port_offset / 0x80;
            let reg = port_offset % 0x80;
            if port_num < 6 {
                return self.read_port_reg(port_num, reg);
            }
        }
        return 0;
    }

    fn mmio_write(self, req) {
        let offset = req.addr & 0xFFF;
        let val = req.value;

        if offset == 0x04 {
            if (val & AHCI_GHC_HR) != 0 {
                self.reset();
                return;
            }
            self.ghc = val | AHCI_GHC_AE;
            return;
        }
        if offset == 0x08 {
            self.is_reg = self.is_reg & ~val;  # Write-1-to-clear
            return;
        }
        if offset >= 0x100 {
            let port_offset = offset - 0x100;
            let port_num = port_offset / 0x80;
            let reg = port_offset % 0x80;
            if port_num < 6 {
                self.write_port_reg(port_num, reg, val);
            }
        }
    }

    fn read_port_reg(self, port, reg) {
        let p = self.ports[port];
        if reg == 0x00 { return p["clb"]; }
        if reg == 0x04 { return p["clbu"]; }
        if reg == 0x08 { return p["fb"]; }
        if reg == 0x0C { return p["fbu"]; }
        if reg == 0x10 { return p["is"]; }
        if reg == 0x14 { return p["ie"]; }
        if reg == 0x18 { return p["cmd"]; }
        if reg == 0x20 { return p["tfd"]; }
        if reg == 0x24 { return p["sig"]; }
        if reg == 0x28 { return p["ssts"]; }
        if reg == 0x2C { return p["sctl"]; }
        if reg == 0x30 { return p["serr"]; }
        if reg == 0x34 { return p["sact"]; }
        if reg == 0x38 { return p["ci"]; }
        return 0;
    }

    fn write_port_reg(self, port, reg, val) {
        let p = self.ports[port];
        if reg == 0x00 { p["clb"] = val; return; }
        if reg == 0x04 { p["clbu"] = val; return; }
        if reg == 0x08 { p["fb"] = val; return; }
        if reg == 0x0C { p["fbu"] = val; return; }
        if reg == 0x10 { p["is"] = p["is"] & ~val; return; }
        if reg == 0x14 { p["ie"] = val; return; }
        if reg == 0x18 {
            # PxCMD
            p["cmd"] = val;
            if (val & 0x01) != 0 {
                p["cmd"] = p["cmd"] | (1 << 15);  # CR = running
            }
            return;
        }
        if reg == 0x2C { p["sctl"] = val; return; }
        if reg == 0x30 { p["serr"] = p["serr"] & ~val; return; }
        if reg == 0x34 { p["sact"] = val; return; }
        if reg == 0x38 {
            # PxCI — Command Issue
            p["ci"] = val;
            # Process commands immediately (simplified)
            p["ci"] = 0;
            p["is"] = p["is"] | 0x01;  # DHRS — Device to Host Register FIS
            if (self.ghc & AHCI_GHC_IE) != 0 and (p["ie"] & 0x01) != 0 {
                self.is_reg = self.is_reg | (1 << port);
                self.raise_irq();
            }
            return;
        }
    }
}

# ===========================================
# Intel E1000 Network Interface
# ===========================================

# E1000 Register offsets
const E1000_CTRL   = 0x0000;
const E1000_STATUS = 0x0008;
const E1000_EECD   = 0x0010;
const E1000_EERD   = 0x0014;
const E1000_ICR    = 0x00C0;
const E1000_ICS    = 0x00C8;
const E1000_IMS    = 0x00D0;
const E1000_IMC    = 0x00D8;
const E1000_RCTL   = 0x0100;
const E1000_TCTL   = 0x0400;
const E1000_RDBAL  = 0x2800;
const E1000_RDBAH  = 0x2804;
const E1000_RDLEN  = 0x2808;
const E1000_RDH    = 0x2810;
const E1000_RDT    = 0x2818;
const E1000_TDBAL  = 0x3800;
const E1000_TDBAH  = 0x3804;
const E1000_TDLEN  = 0x3808;
const E1000_TDH    = 0x3810;
const E1000_TDT    = 0x3818;
const E1000_RAL    = 0x5400;
const E1000_RAH    = 0x5404;
const E1000_MTA    = 0x5200;

class E1000Device: PCIDevice {
    fn init(self) {
        super.init("e1000", 0x8086, 0x100E);
        self.class_code = 0x02;
        self.subclass = 0x00;
        self.subsystem_vendor = 0x8086;
        self.subsystem_id = 0x001E;
        self.revision = 3;
        self.enable_msi();
        # BAR0: MMIO registers (128KB)
        self.setup_bar(0, 131072, false);
        # BAR1: IO ports (64 bytes)
        self.setup_bar(1, 64, true);
        self.reset();
    }

    fn reset(self) {
        self.ctrl = 0;
        self.status_reg = 0x80080783;   # Link up, speed 1000, FD
        self.eecd = 0;
        self.eerd = 0;
        self.icr = 0;
        self.ims = 0;
        self.rctl = 0;
        self.tctl = 0;
        self.rdbal = 0;
        self.rdbah = 0;
        self.rdlen = 0;
        self.rdh = 0;
        self.rdt = 0;
        self.tdbal = 0;
        self.tdbah = 0;
        self.tdlen = 0;
        self.tdh = 0;
        self.tdt = 0;
        self.mac = [0x52, 0x54, 0x00, 0x12, 0x34, 0x56];
        # EEPROM (64 words)
        self.eeprom = [];
        for i in 0..64 { push(self.eeprom, 0); }
        # MAC address in EEPROM words 0-2
        self.eeprom[0] = self.mac[0] | (self.mac[1] << 8);
        self.eeprom[1] = self.mac[2] | (self.mac[3] << 8);
        self.eeprom[2] = self.mac[4] | (self.mac[5] << 8);
        # Multicast Table Array (128 dwords)
        self.mta = [];
        for i in 0..128 { push(self.mta, 0); }
        # TX/RX callbacks
        self.tx_callback = null;
        self.rx_queue = [];
    }

    fn mmio_read(self, req) {
        let offset = req.addr & 0x1FFFF;

        if offset == E1000_CTRL { return self.ctrl; }
        if offset == E1000_STATUS { return self.status_reg; }
        if offset == E1000_EECD { return self.eecd; }
        if offset == E1000_EERD {
            # EEPROM read
            let addr = (self.eerd >> 8) & 0xFF;
            if addr < 64 {
                return (self.eeprom[addr] << 16) | (1 << 4) | (addr << 8);
            }
            return self.eerd;
        }
        if offset == E1000_ICR {
            let val = self.icr;
            self.icr = 0;  # Read-to-clear
            return val;
        }
        if offset == E1000_IMS { return self.ims; }
        if offset == E1000_RCTL { return self.rctl; }
        if offset == E1000_TCTL { return self.tctl; }
        if offset == E1000_RDBAL { return self.rdbal; }
        if offset == E1000_RDBAH { return self.rdbah; }
        if offset == E1000_RDLEN { return self.rdlen; }
        if offset == E1000_RDH { return self.rdh; }
        if offset == E1000_RDT { return self.rdt; }
        if offset == E1000_TDBAL { return self.tdbal; }
        if offset == E1000_TDBAH { return self.tdbah; }
        if offset == E1000_TDLEN { return self.tdlen; }
        if offset == E1000_TDH { return self.tdh; }
        if offset == E1000_TDT { return self.tdt; }
        if offset == E1000_RAL {
            return self.mac[0] | (self.mac[1] << 8) |
                   (self.mac[2] << 16) | (self.mac[3] << 24);
        }
        if offset == E1000_RAH {
            return self.mac[4] | (self.mac[5] << 8) | (1 << 31);  # AV=1
        }
        if offset >= E1000_MTA and offset < E1000_MTA + 512 {
            let idx = (offset - E1000_MTA) / 4;
            return self.mta[idx];
        }
        return 0;
    }

    fn mmio_write(self, req) {
        let offset = req.addr & 0x1FFFF;
        let val = req.value;

        if offset == E1000_CTRL {
            self.ctrl = val;
            if (val & (1 << 26)) != 0 {
                # RST bit — device reset
                self.reset();
            }
            return;
        }
        if offset == E1000_EECD { self.eecd = val; return; }
        if offset == E1000_EERD { self.eerd = val; return; }
        if offset == E1000_ICS {
            self.icr = self.icr | val;
            self.check_interrupts();
            return;
        }
        if offset == E1000_IMS {
            self.ims = self.ims | val;
            self.check_interrupts();
            return;
        }
        if offset == E1000_IMC {
            self.ims = self.ims & ~val;
            return;
        }
        if offset == E1000_RCTL { self.rctl = val; return; }
        if offset == E1000_TCTL { self.tctl = val; return; }
        if offset == E1000_RDBAL { self.rdbal = val; return; }
        if offset == E1000_RDBAH { self.rdbah = val; return; }
        if offset == E1000_RDLEN { self.rdlen = val; return; }
        if offset == E1000_RDH { self.rdh = val; return; }
        if offset == E1000_RDT {
            self.rdt = val;
            self.process_rx();
            return;
        }
        if offset == E1000_TDBAL { self.tdbal = val; return; }
        if offset == E1000_TDBAH { self.tdbah = val; return; }
        if offset == E1000_TDLEN { self.tdlen = val; return; }
        if offset == E1000_TDH { self.tdh = val; return; }
        if offset == E1000_TDT {
            self.tdt = val;
            self.process_tx();
            return;
        }
        if offset == E1000_RAL {
            self.mac[0] = val & 0xFF;
            self.mac[1] = (val >> 8) & 0xFF;
            self.mac[2] = (val >> 16) & 0xFF;
            self.mac[3] = (val >> 24) & 0xFF;
            return;
        }
        if offset == E1000_RAH {
            self.mac[4] = val & 0xFF;
            self.mac[5] = (val >> 8) & 0xFF;
            return;
        }
        if offset >= E1000_MTA and offset < E1000_MTA + 512 {
            let idx = (offset - E1000_MTA) / 4;
            self.mta[idx] = val;
            return;
        }
    }

    fn process_tx(self) {
        # Process transmit descriptors
        if (self.tctl & (1 << 1)) == 0 { return; }  # TCTL.EN
        # Signal TX completion
        self.icr = self.icr | 0x01;  # TXDW
        self.tdh = self.tdt;          # All consumed
        self.check_interrupts();
    }

    fn process_rx(self) {
        # Deliver queued packets to guest RX ring
        if (self.rctl & (1 << 1)) == 0 { return; }  # RCTL.EN
    }

    fn receive_packet(self, data) {
        push(self.rx_queue, data);
        self.icr = self.icr | 0x80;  # RXT0 — RX timer
        self.check_interrupts();
    }

    fn check_interrupts(self) {
        if (self.icr & self.ims) != 0 {
            self.raise_irq();
        }
    }

    fn snapshot(self) {
        return {
            "ctrl": self.ctrl, "status": self.status_reg,
            "mac": self.mac, "icr": self.icr, "ims": self.ims
        };
    }
}

# ===========================================
# Virtio Network Device
# ===========================================

class VirtioNetDevice: PCIDevice {
    fn init(self) {
        super.init("virtio_net", 0x1AF4, 0x1041);  # virtio 1.0
        self.class_code = 0x02;
        self.subclass = 0x00;
        self.subsystem_vendor = 0x1AF4;
        self.subsystem_id = 0x0001;
        self.enable_msi();
        self.setup_bar(0, 4096, false);
        self.mac = [0x52, 0x54, 0x00, 0x12, 0x34, 0x56];
        self.reset();
    }

    fn reset(self) {
        self.device_status = 0;
        self.device_features = (1 << 5) | (1 << 0);  # MAC, CSUM
        self.driver_features = 0;
        self.queue_select = 0;
        self.isr_status = 0;
        # Two virtqueues: 0=RX, 1=TX
        self.queues = [
            {"size": 256, "desc": 0, "avail": 0, "used": 0, "enable": false},
            {"size": 256, "desc": 0, "avail": 0, "used": 0, "enable": false}
        ];
        self.tx_callback = null;
        self.rx_queue = [];
    }

    fn mmio_read(self, req) {
        let offset = req.addr & 0xFFF;
        if offset == 0x00 { return self.device_features; }
        if offset == 0x14 { return self.device_status; }
        if offset == 0x1C { return self.isr_status; }
        # MAC address in device config
        if offset >= 0x100 and offset < 0x106 {
            return self.mac[offset - 0x100];
        }
        return 0;
    }

    fn mmio_write(self, req) {
        let offset = req.addr & 0xFFF;
        let val = req.value;
        if offset == 0x04 { self.driver_features = val; return; }
        if offset == 0x0C { self.queue_select = val; return; }
        if offset == 0x14 {
            self.device_status = val & 0xFF;
            if val == 0 { self.reset(); }
            return;
        }
        if offset >= 0xF00 {
            self.process_queue(val);
        }
    }

    fn process_queue(self, queue_idx) {
        if queue_idx == 1 {
            # TX queue notify
            self.isr_status = self.isr_status | 0x01;
            self.raise_irq();
        }
    }

    fn receive_packet(self, data) {
        push(self.rx_queue, data);
        self.isr_status = self.isr_status | 0x01;
        self.raise_irq();
    }
}

# ===========================================
# VGA + Bochs Display Adapter
# ===========================================

# Bochs VBE register indices
const VBE_DISPI_INDEX_ID          = 0;
const VBE_DISPI_INDEX_XRES        = 1;
const VBE_DISPI_INDEX_YRES        = 2;
const VBE_DISPI_INDEX_BPP         = 3;
const VBE_DISPI_INDEX_ENABLE      = 4;
const VBE_DISPI_INDEX_BANK        = 5;
const VBE_DISPI_INDEX_VIRT_WIDTH  = 6;
const VBE_DISPI_INDEX_VIRT_HEIGHT = 7;
const VBE_DISPI_INDEX_X_OFFSET    = 8;
const VBE_DISPI_INDEX_Y_OFFSET    = 9;
const VBE_DISPI_INDEX_VIDEO_MEM   = 10;

const VBE_DISPI_ID5       = 0xB0C5;
const VBE_DISPI_ENABLED   = 0x01;
const VBE_DISPI_LFB       = 0x40;
const VBE_DISPI_NOCLEARMEM = 0x80;

# VGA ports
const VGA_AC_INDEX     = 0x3C0;
const VGA_AC_WRITE     = 0x3C0;
const VGA_AC_READ      = 0x3C1;
const VGA_MISC_READ    = 0x3CC;
const VGA_MISC_WRITE   = 0x3C2;
const VGA_SEQ_INDEX    = 0x3C4;
const VGA_SEQ_DATA     = 0x3C5;
const VGA_DAC_MASK     = 0x3C6;
const VGA_DAC_READ_IDX = 0x3C7;
const VGA_DAC_WRITE_IDX = 0x3C8;
const VGA_DAC_DATA     = 0x3C9;
const VGA_GFX_INDEX    = 0x3CE;
const VGA_GFX_DATA     = 0x3CF;
const VGA_CRTC_INDEX   = 0x3D4;
const VGA_CRTC_DATA    = 0x3D5;
const VGA_ISR1         = 0x3DA;

class VGADevice: Device {
    fn init(self) {
        super.init("vga");
        self.reset();
    }

    fn reset(self) {
        self.misc_reg = 0x67;
        self.seq_index = 0;
        self.seq_regs = [];
        for i in 0..8 { push(self.seq_regs, 0); }
        self.gfx_index = 0;
        self.gfx_regs = [];
        for i in 0..16 { push(self.gfx_regs, 0); }
        self.crtc_index = 0;
        self.crtc_regs = [];
        for i in 0..25 { push(self.crtc_regs, 0); }
        self.ac_index = 0;
        self.ac_regs = [];
        for i in 0..21 { push(self.ac_regs, 0); }
        self.ac_flip_flop = false;
        self.dac_read_idx = 0;
        self.dac_write_idx = 0;
        self.dac_mask = 0xFF;
        self.dac_state = 0;
        self.dac = [];
        for i in 0..768 { push(self.dac, 0); }
        self.isr1_clear = false;
        self.latch = 0;
    }

    fn io_read(self, req) {
        let port = req.port;
        if port == VGA_MISC_READ { return self.misc_reg; }
        if port == VGA_SEQ_INDEX { return self.seq_index; }
        if port == VGA_SEQ_DATA { return self.seq_regs[self.seq_index & 0x07]; }
        if port == VGA_GFX_INDEX { return self.gfx_index; }
        if port == VGA_GFX_DATA { return self.gfx_regs[self.gfx_index & 0x0F]; }
        if port == VGA_CRTC_INDEX { return self.crtc_index; }
        if port == VGA_CRTC_DATA {
            if self.crtc_index < 25 { return self.crtc_regs[self.crtc_index]; }
            return 0;
        }
        if port == VGA_DAC_MASK { return self.dac_mask; }
        if port == VGA_DAC_DATA {
            let val = self.dac[self.dac_read_idx];
            self.dac_read_idx = (self.dac_read_idx + 1) % 768;
            return val;
        }
        if port == VGA_ISR1 {
            # Input Status Register 1: toggle retrace bits
            self.ac_flip_flop = false;
            self.isr1_clear = !self.isr1_clear;
            if self.isr1_clear { return 0x09; }  # VRetrace + Display
            return 0x00;
        }
        if port == VGA_AC_READ {
            if self.ac_index < 21 { return self.ac_regs[self.ac_index]; }
            return 0;
        }
        return 0xFF;
    }

    fn io_write(self, req) {
        let port = req.port;
        let val = req.value & 0xFF;
        if port == VGA_MISC_WRITE { self.misc_reg = val; return; }
        if port == VGA_SEQ_INDEX { self.seq_index = val; return; }
        if port == VGA_SEQ_DATA { self.seq_regs[self.seq_index & 0x07] = val; return; }
        if port == VGA_GFX_INDEX { self.gfx_index = val; return; }
        if port == VGA_GFX_DATA { self.gfx_regs[self.gfx_index & 0x0F] = val; return; }
        if port == VGA_CRTC_INDEX { self.crtc_index = val; return; }
        if port == VGA_CRTC_DATA {
            if self.crtc_index < 25 { self.crtc_regs[self.crtc_index] = val; }
            return;
        }
        if port == VGA_DAC_MASK { self.dac_mask = val; return; }
        if port == VGA_DAC_READ_IDX {
            self.dac_read_idx = val * 3;
            self.dac_state = 3;
            return;
        }
        if port == VGA_DAC_WRITE_IDX {
            self.dac_write_idx = val * 3;
            self.dac_state = 0;
            return;
        }
        if port == VGA_DAC_DATA {
            self.dac[self.dac_write_idx] = val & 0x3F;
            self.dac_write_idx = (self.dac_write_idx + 1) % 768;
            return;
        }
        if port == VGA_AC_INDEX or port == VGA_AC_WRITE {
            if !self.ac_flip_flop {
                self.ac_index = val & 0x1F;
            } else {
                if self.ac_index < 21 { self.ac_regs[self.ac_index] = val; }
            }
            self.ac_flip_flop = !self.ac_flip_flop;
            return;
        }
    }
}

class BochsGPU: PCIDevice {
    fn init(self) {
        super.init("bochs_gpu", 0x1234, 0x1111);
        self.class_code = 0x03;
        self.subclass = 0x00;
        self.revision = 2;
        self.enable_msi();
        # BAR0: framebuffer (16MB)
        self.setup_bar(0, 16 * 1024 * 1024, false);
        # BAR2: MMIO registers (4KB)
        self.setup_bar(2, 4096, false);
        self.framebuffer = systems.alloc(16 * 1024 * 1024);
        self.vga = VGADevice();
        self.reset();
    }

    fn reset(self) {
        self.vbe_index = 0;
        self.xres = 1024;
        self.yres = 768;
        self.bpp = 32;
        self.enable = 0;
        self.bank = 0;
        self.virt_width = 1024;
        self.virt_height = 768;
        self.x_offset = 0;
        self.y_offset = 0;
        self.video_mem_size = 16 * 1024 * 1024;
        self.vga.reset();
    }

    fn io_read(self, req) {
        # VBE Dispi ports: index at 0x01CE, data at 0x01CF
        if req.port == 0x01CE { return self.vbe_index; }
        if req.port == 0x01CF { return self.read_vbe_reg(); }
        # Delegate standard VGA ports to embedded VGA
        return self.vga.io_read(req);
    }

    fn io_write(self, req) {
        if req.port == 0x01CE {
            self.vbe_index = req.value & 0xFFFF;
            return;
        }
        if req.port == 0x01CF {
            self.write_vbe_reg(req.value & 0xFFFF);
            return;
        }
        self.vga.io_write(req);
    }

    fn read_vbe_reg(self) {
        if self.vbe_index == VBE_DISPI_INDEX_ID { return VBE_DISPI_ID5; }
        if self.vbe_index == VBE_DISPI_INDEX_XRES { return self.xres; }
        if self.vbe_index == VBE_DISPI_INDEX_YRES { return self.yres; }
        if self.vbe_index == VBE_DISPI_INDEX_BPP { return self.bpp; }
        if self.vbe_index == VBE_DISPI_INDEX_ENABLE { return self.enable; }
        if self.vbe_index == VBE_DISPI_INDEX_BANK { return self.bank; }
        if self.vbe_index == VBE_DISPI_INDEX_VIRT_WIDTH { return self.virt_width; }
        if self.vbe_index == VBE_DISPI_INDEX_VIRT_HEIGHT { return self.virt_height; }
        if self.vbe_index == VBE_DISPI_INDEX_X_OFFSET { return self.x_offset; }
        if self.vbe_index == VBE_DISPI_INDEX_Y_OFFSET { return self.y_offset; }
        if self.vbe_index == VBE_DISPI_INDEX_VIDEO_MEM {
            return self.video_mem_size / 65536;
        }
        return 0;
    }

    fn write_vbe_reg(self, val) {
        if self.vbe_index == VBE_DISPI_INDEX_ID { return; }
        if self.vbe_index == VBE_DISPI_INDEX_XRES {
            if val >= 1 and val <= 2560 { self.xres = val; }
            return;
        }
        if self.vbe_index == VBE_DISPI_INDEX_YRES {
            if val >= 1 and val <= 1600 { self.yres = val; }
            return;
        }
        if self.vbe_index == VBE_DISPI_INDEX_BPP {
            if val == 8 or val == 15 or val == 16 or val == 24 or val == 32 {
                self.bpp = val;
            }
            return;
        }
        if self.vbe_index == VBE_DISPI_INDEX_ENABLE {
            let was_enabled = (self.enable & VBE_DISPI_ENABLED) != 0;
            self.enable = val;
            if (val & VBE_DISPI_ENABLED) != 0 and !was_enabled {
                self.virt_width = self.xres;
                self.virt_height = self.yres;
                if (val & VBE_DISPI_NOCLEARMEM) == 0 {
                    systems.memset(self.framebuffer, 0, self.video_mem_size);
                }
            }
            return;
        }
        if self.vbe_index == VBE_DISPI_INDEX_BANK { self.bank = val; return; }
        if self.vbe_index == VBE_DISPI_INDEX_VIRT_WIDTH { self.virt_width = val; return; }
        if self.vbe_index == VBE_DISPI_INDEX_X_OFFSET { self.x_offset = val; return; }
        if self.vbe_index == VBE_DISPI_INDEX_Y_OFFSET { self.y_offset = val; return; }
    }

    fn mmio_read(self, req) {
        # Framebuffer reads
        let bar0_base = self.get_bar_addr(0);
        if bar0_base > 0 and req.addr >= bar0_base and req.addr < bar0_base + self.video_mem_size {
            let fb_off = req.addr - bar0_base;
            if req.size == 4 { return systems.peek_u32(self.framebuffer + fb_off); }
            if req.size == 2 { return systems.peek_u16(self.framebuffer + fb_off); }
            return systems.peek_u8(self.framebuffer + fb_off);
        }
        return 0;
    }

    fn mmio_write(self, req) {
        let bar0_base = self.get_bar_addr(0);
        if bar0_base > 0 and req.addr >= bar0_base and req.addr < bar0_base + self.video_mem_size {
            let fb_off = req.addr - bar0_base;
            if req.size == 4 { systems.poke_u32(self.framebuffer + fb_off, req.value); return; }
            if req.size == 2 { systems.poke_u16(self.framebuffer + fb_off, req.value); return; }
            systems.poke_u8(self.framebuffer + fb_off, req.value);
        }
    }

    fn get_display_info(self) {
        return {
            "width": self.xres,
            "height": self.yres,
            "bpp": self.bpp,
            "enabled": (self.enable & VBE_DISPI_ENABLED) != 0,
            "framebuffer": self.framebuffer,
            "stride": self.virt_width * (self.bpp / 8)
        };
    }

    fn snapshot(self) {
        return {
            "xres": self.xres, "yres": self.yres, "bpp": self.bpp,
            "enable": self.enable
        };
    }
}

# ===========================================
# I/O APIC
# ===========================================

const IOAPIC_ID_REG       = 0x00;
const IOAPIC_VER_REG      = 0x01;
const IOAPIC_ARB_REG      = 0x02;
const IOAPIC_REDIR_BASE   = 0x10;
const IOAPIC_MAX_REDIRS   = 24;

class IOAPICDevice: Device {
    fn init(self) {
        super.init("ioapic");
        self.id = 0;
        self.reg_select = 0;
        self.reset();
    }

    fn reset(self) {
        # 24 redirection entries (each 64-bit, stored as low + high 32-bit)
        self.redir = [];
        for i in 0..IOAPIC_MAX_REDIRS {
            push(self.redir, {
                "lo": (1 << 16),  # Masked by default
                "hi": 0
            });
        }
        self.irr = 0;  # IRQ request register
        self.lapic_callback = null;
    }

    fn mmio_read(self, req) {
        let offset = req.addr & 0xFF;
        if offset == 0x00 {
            # IOREGSEL
            return self.reg_select;
        }
        if offset == 0x10 {
            # IOWIN — read selected register
            return self.read_register(self.reg_select);
        }
        return 0;
    }

    fn mmio_write(self, req) {
        let offset = req.addr & 0xFF;
        if offset == 0x00 {
            self.reg_select = req.value & 0xFF;
            return;
        }
        if offset == 0x10 {
            self.write_register(self.reg_select, req.value);
            return;
        }
    }

    fn read_register(self, reg) {
        if reg == IOAPIC_ID_REG { return self.id << 24; }
        if reg == IOAPIC_VER_REG {
            return 0x00170011;  # Version 0x11, max redir entry 23
        }
        if reg == IOAPIC_ARB_REG { return self.id << 24; }
        if reg >= IOAPIC_REDIR_BASE and reg < IOAPIC_REDIR_BASE + (IOAPIC_MAX_REDIRS * 2) {
            let entry = (reg - IOAPIC_REDIR_BASE) / 2;
            let is_high = ((reg - IOAPIC_REDIR_BASE) % 2) == 1;
            if entry < IOAPIC_MAX_REDIRS {
                if is_high { return self.redir[entry]["hi"]; }
                return self.redir[entry]["lo"];
            }
        }
        return 0;
    }

    fn write_register(self, reg, val) {
        if reg == IOAPIC_ID_REG {
            self.id = (val >> 24) & 0x0F;
            return;
        }
        if reg >= IOAPIC_REDIR_BASE and reg < IOAPIC_REDIR_BASE + (IOAPIC_MAX_REDIRS * 2) {
            let entry = (reg - IOAPIC_REDIR_BASE) / 2;
            let is_high = ((reg - IOAPIC_REDIR_BASE) % 2) == 1;
            if entry < IOAPIC_MAX_REDIRS {
                if is_high {
                    self.redir[entry]["hi"] = val;
                } else {
                    self.redir[entry]["lo"] = val;
                }
            }
        }
    }

    fn set_irq(self, irq, assert) {
        if irq >= IOAPIC_MAX_REDIRS { return; }
        let bit = 1 << irq;
        if assert {
            self.irr = self.irr | bit;
            self.deliver_irq(irq);
        } else {
            self.irr = self.irr & ~bit;
        }
    }

    fn deliver_irq(self, irq) {
        let lo = self.redir[irq]["lo"];
        let hi = self.redir[irq]["hi"];
        # Check masked
        if (lo & (1 << 16)) != 0 { return; }
        let vector = lo & 0xFF;
        let delivery = (lo >> 8) & 0x7;
        let dest = (hi >> 24) & 0xFF;
        if self.lapic_callback != null {
            self.lapic_callback(dest, vector, delivery);
        }
    }

    fn snapshot(self) {
        return {"id": self.id, "redir": self.redir, "irr": self.irr};
    }
}

# ===========================================
# Local APIC
# ===========================================

class LAPICDevice: Device {
    fn init(self, cpu_id) {
        super.init("lapic");
        self.id = cpu_id;
        self.reset();
    }

    fn reset(self) {
        self.version = 0x00050014;  # Version 20, 6 LVT entries
        self.tpr = 0;              # Task Priority Register
        self.apr = 0;              # Arbitration Priority
        self.ppr = 0;              # Processor Priority
        self.eoi = 0;
        self.ldr = 0;              # Logical Destination
        self.dfr = 0xFFFFFFFF;     # Destination Format (flat)
        self.svr = 0xFF;           # Spurious Vector Register (APIC disabled)
        self.isr = [];             # In-Service Register (256 bits as 8 dwords)
        self.tmr = [];             # Trigger Mode Register
        self.irr_reg = [];         # Interrupt Request Register
        for i in 0..8 {
            push(self.isr, 0);
            push(self.tmr, 0);
            push(self.irr_reg, 0);
        }
        self.esr = 0;              # Error Status
        self.icr_lo = 0;
        self.icr_hi = 0;
        # LVT entries
        self.lvt_timer = 0x00010000;     # Masked
        self.lvt_thermal = 0x00010000;
        self.lvt_perfmon = 0x00010000;
        self.lvt_lint0 = 0x00010000;
        self.lvt_lint1 = 0x00010000;
        self.lvt_error = 0x00010000;
        # Timer
        self.timer_initial = 0;
        self.timer_current = 0;
        self.timer_divide = 0;
        self.timer_divide_val = 1;
        # Pending interrupts
        self.pending_vectors = [];
        self.ipi_callback = null;
    }

    fn mmio_read(self, req) {
        let offset = req.addr & 0xFFF;
        if offset == 0x020 { return self.id << 24; }
        if offset == 0x030 { return self.version; }
        if offset == 0x080 { return self.tpr; }
        if offset == 0x090 { return self.apr; }
        if offset == 0x0A0 { return self.ppr; }
        if offset == 0x0D0 { return self.ldr; }
        if offset == 0x0E0 { return self.dfr; }
        if offset == 0x0F0 { return self.svr; }
        # ISR (0x100-0x170)
        if offset >= 0x100 and offset <= 0x170 {
            return self.isr[(offset - 0x100) / 0x10];
        }
        # TMR (0x180-0x1F0)
        if offset >= 0x180 and offset <= 0x1F0 {
            return self.tmr[(offset - 0x180) / 0x10];
        }
        # IRR (0x200-0x270)
        if offset >= 0x200 and offset <= 0x270 {
            return self.irr_reg[(offset - 0x200) / 0x10];
        }
        if offset == 0x280 { return self.esr; }
        if offset == 0x300 { return self.icr_lo; }
        if offset == 0x310 { return self.icr_hi; }
        if offset == 0x320 { return self.lvt_timer; }
        if offset == 0x330 { return self.lvt_thermal; }
        if offset == 0x340 { return self.lvt_perfmon; }
        if offset == 0x350 { return self.lvt_lint0; }
        if offset == 0x360 { return self.lvt_lint1; }
        if offset == 0x370 { return self.lvt_error; }
        if offset == 0x380 { return self.timer_initial; }
        if offset == 0x390 { return self.timer_current; }
        if offset == 0x3E0 { return self.timer_divide; }
        return 0;
    }

    fn mmio_write(self, req) {
        let offset = req.addr & 0xFFF;
        let val = req.value;

        if offset == 0x080 { self.tpr = val & 0xFF; self.update_ppr(); return; }
        if offset == 0x0B0 {
            # EOI
            self.handle_eoi();
            return;
        }
        if offset == 0x0D0 { self.ldr = val; return; }
        if offset == 0x0E0 { self.dfr = val | 0x0FFFFFFF; return; }
        if offset == 0x0F0 { self.svr = val; return; }
        if offset == 0x280 { self.esr = 0; return; }  # Write clears ESR
        if offset == 0x300 {
            self.icr_lo = val;
            self.send_ipi();
            return;
        }
        if offset == 0x310 { self.icr_hi = val; return; }
        if offset == 0x320 { self.lvt_timer = val; return; }
        if offset == 0x330 { self.lvt_thermal = val; return; }
        if offset == 0x340 { self.lvt_perfmon = val; return; }
        if offset == 0x350 { self.lvt_lint0 = val; return; }
        if offset == 0x360 { self.lvt_lint1 = val; return; }
        if offset == 0x370 { self.lvt_error = val; return; }
        if offset == 0x380 {
            self.timer_initial = val;
            self.timer_current = val;
            return;
        }
        if offset == 0x3E0 {
            self.timer_divide = val & 0x0B;
            # Decode divide value
            let bits = ((val & 0x08) >> 1) | (val & 0x03);
            let dividers = [2, 4, 8, 16, 32, 64, 128, 1];
            self.timer_divide_val = dividers[bits & 7];
            return;
        }
    }

    fn handle_eoi(self) {
        # Find highest-priority ISR bit and clear it
        for i in 7..(-1) {
            if self.isr[i] != 0 {
                for bit in 31..(-1) {
                    if (self.isr[i] & (1 << bit)) != 0 {
                        self.isr[i] = self.isr[i] & ~(1 << bit);
                        self.update_ppr();
                        return;
                    }
                }
            }
        }
    }

    fn deliver_interrupt(self, vector, delivery) {
        if (self.svr & 0x100) == 0 { return; }  # APIC disabled
        if delivery == 0 or delivery == 1 {
            # Fixed / Lowest Priority
            let word = vector / 32;
            let bit = vector % 32;
            self.irr_reg[word] = self.irr_reg[word] | (1 << bit);
        } else if delivery == 2 {
            # SMI
        } else if delivery == 4 {
            # NMI
        } else if delivery == 5 {
            # INIT
        } else if delivery == 6 {
            # Start-up (SIPI)
            push(self.pending_vectors, vector);
        }
    }

    fn get_pending_interrupt(self) {
        for i in 7..(-1) {
            if self.irr_reg[i] != 0 {
                for bit in 31..(-1) {
                    if (self.irr_reg[i] & (1 << bit)) != 0 {
                        let vector = i * 32 + bit;
                        if vector > (self.ppr & 0xF0) {
                            # Accept interrupt
                            self.irr_reg[i] = self.irr_reg[i] & ~(1 << bit);
                            self.isr[i] = self.isr[i] | (1 << bit);
                            self.update_ppr();
                            return vector;
                        }
                    }
                }
            }
        }
        return -1;
    }

    fn update_ppr(self) {
        let isrv = 0;
        for i in 7..(-1) {
            if self.isr[i] != 0 {
                for bit in 31..(-1) {
                    if (self.isr[i] & (1 << bit)) != 0 {
                        isrv = i * 32 + bit;
                        break;
                    }
                }
                break;
            }
        }
        if (self.tpr & 0xF0) >= (isrv & 0xF0) {
            self.ppr = self.tpr;
        } else {
            self.ppr = isrv & 0xF0;
        }
    }

    fn send_ipi(self) {
        if self.ipi_callback != null {
            let dest = (self.icr_hi >> 24) & 0xFF;
            let vector = self.icr_lo & 0xFF;
            let delivery = (self.icr_lo >> 8) & 0x7;
            let shorthand = (self.icr_lo >> 18) & 0x3;
            self.ipi_callback(dest, vector, delivery, shorthand);
        }
    }

    fn tick_timer(self) {
        if self.timer_current > 0 {
            self.timer_current = self.timer_current - self.timer_divide_val;
            if self.timer_current <= 0 {
                self.timer_current = 0;
                # Deliver timer interrupt if not masked
                if (self.lvt_timer & (1 << 16)) == 0 {
                    let vector = self.lvt_timer & 0xFF;
                    self.deliver_interrupt(vector, 0);
                }
                # One-shot vs periodic
                let mode = (self.lvt_timer >> 17) & 0x3;
                if mode == 1 {
                    # Periodic — reload
                    self.timer_current = self.timer_initial;
                }
            }
        }
    }

    fn snapshot(self) {
        return {
            "id": self.id, "svr": self.svr, "tpr": self.tpr,
            "isr": self.isr, "irr": self.irr_reg
        };
    }
}

# ===========================================
# HPET (High Precision Event Timer)
# ===========================================

const HPET_CLK_PERIOD = 10000000;   # 100ns per tick (10MHz)

class HPETDevice: Device {
    fn init(self) {
        super.init("hpet");
        self.reset();
    }

    fn reset(self) {
        # General Capabilities and ID
        self.cap = (HPET_CLK_PERIOD << 32) | 0x8086A201;
        self.config = 0;            # General Configuration
        self.isr_reg = 0;           # General Interrupt Status
        self.counter = 0;           # Main Counter
        self.comparators = [];
        for i in 0..3 {
            push(self.comparators, {
                "config": 0,
                "comparator": 0,
                "fsb_route": 0
            });
        }
    }

    fn mmio_read(self, req) {
        let offset = req.addr & 0x3FF;
        if offset == 0x000 { return self.cap & 0xFFFFFFFF; }
        if offset == 0x004 { return (self.cap >> 32) & 0xFFFFFFFF; }
        if offset == 0x010 { return self.config; }
        if offset == 0x020 { return self.isr_reg; }
        if offset == 0x0F0 { return self.counter & 0xFFFFFFFF; }
        if offset == 0x0F4 { return (self.counter >> 32) & 0xFFFFFFFF; }
        # Timer N (offset 0x100 + N*0x20)
        if offset >= 0x100 and offset < 0x160 {
            let timer = (offset - 0x100) / 0x20;
            let reg = (offset - 0x100) % 0x20;
            if timer < 3 {
                if reg == 0x00 { return self.comparators[timer]["config"]; }
                if reg == 0x08 { return self.comparators[timer]["comparator"] & 0xFFFFFFFF; }
                if reg == 0x0C { return (self.comparators[timer]["comparator"] >> 32) & 0xFFFFFFFF; }
            }
        }
        return 0;
    }

    fn mmio_write(self, req) {
        let offset = req.addr & 0x3FF;
        let val = req.value;
        if offset == 0x010 {
            self.config = val;
            if (val & 0x01) == 0 {
                # Counter halted
            }
            return;
        }
        if offset == 0x020 {
            self.isr_reg = self.isr_reg & ~val;  # Write-1-to-clear
            return;
        }
        if offset == 0x0F0 {
            if (self.config & 0x01) == 0 {
                self.counter = (self.counter & 0xFFFFFFFF00000000) | (val & 0xFFFFFFFF);
            }
            return;
        }
        if offset == 0x0F4 {
            if (self.config & 0x01) == 0 {
                self.counter = (self.counter & 0xFFFFFFFF) | ((val & 0xFFFFFFFF) << 32);
            }
            return;
        }
        if offset >= 0x100 and offset < 0x160 {
            let timer = (offset - 0x100) / 0x20;
            let reg = (offset - 0x100) % 0x20;
            if timer < 3 {
                if reg == 0x00 { self.comparators[timer]["config"] = val; return; }
                if reg == 0x08 {
                    self.comparators[timer]["comparator"] = (self.comparators[timer]["comparator"] & 0xFFFFFFFF00000000) | val;
                    return;
                }
                if reg == 0x0C {
                    self.comparators[timer]["comparator"] = (self.comparators[timer]["comparator"] & 0xFFFFFFFF) | (val << 32);
                    return;
                }
            }
        }
    }

    fn tick(self) {
        if (self.config & 0x01) == 0 { return; }  # Not enabled
        self.counter = self.counter + 1;
        for i in 0..3 {
            let cfg = self.comparators[i]["config"];
            if (cfg & (1 << 2)) != 0 {
                # Timer interrupt enabled
                if self.counter >= self.comparators[i]["comparator"] {
                    self.isr_reg = self.isr_reg | (1 << i);
                    if (cfg & (1 << 3)) != 0 {
                        # Periodic — add period to comparator
                        self.comparators[i]["comparator"] = self.comparators[i]["comparator"] + self.comparators[i]["comparator"];
                    }
                    self.raise_irq();
                }
            }
        }
    }

    fn snapshot(self) {
        return {"config": self.config, "counter": self.counter};
    }
}

# ===========================================
# Port 0x80 — POST Code / Diagnostic
# ===========================================

class PostCodeDevice: Device {
    fn init(self) {
        super.init("post_code");
        self.last_code = 0;
    }

    fn io_write(self, req) {
        self.last_code = req.value & 0xFF;
    }

    fn io_read(self, req) {
        return self.last_code;
    }
}

# ===========================================
# Port 0x92 — System Control Port A
# ===========================================

class SystemControlA: Device {
    fn init(self) {
        super.init("sys_ctrl_a");
        self.value = 0;
        self.a20_enabled = true;
    }

    fn io_read(self, req) {
        let val = 0;
        if self.a20_enabled { val = val | 0x02; }
        return val;
    }

    fn io_write(self, req) {
        let val = req.value & 0xFF;
        self.a20_enabled = ((val & 0x02) != 0);
        if (val & 0x01) != 0 {
            # Fast reset
        }
    }
}

# ===========================================
# ELCR (Edge/Level Control Register) 0x4D0-0x4D1
# ===========================================

class ELCRDevice: Device {
    fn init(self, pic) {
        super.init("elcr");
        self.pic = pic;
    }

    fn io_read(self, req) {
        if req.port == 0x4D0 { return self.pic.master.elcr; }
        if req.port == 0x4D1 { return self.pic.slave.elcr; }
        return 0xFF;
    }

    fn io_write(self, req) {
        let val = req.value & 0xFF;
        if req.port == 0x4D0 { self.pic.master.elcr = val; }
        if req.port == 0x4D1 { self.pic.slave.elcr = val; }
    }
}
