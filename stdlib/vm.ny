# ===========================================
# Nyx Virtual Machine Core — Production
# ===========================================
# Full system VM: UEFI + BIOS boot, multi-vCPU,
# ACPI tables, E820, PCI enumeration, hypercall dispatch,
# device initialization, snapshot/migration, event loop.

import systems
import hardware
import paging
import hypervisor
import vm_devices
import vm_acpi
import vm_bios

# ===========================================
# VM Configuration
# ===========================================

const BOOT_UEFI = 1;
const BOOT_BIOS = 2;

# Hypercall numbers (guest VMCALL AX values)
const HYPERCALL_INT10     = 0x0010;
const HYPERCALL_INT13     = 0x0013;
const HYPERCALL_INT15     = 0x0015;
const HYPERCALL_INT16     = 0x0016;
const HYPERCALL_INT19     = 0x0019;
const HYPERCALL_INT1A     = 0x001A;
const HYPERCALL_SHUTDOWN  = 0xFF00;
const HYPERCALL_SNAPSHOT  = 0xFF01;

class VMConfig {
    fn init(self) {
        self.memory_size = 2 * 1024 * 1024 * 1024;  # 2 GB default
        self.cpu_count = 2;
        self.boot_mode = BOOT_UEFI;
        self.firmware_path = null;
        self.disks = [];
        self.nics = [];
        self.nic_models = [];
        self.enable_gpu = true;
        self.enable_legacy = true;
        self.enable_ahci = false;
        self.serial_output = null;
        self.debug_port = false;
        self.numa_nodes = 1;
    }
}

# ===========================================
# Guest Physical Memory Manager
# ===========================================

const MEM_FLAG_READ    = 0x01;
const MEM_FLAG_WRITE   = 0x02;
const MEM_FLAG_EXEC    = 0x04;
const MEM_FLAG_MMIO    = 0x08;
const MEM_FLAG_ROM     = 0x10;

class GuestMemory {
    fn init(self, size) {
        self.size = size;
        self.base = systems.alloc(size);
        systems.memset(self.base, 0, size);
        self.regions = [];
        self.dirty_bitmap = null;
        self.dirty_tracking = false;
        # Set up default identity-mapped RAM region
        self.map_region(0, self.base, size,
                       MEM_FLAG_READ | MEM_FLAG_WRITE | MEM_FLAG_EXEC);
    }

    fn map_region(self, guest_phys, host_ptr, size, flags) {
        push(self.regions, {
            "guest": guest_phys,
            "host": host_ptr,
            "size": size,
            "flags": flags
        });
    }

    fn read(self, guest_phys, size) {
        let host_ptr = self.translate(guest_phys);
        if host_ptr == 0 { return 0; }
        if size == 1 { return systems.peek_u8(host_ptr); }
        if size == 2 { return systems.peek_u16(host_ptr); }
        if size == 4 { return systems.peek_u32(host_ptr); }
        return systems.peek_u64(host_ptr);
    }

    fn write(self, guest_phys, size, value) {
        let host_ptr = self.translate(guest_phys);
        if host_ptr == 0 { return; }
        if self.dirty_tracking {
            self.mark_dirty(guest_phys);
        }
        if size == 1 { systems.poke_u8(host_ptr, value); return; }
        if size == 2 { systems.poke_u16(host_ptr, value); return; }
        if size == 4 { systems.poke_u32(host_ptr, value); return; }
        systems.poke_u64(host_ptr, value);
    }

    fn read_bytes(self, guest_phys, count) {
        let result = [];
        for i in 0..count {
            push(result, self.read(guest_phys + i, 1));
        }
        return result;
    }

    fn write_bytes(self, guest_phys, data) {
        for i in 0..len(data) {
            self.write(guest_phys + i, 1, data[i]);
        }
    }

    fn copy_from_host(self, guest_phys, host_ptr, count) {
        let dest = self.translate(guest_phys);
        if dest != 0 {
            systems.memcpy(dest, host_ptr, count);
        }
    }

    fn translate(self, guest_phys) {
        # Fast path: identity-mapped contiguous RAM
        if guest_phys < self.size {
            return self.base + guest_phys;
        }
        # Slow path: check mapped regions
        for r in self.regions {
            if guest_phys >= r["guest"] and guest_phys < r["guest"] + r["size"] {
                return r["host"] + (guest_phys - r["guest"]);
            }
        }
        return 0;
    }

    fn enable_dirty_tracking(self) {
        let bitmap_size = (self.size / 4096) / 8;
        self.dirty_bitmap = systems.alloc(bitmap_size);
        systems.memset(self.dirty_bitmap, 0, bitmap_size);
        self.dirty_tracking = true;
    }

    fn mark_dirty(self, guest_phys) {
        let page = guest_phys / 4096;
        let byte_idx = page / 8;
        let bit_idx = page % 8;
        let cur = systems.peek_u8(self.dirty_bitmap + byte_idx);
        systems.poke_u8(self.dirty_bitmap + byte_idx, cur | (1 << bit_idx));
    }

    fn get_and_clear_dirty(self) {
        let bitmap_size = (self.size / 4096) / 8;
        let result = systems.alloc(bitmap_size);
        systems.memcpy(result, self.dirty_bitmap, bitmap_size);
        systems.memset(self.dirty_bitmap, 0, bitmap_size);
        return result;
    }
}

# ===========================================
# vCPU State
# ===========================================

