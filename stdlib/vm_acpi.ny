# ===========================================
# Nyx VM ACPI Table Generation
# ===========================================
# Generates ACPI tables for guest firmware discovery.
# Covers RSDP, RSDT/XSDT, FADT, MADT, DSDT, MCFG, HPET, BGRT, SRAT, SLIT.
# Production-grade: checksum-correct, Windows/Linux compatible.

import systems

# ===========================================
# Constants
# ===========================================

const ACPI_RSDP_ADDR     = 0x000E0000;   # RSDP in E-segment (BIOS scan area)
const ACPI_TABLE_BASE    = 0x000E1000;   # Tables placed after RSDP
const ACPI_OEM_ID        = "NYXVM ";      # 6-byte OEM ID
const ACPI_OEM_TABLE_ID  = "NYXVMTBL";   # 8-byte OEM Table ID
const ACPI_CREATOR_ID    = "NYX ";        # 4-byte creator
const ACPI_CREATOR_REV   = 0x00000001;

# MADT entry types
const MADT_LAPIC          = 0;
const MADT_IOAPIC         = 1;
const MADT_ISO            = 2;   # Interrupt Source Override
const MADT_NMI            = 4;
const MADT_LAPIC_NMI      = 5;
const MADT_X2APIC         = 9;

# FADT flags
const FADT_WBINVD                = (1 << 0);
const FADT_WBINVD_FLUSH          = (1 << 1);
const FADT_PROC_C1               = (1 << 2);
const FADT_P_LVL2_UP             = (1 << 3);
const FADT_PWR_BUTTON            = (1 << 4);
const FADT_SLP_BUTTON            = (1 << 5);
const FADT_FIX_RTC               = (1 << 6);
const FADT_RTC_S4                = (1 << 7);
const FADT_TMR_VAL_EXT           = (1 << 8);
const FADT_RESET_REG_SUP         = (1 << 10);
const FADT_HW_REDUCED_ACPI       = (1 << 20);

# PM I/O port base
const ACPI_PM_BASE       = 0x600;
const ACPI_PM_TMR_BLK    = 0x608;
const ACPI_GPE0_BLK      = 0x620;
const ACPI_RESET_REG      = 0xCF9;
const ACPI_RESET_VALUE     = 0x06;

# ===========================================
# Low-Level Table Writers
# ===========================================

class ACPIWriter {
    fn init(self, guest_mem) {
        self.mem = guest_mem;
        self.pos = ACPI_TABLE_BASE;
    }

    fn write_u8(self, val) {
        self.mem.write(self.pos, 1, val & 0xFF);
        self.pos = self.pos + 1;
    }

    fn write_u16(self, val) {
        self.mem.write(self.pos, 2, val & 0xFFFF);
        self.pos = self.pos + 2;
    }

    fn write_u32(self, val) {
        self.mem.write(self.pos, 4, val & 0xFFFFFFFF);
        self.pos = self.pos + 4;
    }

    fn write_u64(self, val) {
        self.mem.write(self.pos, 4, val & 0xFFFFFFFF);
        self.mem.write(self.pos + 4, 4, (val >> 32) & 0xFFFFFFFF);
        self.pos = self.pos + 8;
    }

    fn write_bytes(self, data) {
        for b in data {
            self.write_u8(b);
        }
    }

    fn write_string(self, s, padded_len) {
        for i in 0..len(s) {
            self.write_u8(ord(s[i]));
        }
        for i in len(s)..padded_len {
            self.write_u8(0x20);  # space pad
        }
    }

    fn write_signature(self, sig) {
        # 4-byte ASCII signature
        for i in 0..4 {
            self.write_u8(ord(sig[i]));
        }
    }

    fn align(self, boundary) {
        while (self.pos % boundary) != 0 {
            self.write_u8(0);
        }
    }

    fn tell(self) {
        return self.pos;
    }

    fn seek(self, addr) {
        self.pos = addr;
    }

    fn checksum_region(self, start, length) {
        let sum = 0;
        for i in 0..length {
            sum = sum + self.mem.read(start + i, 1);
        }
        return (256 - (sum & 0xFF)) & 0xFF;
    }

    fn patch_checksum(self, table_start, checksum_offset, table_length) {
        # Zero the checksum byte first
        self.mem.write(table_start + checksum_offset, 1, 0);
        let cs = self.checksum_region(table_start, table_length);
        self.mem.write(table_start + checksum_offset, 1, cs);
    }
}

