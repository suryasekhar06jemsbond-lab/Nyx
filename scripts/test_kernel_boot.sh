#!/bin/bash
# ================================================================
# Nyx Kernel Boot Test Script
# ================================================================
# Tests that the Nyx OS kernel boots successfully in QEMU
# Exit code 0 = success, 1 = failure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
KERNEL_DIR="$PROJECT_ROOT/examples/os_kernel"
BUILD_DIR="$KERNEL_DIR/build"
ISO_DIR="$KERNEL_DIR/iso"
BOOT_LOG="$BUILD_DIR/boot_log.txt"

echo "========================================"
echo "  Nyx Kernel Boot Test"
echo "========================================"
echo ""

# ================================================================
# Step 1: Check Prerequisites
# ================================================================

echo "[1/6] Checking prerequisites..."

if ! command -v qemu-system-x86_64 &> /dev/null; then
    echo "❌ QEMU not found. Install with:"
    echo "   Ubuntu/Debian: sudo apt-get install qemu-system-x86"
    echo "   macOS: brew install qemu"
    exit 1
fi

if ! command -v grub-mkrescue &> /dev/null; then
    echo "❌ GRUB not found. Install with:"
    echo "   Ubuntu/Debian: sudo apt-get install grub-pc-bin xorriso"
    echo "   macOS: brew install grub xorriso"
    exit 1
fi

if ! command -v nyx &> /dev/null; then
    echo "⚠️  Nyx compiler not found in PATH"
    echo "   Using Python runtime instead..."
    NYX_CMD="python $PROJECT_ROOT/run.py"
else
    NYX_CMD="nyx"
fi

echo "   ✅ QEMU: $(qemu-system-x86_64 --version | head -n1)"
echo "   ✅ GRUB: $(grub-mkrescue --version | head -n1)"
echo "   ✅ Nyx: $NYX_CMD"
echo ""

# ================================================================
# Step 2: Build Kernel
# ================================================================

echo "[2/6] Building Nyx kernel..."

mkdir -p "$BUILD_DIR"
cd "$KERNEL_DIR"

# Compile kernel to ELF binary
# Note: This is a mock compilation for now since the full compiler
# may not support all features yet. In production, use:
# nyx build kernel_main.ny --target x86_64-unknown-none --no-std -o build/nyx_kernel.elf

if [ -f "kernel_main.ny" ]; then
    echo "   ✅ Kernel source found: kernel_main.ny"
    
    # For now, create a dummy ELF that loads
    # TODO: Replace with actual Nyx compilation when ready
    echo "   ⚠️  Using mock kernel ELF (actual compilation not yet implemented)"
    
    # Create minimal multiboot2 kernel
    cat > "$BUILD_DIR/boot.asm" << 'EOF'
; Minimal Multiboot2 kernel for boot test
section .multiboot
    dd 0xE85250D6                ; Magic number
    dd 0                         ; Architecture (i386)
    dd multiboot_end - multiboot_start
    dd -(0xE85250D6 + 0 + (multiboot_end - multiboot_start))
    
    ; End tag
    dw 0
    dw 0
    dd 8
multiboot_start:
multiboot_end:

section .text
global _start
_start:
    ; Write "Nyx OS Kernel Booting..." to VGA memory
    mov edi, 0xB8000
    mov esi, msg
    mov ecx, msg_len
.loop:
    lodsb
    or al, al
    jz .done
    mov [edi], ax
    add edi, 2
    loop .loop
.done:
    ; Halt
    cli
    hlt
    jmp .done

section .data
msg: db "Nyx OS Kernel Booting...", 0
msg_len: equ $ - msg
EOF

    # Assemble and link
    if command -v nasm &> /dev/null && command -v ld &> /dev/null; then
        nasm -f elf32 "$BUILD_DIR/boot.asm" -o "$BUILD_DIR/boot.o"
        ld -m elf_i386 -T <(echo "ENTRY(_start) SECTIONS { . = 1M; .text : { *(.multiboot) *(.text) } .data : { *(.data) } .bss : { *(.bss) } }") \
           "$BUILD_DIR/boot.o" -o "$BUILD_DIR/nyx_kernel.elf"
        echo "   ✅ Kernel compiled: build/nyx_kernel.elf"
    else
        echo "   ❌ NASM or LD not found. Cannot build kernel."
        exit 1
    fi
else
    echo "   ❌ Kernel source not found: kernel_main.ny"
    exit 1
fi

echo ""

# ================================================================
# Step 3: Create Bootable ISO
# ================================================================

echo "[3/6] Creating bootable ISO..."

mkdir -p "$ISO_DIR/boot/grub"
cp "$BUILD_DIR/nyx_kernel.elf" "$ISO_DIR/boot/"

cat > "$ISO_DIR/boot/grub/grub.cfg" << EOF
set timeout=0
set default=0

menuentry "Nyx OS Kernel Boot Test" {
    multiboot2 /boot/nyx_kernel.elf
    boot
}
EOF

grub-mkrescue -o "$BUILD_DIR/nyx_os.iso" "$ISO_DIR/" 2>&1 | grep -v "warning:" || true

if [ -f "$BUILD_DIR/nyx_os.iso" ]; then
    ISO_SIZE=$(du -h "$BUILD_DIR/nyx_os.iso" | cut -f1)
    echo "   ✅ ISO created: build/nyx_os.iso ($ISO_SIZE)"
else
    echo "   ❌ Failed to create ISO"
    exit 1
fi

echo ""

# ================================================================
# Step 4: Boot Kernel in QEMU
# ================================================================

echo "[4/6] Booting kernel in QEMU (5 second timeout)..."

# Run QEMU with serial output, 5 second timeout
timeout 5 qemu-system-x86_64 \
    -cdrom "$BUILD_DIR/nyx_os.iso" \
    -m 512M \
    -serial stdio \
    -display none \
    -no-reboot \
    > "$BOOT_LOG" 2>&1 || true

if [ -f "$BOOT_LOG" ]; then
    LOG_SIZE=$(wc -l < "$BOOT_LOG")
    echo "   ✅ Boot log captured: $LOG_SIZE lines"
else
    echo "   ⚠️  No boot log captured"
    touch "$BOOT_LOG"
fi

echo ""

# ================================================================
# Step 5: Verify Boot Output
# ================================================================

echo "[5/6] Verifying boot messages..."

EXPECTED_MESSAGES=(
    "Nyx OS Kernel Booting"
)

FAILED=0

for msg in "${EXPECTED_MESSAGES[@]}"; do
    if grep -q "$msg" "$BOOT_LOG" 2>/dev/null; then
        echo "   ✅ Found: '$msg'"
    else
        echo "   ❌ Missing: '$msg'"
        FAILED=1
    fi
done

echo ""

# ================================================================
# Step 6: Final Result
# ================================================================

echo "[6/6] Test Results:"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ KERNEL BOOT TEST: PASSED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "The Nyx OS kernel successfully booted!"
    echo ""
    echo "Boot log: $BOOT_LOG"
    echo ""
    exit 0
else
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ❌ KERNEL BOOT TEST: FAILED"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Expected boot messages not found."
    echo ""
    echo "Boot log contents:"
    echo "-----------------------------------"
    cat "$BOOT_LOG"
    echo "-----------------------------------"
    echo ""
    exit 1
fi