const VCPU_STATE_STOPPED  = 0;
const VCPU_STATE_RUNNING  = 1;
const VCPU_STATE_HALTED   = 2;
const VCPU_STATE_INIT     = 3;
const VCPU_STATE_SIPI     = 4;

class VCPUState {
    fn init(self, id) {
        self.id = id;
        self.vcpu = null;          # hypervisor VCPU handle
        self.state = VCPU_STATE_STOPPED;
        self.is_bsp = (id == 0);
        self.sipi_vector = 0;
        self.injection_pending = false;
        self.pending_vector = 0;
        self.nmi_pending = false;
        self.lapic = null;
    }
}

# ===========================================
# Virtual Machine
# ===========================================

class VirtualMachine {
    fn init(self, config) {
        self.config = config;
        self.hyp = hypervisor.get_hypervisor();
        self.bus = vm_devices.DeviceBus();
        self.guest_mem = GuestMemory(config.memory_size);
        self.vcpu_states = [];
        self.pci = vm_devices.PCIConfigSpace();
        self.running = false;
        self.exit_code = 0;

        # Device references (for tick/interrupt routing)
        self.pic = null;
        self.pit = null;
        self.rtc = null;
        self.ioapic = null;
        self.hpet = null;
        self.lapics = [];
        self.acpi_pm = null;
        self.gpu = null;
        self.serial_ports = [];
        self.storage_devices = [];
        self.nic_devices = [];
        self.pci_devices = [];

        # Boot info
        self.acpi_tables = null;
        self.bios_info = null;

        # EPT for guest memory
        self.ept = null;
    }

    fn add_disk(self, path) {
        push(self.config.disks, path);
    }

    fn add_nic(self, model) {
        push(self.config.nics, model);
        push(self.config.nic_models, model);
    }

    # ===========================================
    # Device Initialization
    # ===========================================

    fn init_devices(self) {
        let irq_cb = self.bus.irq_router.make_irq_callback();

        # --- Interrupt Controllers ---

        # 8259A PIC (master + slave)
        self.pic = vm_devices.PICController();
        self.bus.irq_router.pic = self.pic;
        self.bus.register_io_device(0x20, 0x21, self.pic.master);
        self.bus.register_io_device(0xA0, 0xA1, self.pic.slave);

        # ELCR (edge/level control)
        let elcr = vm_devices.ELCRDevice(self.pic);
        self.bus.register_io_device(0x4D0, 0x4D1, elcr);

        # I/O APIC
        self.ioapic = vm_devices.IOAPICDevice();
        self.bus.irq_router.ioapic = self.ioapic;
        self.ioapic.lapic_callback = fn(dest, vector, delivery) {
            self.deliver_lapic_interrupt(dest, vector, delivery);
        };
        self.bus.register_mmio_device(0xFEC00000, 0x1000, self.ioapic);

        # Local APICs (one per vCPU)
        for i in 0..self.config.cpu_count {
            let lapic = vm_devices.LAPICDevice(i);
            push(self.lapics, lapic);
            push(self.bus.irq_router.lapics, lapic);
            lapic.ipi_callback = fn(dest, vector, delivery, shorthand) {
                self.handle_ipi(dest, vector, delivery, shorthand);
            };
        }
        # BSP LAPIC mapped at 0xFEE00000
        if len(self.lapics) > 0 {
            self.bus.register_mmio_device(0xFEE00000, 0x1000, self.lapics[0]);
        }

        # --- ISA Chipset (Legacy) ---

        # PIT (8254)
        self.pit = vm_devices.PITDevice();
        self.pit.irq_line = 0;
        self.pit.irq_callback = irq_cb;
        self.bus.register_io_device(0x40, 0x43, self.pit);
        self.bus.register_io_device(0x61, 0x61, self.pit);  # Speaker gate

        # RTC / CMOS
        self.rtc = vm_devices.RTCDevice();
        self.rtc.irq_line = 8;
        self.rtc.irq_callback = irq_cb;
        self.rtc.set_memory_size(self.config.memory_size);
        self.bus.register_io_device(0x70, 0x71, self.rtc);

        # PS/2 Controller (8042)
        let ps2 = vm_devices.PS2Controller();
        ps2.irq_line = 1;
        ps2.irq_callback = irq_cb;
        self.bus.register_io_device(0x60, 0x60, ps2);
        self.bus.register_io_device(0x64, 0x64, ps2);

        # DMA Controllers (8237)
        let dma1 = vm_devices.DMAController(0x00);
        let dma2 = vm_devices.DMAController(0xC0);
        self.bus.register_io_device(0x00, 0x0F, dma1);
        self.bus.register_io_device(0xC0, 0xDF, dma2);
        let dma_pages = vm_devices.DMAPageRegisters(dma1, dma2);
        self.bus.register_io_device(0x80, 0x8F, dma_pages);

        # UART 16550A (COM1 + COM2)
        let com1 = vm_devices.UARTDevice(0x3F8, 4);
        com1.irq_callback = irq_cb;
        self.bus.register_io_device(0x3F8, 0x3FF, com1);
        push(self.serial_ports, com1);

        let com2 = vm_devices.UARTDevice(0x2F8, 3);
        com2.irq_callback = irq_cb;
        self.bus.register_io_device(0x2F8, 0x2FF, com2);
        push(self.serial_ports, com2);

        if self.config.serial_output != null {
            com1.output_callback = self.config.serial_output;
        }

        # POST code / diagnostic port
        let post = vm_devices.PostCodeDevice();
        self.bus.register_io_device(0x80, 0x80, post);

        # System Control Port A (A20 gate, fast reset)
        let sys_ctrl = vm_devices.SystemControlA();
        self.bus.register_io_device(0x92, 0x92, sys_ctrl);

        # --- ACPI Power Management ---

        self.acpi_pm = vm_devices.ACPIPMDevice();
        self.acpi_pm.irq_line = 9;
        self.acpi_pm.irq_callback = irq_cb;
        self.acpi_pm.shutdown_callback = fn() { self.shutdown(); };
        self.bus.register_io_device(0x600, 0x63F, self.acpi_pm);

        # SMI command port
        let smi = vm_devices.SMICommandPort(self.acpi_pm);
        self.bus.register_io_device(0xB2, 0xB3, smi);

        # Reset control register
        let reset_ctrl = vm_devices.ResetControlDevice();
        reset_ctrl.reset_callback = fn(mode) { self.handle_reset(mode); };
        self.bus.register_io_device(0xCF9, 0xCF9, reset_ctrl);

        # --- HPET ---

        self.hpet = vm_devices.HPETDevice();
        self.hpet.irq_line = 2;
        self.hpet.irq_callback = irq_cb;
        self.bus.register_mmio_device(0xFED00000, 0x1000, self.hpet);

        # --- PCI Host Bridge ---

        self.bus.register_io_device(0xCF8, 0xCFF, self.pci);

        # --- PCI Devices ---

        let pci_slot = 1;

        # Storage: VirtioBlk or AHCI for each disk
        for i in 0..len(self.config.disks) {
            let storage = null;
            if self.config.enable_ahci {
                storage = vm_devices.AHCIController();
                storage.attach_disk(0, self.config.disks[i]);
            } else {
                storage = vm_devices.VirtioBlockDevice();
                storage.attach_disk(self.config.disks[i]);
            }
            storage.pci_bus = 0;
            storage.pci_device = pci_slot;
            storage.pci_function = 0;
            storage.interrupt_line = 10 + i;
            storage.interrupt_pin = 1;
            storage.irq_line = 10 + i;
            storage.irq_callback = irq_cb;
            self.pci.register_device(storage);
            push(self.storage_devices, storage);
            push(self.pci_devices, storage);
            pci_slot = pci_slot + 1;
        }

        # Network
        for i in 0..len(self.config.nics) {
            let model = self.config.nics[i];
            let nic = null;
            if model == "virtio" or model == "virtio-net" {
                nic = vm_devices.VirtioNetDevice();
            } else {
                nic = vm_devices.E1000Device();
            }
            nic.pci_bus = 0;
            nic.pci_device = pci_slot;
            nic.pci_function = 0;
            nic.interrupt_line = 11;
            nic.interrupt_pin = 1;
            nic.irq_line = 11;
            nic.irq_callback = irq_cb;
            self.pci.register_device(nic);
            push(self.nic_devices, nic);
            push(self.pci_devices, nic);
            pci_slot = pci_slot + 1;
        }

        # GPU
        if self.config.enable_gpu {
            self.gpu = vm_devices.BochsGPU();
            self.gpu.pci_bus = 0;
            self.gpu.pci_device = pci_slot;
            self.gpu.pci_function = 0;
            self.gpu.interrupt_line = 14;
            self.gpu.interrupt_pin = 1;
            self.gpu.irq_line = 14;
            self.gpu.irq_callback = irq_cb;
            self.pci.register_device(self.gpu);
            push(self.pci_devices, self.gpu);
            pci_slot = pci_slot + 1;

            # Register VGA legacy IO ports with embedded VGA
            self.bus.register_io_device(0x3C0, 0x3DA, self.gpu);
            self.bus.register_io_device(0x01CE, 0x01CF, self.gpu);  # Bochs VBE
        }
    }

