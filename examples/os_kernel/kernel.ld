/* Linker script for Nyx OS Kernel (x86_64) */
/* Multiboot2 compatible, loads at 1MB physical memory */

ENTRY(_start)

SECTIONS
{
    /* Kernel loads at 1MB (0x00100000) */
    . = 1M;

    /* Multiboot2 header must be in first 32KB */
    .multiboot ALIGN(4K) : {
        *(.multiboot)
    }

    /* Read-only code and data */
    .text ALIGN(4K) : {
        *(.text)
        *(.text.*)
    }

    .rodata ALIGN(4K) : {
        *(.rodata)
        *(.rodata.*)
    }

    /* Read-write data */
    .data ALIGN(4K) : {
        *(.data)
        *(.data.*)
    }

    /* Uninitialized data */
    .bss ALIGN(4K) : {
        __bss_start = .;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        __bss_end = .;
    }

    /* Stack (16KB) */
    .stack ALIGN(4K) : {
        __stack_bottom = .;
        . += 16K;
        __stack_top = .;
    }

    /* Discard debug info for now */
    /DISCARD/ : {
        *(.comment)
        *(.eh_frame)
        *(.note.*)
    }
}
