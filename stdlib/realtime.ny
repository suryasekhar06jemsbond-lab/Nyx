# ===========================================
# Nyx Real-Time Systems Library
# ===========================================
# Real-time scheduling, CPU affinity, priority control
# Beyond what Rust/C++/Zig provide - OS-level RT control

import systems
import hardware
import interrupts

# ===========================================
# CPU Affinity
# ===========================================

class CPUAffinity {
    fn init(self) {
        self.num_cpus = self.detect_cpu_count();
        self.affinity_mask = (1 << self.num_cpus) - 1;  # All CPUs
    }
    
    fn detect_cpu_count(self) {
        # Get number of logical processors
        let cpuid = hardware.cpuid_query(1, 0);
        let logical_count = (cpuid["ebx"] >> 16) & 0xFF;
        
        # Check for x2APIC
        let cpuid_b = hardware.cpuid_query(0xB, 0);
        if cpuid_b["ebx"] != 0 {
            return cpuid_b["ebx"] & 0xFFFF;
        }
        
        return logical_count;
    }
    
    fn set_affinity(self, cpu_mask) {
        # Set CPU affinity for current thread
        self.affinity_mask = cpu_mask;
        _set_cpu_affinity(cpu_mask);
    }
    
    fn set_single_cpu(self, cpu_id) {
        # Pin to single CPU
        if cpu_id >= self.num_cpus {
            panic("CPU ID out of range");
        }
        self.set_affinity(1 << cpu_id);
    }
    
    fn set_all_cpus(self) {
        # Allow all CPUs
        self.set_affinity((1 << self.num_cpus) - 1);
    }
    
    fn get_current_cpu(self) {
        # Get current CPU ID
        return _get_current_cpu_id();
    }
    
    fn get_affinity(self) {
        return self.affinity_mask;
    }
    
    fn migrate_to_cpu(self, cpu_id) {
        # Migrate current thread to specific CPU
        self.set_single_cpu(cpu_id);
        _yield_cpu();  # Force migration
    }
}

# ===========================================
# Priority Levels
# ===========================================

const PRIORITY_IDLE = 0;
const PRIORITY_LOWEST = 1;
const PRIORITY_BELOW_NORMAL = 2;
const PRIORITY_NORMAL = 3;
const PRIORITY_ABOVE_NORMAL = 4;
const PRIORITY_HIGH = 5;
const PRIORITY_HIGHEST = 6;
const PRIORITY_REALTIME = 7;

class ThreadPriority {
    fn init(self) {
        self.current_priority = PRIORITY_NORMAL;
    }
    
    fn set(self, priority) {
        if priority < PRIORITY_IDLE || priority > PRIORITY_REALTIME {
            panic("Invalid priority level");
        }
        self.current_priority = priority;
        _set_thread_priority(priority);
    }
    
    fn get(self) {
        return self.current_priority;
    }
    
    fn set_realtime(self) {
        self.set(PRIORITY_REALTIME);
    }
    
    fn set_normal(self) {
        self.set(PRIORITY_NORMAL);
    }
    
    fn boost_priority(self) {
        if self.current_priority < PRIORITY_REALTIME {
            self.set(self.current_priority + 1);
        }
    }
    
    fn lower_priority(self) {
        if self.current_priority > PRIORITY_IDLE {
            self.set(self.current_priority - 1);
        }
    }
}

# ===========================================
# Scheduling Policies
# ===========================================

const SCHED_POLICY_FIFO = 0;        # First-In First-Out
const SCHED_POLICY_RR = 1;          # Round-Robin
const SCHED_POLICY_DEADLINE = 2;    # Earliest Deadline First
const SCHED_POLICY_SPORADIC = 3;    # Sporadic Server
const SCHED_POLICY_NORMAL = 4;      # Normal time-sharing

class SchedulingPolicy {
    fn init(self) {
        self.policy = SCHED_POLICY_NORMAL;
        self.params = {};
    }
    
    fn set_fifo(self, priority) {
        # Real-time FIFO scheduling
        self.policy = SCHED_POLICY_FIFO;
        self.params = {"priority": priority};
        _set_scheduling_policy(SCHED_POLICY_FIFO, priority);
    }
    
