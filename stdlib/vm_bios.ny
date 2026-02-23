# ===========================================
# Nyx VM Legacy BIOS Boot Module
# ===========================================
# Full legacy BIOS boot path: real-mode setup, IVT, BDA,
# EBDA, E820 memory map, VGA text-mode init, PCI BIOS,
# SMBIOS entry point, MP table.

import systems
import hardware

# ===========================================
# Constants
# ===========================================

# Memory layout for legacy BIOS
const IVT_BASE           = 0x00000000;   # Interrupt Vector Table (1KB)
const BDA_BASE           = 0x00000400;   # BIOS Data Area
const EBDA_BASE          = 0x0009FC00;   # Extended BIOS Data Area
const VGA_TEXT_BASE      = 0x000B8000;   # VGA text framebuffer
const VGA_ROM_BASE       = 0x000C0000;   # VGA BIOS ROM
const BIOS_ROM_BASE      = 0x000F0000;   # System BIOS ROM (64KB)
const BIOS_ENTRY_POINT   = 0x000FFFF0;   # CPU reset vector (jmp to BIOS)
const E820_TABLE_ADDR    = 0x00090000;   # E820 memory map scratch area
const SMBIOS_ENTRY_ADDR  = 0x000F0100;   # SMBIOS entry point
const MP_TABLE_ADDR      = 0x000F0400;   # MP Floating Pointer

# BDA offsets (relative to 0x400)
const BDA_COM1_PORT      = 0x00;   # COM1 base address (2 bytes)
const BDA_COM2_PORT      = 0x02;
const BDA_LPT1_PORT      = 0x08;
const BDA_EQUIPMENT_WORD = 0x10;   # Equipment list word
const BDA_MEM_SIZE       = 0x13;   # Memory size in KB (below 1MB)
const BDA_KEYBOARD_FLAGS = 0x17;
const BDA_NUM_HARD_DISKS = 0x75;
const BDA_VIDEO_MODE     = 0x49;
const BDA_VIDEO_COLS     = 0x4A;
const BDA_VIDEO_PAGE_SIZE= 0x4C;
const BDA_CURSOR_POS     = 0x50;
const BDA_CURSOR_SHAPE   = 0x60;
const BDA_ACTIVE_PAGE    = 0x62;
const BDA_CRTC_BASE      = 0x63;
const BDA_VIDEO_ROWS     = 0x84;
const BDA_CHAR_HEIGHT    = 0x85;
const BDA_VGA_MISC       = 0x89;
const BDA_EBDA_SEGMENT   = 0x0E;   # EBDA segment (2 bytes) at 0x40E

# E820 types
const E820_RAM           = 1;
const E820_RESERVED      = 2;
const E820_ACPI_RECLAIM  = 3;
const E820_ACPI_NVS      = 4;
const E820_UNUSABLE       = 5;

# ===========================================
# BIOS Data Area Setup
# ===========================================

class BIOSDataArea {
    fn init(self, guest_mem) {
        self.mem = guest_mem;
    }

    fn setup(self, config) {
        # COM ports
        self.mem.write(BDA_BASE + BDA_COM1_PORT, 2, 0x03F8);
        self.mem.write(BDA_BASE + BDA_COM2_PORT, 2, 0x02F8);

        # LPT ports
        self.mem.write(BDA_BASE + BDA_LPT1_PORT, 2, 0x0378);

        # Equipment word:
        # Bit 0: floppy available
        # Bits 1: math coprocessor
        # Bit 4-5: initial video mode (10 = 80x25 color)
        # Bit 9-11: number of COM ports
        let equip = 0x0000;
        equip = equip | (1 << 1);     # FPU present
        equip = equip | (2 << 4);     # 80x25 color mode
        equip = equip | (2 << 9);     # 2 COM ports
        self.mem.write(BDA_BASE + BDA_EQUIPMENT_WORD, 2, equip);

        # Conventional memory size (in KB, max 640)
        self.mem.write(BDA_BASE + BDA_MEM_SIZE, 2, 640);

        # Keyboard flags (clear)
        self.mem.write(BDA_BASE + BDA_KEYBOARD_FLAGS, 1, 0);

        # Hard disk count
        let num_disks = len(config.disks);
        if num_disks > 4 { num_disks = 4; }
        self.mem.write(BDA_BASE + BDA_NUM_HARD_DISKS, 1, num_disks);

        # Video mode setup
        self.mem.write(BDA_BASE + BDA_VIDEO_MODE, 1, 0x03);     # Mode 3: 80x25 color text
        self.mem.write(BDA_BASE + BDA_VIDEO_COLS, 2, 80);
        self.mem.write(BDA_BASE + BDA_VIDEO_PAGE_SIZE, 2, 4000); # 80*25*2
        self.mem.write(BDA_BASE + BDA_CURSOR_POS, 2, 0);
        self.mem.write(BDA_BASE + BDA_CURSOR_SHAPE, 2, 0x0607);  # Underline cursor
        self.mem.write(BDA_BASE + BDA_ACTIVE_PAGE, 1, 0);
        self.mem.write(BDA_BASE + BDA_CRTC_BASE, 2, 0x03D4);    # Color CRTC
        self.mem.write(BDA_BASE + BDA_VIDEO_ROWS, 1, 24);        # 25 rows - 1
        self.mem.write(BDA_BASE + BDA_CHAR_HEIGHT, 2, 16);

        # VGA miscellaneous flags
        self.mem.write(BDA_BASE + BDA_VGA_MISC, 1, 0x60);

        # EBDA segment pointer
        self.mem.write(BDA_BASE + BDA_EBDA_SEGMENT, 2, EBDA_BASE >> 4);
    }
}

