# ===========================================
# Nyx Interrupt & Exception Handling Library
# ===========================================
# IDT management, interrupt/exception handlers
# Beyond what Rust/C++/Zig provide - full OS-level interrupt control

import systems
import hardware

# ===========================================
# Interrupt Descriptor Table (IDT)
# ===========================================

class IDTEntry {
    fn init(self, offset, selector, ist = 0, type_attr = 0x8E) {
        self.offset_low = offset & 0xFFFF;
        self.offset_mid = (offset >> 16) & 0xFFFF;
        self.offset_high = (offset >> 32) & 0xFFFFFFFF;
        self.selector = selector;
        self.ist = ist;
        self.type_attr = type_attr;
        self.reserved = 0;
    }
    
    fn set_offset(self, offset) {
        self.offset_low = offset & 0xFFFF;
        self.offset_mid = (offset >> 16) & 0xFFFF;
        self.offset_high = (offset >> 32) & 0xFFFFFFFF;
    }
    
    fn get_offset(self) {
        return self.offset_low | (self.offset_mid << 16) | (self.offset_high << 32);
    }
    
    fn set_present(self, present) {
        if present {
            self.type_attr = self.type_attr | 0x80;
        } else {
            self.type_attr = self.type_attr & ~0x80;
        }
    }
    
    fn set_dpl(self, dpl) {
        # Descriptor Privilege Level (0-3)
        self.type_attr = (self.type_attr & 0x9F) | ((dpl & 0x3) << 5);
    }
    
    fn encode(self) {
        # Encode to 16-byte IDT entry format
        let entry = systems.alloc(16);
        
        systems.poke_u16(entry + 0, self.offset_low);
        systems.poke_u16(entry + 2, self.selector);
        systems.poke_u8(entry + 4, self.ist);
        systems.poke_u8(entry + 5, self.type_attr);
        systems.poke_u16(entry + 6, self.offset_mid);
        systems.poke_u32(entry + 8, self.offset_high);
        systems.poke_u32(entry + 12, self.reserved);
        
        return entry;
    }
}

class IDT {
    fn init(self, num_entries = 256) {
        self.num_entries = num_entries;
        self.entries = [];
        self.handlers = {};
        
        for i in range(0, num_entries) {
            let entry = IDTEntry(0, 0x08, 0, 0x8E);
            entry.set_present(false);
            push(self.entries, entry);
        }
    }
    
    fn set_gate(self, vector, handler, selector = 0x08, ist = 0, type_attr = 0x8E) {
        if vector >= self.num_entries {
            panic("IDT: vector out of range");
        }
        
        let entry = self.entries[vector];
        entry.set_offset(handler);
        entry.selector = selector;
        entry.ist = ist;
        entry.type_attr = type_attr;
        entry.set_present(true);
        
        self.handlers[vector] = handler;
    }
    
    fn set_interrupt_gate(self, vector, handler, dpl = 0) {
        # Type 0xE = Interrupt Gate (interrupts disabled)
        self.set_gate(vector, handler, 0x08, 0, 0x8E | (dpl << 5));
    }
    
    fn set_trap_gate(self, vector, handler, dpl = 0) {
        # Type 0xF = Trap Gate (interrupts enabled)
        self.set_gate(vector, handler, 0x08, 0, 0x8F | (dpl << 5));
    }
    
    fn load(self) {
        # Build IDT table in memory
        let idt_size = self.num_entries * 16;
        let idt_ptr = systems.alloc(idt_size);
        
        for i in range(0, self.num_entries) {
            let entry_bytes = self.entries[i].encode();
            systems.memcpy(idt_ptr + (i * 16), entry_bytes, 16);
        }
        
        # Load IDTR register
        let idtr = systems.alloc(10);
        systems.poke_u16(idtr, idt_size - 1);  # Limit
        systems.poke_u64(idtr + 2, idt_ptr);   # Base
        
        _lidt(idtr);
    }
    
    fn get_handler(self, vector) {
        return self.handlers.get(vector, null);
    }
}

# ===========================================
# Exception Vectors (x86/x64)
# ===========================================

