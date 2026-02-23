# ===========================================
# Nyx Hardware Debugging Library
# ===========================================
# Hardware breakpoints, watchpoints, stack unwinding
# Beyond what Rust/C++/Zig provide - full hardware debug control

import systems
import hardware

# ===========================================
# Hardware Breakpoints (DR0-DR3)
# ===========================================

class HardwareBreakpoint {
    fn init(self, index) {
        if index < 0 || index > 3 {
            panic("HardwareBreakpoint: index must be 0-3");
        }
        self.index = index;
        self.address = 0;
        self.enabled = false;
        self.type = 0;  # 0=execute, 1=write, 2=io, 3=read/write
        self.length = 0;  # 0=1byte, 1=2bytes, 2=8bytes, 3=4bytes
    }
    
    fn set_address(self, addr) {
        # Set breakpoint address
        self.address = addr;
        
        if self.index == 0 {
            hardware.write_dr0(addr);
        } else if self.index == 1 {
            hardware.write_dr1(addr);
        } else if self.index == 2 {
            hardware.write_dr2(addr);
        } else if self.index == 3 {
            hardware.write_dr3(addr);
        }
    }
    
    fn set_execute(self, addr) {
        # Set execution breakpoint
        self.set_address(addr);
        self.type = 0;
        self.length = 0;
    }
    
    fn set_write(self, addr, size) {
        # Set write watchpoint
        self.set_address(addr);
        self.type = 1;
        self.length = self.size_to_length(size);
    }
    
    fn set_read_write(self, addr, size) {
        # Set read/write watchpoint
        self.set_address(addr);
        self.type = 3;
        self.length = self.size_to_length(size);
    }
    
    fn size_to_length(self, size) {
        if size == 1 { return 0; }
        if size == 2 { return 1; }
        if size == 4 { return 3; }
        if size == 8 { return 2; }
        panic("Invalid breakpoint size");
    }
    
    fn enable(self) {
        # Enable breakpoint in DR7
        self.enabled = true;
        
        let dr7 = hardware.read_dr7();
        
        # Set local enable bit (bit index*2)
        dr7 = dr7 | (1 << (self.index * 2));
        
        # Set type and length (4 bits starting at 16 + index*4)
        let shift = 16 + (self.index * 4);
        dr7 = dr7 & ~(0xF << shift);
        dr7 = dr7 | ((self.type << shift) | (self.length << (shift + 2)));
        
        hardware.write_dr7(dr7);
    }
    
    fn disable(self) {
        # Disable breakpoint in DR7
        self.enabled = false;
        
        let dr7 = hardware.read_dr7();
        
        # Clear local enable bit
        dr7 = dr7 & ~(1 << (self.index * 2));
        
        hardware.write_dr7(dr7);
    }
    
    fn check_triggered(self) {
        # Check if this breakpoint was triggered (DR6)
        let dr6 = hardware.read_dr6();
        return (dr6 & (1 << self.index)) != 0;
    }
    
    fn clear_triggered(self) {
        # Clear triggered status
        let dr6 = hardware.read_dr6();
        dr6 = dr6 & ~(1 << self.index);
        hardware.write_dr6(dr6);
    }
}

# ===========================================
# Debug Register Manager
# ===========================================

class DebugRegisters {
    fn init(self) {
        self.breakpoints = [
            HardwareBreakpoint(0),
            HardwareBreakpoint(1),
            HardwareBreakpoint(2),
            HardwareBreakpoint(3)
        ];
    }
    
    fn get_breakpoint(self, index) {
        return self.breakpoints[index];
    }
    
    fn allocate_breakpoint(self) {
        # Find free breakpoint
        for bp in self.breakpoints {
            if !bp.enabled {
                return bp;
            }
        }
        return null;
    }
    
    fn disable_all(self) {
        # Disable all breakpoints
        for bp in self.breakpoints {
            if bp.enabled {
                bp.disable();
            }
        }
    }
    
    fn get_triggered_breakpoints(self) {
        # Get list of triggered breakpoints
        let triggered = [];
        for bp in self.breakpoints {
            if bp.check_triggered() {
                push(triggered, bp);
            }
        }
        return triggered;
    }
    
