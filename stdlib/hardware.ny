# ===========================================
# Nyx Hardware Access Library
# ===========================================
# Direct CPU and hardware register access
# Beyond what Rust/C++/Zig provide in stdlib
# WARNING: Requires kernel mode / supervisor privileges

import systems

# ===========================================
# CPU Identification (CPUID)
# ===========================================

class CPUID {
    fn query(self, leaf, subleaf = 0) {
        # Execute CPUID instruction
        return _cpuid(leaf, subleaf);
    }
    
    fn vendor_string(self) {
        let result = self.query(0, 0);
        # EBX, EDX, ECX contain 12-char vendor string
        return _decode_vendor(result);
    }
    
    fn brand_string(self) {
        let part1 = self.query(0x80000002, 0);
        let part2 = self.query(0x80000003, 0);
        let part3 = self.query(0x80000004, 0);
        return _decode_brand([part1, part2, part3]);
    }
    
    fn has_feature(self, feature) {
        # Check CPU feature flags
        if feature == "SSE" {
            let result = self.query(1, 0);
            return (result["edx"] & (1 << 25)) != 0;
        }
        if feature == "SSE2" {
            let result = self.query(1, 0);
            return (result["edx"] & (1 << 26)) != 0;
        }
        if feature == "AVX" {
            let result = self.query(1, 0);
            return (result["ecx"] & (1 << 28)) != 0;
        }
        if feature == "AVX2" {
            let result = self.query(7, 0);
            return (result["ebx"] & (1 << 5)) != 0;
        }
        if feature == "AVX512F" {
            let result = self.query(7, 0);
            return (result["ebx"] & (1 << 16)) != 0;
        }
        if feature == "AES" {
            let result = self.query(1, 0);
            return (result["ecx"] & (1 << 25)) != 0;
        }
        if feature == "RDRAND" {
            let result = self.query(1, 0);
            return (result["ecx"] & (1 << 30)) != 0;
        }
        if feature == "RDSEED" {
            let result = self.query(7, 0);
            return (result["ebx"] & (1 << 18)) != 0;
        }
        if feature == "TSX" {
            let result = self.query(7, 0);
            return (result["ebx"] & (1 << 11)) != 0;
        }
        if feature == "VMX" {
            let result = self.query(1, 0);
            return (result["ecx"] & (1 << 5)) != 0;
        }
        if feature == "SVM" {
            let result = self.query(0x80000001, 0);
            return (result["ecx"] & (1 << 2)) != 0;
        }
        return false;
    }
    
    fn cache_info(self) {
        # Get L1/L2/L3 cache sizes
        let leaf4 = self.query(4, 0);
        return {
            "l1_data": _extract_cache_size(leaf4, 1),
            "l1_instruction": _extract_cache_size(leaf4, 2),
            "l2": _extract_cache_size(leaf4, 3),
            "l3": _extract_cache_size(leaf4, 4)
        };
    }
    
    fn core_count(self) {
        let result = self.query(1, 0);
        return (result["ebx"] >> 16) & 0xFF;
    }
    
    fn family_model_stepping(self) {
        let result = self.query(1, 0);
        let eax = result["eax"];
        
        let stepping = eax & 0xF;
        let model = (eax >> 4) & 0xF;
        let family = (eax >> 8) & 0xF;
        let ext_model = (eax >> 16) & 0xF;
        let ext_family = (eax >> 20) & 0xFF;
        
        let display_family = family + ext_family;
        let display_model = model + (ext_model << 4);
        
        return {
            "family": display_family,
            "model": display_model,
            "stepping": stepping
        };
    }
}

# ===========================================
# Model-Specific Registers (MSRs)
# ===========================================

class MSR {
    fn read(self, msr_id) {
        # RDMSR instruction (requires ring 0)
        return _rdmsr(msr_id);
    }
    
    fn write(self, msr_id, value) {
        # WRMSR instruction (requires ring 0)
        _wrmsr(msr_id, value);
    }
    