const EXCEPTION_DIVIDE_ERROR = 0;
const EXCEPTION_DEBUG = 1;
const EXCEPTION_NMI = 2;
const EXCEPTION_BREAKPOINT = 3;
const EXCEPTION_OVERFLOW = 4;
const EXCEPTION_BOUND_RANGE = 5;
const EXCEPTION_INVALID_OPCODE = 6;
const EXCEPTION_DEVICE_NOT_AVAILABLE = 7;
const EXCEPTION_DOUBLE_FAULT = 8;
const EXCEPTION_COPROCESSOR_SEGMENT = 9;
const EXCEPTION_INVALID_TSS = 10;
const EXCEPTION_SEGMENT_NOT_PRESENT = 11;
const EXCEPTION_STACK_SEGMENT = 12;
const EXCEPTION_GENERAL_PROTECTION = 13;
const EXCEPTION_PAGE_FAULT = 14;
const EXCEPTION_RESERVED_15 = 15;
const EXCEPTION_FPU_ERROR = 16;
const EXCEPTION_ALIGNMENT_CHECK = 17;
const EXCEPTION_MACHINE_CHECK = 18;
const EXCEPTION_SIMD_FP = 19;
const EXCEPTION_VIRTUALIZATION = 20;
const EXCEPTION_CONTROL_PROTECTION = 21;

# Hardware interrupts (PIC)
const IRQ_TIMER = 32;
const IRQ_KEYBOARD = 33;
const IRQ_CASCADE = 34;
const IRQ_COM2 = 35;
const IRQ_COM1 = 36;
const IRQ_LPT2 = 37;
const IRQ_FLOPPY = 38;
const IRQ_LPT1 = 39;
const IRQ_RTC = 40;
const IRQ_FREE1 = 41;
const IRQ_FREE2 = 42;
const IRQ_FREE3 = 43;
const IRQ_MOUSE = 44;
const IRQ_FPU = 45;
const IRQ_PRIMARY_ATA = 46;
const IRQ_SECONDARY_ATA = 47;

# ===========================================
# Interrupt Frame
# ===========================================

class InterruptFrame {
    fn init(self, frame_ptr) {
        self.ptr = frame_ptr;
    }
    
    fn get_rip(self) {
        return systems.peek_u64(self.ptr + 0);
    }
    
    fn get_cs(self) {
        return systems.peek_u64(self.ptr + 8);
    }
    
    fn get_rflags(self) {
        return systems.peek_u64(self.ptr + 16);
    }
    
    fn get_rsp(self) {
        return systems.peek_u64(self.ptr + 24);
    }
    
    fn get_ss(self) {
        return systems.peek_u64(self.ptr + 32);
    }
    
    fn get_error_code(self) {
        # Error code is pushed for some exceptions
        return systems.peek_u64(self.ptr - 8);
    }
    
    fn set_rip(self, rip) {
        systems.poke_u64(self.ptr + 0, rip);
    }
    
    fn set_rsp(self, rsp) {
        systems.poke_u64(self.ptr + 24, rsp);
    }
    
    fn dump(self) {
        println("RIP: 0x", hex(self.get_rip()));
        println("CS:  0x", hex(self.get_cs()));
        println("RFLAGS: 0x", hex(self.get_rflags()));
        println("RSP: 0x", hex(self.get_rsp()));
        println("SS:  0x", hex(self.get_ss()));
    }
}

# ===========================================
# Exception Handlers
# ===========================================

class ExceptionHandlers {
    fn init(self) {
        self.handlers = {};
    }
    
    fn register(self, exception_vector, handler) {
        self.handlers[exception_vector] = handler;
    }
    
    fn handle_divide_error(self, frame) {
        println("EXCEPTION: Divide by zero at RIP=0x", hex(frame.get_rip()));
        self.call_handler(EXCEPTION_DIVIDE_ERROR, frame);
    }
    
    fn handle_debug(self, frame) {
        println("EXCEPTION: Debug at RIP=0x", hex(frame.get_rip()));
        self.call_handler(EXCEPTION_DEBUG, frame);
    }
    
    fn handle_breakpoint(self, frame) {
        println("EXCEPTION: Breakpoint at RIP=0x", hex(frame.get_rip()));
        self.call_handler(EXCEPTION_BREAKPOINT, frame);
    }
    
    fn handle_invalid_opcode(self, frame) {
        println("EXCEPTION: Invalid opcode at RIP=0x", hex(frame.get_rip()));
        self.call_handler(EXCEPTION_INVALID_OPCODE, frame);
    }
    
    fn handle_general_protection(self, frame) {
        let error_code = frame.get_error_code();
        println("EXCEPTION: General protection fault at RIP=0x", hex(frame.get_rip()));
        println("Error code: 0x", hex(error_code));
        self.call_handler(EXCEPTION_GENERAL_PROTECTION, frame);
    }
    
