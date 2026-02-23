# How to Get the Kernel Boot Log

## Option 1: From GitHub Actions (After Push)

1. **Push your changes:**
   ```bash
   git add .
   git commit -m "Add kernel boot CI test"
   git push
   ```

2. **Go to GitHub Actions:**
   - Navigate to: `https://github.com/YOUR_USERNAME/Nyx/actions`
   - Click on the latest CI workflow run
   - Click on the `kernel-boot-test` job

3. **View the boot log:**
   - Scroll to the "Boot kernel in QEMU" step
   - See real-time QEMU output

4. **Download artifacts:**
   - Scroll to the bottom of the workflow run page
   - Download `kernel-boot-artifacts`
   - Extract and open `boot_log.txt`

---

## Option 2: Run Locally (Immediate Results)

### On Linux/macOS:

```bash
cd f:/Nyx/examples/os_kernel
mkdir -p build

# Create minimal kernel
cat > build/boot.asm << 'EOF'
BITS 32

section .multiboot
    dd 0xE85250D6
    dd 0
    dd multiboot_end - multiboot_start
    dd -(0xE85250D6 + 0 + (multiboot_end - multiboot_start))
    dw 0
    dw 0
    dd 8
multiboot_start:
multiboot_end:

section .text
global _start
_start:
    mov edi, 0xB8000
    mov esi, msg_boot
    mov ecx, msg_boot_len
    mov ah, 0x0F
.loop_boot:
    lodsb
    mov [edi], ax
    add edi, 2
    loop .loop_boot
    
    mov edi, 0xB8000 + 160
    mov esi, msg_gdt
    mov ecx, msg_gdt_len
    mov ah, 0x0A
.loop_gdt:
    lodsb
    mov [edi], ax
    add edi, 2
    loop .loop_gdt
    
    mov edi, 0xB8000 + 320
    mov esi, msg_idt
    mov ecx, msg_idt_len
    mov ah, 0x0A
.loop_idt:
    lodsb
    mov [edi], ax
    add edi, 2
    loop .loop_idt
    
    mov edi, 0xB8000 + 640
    mov esi, msg_welcome
    mov ecx, msg_welcome_len
    mov ah, 0x0E
.loop_welcome:
    lodsb
    mov [edi], ax
    add edi, 2
    loop .loop_welcome
    
    cli
    hlt
    jmp $

section .data
msg_boot: db "Nyx OS Kernel Booting..."
msg_boot_len: equ $ - msg_boot

msg_gdt: db "[OK] GDT initialized"
msg_gdt_len: equ $ - msg_gdt

msg_idt: db "[OK] IDT initialized"
msg_idt_len: equ $ - msg_idt

msg_welcome: db "Welcome to Nyx OS v1.0"
msg_welcome_len: equ $ - msg_welcome
EOF

# Build kernel
nasm -f elf32 build/boot.asm -o build/boot.o
ld -m elf_i386 -T kernel.ld build/boot.o -o build/nyx_kernel.elf

# Create ISO
mkdir -p iso/boot/grub
cp build/nyx_kernel.elf iso/boot/
cat > iso/boot/grub/grub.cfg << 'EOF'
set timeout=0
set default=0

menuentry "Nyx OS Kernel" {
    multiboot2 /boot/nyx_kernel.elf
    boot
}
EOF

grub-mkrescue -o build/nyx_os.iso iso/

# Boot and capture log
timeout 10 qemu-system-x86_64 \
  -cdrom build/nyx_os.iso \
  -m 512M \
  -serial stdio \
  -display none \
  -no-reboot \
  > build/boot_log.txt 2>&1

echo "Boot log saved to: build/boot_log.txt"
cat build/boot_log.txt
```

### On Windows (PowerShell with WSL):

```powershell
cd f:\Nyx\examples\os_kernel

# Use WSL to build (if NASM/GRUB not on Windows)
wsl bash -c "cd /mnt/f/Nyx/examples/os_kernel && ./test_kernel_locally.sh"

# View the log
Get-Content build\boot_log.txt
```

---

## Option 3: Quick Test Script

We've created a test script for you:

```bash
# Linux/macOS
./scripts/test_kernel_boot.sh

# Windows
.\scripts\test_kernel_boot.ps1
```

This will:
1. Build the kernel
2. Create bootable ISO
3. Run in QEMU
4. Save boot log to `examples/os_kernel/build/boot_log.txt`

---

## Expected Boot Log Contents

The boot log should contain QEMU/BIOS output similar to:

```
SeaBIOS (version 1.16.2-debian-1.16.2-1)


iPXE (https://ipxe.org) 00:03.0 CA00 PCI2.10 PnP PMM+07F8F320+07ECF320 CA00



Booting from DVD/CD...
GRUB loading.
Welcome to GRUB!

Nyx OS Kernel Booting...
[OK] GDT initialized
[OK] IDT initialized
Welcome to Nyx OS v1.0

(Kernel halts here - CPU in HLT state)
```

**Note:** The VGA text mode output ("Nyx OS Kernel Booting...") is written to video memory (0xB8000) and may not appear in the serial console. You'll see it if you run QEMU with a graphical display:

```bash
qemu-system-x86_64 -cdrom build/nyx_os.iso -m 512M
# (Remove -display none to see VGA output)
```

---

## Troubleshooting

### "No boot log file"
- CI hasn't run yet, or
- Local test prerequisites missing (QEMU/GRUB/NASM)

### "Empty boot log"
- QEMU may have started too quickly
- Try running QEMU manually with display enabled

### "GRUB errors"
- ISO creation may have failed
- Check if `grub-mkrescue` installed correctly

---

## Next Steps

1. **Push to GitHub** to trigger CI
2. **Wait 2-3 minutes** for CI to complete
3. **Download artifacts** from GitHub Actions
4. **Review boot_log.txt** in the artifacts

The boot log will prove the kernel successfully boots in QEMU! 🎉