    fn set_rr(self, priority, timeslice_us) {
        # Real-time round-robin scheduling
        self.policy = SCHED_POLICY_RR;
        self.params = {
            "priority": priority,
            "timeslice_us": timeslice_us
        };
        _set_scheduling_policy_rr(SCHED_POLICY_RR, priority, timeslice_us);
    }
    
    fn set_deadline(self, runtime_us, deadline_us, period_us) {
        # Deadline scheduling
        self.policy = SCHED_POLICY_DEADLINE;
        self.params = {
            "runtime_us": runtime_us,
            "deadline_us": deadline_us,
            "period_us": period_us
        };
        _set_scheduling_policy_deadline(runtime_us, deadline_us, period_us);
    }
    
    fn set_normal(self) {
        # Normal time-sharing scheduling
        self.policy = SCHED_POLICY_NORMAL;
        self.params = {};
        _set_scheduling_policy(SCHED_POLICY_NORMAL, 0);
    }
    
    fn get_policy(self) {
        return self.policy;
    }
    
    fn get_params(self) {
        return self.params;
    }
}

# ===========================================
# Real-Time Task
# ===========================================

class RealTimeTask {
    fn init(self, name, period_us, deadline_us, wcet_us) {
        self.name = name;
        self.period_us = period_us;        # Period (microseconds)
        self.deadline_us = deadline_us;    # Relative deadline
        self.wcet_us = wcet_us;            # Worst-case execution time
        self.priority = PRIORITY_REALTIME;
        self.cpu_affinity = CPUAffinity();
        self.sched_policy = SchedulingPolicy();
        self.missed_deadlines = 0;
        self.total_executions = 0;
    }
    
    fn setup(self) {
        # Configure task for real-time execution
        self.sched_policy.set_deadline(self.wcet_us, self.deadline_us, self.period_us);
    }
    
    fn pin_to_cpu(self, cpu_id) {
        # Pin task to specific CPU
        self.cpu_affinity.set_single_cpu(cpu_id);
    }
    
    fn execute(self, task_fn) {
        # Execute task with deadline tracking
        self.total_executions = self.total_executions + 1;
        
        let start_time = hardware.rdtsc();
        let deadline = start_time + (self.deadline_us * _cycles_per_us());
        
        # Execute task
        task_fn();
        
        let end_time = hardware.rdtsc();
        
        # Check if deadline was met
        if end_time > deadline {
            self.missed_deadlines = self.missed_deadlines + 1;
            println("RT Task '", self.name, "' missed deadline!");
        }
        
        # Calculate actual execution time
        let actual_us = (end_time - start_time) / _cycles_per_us();
        
        if actual_us > self.wcet_us {
            println("RT Task '", self.name, "' exceeded WCET: ", actual_us, "us");
        }
    }
    
    fn get_deadline_miss_ratio(self) {
        if self.total_executions == 0 {
            return 0.0;
        }
        return (self.missed_deadlines * 1.0) / (self.total_executions * 1.0);
    }
}

# ===========================================
# Periodic Task Scheduler
# ===========================================

class PeriodicScheduler {
    fn init(self) {
        self.tasks = [];
        self.running = false;
        self.timer_resolution_us = 100;  # 100μs resolution
    }
    
    fn add_task(self, task) {
        push(self.tasks, task);
    }
    
    fn remove_task(self, task) {
        # Remove task from scheduler
        let new_tasks = [];
        for t in self.tasks {
            if t != task {
                push(new_tasks, t);
            }
        }
        self.tasks = new_tasks;
    }
    
    fn start(self) {
        # Start periodic scheduler
        if self.running {
            return;
        }
        
        self.running = true;
        
        # Setup all tasks
        for task in self.tasks {
            task.setup();
        }
        
        # Configure high-resolution timer
        self.setup_timer();
        
        # Main scheduling loop
        self.schedule_loop();
    }
    
    fn stop(self) {
        self.running = false;
    }
    
