# Nyx Hypervisor — IOMMU & Device Pass-Through Guide

## Overview

IOMMU (Input/Output Memory Management Unit) enables direct hardware device assignment to guest VMs with full isolation and protection. This guide covers Intel VT-d and AMD-Vi implementation in Nyx.

## Key Capabilities

### Intel VT-d Compatible
- 4-level page table hierarchy (PML4/PDPT/PD/PT)
- DMA remapping for device memory access
- Interrupt remapping for MSI/MSI-X
- Per-device domain isolation
- Queued invalidation

### AMD-Vi Compatible
- IOMMU page tables (identical hierarchy to VT-d)
- Guest Virtual Address translation
- Device access control
- I/O page fault handling
- Per-domain ASID management

### Device Isolation Modes

```
STRICT:   Each device in isolated domain
          ├─ Device cannot access other VMs
          ├─ Host cannot access device DMA
          ├─ Fault isolation: Faults quarantine device
          └─ Performance: Slight latency due to TLB invalidation

SHARED:   Devices in shared domains
          ├─ Multiple devices can share domain
          ├─ Reduces IOMMU overhead
          ├─ Less isolation but better performance
          └─ Good for storage and network together

UNMANAGED: No IOMMU protection
          ├─ Raw hardware access
          ├─ Maximum performance
          ├─ No isolation (risky)
          └─ Only for trusted environments
```

## Architecture

### Page Table Structure

```
Guest Physical Address (48-bit):
┌─────────────────────────────────────────────────┐
│ Bits 47-39 │ Bits 38-30 │ Bits 29-21 │ Bits 20-12 │
│ PML4 Index │ PDPT Index │  PD Index  │   PT Index  │
└─────────────────────────────────────────────────┘
                    ↓
        IOMMU Page Table Walk
                    ↓
Host Physical Address (40-bit)
┌──────────────────────────────┐
│ Bits 39-12 │ Bits 11-0      │
│ Page Frame │ Access Flags   │
└──────────────────────────────┘

Access Flags:
  Bit 0: Present
  Bit 1: Write Enable
  Bit 2: Reserved (for SW use)
  ... (cache control, etc)
```

### Interrupt Remapping

```
MSI/MSI-X from Device
    ↓
Interrupt Remapping Table [IRQ Index]
    ├─ Vector: Interrupt vector (0-255)
    ├─ Delivery Mode: Fixed, Lowest, SMI, NMI, INIT
    ├─ Destination: LAPIC ID or x2APIC ID
    └─ Flags: Mask, Present, etc.
    ↓
Guest LAPIC Receives Remapped Interrupt
```

## Usage Patterns

### Pattern 1: Single Device Pass-Through (NIC)

```nyx
let vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .disk("system.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")  # NIC at 03:00.0
    .with_logging()
    .with_error_handling()
    .build();

# IOMMU creates isolated domain for NIC
# Guest driver accesses hardware directly:
# - Read/write NIC registers (MMIO)
# - DMA to/from guest memory via IOMMU
# - Interrupts remapped by IOMMU

vm.run();
```

### Pattern 2: Multiple Devices with Isolation

```nyx
let vm = ProductionVMBuilder()
    .memory(16 * 1024**3)
    .cpus(8)
    .uefi("OVMF.fd")
    .disk("data.qcow2")
    .with_iommu()
    .passthrough_device(0x0100, "STRICT")  # GPU in domain 1
    .passthrough_device(0x0300, "STRICT")  # NIC in domain 2
    .with_error_handling()
    .build();

# Each device in separate domain:
# ├─ GPU faults don't affect NIC
# ├─ NIC faults don't affect GPU
# └─ Host remains protected from both
```

### Pattern 3: Shared Domain (Related Devices)

```nyx
let vm = ProductionVMBuilder()
    .memory(12 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .with_iommu()
    .passthrough_device(0x0400, "SHARED")  # Storage controller 1
    .passthrough_device(0x0401, "SHARED")  # Storage controller 2
    # Both storage devices in same domain = lower overhead
    .with_metrics()
    .build();
```

### Pattern 4: Query IOMMU Status

```nyx
# Check what's assigned
let status = vm.iommu_mgr.get_status();
printf("IOMMU Enabled: %s\n", status.enabled);
printf("Domains: %d\n", status.domains);
printf("Devices: %d\n", status.devices);
printf("Fault Events: %d\n", status.fault_events);

# Report on device
let device = vm.iommu_mgr.get_passthrough_device(0x0300);
if (device != null) {
    printf("Device 0x0300 operational: %s\n", device.is_operational());
    printf("Device faults: %d\n", device.fault_count);
}
```

### Pattern 5: Manual Domain Management

