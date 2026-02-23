# IOMMU Technical Specification v2.0

## 1. Overview

**Nyx IOMMU Implementation** provides hardware-agnostic device pass-through with:
- Intel VT-d (Virtualization Technology for Directed I/O) compatibility
- AMD-Vi (AMD I/O Virtualization) compatibility  
- Full DMA remapping with 4-level page tables
- Interrupt remapping for MSI/MSI-X devices
- Per-device isolation and fault handling
- Production-grade security and robustness

## 2. Memory Architecture

### 2.1 Virtual Address Space

```
IOMMU Address Translation:
┌────────────────────────────────────────────────────────┐
│ Guest Physical Address (GPA) / Device Virtual Address  │
│                    (48-bit address)                    │
│   Bits 47-39     Bits 38-30     Bits 29-21  Bits 20-0 │
│   PML4 Index     PDPT Index     PD Index    Offset     │
└────────────────────────────────────────────────────────┘
                         ↓ IOMMU Walk
┌────────────────────────────────────────────────────────┐
│    Host Physical Address (HPA) / System Memory Address │
│                    (40-bit address)                    │
│       Bits 39-12          Bits 11-0                    │
│    Page Frame Number      Page Offset                  │
└────────────────────────────────────────────────────────┘
```

### 2.2 Page Table Structure

```
PML4 Entry (Page Map Level 4)
┌─ Bit 0: Present (P)
├─ Bit 1: Writable (W)
├─ Bit 2: Reserved for Software
├─ Bit 3: Reserved for Software
├─ Bit 4: Reserved for Software
├─ Bit 5: Accessed (A)
├─ Bit 6: Cache Disable (CD)
├─ Bit 7: Write-Through (WT)
├─ Bit 8: User-Accessible (U)
├─ Bit 9: Execute Disable (XD)
├─ Bits 10-11: Reserved
├─ Bits 12-51: Page Frame Number (PFN)
├─ Bits 52-61: Reserved for Software
└─ Bits 62-63: Protection Key (if supported)

Level 4 translations identical for PDPT, PD, PT entries.

Address of next level table = (PFN << 12) | flags
```

### 2.3 Page Table Levels

| Level | Entry | Size | Indices | GPA Coverage |
|-------|-------|------|---------|--------------|
| PML4 | 512 | 4KB | 0-511 | Bits 47-39 |
| PDPT | 512 | 4KB | 0-511 | Bits 38-30 |
| PD | 512 | 4KB | 0-511 | Bits 29-21 |
| PT | 512 | 4KB | 0-511 | Bits 20-12 |

**Total Coverage:** 512^4 = 281 trillion entries (2^48 = 256TB address space)

### 2.4 Memory Hierarchy

```
System Memory
├─ PML4 Table Entry (64 bits)
├─ PDPT Table Entries[512] (4KB)
├─ PD Table Entries[512] (4KB) × N
├─ PT Table Entries[512] (4KB) × N²
└─ Physical Pages[4KB] × N³

Example 1GB Mapping:
├─ 1 PML4 entry (already allocated)
├─ 1 PDPT entry
├─ 1 PD entry
├─ 256 PT entries (covers 256 × 4KB = 1MB per PT)
└─ 262,144 × 4KB physical pages

On-demand allocation: Tables created only when mapping extends beyond existing coverage
```

## 3. IOMMU Domain Model

### 3.1 Domain Types

```
Domain:
├─ ID (0-65535): Unique identifier
├─ Type (STRICT | SHARED | UNMANAGED)
├─ Devices: Set of assigned PCI device IDs
├─ Page Tables: Per-domain IOMMU page table root
├─ Fault Counter: Cumulative DMA faults
└─ Status: ACTIVE | QUARANTINED | DISABLED

STRICT Domain:
├─ One device per domain (or close affinity group)
├─ Faults in device → isolate only that device
├─ Highest security, moderate performance
└─ Use: GPUs, dedicated NICs, storage controllers

SHARED Domain:
├─ Multiple related devices in one domain
├─ Faults in any device → all devices in domain affected
├─ Lower overhead, reduced security isolation
└─ Use: Related storage controllers, bonded NICs, same adapter functions

UNMANAGED Domain:
├─ No IOMMU translation (passthrough at page level)
├─ Direct hardware access, no protection
├─ Lowest latency, no isolation
└─ Use: Trusted environments only (testing, dedicated appliances)
```