    fn schedule_loop(self) {
        let base_time = hardware.rdtsc();
        let task_next_exec = [];
        
        # Initialize next execution times
        for task in self.tasks {
            push(task_next_exec, 0);
        }
        
        while self.running {
            let current_time = hardware.rdtsc();
            
            # Check each task
            for i in range(0, len(self.tasks)) {
                let task = self.tasks[i];
                
                if current_time >= task_next_exec[i] {
                    # Time to execute this task
                    task.execute(task.callback);
                    
                    # Schedule next execution
                    task_next_exec[i] = current_time + (task.period_us * _cycles_per_us());
                }
            }
            
            # Sleep until next event
            let next_event = self.find_next_event(task_next_exec);
            if next_event > current_time {
                let sleep_us = (next_event - current_time) / _cycles_per_us();
                _sleep_us(min(sleep_us, self.timer_resolution_us));
            }
        }
    }
    
    fn find_next_event(self, task_next_exec) {
        let min_time = task_next_exec[0];
        for time in task_next_exec {
            if time < min_time {
                min_time = time;
            }
        }
        return min_time;
    }
    
    fn setup_timer(self) {
        # Configure high-resolution timer (APIC timer or HPET)
        _setup_high_res_timer(self.timer_resolution_us);
    }
    
    fn get_schedulability_test(self) {
        # Liu & Layland utilization bound test for Rate Monotonic
        let total_utilization = 0.0;
        
        for task in self.tasks {
            let utilization = (task.wcet_us * 1.0) / (task.period_us * 1.0);
            total_utilization = total_utilization + utilization;
        }
        
        let n = len(self.tasks);
        let bound = n * (pow(2.0, 1.0 / n) - 1.0);
        
        return {
            "utilization": total_utilization,
            "bound": bound,
            "schedulable": total_utilization <= bound
        };
    }
}

# ===========================================
# IRQ Affinity and Priority
# ===========================================

class IRQAffinity {
    fn init(self) {
        self.num_irqs = 256;
    }
    
    fn set_irq_affinity(self, irq, cpu_mask) {
        # Set CPU affinity for IRQ
        _set_irq_affinity(irq, cpu_mask);
    }
    
    fn set_irq_priority(self, irq, priority) {
        # Set priority for IRQ (APIC)
        _set_irq_priority(irq, priority);
    }
    
    fn isolate_irq_to_cpu(self, irq, cpu_id) {
        # Isolate IRQ to specific CPU
        self.set_irq_affinity(irq, 1 << cpu_id);
    }
    
    fn spread_irqs(self, irqs, cpus) {
        # Spread IRQs across CPUs for load balancing
        for i in range(0, len(irqs)) {
            let cpu = cpus[i % len(cpus)];
            self.isolate_irq_to_cpu(irqs[i], cpu);
        }
    }
}

# ===========================================
# Memory Locking for Real-Time
# ===========================================

class MemoryLocking {
    fn lock_all(self) {
        # Lock all memory pages to prevent page faults
        _mlock_all();
    }
    
    fn unlock_all(self) {
        # Unlock all memory pages
        _munlock_all();
    }
    
    fn lock_region(self, addr, size) {
        # Lock specific memory region
        _mlock(addr, size);
    }
    
    fn unlock_region(self, addr, size) {
        # Unlock specific memory region
        _munlock(addr, size);
    }
    
    fn prefault_stack(self, size) {
        # Pre-fault stack pages to avoid page faults during RT execution
        let buffer = systems.alloc(size);
        systems.memset(buffer, 0, size);  # Touch all pages
    }
}

# ===========================================
# Cache Partitioning (Intel CAT)
# ===========================================

class CacheAllocation {
    fn init(self) {
        # Check for Intel CAT support
        self.supported = self.detect_cat_support();
    }
    
    fn detect_cat_support(self) {
        let cpuid = hardware.cpuid_query(0x10, 0);
        return (cpuid["ebx"] & (1 << 1)) != 0;  # L3 CAT
    }
    
    fn is_supported(self) {
        return self.supported;
    }
    
    fn allocate_cache_ways(self, cos_id, way_mask) {
        # Allocate L3 cache ways to Class of Service
        if !self.supported {
            panic("Intel CAT not supported");
        }
        
        # Write to IA32_L3_MASK_n MSR
        let msr = 0xC90 + cos_id;
        hardware.wrmsr(msr, way_mask);
    }
    