# ===========================================
# Interrupt Vector Table
# ===========================================

class IVTSetup {
    fn init(self, guest_mem) {
        self.mem = guest_mem;
    }

    fn setup(self, bios_segment) {
        # Set all 256 IVT entries to a default IRET handler in BIOS ROM
        # Each entry is 4 bytes: offset(2) + segment(2)
        let default_handler = 0xFFF0;  # Offset within BIOS segment pointing to IRET

        for i in 0..256 {
            let addr = i * 4;
            self.mem.write(addr, 2, default_handler);
            self.mem.write(addr + 2, 2, bios_segment);
        }

        # Set specific interrupt handlers
        # INT 0x10 — Video Services
        self.set_ivt(0x10, bios_segment, 0x1000);
        # INT 0x11 — Equipment List
        self.set_ivt(0x11, bios_segment, 0x1100);
        # INT 0x12 — Memory Size
        self.set_ivt(0x12, bios_segment, 0x1200);
        # INT 0x13 — Disk Services
        self.set_ivt(0x13, bios_segment, 0x1300);
        # INT 0x14 — Serial Port Services
        self.set_ivt(0x14, bios_segment, 0x1400);
        # INT 0x15 — System Services (E820, etc.)
        self.set_ivt(0x15, bios_segment, 0x1500);
        # INT 0x16 — Keyboard Services
        self.set_ivt(0x16, bios_segment, 0x1600);
        # INT 0x17 — Printer Services
        self.set_ivt(0x17, bios_segment, 0x1700);
        # INT 0x18 — ROM BASIC (boot failure)
        self.set_ivt(0x18, bios_segment, 0x1800);
        # INT 0x19 — Bootstrap Loader
        self.set_ivt(0x19, bios_segment, 0x1900);
        # INT 0x1A — Time Services / PCI BIOS
        self.set_ivt(0x1A, bios_segment, 0x1A00);
    }

    fn set_ivt(self, vector, segment, offset) {
        let addr = vector * 4;
        self.mem.write(addr, 2, offset);
        self.mem.write(addr + 2, 2, segment);
    }
}

# ===========================================
# E820 Memory Map
# ===========================================

class E820MemoryMap {
    fn init(self) {
        self.entries = [];
    }

    fn add(self, base, length, type) {
        push(self.entries, {
            "base": base,
            "length": length,
            "type": type
        });
    }