    fn handle_page_fault(self, frame) {
        let error_code = frame.get_error_code();
        let fault_addr = hardware.read_cr2();
        
        println("EXCEPTION: Page fault at RIP=0x", hex(frame.get_rip()));
        println("Fault address: 0x", hex(fault_addr));
        println("Error code: 0x", hex(error_code));
        
        # Error code bits:
        # 0: Present (0 = not present, 1 = protection)
        # 1: Write (0 = read, 1 = write)
        # 2: User (0 = supervisor, 1 = user)
        # 3: Reserved write
        # 4: Instruction fetch
        
        let present = (error_code & 1) != 0;
        let write = (error_code & 2) != 0;
        let user = (error_code & 4) != 0;
        let reserved = (error_code & 8) != 0;
        let instruction = (error_code & 16) != 0;
        
        println("  Present: ", present);
        println("  Write: ", write);
        println("  User: ", user);
        println("  Reserved: ", reserved);
        println("  Instruction fetch: ", instruction);
        
        self.call_handler(EXCEPTION_PAGE_FAULT, frame);
    }
    
    fn handle_double_fault(self, frame) {
        println("EXCEPTION: Double fault at RIP=0x", hex(frame.get_rip()));
        println("System halted - unrecoverable error");
        _halt();
    }
    
    fn call_handler(self, vector, frame) {
        let handler = self.handlers.get(vector, null);
        if handler != null {
            handler(frame);
        }
    }
}

# ===========================================
# Programmable Interrupt Controller (PIC)
# ===========================================

class PIC {
    fn init(self, offset1 = 0x20, offset2 = 0x28) {
        self.offset1 = offset1;  # Master PIC vector offset
        self.offset2 = offset2;  # Slave PIC vector offset
    }
    
    fn initialize(self) {
        # Save masks
        let mask1 = hardware.inb(0x21);
        let mask2 = hardware.inb(0xA1);
        
        # Initialize master PIC
        hardware.outb(0x20, 0x11);  # ICW1: Initialize + ICW4
        hardware.io_wait();
        hardware.outb(0x21, self.offset1);  # ICW2: Vector offset
        hardware.io_wait();
        hardware.outb(0x21, 0x04);  # ICW3: Tell master about slave at IRQ2
        hardware.io_wait();
        hardware.outb(0x21, 0x01);  # ICW4: 8086 mode
        hardware.io_wait();
        
        # Initialize slave PIC
        hardware.outb(0xA0, 0x11);
        hardware.io_wait();
        hardware.outb(0xA1, self.offset2);
        hardware.io_wait();
        hardware.outb(0xA1, 0x02);  # ICW3: Slave identity
        hardware.io_wait();
        hardware.outb(0xA1, 0x01);
        hardware.io_wait();
        
        # Restore masks
        hardware.outb(0x21, mask1);
        hardware.outb(0xA1, mask2);
    }
    
    fn mask_irq(self, irq) {
        let port = if irq < 8 { 0x21 } else { 0xA1 };
        let value = hardware.inb(port);
        let bit = irq % 8;
        hardware.outb(port, value | (1 << bit));
    }
    
    fn unmask_irq(self, irq) {
        let port = if irq < 8 { 0x21 } else { 0xA1 };
        let value = hardware.inb(port);
        let bit = irq % 8;
        hardware.outb(port, value & ~(1 << bit));
    }
    
    fn send_eoi(self, irq) {
        # Send End Of Interrupt
        if irq >= 8 {
            hardware.outb(0xA0, 0x20);  # Send EOI to slave
        }
        hardware.outb(0x20, 0x20);  # Send EOI to master
    }
}

# ===========================================
# Advanced Programmable Interrupt Controller (APIC)
# ===========================================

class LocalAPIC {
    fn init(self, base_addr = 0xFEE00000) {
        self.base = base_addr;
    }
    
    fn read_register(self, offset) {
        return systems.peek_u32(self.base + offset);
    }
    
    fn write_register(self, offset, value) {
        systems.poke_u32(self.base + offset, value);
    }
    
    fn enable(self) {
        # Set bit 8 (software enable) in spurious interrupt vector register
        let svr = self.read_register(0xF0);
        self.write_register(0xF0, svr | 0x100);
    }
    