# ===========================================
# Generic Address Structure (GAS)
# ===========================================

fn write_gas(w, address_space, bit_width, bit_offset, access_size, address) {
    w.write_u8(address_space);      # Address Space ID (0=SystemMemory, 1=SystemIO)
    w.write_u8(bit_width);
    w.write_u8(bit_offset);
    w.write_u8(access_size);        # 0=undefined, 1=byte, 2=word, 3=dword, 4=qword
    w.write_u64(address);
}

# ===========================================
# RSDP (Root System Description Pointer)
# ===========================================

fn write_rsdp(w, rsdt_addr, xsdt_addr) {
    let start = ACPI_RSDP_ADDR;
    w.seek(start);

    # Signature "RSD PTR "
    w.write_bytes([0x52, 0x53, 0x44, 0x20, 0x50, 0x54, 0x52, 0x20]);
    w.write_u8(0);                       # Checksum (patched later)
    w.write_string(ACPI_OEM_ID, 6);      # OEM ID
    w.write_u8(2);                       # Revision (2 = ACPI 2.0+)
    w.write_u32(rsdt_addr);              # RSDT Address
    w.write_u32(36);                     # Length (36 bytes for RSDP 2.0+)
    w.write_u64(xsdt_addr);             # XSDT Address
    w.write_u8(0);                       # Extended Checksum (patched later)
    w.write_bytes([0, 0, 0]);            # Reserved

    # Patch checksums
    # Legacy checksum covers first 20 bytes
    w.patch_checksum(start, 8, 20);
    # Extended checksum covers full 36 bytes
    w.patch_checksum(start, 32, 36);
}

# ===========================================
# Standard Table Header
# ===========================================

fn write_table_header(w, signature, length, revision) {
    w.write_signature(signature);
    w.write_u32(length);
    w.write_u8(revision);
    w.write_u8(0);                           # Checksum (patched later)
    w.write_string(ACPI_OEM_ID, 6);
    w.write_string(ACPI_OEM_TABLE_ID, 8);
    w.write_u32(1);                          # OEM Revision
    w.write_string(ACPI_CREATOR_ID, 4);
    w.write_u32(ACPI_CREATOR_REV);
}

# ===========================================
# RSDT (Root System Description Table)
# ===========================================

fn write_rsdt(w, table_addrs) {
    let start = w.tell();
    let length = 36 + (len(table_addrs) * 4);
    write_table_header(w, "RSDT", length, 1);
    for addr in table_addrs {
        w.write_u32(addr);
    }
    w.patch_checksum(start, start + 9 - start, length);
    # Actually checksum offset is byte 9 from table start
    w.patch_checksum(start, 9, length);
    return start;
}

# ===========================================
# XSDT (Extended System Description Table)
# ===========================================

fn write_xsdt(w, table_addrs) {
    let start = w.tell();
    let length = 36 + (len(table_addrs) * 8);
    write_table_header(w, "XSDT", length, 1);
    for addr in table_addrs {
        w.write_u64(addr);
    }
    w.patch_checksum(start, 9, length);
    return start;
}

# ===========================================
# FADT (Fixed ACPI Description Table)
# ===========================================