    # ===========================================
    # Boot Path Setup
    # ===========================================

    fn setup_boot(self) {
        if self.config.boot_mode == BOOT_UEFI {
            self.setup_uefi_boot();
        } else {
            self.setup_bios_boot();
        }
    }

    fn setup_uefi_boot(self) {
        # 1. Load UEFI firmware (OVMF) into high memory
        if self.config.firmware_path != null {
            let firmware = systems.read_file(self.config.firmware_path);
            let fw_size = len(firmware);
            let fw_base = 0x100000000 - fw_size;  # Top of 4GB
            self.guest_mem.copy_from_host(fw_base, firmware, fw_size);
            # Map firmware region as ROM
            self.guest_mem.map_region(fw_base, self.guest_mem.base + fw_base,
                                     fw_size, MEM_FLAG_READ | MEM_FLAG_EXEC | MEM_FLAG_ROM);
        }

        # 2. Generate ACPI tables
        let acpi_builder = vm_acpi.ACPITableBuilder(self.guest_mem);
        self.acpi_tables = acpi_builder.build(
            self.config.cpu_count,
            self.pci_devices,
            self.config.memory_size
        );

        # 3. Set initial vCPU state for UEFI (protected mode, long mode)
        for state in self.vcpu_states {
            if state.is_bsp {
                state.vcpu.set_register("rip", 0xFFFFFFF0);  # Reset vector
                state.vcpu.set_register("rsp", 0);
                state.vcpu.cr0 = 0x00000010;  # PE=0, protection disabled initially
                state.vcpu.cr3 = 0;
                state.vcpu.cr4 = 0;
                state.state = VCPU_STATE_RUNNING;
            } else {
                state.state = VCPU_STATE_INIT;  # APs wait for SIPI
            }
        }
    }