### 3.2 Domain Lifecycle

```
VM Creation
    └─ Create domains for each device
       ├─ Allocate unique domain ID
       ├─ Initialize page table root
       └─ Set isolation type (STRICT/SHARED/UNMANAGED)
    ↓
Device Assignment
    └─ Assign device to domain
       ├─ Register in domain device map
       ├─ Create PassThroughDevice wrapper
       └─ Set IOMMU context register
    ↓
Guest Access
    └─ Device → Data access
       ├─ IOMMU translates GPA → HPA
       ├─ Permissions verified (R/W/X)
       └─ Physical page accessed
    ↓
Fault (optional)
    └─ Invalid access detected
       ├─ Record fault event
       ├─ Increment fault counter
       └─ Quarantine if threshold exceeded
    ↓
VM Shutdown
    └─ Clear domain resources
       ├─ Unmap all pages
       ├─ Free page tables
       └─ Release domain ID
```

## 4. Interrupt Remapping

### 4.1 Interrupt Remapping Table

```
IRQ Remapping:
  Device MSI/MSI-X → Interrupt Remapping Table → Guest Vector

Interrupt Remapping Entry (64 bits):
┌─ Bit 0: Present (P)
├─ Bit 1: Fault Processing Disable (FPD)
├─ Bits 2-7: Delivery Mode (Fixed=0, Lowest=1, SMI=2, NMI=4, INIT=5)
├─ Bits 8: Reserved
├─ Bits 9-16: Destination Mode (0=Physical, 1=Logical)
├─ Bits 17-27: Reserved
├─ Bits 28-31: Destination APIC ID (physical mode)
│   or Bits 48-63: Destination x2APIC ID (logical mode)
└─ Bits 32-47: Vector (0-255)

Lookup:
  Index = RemappingTableBase + (Requester ID << 4) + (MSI Vector << 2)
  Remapped Vector = Table Entry[Index].Vector
```

### 4.2 Interrupt Source Requester ID

```
Requester ID (RID) = (Bus, Device, Function)
  Bits 15-8: PCI Bus
  Bits 7-3: PCI Device
  Bits 2-0: PCI Function

Example: 0x0300 → Bus=3, Device=0, Function=0 (3:0.0 in lspci notation)

Lookup into 65536-entry table: (RID << 4) + vector offset
```

### 4.3 MSI Delivery

```
Physical Device
    └─ Firmware enables MSI
       ├─ Assigns MSI vector (e.g., 0x20)
       └─ Sets Requester ID context
    ↓
IOMMU Interrupt Remapping
    └─ Intercepts Device MSI
       ├─ Reads Requester ID (0x0300)
       ├─ Looks up remapping table entry
       │   Entry = Table[0x0300 << 4 + 0x20]
       └─ Translates to guest vector (e.g., 0x20)
    ↓
Guest LAPIC
    └─ Receives remapped interrupt
       ├─ Injects as guest vector
       └─ Guest handler processes
```

## 5. DMA Protection Mechanisms

### 5.1 Access Control Flags

```
Bit 0 - Present (P): If 0, access causes fault
Bit 1 - Writable (W): If 0, write access causes fault
Bit 2 - Read-only permission (RO, for PASID)

Example flags:
  0x1 = Read-only (P=1, W=0)
  0x3 = Read+Write (P=1, W=1)
  0x0 = Unmapped (P=0)
```

### 5.2 Fault Types

```
Fault on GPA Translation:
1. Present Fault: GPA not present in page table (bit 0 not set)
2. Write Fault: Write to read-only page (bit 1 not set)
3. Page Table Walk Fault: Intermediate table entry not present
4. Reserved Bit Fault: Reserved bits set to 1 (hardware checks)
5. Page Table Cache Fault: PASID cache miss (PASID TLB)

Fault reporting:
├─ Fault Status Register: Indicates primary fault type
├─ Fault Address Register: GPA that caused fault
├─ Fault Source Identifier: Which device/function
└─ Fault Reason Code: Specific reason (present, write, reserved, etc.)
```

