# Nyx Hypervisor — Integration & Deployment Guide

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│           GUEST OPERATING SYSTEM (UEFI/BIOS Boot)            │
├──────────────────────────────────────────────────────────────┤
│  Exception Handler │ Error Recovery │ Watchdog & Isolation    │
├──────────────────────────────────────────────────────────────┤
│  vCPU Scheduler │ Interrupt Delivery │ Context Switching      │
├──────────────────────────────────────────────────────────────┤
│                    HYPERVISOR CORE (vm.ny)                   │
│  vmx.run() / svm.run() │ Exit Dispatch │ Device Emulation    │
├──────────────────────────────────────────────────────────────┤
│                   DEVICE MODEL (vm_devices.ny)               │
│ PIC/PIT/RTC │ UART │ DMA │ PCI Config │ ISA Chipset         │
│ AHCI │ Virtio-Blk │ E1000 │ Virtio-Net │ Bochs-GPU           │
│ LAPIC │ IOAPIC │ HPET │ TPM 2.0 │ ACPI PM                   │
├──────────────────────────────────────────────────────────────┤
│                    HARDWARE ABSTRACTION                      │
│   VMX (Intel) │ SVM (AMD) │ EPT/NPF Paging │ MSR/CPUID      │
├──────────────────────────────────────────────────────────────┤
│                  PRODUCTION LAYER (Integration)              │
│                                                              │
│  Error Handling      TPM 2.0           Migration            │
│  (vm_errors.ny)      (vm_tpm.ny)       (vm_migration.ny)    │
│                                                              │
│  Advanced ACPI       Hotplug           Logging/Debug        │
│  (vm_acpi_adv.ny)    (vm_hotplug.ny)   (vm_logging.ny)      │
│                                                              │
│  Performance Monitor Integration Layer (vm_production.ny)   │
│  (vm_metrics.ny)     + FluentAPI  + Examples                │
└──────────────────────────────────────────────────────────────┘
```

## Module Dependency Graph

```
vm_production.ny
    ├─→ vm.ny (Core VM)
    │    ├─→ hypervisor.ny (VMX/SVM)
    │    ├─→ vm_devices.ny (Devices)
    │    ├─→ vm_bootloader.ny (BIOS/UEFI)
    │    └─→ vm_acpi.ny (ACPI tables)
    │
    ├─→ vm_errors.ny (Exception handling)
    ├─→ vm_tpm.ny (Trusted computing)
    ├─→ vm_acpi_advanced.ny (Advanced power/thermal)
    ├─→ vm_migration.ny (Live migration)
    ├─→ vm_hotplug.ny (PCI hot-plug)
    ├─→ vm_logging.ny (Debugging/logging)
    └─→ vm_metrics.ny (Performance monitoring)
```

## Feature Integration Checklist

### Core System Integration

- [x] **Boot Path Selection**
  - BIOS mode: Real mode 16-bit real mode @ 0xFFF0
  - UEFI mode: Protected/long mode with ACPI tables
  - Device initialization order: PIC → DSA → LAPIC → IOAPIC

- [x] **Interrupt Handling Flow**
  1. Device raises IRQ via `raise_irq(irq_number)`
  2. InterruptRouter routes through PIC/IOAPIC based on mode
  3. vCPU receives interrupt vector
  4. Exception handler optional post-processing
  5. Guest IDT handler executes

- [x] **I/O Routing**
  - Port I/O (0x0-0xFFFF): DeviceBus.io_read/io_write
  - MMIO (0-4GB): DeviceBus.mmio_read/mmio_write
  - Device dispatch via registered address ranges
  - Fault isolation on failed access

- [x] **Memory Management**
  - Guest physical: 0x0 - (memory_size)
  - Host physical: Dynamically allocated
  - EPT/NPF page tables for isolation
  - Dirty tracking bitmap for migration

### Error Recovery Integration

**Exception Context Flow:**
```
Exception Generated
    ↓
ExceptionHandler.handle_exception(type, context)
    ↓
    ├→ DEFAULT HANDLER (if registered)
    │     ↓
    │   RECOVERY STRATEGY
    │
    └→ ERROR LOGGING
          ↓
        Ring Buffer (1024 entries)
          ↓
        Component Filtering