    fn setup_bios_boot(self) {
        # 1. Load BIOS ROM (or use built-in stubs)
        if self.config.firmware_path != null {
            let firmware = systems.read_file(self.config.firmware_path);
            let fw_size = len(firmware);
            if fw_size > 65536 { fw_size = 65536; }
            self.guest_mem.copy_from_host(0xF0000, firmware, fw_size);
            # Mirror reset vector area at 0xFFFF0000 for 16-byte initial fetch
            self.guest_mem.copy_from_host(0xFFFF0000, firmware, fw_size);
        }

        # 2. Run legacy BIOS setup (IVT, BDA, E820, SMBIOS, MP Table, stubs)
        let bios_setup = vm_bios.LegacyBIOSSetup(self.guest_mem, self.config);
        self.bios_info = bios_setup.setup();

        # 3. Generate ACPI tables (BIOS guests also need ACPI)
        let acpi_builder = vm_acpi.ACPITableBuilder(self.guest_mem);
        self.acpi_tables = acpi_builder.build(
            self.config.cpu_count,
            self.pci_devices,
            self.config.memory_size
        );

        # 4. Set BSP to real mode at reset vector
        for state in self.vcpu_states {
            if state.is_bsp {
                state.vcpu.set_register("rip", 0xFFF0);
                state.vcpu.set_register("rsp", 0);
                # Real mode: CS base = 0xF000, limit = 0xFFFF
                state.vcpu.cr0 = 0x00000010;  # ET bit set
                state.state = VCPU_STATE_RUNNING;
            } else {
                state.state = VCPU_STATE_INIT;
            }
        }
    }

    # ===========================================
    # EPT / Memory Setup
    # ===========================================

    fn setup_ept(self) {
        self.ept = hypervisor.EPT();
        # Map all guest RAM as read/write/execute
        let page_count = self.config.memory_size / 4096;
        for i in 0..page_count {
            let gpa = i * 4096;
            let hpa = self.guest_mem.base + gpa;
            self.ept.map_page(gpa, hpa, 0x07);  # RWX
        }
        # Map LAPIC MMIO as uncacheable
        self.ept.map_page(0xFEE00000, 0xFEE00000, 0x07);
        # Map IOAPIC
        self.ept.map_page(0xFEC00000, 0xFEC00000, 0x07);
        # Map HPET
        self.ept.map_page(0xFED00000, 0xFED00000, 0x07);
    }

    # ===========================================
    # vCPU Creation
    # ===========================================

    fn create_vcpus(self) {
        for i in 0..self.config.cpu_count {
            let state = VCPUState(i);
            state.vcpu = self.hyp.create_vcpu();
            if i < len(self.lapics) {
                state.lapic = self.lapics[i];
            }
            push(self.vcpu_states, state);
        }
    }

    # ===========================================
    # Main Run Loop
    # ===========================================

    fn run(self) {
        self.create_vcpus();
        self.init_devices();
        self.setup_ept();
        self.setup_boot();
        self.running = true;

        # Run BSP
        let bsp = self.vcpu_states[0];
        self.run_vcpu_loop(bsp);

        return self.exit_code;
    }

    fn run_vcpu_loop(self, state) {
        while self.running and state.state == VCPU_STATE_RUNNING {
            # Inject pending interrupts before entry
            self.inject_interrupt(state);

            # Tick timer devices
            self.tick_devices();

            # Run guest
            self.hyp.run_vcpu(state.vcpu);
            let exit_info = self.hyp.get_vmexit_info();

            if !self.handle_vmexit(state, exit_info) {
                state.state = VCPU_STATE_STOPPED;
                break;
            }
        }
    }

    # ===========================================
    # Interrupt Injection
    # ===========================================

    fn inject_interrupt(self, state) {
        if state.lapic != null {
            let vector = state.lapic.get_pending_interrupt();
            if vector >= 0 {
                state.injection_pending = true;
                state.pending_vector = vector;
            }
        }
        # Fall back to PIC
        if !state.injection_pending and state.is_bsp and self.pic != null {
            if self.pic.has_interrupt() {
                let vec = self.pic.get_vector();
                if vec >= 0 {
                    state.injection_pending = true;
                    state.pending_vector = vec;
                }
            }
        }
    }

    fn deliver_lapic_interrupt(self, dest, vector, delivery) {
        for lapic in self.lapics {
            if lapic.id == dest or dest == 0xFF {
                lapic.deliver_interrupt(vector, delivery);
            }
        }
    }

    fn handle_ipi(self, dest, vector, delivery, shorthand) {
        if shorthand == 0 {
            # No shorthand — use destination
            self.deliver_lapic_interrupt(dest, vector, delivery);
        } else if shorthand == 1 {
            # Self
            # Deliver to sending LAPIC (determined by context)
        } else if shorthand == 2 {
            # All including self
            for lapic in self.lapics {
                lapic.deliver_interrupt(vector, delivery);
            }
        } else if shorthand == 3 {
            # All excluding self
            for lapic in self.lapics {
                if lapic.id != dest {
                    lapic.deliver_interrupt(vector, delivery);
                }
            }
        }
        # Handle INIT and SIPI for AP startup
        if delivery == 5 {
            # INIT
            for state in self.vcpu_states {
                if state.id == dest or dest == 0xFF {
                    if !state.is_bsp {
                        state.state = VCPU_STATE_INIT;
                    }
                }
            }
        } else if delivery == 6 {
            # SIPI — Start-up IPI
            for state in self.vcpu_states {
                if state.state == VCPU_STATE_INIT and !state.is_bsp {
                    state.sipi_vector = vector;
                    state.state = VCPU_STATE_SIPI;
                    self.start_ap(state);
                }
            }
        }
    }