### 5.3 Fault Response

```
Device DMA → Unmapped address
    ↓
IOMMU Fault Detected
    ├─ Match fault address in page table
    ├─ Determine fault reason
    └─ Record event
    ↓
Fault Handling Options:
1. Silent Drop: Discard request, no interrupt
2. Interrupt: Generate fault interrupt to hypervisor
3. Queued Invalidation: Report in fault queue

In Nyx:
├─ Record in PDomain.fault_counter
├─ Record in Device.fault_events[]
├─ If counter > threshold: Auto-quarantine
└─ Report to host via metrics/logging
```

## 6. Hardware Compatibility

### 6.1 Intel VT-d

**Capability Detection:**
```
CPUID leaf 0x7, ECX bit 10: "VMX"
Check IOMMU base address in DMAR ACPI table
```

**Features Supported:**
- 4-level page tables (identical to spec)
- Interrupt remapping (VT-d 2.0+)
- Page request service (for PASID handling)
- Queued invalidation (VT-d 2.0+)
- Pass-Through mode (no translation)

**Registers (MMIO):**
```
Offset 0x00: Version Register
Offset 0x04: Capabilities Register
Offset 0x08: Extended Capabilities Register
Offset 0x0C: Global Command Register
Offset 0x10: Global Status Register
Offset 0x14: Root Table Address Register
Offset 0x20: Context Command Register
Offset 0x34: IOTLB Invalidation Register
Offset 0x100: Interrupt Remapping Table Address Register
```

### 6.2 AMD-Vi (AMD IOMMU)

**Capability Detection:**
```
CPUID: Family 0x10+ (Opteron, EPYC)
Check IOMMU base address in IVRS ACPI table
```

**Features Supported:**
- 4-level page tables (GCR3, similar structure)
- I/O page fault handling
- ASID per device (equivalent to domain ID)
- Queued invalidation
- Hardware virtualization nested with IOMMU

**Registers (MMIO):**
```
Offset 0x00: Device Table Address Register
Offset 0x08: Command Queue Base Address Register
Offset 0x10: Event Queue Base Address Register
Offset 0x18: Control Register
Offset 0x1C: Exclusion Range Lower Register
Offset 0x20: Exclusion Range Upper Register
```

### 6.3 Compatibility Assurance

```
Nyx IOMMU Layer Implementation:
├─ Abstract IOMMU operations (map, unmap, invalidate)
├─ Detect hardware type at runtime (VT-d vs AMD-Vi)
├─ Provide unified API (IOMMUManager)
└─ Transparent to guest (hardware differences hidden)

Hardware Abstraction:
├─ IOMMUController(type) factory detects capabilities
├─ Register simulation handles vendor-specific MMIO
└─ Page table walk identical across vendors
```

## 7. Performance Characteristics

### 7.1 Page Walk Latency

```
4-Level Page Table Walk:
├─ Miss L1 TLB
├─ Read PML4 entry from L3/memory: ~50-200ns
├─ Read PDPT entry from L3/memory: ~50-200ns
├─ Read PD entry from L3/memory: ~50-200ns
├─ Read PT entry from L3/memory: ~50-200ns
├─ Total: 200-800ns (typically 400ns)
└─ With L1/L2 cache hit: 50-100ns

IOMMU TLB (Translation Lookaside Buffer):
├─ Modern IOMMU: 256-2048 entry TLB
├─ 95% hit rate for typical workloads
├─ Hit latency: ~1-10ns
└─ Miss penalty: Full walk ~400ns

Effective latency (working set fits in TLB):
├─ 5% miss rate × 400ns misses
├─ 95% hit rate × 5ns hits
└─ Average: ~25ns per access
```

### 7.2 Operation Latencies