    fn disable(self) {
        let svr = self.read_register(0xF0);
        self.write_register(0xF0, svr & ~0x100);
    }
    
    fn get_id(self) {
        return self.read_register(0x20) >> 24;
    }
    
    fn send_eoi(self) {
        # Write 0 to EOI register
        self.write_register(0xB0, 0);
    }
    
    fn send_ipi(self, dest, vector, delivery_mode = 0) {
        # Delivery modes:
        # 0 = Fixed
        # 1 = Lowest Priority
        # 2 = SMI
        # 3 = Reserved
        # 4 = NMI
        # 5 = INIT
        # 6 = Start Up
        # 7 = ExtINT
        
        let icr_high = dest << 24;
        let icr_low = vector | (delivery_mode << 8) | (1 << 14);  # Assert
        
        self.write_register(0x310, icr_high);
        self.write_register(0x300, icr_low);
    }
    
    fn broadcast_ipi(self, vector) {
        # Broadcast to all CPUs except self
        let icr_low = vector | (1 << 19) | (1 << 14);
        self.write_register(0x300, icr_low);
    }
}

# ===========================================
# Interrupt Service Routine (ISR) Manager
# ===========================================

class ISRManager {
    fn init(self) {
        self.handlers = {};
        self.idt = IDT(256);
    }
    
    fn register_handler(self, vector, handler) {
        self.handlers[vector] = handler;
    }
    
    fn unregister_handler(self, vector) {
        delete self.handlers[vector];
    }
    
    fn dispatch(self, vector, frame_ptr) {
        let frame = InterruptFrame(frame_ptr);
        let handler = self.handlers.get(vector, null);
        
        if handler != null {
            handler(frame);
        } else {
            println("Unhandled interrupt: ", vector);
        }
    }
    
    fn install(self) {
        # Install all exception handlers
        for i in range(0, 32) {
            let wrapper = _create_interrupt_wrapper(i);
            self.idt.set_interrupt_gate(i, wrapper);
        }
        
        # Install IRQ handlers
        for i in range(32, 48) {
            let wrapper = _create_interrupt_wrapper(i);
            self.idt.set_interrupt_gate(i, wrapper);
        }
        
        # Load IDT
        self.idt.load();
    }
}

# ===========================================
# Interrupt Disabling/Enabling
# ===========================================

class InterruptControl {
    fn disable(self) {
        _cli();
    }
    
    fn enable(self) {
        _sti();
    }
    
    fn are_enabled(self) {
        let rflags = _read_rflags();
        return (rflags & (1 << 9)) != 0;
    }
    
    fn disable_and_save(self) {
        let was_enabled = self.are_enabled();
        self.disable();
        return was_enabled;
    }
    
    fn restore(self, was_enabled) {
        if was_enabled {
            self.enable();
        }
    }
}

# Critical section helper
class CriticalSection {
    fn enter(self) {
        self.int_ctrl = InterruptControl();
        self.was_enabled = self.int_ctrl.disable_and_save();
    }
    
    fn exit(self) {
        self.int_ctrl.restore(self.was_enabled);
    }
}

# Macro for critical sections
fn with_interrupts_disabled(callback) {
    let cs = CriticalSection();
    cs.enter();
    
    let result = callback();
    
    cs.exit();
    return result;
}

# ===========================================
# Native Implementation Stubs
# ===========================================

fn _lidt(idtr_ptr) {
    # Load IDT register
}

fn _sidt(idtr_ptr) {
    # Store IDT register
}

fn _cli() {
    # Clear interrupt flag (disable interrupts)
}

fn _sti() {
    # Set interrupt flag (enable interrupts)
}

fn _halt() {
    # Halt CPU
    loop {}
}

fn _read_rflags() {
    return 0;
}

fn _create_interrupt_wrapper(vector) {
    # Create assembly wrapper for interrupt handler
    return 0;
}

# ===========================================
# Global Instances
# ===========================================

let IDT_GLOBAL = IDT(256);
let EXCEPTION_HANDLERS_GLOBAL = ExceptionHandlers();
let ISR_MANAGER_GLOBAL = ISRManager();
let INT_CONTROL_GLOBAL = InterruptControl();

# Convenience functions
fn disable_interrupts() { INT_CONTROL_GLOBAL.disable(); }
fn enable_interrupts() { INT_CONTROL_GLOBAL.enable(); }
fn are_interrupts_enabled() { return INT_CONTROL_GLOBAL.are_enabled(); }