    fn start_ap(self, state) {
        # AP starts in real mode at CS:IP = (sipi_vector << 8):0000
        let start_addr = state.sipi_vector * 0x1000;
        state.vcpu.set_register("rip", 0);
        state.vcpu.cr0 = 0x00000010;
        state.state = VCPU_STATE_RUNNING;
        # AP runs in its own execution context
    }

    # ===========================================
    # Device Ticks
    # ===========================================

    fn tick_devices(self) {
        if self.pit != null { self.pit.tick(); }
        if self.hpet != null { self.hpet.tick(); }
        if self.acpi_pm != null { self.acpi_pm.tick(); }
        for lapic in self.lapics {
            lapic.tick_timer();
        }
    }

    # ===========================================
    # VM Exit Handling
    # ===========================================

    fn handle_vmexit(self, state, exit_info) {
        let reason = exit_info.reason;
        let vcpu = state.vcpu;

        # --- HLT ---
        if reason == hypervisor.VMX_EXIT_HLT {
            state.state = VCPU_STATE_HALTED;
            # Check for pending interrupts to wake
            if state.lapic != null and state.lapic.get_pending_interrupt() >= 0 {
                state.state = VCPU_STATE_RUNNING;
                vcpu.set_register("rip", vcpu.get_register("rip") + exit_info.instruction_len);
                return true;
            }
            if self.pic != null and self.pic.has_interrupt() {
                state.state = VCPU_STATE_RUNNING;
                vcpu.set_register("rip", vcpu.get_register("rip") + exit_info.instruction_len);
                return true;
            }
            return false;
        }

        # --- I/O ---
        if reason == hypervisor.VMX_EXIT_IO {
            let req = exit_info.decode_io();
            if req.is_write {
                self.bus.handle_io(req);
            } else {
                let value = self.bus.handle_io(req);
                self.set_io_result(vcpu, value, req.size);
            }
            vcpu.set_register("rip", vcpu.get_register("rip") + exit_info.instruction_len);
            return true;
        }

        # --- EPT Violation (MMIO) ---
        if reason == hypervisor.VMX_EXIT_EPT_VIOLATION {
            let mmio_req = exit_info.decode_mmio();
            if mmio_req.is_write {
                self.bus.handle_mmio(mmio_req);
            } else {
                let value = self.bus.handle_mmio(mmio_req);
                vcpu.set_register("rax", value);
            }
            vcpu.set_register("rip", vcpu.get_register("rip") + exit_info.instruction_len);
            return true;
        }

        # --- CPUID ---
        if reason == hypervisor.VMX_EXIT_CPUID {
            self.emulate_cpuid(vcpu);
            vcpu.set_register("rip", vcpu.get_register("rip") + exit_info.instruction_len);
            return true;
        }

        # --- MSR Read ---
        if reason == hypervisor.VMX_EXIT_MSR_READ {
            self.emulate_rdmsr(vcpu);
            vcpu.set_register("rip", vcpu.get_register("rip") + exit_info.instruction_len);
            return true;
        }

        # --- MSR Write ---
        if reason == hypervisor.VMX_EXIT_MSR_WRITE {
            self.emulate_wrmsr(vcpu);
            vcpu.set_register("rip", vcpu.get_register("rip") + exit_info.instruction_len);
            return true;
        }

        # --- VMCALL (Hypercall) ---
        if reason == hypervisor.VMX_EXIT_VMCALL {
            self.handle_hypercall(state);
            vcpu.set_register("rip", vcpu.get_register("rip") + exit_info.instruction_len);
            return true;
        }

        # --- CR Access ---
        if reason == hypervisor.VMX_EXIT_CR_ACCESS {
            self.emulate_cr_access(vcpu, exit_info.qualification);
            vcpu.set_register("rip", vcpu.get_register("rip") + exit_info.instruction_len);
            return true;
        }

        # --- Triple Fault ---
        if reason == hypervisor.VMX_EXIT_TRIPLE_FAULT {
            self.exit_code = 1;
            return false;
        }

        # --- External Interrupt ---
        if reason == hypervisor.VMX_EXIT_EXTERNAL_INTERRUPT {
            return true;  # Re-enter guest
        }

        # --- INIT Signal ---
        if reason == hypervisor.VMX_EXIT_INIT_SIGNAL {
            state.state = VCPU_STATE_INIT;
            return false;
        }

        # --- SIPI ---
        if reason == hypervisor.VMX_EXIT_SIPI {
            state.sipi_vector = exit_info.qualification & 0xFF;
            self.start_ap(state);
            return true;
        }

        # --- Fall back to hypervisor ---
        return self.hyp.handle_vmexit(vcpu, reason);
    }

    fn set_io_result(self, vcpu, value, size) {
        let rax = vcpu.get_register("rax");
        if size == 1 {
            rax = (rax & 0xFFFFFFFFFFFFFF00) | (value & 0xFF);
        } else if size == 2 {
            rax = (rax & 0xFFFFFFFFFFFF0000) | (value & 0xFFFF);
        } else {
            rax = value & 0xFFFFFFFF;
        }
        vcpu.set_register("rax", rax);
    }

    # ===========================================
    # CPUID Emulation
    # ===========================================