| Operation | Latency | Notes |
|-----------|---------|-------|
| Page table create (PML4) | <100ns | On-demand allocation |
| Single page map | 100-500ns | Depends on walk depth |
| 1MB bulk map (256 pages) | 10-50μs | Batch optimized |
| Page unmap | 50-200ns | Clear, no alloc |
| 1MB bulk unmap | 5-20μs | Batch with TLB flush |
| IOTLB invalidation | 2-10μs | Per-page or per-domain |
| Interrupt lookup | 50-200ns | Table lookup + delivery |
| Fault handling | 100-1000ns | Depends on type |

### 7.3 Throughput

```
DMA Throughput:
├─ Read-intensive: 95-98% of maximum throughput
├─ Write-intensive: 90-95% of maximum throughput
├─ Mixed R/W: 92-96% of maximum throughput
├─ Random access: 85-90% (higher TLB misses)
└─ Sequential access: 98%+ (TLB reuse)

Maximum DMA rates (with IOMMU):
├─ PCIe 3.0 x16: ~15.7 GB/s (up to 98% achieved)
├─ PCIe 4.0 x16: ~31.5 GB/s (up to 96% achieved)
├─ PCIe 5.0 x16: ~63 GB/s (up to 95% achieved)
```

## 8. Security Model

### 8.1 Threat Model

```
Adversaries:
1. Malicious Device: Performs arbitrary DMA reads/writes
2. Device Driver Bug: Unmapped DMA attempts
3. Guest OS Exploit: Tries to escape via IOMMU misconfiguration
4. Physical Attack: Rogue device plugged into PCIe

Protections:
1. GPA→HPA translation: Device can only access guest memory
2. Fault isolation: Faulty device quarantined automatically
3. Access control: Per-page R/W permissions enforced
4. Interrupt masking: Device interrupts remapped safely
5. Domain isolation: Device cannot affect other VMs
```

### 8.2 Isolation Guarantees

```
STRICT Isolation (One device per domain):
├─ Device A fault → Only Device A isolated
├─ Device A cannot read/write Device B memory
├─ Device A DMA → Only VM memory accessible
└─ Security: Strong (hardware-enforced)

SHARED Isolation (Multiple devices per domain):
├─ Device A fault → All devices in domain affected
├─ Device A and B can coexist (same VM)
├─ Both can access shared VM memory
└─ Security: Moderate (group-level isolation)

No Isolation (UNMANAGED):
├─ Device bypasses IOMMU entirely
├─ Direct access to all system memory
├─ Only use in trusted scenarios
└─ Security: None (administrator responsibility)
```

### 8.3 Protection against Privilege Escalation

```
Without IOMMU:
  Guest Device Driver
    └─ Arbitrary DMA → Hypervisor Memory
       ├─ Hypervisor code pages
       ├─ Other VM memory
       └─ IOMMU page tables

With IOMMU:
  Guest Device Driver
    └─ DMA attempts
       ├─ IOMMU filters all accesses
       ├─ Only guest memory + explicitly mapped regions allowed
       └─ Hypervisor/other VMs protected
```

## 9. Configuration Requirements

### 9.1 BIOS/EFI Settings

```
Intel System:
├─ IOMMU/VT-d: Enabled
├─ Interrupt Remapping: Enabled
├─ DMA Remapping: Enabled
├─ ACS (Access Control Services): Enabled
└─ VT-d Pass-Through: Enabled

AMD System:
├─ IOMMU/SVM: Enabled
├─ I/O TLB: Enabled
├─ Interrupt Remapping: Enabled
├─ Device Exclusion Vector: Disabled (unless specific devices)
└─ ASID: Enabled

PCIe Configuration:
├─ ACS (Access Control Services): Enabled (if available)
├─ Remote Request Peer-to-Peer: Disabled (for STRICT isolation)
└─ Peer-to-Peer: Handled by IOMMU
```

### 9.2 Kernel Requirements

```
Linux Kernel:
├─ CONFIG_IOMMU_SUPPORT=y
├─ CONFIG_INTEL_IOMMU=y (or AMD_IOMMU for AMD)
├─ intel_iommu=on (kernel param) or amd_iommu=on
├─ iommu.strict=1 (optional, enforces strict mode)
└─ vfio-pci driver (optional, for pass-through)

QEMU/KVM:
├─ KVM module: kvm_intel (or kvm_amd)
├─ IOMMU emulation: enabled
├─ pass-through: requires vfio-pci or similar
└─ EPT (Extended Page Tables) for nested paging
```