```

**Recovery Strategies Applied:**
- **Page Fault**: Try RESET_VCPU first, then ISOLATE_DEVICE if persistent
- **General Protection**: Pause VM for inspection if logged > 5 times
- **Machine Check**: Automatic SHUTDOWN (critical)
- **Invalid Opcode**: Log and CONTINUE (skip instruction)

**Integration Points:**
1. Embedded in vCPU exception injection path
2. Called from `handle_vmexit()` when guest exception detected
3. Feeds exceptions to logger for auditing
4. Coordinates with Watchdog Timer for timeout recovery
5. Triggers state snapshots for forensic analysis

### TPM Integration

**Boot Sequence:**
```
UEFI Firmware Load
    ↓
TPM Startup (PCRs zeroed)
    ↓
PEI → DXE → BDS phases
    ↓
PCR Extend events
    ├→ PCR[0] = firmware measurements
    ├→ PCR[2] = option ROM measurements
    ├→ PCR[7] = UEFI secure boot state
    └→ PCR[4] = MBR/GPT measurements
    ↓
Operating System Boot
    ↓
Post-boot PCR values locked
```

**Integration Checks:**
- TPM responds at MMIO 0xFED40000
- UEFI calls to TPM_PCR_Extend succeed
- NV storage available for secure boot variables
- GetCapability reports correct PCR count
- Random number generation for OS entropy

### Advanced ACPI Integration

**Power State Transitions:**
```
S0 (Working)
  ↓ [User requests sleep]
S1 (Light sleep)
  ↓ [System idle for 5min]
S3 (Suspend-to-RAM)
  ↓ [User requests hibernate]
S4 (Suspend-to-Disk)
  ↓ [System powered off]
S5 (Soft-Off)
  ↓ [Wake interrupt or user power button]
S0 (Back to working)
```

**Thermal Management:**
```
Temperature Monitor (every 100ms)
    ↓
Passive Cooling [80-95°C]
  ├→ Reduce CPU frequency
  ├→ Activate fan
  └→ Throttle device I/O
    ↓
Critical Thermal [>100°C]
  └→ Force SHUTDOWN
```

**Integration with Guest**
- ACPI tables in UEFI firmware
- Guest queries via Port 0xB2 (SMI) or MMIO
- Button device generates notifications (SCI interrupt)
- Battery/power supply status updated
- Lid switch generates wake events

### Migration Integration

**Live Migration Workflow:**

```
┌─────────────────────────── Precopy Phase ─────────────────────────┐
│ Send memory via iterative transfers (VM running)                  │
│ ┌─ Iteration 1: All pages                                        │
│ │   Dirty tracking enabled
│ ├─ Iteration 2-N: Only dirty pages (< 1% new requests pass)     │
│ │   Check convergence: if (dirty_rate < threshold) converged = true
│ └─ When converged → advance to Phase 2                          │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌────────────── Stop-and-Copy Phase (Brief Pause) ───────────────┐
│ 1. Pause guest vCPUs                                            │
│ 2. Send final dirty pages                                       │
│ 3. Serialize VCPU state (registers, CR0/3/4, EFER)            │
│ 4. Serialize device snapshots                                   │
│ 5. Checkpoint timestamp                                         │
└──────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────── Postcopy Phase (Activation) ──────────────────┐
│ 1. Resume vCPUs on destination (if postcopy enabled)         │
│ 2. Demand-page missing memory on demand                       │
│ 3. Send device state updates                                  │
│ 4. Resume full operation                                      │
└──────────────────────────────────────────────────────────────┘
```

**Integration with VM lifecycle:**
- Dirty tracking enabled before precopy
- Memory snapshot taken before stop-and-copy
- Device snapshots synchronized with VCPU state
- Migration state serialization atomic with pause
- Destination VM restore from serialized state

### Hotplug Integration

**Device Add Workflow:**
```
Enable Hotplug
    ↓
User: vm.dynamic_devices.add_pci_device(device)
    ↓
Controller: Auto-assign PCI bus/slot
    ↓
Bus: Register device I/O ranges
    ↓
Notify: Raise hotplug SCI interrupt
    ↓
Guest: Enumerate new device via PCI CONFIG_ADDRESS
    ↓
Driver: Install, allocate interrupts, setup DMA
    ↓
Complete: Device operational
```

**Device Remove Workflow:**
```
User: vm.dynamic_devices.remove_pci_device(device_id)
    ↓