    fn emulate_cpuid(self, vcpu) {
        let leaf = vcpu.get_register("rax") & 0xFFFFFFFF;
        let subleaf = vcpu.get_register("rcx") & 0xFFFFFFFF;

        let result = hardware.cpuid_query(leaf, subleaf);

        # Mask out host VMX/SVM features from guest
        if leaf == 1 {
            result["ecx"] = result["ecx"] & ~(1 << 5);   # Hide VMX
            result["ecx"] = result["ecx"] & ~(1 << 2);   # Hide SVM
        }

        # Hypervisor present bit (leaf 1, ECX bit 31)
        if leaf == 1 {
            result["ecx"] = result["ecx"] | (1 << 31);   # Hypervisor present
        }

        # Hypervisor info leaf
        if leaf == 0x40000000 {
            result["eax"] = 0x40000001;  # Max hypervisor leaf
            result["ebx"] = 0x4E795856;  # "NyxV"
            result["ecx"] = 0x4D000000;  # "M\0\0\0"
            result["edx"] = 0;
        }
        if leaf == 0x40000001 {
            result["eax"] = 0x01000000;  # Version 1.0
            result["ebx"] = 0;
            result["ecx"] = 0;
            result["edx"] = 0;
        }

        vcpu.set_register("rax", result["eax"]);
        vcpu.set_register("rbx", result["ebx"]);
        vcpu.set_register("rcx", result["ecx"]);
        vcpu.set_register("rdx", result["edx"]);
    }

    # ===========================================
    # MSR Emulation
    # ===========================================

    fn emulate_rdmsr(self, vcpu) {
        let msr = vcpu.get_register("rcx") & 0xFFFFFFFF;
        let value = 0;

        if msr == 0x1B {
            # IA32_APIC_BASE
            value = 0xFEE00000 | (1 << 11);  # APIC enabled
            if vcpu.get_register("rip") == 0 {
                value = value | (1 << 8);  # BSP
            }
        } else if msr == 0xC0000080 {
            # IA32_EFER
            value = 0;
        } else if msr == 0xC0000100 {
            # FS.base
            value = 0;
        } else if msr == 0xC0000101 {
            # GS.base
            value = 0;
        } else if msr == 0xC0000102 {
            # KernelGSbase
            value = 0;
        } else if msr == 0x10 {
            # IA32_TIME_STAMP_COUNTER
            value = hardware.rdtsc();
        } else if msr == 0x174 {
            # IA32_SYSENTER_CS
            value = 0;
        }

        vcpu.set_register("rax", value & 0xFFFFFFFF);
        vcpu.set_register("rdx", (value >> 32) & 0xFFFFFFFF);
    }

    fn emulate_wrmsr(self, vcpu) {
        let msr = vcpu.get_register("rcx") & 0xFFFFFFFF;
        let val_lo = vcpu.get_register("rax") & 0xFFFFFFFF;
        let val_hi = vcpu.get_register("rdx") & 0xFFFFFFFF;
        let value = val_lo | (val_hi << 32);

        if msr == 0x1B {
            # IA32_APIC_BASE — update LAPIC base
        } else if msr == 0xC0000080 {
            # IA32_EFER — handle LME bit
        }
        # Most MSR writes are silently ignored in a VM
    }

    # ===========================================
    # CR Access Emulation
    # ===========================================

    fn emulate_cr_access(self, vcpu, qualification) {
        let cr_num = qualification & 0xF;
        let access_type = (qualification >> 4) & 0x3;
        let reg = (qualification >> 8) & 0xF;

        let reg_names = ["rax", "rcx", "rdx", "rbx", "rsp", "rbp", "rsi", "rdi",
                         "r8", "r9", "r10", "r11", "r12", "r13", "r14", "r15"];

        if access_type == 0 {
            # MOV to CR
            let val = vcpu.get_register(reg_names[reg]);
            if cr_num == 0 { vcpu.cr0 = val; }
            if cr_num == 3 { vcpu.cr3 = val; }
            if cr_num == 4 { vcpu.cr4 = val; }
        } else if access_type == 1 {
            # MOV from CR
            let val = 0;
            if cr_num == 0 { val = vcpu.cr0; }
            if cr_num == 3 { val = vcpu.cr3; }
            if cr_num == 4 { val = vcpu.cr4; }
            vcpu.set_register(reg_names[reg], val);
        }
    }

    # ===========================================
    # Hypercall Dispatch (BIOS Service Emulation)
    # ===========================================

    fn handle_hypercall(self, state) {
        let vcpu = state.vcpu;
        let ax = vcpu.get_register("rax") & 0xFFFF;

        if ax == HYPERCALL_INT10 {
            self.hypercall_int10(vcpu);
        } else if ax == HYPERCALL_INT13 {
            self.hypercall_int13(vcpu);
        } else if ax == HYPERCALL_INT15 {
            self.hypercall_int15(vcpu);
        } else if ax == HYPERCALL_INT16 {
            self.hypercall_int16(vcpu);
        } else if ax == HYPERCALL_INT19 {
            self.hypercall_int19(vcpu);
        } else if ax == HYPERCALL_INT1A {
            self.hypercall_int1a(vcpu);
        } else if ax == HYPERCALL_SHUTDOWN {
            self.shutdown();
        }
    }

    fn hypercall_int10(self, vcpu) {
        let ah = (vcpu.get_register("rax") >> 8) & 0xFF;
        if ah == 0x0E {
            # Teletype output
            let ch = vcpu.get_register("rax") & 0xFF;
            if len(self.serial_ports) > 0 {
                self.serial_ports[0].receive_byte(ch);
            }
        } else if ah == 0x00 {
            # Set video mode — handled by VGA device
        } else if ah == 0x0F {
            # Get video mode
            let rax = vcpu.get_register("rax");
            vcpu.set_register("rax", (rax & 0xFFFF0000) | 0x5003);  # Mode 3, 80 cols
        }
    }

