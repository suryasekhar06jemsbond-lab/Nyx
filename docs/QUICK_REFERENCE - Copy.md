# Nyx Hypervisor — Quick Reference Guide

## Quickest Start (3 steps)

```nyx
# Step 1: Build a VM
vm = ProductionVMBuilder()
    .memory(2 * 1024 * 1024 * 1024)  # 2GB
    .cpus(2)                          # 2 vCPUs
    .uefi("OVMF.fd")                 # UEFI firmware
    .disk("guest.img")               # Virtual disk
    .with_logging()                  # Minimal production features
    .build();

# Step 2: Run it
exit_code = vm.run();

# Step 3: Check logs
logger.dump_buffer();
```

## Module Import & Use

### Loading Modules (Both Syntax Support)
```nyx
# Modern syntax (unquoted - preferred)
import vm_production;
import vm_iommu;
import systems;

# Using use keyword (equivalent)
use vm_production;
use vm_iommu;
use systems;

# Legacy syntax (quoted - still works)
import "vm_production";
use "systems";

# Mix all styles freely
import systems;
use "hardware";
import memory;
```

### Built-in Modules
```nyx
import systems;       # Hardware systems & virtualization
import hardware;      # Hardware simulation & emulation
import memory;        # Memory management & paging
import vm_core;       # Core VM functionality
import vm_iommu;      # IOMMU & device pass-through
import vm_production; # ProductionVMBuilder fluent API
import logging;       # Logging framework
import metrics;       # Performance metrics
```

**See [Unquoted Module Syntax](UNQUOTED_IMPORT_SYNTAX.md) for full reference.**

## Common Operations

### Memory & CPU Configuration
```nyx
let vm = ProductionVMBuilder()
    .memory(4 * 1024**3)    # 4 GB (use ** for power)
    .cpus(4)                # 4 vCPUs
```

### Boot Modes
```nyx
.uefi("firmware.fd")           # Modern UEFI
.bios("seabios.bin")           # Legacy BIOS
```

### Storage
```nyx
.disk("system.qcow2")          # First disk (sda/hda)
.disk("data.img")              # Second disk (sdb/hdb)
.ahci(true)                    # Enable AHCI
```

### Networking
```nyx
.nic("e1000")                  # Intel E1000 NIC
.nic("virtio")                 # High-performance VIRTIO
```

### Display
```nyx
.gpu(true)                     # Enable Bochs VGA + VBE
.gpu(false)                    # Disable graphics
```

### Production Features
```nyx
.with_error_handling()         # Enable exception recovery
.with_logging()                # Enable multi-level logging
.with_metrics()                # Enable performance monitoring
.with_live_migration()         # Enable dirty tracking
.with_pci_hotplug()            # Enable runtime device plug/unplug
.with_tpm()                    # Enable TPM 2.0
.with_debug_symbols("file")    # Load debug symbols
.with_performance_tracing()    # Enable performance spans
```

## Logging

### Quick Setup
```nyx
let logger = vm.logger;
logger.set_level(vm_logging.LOG_LEVEL_INFO);
logger.register_component("device", vm_logging.LOG_LEVEL_DEBUG);
logger.register_output(fn(level, component, msg) {
    printf("[%s][%s] %s\n", level, component, msg);
});
```

### Severity Levels (Lowest to Highest)
1. `LOG_LEVEL_TRACE` — Detailed execution flow
2. `LOG_LEVEL_DEBUG` — Diagnostic information
3. `LOG_LEVEL_INFO` — General informational
4. `LOG_LEVEL_WARN` — Warning conditions
5. `LOG_LEVEL_ERROR` — Error conditions
6. `LOG_LEVEL_FATAL` — Fatal errors (shutdown)

### Dumping Logs
```nyx
vm.logger.dump_buffer();               # Last 10,000 entries
vm.logger.dump_component("device");    # Just device logs
vm.logger.dump_since(timestamp);       # Since Unix timestamp
```

## Metrics & Monitoring

### Collecting Metrics
```nyx
let metrics = vm.metrics;
metrics.metrics.enable_collection();
```

### Getting Reports
```nyx
let report = metrics.get_performance_report();
# Returns map: {
#   "total_exits": N,
#   "avg_exit_time_us": F,
#   "disk_latency_us": F,
#   "network_errors": N,
#   "memory_efficiency": F
# }

let bottlenecks = metrics.identify_bottleneck();
# Returns: [(issue_type, severity, suggestion), ...]
```

### Snapshots
```nyx
let snapshot = metrics.metrics.take_snapshot();
# Returns: tagged timestamp + all counters at that instant

let prev_snapshot = metrics.metrics.snapshots[length - 2];
let delta = snapshot.counters - prev_snapshot.counters;
```

## Error Handling