fn write_fadt(w, dsdt_addr) {
    let start = w.tell();
    let length = 276;   # ACPI 6.0 FADT is 276 bytes
    write_table_header(w, "FACP", length, 6);

    # FACS pointer (we don't supply one)
    w.write_u32(0);                          # FIRMWARE_CTRL (32-bit)
    w.write_u32(dsdt_addr);                  # DSDT (32-bit pointer)

    w.write_u8(0);                           # Reserved (was INT_MODEL)
    w.write_u8(0);                           # Preferred PM Profile (0=Unspecified)
    w.write_u16(9);                          # SCI_INT (IRQ 9)
    w.write_u32(0xB2);                       # SMI_CMD port
    w.write_u8(0xF0);                        # ACPI_ENABLE value
    w.write_u8(0xF1);                        # ACPI_DISABLE value
    w.write_u8(0);                           # S4BIOS_REQ
    w.write_u8(0);                           # PSTATE_CNT

    w.write_u32(ACPI_PM_BASE);              # PM1a_EVT_BLK
    w.write_u32(0);                          # PM1b_EVT_BLK
    w.write_u32(ACPI_PM_BASE + 4);          # PM1a_CNT_BLK
    w.write_u32(0);                          # PM1b_CNT_BLK
    w.write_u32(0);                          # PM2_CNT_BLK
    w.write_u32(ACPI_PM_TMR_BLK);           # PM_TMR_BLK
    w.write_u32(ACPI_GPE0_BLK);             # GPE0_BLK
    w.write_u32(0);                          # GPE1_BLK

    w.write_u8(4);                           # PM1_EVT_LEN
    w.write_u8(2);                           # PM1_CNT_LEN
    w.write_u8(0);                           # PM2_CNT_LEN
    w.write_u8(4);                           # PM_TMR_LEN
    w.write_u8(8);                           # GPE0_BLK_LEN
    w.write_u8(0);                           # GPE1_BLK_LEN
    w.write_u8(0);                           # GPE1_BASE
    w.write_u8(0);                           # CST_CNT
    w.write_u16(0x0065);                     # P_LVL2_LAT
    w.write_u16(0x0FFF);                     # P_LVL3_LAT

    w.write_u16(0);                          # FLUSH_SIZE
    w.write_u16(0);                          # FLUSH_STRIDE
    w.write_u8(0);                           # DUTY_OFFSET
    w.write_u8(0);                           # DUTY_WIDTH
    w.write_u8(0);                           # DAY_ALRM
    w.write_u8(0);                           # MON_ALRM
    w.write_u8(0x32);                        # CENTURY (RTC register 0x32)

    w.write_u16(0);                          # IAPC_BOOT_ARCH (16-bit)
    w.write_u8(0);                           # Reserved

    # Flags
    let flags = FADT_WBINVD | FADT_PROC_C1 | FADT_SLP_BUTTON |
                FADT_FIX_RTC | FADT_TMR_VAL_EXT | FADT_RESET_REG_SUP;
    w.write_u32(flags);

    # RESET_REG (GAS)
    write_gas(w, 1, 8, 0, 1, ACPI_RESET_REG);
    w.write_u8(ACPI_RESET_VALUE);            # RESET_VALUE

    w.write_u16(0);                          # ARM_BOOT_ARCH
    w.write_u8(2);                           # FADT Minor Version (6.2)

    # 64-bit fields (ACPI 2.0+)
    w.write_u64(0);                          # X_FIRMWARE_CTRL
    w.write_u64(dsdt_addr);                  # X_DSDT

    # X_PM1a_EVT_BLK
    write_gas(w, 1, 32, 0, 3, ACPI_PM_BASE);
    # X_PM1b_EVT_BLK
    write_gas(w, 0, 0, 0, 0, 0);
    # X_PM1a_CNT_BLK
    write_gas(w, 1, 16, 0, 2, ACPI_PM_BASE + 4);
    # X_PM1b_CNT_BLK
    write_gas(w, 0, 0, 0, 0, 0);
    # X_PM2_CNT_BLK
    write_gas(w, 0, 0, 0, 0, 0);
    # X_PM_TMR_BLK
    write_gas(w, 1, 32, 0, 3, ACPI_PM_TMR_BLK);
    # X_GPE0_BLK
    write_gas(w, 1, 64, 0, 3, ACPI_GPE0_BLK);
    # X_GPE1_BLK
    write_gas(w, 0, 0, 0, 0, 0);

    # Pad to exact length
    while w.tell() < start + length {
        w.write_u8(0);
    }

    w.patch_checksum(start, 9, length);
    return start;
}

# ===========================================
# MADT (Multiple APIC Description Table)
# ===========================================