## 10. Implementation Details (Nyx)

### 10.1 Page Table Implementation

```nyx
struct IOMMUPageTable {
    # Physical address of PML4 table
    pml4_table: *mut [u64; 512];
    
    # Lazy allocation: tables created on first map
    pml4: [IOMMUPageTableLevel; 512];
    
    # Cache for TLB invalidation
    invalidation_bitmap: BitSet; # Track dirtied entries
}

# 4-level tree structure:
struct IOMMUPageTableLevel {
    entries: [PTE; 512];  # Page Table Entry (64-bit)
    subtables: [*IOMMUPageTableLevel; 512];  # Next level
    allocated: bool;
}
```

### 10.2 Domain Implementation

```nyx
struct IOMMUDomain {
    domain_id: u16;
    isolation_type: String;  # "STRICT", "SHARED", "UNMANAGED"
    device_map: HashMap<u16, DeviceState>;
    iommu_table: IOMMUPageTable;
    fault_counter: AtomicU32;
    lock: RwLock;  # Synchronization
}

# Each domain maintains separate page tables
# for complete address space isolation
```

### 10.3 Pass-Through Device

```nyx
struct PassThroughDevice {
    device_id: u16;       # PCI Bus.Device.Function
    domain_id: u16;
    fault_count: AtomicU32;
    max_faults: u32;      # Default 10
    last_fault_time: u64;
    fault_events: VecDeque<FaultEvent>;
}

# Auto-isolation after max_faults exceeded
# All faults recorded for diagnostics
```

### 10.4 Manager API

```nyx
struct IOMMUManager {
    controllers: Vec<IOMMUController>;
    domains: HashMap<u16, IOMMUDomain>;
    devices: HashMap<u16, PassThroughDevice>;
    next_domain_id: u16;
}

# Public API:
impl IOMMUManager {
    assign_device(device_id, isolation_type) -> bool;
    map_guest_memory(domain, gpa, hpa, size, flags);
    translate_address(domain, gpa) -> Result<hpa>;
    record_dma_fault(device_id);
    get_status() -> IOMMUStatus;
}
```

## 11. Deployment Checklist

```
Pre-deployment:
□ Verify IOMMU supported (check CPU model)
□ Check BIOS for IOMMU/VT-d enabled
□ Update BIOS/UEFI to latest version
□ Enable IOMMU in EFI settings
□ Enable Interrupt Remapping
□ Test with dmesg | grep -i iommu

Device Preparation:
□ Identify devices for pass-through (lspci)
□ Check device grouping (lspci -d)
□ Unbind from host drivers (if kernel)
□ Bind to vfio-pci (if kernel-based)
□ Verify device accessible to VM

Configuration:
□ Set ProductionVMBuilder with .with_iommu()
□ Assign devices with .passthrough_device()
□ Configure isolation type (STRICT/SHARED)
□ Test with single device first
□ Monitor fault events during testing

Production:
□ Enable error handling (.with_error_handling())
□ Enable logging (.with_logging())
□ Enable metrics (.with_metrics())
□ Set up monitoring for IOMMU faults
□ Document device grouping for RTO/RPO

Maintenance:
□ Monitor fault rate (should be ~0 in steady state)
□ Track device operational status
□ Plan maintenance windows for problematic devices
□ Review IOMMU performance metrics periodically
```

## 12. Reference

### Specifications
- Intel VT-d Specification (3rd gen): https://www.intel.com/content/dam/develop/external/us/en/documents/vt-directed-io-spec.pdf
- AMD-Vi IOMMU Specification: https://www.amd.com/system/files/TechDocs/24593.pdf
- ACPI DMAR Table: ACPI Spec 6.4+

### Related Features (Nyx)
- Live Migration + IOMMU: Serializes device state
- Hotplug + IOMMU: Manages domain changes atomically
- Error Handling: Automatic restart from IOMMU faults
- Logging/Metrics: Full visibility into IOMMU operations

---

**Nyx IOMMU Technical Specification** — Intel VT-d and AMD-Vi compatible