### Exception Types (19 total)
```nyx
EXCEPTION_DIVIDE_BY_ZERO        (0)
EXCEPTION_DEBUG                 (1)
EXCEPTION_NMI                   (2)
EXCEPTION_BREAKPOINT            (3)
EXCEPTION_OVERFLOW              (4)
EXCEPTION_BOUND_RANGE           (5)
EXCEPTION_INVALID_OPCODE        (6)
EXCEPTION_DEVICE_NOT_AVAILABLE  (7)
EXCEPTION_DOUBLE_FAULT          (8)
EXCEPTION_COPROC_SEGMENT_OVRUN  (9)
EXCEPTION_INVALID_TSS           (10)
EXCEPTION_SEGMENT_NOT_PRESENT   (11)
EXCEPTION_STACK_SEGMENT         (12)
EXCEPTION_GENERAL_PROTECTION    (13)
EXCEPTION_PAGE_FAULT            (14)
EXCEPTION_FLOATING_POINT        (16)
EXCEPTION_ALIGNMENT_CHECK        (17)
EXCEPTION_MACHINE_CHECK         (18)
```

### Recovery Strategies
```nyx
RECOVERY_IGNORE                 # Log only
RECOVERY_RESET_DEVICE          # Isolate device
RECOVERY_RESET_VCPU            # Reset vCPU
RECOVERY_HARD_RESET            # Full VM reset
RECOVERY_PAUSE_VM              # Pause & inspect
RECOVERY_SNAPSHOT_RESTORE      # Time-travel restore
RECOVERY_ISOLATE_DEVICE        # Quarantine device
RECOVERY_SHUTDOWN              # Graceful shutdown
```

### Example Handler
```nyx
let error_handler = vm.error_handler;
error_handler.register_exception_handler(
    EXCEPTION_PAGE_FAULT,
    fn(ctx) {
        logger.warn("VM", "Page fault at " + ctx.guest_rip);
        return RECOVERY_CONTINUE;  # Log and continue
    }
);
```

## Migration Workflow

### Three-Phase Migration
```nyx
# Phase 1: Start precopy (VM running with tracking)
vm.dirty_tracker.enable_tracking();
success = vm.migration_mgr.start_iterative_precopy(
    vm,
    dest_host,
    {
        "max_iterations": 10,
        "convergence_threshold": 0.01,  # 1%
        "bandwidth_limit_mbps": 1024
    }
);

# Phase 2: When converged, stop & copy (VM paused)
success = vm.migration_mgr.start_stop_and_copy(vm, dest_host);

# Phase 3: Activate on destination
success = vm.migration_mgr.activate_on_destination(dest_vm);
```

### Dirty Page Tracking
```nyx
vm.dirty_tracker.enable_tracking();
dirty_pages = vm.dirty_tracker.get_dirty_pages();
# Returns: array of page addresses that changed

vm.dirty_tracker.clear_dirty_map();
# Reset tracking for next iteration
```

## PCI Hotplug

### Enable Hotplug
```nyx
vm.dynamic_devices.enable_pci_hotplug();
```

### Add Device at Runtime
```nyx
let nic = vm_devices.E1000Device();
vm.dynamic_devices.add_pci_device(nic, {
    "device_type": "network",
    "name": "eth1"
});
```

### Remove Device
```nyx
vm.dynamic_devices.remove_pci_device(device_id);
```

## IOMMU & Device Pass-Through

### Enable IOMMU
```nyx
vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .with_iommu()  # Enable IOMMU for pass-through
    .passthrough_device(0x0300, "STRICT")  # Pass-through NIC at 03:00.0
    .passthrough_device(0x0400, "SHARED")  # Pass-through storage with shared domain
    .build();
```

### Pass-Through Device Configuration
```nyx
# PCI ID Format: 0xBBDD (Bus.Device.Function)
# 0x0300 = Bus 3, Device 0, Function 0
# 0x1A02 = Bus 26, Device 2, Function 0 (in hex)

# Isolation types:
# STRICT  - Device fully isolated, DMA to domain only
# SHARED  - Device in shared domain (cheaper isolation)
# UNMANAGED - No IOMMU protection (valid but risky)

.passthrough_device(0x0100, "STRICT")    # GPU
.passthrough_device(0x0300, "STRICT")    # NIC
.passthrough_device(0x0400, "SHARED")    # Storage
```

### Get IOMMU Status
```nyx
let status = vm.iommu_mgr.get_status();
# Returns: {
#   enabled: true/false,
#   controllers: N,
#   domains: M,
#   devices: K,
#   fault_events: F
# }
```

### Interrupt Remapping
```nyx
vm.iommu_mgr.setup_interrupt_remap(
    device_id=0x0300,
    irq_index=0,
    vector=32,           # Interrupt vector
    destination=0        # LAPIC ID
);
```

### DMA Mapping
```nyx
vm.iommu_mgr.map_guest_memory(
    domain_id=0,
    guest_phys=0x10000000,
    host_phys=0x40000000,
    size=256*1024*1024,  # 256MB
    flags=0x3            # RW
);

vm.iommu_mgr.unmap_guest_memory(
    domain_id=0,
    guest_phys=0x10000000,
    size=256*1024*1024
);
```