    fn hypercall_int13(self, vcpu) {
        let ah = (vcpu.get_register("rax") >> 8) & 0xFF;
        if ah == 0x00 {
            # Reset disk
            vcpu.set_register("rax", vcpu.get_register("rax") & 0xFFFF00FF);  # AH=0 success
        } else if ah == 0x02 {
            # Read sectors
            let count = vcpu.get_register("rax") & 0xFF;
            let cx = vcpu.get_register("rcx") & 0xFFFF;
            let dh = (vcpu.get_register("rdx") >> 8) & 0xFF;
            let cyl = ((cx >> 8) & 0xFF) | ((cx & 0xC0) << 2);
            let head = dh;
            let sector = cx & 0x3F;
            let lba = (cyl * 255 + head) * 63 + (sector - 1);
            let es = 0;   # Segment from ES register
            let bx = vcpu.get_register("rbx") & 0xFFFF;
            let buf_addr = (es << 4) + bx;
            if len(self.storage_devices) > 0 {
                self.storage_devices[0].do_io(self.guest_mem, lba, count, buf_addr, false);
            }
            vcpu.set_register("rax", (vcpu.get_register("rax") & 0xFFFF0000) | count);
        } else if ah == 0x08 {
            # Get drive parameters
            vcpu.set_register("rcx", 0xFEFF);  # Max CHS
            vcpu.set_register("rdx", 0xFE01);  # Max heads, 1 drive
        } else if ah == 0x41 {
            # Check INT 13h extensions
            vcpu.set_register("rbx", 0xAA55);
            vcpu.set_register("rcx", 0x0007);
            vcpu.set_register("rax", (vcpu.get_register("rax") & 0xFFFF0000) | 0x2100);
        } else if ah == 0x42 {
            # Extended Read
            # DAP at DS:SI
        }
    }

    fn hypercall_int15(self, vcpu) {
        let ax = vcpu.get_register("rax") & 0xFFFF;
        let ah = (ax >> 8) & 0xFF;
        if ax == 0xE820 {
            # Memory map query
            self.handle_e820(vcpu);
        } else if ah == 0x88 {
            # Extended memory size (in KB above 1MB)
            let ext_kb = 0;
            if self.config.memory_size > 0x100000 {
                ext_kb = (self.config.memory_size - 0x100000) / 1024;
            }
            if ext_kb > 0xFFFF { ext_kb = 0xFFFF; }
            vcpu.set_register("rax", (vcpu.get_register("rax") & 0xFFFF0000) | ext_kb);
        } else if ah == 0xC0 {
            # Get system configuration — return pointer to config table
        } else if ax == 0x2401 {
            # Enable A20 gate
        }
    }

    fn handle_e820(self, vcpu) {
        let ebx = vcpu.get_register("rbx") & 0xFFFFFFFF;  # Continuation value (entry index)
        let ecx = vcpu.get_register("rcx") & 0xFFFFFFFF;  # Buffer size

        # Build E820 table
        let e820 = vm_bios.E820MemoryMap();
        e820.build_standard(self.config.memory_size);

        if ebx >= len(e820.entries) {
            # No more entries
            vcpu.set_register("rbx", 0);
            return;
        }

        let entry = e820.entries[ebx];
        let di = vcpu.get_register("rdi") & 0xFFFF;
        let es = 0;  # ES segment
        let buf = (es << 4) + di;

        # Write E820 entry to guest buffer
        self.guest_mem.write(buf, 4, entry["base"] & 0xFFFFFFFF);
        self.guest_mem.write(buf + 4, 4, (entry["base"] >> 32) & 0xFFFFFFFF);
        self.guest_mem.write(buf + 8, 4, entry["length"] & 0xFFFFFFFF);
        self.guest_mem.write(buf + 12, 4, (entry["length"] >> 32) & 0xFFFFFFFF);
        self.guest_mem.write(buf + 16, 4, entry["type"]);

        ebx = ebx + 1;
        if ebx >= len(e820.entries) { ebx = 0; }
        vcpu.set_register("rbx", ebx);
        vcpu.set_register("rcx", 20);
        vcpu.set_register("rax", 0x534D4150);  # "SMAP" signature
    }

    fn hypercall_int16(self, vcpu) {
        let ah = (vcpu.get_register("rax") >> 8) & 0xFF;
        if ah == 0x00 {
            # Wait for keypress — return 0 (no key)
            vcpu.set_register("rax", 0);
        } else if ah == 0x01 {
            # Check for keypress — ZF set means no key
        }
    }

    fn hypercall_int19(self, vcpu) {
        # Bootstrap loader — load boot sector from first disk
        if len(self.storage_devices) > 0 {
            self.storage_devices[0].do_io(self.guest_mem, 0, 1, 0x7C00, false);
            # Jump to boot sector
            vcpu.set_register("rip", 0x7C00);
        }
    }

    fn hypercall_int1a(self, vcpu) {
        let ah = (vcpu.get_register("rax") >> 8) & 0xFF;
        if ah == 0x00 {
            # Get system time (ticks since midnight)
            vcpu.set_register("rcx", 0);
            vcpu.set_register("rdx", 0);
            vcpu.set_register("rax", vcpu.get_register("rax") & 0xFFFF0000);
        } else if ah == 0xB1 {
            # PCI BIOS
            let al = vcpu.get_register("rax") & 0xFF;
            if al == 0x01 {
                # PCI BIOS Present
                vcpu.set_register("rax", (vcpu.get_register("rax") & 0xFFFF0000) | 0x0001);
                vcpu.set_register("rbx", 0x0210);  # PCI rev 2.1
                vcpu.set_register("rcx", 0);       # Last bus
                vcpu.set_register("rdx", 0x20494350);  # " ICP" 
            }
        }
    }