    fn read_tsc(self) {
        # Read Time Stamp Counter
        return _rdtsc();
    }
    
    fn read_tscp(self) {
        # Read TSC and processor ID
        return _rdtscp();
    }
    
    fn read_pmc(self, counter) {
        # Read Performance Monitoring Counter
        return _rdpmc(counter);
    }
}

# Common MSR addresses
const MSR_IA32_APIC_BASE = 0x0000001B;
const MSR_IA32_FEATURE_CONTROL = 0x0000003A;
const MSR_IA32_TSC = 0x00000010;
const MSR_IA32_MTRRCAP = 0x000000FE;
const MSR_IA32_SYSENTER_CS = 0x00000174;
const MSR_IA32_SYSENTER_ESP = 0x00000175;
const MSR_IA32_SYSENTER_EIP = 0x00000176;
const MSR_IA32_EFER = 0xC0000080;
const MSR_IA32_STAR = 0xC0000081;
const MSR_IA32_LSTAR = 0xC0000082;
const MSR_IA32_CSTAR = 0xC0000083;
const MSR_IA32_FMASK = 0xC0000084;
const MSR_IA32_FS_BASE = 0xC0000100;
const MSR_IA32_GS_BASE = 0xC0000101;
const MSR_IA32_KERNEL_GS_BASE = 0xC0000102;

# ===========================================
# CPU Registers (Direct Access)
# ===========================================

class CPURegisters {
    fn read_cr0(self) {
        return _read_cr0();
    }
    
    fn write_cr0(self, value) {
        _write_cr0(value);
    }
    
    fn read_cr2(self) {
        # Page fault linear address
        return _read_cr2();
    }
    
    fn read_cr3(self) {
        # Page directory base
        return _read_cr3();
    }
    
    fn write_cr3(self, value) {
        # Change page directory
        _write_cr3(value);
    }
    
    fn read_cr4(self) {
        return _read_cr4();
    }
    
    fn write_cr4(self, value) {
        _write_cr4(value);
    }
    
    fn read_cr8(self) {
        # Task priority (64-bit mode only)
        return _read_cr8();
    }
    
    fn write_cr8(self, value) {
        _write_cr8(value);
    }
    
    fn read_dr0(self) {
        # Debug register 0 (breakpoint)
        return _read_dr0();
    }
    
    fn write_dr0(self, value) {
        _write_dr0(value);
    }
    
    fn read_dr1(self) { return _read_dr1(); }
    fn write_dr1(self, value) { _write_dr1(value); }
    fn read_dr2(self) { return _read_dr2(); }
    fn write_dr2(self, value) { _write_dr2(value); }
    fn read_dr3(self) { return _read_dr3(); }
    fn write_dr3(self, value) { _write_dr3(value); }
    
    fn read_dr6(self) {
        # Debug status
        return _read_dr6();
    }
    
    fn write_dr6(self, value) {
        _write_dr6(value);
    }
    
    fn read_dr7(self) {
        # Debug control
        return _read_dr7();
    }
    
    fn write_dr7(self, value) {
        _write_dr7(value);
    }
    
    fn read_rflags(self) {
        return _read_rflags();
    }
    
    fn write_rflags(self, value) {
        _write_rflags(value);
    }
    
    fn read_fs_base(self) {
        return _read_fs_base();
    }
    
    fn write_fs_base(self, value) {
        _write_fs_base(value);
    }
    
    fn read_gs_base(self) {
        return _read_gs_base();
    }
    
    fn write_gs_base(self, value) {
        _write_gs_base(value);
    }
}

# ===========================================
# Port I/O (x86/x64)
# ===========================================

class PortIO {
    fn inb(self, port) {
        # Read byte from port
        return _inb(port);
    }
    
    fn inw(self, port) {
        # Read word from port
        return _inw(port);
    }
    
    fn inl(self, port) {
        # Read dword from port
        return _inl(port);
    }
    
    fn outb(self, port, value) {
        # Write byte to port
        _outb(port, value);
    }
    
