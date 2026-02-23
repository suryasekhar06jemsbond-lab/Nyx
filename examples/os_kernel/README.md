# Nyx OS Kernel Example

A complete operating system kernel written entirely in **Nyx**!

## Features

✅ **Bootloader Integration** — Multiboot2 compatible (GRUB)  
✅ **VGA Text Mode** — 80x25 color text output  
✅ **GDT & IDT** — Proper x86-64 descriptor tables  
✅ **Exception Handling** — Division by zero, page faults, etc.  
✅ **Hardware Interrupts** — Timer (PIT), Keyboard (PS/2)  
✅ **Memory Management** — Simple heap allocator  
✅ **Keyboard Driver** — Read keyboard input  
✅ **Timer** — 100 Hz system timer with uptime counter  

## Building

### Prerequisites
- Nyx compiler
- QEMU (for testing)
- GRUB (for bootloader)

### Compile Kernel
```bash
# Compile kernel to ELF binary
nyx build kernel_main.ny \
    --target x86_64-unknown-none \
    --no-std \
    --opt-level 3 \
    --linker-script kernel.ld \
    --output nyx_kernel.elf
```

### Create Bootable ISO
```bash
# Create GRUB boot directory
mkdir -p iso/boot/grub

# Copy kernel
cp nyx_kernel.elf iso/boot/

# Create GRUB config
cat > iso/boot/grub/grub.cfg << EOF
set timeout=0
set default=0

menuentry "Nyx OS" {
    multiboot2 /boot/nyx_kernel.elf
    boot
}
EOF

# Generate ISO
grub-mkrescue -o nyx_os.iso iso/
```

### Run in QEMU
```bash
qemu-system-x86_64 -cdrom nyx_os.iso -m 512M
```

## Kernel Structure

```
kernel_main.ny
├── Multiboot2 Header         # Bootloader magic
├── _start()                   # Kernel entry point
├── VGA Driver                 # Text mode output
├── GDT Setup                  # Segmentation
├── IDT Setup                  # Interrupts
├── Exception Handlers         # Fault handling
├── IRQ Handlers              # Timer, keyboard
├── PIC Initialization        # Interrupt controller
├── Paging Setup              # Virtual memory
├── Heap Allocator            # Dynamic memory
└── kernel_main()             # Main kernel loop
```

## What Happens When You Boot

1. **GRUB loads the kernel** at 1MB physical memory
2. **Multiboot2 header verified** (magic: 0x36D76289)
3. **BSS section cleared** (uninitialized data)
4. **VGA initialized** (80x25 text mode at 0xB8000)
5. **GDT loaded** (64-bit code/data segments)
6. **IDT setup** (256 interrupt vectors)
7. **Paging enabled** (4-level page tables)
8. **Heap allocator ready** (4MB heap at 2MB)
9. **PIC remapped** (IRQ 0-15 → INT 32-47)
10. **Interrupts enabled** (`sti` instruction)
11. **Keyboard driver active** (IRQ1)
12. **Timer running** (100 Hz, IRQ0)
13. **Kernel main loop** — halts CPU until interrupts

## Testing the Kernel

### 1. Check VGA Output
You should see:
```
Nyx OS Kernel Booting...
[OK] GDT initialized
[OK] IDT initialized
[OK] Paging enabled
[OK] Heap allocator ready
[OK] PIC initialized
[OK] Interrupts enabled
[OK] Keyboard driver loaded
[OK] Timer initialized (100Hz)

========================================
  Welcome to Nyx OS v1.0
  A kernel written entirely in Nyx!
========================================

Kernel is running...

Type on your keyboard to see input!
(Keyboard driver is active)
```

### 2. Type on Keyboard
- Press any key
- You'll see: `> <key>`
- Example: Press 'a' → Output: `> a`

### 3. Watch Uptime Counter
- Top-right corner shows: `Uptime: XXs`
- Updates every second

## Adding Features

### Add a System Call Interface
```nyx
#[no_mangle]
extern "C" fn syscall_handler(
    syscall_num: u64,
    arg1: u64, arg2: u64, arg3: u64
) -> u64 {
    match syscall_num {
        1 => sys_write(arg1, arg2 as *u8, arg3),
        2 => sys_read(arg1, arg2 as *mut u8, arg3),
        _ => -1 as u64
    }
}
```

### Add Process Scheduler
```nyx
struct Process {
    pid: u32,
    stack_ptr: u64,
    state: ProcessState
}

fn schedule() {
    let next = scheduler.get_next_process()
    context_switch(current_process, next)
}
```

### Add File System
```nyx
struct FileSystem {
    root: *mut INode
}

fn read_file(path: &str) -> Vec<u8> {
    let inode = fs.lookup(path)
    return inode.read()
}
```

## Debugging

### Debug with GDB
```bash
# Run QEMU with GDB server
qemu-system-x86_64 -cdrom nyx_os.iso -s -S

# In another terminal
gdb nyx_kernel.elf
(gdb) target remote :1234
(gdb) break kernel_main
(gdb) continue
```

### View Serial Output
```bash
# Add serial port to QEMU
qemu-system-x86_64 -cdrom nyx_os.iso -serial stdio

# In kernel, write to COM1:
fn serial_print(s: &str) {
    for c in s.chars() {
        while (inb(0x3FD) & 0x20) == 0 {}  # Wait for ready
        outb(0x3F8, c as u8)               # Write byte
    }
}
```

## Next Steps

1. **Add more drivers**: PCI, AHCI, NVMe, USB
2. **Implement virtual memory**: Page allocator, heap manager
3. **Add multitasking**: Process scheduler, context switching
4. **Create user-space**: System calls, ELF loader
5. **Build file system**: ext2, FAT32, or custom FS
6. **Network stack**: TCP/IP, sockets, drivers
7. **GUI**: Framebuffer, window manager

## License

This kernel example is part of the Nyx project.  
Use it to learn OS development in Nyx!

---

**You just built an OS kernel in Nyx!** 🎉🚀