    fn build_standard(self, total_memory) {
        # Standard PC memory map
        # 0x00000000 - 0x0009FBFF: Conventional RAM (639.75 KB)
        self.add(0x00000000, 0x0009FC00, E820_RAM);

        # 0x0009FC00 - 0x0009FFFF: EBDA (1 KB)
        self.add(0x0009FC00, 0x00000400, E820_RESERVED);

        # 0x000A0000 - 0x000BFFFF: VGA memory
        self.add(0x000A0000, 0x00020000, E820_RESERVED);

        # 0x000C0000 - 0x000C7FFF: VGA BIOS ROM
        self.add(0x000C0000, 0x00008000, E820_RESERVED);

        # 0x000E0000 - 0x000FFFFF: System BIOS / ACPI
        self.add(0x000E0000, 0x00020000, E820_RESERVED);

        # 0x00100000 - (total - 1MB): Extended RAM
        if total_memory > 0x00100000 {
            let extended = total_memory - 0x00100000;
            # Reserve top 64KB for ACPI tables if above 1MB
            if extended > 0x00010000 {
                self.add(0x00100000, extended - 0x00010000, E820_RAM);
                self.add(total_memory - 0x00010000, 0x00010000, E820_ACPI_RECLAIM);
            } else {
                self.add(0x00100000, extended, E820_RAM);
            }
        }

        # Above 4GB if applicable
        if total_memory > 0x100000000 {
            let above_4g = total_memory - 0x100000000;
            self.add(0x100000000, above_4g, E820_RAM);
        }

        # PCI MMIO hole: 0xE0000000 - 0xFEFFFFFF
        self.add(0xE0000000, 0x1F000000, E820_RESERVED);

        # Local APIC/IOAPIC/HPET
        self.add(0xFEC00000, 0x00400000, E820_RESERVED);
    }

    fn write_to_guest(self, guest_mem, addr) {
        # Write entries count first
        guest_mem.write(addr, 4, len(self.entries));
        let pos = addr + 4;
        for entry in self.entries {
            # Each entry: base(8) + length(8) + type(4) = 20 bytes
            guest_mem.write(pos, 4, entry["base"] & 0xFFFFFFFF);
            guest_mem.write(pos + 4, 4, (entry["base"] >> 32) & 0xFFFFFFFF);
            guest_mem.write(pos + 8, 4, entry["length"] & 0xFFFFFFFF);
            guest_mem.write(pos + 12, 4, (entry["length"] >> 32) & 0xFFFFFFFF);
            guest_mem.write(pos + 16, 4, entry["type"]);
            pos = pos + 20;
        }
        return len(self.entries);
    }
}

# ===========================================
# VGA Text Mode Initialization
# ===========================================

class VGATextInit {
    fn init(self, guest_mem) {
        self.mem = guest_mem;
    }

    fn setup(self) {
        # Clear VGA text buffer to spaces with light gray on black
        let attr = 0x07;  # Light gray on black
        for i in 0..2000 {  # 80 x 25
            let offset = VGA_TEXT_BASE + (i * 2);
            self.mem.write(offset, 1, 0x20);      # Space character
            self.mem.write(offset + 1, 1, attr);   # Attribute
        }
    }

    fn write_string(self, row, col, text, attr) {
        let offset = VGA_TEXT_BASE + ((row * 80 + col) * 2);
        for i in 0..len(text) {
            self.mem.write(offset, 1, systems.char_to_int(text[i]));
            self.mem.write(offset + 1, 1, attr);
            offset = offset + 2;
        }
    }
}

# ===========================================
# BIOS Service Handlers (Real-Mode Stubs)
# ===========================================
# These are x86 machine code snippets placed in BIOS ROM
# that implement INT 10h, INT 13h, INT 15h, etc.

class BIOSServiceStubs {
    fn init(self, guest_mem) {
        self.mem = guest_mem;
    }

    fn install(self) {
        let base = BIOS_ROM_BASE;  # 0xF0000

        # IRET handler at the default vector location (0xFFF0 in segment)
        self.mem.write(base + 0xFFF0, 1, 0xCF);  # IRET

        # INT 10h — Video Services handler at offset 0x1000
        self.install_int10(base + 0x1000);

        # INT 11h — Equipment List at offset 0x1100
        self.install_int11(base + 0x1100);

        # INT 12h — Memory Size at offset 0x1200
        self.install_int12(base + 0x1200);

        # INT 13h — Disk Services at offset 0x1300
        self.install_int13(base + 0x1300);

        # INT 15h — System Services at offset 0x1500
        self.install_int15(base + 0x1500);

        # INT 16h — Keyboard Services at offset 0x1600
        self.install_int16(base + 0x1600);

        # INT 19h — Bootstrap at offset 0x1900
        self.install_int19(base + 0x1900);

        # INT 1Ah — Time/PCI BIOS at offset 0x1A00
        self.install_int1a(base + 0x1A00);

        # Reset vector at 0xFFFF0 (16 bytes before end of BIOS ROM)
        # JMP far 0xF000:0xE05B (typical BIOS entry)
        # EA 5B E0 00 F0
        self.mem.write(BIOS_ENTRY_POINT, 1, 0xEA);
        self.mem.write(BIOS_ENTRY_POINT + 1, 2, 0x0000);  # offset — start of POST
        self.mem.write(BIOS_ENTRY_POINT + 3, 2, 0xF000);  # segment

        # POST stub at 0xF0000 — minimal: set up stack, call INT 19h
        self.install_post(base);
    }