Controller: Power-down device
    ↓
Notify: Raise hotplug SCI interrupt
    ↓
Guest: Eject via ACPI _EJ0 method
    ↓
Bus: Unregister device I/O ranges
    ↓
Memory: Deallocate device structures
    ↓
Complete: Device removed
```

**Integration Points:**
- Hotplug controller at MMIO 0xAE00
- Uses PCI hotplug interrupt (typically IRQ5)
- Coordinates with dynamic device manager
- Failure recovery isolates faulty devices

### Logging Integration

**Logging Hierarchy:**
```
Logger (Central)
    ├─→ Component Filters
    │    ├─→ device (DEBUG level)
    │    ├─→ guest (INFO level)
    │    ├─→ migration (WARN level)
    │    └─→ * (default: INFO)
    │
    ├─→ Output Channels
    │    ├─→ Syslog
    │    ├─→ File
    │    ├─→ Console
    │    └─→ Network
    │
    ├─→ Ring Buffer (10,000 entries)
    │    └─→ Latest logs retained for diagnostics
    │
    └─→ Performance Tracer
         ├─→ Spans (boot, migration, critical paths)
         ├─→ Events (I/O complete, interrupt inject)
         └─→ Statistics (latency, throughput)
```

**Integration Points:**
- All modules call `logger.info/warn/error`
- Device state changes logged
- Exception handler logs before recovery
- Migration logs phase transitions
- Performance critical paths traced
- Bottleneck detection uses trace data

### Metrics Integration

**Collection Points:**
```
vCPU Execution
    ├→ Count VM exits (total, by type)
    ├→ Measure exit time (min/avg/max)
    └→ Record vCPU context switch latency

Device I/O
    ├→ Count I/O operations (read/write)
    ├→ Measure I/O latency (histogram)
    └→ Track device-specific metrics

Memory Management
    ├→ Dirty page rate (during migration)
    ├→ Memory pressure (allocation failures)
    └→ Cache hit rates (if applicable)

Network Devices
    ├→ Packet count (RX/TX)
    ├→ Byte throughput
    ├→ Error rates
    └→ Pipeline depth

Disk Devices
    ├→ Operation count
    ├→ Latency distribution
    ├→ Queue depth
    └→ Bandwidth utilization
```

**Bottleneck Identification Algorithm:**
```
Snapshot metrics every 100ms
    ↓
Calculate rates (exits/sec, bytes/sec, etc.)
    ↓
Compare to thresholds:
    ├→ Exit rate > 100k/sec → IO_BOTTLENECK
    ├→ Disk latency > 1ms → DISK_BOTTLENECK  
    ├→ Network errors > 0.1% → NETWORK_BOTTLENECK
    ├→ Memory allocation failures > 0 → MEMORY_BOTTLENECK
    └→ Thermal throttling active → THERMAL_BOTTLENECK
    ↓
Aggregate over last N snapshots
    ↓
Generate severity score and recommendations
```

## Deployment Scenarios

### Scenario 1: Development VM

```nyx
let dev_vm = ProductionVMBuilder()
    .memory(4 * 1024**3)              # 4GB adequate
    .cpus(4)                          # 4 vCPUs
    .bios("seabios.bin")              # Legacy for Linux dev work
    .disk("dev.qcow2")                # QCOW2 for snapshots
    .gpu(true)                        # Enable graphics
    .with_logging()                   # Debug logging
    .with_debug_symbols("app.dbg")   # Load debug symbols
    .build();
```

**Recommended Configuration:**
- BIOS mode (faster boot for development)
- Single NIC (e1000)
- Logging at DEBUG level
- Periodic snapshots (via .snapshot())
- Breakpoints on critical functions

### Scenario 2: Windows Production Server

```nyx
let windows_server = ProductionVMBuilder()
    .memory(16 * 1024**3)             # 16GB for server workload
    .cpus(8)                          # 8 vCPUs
    .uefi("OVMF_WIN.fd")              # Windows UEFI firmware
    .disk("system.vhdx")              # VHDX format
    .disk("data.vhdx")                # Additional storage
    .ahci(true)                       # AHCI for multiple drives
    .nic("e1000")                     # Primary NIC
    .nic("e1000")                     # Redundant NIC (teaming)
    .gpu(false)                       # Headless
    .with_tpm()                       # Secure boot
    .with_error_handling()            # Fault recovery
    .with_logging()                   # Operational logging
    .with_metrics()                   # Performance monitoring
    .with_pci_hotplug()               # Add storage dynamically
    .build();