    fn clear_all_triggered(self) {
        # Clear all triggered flags
        hardware.write_dr6(0);
    }
}

# ===========================================
# Stack Unwinding
# ===========================================

class StackFrame {
    fn init(self, rbp, rip) {
        self.rbp = rbp;
        self.rip = rip;
    }
    
    fn to_string(self) {
        return "RIP: 0x" + hex(self.rip) + " RBP: 0x" + hex(self.rbp);
    }
}

class StackUnwinder {
    fn init(self) {
        self.max_frames = 64;
    }
    
    fn unwind(self) {
        # Unwind stack and collect frames
        let frames = [];
        let rbp = _get_rbp();
        let rip = _get_rip();
        
        push(frames, StackFrame(rbp, rip));
        
        for i in range(0, self.max_frames) {
            if rbp == 0 || rbp < 0x1000 {
                break;
            }
            
            # Read saved RBP and RIP from stack
            let saved_rbp = systems.peek_u64(rbp);
            let saved_rip = systems.peek_u64(rbp + 8);
            
            if saved_rip == 0 {
                break;
            }
            
            push(frames, StackFrame(saved_rbp, saved_rip));
            rbp = saved_rbp;
        }
        
        return frames;
    }
    
    fn print_backtrace(self) {
        println("Stack backtrace:");
        let frames = self.unwind();
        
        for i in range(0, len(frames)) {
            println("  #", i, ": ", frames[i].to_string());
        }
    }
}

# ===========================================
# Performance Monitoring Counters
# ===========================================

class PerfCounter {
    fn init(self, counter_id, event_select) {
        self.counter_id = counter_id;
        self.event_select = event_select;
        self.enabled = false;
    }
    
    fn enable(self) {
        # Enable performance counter
        # Write to IA32_PERFEVTSELx MSR
        let msr = 0x186 + self.counter_id;
        
        # Event select format:
        # Bits 0-7: Event select
        # Bits 8-15: Unit mask
        # Bit 16: User mode
        # Bit 17: OS mode
        # Bit 22: Enable
        
        let value = self.event_select | (1 << 16) | (1 << 17) | (1 << 22);
        hardware.wrmsr(msr, value);
        
        self.enabled = true;
    }
    
    fn disable(self) {
        # Disable performance counter
        let msr = 0x186 + self.counter_id;
        hardware.wrmsr(msr, 0);
        self.enabled = false;
    }
    
    fn read(self) {
        # Read performance counter value
        if !self.enabled {
            return 0;
        }
        
        return hardware.rdpmc(self.counter_id);
    }
    
    fn reset(self) {
        # Reset counter to zero
        let msr = 0xC1 + self.counter_id;
        hardware.wrmsr(msr, 0);
    }
}

# Common performance events
const PERF_CYCLES = 0x3C;
const PERF_INSTRUCTIONS = 0xC0;
const PERF_CACHE_REFERENCES = 0x2E;
const PERF_CACHE_MISSES = 0x412E;
const PERF_BRANCH_INSTRUCTIONS = 0xC4;
const PERF_BRANCH_MISSES = 0xC5;
const PERF_L1D_LOADS = 0x0143;
const PERF_L1D_LOAD_MISSES = 0x0151;
const PERF_L1I_LOADS = 0x0280;
const PERF_L1I_LOAD_MISSES = 0x0280;
const PERF_LLC_LOADS = 0x4F2E;
const PERF_LLC_LOAD_MISSES = 0x412E;

class PerformanceMonitoring {
    fn init(self) {
        self.counters = {};
    }
    
    fn start_counting(self, name, event) {
        # Start performance counter
        let counter_id = len(self.counters);
        if counter_id >= 4 {
            panic("Maximum 4 performance counters");
        }
        
        let counter = PerfCounter(counter_id, event);
        counter.reset();
        counter.enable();
        
        self.counters[name] = counter;
    }
    
    fn stop_counting(self, name) {
        # Stop performance counter
        let counter = self.counters[name];
        if counter != null {
            counter.disable();
        }
    }
    
    fn read_counter(self, name) {
        # Read counter value
        let counter = self.counters[name];
        if counter == null {
            return 0;
        }
        return counter.read();
    }
    
