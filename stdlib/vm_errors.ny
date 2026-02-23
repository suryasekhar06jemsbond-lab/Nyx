# ===========================================
# VM Error Handling & Recovery — Production Grade
# ===========================================
# Comprehensive error handling, exception recovery,
# safe state transitions, and fault isolation.

import systems
import hardware

# ===========================================
# Error Codes (Nyx Hypervisor)
# ===========================================

const ERR_OK                          = 0x00000000;
const ERR_INVALID_STATE              = 0x80000001;
const ERR_INVALID_PARAM              = 0x80000002;
const ERR_OUT_OF_MEMORY              = 0x80000003;
const ERR_DEVICE_NOT_FOUND           = 0x80000004;
const ERR_DEVICE_INIT_FAILED         = 0x80000005;
const ERR_VMCALL_INVALID             = 0x80000006;
const ERR_GUEST_FAULT                = 0x80000007;
const ERR_EPT_VIOLATION              = 0x80000008;
const ERR_EXIT_TIMEOUT               = 0x80000009;
const ERR_WATCHDOG_TIMEOUT           = 0x8000000A;
const ERR_INTERRUPT_MASKING_FAILED   = 0x8000000B;
const ERR_MSR_WRITE_PROTECTED        = 0x8000000C;
const ERR_CPUID_LEAF_UNSUPPORTED     = 0x8000000D;
const ERR_NESTED_VIRTUALIZATION      = 0x8000000E;
const ERR_MIGRATION_FAILED           = 0x8000000F;
const ERR_SNAPSHOT_CORRUPTED         = 0x80000010;
const ERR_DEVICE_HOTPLUG_FAILED      = 0x80000011;
const ERR_IOMMU_FAULT                = 0x80000012;
const ERR_TPM_INIT_FAILED            = 0x80000013;

# ===========================================
# Exception Types
# ===========================================

const EXCEPTION_DIV_BY_ZERO          = 0;
const EXCEPTION_DEBUG                = 1;
const EXCEPTION_NMI                  = 2;
const EXCEPTION_BREAKPOINT           = 3;
const EXCEPTION_OVERFLOW             = 4;
const EXCEPTION_BOUND_CHECK          = 5;
const EXCEPTION_INVALID_OPCODE       = 6;
const EXCEPTION_NO_DEVICE            = 7;
const EXCEPTION_DOUBLE_FAULT         = 8;
const EXCEPTION_SEG_OVERRUN          = 9;
const EXCEPTION_INVALID_TSS          = 10;
const EXCEPTION_SEGMENT_NOT_PRESENT  = 11;
const EXCEPTION_STACK_FAULT          = 12;
const EXCEPTION_GENERAL_PROTECTION   = 13;
const EXCEPTION_PAGE_FAULT           = 14;
const EXCEPTION_RESERVED             = 15;
const EXCEPTION_FLOATING_POINT       = 16;
const EXCEPTION_ALIGNMENT_CHECK      = 17;
const EXCEPTION_MACHINE_CHECK        = 18;

# ===========================================
# Error Recovery Strategies
# ===========================================

const RECOVERY_IGNORE                = 0;  # Log and continue
const RECOVERY_RESET_DEVICE          = 1;  # Reset faulting device
const RECOVERY_RESET_VCPU            = 2;  # Reset VCPU to known state
const RECOVERY_HARD_RESET            = 3;  # Hard reset entire VM
const RECOVERY_PAUSE_VM              = 4;  # Pause VM for inspection
const RECOVERY_SNAPSHOT_RESTORE      = 5;  # Restore from snapshot
const RECOVERY_ISOLATE_DEVICE        = 6;  # Disable faulting device
const RECOVERY_SHUTDOWN              = 7;  # Graceful shutdown

# ===========================================
# Error Context
# ===========================================

class ErrorContext {
    fn init(self, error_code, message) {
        self.error_code = error_code;
        self.message = message;
        self.timestamp = hardware.rdtsc();
        self.vcpu_id = 0;
        self.guest_rip = 0;
        self.guest_cr3 = 0;
        self.device_name = null;
        self.recovery_action = RECOVERY_PAUSE_VM;
        self.retryable = false;
        self.context_data = {};
    }

    fn describe(self) {
        return self.message;
    }

    fn get_recovery_action(self) {
        return self.recovery_action;
    }

    fn is_retryable(self) {
        return self.retryable;
    }
}