    fn set_thread_cos(self, cos_id) {
        # Set COS for current thread
        if !self.supported {
            return;
        }
        
        # Write to IA32_PQR_ASSOC MSR
        hardware.wrmsr(0xC8F, cos_id << 32);
    }
    
    fn partition_cache(self, rt_ways, bg_ways) {
        # Partition cache between real-time and background tasks
        self.allocate_cache_ways(0, rt_ways);   # COS 0: Real-time
        self.allocate_cache_ways(1, bg_ways);   # COS 1: Background
    }
}

# ===========================================
# CPU Isolation
# ===========================================

class CPUIsolation {
    fn isolate_cpus(self, cpu_list) {
        # Isolate CPUs for dedicated real-time use
        for cpu in cpu_list {
            _isolate_cpu(cpu);
        }
    }
    
    fn unisolate_cpus(self, cpu_list) {
        # Return CPUs to general use
        for cpu in cpu_list {
            _unisolate_cpu(cpu);
        }
    }
    
    fn disable_cpu_idle(self, cpu_id) {
        # Disable C-states for deterministic latency
        _disable_cpu_idle(cpu_id);
    }
    
    fn set_cpu_frequency(self, cpu_id, freq_mhz) {
        # Set fixed CPU frequency (disable turbo/scaling)
        _set_cpu_frequency(cpu_id, freq_mhz);
    }
}

# ===========================================
# Watchdog Timer
# ===========================================

class WatchdogTimer {
    fn init(self, timeout_ms) {
        self.timeout_ms = timeout_ms;
        self.enabled = false;
    }
    
    fn start(self) {
        # Start hardware watchdog
        self.enabled = true;
        _start_watchdog(self.timeout_ms);
    }
    
    fn stop(self) {
        # Stop hardware watchdog
        self.enabled = false;
        _stop_watchdog();
    }
    
    fn kick(self) {
        # Pet the watchdog (reset timer)
        if self.enabled {
            _kick_watchdog();
        }
    }
}

# ===========================================
# Native Implementation Stubs
# ===========================================

fn _set_cpu_affinity(mask) {}
fn _get_current_cpu_id() { return 0; }
fn _yield_cpu() {}
fn _set_thread_priority(priority) {}
fn _set_scheduling_policy(policy, priority) {}
fn _set_scheduling_policy_rr(policy, priority, timeslice) {}
fn _set_scheduling_policy_deadline(runtime, deadline, period) {}
fn _cycles_per_us() { return 3000; }  # Assume 3GHz
fn _sleep_us(us) {}
fn _setup_high_res_timer(resolution_us) {}
fn _set_irq_affinity(irq, mask) {}
fn _set_irq_priority(irq, priority) {}
fn _mlock_all() {}
fn _munlock_all() {}
fn _mlock(addr, size) {}
fn _munlock(addr, size) {}
fn _isolate_cpu(cpu) {}
fn _unisolate_cpu(cpu) {}
fn _disable_cpu_idle(cpu) {}
fn _set_cpu_frequency(cpu, freq) {}
fn _start_watchdog(timeout_ms) {}
fn _stop_watchdog() {}
fn _kick_watchdog() {}

# ===========================================
# Global Instances
# ===========================================

let CPU_AFFINITY_GLOBAL = CPUAffinity();
let THREAD_PRIORITY_GLOBAL = ThreadPriority();
let SCHED_POLICY_GLOBAL = SchedulingPolicy();
let IRQ_AFFINITY_GLOBAL = IRQAffinity();
let MEMORY_LOCKING_GLOBAL = MemoryLocking();
let CACHE_ALLOCATION_GLOBAL = CacheAllocation();

# Convenience functions
fn pin_to_cpu(cpu_id) {
    CPU_AFFINITY_GLOBAL.set_single_cpu(cpu_id);
}

fn set_realtime_priority() {
    THREAD_PRIORITY_GLOBAL.set_realtime();
}

fn lock_memory() {
    MEMORY_LOCKING_GLOBAL.lock_all();
}