    fn profile_function(self, fn_callback) {
        # Profile function execution
        self.start_counting("cycles", PERF_CYCLES);
        self.start_counting("instructions", PERF_INSTRUCTIONS);
        self.start_counting("l1_misses", PERF_L1D_LOAD_MISSES);
        self.start_counting("llc_misses", PERF_LLC_LOAD_MISSES);
        
        # Execute function
        let start_tsc = hardware.rdtsc();
        fn_callback();
        let end_tsc = hardware.rdtsc();
        
        # Read counters
        let cycles = self.read_counter("cycles");
        let instructions = self.read_counter("instructions");
        let l1_misses = self.read_counter("l1_misses");
        let llc_misses = self.read_counter("llc_misses");
        
        # Stop counters
        self.stop_counting("cycles");
        self.stop_counting("instructions");
        self.stop_counting("l1_misses");
        self.stop_counting("llc_misses");
        
        return {
            "tsc_cycles": end_tsc - start_tsc,
            "cycles": cycles,
            "instructions": instructions,
            "ipc": (instructions * 1.0) / (cycles * 1.0),
            "l1_misses": l1_misses,
            "llc_misses": llc_misses
        };
    }
}

# ===========================================
# Intel Processor Trace (PT)
# ===========================================

class ProcessorTrace {
    fn init(self) {
        self.supported = self.check_support();
    }
    
    fn check_support(self) {
        let cpuid = hardware.cpuid_query(0x14, 0);
        return cpuid["ebx"] != 0;
    }
    
    fn is_supported(self) {
        return self.supported;
    }
    
    fn enable(self, trace_buffer, size) {
        if !self.supported {
            panic("Intel PT not supported");
        }
        
        # Configure trace buffer
        self.trace_buffer = trace_buffer;
        self.trace_size = size;
        
        # Write to IA32_RTIT_CTL MSR
        let rtit_ctl = (1 << 0) |  # TraceEn
                      (1 << 2) |  # OS
                      (1 << 3) |  # User
                      (1 << 13);  # BranchEn
        
        hardware.wrmsr(0x570, rtit_ctl);
        
        # Set output base
        hardware.wrmsr(0x560, trace_buffer);  # IA32_RTIT_OUTPUT_BASE
        hardware.wrmsr(0x561, trace_buffer + size);  # IA32_RTIT_OUTPUT_MASK_PTRS
    }
    
    fn disable(self) {
        # Disable Intel PT
        hardware.wrmsr(0x570, 0);
    }
    
    fn get_trace_data(self) {
        # Read trace data from buffer
        return self.trace_buffer;
    }
}

# ===========================================
# Last Branch Record (LBR)
# ===========================================

class LastBranchRecord {
    fn init(self) {
        self.supported = self.check_support();
        self.num_entries = 32;  # Most CPUs have 32 LBR entries
    }
    
    fn check_support(self) {
        let cpuid = hardware.cpuid_query(1, 0);
        return (cpuid["edx"] & (1 << 21)) != 0;
    }
    
    fn is_supported(self) {
        return self.supported;
    }
    
    fn enable(self) {
        if !self.supported {
            panic("LBR not supported");
        }
        
        # Enable LBR in IA32_DEBUGCTL MSR
        let debugctl = hardware.rdmsr(0x1D9);
        debugctl = debugctl | (1 << 0);  # LBR
        hardware.wrmsr(0x1D9, debugctl);
    }
    
    fn disable(self) {
        # Disable LBR
        let debugctl = hardware.rdmsr(0x1D9);
        debugctl = debugctl & ~(1 << 0);
        hardware.wrmsr(0x1D9, debugctl);
    }
    
    fn read_entries(self) {
        # Read all LBR entries
        let entries = [];
        
        for i in range(0, self.num_entries) {
            let from_msr = 0x680 + i;
            let to_msr = 0x6C0 + i;
            
            let from_ip = hardware.rdmsr(from_msr);
            let to_ip = hardware.rdmsr(to_msr);
            
            push(entries, {"from": from_ip, "to": to_ip});
        }
        
        return entries;
    }
    