```

**Recommended Configuration:**
- UEFI + TPM 2.0 for Windows compatibility
- Metrics at WARN+ level (reduce overhead)
- Hotplug enabled for storage expansion
- Error isolation enabled
- Remote syslog for centralized logging

### Scenario 3: Linux with Live Migration

```nyx
let migratable_linux = ProductionVMBuilder()
    .memory(8 * 1024**3)              # 8GB
    .cpus(4)                          # 4 vCPUs
    .uefi("OVMF.fd")                  # UEFI for modern Linux
    .disk("root.img")                 # Root filesystem
    .disk("var.img")                  # Writable /var
    .nic("virtio")                    # High-perf VIRTIO NIC
    .gpu(false)                       # Headless
    .with_error_handling()
    .with_logging()
    .with_metrics()
    .with_live_migration()            # Enable migration
    .build();
```

**Recommended Configuration:**
- UEFI + virtio devices for optimal performance
- Dirty tracking enabled continuously
- Metrics focus on memory/I/O patterns
- Live migration precopy convergence threshold 5%
- Hotplug optional (not needed for Linux)

### Scenario 4: High-Availability Cluster VM

```nyx
let ha_vm = ProductionVMBuilder()
    .memory(32 * 1024**3)             # 32GB high availability
    .cpus(16)                         # 16 vCPUs for services
    .uefi("OVMF_HA.fd")               # HA-optimized firmware
    .disk("ssd0.nvme")                # NVMe for low latency
    .disk("ssd1.nvme")                # Mirrored storage
    .nic("e1000")                     # Primary network
    .nic("e1000")                     # Heartbeat network
    .nic("virtio")                    # High-speed data network
    .ahci(false)                      # Use direct NVMe if possible
    .with_tpm()                       # Security critical
    .with_error_handling()            # Fault recovery essential
    .with_logging()                   # Comprehensive audit trail
    .with_metrics()                   # Real-time monitoring
    .with_live_migration()            # Continuous availability
    .with_performance_tracing()       # Performance SLO tracking
    .build();
```

**Recommended Configuration:**
- Maximum compute resources
- Multiple NIC paths for redundancy
- All logging enabled (INFO level minimum)
- Metrics collection with export to monitoring system
- Watchdog timeout 2-3 seconds (aggressive)
- Error isolation critical for resilience

## Best Practices

### 1. Boot Mode Selection

**Choose UEFI when:**
- Running Windows 11 (requires UEFI)
- Need secure boot with TPM
- Support for >2TB disks
- Modern driver support needed
- UEFI Shell debugging valuable

**Choose BIOS when:**
- Legacy Linux compatibility needed
- Minimal firmware overhead desired
- Custom real-mode code required
- Compatibility with old drivers critical

### 2. Memory Sizing

```
Linux: Base=512MB + (1.2× data set size)
Windows: Base=2GB + (1.5× data set size)
Database: Base=4GB + (2× working set)
Development: Base=4GB + (reserved for growth)
```

### 3. Logging Strategy

**For Development:**
```nyx
logger.set_level(LOG_LEVEL_DEBUG);
logger.register_component("*", LOG_LEVEL_TRACE);
logger.register_output(fn(level, comp, msg) {
    printf("[%s][%s] %s\n", level, comp, msg);
});
```

**For Production:**
```nyx
logger.set_level(LOG_LEVEL_WARN);
logger.register_component("device", LOG_LEVEL_INFO);
logger.register_component("migration", LOG_LEVEL_DEBUG);
logger.register_output(syslog_callback);  # Send to syslog
```

**For High-Security:**
```nyx
logger.set_level(LOG_LEVEL_INFO);
logger.enable_audit_trail();  # Sign all entries
logger.register_output(remote_syslog);  # Centralized
logger.set_rotation("hourly");  # Rotate logs
```

### 4. Error Recovery Strategy

```nyx
# Aggressive recovery (for fault-tolerant VMs)
error_handler.set_recovery_strategy(
    EXCEPTION_PAGE_FAULT,
    RECOVERY_RESET_VCPU
);
error_handler.set_recovery_strategy(
    EXCEPTION_GENERAL_PROTECTION,
    RECOVERY_PAUSE_VM
);