# ===========================================
# Exception Handler
# ===========================================

class ExceptionHandler {
    fn init(self) {
        self.handlers = [];
        self.error_log = [];
        self.max_log_entries = 1024;
        self.recovery_callbacks = {};
    }

    fn register_exception_handler(self, exc_num, callback) {
        while len(self.handlers) <= exc_num {
            push(self.handlers, null);
        }
        self.handlers[exc_num] = callback;
    }

    fn handle_exception(self, exc_num, error_code, rip, cr3) {
        # Create error context
        let exc_names = [
            "Division by Zero", "Debug", "NMI", "Breakpoint",
            "Overflow", "Bound Range Exceeded", "Invalid Opcode", "Device Not Available",
            "Double Fault", "Coprocessor Segment Overrun", "Invalid TSS", "Segment Not Present",
            "Stack Segment Fault", "General Protection", "Page Fault", "Reserved",
            "Floating Point Exception", "Alignment Check", "Machine Check"
        ];
        
        let exc_name = if exc_num < len(exc_names) then exc_names[exc_num] else "Unknown";
        let ctx = ErrorContext(error_code, exc_name);
        ctx.guest_rip = rip;
        ctx.guest_cr3 = cr3;

        # Log error
        self.log_error(ctx);

        # Call registered handler if exists
        if exc_num < len(self.handlers) and self.handlers[exc_num] != null {
            return self.handlers[exc_num](ctx);
        }

        # Default handling
        return self.default_exception_handler(exc_num, ctx);
    }

    fn default_exception_handler(self, exc_num, ctx) {
        # Double fault is always fatal
        if exc_num == EXCEPTION_DOUBLE_FAULT {
            ctx.recovery_action = RECOVERY_SHUTDOWN;
            return false;
        }

        # Machine check is always fatal
        if exc_num == EXCEPTION_MACHINE_CHECK {
            ctx.recovery_action = RECOVERY_SHUTDOWN;
            return false;
        }

        # Page faults can be retried or recovered
        if exc_num == EXCEPTION_PAGE_FAULT {
            ctx.retryable = true;
            ctx.recovery_action = RECOVERY_RESET_VCPU;
            return true;
        }

        # General Protection faults: try to isolate
        if exc_num == EXCEPTION_GENERAL_PROTECTION {
            ctx.recovery_action = RECOVERY_PAUSE_VM;
            return false;
        }

        # Invalid opcode: skip instruction
        if exc_num == EXCEPTION_INVALID_OPCODE {
            ctx.recovery_action = RECOVERY_IGNORE;
            return true;
        }

        # Default: pause for inspection
        ctx.recovery_action = RECOVERY_PAUSE_VM;
        return false;
    }

    fn log_error(self, ctx) {
        push(self.error_log, {
            "code": ctx.error_code,
            "message": ctx.message,
            "timestamp": ctx.timestamp,
            "rip": ctx.guest_rip,
            "cr3": ctx.guest_cr3
        });

        # Keep log size bounded
        if len(self.error_log) > self.max_log_entries {
            self.error_log = self.error_log[len(self.error_log) - self.max_log_entries..];
        }
    }

    fn register_recovery_callback(self, error_code, callback) {
        self.recovery_callbacks[error_code] = callback;
    }

    fn execute_recovery(self, ctx) {
        # Execute recovery action
        if ctx.recovery_action == RECOVERY_IGNORE {
            return true;
        } else if ctx.recovery_action == RECOVERY_PAUSE_VM {
            return false;
        } else if ctx.recovery_action == RECOVERY_SHUTDOWN {
            return false;
        }

        # Check for custom recovery handler
        if ctx.error_code in self.recovery_callbacks {
            return self.recovery_callbacks[ctx.error_code](ctx);
        }

        # Default: pause VM
        return false;
    }

    fn get_error_log(self) {
        return self.error_log;
    }

    fn clear_error_log(self) {
        self.error_log = [];
    }
}

# ===========================================
# Watchdog Timer
# ===========================================

class WatchdogTimer {
    fn init(self, timeout_ms) {
        self.timeout = timeout_ms;
        self.start_time = 0;
        self.enabled = false;
        self.vcpu_id = 0;
        self.timeout_callback = null;
        self.armed_at_rip = 0;
    }

    fn start(self, vcpu_id) {
        self.vcpu_id = vcpu_id;
        self.start_time = hardware.rdtsc();
        self.enabled = true;
        self.armed_at_rip = 0;
    }