    # ===========================================
    # System Operations
    # ===========================================

    fn shutdown(self) {
        self.running = false;
        self.exit_code = 0;
    }

    fn handle_reset(self, mode) {
        if mode == "hard" {
            self.bus.reset_all();
            self.setup_boot();
        }
        # Soft reset: just restart the BSP
    }

    fn pause(self) {
        self.running = false;
    }

    fn resume(self) {
        self.running = true;
        let bsp = self.vcpu_states[0];
        if bsp.state == VCPU_STATE_HALTED {
            bsp.state = VCPU_STATE_RUNNING;
        }
        self.run_vcpu_loop(bsp);
    }

    # ===========================================
    # Snapshot / Migration
    # ===========================================

    fn snapshot(self) {
        let state = {
            "config": {
                "memory_size": self.config.memory_size,
                "cpu_count": self.config.cpu_count,
                "boot_mode": self.config.boot_mode
            },
            "vcpus": [],
            "devices": {}
        };
        for vs in self.vcpu_states {
            push(state["vcpus"], {
                "id": vs.id,
                "state": vs.state,
                "regs": vs.vcpu.regs,
                "cr0": vs.vcpu.cr0,
                "cr3": vs.vcpu.cr3,
                "cr4": vs.vcpu.cr4
            });
        }
        if self.pic != null { state["devices"]["pic"] = self.pic.master.snapshot(); }
        if self.pit != null { state["devices"]["pit"] = self.pit.snapshot(); }
        if self.rtc != null { state["devices"]["rtc"] = self.rtc.snapshot(); }
        if self.ioapic != null { state["devices"]["ioapic"] = self.ioapic.snapshot(); }
        if self.hpet != null { state["devices"]["hpet"] = self.hpet.snapshot(); }
        return state;
    }

    fn restore(self, state) {
        for i in 0..len(state["vcpus"]) {
            let saved = state["vcpus"][i];
            if i < len(self.vcpu_states) {
                self.vcpu_states[i].state = saved["state"];
                self.vcpu_states[i].vcpu.regs = saved["regs"];
                self.vcpu_states[i].vcpu.cr0 = saved["cr0"];
                self.vcpu_states[i].vcpu.cr3 = saved["cr3"];
                self.vcpu_states[i].vcpu.cr4 = saved["cr4"];
            }
        }
    }

    # ===========================================
    # Query / Debug
    # ===========================================

    fn get_display_info(self) {
        if self.gpu != null {
            return self.gpu.get_display_info();
        }
        return null;
    }

    fn read_serial_output(self) {
        if len(self.serial_ports) > 0 {
            return self.serial_ports[0].tx_fifo;
        }
        return [];
    }
}

# ===========================================
# High-Level VM Builder (Fluent API)
# ===========================================

class VMBuilder {
    fn init(self) {
        self.config = VMConfig();
    }

    fn memory(self, size) {
        self.config.memory_size = size;
        return self;
    }

    fn cpus(self, count) {
        self.config.cpu_count = count;
        return self;
    }

    fn uefi(self, firmware_path) {
        self.config.boot_mode = BOOT_UEFI;
        self.config.firmware_path = firmware_path;
        return self;
    }

    fn bios(self, firmware_path) {
        self.config.boot_mode = BOOT_BIOS;
        self.config.firmware_path = firmware_path;
        return self;
    }

    fn disk(self, path) {
        push(self.config.disks, path);
        return self;
    }

    fn ahci(self, enabled) {
        self.config.enable_ahci = enabled;
        return self;
    }

    fn nic(self, model) {
        push(self.config.nics, model);
        push(self.config.nic_models, model);
        return self;
    }

    fn gpu(self, enabled) {
        self.config.enable_gpu = enabled;
        return self;
    }

    fn serial(self, callback) {
        self.config.serial_output = callback;
        return self;
    }

    fn legacy(self, enabled) {
        self.config.enable_legacy = enabled;
        return self;
    }

    fn build(self) {
        return VirtualMachine(self.config);
    }
}

# ===========================================
# Example Usage
# ===========================================

fn example_windows_uefi() {
    let vm = VMBuilder()
        .memory(4 * 1024 * 1024 * 1024)
        .cpus(4)
        .uefi("OVMF.fd")
        .disk("windows.qcow2")
        .nic("e1000")
        .gpu(true)
        .build();

    vm.run();
}

fn example_linux_bios() {
    let vm = VMBuilder()
        .memory(2 * 1024 * 1024 * 1024)
        .cpus(2)
        .bios("seabios.bin")
        .disk("linux.img")
        .nic("virtio")
        .gpu(true)
        .serial(fn(ch) { systems.putchar(ch); })
        .build();

    vm.run();
}

fn example_ahci_setup() {
    let vm = VMBuilder()
        .memory(8 * 1024 * 1024 * 1024)
        .cpus(8)
        .uefi("OVMF.fd")
        .ahci(true)
        .disk("disk0.qcow2")
        .disk("disk1.qcow2")
        .nic("e1000")
        .nic("virtio")
        .gpu(true)
        .build();

    vm.run();
}