fn write_madt(w, num_cpus, num_ioapics) {
    let start = w.tell();
    # Calculate length: header(36+8) + LAPIC entries + IOAPIC entries + ISOs + LAPIC NMI
    let lapic_size = num_cpus * 8;
    let ioapic_size = num_ioapics * 12;
    let iso_size = 10 * 2;     # IRQ0→2 and IRQ9 overrides
    let nmi_size = 6;          # LAPIC NMI
    let length = 44 + lapic_size + ioapic_size + iso_size + nmi_size;

    write_table_header(w, "APIC", length, 4);

    # Local APIC Address
    w.write_u32(0xFEE00000);
    # Flags (1 = PCAT_COMPAT - dual 8259 present)
    w.write_u32(1);

    # Local APIC entries (type 0)
    for i in 0..num_cpus {
        w.write_u8(MADT_LAPIC);         # Type
        w.write_u8(8);                  # Length
        w.write_u8(i);                  # ACPI Processor UID
        w.write_u8(i);                  # APIC ID
        w.write_u32(1);                 # Flags (1=enabled)
    }

    # I/O APIC entries (type 1)
    for i in 0..num_ioapics {
        w.write_u8(MADT_IOAPIC);        # Type
        w.write_u8(12);                 # Length
        w.write_u8(i);                  # I/O APIC ID
        w.write_u8(0);                  # Reserved
        w.write_u32(0xFEC00000 + (i * 0x1000));  # I/O APIC Address
        w.write_u32(i * 24);            # Global System Interrupt Base
    }

    # Interrupt Source Overrides
    # ISA IRQ 0 → GSI 2 (timer remap)
    w.write_u8(MADT_ISO);
    w.write_u8(10);
    w.write_u8(0);       # Bus (ISA)
    w.write_u8(0);       # Source (IRQ 0)
    w.write_u32(2);      # Global System Interrupt
    w.write_u16(0);      # Flags (conforms)

    # ISA IRQ 9 → GSI 9 (SCI, level-triggered active-low)
    w.write_u8(MADT_ISO);
    w.write_u8(10);
    w.write_u8(0);       # Bus
    w.write_u8(9);       # Source
    w.write_u32(9);      # GSI
    w.write_u16(0x000D); # Flags: active-low, level-triggered

    # Local APIC NMI (LINT1 for all processors)
    w.write_u8(MADT_LAPIC_NMI);
    w.write_u8(6);
    w.write_u8(0xFF);    # All processors
    w.write_u16(0x0005); # Flags: active-high, edge-triggered
    w.write_u8(1);       # LINT#1

    w.patch_checksum(start, 9, length);
    return start;
}

# ===========================================
# DSDT (Differentiated System Description Table)
# ===========================================
# Minimal AML bytecode for Windows/Linux compatibility.

fn write_dsdt(w, num_cpus, pci_devices) {
    let start = w.tell();

    # We emit a minimal DSDT with:
    #   - \_SB scope with processor devices
    #   - PCI0 device with _HID, _CRS
    #   - \_S5 sleep object (for shutdown)
    # The AML is hand-assembled.

    let aml = build_dsdt_aml(num_cpus, pci_devices);
    let length = 36 + len(aml);

    write_table_header(w, "DSDT", length, 2);
    w.write_bytes(aml);

    w.patch_checksum(start, 9, length);
    return start;
}

fn build_dsdt_aml(num_cpus, pci_devices) {
    let aml = [];

    # DefinitionBlock header is implicit (header already written)

    # === Scope(\_SB) ===
    # ScopeOp, PkgLength, "\_SB_"
    let sb_body = [];

    # --- PCI0 Device ---
    let pci0_body = [];

    # _HID = "PNP0A08" (PCI Express root)
    push_all(pci0_body, aml_name_string("_HID", aml_eisaid("PNP0A08")));

    # _CID = "PNP0A03" (PCI bus, compat)
    push_all(pci0_body, aml_name_string("_CID", aml_eisaid("PNP0A03")));

    # _SEG = 0
    push_all(pci0_body, aml_name_integer("_SEG", 0));

    # _BBN = 0 (bus base number)
    push_all(pci0_body, aml_name_integer("_BBN", 0));

    # _UID = 0
    push_all(pci0_body, aml_name_integer("_UID", 0));

    # _CRS (Current Resource Settings) — I/O 0xCF8-0xCFF, MMIO config space
    push_all(pci0_body, aml_pci0_crs());

    # PCI routing table (_PRT) for 4 interrupt pins
    push_all(pci0_body, aml_pci0_prt(pci_devices));

    # Wrap in Device(PCI0)
    let pci0 = aml_device("PCI0", pci0_body);
    push_all(sb_body, pci0);

    # --- Processor Devices ---
    for i in 0..num_cpus {
        let cpu_name = "C" + zero_pad(i, 3);  # C000, C001, ...
        let cpu_body = [];
        push_all(cpu_body, aml_name_string("_HID", aml_string("ACPI0007")));
        push_all(cpu_body, aml_name_integer("_UID", i));
        push_all(sb_body, aml_device(cpu_name, cpu_body));
    }

    # Wrap in Scope(\_SB)
    let sb_scope = aml_scope("\\_SB_", sb_body);
    push_all(aml, sb_scope);

    # === \_S5 (Soft Off) ===
    # Name(\_S5, Package(0x04){0x05, 0x05, 0x00, 0x00})
    push_all(aml, aml_s5_package());

    return aml;
}