```nyx
# Advanced: Create custom domains
let iommu = vm.iommu_mgr;

# Create isolated domain for sensitive device
let secure_domain = iommu.create_domain("STRICT");

# Assign device
iommu.assign_device(0x0200, secure_domain.domain_id);

# Map guest memory regions for DMA
iommu.map_guest_memory(
    domain_id = secure_domain.domain_id,
    guest_phys = 0x10000000,
    host_phys = 0x40000000,
    size = 256 * 1024 * 1024,  # 256MB
    flags = 0x3  # Read+Write
);

# Configure interrupt remapping
let irq_remapping = vm.iommu_mgr.iommu_controllers[0].passt_mgr;
irq_remapping.setup_interrupt_remap(
    device_id = 0x0200,
    irq_index = 0,
    vector = 32,  # Interrupt vector
    destination = 0  # LAPIC 0
);
```

## DMA Handling

### Guest DMA Access

```
Guest Application
    ↓ [DMA request via device driver]
Physical Device (with IOMMU)
    ↓ [Device reads IOMMU context from DMA]
IOMMU Page Table
    ├─ Translate Guest Physical → Host Physical
    ├─ Check access permissions (R/W/X)
    ├─ Check presence bit (mapped vs unmapped)
    └─ Return frame number or trigger fault
    ↓ [Device performs DMA with host physical address]
Host Memory (through IOMMU protection)
```

### Fault Handling

```
Device performs invalid DMA (unmapped address)
    ↓
IOMMU detects fault
    ├─ No mapping for guest physical address
    ├─ Permission violation (W to R-only page)
    └─ Access fault
    ↓
Hypervisor fault handler
    ├─ Record fault event
    ├─ Increment device fault counter
    ├─ If counter > threshold (e.g., 10)
    │   └─ Auto-isolate device (remove from IOMMU)
    └─ Inject device error to guest
    ↓
Guest handles device error
    ├─ Driver detects error register
    ├─ Initiates device reset
    └─ Resumes operation
```

## Security Considerations

### 1. DMA Attacks Prevention

```
Without IOMMU:
  Malicious Device → Direct host memory access → Hypervisor compromise

With IOMMU:
  Malicious Device → IOMMU translation → Isolated guest memory only
```

### 2. Interrupt Masking

```
Without IOMMU:
  Device MSI injection → Arbitrary guest interrupt

With IOMMU:
  Device MSI → Interrupt remapping table → Fixed vector → Safe delivery
```

### 3. Device Isolation

```
VM1 Device (Compr.)   VM2 Hypervisor   VM3 (Secure)
     ↓ (fault)           ↓                  ↓
IOMMU Quarantine     Unaffected         Unaffected
(device only)       (other VM safe)     (other VM safe)
```

## Performance Optimization

### TLB Invalidation

```
When: Page table modified (unmap, remap)
Cost: Full IOMMU TLB flush
Impact: 
  - Few large mappings: Infrequent invalidation
  - Many small mappings: Frequent invalidations
  - Migration with dirty tracking: Minimal (existing pages)

Optimization:
  # Batch unmaps to reduce invalidations
  iommu.map_guest_memory(domain, start, host, 256MB, flags);
  # Single invalidation for entire range
```

### Queued Invalidation

```
Modern IOMMU (VT-d gen 3+):
  - Queued invalidation commands (batch)
  - Asynchronous completion
  - Reduces overhead vs individual invalidations

In Nyx:
  # Automatically batches invalidations
  invalidate_tlb()  # Async batch operation
```

### Symmetric Domains

```
Related devices → shared domain:
  - Storage controllers together
  - Function of same adapter
  - Network bonding (multiple NICs)

Result:
  - Fewer TLB entries
  - Single invalidation for related changes
  - Lower overhead
```

## Troubleshooting

### "Device not operational"

```
Symptom: Device reports operational() == false
Cause: Fault count exceeded threshold (default 10)
Solution:
  1. Check device logs: tail /var/log/kern
  2. Verify DMA mappings: iommu.get_status()
  3. Reset device: Device removal + re-add
  4. Increase threshold (if transient issues):
     device.max_faults = 20
```

### "IOMMU fault events high"

```
Symptom: Fault count increasing rapidly
Causes:
  1. Guest driver bug (unmapped DMA access)
  2. Memory fragmentation → unmapped regions
  3. IOMMU configuration mismatch
Solution:
  1. Check guest dmesg for IOMMU errors
  2. Enable debug logging: logger.set_level(DEBUG)
  3. Check memory layout: free -h + /proc/iomem
  4. Review mapping configuration
```

### "Guest can't access device"

```
Symptom: Guest driver can't probe device
Causes:
  1. Device not in PCI enumeration
  2. Interrupt routing broken
  3. MMIO mapping missing
Solution:
  1. Verify device in lspci (guest): lspci -v
  2. Check IOMMU domain assignment: vm.iommu_mgr.get_passthrough_device()
  3. Enable interrupt remapping if needed
  4. Check interrupt vector assignment
```

### "High latency with pass-through"

```
Symptom: Device performance degraded
Causes:
  1. Frequent TLB invalidations
  2. Interrupt remapping overhead
  3. Device in STRICT domain (unnecessary isolation)
Solutions:
  1. Batch related devices in SHARED domain
  2. Reduce memory mapping changes (use large pages)
  3. Use SHARED isolation if multiple devices related
  4. Profile with metrics: vm.metrics.disk_latency
```