    fn install_int10(self, addr) {
        # Minimal INT 10h: handle AH=0Eh (teletype output) via VMCALL
        # We use VMCALL as a hypercall to the VMM for actual emulation
        let code = [
            0x80, 0xFC, 0x0E,    # CMP AH, 0x0E
            0x75, 0x04,          # JNE skip
            0x0F, 0x01, 0xC1,    # VMCALL (hypercall to VMM)
            0xCF,                # IRET
            # skip:
            0x0F, 0x01, 0xC1,    # VMCALL
            0xCF                 # IRET
        ];
        self.write_code(addr, code);
    }

    fn install_int11(self, addr) {
        # INT 11h: return equipment word from BDA
        let code = [
            0x1E,                # PUSH DS
            0xB8, 0x40, 0x00,    # MOV AX, 0x0040
            0x8E, 0xD8,          # MOV DS, AX
            0xA1, 0x10, 0x00,    # MOV AX, [0x0010] (equipment word)
            0x1F,                # POP DS
            0xCF                 # IRET
        ];
        self.write_code(addr, code);
    }

    fn install_int12(self, addr) {
        # INT 12h: return conventional memory size
        let code = [
            0x1E,                # PUSH DS
            0xB8, 0x40, 0x00,    # MOV AX, 0x0040
            0x8E, 0xD8,          # MOV DS, AX
            0xA1, 0x13, 0x00,    # MOV AX, [0x0013] (mem size KB)
            0x1F,                # POP DS
            0xCF                 # IRET
        ];
        self.write_code(addr, code);
    }

    fn install_int13(self, addr) {
        # INT 13h: Disk services — use VMCALL for all disk ops
        let code = [
            0x0F, 0x01, 0xC1,    # VMCALL
            0xCF                 # IRET
        ];
        self.write_code(addr, code);
    }

    fn install_int15(self, addr) {
        # INT 15h: System services
        # AX=E820h: memory map query → VMCALL
        # AH=88h: extended memory size → VMCALL
        # AH=C0: system config → VMCALL
        let code = [
            0x0F, 0x01, 0xC1,    # VMCALL
            0xCF                 # IRET
        ];
        self.write_code(addr, code);
    }

    fn install_int16(self, addr) {
        # INT 16h: Keyboard services → VMCALL
        let code = [
            0x0F, 0x01, 0xC1,    # VMCALL
            0xCF                 # IRET
        ];
        self.write_code(addr, code);
    }

    fn install_int19(self, addr) {
        # INT 19h: Bootstrap — load boot sector from first disk
        let code = [
            0x0F, 0x01, 0xC1,    # VMCALL (VMM handles boot sector load)
            0xCF                 # IRET
        ];
        self.write_code(addr, code);
    }

    fn install_int1a(self, addr) {
        # INT 1Ah: Time services + PCI BIOS
        # AH=00: read tick count
        # AH=B1: PCI BIOS (function in AL)
        let code = [
            0x0F, 0x01, 0xC1,    # VMCALL
            0xCF                 # IRET
        ];
        self.write_code(addr, code);
    }

    fn install_post(self, base) {
        # Power-On Self Test stub at segment:0000
        # Sets up real-mode stack, initializes segments, then INT 19h
        let code = [
            0xFA,                # CLI
            0x31, 0xC0,          # XOR AX, AX
            0x8E, 0xD0,          # MOV SS, AX
            0xBC, 0xFC, 0x7B,    # MOV SP, 0x7BFC (stack below 0x7C00)
            0x8E, 0xD8,          # MOV DS, AX
            0x8E, 0xC0,          # MOV ES, AX
            0xFB,                # STI
            0xCD, 0x19,          # INT 19h (bootstrap)
            0xF4,                # HLT
            0xEB, 0xFD           # JMP $-1 (loop on HLT)
        ];
        self.write_code(base, code);
    }