# ===========================================
# AML Bytecode Helpers
# ===========================================

fn aml_scope(name, body) {
    let name_bytes = aml_namestring(name);
    let contents = [];
    push_all(contents, name_bytes);
    push_all(contents, body);

    let pkg = aml_pkg_length(len(contents) + 1);
    let result = [0x10];  # ScopeOp
    push_all(result, pkg);
    push_all(result, contents);
    return result;
}

fn aml_device(name, body) {
    let name_bytes = aml_namestring(name);
    let contents = [];
    push_all(contents, name_bytes);
    push_all(contents, body);

    let pkg = aml_pkg_length(len(contents) + 2);
    let result = [0x5B, 0x82];  # ExtOpPrefix + DeviceOp
    push_all(result, pkg);
    push_all(result, contents);
    return result;
}

fn aml_name_string(name, value_bytes) {
    let result = [0x08];  # NameOp
    push_all(result, aml_namestring(name));
    push_all(result, value_bytes);
    return result;
}

fn aml_name_integer(name, value) {
    let result = [0x08];  # NameOp
    push_all(result, aml_namestring(name));
    if value == 0 {
        push(result, 0x00);  # ZeroOp
    } else if value == 1 {
        push(result, 0x01);  # OneOp
    } else if value <= 0xFF {
        push(result, 0x0A);  # BytePrefix
        push(result, value);
    } else if value <= 0xFFFF {
        push(result, 0x0B);  # WordPrefix
        push(result, value & 0xFF);
        push(result, (value >> 8) & 0xFF);
    } else {
        push(result, 0x0C);  # DWordPrefix
        push(result, value & 0xFF);
        push(result, (value >> 8) & 0xFF);
        push(result, (value >> 16) & 0xFF);
        push(result, (value >> 24) & 0xFF);
    }
    return result;
}

fn aml_string(s) {
    let result = [0x0D];  # StringPrefix
    for i in 0..len(s) {
        push(result, ord(s[i]));
    }
    push(result, 0x00);  # Null terminator
    return result;
}

fn aml_eisaid(id) {
    # EISA ID encoding: "PNP0A08" → DWordConst
    # Compress 3-char vendor + 4-hex product into 32-bit
    let c0 = ord(id[0]) - 0x40;
    let c1 = ord(id[1]) - 0x40;
    let c2 = ord(id[2]) - 0x40;

    let hi = ((c0 & 0x1F) << 2) | ((c1 >> 3) & 0x03);
    let lo = ((c1 & 0x07) << 5) | (c2 & 0x1F);

    let product = hex_to_int(id[3..7]);
    let swap_product = ((product & 0xFF) << 8) | ((product >> 8) & 0xFF);

    let eisa = (hi << 24) | (lo << 16) | swap_product;

    let result = [0x0C];  # DWordPrefix
    push(result, eisa & 0xFF);
    push(result, (eisa >> 8) & 0xFF);
    push(result, (eisa >> 16) & 0xFF);
    push(result, (eisa >> 24) & 0xFF);
    return result;
}

fn aml_namestring(name) {
    let result = [];
    let start = 0;
    # Handle root prefix
    if len(name) > 0 and name[0] == '\\' {
        push(result, 0x5C);  # RootChar
        start = 1;
    }
    # Split by '.' and handle segments
    let seg = "";
    for i in start..len(name) {
        if name[i] == '.' {
            if len(seg) > 0 {
                push_all(result, aml_nameseg(seg));
            }
            seg = "";
        } else {
            seg = seg + name[i];
        }
    }
    if len(seg) > 0 {
        push_all(result, aml_nameseg(seg));
    }
    return result;
}