    fn outw(self, port, value) {
        # Write word to port
        _outw(port, value);
    }
    
    fn outl(self, port, value) {
        # Write dword to port
        _outl(port, value);
    }
    
    fn io_wait(self) {
        # Wait for I/O operation to complete
        self.outb(0x80, 0);
    }
}

# ===========================================
# Memory-Mapped I/O (MMIO)
# ===========================================

class MMIO {
    fn init(self, base_address, size) {
        self.base = base_address;
        self.size = size;
    }
    
    fn read8(self, offset) {
        if offset >= self.size {
            panic("MMIO: offset out of bounds");
        }
        return _mmio_read8(self.base + offset);
    }
    
    fn read16(self, offset) {
        if offset + 1 >= self.size {
            panic("MMIO: offset out of bounds");
        }
        return _mmio_read16(self.base + offset);
    }
    
    fn read32(self, offset) {
        if offset + 3 >= self.size {
            panic("MMIO: offset out of bounds");
        }
        return _mmio_read32(self.base + offset);
    }
    
    fn read64(self, offset) {
        if offset + 7 >= self.size {
            panic("MMIO: offset out of bounds");
        }
        return _mmio_read64(self.base + offset);
    }
    
    fn write8(self, offset, value) {
        if offset >= self.size {
            panic("MMIO: offset out of bounds");
        }
        _mmio_write8(self.base + offset, value);
    }
    
    fn write16(self, offset, value) {
        if offset + 1 >= self.size {
            panic("MMIO: offset out of bounds");
        }
        _mmio_write16(self.base + offset, value);
    }
    
    fn write32(self, offset, value) {
        if offset + 3 >= self.size {
            panic("MMIO: offset out of bounds");
        }
        _mmio_write32(self.base + offset, value);
    }
    
    fn write64(self, offset, value) {
        if offset + 7 >= self.size {
            panic("MMIO: offset out of bounds");
        }
        _mmio_write64(self.base + offset, value);
    }
    
    fn set_bits32(self, offset, mask) {
        let val = self.read32(offset);
        self.write32(offset, val | mask);
    }
    
    fn clear_bits32(self, offset, mask) {
        let val = self.read32(offset);
        self.write32(offset, val & ~mask);
    }
}

# ===========================================
# PCI Configuration Space Access
# ===========================================

class PCI {
    fn read_config_byte(self, bus, device, func, offset) {
        let address = self.make_address(bus, device, func, offset);
        _pci_write_address(address);
        return _pci_read_data_byte(offset);
    }
    
    fn read_config_word(self, bus, device, func, offset) {
        let address = self.make_address(bus, device, func, offset);
        _pci_write_address(address);
        return _pci_read_data_word(offset);
    }
    
    fn read_config_dword(self, bus, device, func, offset) {
        let address = self.make_address(bus, device, func, offset);
        _pci_write_address(address);
        return _pci_read_data_dword();
    }
    
    fn write_config_byte(self, bus, device, func, offset, value) {
        let address = self.make_address(bus, device, func, offset);
        _pci_write_address(address);
        _pci_write_data_byte(offset, value);
    }
    
    fn write_config_word(self, bus, device, func, offset, value) {
        let address = self.make_address(bus, device, func, offset);
        _pci_write_address(address);
        _pci_write_data_word(offset, value);
    }
    
    fn write_config_dword(self, bus, device, func, offset, value) {
        let address = self.make_address(bus, device, func, offset);
        _pci_write_address(address);
        _pci_write_data_dword(value);
    }
    
    fn make_address(self, bus, device, func, offset) {
        return 0x80000000 | (bus << 16) | (device << 11) | (func << 8) | (offset & 0xFC);
    }
    
    fn enumerate_devices(self) {
        let devices = [];
        
        for bus in range(0, 256) {
            for device in range(0, 32) {
                for func in range(0, 8) {
                    let vendor = self.read_config_word(bus, device, func, 0);
                    if vendor != 0xFFFF {
                        let device_id = self.read_config_word(bus, device, func, 2);
                        push(devices, {
                            "bus": bus,
                            "device": device,
                            "function": func,
                            "vendor_id": vendor,
                            "device_id": device_id
                        });
                    }
                }
            }
        }
        
        return devices;
    }
}