    fn write_code(self, addr, bytes) {
        for i in 0..len(bytes) {
            self.mem.write(addr + i, 1, bytes[i]);
        }
    }
}

# ===========================================
# SMBIOS (System Management BIOS)
# ===========================================

class SMBIOSBuilder {
    fn init(self, guest_mem) {
        self.mem = guest_mem;
    }

    fn build(self, config) {
        let w = self;
        let pos = SMBIOS_ENTRY_ADDR;

        # SMBIOS 3.0 Entry Point (64-bit)
        let anchor = [0x5F, 0x53, 0x4D, 0x33, 0x5F];  # "_SM3_"
        for i in 0..len(anchor) {
            self.mem.write(pos + i, 1, anchor[i]);
        }
        pos = pos + 5;
        self.mem.write(pos, 1, 0);        # Checksum (patch later)
        pos = pos + 1;
        self.mem.write(pos, 1, 24);       # Entry Point Length
        pos = pos + 1;
        self.mem.write(pos, 1, 3);        # SMBIOS Major Version
        pos = pos + 1;
        self.mem.write(pos, 1, 0);        # SMBIOS Minor Version
        pos = pos + 1;
        self.mem.write(pos, 1, 0);        # Docrev
        pos = pos + 1;
        self.mem.write(pos, 1, 0x01);     # Entry Point Revision
        pos = pos + 1;
        self.mem.write(pos, 1, 0);        # Reserved
        pos = pos + 1;

        # Structure Table Maximum Size (4 bytes)
        self.mem.write(pos, 4, 0x1000);
        pos = pos + 4;

        # Structure Table Address (8 bytes)
        let table_addr = SMBIOS_ENTRY_ADDR + 0x40;
        self.mem.write(pos, 4, table_addr & 0xFFFFFFFF);
        self.mem.write(pos + 4, 4, 0);
        pos = pos + 8;

        # Write SMBIOS structures
        self.write_type0(table_addr);          # BIOS Information
        self.write_type1(table_addr + 0x60);   # System Information
        self.write_type3(table_addr + 0xC0);   # Chassis
        self.write_type4(table_addr + 0x120, config.cpu_count);  # Processor
        self.write_type16(table_addr + 0x180);  # Physical Memory Array
        self.write_type17(table_addr + 0x1E0, config.memory_size);  # Memory Device
        self.write_type127(table_addr + 0x240); # End of Table
    }

    fn write_type0(self, addr) {
        # Type 0: BIOS Information
        self.mem.write(addr, 1, 0);          # Type
        self.mem.write(addr + 1, 1, 24);     # Length
        self.mem.write(addr + 2, 2, 0);      # Handle
        self.mem.write(addr + 4, 1, 1);      # Vendor string index
        self.mem.write(addr + 5, 1, 2);      # BIOS Version string index
        self.mem.write(addr + 6, 2, 0xF000); # BIOS Starting Segment
        self.mem.write(addr + 8, 1, 3);      # BIOS Release Date string index
        self.mem.write(addr + 9, 1, 0xFF);   # BIOS ROM Size (16MB)
        # Characteristics (8 bytes)
        self.mem.write(addr + 10, 4, 0x08);  # BIOS char supported
        self.mem.write(addr + 14, 4, 0);
        # Strings follow header
        let strings = "Nyx VM\x00" + "1.0.0\x00" + "01/01/2026\x00" + "\x00";
        self.write_string_at(addr + 24, strings);
    }

    fn write_type1(self, addr) {
        # Type 1: System Information
        self.mem.write(addr, 1, 1);          # Type
        self.mem.write(addr + 1, 1, 27);     # Length
        self.mem.write(addr + 2, 2, 1);      # Handle
        self.mem.write(addr + 4, 1, 1);      # Manufacturer string index
        self.mem.write(addr + 5, 1, 2);      # Product Name string index
        self.mem.write(addr + 6, 1, 3);      # Version string index
        self.mem.write(addr + 7, 1, 4);      # Serial Number string index
        # UUID (16 bytes) — random-looking but deterministic
        let uuid = [0x4E, 0x79, 0x78, 0x56, 0x4D, 0x00, 0x00, 0x01,
                     0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01];
        for i in 0..16 {
            self.mem.write(addr + 8 + i, 1, uuid[i]);
        }
        self.mem.write(addr + 24, 1, 0x01);  # Wake-up Type
        self.mem.write(addr + 25, 1, 5);     # SKU Number
        self.mem.write(addr + 26, 1, 6);     # Family
        let strings = "Nyx\x00" + "Nyx Virtual Machine\x00" + "1.0\x00" + "NYX-00001\x00" + "Standard\x00" + "Virtual\x00" + "\x00";
        self.write_string_at(addr + 27, strings);
    }

