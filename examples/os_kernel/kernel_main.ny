# ╔══════════════════════════════════════════════════════════════════╗
# ║                      NYX OS KERNEL EXAMPLE                       ║
# ║          Complete Operating System Kernel Written in Nyx         ║
# ╚══════════════════════════════════════════════════════════════════╝

# COMPILATION:
# nyx build kernel_main.ny --target x86_64-unknown-none --no-std -o nyx_kernel.elf

#[no_std]
#[memory_model = "manual"]

import nysystem.memory as mem
import nysystem.interrupts as irq
import nysystem.asm as asm

# ═══════════════════════════════════════════════════════════════════
# SECTION 1: MULTIBOOT2 HEADER (Required by GRUB bootloader)
# ═══════════════════════════════════════════════════════════════════

#[section = ".multiboot"]
#[align = 8]
static MULTIBOOT2_HEADER: [u32; 8] = [
    0xE85250D6,                        # Magic number
    0,                                  # Architecture: i386 (0)
    32,                                 # Header length
    0 - (0xE85250D6 + 0 + 32),        # Checksum
    # End tag
    0, 0, 8, 0
]

# ═══════════════════════════════════════════════════════════════════
# SECTION 2: KERNEL ENTRY POINT
# ═══════════════════════════════════════════════════════════════════

static mut KERNEL_BOOT_INFO: *mut u8 = null

#[no_mangle]
#[link_section = ".text.boot"]
pub extern "C" fn _start(magic: u32, boot_info: *mut u8) -> ! {
    # Verify multiboot2 magic
    if magic != 0x36D76289 {
        halt_forever()
    }
    
    unsafe {
        KERNEL_BOOT_INFO = boot_info
        
        # Clear BSS section
        clear_bss()
        
        # Initialize VGA text mode
        init_vga()
        
        # Print boot message
        vga_print("Nyx OS Kernel Booting...\n")
        
        # Setup GDT (Global Descriptor Table)
        setup_gdt()
        vga_print("[OK] GDT initialized\n")
        
        # Setup IDT (Interrupt Descriptor Table)
        setup_idt()
        vga_print("[OK] IDT initialized\n")
        
        # Setup paging (4-level)
        setup_paging()
        vga_print("[OK] Paging enabled\n")
        
        # Initialize heap allocator
        init_heap()
        vga_print("[OK] Heap allocator ready\n")
        
        # Initialize PIC (Programmable Interrupt Controller)
        init_pic()
        vga_print("[OK] PIC initialized\n")
        
        # Enable interrupts
        enable_interrupts()
        vga_print("[OK] Interrupts enabled\n")
        
        # Initialize keyboard driver
        init_keyboard()
        vga_print("[OK] Keyboard driver loaded\n")
        
        # Initialize timer (PIT)
        init_timer(frequency: 100)  # 100 Hz
        vga_print("[OK] Timer initialized (100Hz)\n")
        
        # Jump to kernel main
        vga_print("\n========================================\n")
        vga_print("  Welcome to Nyx OS v1.0\n")
        vga_print("  A kernel written entirely in Nyx!\n")
        vga_print("========================================\n\n")
        
        kernel_main()
    }
}

fn clear_bss() {
    extern "C" {
        static mut __bss_start: u8
        static mut __bss_end: u8
    }
    
    unsafe {
        let start = &mut __bss_start as *mut u8
        let end = &mut __bss_end as *mut u8
        let size = end as usize - start as usize
        
        mem.set(start, 0, size)
    }
}