    fn print_branches(self) {
        println("Last Branch Records:");
        let entries = self.read_entries();
        
        for i in range(0, len(entries)) {
            if entries[i]["from"] != 0 {
                println("  ", i, ": 0x", hex(entries[i]["from"]), " -> 0x", hex(entries[i]["to"]));
            }
        }
    }
}

# ===========================================
# Memory Access Tracing
# ===========================================

class MemoryTracer {
    fn init(self) {
        self.watchpoints = [];
    }
    
    fn add_watchpoint(self, address, size, type) {
        # Add memory watchpoint using debug registers
        let dbg_regs = DebugRegisters();
        let bp = dbg_regs.allocate_breakpoint();
        
        if bp == null {
            panic("No free debug registers");
        }
        
        if type == "write" {
            bp.set_write(address, size);
        } else if type == "read_write" {
            bp.set_read_write(address, size);
        } else {
            panic("Invalid watchpoint type");
        }
        
        bp.enable();
        push(self.watchpoints, bp);
        
        return bp;
    }
    
    fn remove_watchpoint(self, bp) {
        bp.disable();
        
        let new_watchpoints = [];
        for wp in self.watchpoints {
            if wp != bp {
                push(new_watchpoints, wp);
            }
        }
        self.watchpoints = new_watchpoints;
    }
    
    fn clear_all_watchpoints(self) {
        for wp in self.watchpoints {
            wp.disable();
        }
        self.watchpoints = [];
    }
}

# ===========================================
# Instruction Pointer Profiling
# ===========================================

class IPProfiler {
    fn init(self, sample_interval_cycles) {
        self.sample_interval = sample_interval_cycles;
        self.samples = {};
    }
    
    fn start(self) {
        # Setup performance counter to interrupt at interval
        _setup_sampling_interrupt(self.sample_interval);
    }
    
    fn record_sample(self, rip) {
        # Record instruction pointer sample
        let count = self.samples.get(rip, 0);
        self.samples[rip] = count + 1;
    }
    
    fn get_hotspots(self, top_n = 10) {
        # Get top N hottest instruction pointers
        let sorted = self.sort_samples();
        
        let hotspots = [];
        for i in range(0, min(top_n, len(sorted))) {
            push(hotspots, sorted[i]);
        }
        
        return hotspots;
    }
    
    fn sort_samples(self) {
        # Sort samples by count
        let sorted = [];
        
        for rip in keys(self.samples) {
            push(sorted, {"rip": rip, "count": self.samples[rip]});
        }
        
        # Simple bubble sort
        for i in range(0, len(sorted)) {
            for j in range(i + 1, len(sorted)) {
                if sorted[j]["count"] > sorted[i]["count"] {
                    let temp = sorted[i];
                    sorted[i] = sorted[j];
                    sorted[j] = temp;
                }
            }
        }
        
        return sorted;
    }
    
    fn print_hotspots(self) {
        println("Instruction Pointer Hotspots:");
        let hotspots = self.get_hotspots(10);
        
        for i in range(0, len(hotspots)) {
            println("  ", i + 1, ": 0x", hex(hotspots[i]["rip"]), 
                   " (", hotspots[i]["count"], " samples)");
        }
    }
}

# ===========================================
# Native Implementation Stubs
# ===========================================

fn _get_rbp() { return 0; }
fn _get_rip() { return 0; }
fn _setup_sampling_interrupt(interval) {}

# ===========================================
# Global Instances
# ===========================================

let DEBUG_REGS_GLOBAL = DebugRegisters();
let STACK_UNWINDER_GLOBAL = StackUnwinder();
let PERF_MONITORING_GLOBAL = PerformanceMonitoring();
let PROCESSOR_TRACE_GLOBAL = ProcessorTrace();
let LBR_GLOBAL = LastBranchRecord();
let MEMORY_TRACER_GLOBAL = MemoryTracer();

# Convenience functions
fn set_breakpoint(address) {
    let bp = DEBUG_REGS_GLOBAL.allocate_breakpoint();
    if bp != null {
        bp.set_execute(address);
        bp.enable();
        return bp;
    }
    return null;
}

fn print_backtrace() {
    STACK_UNWINDER_GLOBAL.print_backtrace();
}

fn profile(fn_callback) {
    return PERF_MONITORING_GLOBAL.profile_function(fn_callback);
}