    fn write_type3(self, addr) {
        # Type 3: System Enclosure
        self.mem.write(addr, 1, 3);
        self.mem.write(addr + 1, 1, 21);
        self.mem.write(addr + 2, 2, 2);
        self.mem.write(addr + 4, 1, 1);     # Manufacturer
        self.mem.write(addr + 5, 1, 0x01);  # Type: Other
        let strings = "Nyx\x00\x00";
        self.write_string_at(addr + 21, strings);
    }

    fn write_type4(self, addr, num_cpus) {
        # Type 4: Processor Information
        self.mem.write(addr, 1, 4);
        self.mem.write(addr + 1, 1, 42);
        self.mem.write(addr + 2, 2, 3);
        self.mem.write(addr + 4, 1, 1);     # Socket Designation
        self.mem.write(addr + 5, 1, 0x03);  # Processor Type: Central
        self.mem.write(addr + 6, 1, 0x02);  # Processor Family
        self.mem.write(addr + 7, 1, 2);     # Manufacturer string index
        # Processor ID (8 bytes)
        self.mem.write(addr + 8, 4, 0x00000000);
        self.mem.write(addr + 12, 4, 0x00000000);
        self.mem.write(addr + 16, 1, 3);    # Version string index
        self.mem.write(addr + 17, 1, 0x00); # Voltage
        self.mem.write(addr + 18, 2, 0);    # External Clock
        self.mem.write(addr + 20, 2, 3000); # Max Speed (MHz)
        self.mem.write(addr + 22, 2, 3000); # Current Speed
        self.mem.write(addr + 24, 1, 0x41); # Status: Populated, Enabled
        self.mem.write(addr + 25, 1, 0x03); # Upgrade
        # L1/L2/L3 cache handles
        self.mem.write(addr + 26, 2, 0xFFFF);
        self.mem.write(addr + 28, 2, 0xFFFF);
        self.mem.write(addr + 30, 2, 0xFFFF);
        self.mem.write(addr + 32, 1, 0);    # Serial
        self.mem.write(addr + 33, 1, 0);    # Asset Tag
        self.mem.write(addr + 34, 1, 0);    # Part Number
        self.mem.write(addr + 35, 1, num_cpus); # Core Count
        self.mem.write(addr + 36, 1, num_cpus); # Core Enabled
        self.mem.write(addr + 37, 1, num_cpus); # Thread Count
        self.mem.write(addr + 38, 2, 0x00FC); # Characteristics (64-bit, multi-core)
        self.mem.write(addr + 40, 2, 0x02);   # Family 2
        let strings = "CPU0\x00" + "Nyx\x00" + "Nyx vCPU\x00\x00";
        self.write_string_at(addr + 42, strings);
    }

    fn write_type16(self, addr) {
        # Type 16: Physical Memory Array
        self.mem.write(addr, 1, 16);
        self.mem.write(addr + 1, 1, 15);
        self.mem.write(addr + 2, 2, 4);
        self.mem.write(addr + 4, 1, 0x03);  # Location: System Board
        self.mem.write(addr + 5, 1, 0x03);  # Use: System Memory
        self.mem.write(addr + 6, 1, 0x06);  # Error Correction: Multi-bit ECC
        self.mem.write(addr + 7, 4, 0x80000000);  # Max Capacity (use extended)
        self.mem.write(addr + 11, 2, 0xFFFE);     # Error Info Handle
        self.mem.write(addr + 13, 2, 1);           # Num Memory Devices
        # Strings
        self.write_string_at(addr + 15, "\x00");
    }