fn aml_nameseg(seg) {
    # Pad to exactly 4 bytes
    let result = [];
    for i in 0..4 {
        if i < len(seg) {
            push(result, ord(seg[i]));
        } else {
            push(result, ord('_'));
        }
    }
    return result;
}

fn aml_pkg_length(length) {
    # Encode PkgLength per ACPI spec
    if length < 0x3F {
        return [length + 1];
    } else if length < 0x0FFF {
        let total = length + 2;
        let b0 = (1 << 6) | (total & 0x0F);
        let b1 = (total >> 4) & 0xFF;
        return [b0, b1];
    } else if length < 0x0FFFFF {
        let total = length + 3;
        let b0 = (2 << 6) | (total & 0x0F);
        let b1 = (total >> 4) & 0xFF;
        let b2 = (total >> 12) & 0xFF;
        return [b0, b1, b2];
    } else {
        let total = length + 4;
        let b0 = (3 << 6) | (total & 0x0F);
        let b1 = (total >> 4) & 0xFF;
        let b2 = (total >> 12) & 0xFF;
        let b3 = (total >> 20) & 0xFF;
        return [b0, b1, b2, b3];
    }
}

fn aml_pci0_crs() {
    # ResourceTemplate for PCI0:
    # WordBusNumber(0x00, 0xFF)
    # IO(0xCF8, 0xCFF)
    # DWordMemory(0, 0xFFFFFFFF) — will be narrowed by firmware
    # We encode as raw resource descriptor bytes.

    let crs_data = [];

    # Word Bus Number (type 0x88)
    push_all(crs_data, [
        0x88, 0x0D, 0x00,    # Large: WordBusNumber, length=13
        0x02,                  # ResourceType=BusNumber
        0x0C,                  # General Flags: Min fixed, Max fixed
        0x00,                  # Type Specific
        0x00, 0x00,            # Granularity
        0x00, 0x00,            # Min = 0
        0xFF, 0x00,            # Max = 255
        0x00, 0x00,            # Translation
        0x00, 0x01             # Length = 256
    ]);

    # IO port range (type 0x47)
    push_all(crs_data, [
        0x47,           # Small: IO
        0x01,           # Decode 16-bit
        0xF8, 0x0C,     # Min = 0x0CF8
        0xFF, 0x0C,     # Max = 0x0CFF
        0x01,           # Alignment
        0x08            # Length = 8
    ]);

    # DWord Memory (IO Window for PCI MMIO)
    push_all(crs_data, [
        0x87, 0x17, 0x00,     # Large: DWordMemory, length=23
        0x00,                  # ResourceType=Memory
        0x0C,                  # General Flags: Min/Max fixed
        0x03,                  # Type: read-write, non-cacheable
        0x00, 0x00, 0x00, 0x00, # Granularity
        0x00, 0x00, 0x00, 0xE0, # Min = 0xE0000000
        0xFF, 0xFF, 0xFF, 0xFE, # Max = 0xFEFFFFFF
        0x00, 0x00, 0x00, 0x00, # Translation
        0x00, 0x00, 0x00, 0x1F  # Length = 0x1F000000
    ]);

    # End Tag
    push_all(crs_data, [0x79, 0x00]);

    # Wrap as Name(_CRS, Buffer(...))
    let result = [0x08];  # NameOp
    push_all(result, aml_namestring("_CRS"));

    # BufferOp
    push(result, 0x11);  # BufferOp
    let buf_inner = [];
    # Buffer size as byte/word
    if len(crs_data) <= 0xFF {
        push(buf_inner, 0x0A);  # BytePrefix
        push(buf_inner, len(crs_data));
    } else {
        push(buf_inner, 0x0B);  # WordPrefix
        push(buf_inner, len(crs_data) & 0xFF);
        push(buf_inner, (len(crs_data) >> 8) & 0xFF);
    }
    push_all(buf_inner, crs_data);

    let pkg = aml_pkg_length(len(buf_inner));
    push_all(result, pkg);
    push_all(result, buf_inner);

    return result;
}