# Conservative recovery (for mission-critical)
error_handler.set_recovery_strategy(
    EXCEPTION_PAGE_FAULT,
    RECOVERY_SNAPSHOT_RESTORE
);
error_handler.set_recovery_strategy(
    EXCEPTION_MACHINE_CHECK,
    RECOVERY_SHUTDOWN  # Always for MC
);

# Watchdog aggressive
watchdog.set_timeout(2000);  # 2 second timeout
```

### 5. Migration Planning

```nyx
# Before migration
vm.dirty_tracker.enable_tracking();
vm.metrics.take_snapshot();  # Baseline metrics

# Monitor convergence
let max_iterations = 10;
let convergence_threshold = 0.01;  # 1%

new_vm = migrate_vm(vm, dest_host, {
    max_iterations: max_iterations,
    threshold: convergence_threshold,
    downtime_type: DOWNTIME_BRIEF  # < 1 second
});

# Post-migration verification
assert(new_vm.memory matches vm.memory);
assert(new_vm.vcpu_state matches vm.vcpu_state);
assert(new_vm.device_snapshots match vm.device_snapshots);
```

### 6. Performance Optimization

```nyx
# Check bottlenecks regularly
let report = vm.metrics.get_performance_report();
for (bottleneck in report.bottlenecks) {
    printf("Bottleneck: %s (%s)\n", 
        bottleneck.type, 
        bottleneck.severity
    );
    printf("  Suggestion: %s\n", bottleneck.recommendation);
}

# Adjust configuration based on findings
if ("vm_exit_rate" in bottlenecks) {
    # Too many exits - possibly inefficient emulation
    # Solution: Check device driver, consider virtio
}

if ("disk_latency" in bottlenecks) {
    # Slow disk I/O
    # Solution: Enable AHCI, check I/O scheduler
}

if ("network_errors" in bottlenecks) {
    # Network issues
    # Solution: Switch to virtio-net, check MTU
}
```

### 7. Monitoring Integration

**Export metrics to external systems:**

```nyx
let prometheus_callback = fn(metric_name, value, labels) {
    # Export in Prometheus text format
    let line = metric_name + "{";
    for (label in labels) {
        line += label + "=\"" + labels[label] + "\",";
    }
    line = trim_end(line, ",") + "} " + value;
    send_to_prometheus(line);
};

vm.metrics.register_export_callback(prometheus_callback);
```

## Troubleshooting Guide

| Symptom | Cause | Solution |
|---------|-------|----------|
| High VM exit rate | Inefficient device emulation | Use virtio instead of legacy devices |
| Guest freeze | Watchdog timeout | Increase timeout or fix resource contention |
| Page fault loop | Memory mapping issue | Check EPT/NPF setup, enable debug logging |
| TPM failures | UEFI firmware mismatch | Re-verify OVMF TPM support |
| Migration hangs | Convergence threshold unreachable | Reduce threshold or increase iterations |
| Device hotplug not detected | SCI interrupt missing | Check IOAPIC setup for hotplug IRQ |
| Log buffer overflow | Too much I/O in short time | Reduce log level or filter components |
| Thermal throttling | CPU overheat | Increase vCPU count or reduce guest CPU affinity |

## Security Hardening

### UEFI + Secure Boot + TPM Stack

```nyx
let secure_vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF_SECURE.fd")    # UEFI with secure boot
    .with_tpm()                 # Mandatory
    .with_error_handling()      # Fault recovery
    .with_logging()             # Audit trail
    .enable_iommu()             # Device isolation (future)
    .build();

# Verify secure boot variables
let pk = vm.tpm.read_nv(0x1000001);   # PK (Platform Key)
let kek = vm.tpm.read_nv(0x1000002);  # KEK (Key Encryption Key)
let db = vm.tpm.read_nv(0x1000004);   # DB (Allowed signatures)
assert(pk != null, "Secure boot configured");
```

## Conclusion

The Nyx Hypervisor v2.0 is a feature-complete, production-grade system suitable for cloud, data center, and enterprise deployments. Its modular architecture allows customization while maintaining stability and security.

For support and further documentation, refer to the main README and individual module documentation.

---

**Nyx Hypervisor v2.0 — Integration & Deployment Complete**