    fn write_type17(self, addr, memory_size) {
        # Type 17: Memory Device
        self.mem.write(addr, 1, 17);
        self.mem.write(addr + 1, 1, 40);
        self.mem.write(addr + 2, 2, 5);
        self.mem.write(addr + 4, 2, 4);     # Physical Memory Array Handle
        self.mem.write(addr + 6, 2, 0xFFFE); # Error Info Handle
        self.mem.write(addr + 8, 2, 64);     # Total Width (bits)
        self.mem.write(addr + 10, 2, 64);    # Data Width
        let size_mb = memory_size / (1024 * 1024);
        if size_mb <= 0x7FFF {
            self.mem.write(addr + 12, 2, size_mb);  # Size in MB
        } else {
            self.mem.write(addr + 12, 2, 0x7FFF);   # Use extended size
        }
        self.mem.write(addr + 14, 1, 0x09);  # Form Factor: DIMM
        self.mem.write(addr + 15, 1, 0);     # Device Set
        self.mem.write(addr + 16, 1, 1);     # Device Locator string
        self.mem.write(addr + 17, 1, 2);     # Bank Locator string
        self.mem.write(addr + 18, 1, 0x1A);  # Memory Type: DDR4
        self.mem.write(addr + 19, 2, 0);     # Type Detail
        self.mem.write(addr + 21, 2, 2666);  # Speed (MT/s)
        self.mem.write(addr + 23, 1, 3);     # Manufacturer
        self.mem.write(addr + 24, 1, 0);     # Serial
        self.mem.write(addr + 25, 1, 0);     # Asset Tag
        self.mem.write(addr + 26, 1, 0);     # Part Number
        # Extended Size (for > 32GB)
        if size_mb > 0x7FFF {
            self.mem.write(addr + 28, 4, size_mb);
        }
        let strings = "DIMM 0\x00" + "Bank 0\x00" + "Nyx\x00\x00";
        self.write_string_at(addr + 40, strings);
    }

    fn write_type127(self, addr) {
        # End-of-Table
        self.mem.write(addr, 1, 127);
        self.mem.write(addr + 1, 1, 4);
        self.mem.write(addr + 2, 2, 0xFFFF);
        self.mem.write(addr + 4, 1, 0);   # Double null terminator
        self.mem.write(addr + 5, 1, 0);
    }

    fn write_string_at(self, addr, s) {
        for i in 0..len(s) {
            self.mem.write(addr + i, 1, systems.char_to_int(s[i]));
        }
    }
}

# ===========================================
# MP Table (MultiProcessor Specification)
# ===========================================

class MPTableBuilder {
    fn init(self, guest_mem) {
        self.mem = guest_mem;
    }