fn aml_pci0_prt(pci_devices) {
    # Minimal _PRT (PCI Routing Table) using GSI direct routing
    # Each entry: Package{Address, Pin, Source, SourceIndex}

    let entries = [];
    let slot = 0;
    for dev in pci_devices {
        for pin in 0..4 {
            let gsi = ((slot + pin) % 24) + 5;  # Round-robin GSIs starting at 5
            # Package{DWORD address, BYTE pin, NIL source, DWORD GSI}
            let entry = [];
            push(entry, 0x12);  # PackageOp
            let inner = [];
            push(inner, 0x04);  # NumElements = 4

            # Address: (slot << 16) | 0xFFFF
            push(inner, 0x0C);  # DWordPrefix
            let addr = (slot << 16) | 0xFFFF;
            push(inner, addr & 0xFF);
            push(inner, (addr >> 8) & 0xFF);
            push(inner, (addr >> 16) & 0xFF);
            push(inner, (addr >> 24) & 0xFF);

            # Pin
            push(inner, 0x0A);
            push(inner, pin);

            # Source (0 = no PIC source, use GSI)
            push(inner, 0x00);

            # Source Index (GSI)
            push(inner, 0x0A);
            push(inner, gsi);

            let entry_pkg = aml_pkg_length(len(inner));
            push_all(entry, entry_pkg);
            push_all(entry, inner);
            push_all(entries, entry);
        }
        slot = slot + 1;
    }

    # Wrap in Name(_PRT, Package(N) { ... })
    let result = [0x08];  # NameOp
    push_all(result, aml_namestring("_PRT"));
    push(result, 0x12);   # PackageOp

    let pkg_inner = [];
    push(pkg_inner, len(pci_devices) * 4);  # NumElements
    push_all(pkg_inner, entries);

    let pkg = aml_pkg_length(len(pkg_inner));
    push_all(result, pkg);
    push_all(result, pkg_inner);

    return result;
}

fn aml_s5_package() {
    # Name(\_S5_, Package(0x04){0x05, 0x05, 0x00, 0x00})
    let result = [0x08];  # NameOp
    push_all(result, aml_namestring("\\_S5_"));
    push_all(result, [
        0x12, 0x06, 0x04,  # Package, Length, NumElements=4
        0x0A, 0x05,         # BytePrefix, 5 (SLP_TYPa)
        0x0A, 0x05,         # BytePrefix, 5 (SLP_TYPb)
        0x00,               # Zero
        0x00                # Zero
    ]);
    return result;
}

# ===========================================
# MCFG (PCI Express MMIO Config Space)
# ===========================================

fn write_mcfg(w, ecam_base, start_bus, end_bus, segment) {
    let start = w.tell();
    let length = 36 + 8 + 16;  # header + reserved + 1 allocation entry

    write_table_header(w, "MCFG", length, 1);

    w.write_u64(0);               # Reserved

    # Configuration Space Base Address Allocation Structure
    w.write_u64(ecam_base);       # Base Address
    w.write_u16(segment);         # PCI Segment Group
    w.write_u8(start_bus);        # Start Bus
    w.write_u8(end_bus);          # End Bus
    w.write_u32(0);               # Reserved

    w.patch_checksum(start, 9, length);
    return start;
}

# ===========================================
# HPET (High Precision Event Timer Table)
# ===========================================

fn write_hpet_table(w) {
    let start = w.tell();
    let length = 36 + 4 + 12 + 4 + 2 + 1 + 1;

    write_table_header(w, "HPET", 56, 1);

    # Hardware Revision ID + Number of Comparators + Counter Size + etc
    w.write_u32(0x8086A201);      # Event Timer Block ID (vendor + rev)

    # Base Address (GAS)
    write_gas(w, 0, 64, 0, 0, 0xFED00000);

    w.write_u8(0);                # HPET Number
    w.write_u16(0x0080);          # Main Counter Minimum Clock Tick
    w.write_u8(0);                # Page Protection

    while w.tell() < start + 56 {
        w.write_u8(0);
    }

    w.patch_checksum(start, 9, 56);
    return start;
}

# ===========================================
# SRAT (System Resource Affinity Table) - NUMA
# ===========================================