### Fault Handling
```nyx
# On DMA fault, IOMMU automatically records and isolates
let fault_response = vm.iommu_mgr.report_dma_fault(device_id=0x0300);
# Returns: "FAULT_RECORDED" or "DEVICE_ISOLATED"
```

## Debug Symbols

### Register Symbols from File
```nyx
vm.debug_ctx.load_symbols_from_file("kernel.pdb");
vm.debug_ctx.load_symbols_from_file("app.dbg");
```

### Manual Symbol Registration
```nyx
vm.debug_ctx.register_symbol(0x400000, "main", "function");
vm.debug_ctx.register_symbol(0x4001a0, "helper", "function");
vm.debug_ctx.register_symbol(0x600000, "data", "data");
```

### Symbol Lookup
```nyx
let sym = vm.debug_ctx.lookup_address(0x401234);
# Returns: {name: "strlen", type: "function", module: "libc"}
```

### Stack Traces
```nyx
let trace = vm.debug_ctx.get_stack_trace(vcpu_id);
# Returns: [
#   {symbol: "main", address: 0x400000, offset: 0x1a4},
#   {symbol: "helper", address: 0x4001a0, offset: 0x2c},
#   ...
# ]
```

## Performance Tracing

### Start Tracing
```nyx
let tracer = vm.debug_ctx.tracer;
tracer.start_span("Guest Boot");
```

### Add Events in Span
```nyx
tracer.add_event("disk_read_start");
# ... I/O operation ...
tracer.add_event("disk_read_complete");
```

### End Tracing
```nyx
tracer.end_span();  # Auto-calculates duration
```

### Get Statistics
```nyx
let stats = tracer.get_statistics();
# Returns: {
#   slowest_spans: [(name, duration_us), ...],
#   event_counts: {event: count, ...},
#   total_time_us: N
# }
```

## Watchdog Timers

### Create Watchdog
```nyx
let watchdog = vm.error_handler.watchdog;
watchdog.set_timeout(5000);  # 5 second timeout
```

### Watchdog Callback
```nyx
watchdog.set_timeout_callback(fn(vcpu_id) {
    logger.error("VM", "VCPU " + vcpu_id + " stuck");
    return false;  # Pause VM for inspection
});
```

## State Snapshots

### Take Snapshot
```nyx
let state = vm.snapshot();
# Returns serialized VM state (memory, registers, devices)
```

### Restore from Snapshot
```nyx
let new_vm = VirtualMachine(config);
new_vm.restore(state);
```

## TPM 2.0

### Quick Setup
```nyx
.with_tpm()  # Enable TPM in builder
```

### TPM Commands
```nyx
# Extend PCR
tpm.execute_command(
    vm_tpm.TPM_CMD_PCR_EXTEND,
    {
        "pcr_index": 0,
        "hash": "sha256",
        "value": hash_value
    }
);

# Read PCR
let pcr_value = tpm.execute_command(
    vm_tpm.TPM_CMD_PCR_READ,
    {"pcr_index": 0, "hash": "sha256"}
);

# NV Write
tpm.execute_command(
    vm_tpm.TPM_CMD_NV_WRITE,
    {"index": 0x1000001, "data": buffer}
);
```

## Advanced: Direct Configuration

```nyx
let vm_config = VMConfig(
    name="MyVM",
    memory_size=4*1024**3,
    vcpu_count=4,
    boot_firmware="UEFI",
    boot_path=0xFFF0,  # BIOS: 0xFFF0, UEFI: 0xFFFFFFFF
    allow_nested_vm=false,
    enable_msi=true,
    enable_iommu=false
);

let vm = VirtualMachine(vm_config);
vm.init_devices();
vm.setup_uefi_boot("firmware.fd");
vm.run();
```

## Health Check

### Production Readiness
```nyx
let ready = production_readiness_check(vm);
if (!ready) {
    logger.error("VM", "Not production-ready!");
    for (issue in vm.error_handler.validation_errors) {
        printf("  - %s\n", issue);
    }
}
```

## Useful Constants

```nyx
# Memory
1 * 1024 = 1 KiB
1 * 1024 * 1024 = 1 MiB
1 * 1024 * 1024 * 1024 = 1 GiB

# Registers  
RSP, RIP, RAX, RBX, RCX, RDX, RSI, RDI, R8-R15

# Control Registers
CR0, CR3, CR4, CR8  (XCR0 for extended state)

# Physical Addresses
LAPIC_BASE = 0xFEE00000
IOAPIC_BASE = 0xFEC00000
TPM_BASE = 0xFED40000
HPET_BASE = 0xFED00000
SMI_PORT = 0xB2

# ISA Ports
PIC_MASTER = 0x20-0x21
PIC_SLAVE = 0xA0-0xA1
PIT_PORT = 0x40-0x43
RTC_PORT = 0x70-0x71
PS2_PORT = 0x60-0x64
DMA_PORT = 0x00-0x7F
```

---

**Nyx Hypervisor v2.0 — Complete Feature Set**