## Examples by Use Case

### Network Appliance (Multiple NICs)

```nyx
let appliance_vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .disk("appliance.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")  # WAN NIC 1
    .passthrough_device(0x0301, "STRICT")  # WAN NIC 2
    .passthrough_device(0x0302, "SHARED")  # LAN NIC (shared ok)
    .passthrough_device(0x0303, "SHARED")  # MGMT NIC (shared ok)
    .with_error_handling()
    .with_metrics()
    .build();

# WAN NICs in strict domains for traffic isolation
# LAN/MGMT in shared domain for internal communication
```

### GPU Workstation

```nyx
let gpu_vm = ProductionVMBuilder()
    .memory(32 * 1024**3)
    .cpus(16)
    .uefi("OVMF_WORKSTATION.fd")
    .disk("workstation.qcow2")
    .with_iommu()
    .passthrough_device(0x0100, "STRICT")  # Primary GPU (vega/rtx)
    .passthrough_device(0x0101, "STRICT")  # Audio codec
    .passthrough_device(0x0300, "STRICT")  # Management NIC
    .with_logging()
    .with_metrics()
    .build();

# GPU + audio + NIC all direct access
# High performance rendering @ near-native speed
```

### Storage Server

```nyx
let storage_vm = ProductionVMBuilder()
    .memory(64 * 1024**3)
    .cpus(24)
    .uefi("OVMF.fd")
    .with_iommu()
    # NVMe controllers in shared domain (all storage together)
    .passthrough_device(0x0400, "SHARED")  # NVMe controller 1
    .passthrough_device(0x0401, "SHARED")  # NVMe controller 2
    .passthrough_device(0x0402, "SHARED")  # NVMe controller 3
    .passthrough_device(0x0403, "SHARED")  # NVMe controller 4
    # Network in separate domain
    .passthrough_device(0x0300, "STRICT")  # Management NIC
    .passthrough_device(0x0301, "STRICT")  # Storage NIC
    .with_error_handling()
    .with_live_migration()    # Migration + IOMMU compatible
    .with_metrics()
    .build();

# Storage controllers batched for efficiency
# Network isolated for security
# Live migration moves entire device state
```

## Performance Benchmarks

| Operation | Latency | Notes |
|-----------|---------|-------|
| Device register access (MMIO) | 500ns-2μs | Through IOMMU translation |
| DMA read (small) | 1-5μs | IOMMU page walk |
| DMA write (bulk) | 50-500ns/KB | Pipeline efficient |
| TLB invalidation | 1-10μs | Per-device domain flush |
| Interrupt delivery | 1-2μs | Remapping table lookup |

## Comparison with Emulation

```
Property           │ Emulated Device    │ Pass-Through Device
─────────────────────────────────────────────────────────────
Performance        │ 1-10 Mbps (emulated) │ 1-40 Gbps (direct)
Latency            │ 100μs-1ms          │ 1-10μs
CPU overhead       │ High (20-30%)      │ Low (< 5%)
Security           │ Host protected     │ Host + IOMMU
Migration          │ Trivial (snapshot) │ Device state serialization
Device compatibility│ Limited           │ Full hardware support
─────────────────────────────────────────────────────────────
```

## Integration with Other Features

### Live Migration with Pass-Through Devices

```nyx
# Migration preserves device state
vm.dirty_tracker.enable_tracking();
vm.migration_mgr.start_iterative_precopy(vm, "destination");

# Device state serialized atomically:
# ├─ Device registers
# ├─ Queued commands (if applicable)
# ├─ IOMMU page table snapshot
# └─ Interrupt routing tables

# On destination: Devices re-assigned to same domains
```

### Error Recovery with Pass-Through

```nyx
# On device fault:
let fault_resp = vm.iommu_mgr.report_dma_fault(0x0300);
# → DEVICE_ISOLATED (auto quarantine)

# Host remains operational
# Guest either:
# 1. Resets device via ACPI _RST method
# 2. Loads alternative driver
# 3. Continues without device
```

### Hotplug & Pass-Through

```nyx
# Unlike emulated device hotplug, pass-through devices
# require guest driver support for hot-removal
# (No ACPI _EJ0 for hardware devices)

# Better approach: Managed removal via ACPI
vm.iommu_mgr.remove_device(0x0300);  # Logical remove
# Guest detects via ACPI event
```

## Conclusion

IOMMU support in Nyx enables:
- ✅ Production-grade direct hardware access
- ✅ Strong isolation between VMs
- ✅ Near-native performance
- ✅ Secure device assignment
- ✅ Compatible with other features (migration, hotplug, etc.)

For security-critical deployments, STRICT isolation on sensitive devices is recommended. For performance-critical workloads, SHARED domains on related devices optimize IOMMU overhead.

---

**Nyx IOMMU — Enterprise-Grade Device Pass-Through**