# ===========================================
# Hardware Random Number Generator
# ===========================================

class HardwareRNG {
    fn init(self) {
        let cpuid = CPUID();
        self.has_rdrand = cpuid.has_feature("RDRAND");
        self.has_rdseed = cpuid.has_feature("RDSEED");
    }
    
    fn rdrand(self) {
        if !self.has_rdrand {
            panic("HardwareRNG: RDRAND not supported");
        }
        return _rdrand();
    }
    
    fn rdseed(self) {
        if !self.has_rdseed {
            panic("HardwareRNG: RDSEED not supported");
        }
        return _rdseed();
    }
    
    fn rdrand_retry(self, max_retries = 10) {
        for i in range(0, max_retries) {
            let result = _rdrand_check();
            if result[0] {
                return result[1];
            }
        }
        panic("HardwareRNG: RDRAND failed after retries");
    }
    
    fn fill_buffer(self, buffer, size) {
        let offset = 0;
        while offset < size {
            let rand = self.rdrand();
            let bytes_to_copy = min(8, size - offset);
            
            for i in range(0, bytes_to_copy) {
                let byte = (rand >> (i * 8)) & 0xFF;
                systems.poke_u8(buffer + offset + i, byte);
            }
            
            offset = offset + bytes_to_copy;
        }
    }
}

# ===========================================
# CPU Cache Control
# ===========================================

class CacheControl {
    fn flush_line(self, address) {
        # CLFLUSH instruction
        _clflush(address);
    }
    
    fn flush_opt(self, address) {
        # CLFLUSHOPT instruction (optimized)
        _clflushopt(address);
    }
    
    fn writeback_line(self, address) {
        # CLWB instruction (write back, no invalidate)
        _clwb(address);
    }
    
    fn prefetch_t0(self, address) {
        # Prefetch to L1 cache
        _prefetch_t0(address);
    }
    
    fn prefetch_t1(self, address) {
        # Prefetch to L2 cache
        _prefetch_t1(address);
    }
    
    fn prefetch_t2(self, address) {
        # Prefetch to L3 cache
        _prefetch_t2(address);
    }
    
    fn prefetch_nta(self, address) {
        # Non-temporal prefetch (bypass cache)
        _prefetch_nta(address);
    }
    
    fn serialize(self) {
        # Serialize instruction execution (MFENCE + LFENCE + SFENCE)
        _serialize();
    }
    
    fn wbinvd(self) {
        # Write back and invalidate cache (requires ring 0)
        _wbinvd();
    }
    
    fn invd(self) {
        # Invalidate cache (requires ring 0)
        _invd();
    }
}

# ===========================================
# Performance Monitoring
# ===========================================

class PerformanceMonitoring {
    fn init(self) {
        self.counters = [];
    }
    
    fn read_counter(self, counter) {
        # Read performance monitoring counter
        return _rdpmc(counter);
    }
    
    fn enable_counter(self, counter, event) {
        # Configure and enable PMC
        _enable_pmc(counter, event);
    }
    
    fn disable_counter(self, counter) {
        _disable_pmc(counter);
    }
    
    fn read_cycles(self) {
        # Read CPU cycle counter (TSC)
        return _rdtsc();
    }
    
    fn read_instructions(self) {
        # Read retired instructions counter
        return self.read_counter(0);
    }
    
    fn read_cache_misses(self) {
        # Read L3 cache misses
        return self.read_counter(1);
    }
    
    fn read_branch_misses(self) {
        # Read branch mispredictions
        return self.read_counter(2);
    }
}

# ===========================================
# TLB Management
# ===========================================

class TLB {
    fn invlpg(self, address) {
        # Invalidate single page
        _invlpg(address);
    }
    