fn halt_forever() -> ! {
    loop {
        unsafe {
            asm! { "cli; hlt" }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 3: VGA TEXT MODE DRIVER (80x25, 16 colors)
# ═══════════════════════════════════════════════════════════════════

const VGA_BUFFER: *mut u8 = 0xB8000 as *mut u8
const VGA_WIDTH: usize = 80
const VGA_HEIGHT: usize = 25
static mut VGA_X: usize = 0
static mut VGA_Y: usize = 0

enum VGAColor {
    Black = 0, Blue = 1, Green = 2, Cyan = 3,
    Red = 4, Magenta = 5, Brown = 6, LightGray = 7,
    DarkGray = 8, LightBlue = 9, LightGreen = 10, LightCyan = 11,
    LightRed = 12, Pink = 13, Yellow = 14, White = 15
}

fn init_vga() {
    unsafe {
        # Clear screen
        for i in 0..(VGA_WIDTH * VGA_HEIGHT) {
            let offset = i * 2
            *(VGA_BUFFER + offset) = ' ' as u8
            *(VGA_BUFFER + offset + 1) = vga_color(VGAColor.White, VGAColor.Black)
        }
        VGA_X = 0
        VGA_Y = 0
    }
}

fn vga_color(fg: VGAColor, bg: VGAColor) -> u8 {
    return (bg as u8) << 4 | (fg as u8)
}

fn vga_print(s: &str) {
    for c in s.chars() {
        vga_putchar(c)
    }
}

fn vga_putchar(c: char) {
    unsafe {
        if c == '\n' {
            VGA_X = 0
            VGA_Y += 1
        } else {
            let offset = (VGA_Y * VGA_WIDTH + VGA_X) * 2
            *(VGA_BUFFER + offset) = c as u8
            *(VGA_BUFFER + offset + 1) = vga_color(VGAColor.LightGreen, VGAColor.Black)
            
            VGA_X += 1
            if VGA_X >= VGA_WIDTH {
                VGA_X = 0
                VGA_Y += 1
            }
        }
        
        # Scroll if needed
        if VGA_Y >= VGA_HEIGHT {
            vga_scroll()
            VGA_Y = VGA_HEIGHT - 1
        }
    }
}

fn vga_scroll() {
    unsafe {
        # Copy all lines up by one
        for y in 1..VGA_HEIGHT {
            for x in 0..VGA_WIDTH {
                let src = (y * VGA_WIDTH + x) * 2
                let dst = ((y - 1) * VGA_WIDTH + x) * 2
                *(VGA_BUFFER + dst) = *(VGA_BUFFER + src)
                *(VGA_BUFFER + dst + 1) = *(VGA_BUFFER + src + 1)
            }
        }
        
        # Clear last line
        for x in 0..VGA_WIDTH {
            let offset = ((VGA_HEIGHT - 1) * VGA_WIDTH + x) * 2
            *(VGA_BUFFER + offset) = ' ' as u8
            *(VGA_BUFFER + offset + 1) = vga_color(VGAColor.White, VGAColor.Black)
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 4: GDT (Global Descriptor Table)
# ═══════════════════════════════════════════════════════════════════

#[repr(C, packed)]
struct GDTPointer {
    limit: u16,
    base: u64
}

#[repr(C, align(16))]
static mut GDT: [u64; 5] = [
    0x0000000000000000,  # Null descriptor
    0x00AF9A000000FFFF,  # Code segment (64-bit, kernel)
    0x00CF92000000FFFF,  # Data segment (kernel)
    0x00AFFA000000FFFF,  # Code segment (64-bit, user)
    0x00CFF2000000FFFF   # Data segment (user)
]

fn setup_gdt() {
    unsafe {
        let gdt_ptr = GDTPointer {
            limit: (GDT.len() * 8 - 1) as u16,
            base: &GDT[0] as *u64 as u64
        }
        
        asm! {
            "lgdt [{}]"
            :
            : "r"(&gdt_ptr)
            : "memory"
        }
        
        # Reload segment registers
        asm! {
            "mov ax, 0x10"    # Data segment selector
            "mov ds, ax"
            "mov es, ax"
            "mov fs, ax"
            "mov gs, ax"
            "mov ss, ax"
            :
            :
            : "ax"
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 5: IDT (Interrupt Descriptor Table)
# ═══════════════════════════════════════════════════════════════════

#[repr(C, packed)]
struct IDTEntry {
    offset_low: u16,
    selector: u16,
    ist: u8,
    flags: u8,
    offset_mid: u16,
    offset_high: u32,
    zero: u32
}

#[repr(C, packed)]
struct IDTPointer {
    limit: u16,
    base: u64
}

static mut IDT: [IDTEntry; 256] = [IDTEntry {
    offset_low: 0, selector: 0, ist: 0, flags: 0,
    offset_mid: 0, offset_high: 0, zero: 0
}; 256]

fn setup_idt() {
    unsafe {
        # Exception handlers (0-31)
        idt_set_gate(0, exception_divide_error as u64, 0x08, 0x8E)
        idt_set_gate(1, exception_debug as u64, 0x08, 0x8E)
        idt_set_gate(3, exception_breakpoint as u64, 0x08, 0x8E)
        idt_set_gate(8, exception_double_fault as u64, 0x08, 0x8E)
        idt_set_gate(13, exception_general_protection as u64, 0x08, 0x8E)
        idt_set_gate(14, exception_page_fault as u64, 0x08, 0x8E)
        
        # IRQ handlers (32-47)
        idt_set_gate(32, irq_timer as u64, 0x08, 0x8E)      # IRQ0: Timer
        idt_set_gate(33, irq_keyboard as u64, 0x08, 0x8E)   # IRQ1: Keyboard
        
        # Load IDT
        let idt_ptr = IDTPointer {
            limit: (IDT.len() * 16 - 1) as u16,
            base: &IDT[0] as *IDTEntry as u64
        }
        
        asm! {
            "lidt [{}]"
            :
            : "r"(&idt_ptr)
            : "memory"
        }
    }
}

fn idt_set_gate(num: u8, handler: u64, selector: u16, flags: u8) {
    unsafe {
        IDT[num as usize].offset_low = (handler & 0xFFFF) as u16
        IDT[num as usize].selector = selector
        IDT[num as usize].ist = 0
        IDT[num as usize].flags = flags
        IDT[num as usize].offset_mid = ((handler >> 16) & 0xFFFF) as u16
        IDT[num as usize].offset_high = ((handler >> 32) & 0xFFFFFFFF) as u32
        IDT[num as usize].zero = 0
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 6: EXCEPTION HANDLERS
# ═══════════════════════════════════════════════════════════════════

#[no_mangle]
extern "C" fn exception_divide_error() {
    vga_print("\n[EXCEPTION] Divide by zero!\n")
    halt_forever()
}

#[no_mangle]
extern "C" fn exception_debug() {
    vga_print("\n[EXCEPTION] Debug\n")
}

#[no_mangle]
extern "C" fn exception_breakpoint() {
    vga_print("\n[EXCEPTION] Breakpoint\n")
}

#[no_mangle]
extern "C" fn exception_double_fault() {
    vga_print("\n[EXCEPTION] Double fault! System halted.\n")
    halt_forever()
}

#[no_mangle]
extern "C" fn exception_general_protection() {
    vga_print("\n[EXCEPTION] General protection fault!\n")
    halt_forever()
}

#[no_mangle]
extern "C" fn exception_page_fault() {
    let fault_addr: u64
    unsafe {
        asm! {
            "mov {}, cr2"
            : "=r"(fault_addr)
            :
            :
        }
    }
    vga_print("\n[EXCEPTION] Page fault at address: ")
    vga_print_hex(fault_addr)
    vga_print("\n")
    halt_forever()
}

fn vga_print_hex(value: u64) {
    let hex_chars = "0123456789ABCDEF"
    vga_print("0x")
    for i in (0..16).rev() {
        let digit = ((value >> (i * 4)) & 0xF) as usize
        vga_putchar(hex_chars.chars().nth(digit).unwrap())
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 7: IRQ HANDLERS
# ═══════════════════════════════════════════════════════════════════

static mut TIMER_TICKS: u64 = 0

#[no_mangle]
extern "C" fn irq_timer() {
    unsafe {
        TIMER_TICKS += 1
        
        # Send EOI to PIC
        outb(0x20, 0x20)
    }
}

static mut KEYBOARD_BUFFER: [u8; 256] = [0; 256]
static mut KEYBOARD_HEAD: usize = 0

#[no_mangle]
extern "C" fn irq_keyboard() {
    unsafe {
        let scancode = inb(0x60)
        
        # Store in buffer
        KEYBOARD_BUFFER[KEYBOARD_HEAD] = scancode
        KEYBOARD_HEAD = (KEYBOARD_HEAD + 1) % 256
        
        # Handle key press
        handle_keyboard(scancode)
        
        # Send EOI
        outb(0x20, 0x20)
    }
}

fn handle_keyboard(scancode: u8) {
    # Simple scancode to ASCII mapping (US keyboard)
    let ascii_map = [
        0, 27, '1', '2', '3', '4', '5', '6', '7', '8', '9', '0', '-', '=', 8,
        '\t', 'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p', '[', ']', '\n',
        0, 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', '\'', '`',
        0, '\\', 'z', 'x', 'c', 'v', 'b', 'n', 'm', ',', '.', '/', 0, '*',
        0, ' '
    ]
    
    if scancode < ascii_map.len() as u8 {
        let c = ascii_map[scancode as usize]
        if c != 0 {
            vga_print("> ")
            vga_putchar(c as char)
            vga_putchar('\n')
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 8: HARDWARE I/O
# ═══════════════════════════════════════════════════════════════════

fn outb(port: u16, value: u8) {
    unsafe {
        asm! {
            "out dx, al"
            :
            : "{dx}"(port), "{al}"(value)
            :
        }
    }
}

fn inb(port: u16) -> u8 {
    let value: u8
    unsafe {
        asm! {
            "in al, dx"
            : "={al}"(value)
            : "{dx}"(port)
            :
        }
    }
    return value
}

fn enable_interrupts() {
    unsafe {
        asm! { "sti" }
    }
}

fn disable_interrupts() {
    unsafe {
        asm! { "cli" }
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 9: PIC (Programmable Interrupt Controller)
# ═══════════════════════════════════════════════════════════════════

fn init_pic() {
    unsafe {
        # Remap PIC (IRQ 0-15 → INT 32-47)
        outb(0x20, 0x11)  # ICW1: Initialize
        outb(0xA0, 0x11)
        
        outb(0x21, 0x20)  # ICW2: Master offset (32)
        outb(0xA1, 0x28)  # ICW2: Slave offset (40)
        
        outb(0x21, 0x04)  # ICW3: Master has slave at IRQ2
        outb(0xA1, 0x02)  # ICW3: Slave ID
        
        outb(0x21, 0x01)  # ICW4: 8086 mode
        outb(0xA1, 0x01)
        
        # Unmask IRQ0 (timer) and IRQ1 (keyboard)
        outb(0x21, 0xFC)  # Master: 11111100
        outb(0xA1, 0xFF)  # Slave: 11111111
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 10: TIMER (PIT - Programmable Interval Timer)
# ═══════════════════════════════════════════════════════════════════

fn init_timer(frequency: u32) {
    let divisor = 1193180 / frequency
    
    unsafe {
        outb(0x43, 0x36)  # Channel 0, mode 3, binary
        outb(0x40, (divisor & 0xFF) as u8)
        outb(0x40, ((divisor >> 8) & 0xFF) as u8)
    }
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 11: PAGING (4-Level Page Tables)
# ═══════════════════════════════════════════════════════════════════

fn setup_paging() {
    # For simplicity, we assume bootloader already set up paging
    # In a real kernel, you would:
    # 1. Allocate P4, P3, P2, P1 tables
    # 2. Identity map first 2MB (kernel code)
    # 3. Map higher-half kernel (0xFFFFFFFF80000000)
    # 4. Load CR3 with P4 address
    # 5. Enable paging in CR0
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 12: HEAP ALLOCATOR (Simple bump allocator)
# ═══════════════════════════════════════════════════════════════════

const HEAP_START: usize = 0x200000  # 2MB
const HEAP_SIZE: usize = 0x400000   # 4MB
static mut HEAP_NEXT: usize = HEAP_START

fn init_heap() {
    unsafe {
        HEAP_NEXT = HEAP_START
    }
}

pub fn kmalloc(size: usize) -> *mut u8 {
    unsafe {
        let ptr = HEAP_NEXT as *mut u8
        HEAP_NEXT += size
        
        if HEAP_NEXT > HEAP_START + HEAP_SIZE {
            vga_print("\n[PANIC] Out of heap memory!\n")
            halt_forever()
        }
        
        return ptr
    }
}

fn init_keyboard() {
    # Keyboard already initialized by BIOS/bootloader
}

# ═══════════════════════════════════════════════════════════════════
# SECTION 13: KERNEL MAIN
# ═══════════════════════════════════════════════════════════════════

fn kernel_main() -> ! {
    vga_print("Kernel is running...\n\n")
    vga_print("Type on your keyboard to see input!\n")
    vga_print("(Keyboard driver is active)\n\n")
    
    # Main kernel loop
    loop {
        unsafe {
            # Display timer ticks every second
            if TIMER_TICKS % 100 == 0 {
                let old_x = VGA_X
                let old_y = VGA_Y
                
                # Print uptime in top-right corner
                VGA_X = VGA_WIDTH - 15
                VGA_Y = 0
                vga_print("Uptime: ")
                vga_print_dec(TIMER_TICKS / 100)
                vga_print("s")
                
                VGA_X = old_x
                VGA_Y = old_y
            }
            
            # Halt CPU until next interrupt
            asm! { "hlt" }
        }
    }
}

fn vga_print_dec(value: u64) {
    if value == 0 {
        vga_putchar('0')
        return
    }
    
    let mut num = value
    let mut buffer: [char; 20] = ['0'; 20]
    let mut i = 0
    
    while num > 0 {
        buffer[i] = ((num % 10) as u8 + '0' as u8) as char
        num /= 10
        i += 1
    }
    
    # Print in reverse
    for j in (0..i).rev() {
        vga_putchar(buffer[j])
    }
}

# ═══════════════════════════════════════════════════════════════════
# END OF KERNEL
# ═══════════════════════════════════════════════════════════════════