    fn stop(self) {
        self.enabled = false;
    }

    fn check(self) {
        if !self.enabled { return true; }
        
        let elapsed = hardware.rdtsc() - self.start_time;
        let timeout_ticks = self.timeout * 3000;  # Approximate: 3GHz CPU
        
        if elapsed > timeout_ticks {
            self.enabled = false;
            if self.timeout_callback != null {
                return self.timeout_callback(self.vcpu_id);
            }
            return false;  # Timeout
        }
        return true;
    }

    fn set_timeout_callback(self, callback) {
        self.timeout_callback = callback;
    }
}

# ===========================================
# State Validator
# ===========================================

class StateValidator {
    fn init(self) {
        self.vcpu_state_valid = false;
        self.device_state_valid = false;
        self.memory_state_valid = false;
        self.checksum = 0;
    }

    fn validate_vcpu_state(self, vcpu) {
        # Validate VCPU state for consistency
        if vcpu.rip == 0 and vcpu.get_register("rflags") != 0x2 {
            return false;
        }
        if vcpu.cr3 != 0 and (vcpu.cr3 & 0xFFF) != 0 {
            return false;  # CR3 must be page-aligned
        }
        return true;
    }

    fn validate_device_state(self, device) {
        # Validate device state
        if device == null { return false; }
        if device.irq_line < -1 or device.irq_line > 255 {
            return false;
        }
        return true;
    }

    fn validate_memory_state(self, guest_mem) {
        # Validate guest memory state
        if guest_mem == null { return false; }
        if guest_mem.size == 0 { return false; }
        if guest_mem.base == 0 { return false; }
        return true;
    }

    fn compute_checksum(self, data, size) {
        let sum = 0;
        for i in 0..size {
            let byte = systems.peek_u8(data + i);
            sum = (sum + byte) & 0xFFFFFFFF;
        }
        return sum;
    }
}

# ===========================================
# Safe State Transition Manager
# ===========================================

class SafeStateTransition {
    fn init(self) {
        self.current_state = "stopped";
        self.valid_transitions = {
            "stopped": ["running", "paused"],
            "running": ["halted", "paused", "faulted"],
            "paused": ["running", "stopped"],
            "halted": ["running"],
            "faulted": ["paused", "stopped"]
        };
        self.transition_callbacks = {};
    }

    fn transition(self, new_state) {
        # Validate state transition
        if self.current_state not in self.valid_transitions {
            return false;
        }

        let allowed_states = self.valid_transitions[self.current_state];
        let is_allowed = false;
        for state in allowed_states {
            if state == new_state {
                is_allowed = true;
                break;
            }
        }

        if !is_allowed {
            return false;  # Invalid transition
        }

        # Execute pre-transition callback
        let old_state = self.current_state;
        let key = old_state + " -> " + new_state;
        if key in self.transition_callbacks {
            if !self.transition_callbacks[key]() {
                return false;
            }
        }

        self.current_state = new_state;
        return true;
    }

    fn get_state(self) {
        return self.current_state;
    }

    fn register_transition_callback(self, from_state, to_state, callback) {
        let key = from_state + " -> " + to_state;
        self.transition_callbacks[key] = callback;
    }
}

# ===========================================
# Fault Isolation
# ===========================================

class FaultIsolation {
    fn init(self) {
        self.isolated_devices = [];
        self.fault_counters = {};
        self.max_faults_before_isolation = 3;
    }

    fn track_device_fault(self, device_name) {
        if device_name not in self.fault_counters {
            self.fault_counters[device_name] = 0;
        }
        self.fault_counters[device_name] = self.fault_counters[device_name] + 1;

        if self.fault_counters[device_name] >= self.max_faults_before_isolation {
            self.isolate_device(device_name);
        }
    }

    fn isolate_device(self, device_name) {
        # Prevent further device access
        if device_name not in self.isolated_devices {
            push(self.isolated_devices, device_name);
        }
    }

    fn is_isolated(self, device_name) {
        for dev in self.isolated_devices {
            if dev == device_name { return true; }
        }
        return false;
    }

    fn get_fault_count(self, device_name) {
        if device_name in self.fault_counters {
            return self.fault_counters[device_name];
        }
        return 0;
    }

    fn reset_fault_counters(self) {
        self.fault_counters = {};
    }
}