    fn invlpg_all(self) {
        # Flush entire TLB
        let cr3 = _read_cr3();
        _write_cr3(cr3);
    }
    
    fn invpcid_individual(self, pcid, address) {
        # Invalidate individual address for PCID
        _invpcid(0, pcid, address);
    }
    
    fn invpcid_single(self, pcid) {
        # Invalidate all mappings for PCID
        _invpcid(1, pcid, 0);
    }
    
    fn invpcid_all_except(self, pcid) {
        # Invalidate all except PCID
        _invpcid(2, pcid, 0);
    }
    
    fn invpcid_all(self) {
        # Invalidate all TLB entries
        _invpcid(3, 0, 0);
    }
}

# ===========================================
# CPU Features Control
# ===========================================

class CPUFeatures {
    fn enable_sse(self) {
        let cr0 = _read_cr0();
        cr0 = cr0 & ~(1 << 2);  # Clear EM
        cr0 = cr0 | (1 << 1);   # Set MP
        _write_cr0(cr0);
        
        let cr4 = _read_cr4();
        cr4 = cr4 | (1 << 9);   # Set OSFXSR
        cr4 = cr4 | (1 << 10);  # Set OSXMMEXCPT
        _write_cr4(cr4);
    }
    
    fn enable_avx(self) {
        self.enable_sse();
        
        # Set OSXSAVE
        let cr4 = _read_cr4();
        cr4 = cr4 | (1 << 18);
        _write_cr4(cr4);
        
        # Enable AVX in XCR0
        _xsetbv(0, _xgetbv(0) | 0x7);
    }
    
    fn enable_paging(self) {
        let cr0 = _read_cr0();
        cr0 = cr0 | (1 << 31);  # Set PG
        _write_cr0(cr0);
    }
    
    fn disable_paging(self) {
        let cr0 = _read_cr0();
        cr0 = cr0 & ~(1 << 31);  # Clear PG
        _write_cr0(cr0);
    }
    
    fn enable_pae(self) {
        let cr4 = _read_cr4();
        cr4 = cr4 | (1 << 5);  # Set PAE
        _write_cr4(cr4);
    }
    
    fn enable_smep(self) {
        # Supervisor Mode Execution Prevention
        let cr4 = _read_cr4();
        cr4 = cr4 | (1 << 20);
        _write_cr4(cr4);
    }
    
    fn enable_smap(self) {
        # Supervisor Mode Access Prevention
        let cr4 = _read_cr4();
        cr4 = cr4 | (1 << 21);
        _write_cr4(cr4);
    }
}

# ===========================================
# Native Implementation Stubs
# ===========================================

fn _cpuid(leaf, subleaf) {
    # Execute CPUID instruction
    # Returns {"eax": value, "ebx": value, "ecx": value, "edx": value}
    return {"eax": 0, "ebx": 0, "ecx": 0, "edx": 0};
}

fn _rdmsr(msr) { return 0; }
fn _wrmsr(msr, value) {}
fn _rdtsc() { return 0; }
fn _rdtscp() { return [0, 0]; }
fn _rdpmc(counter) { return 0; }

fn _read_cr0() { return 0; }
fn _write_cr0(value) {}
fn _read_cr2() { return 0; }
fn _read_cr3() { return 0; }
fn _write_cr3(value) {}
fn _read_cr4() { return 0; }
fn _write_cr4(value) {}
fn _read_cr8() { return 0; }
fn _write_cr8(value) {}

fn _read_dr0() { return 0; }
fn _write_dr0(value) {}
fn _read_dr1() { return 0; }
fn _write_dr1(value) {}
fn _read_dr2() { return 0; }
fn _write_dr2(value) {}
fn _read_dr3() { return 0; }
fn _write_dr3(value) {}
fn _read_dr6() { return 0; }
fn _write_dr6(value) {}
fn _read_dr7() { return 0; }
fn _write_dr7(value) {}

fn _read_rflags() { return 0; }
fn _write_rflags(value) {}
fn _read_fs_base() { return 0; }
fn _write_fs_base(value) {}
fn _read_gs_base() { return 0; }
fn _write_gs_base(value) {}