    fn build(self, num_cpus) {
        let pos = MP_TABLE_ADDR;

        # MP Floating Pointer Structure (16 bytes)
        # Signature "_MP_"
        self.mem.write(pos, 1, 0x5F);     # _
        self.mem.write(pos + 1, 1, 0x4D); # M
        self.mem.write(pos + 2, 1, 0x50); # P
        self.mem.write(pos + 3, 1, 0x5F); # _

        let config_addr = pos + 16;
        self.mem.write(pos + 4, 4, config_addr);  # Physical Address of MP Config Table
        self.mem.write(pos + 8, 1, 1);             # Length (in 16-byte units)
        self.mem.write(pos + 9, 1, 4);             # Spec Revision (1.4)
        self.mem.write(pos + 10, 1, 0);            # Checksum (patched later)
        self.mem.write(pos + 11, 1, 0);            # Features byte 1
        self.mem.write(pos + 12, 4, 0);            # Features bytes 2-5

        # Patch floating pointer checksum
        let sum = 0;
        for i in 0..16 {
            sum = sum + self.mem.read(pos + i, 1);
        }
        self.mem.write(pos + 10, 1, (256 - (sum & 0xFF)) & 0xFF);

        # MP Configuration Table Header
        pos = config_addr;
        # Signature "PCMP"
        self.mem.write(pos, 1, 0x50);
        self.mem.write(pos + 1, 1, 0x43);
        self.mem.write(pos + 2, 1, 0x4D);
        self.mem.write(pos + 3, 1, 0x50);

        let entry_count = num_cpus + 1 + 1;  # CPUs + 1 IOAPIC + 1 Bus
        let base_length = 44 + (num_cpus * 20) + 8 + 8;  # header + cpu entries + bus + ioapic
        self.mem.write(pos + 4, 2, base_length);
        self.mem.write(pos + 6, 1, 4);       # Spec Revision
        self.mem.write(pos + 7, 1, 0);       # Checksum (patched later)
        # OEM ID (8 bytes)
        let oem = "NYX     ";
        for i in 0..8 {
            self.mem.write(pos + 8 + i, 1, systems.char_to_int(oem[i]));
        }
        # Product ID (12 bytes)
        let prod = "NYXVM       ";
        for i in 0..12 {
            self.mem.write(pos + 16 + i, 1, systems.char_to_int(prod[i]));
        }
        self.mem.write(pos + 28, 4, 0);    # OEM Table Pointer
        self.mem.write(pos + 32, 2, 0);    # OEM Table Size
        self.mem.write(pos + 34, 2, entry_count);
        self.mem.write(pos + 36, 4, 0xFEE00000);  # LAPIC Address
        self.mem.write(pos + 40, 2, 0);    # Extended Table Length
        self.mem.write(pos + 42, 1, 0);    # Extended Table Checksum
        self.mem.write(pos + 43, 1, 0);    # Reserved

        pos = config_addr + 44;

        # Processor entries (type 0, 20 bytes each)
        for i in 0..num_cpus {
            self.mem.write(pos, 1, 0);           # Entry Type: Processor
            self.mem.write(pos + 1, 1, i);       # Local APIC ID
            self.mem.write(pos + 2, 1, 0x14);    # Local APIC Version
            let cpu_flags = 0x01;                # Enabled
            if i == 0 { cpu_flags = cpu_flags | 0x02; }  # BSP
            self.mem.write(pos + 3, 1, cpu_flags);
            self.mem.write(pos + 4, 4, 0);       # CPU Signature
            self.mem.write(pos + 8, 4, 0);       # Feature Flags
            self.mem.write(pos + 12, 4, 0);      # Reserved
            self.mem.write(pos + 16, 4, 0);      # Reserved
            pos = pos + 20;
        }

        # Bus entry (type 1, 8 bytes)
        self.mem.write(pos, 1, 1);       # Entry Type: Bus
        self.mem.write(pos + 1, 1, 0);   # Bus ID
        let bus_type = "PCI   ";
        for i in 0..6 {
            self.mem.write(pos + 2 + i, 1, systems.char_to_int(bus_type[i]));
        }
        pos = pos + 8;

        # I/O APIC entry (type 2, 8 bytes)
        self.mem.write(pos, 1, 2);            # Entry Type: I/O APIC
        self.mem.write(pos + 1, 1, num_cpus); # I/O APIC ID
        self.mem.write(pos + 2, 1, 0x11);     # I/O APIC Version
        self.mem.write(pos + 3, 1, 0x01);     # Enabled
        self.mem.write(pos + 4, 4, 0xFEC00000); # Address
        pos = pos + 8;

        # Patch config table checksum
        sum = 0;
        for i in 0..base_length {
            sum = sum + self.mem.read(config_addr + i, 1);
        }
        self.mem.write(config_addr + 7, 1, (256 - (sum & 0xFF)) & 0xFF);
    }
}

# ===========================================
# Master Legacy BIOS Boot Setup
# ===========================================

class LegacyBIOSSetup {
    fn init(self, guest_mem, config) {
        self.mem = guest_mem;
        self.config = config;
    }

    fn setup(self) {
        # 1. Zero out low memory
        for i in 0..0x1000 {
            self.mem.write(i, 1, 0);
        }

        # 2. Set up IVT
        let ivt = IVTSetup(self.mem);
        ivt.setup(0xF000);

        # 3. Set up BDA
        let bda = BIOSDataArea(self.mem);
        bda.setup(self.config);

        # 4. VGA text mode init
        let vga = VGATextInit(self.mem);
        vga.setup();
        vga.write_string(0, 0, "Nyx VM BIOS v1.0", 0x1F);  # White on blue

        # 5. Install BIOS service stubs
        let stubs = BIOSServiceStubs(self.mem);
        stubs.install();

        # 6. Build E820 memory map
        let e820 = E820MemoryMap();
        e820.build_standard(self.config.memory_size);
        e820.write_to_guest(self.mem, E820_TABLE_ADDR);

        # 7. SMBIOS
        let smbios = SMBIOSBuilder(self.mem);
        smbios.build(self.config);

        # 8. MP Table (for SMP boot)
        let mp = MPTableBuilder(self.mem);
        mp.build(self.config.cpu_count);

        return {
            "e820_addr": E820_TABLE_ADDR,
            "smbios_addr": SMBIOS_ENTRY_ADDR,
            "mp_table_addr": MP_TABLE_ADDR,
            "entry_point": BIOS_ENTRY_POINT
        };
    }
}