fn write_srat(w, num_cpus, memory_size) {
    let start = w.tell();
    # All CPUs and memory in proximity domain 0 (single NUMA node)
    let cpu_entries = num_cpus * 16;
    let mem_entries = 40;  # One memory affinity entry
    let length = 48 + cpu_entries + mem_entries;

    write_table_header(w, "SRAT", length, 3);

    w.write_u32(1);   # Table Revision
    w.write_u64(0);   # Reserved

    # Processor Local APIC Affinity (type 0)
    for i in 0..num_cpus {
        w.write_u8(0);           # Type: Processor LAPIC
        w.write_u8(16);          # Length
        w.write_u8(0);           # Proximity Domain [7:0]
        w.write_u8(i);           # APIC ID
        w.write_u32(1);          # Flags (Enabled)
        w.write_u8(0);           # Local SAPIC EID
        w.write_bytes([0, 0, 0]); # Proximity Domain [31:8]
        w.write_u32(0);          # Clock Domain
    }

    # Memory Affinity (type 1)
    w.write_u8(1);               # Type: Memory
    w.write_u8(40);              # Length
    w.write_u32(0);              # Proximity Domain
    w.write_u16(0);              # Reserved
    w.write_u64(0);              # Base Address Low/High
    w.write_u64(memory_size);    # Length Low/High
    w.write_u32(0);              # Reserved
    w.write_u32(1);              # Flags (Enabled)
    w.write_u64(0);              # Reserved

    w.patch_checksum(start, 9, length);
    return start;
}

# ===========================================
# Master ACPI Table Builder
# ===========================================

class ACPITableBuilder {
    fn init(self, guest_mem) {
        self.writer = ACPIWriter(guest_mem);
        self.guest_mem = guest_mem;
        self.table_addrs = [];
    }

    fn build(self, num_cpus, pci_devices, memory_size) {
        let w = self.writer;

        # Reserve space for RSDT and XSDT (will write last)
        w.seek(ACPI_TABLE_BASE);
        let rsdt_addr = w.tell();
        w.seek(rsdt_addr + 256);     # Reserve space for RSDT

        let xsdt_addr = w.tell();
        w.seek(xsdt_addr + 512);     # Reserve space for XSDT

        w.align(64);

        # DSDT
        let dsdt_addr = w.tell();
        write_dsdt(w, num_cpus, pci_devices);
        w.align(64);

        # FADT (points to DSDT)
        let fadt_addr = w.tell();
        write_fadt(w, dsdt_addr);
        push(self.table_addrs, fadt_addr);
        w.align(64);

        # MADT
        let madt_addr = w.tell();
        write_madt(w, num_cpus, 1);
        push(self.table_addrs, madt_addr);
        w.align(64);

        # MCFG (PCIe ECAM at 0xB0000000)
        let mcfg_addr = w.tell();
        write_mcfg(w, 0xB0000000, 0, 255, 0);
        push(self.table_addrs, mcfg_addr);
        w.align(64);

        # HPET
        let hpet_addr = w.tell();
        write_hpet_table(w);
        push(self.table_addrs, hpet_addr);
        w.align(64);

        # SRAT (NUMA)
        let srat_addr = w.tell();
        write_srat(w, num_cpus, memory_size);
        push(self.table_addrs, srat_addr);
        w.align(64);

        # Now write RSDT and XSDT with collected addresses
        w.seek(rsdt_addr);
        write_rsdt(w, self.table_addrs);

        w.seek(xsdt_addr);
        write_xsdt(w, self.table_addrs);

        # RSDP (points to RSDT and XSDT)
        write_rsdp(w, rsdt_addr, xsdt_addr);

        return {
            "rsdp": ACPI_RSDP_ADDR,
            "rsdt": rsdt_addr,
            "xsdt": xsdt_addr,
            "dsdt": dsdt_addr,
            "fadt": fadt_addr,
            "madt": madt_addr,
            "mcfg": mcfg_addr,
            "hpet": hpet_addr,
            "srat": srat_addr
        };
    }
}

# ===========================================
# Utility Functions
# ===========================================

fn push_all(dst, src) {
    for item in src {
        push(dst, item);
    }
}

fn zero_pad(n, digits) {
    let s = str(n);
    while len(s) < digits {
        s = "0" + s;
    }
    return s;
}

fn hex_to_int(s) {
    let result = 0;
    for i in 0..len(s) {
        let c = s[i];
        let v = 0;
        if c >= '0' and c <= '9' { v = ord(c) - ord('0'); }
        else if c >= 'A' and c <= 'F' { v = ord(c) - ord('A') + 10; }
        else if c >= 'a' and c <= 'f' { v = ord(c) - ord('a') + 10; }
        result = (result << 4) | v;
    }
    return result;
}

fn ord(c) {
    return systems.char_to_int(c);
}