fn _inb(port) { return 0; }
fn _inw(port) { return 0; }
fn _inl(port) { return 0; }
fn _outb(port, value) {}
fn _outw(port, value) {}
fn _outl(port, value) {}

fn _mmio_read8(addr) { return systems.peek_u8(addr); }
fn _mmio_read16(addr) { return systems.peek_u16(addr); }
fn _mmio_read32(addr) { return systems.peek_u32(addr); }
fn _mmio_read64(addr) { return systems.peek_u64(addr); }
fn _mmio_write8(addr, value) { systems.poke_u8(addr, value); }
fn _mmio_write16(addr, value) { systems.poke_u16(addr, value); }
fn _mmio_write32(addr, value) { systems.poke_u32(addr, value); }
fn _mmio_write64(addr, value) { systems.poke_u64(addr, value); }

fn _pci_write_address(addr) { _outl(0xCF8, addr); }
fn _pci_read_data_byte(offset) { return _inb(0xCFC + (offset & 3)); }
fn _pci_read_data_word(offset) { return _inw(0xCFC + (offset & 2)); }
fn _pci_read_data_dword() { return _inl(0xCFC); }
fn _pci_write_data_byte(offset, value) { _outb(0xCFC + (offset & 3), value); }
fn _pci_write_data_word(offset, value) { _outw(0xCFC + (offset & 2), value); }
fn _pci_write_data_dword(value) { _outl(0xCFC, value); }

fn _rdrand() { return 0; }
fn _rdseed() { return 0; }
fn _rdrand_check() { return [false, 0]; }

fn _clflush(addr) {}
fn _clflushopt(addr) {}
fn _clwb(addr) {}
fn _prefetch_t0(addr) {}
fn _prefetch_t1(addr) {}
fn _prefetch_t2(addr) {}
fn _prefetch_nta(addr) {}
fn _serialize() {}
fn _wbinvd() {}
fn _invd() {}

fn _invlpg(addr) {}
fn _invpcid(type, pcid, addr) {}

fn _xgetbv(xcr) { return 0; }
fn _xsetbv(xcr, value) {}

fn _enable_pmc(counter, event) {}
fn _disable_pmc(counter) {}

fn _decode_vendor(result) { return "Unknown"; }
fn _decode_brand(parts) { return "Unknown CPU"; }
fn _extract_cache_size(result, level) { return 0; }

# ===========================================
# Global Instances
# ===========================================

let CPUID_GLOBAL = CPUID();
let MSR_GLOBAL = MSR();
let CPU_REGS_GLOBAL = CPURegisters();
let PORT_IO_GLOBAL = PortIO();
let PCI_GLOBAL = PCI();
let CACHE_CTRL_GLOBAL = CacheControl();
let TLB_GLOBAL = TLB();
let CPU_FEATURES_GLOBAL = CPUFeatures();

# Convenience functions
fn cpuid_vendor() { return CPUID_GLOBAL.vendor_string(); }
fn cpuid_brand() { return CPUID_GLOBAL.brand_string(); }
fn cpuid_has_feature(feature) { return CPUID_GLOBAL.has_feature(feature); }

fn rdtsc() { return MSR_GLOBAL.read_tsc(); }
fn rdmsr(msr) { return MSR_GLOBAL.read(msr); }
fn wrmsr(msr, value) { MSR_GLOBAL.write(msr, value); }

fn read_cr3() { return CPU_REGS_GLOBAL.read_cr3(); }
fn write_cr3(value) { CPU_REGS_GLOBAL.write_cr3(value); }

fn inb(port) { return PORT_IO_GLOBAL.inb(port); }
fn outb(port, value) { PORT_IO_GLOBAL.outb(port, value); }

fn clflush(addr) { CACHE_CTRL_GLOBAL.flush_line(addr); }
fn invlpg(addr) { TLB_GLOBAL.invlpg(addr); }
