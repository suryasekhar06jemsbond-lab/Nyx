# Nyx Hypervisor — Architecture & Design Guide

## Design Philosophy

The Nyx hypervisor is built on five core principles:

1. **Modularity** — Each feature is independent, testable, and composable
2. **Safety** — Comprehensive error handling, fault isolation, and recovery
3. **Performance** — Efficient I/O dispatch, minimal exit overhead, smart caching
4. **Debuggability** — Multi-level logging, symbol support, performance tracing
5. **Production-Ready** — Enterprise features (migration, hotplug, TPM) built-in

## Core Layer Architecture

### 1. Hardware Abstraction Layer (HAL)

```
┌─────────────────────────────────────────────────┐
│     Guest Execution Context (VMCS / VMCB)      │
├─────────────────────────────────────────────────┤
│                                                 │
│  Intel VMX                    AMD SVM           │
│  ├─ VMXON/VMXOFF             ├─ VMCB setup    │
│  ├─ VMCS Fields (48 reads)    ├─ MSRPM/IOPM   │
│  ├─ EPT (4-level)            ├─ ASID mgmt    │
│  ├─ VPID management          └─ NPF (4-level)│
│  └─ 48+ exit codes                            │
│                                                 │
│              Unified Exit Dispatch             │
│       (maps exit reasons to handlers)          │
│                                                 │
│  CPUID  │ MSR  │ CR  │ I/O  │ MMIO │ INT      │
│  HLT    │ RDTSC│ EPT │ PAUSE│ SHUTDOWN       │
│                                                 │
└─────────────────────────────────────────────────┘
    ↑                                          ↑
 Host CPU                              Guest Memory
(VMX/SVM enabled)                      (isolated)
```

**Design Decision: Unified Exit Handler**
- Both VMX and SVM map to single dispatch point
- Reduces code duplication (DRY principle)
- Makes guest behavior consistent across platforms
- Enables future extension (nested VT, etc.)

### 2. Device Bus Architecture

```
┌───────────────── GUEST ADDRESS SPACE ──────────────────┐
│                                                         │
│  0x0000 - 0x9FFF: Conventional memory (640KB)         │
│                                                         │
│  0x9F000: EBDA (Extended BIOS Data Area)              │
│  0xC0000: Video ROM                                   │
│  0xE0000: BIOS ROM (shadow)                           │
│                                                         │
│  0x100000 - 0xFFFFFFF: Extended memory                │
│                                                         │
│  0xFED00000: HPET (High Precision Event Timer)        │
│  0xFED40000: TPM 2.0 (Trusted Platform Module)        │
│  0xFEE00000: LAPIC (Local APIC per vCPU)             │
│  0xFEC00000: IOAPIC (I/O APIC)                        │
│                                                         │
│  0xC0000000-0xFFFFFFFF: MMIO (256MB PCI space)       │
│                                                         │
└─────────────────────────────────────────────────────────┘
         ↑
┌─────────────────── DEVICE BUS ────────────────────────┐
│                                                        │
│  I/O Port Space (0x0000-0xFFFF):                      │
│  ├─ 0x10-0x1F: DMA4                                  │
│  ├─ 0x20-0x21: PIC Master                            │
│  ├─ 0x40-0x43: PIT (programmable timer)              │
│  ├─ 0x60-0x64: PS/2 Controller                       │
│  ├─ 0x70-0x71: RTC (real-time clock)                 │
│  ├─ 0xB2-0xB3: APM / SMI                             │
│  ├─ 0xCF8-0xCFF: PCI Config Space                    │
│  ├─ 0x1F0-0x1F7: IDE Controller (primary)            │
│  ├─ 0x170-0x177: IDE Controller (secondary)          │
│  └─ 0x3F8-0x3FF: UART/Serial (COM1)                  │
│                                                        │
│  Interrupt Routing:                                    │
│  ├─ ISA IRQ0-15 → PIC 8259                          │
│  ├─ PIC → IOAPIC pin mapping                         │
│  ├─ IOAPIC → LAPIC per-vCPU delivery               │
│  └─ LAPIC [EOI] → IRQ ack                           │
│                                                        │
└────────────────────────────────────────────────────────┘
         ↑
  Host I/O Dispatch
  (physical device or emulated)
```

**Design Decision: Hierarchical Interrupt Routing**
- PIC handles legacy ISA devices
- IOAPIC adds modern interrupt routing
- LAPIC provides per-vCPU interrupt delivery
- Allows gradual transition from ISA → PCI → APIC devices

### 3. Memory Management Model

```
Guest Physical Memory (0x0 - max_guest_mem)
    ↓
    ├─→ Non-paging mode
    │   └─→ 1:1 identity (PA = LA)
    │
    └─→ Paging mode
        ├─→ Guest page tables (in guest memory)
        │   └─→ Guest Linear Address → Guest Physical
        │
        └─→ EPT / NPF tables (in hypervisor)
            └─→ Guest Physical → Host Physical

Dirty Tracking bitmap:
    1 bit per page (4KB)
    Total: (memory_size / 4KB) bits
    Example: 1GB VM = 262,144 bits = 32 KB bitmap
```

**Design Decision: Guest Isolated Memory**
- Separate allocations for guest and host prevents information leakage
- EPT/NPF provides transparent address translation
- Dirty bitmap enables efficient migration
- Page table walk emulation for nested paging

### 4. vCPU State Model

```
┌─────────────────────────────────────────┐
│     vCPU State (per hypervisor)         │
├─────────────────────────────────────────┤
│ Registers: RAX-R15, RIP, RSP, RFLAGS   │
│ Segments: ES, CS, SS, DS, FS, GS, LDTR│
│ Control: CR0, CR2, CR3, CR4, CR8, EFER│
│ MSRs: EFER, LSTAR, STAR, FSBASE, etc. │
├─────────────────────────────────────────┤
│ Execution State:                        │
│ ├─ RUNNING (executing guest code)     │
│ ├─ PENDING_EXIT (about to exit)       │
│ ├─ EXITED (waiting for handler)       │
│ ├─ HALTED (HLT instruction)           │
│ ├─ PAUSED (debugger breakpoint)       │
│ └─ FAULTED (exception, recovery)      │
├─────────────────────────────────────────┤
│ Interrupt State:                        │
│ ├─ pending_interrupts (queue)          │
│ ├─ interrupt_priority (vector)         │
│ ├─ interrupt_shadow (after STI/MOVSS)  │
│ └─ nmi_pending (non-maskable interrupt)│
├─────────────────────────────────────────┤
│ Performance Metrics:                    │
│ ├─ total_exits (VM exit count)        │
│ ├─ total_instructions (retired)        │
│ ├─ total_cycles (execution time)       │
│ └─ cycles_per_exit (efficiency)        │
└─────────────────────────────────────────┘
```

**Design Decision: Separate Execution State Machine**
- Explicit states prevent invalid transitions
- Transition callbacks enable hooks (e.g., for debugger)
- Decouples execution logic from guest registers
- Enables safe context switching

## Feature Layer Architecture

### 1. Error Handling (Fault Tolerance)

```
Exception Hierarchy
    ↓
ExceptionContext
    ├─ exception_type (DIV0, PF, GP, etc.)
    ├─ guest_state (RIP, CR3, registers)
    ├─ error_code (if applicable)
    └─ retry_count (for exponential backoff)
    ↓
ExceptionHandler Registry
    ├─ Default handler per exception type
    └─ Custom handlers (optional)
    ↓
Recovery Strategy Decision
    ├─ RECOVERY_IGNORE → Log and continue
    ├─ RECOVERY_RESET_DEVICE → Isolate device
    ├─ RECOVERY_RESET_VCPU → Rewind state
    ├─ RECOVERY_HARD_RESET → Full VM reset
    ├─ RECOVERY_PAUSE_VM → Freeze for inspection
    ├─ RECOVERY_SNAPSHOT_RESTORE → Time-travel
    ├─ RECOVERY_ISOLATE_DEVICE → Quarantine
    └─ RECOVERY_SHUTDOWN → Graceful exit
    ↓
Execution
    └─ Apply recovery, log, call callbacks
```

**Design Decision: Context-Based Recovery**
- Decisions based on exception type, not just guest state
- Configurable per-exception recovery strategy
- Ring buffer stores last 1024 exceptions for forensics
- Watchdog prevents infinite retries

### 2. TPM 2.0 (Cryptographic Trust)

```
TPM2.0 Command Flow
    ↓
CRB Interface (Command Response Buffer)
    ├─ Command buffer (4KB, guest writes)
    ├─ Response buffer (4KB, host writes)
    └─ Status registers (LOC_STATE, LOC_CTRL, LOC_STS)
    ↓
Command Decode
    ├─ Parse tag, size, command code
    ├─ Validate command parameters
    └─ Extract serialized data
    ↓
Command Dispatch (30+ commands)
    ├─ Startup / Shutdown
    ├─ PCR_Allocate / PCR_Extend / PCR_Read
    ├─ NV_DefineSpace / NV_Write / NV_Read
    ├─ ObjectHandle management
    ├─ GetCapability / GetRandom
    ├─ FlushContext
    ├─ SequenceStart / Update / Complete
    └─ ... (full TCG 2.0 command set)
    ↓
Storage Layer
    ├─ PCRBank: 24 PCRs × 3 algorithm (SHA256/384/512)
    ├─ NVStorage: Persistent NV indices
    ├─ HandleManager: Active object handles
    └─ CryptoEngine: (stubbed, uses SHA in guest OS)
    ↓
Response Encode
    ├─ Serialize PCR values / NV data
    ├─ Set response code (TPM_RC_*)
    └─ Write to response buffer
```

**Design Decision: CRB Interface Over LPC**
- More modern than legacy LPC TPM
- Simpler to emulate (no TPM state machine)
- Aligns with UEFI firmware expectations
- Supports DMA for large data transfers

### 3. Advanced ACPI (Power Management)

```
ACPI State Machine
    ↓
┌─────────────────────────────────────────┐
│ S0: Working State (full power)         │
└─────────────────────────────────────────┘
    ↓ [User requests sleep]
┌─────────────────────────────────────────┐
│ S1: Shallow sleep (CPU off, RAM on)    │
│ └─ Resume latency: ~ 0.1 sec           │
│ └─ Power consumption: ~90%             │
└─────────────────────────────────────────┘
    ↓ [Idle for 5 minutes]
┌─────────────────────────────────────────┐
│ S3: Suspend-to-RAM (CPU+chip off)      │
│ └─ Resume latency: ~ 1 sec             │
│ └─ Power consumption: ~5%              │
└─────────────────────────────────────────┘
    ↓ [User requests hibernate]
┌─────────────────────────────────────────┐
│ S4: Suspend-to-Disk (RAM to storage)   │
│ └─ Resume latency: ~ 10 sec            │
│ └─ Power consumption: ~0%              │
└─────────────────────────────────────────┘
    ↓ [AC lost or user shutdown]
┌─────────────────────────────────────────┐
│ S5: Soft-off (all off except RTC)      │
│ └─ Resume trigger: RTC alarm or button│
│ └─ Power consumption: ~0.1%           │
└─────────────────────────────────────────┘

CPU C-States (Idle levels)
    C0: Running (full speed)
    C1: Halt (CPU stops, ready to wake)
    C2: Stop Grant (bus off, longer latency)
    C3: Sleep (all off except RAM)

Thermal Management
    Passive: Reduce frequency (70-80°C)
    Critical: Emergency shutdown (>100°C)
```

**Design Decision: ACPI Tables in High ROM**
- UEFI firmware generates ACPI tables at runtime
- Tables include S/C state info, thermal zones, power buttons
- Guest queries via Port 0xB2 SMI port or MMIO
- Enables OSPM (OS Power Management) compliance

### 4. Live Migration (Zero-Downtime Updates)

```
┌────────────────────────── Precopy Phase ──────────────────────┐
│ Goal: Transfer majority of memory while VM running            │
│                                                                │
│ Iteration 1:                                                   │
│   ├─ Enable dirty page tracking                              │
│   ├─ Send all memory pages (highest transfer cost)           │
│   └─ Measure pages dirtied during transfer                   │
│                                                                │
│ Iteration 2..N:                                               │
│   ├─ Send only pages dirtied since last iteration           │
│   ├─ Dirty rate should exponentially decrease                │
│   └─ Check convergence: dirty_rate(i) / dirty_rate(i-1) < threshold
│                                                                │
│ Loop termination (whichever first):                           │
│   ├─ If converged (default < 1% new dirty pages)            │
│   │   → Proceed to stop-and-copy (very brief downtime)      │
│   └─ If max iterations reached (default 10)                 │
│       → Force stop-and-copy (acceptable downtime)           │
└─────────────────────────────────────────────────────────────┘
            ↓ [Downtime window ~0.1 - 1 second]
┌──────────── Stop-and-Copy Phase (Pause) ──────────────┐
│ Goal: Capture final VM state snapshot                    │
│                                                          │
│ 1. Pause all vCPUs (prevent new dirty pages)           │
│ 2. Disable dirty tracking                               │
│ 3. Send remaining dirty pages                           │
│ 4. Serialize vCPU state:                                │
│    ├─ Registers (RAX-R15, RIP, RFLAGS)                │
│    ├─ Control (CR0/3/4, EFER)                          │
│    ├─ Segment descriptors (CS/DS/SS/ES/FS/GS/LDTR/TR)│
│    └─ MSRs (LSTAR, STAR, FSBASE, etc.)                │
│ 5. Device snapshots (device-specific state bytes)      │
│ 6. Checkpoint timestamp                                 │
│ 7. Send checkpoint record                               │
└──────────────────────────────────────────────────────────┘
            ↓ [Destination receives checkpoint]
┌──────────── Postcopy Phase (Resume) ─────────────────┐
│ Goal: Activate VM on destination                       │
│                                                        │
│ Option A: Postcopy (VM running, demand-page)         │
│   ├─ Resume vCPUs on destination                      │
│   ├─ Page faults trigger demand requests from source  │
│   └─ Continues in parallel with user workload         │
│                                                        │
│ Option B: Always postcopy (safer, VM paused)         │
│   ├─ Wait for all memory transferred                  │
│   ├─ Resume vCPUs on destination                      │
│   └─ No demand paging latency                         │
└────────────────────────────────────────────────────────┘
```

**Design Decision: Iterative Precopy with Convergence Detection**
- First iteration transfers everything (slow but necessary)
- Subsequent iterations transfer only changes (fast)
- Convergence detection prevents infinite loops
- Automatic fallback to stop-and-copy on timeout
- Asymptotic approach to minimal downtime

### 5. PCI Hotplug (Dynamic Extensibility)

```
Hotplug Controller (Device at 0xAE00)
    ├─ Status register (per-slot: present, power, attention)
    ├─ Control register (per-slot: power on/off, eject)
    ├─ Event/interrupt queue
    └─ Slot state machine
        ├─ EMPTY (no device)
        ├─ POWERED_OFF (device present, powered off)
        ├─ POWERED_ON (device present, powered on)
        └─ EJECTED (removed)
        ↓
Device Add Workflow
    1. User: vm.dynamic_devices.add_pci_device(new_device)
    2. Controller: Find free PCI bus/slot
    3. Bus: Register device I/O / MMIO ranges
    4. Events: Generate hotplug SCI interrupt
    5. Guest ACPI _GPE handler processes notification
    6. Guest PCI re-enumeration
    7. Driver installation (if needed)
    8. Device online
        ↓
Device Remove Workflow
    1. User: vm.dynamic_devices.remove_pci_device(device_id)
    2. Guest ACPI _EJ0 method ejects device
    3. Controller: Clear device from bus
    4. Events: Generate hotplug SCI interrupt
    5. Driver unloads
    6. Device offline
    7. Deallocate resources
```

**Design Decision: Controller at Fixed MMIO Address**
- Guest firmware knows hotplug controller location (0xAE00)
- ACPI tables reference hotplug slots
- Events delivered via SCI interrupt (typically IRQ9)
- Decouples hotplug from PCI config space

### 6. Logging & Debugging (Observability)

```
Logger Hierarchy
    ├─ Severity Filter
    │   ├─ TRACE (excessive detail)
    │   ├─ DEBUG (diagnostic info)
    │   ├─ INFO (general progress)
    │   ├─ WARN (problematic condition)
    │   ├─ ERROR (operation failed)
    │   └─ FATAL (shutdown imminent)
    │
    ├─ Component Filter
    │   ├─ device (*/: per-device logs)
    │   ├─ guest (CPU, memory, registers)
    │   ├─ migration (transfer progress)
    │   ├─ error (exception recovery)
    │   ├─ tpm (cryptographic operations)
    │   ├─ hotplug (device add/remove)
    │   ├─ metrics (performance data)
    │   └─ ... (custom components)
    │
    ├─ Storage
    │   └─ Ring buffer (10,000 entries)
    │       ├─ Circular FIFO (overwrites on full)
    │       ├─ Per-entry: timestamp, level, component, message
    │       └─ Survive VM restart (if persistent)
    │
    └─ Output Channels
        ├─ Console (printf)
        ├─ File (with rotation)
        ├─ Syslog (remote)
        ├─ Network (UDP/TCP)
        └─ Custom callbacks

Performance Tracing
    ├─ Span-based (named regions)
    │   ├─ start_span("Boot") → end_span()
    │   └─ Automatically measures duration
    │
    ├─ Event annotations
    │   └─ add_event("disk_read_complete")
    │
    └─ Statistics
        ├─ Slowest spans + durations
        ├─ Event counts per operation
        └─ Total time per trace scope

Debug Symbols
    ├─ Symbol table (address → name, type, offset)
    ├─ Module registration (per ELF section)
    ├─ Symbol lookup (by address or name)
    ├─ Stack trace generation
    └─ DWARF / PDB / ELF support framework
```

**Design Decision: Ring Buffer + Component Filtering**
- Ring buffer: Recent logs always available, bounded memory
- Filtering: Reduce noise in development/testing
- Span tracing: Identify performance regressions
- Symbol support: Cross-reference guest code without debugging symbols

### 7. Performance Metrics (Observability)

```
PerformanceCounter Types
    ├─ Event count: Increment-only (VM exits, IO ops)
    ├─ Gauge: Value can go up/down (queue depth)
    └─ Histogram: Distribution (latency percentiles)

VMMetricsCollector
    ├─ Counters: Registry of all metrics
    ├─ Snapshots: Timestamped collections (max 1000)
    │   └─ Enables delta calculation (rate = (C2-C1) / (T2-T1))
    └─ Filtering: Metric name pattern matching

Standard Metrics Collected
    ├─ Hypervisor Core
    │   ├─ total_vmexits (per-type breakdown)
    │   ├─ avg_exit_latency_us
    │   └─ context_switch_latency_us
    │
    ├─ Storage
    │   ├─ disk_read_ops, disk_write_ops
    │   ├─ disk_read_bytes, disk_write_bytes
    │   ├─ disk_latency_us (histogram)
    │   └─ disk_queue_depth
    │
    ├─ Network
    │   ├─ nic_rx_packets, nic_tx_packets
    │   ├─ nic_rx_bytes, nic_tx_bytes
    │   ├─ nic_rx_errors, nic_tx_errors
    │   └─ nic_rx_dropped, nic_tx_dropped
    │
    ├─ Memory
    │   ├─ dirty_page_rate (during migration)
    │   ├─ page_fault_rate
    │   └─ memory_allocation_failures
    │
    └─ Thermal / Power
        ├─ cpu_temperature
        ├─ power_consumption_w
        └─ throttle_events

Bottleneck Detection Algorithm
    ├─ Thresholds (configurable)
    │   ├─ vmexit_rate > 100k/sec → IO bottleneck
    │   ├─ disk_latency_p99 > 1000μs → disk bottleneck
    │   ├─ nic_error_rate > 0.1% → network bottleneck
    │   └─ memory_failures > 0 → memory pressure
    │
    └─ Severity scoring
        └─ Aggregate over recent snapshots (default 10)
```

**Design Decision: Percentage-based Bottleneck Detection**
- Thresholds relative to workload (not absolute numbers)
- Automatic severity scoring (Low/Medium/High/Critical)
- Recommendations derived from bottleneck type
- Enables proactive scaling/optimization decisions

## Code Organization

```
f:\Nyx\stdlib\
├─ vm.ny                      # Core VM management
│   ├─ VMConfig
│   ├─ GuestMemory
│   ├─ VCPUState
│   ├─ VirtualMachine
│   │   ├─ init_devices()
│   │   ├─ setup_uefi_boot()
│   │   ├─ setup_bios_boot()
│   │   ├─ run_vcpu_loop()
│   │   ├─ handle_vmexit()
│   │   └─ ...
│   └─ VMBuilder
│
├─ hypervisor.ny               # Hardware abstraction (VMX/SVM)
│   ├─ VMX (Intel)
│   ├─ SVM (AMD)
│   ├─ EPT (Extended Page Tables)
│   ├─ Hypervisor manager
│   └─ unified exit dispatch
│
├─ vm_devices.ny               # Device emulation (2200+ lines)
│   ├─ Device base class
│   ├─ Interrupt controllers (PIC, LAPIC, IOAPIC)
│   ├─ Timers (PIT, RTC, HPET)
│   ├─ Storage (AHCI, Virtio-Blk)
│   ├─ Network (E1000, Virtio-Net)
│   ├─ I/O (UART, PS2, DMA)
│   ├─ Display (Bochs VGA)
│   └─ Misc (SMI, Reset, PCI Config)
│
├─ vm_errors.ny                # Error handling & recovery
│   ├─ ErrorContext
│   ├─ ExceptionHandler
│   ├─ WatchdogTimer
│   ├─ StateValidator
│   └─ FaultIsolation
│
├─ vm_tpm.ny                   # TPM 2.0 emulation
│   ├─ TPM2_PCRBank
│   ├─ TPM2_NVStorage
│   ├─ TPM2_HandleManager
│   └─ TPM2_Device (CRB interface)
│
├─ vm_acpi_advanced.ny         # Advanced power management
│   ├─ ACPIPowerStateManager (S0-S5)
│   ├─ ACPIThermalZone
│   ├─ ACPIButtonDevice
│   ├─ ACPIBatteryDevice
│   └─ ACPIAdvancedEventManager
│
├─ vm_migration.ny             # Live migration support
│   ├─ DirtyPageTracker
│   ├─ LiveMigration
│   └─ VMStateSerializer
│
├─ vm_hotplug.ny               # PCI hotplug support
│   ├─ PCIHotplugSlot
│   ├─ PCIHotplugController
│   └─ DynamicDeviceManager
│
├─ vm_logging.ny               # Multi-level logging
│   ├─ Logger (severity, components, filters)
│   ├─ PerformanceTracer (span-based)
│   ├─ BreakpointManager
│   └─ DebugSymbolManager
│
├─ vm_metrics.ny               # Performance monitoring
│   ├─ PerformanceCounter
│   ├─ VMMetricsCollector
│   └─ VMPerformanceMonitor
│
└─ vm_production.ny            # Integration & fluent API
    ├─ ProductionVMBuilder
    ├─ ProductionVMMonitor
    ├─ production_readiness_check()
    └─ Example configurations
```

## Interface Contracts

### Device Interface

```nyx
class Device {
    # I/O operations
    fn io_read(port: int) -> int         # Read from I/O port
    fn io_write(port: int, value: int)   # Write to I/O port
    
    # Memory-mapped I/O
    fn mmio_read(addr: int) -> int       # Read from MMIO address
    fn mmio_write(addr: int, value: int) # Write to MMIO address
    
    # Interrupt signaling
    fn raise_irq(irq: int)                # Signal interrupt (high)
    fn lower_irq(irq: int)                # End interrupt (low)
    
    # Snapshot for migration
    fn snapshot() -> bytes                # Serialize device state
    fn restore(state: bytes)              # Restore device state
}
```

### Exception Handler Interface

```nyx
class ExceptionHandler {
    fn register_exception_handler(
        exception_type: int,
        handler: fn(ErrorContext) -> RecoveryStrategy
    )
    
    fn handle_exception(
        type: int,
        context: ErrorContext
    ) -> bool  # True if recovery applied
}
```

### Migration Interface

```nyx
class LiveMigration {
    fn start_iterative_precopy(
        vm: VirtualMachine,
        dest_host: string,
        config: MigrationConfig
    ) -> MigrationResult  # {success, iterations_completed, converged}
    
    fn start_stop_and_copy(
        vm: VirtualMachine,
        dest_host: string
    ) -> MigrationResult
}
```

## Performance Characteristics

### VM Exit Latency (target)

| Operation | Latency | Notes |
|-----------|---------|-------|
| CPUID | 100-200ns | Fast emulation |
| MSR Read/Write | 200-300ns | MSR emulation |
| I/O Read/Write | 100-500ns | Device dispatch |
| Page Fault (EPT violation) | 1-5μs | Page table walk |
| MMIO access | 500ns-2μs | Device emulation |
| Context switch | 5-10μs | vCPU scheduling |
| Interrupt delivery | 1-2μs | IDT lookup + vector |

### Memory Usage

| Component | Size | Notes |
|-----------|------|-------|
| VMXON region | 4KB | Per VMX hypervisor |
| VMCS | 4KB | Per vCPU |
| EPT page tables | ~1-2MB | For 1GB guest (depends on fragmentati on) |
| Dirty bitmap | 256KB | Per 1GB guest memory |
| Logger ring buffer | ~500KB | 10,000 entries |
| Metrics snapshots | (1000 × counter_count) | Configurable |

### Storage Requirements

| Component | Size | Notes |
|-----------|------|-------|
| OVMF firmware | 2-4MB | UEFI ROM |
| BIOS firmware | 256-512KB | SeaBIOS |
| Guest disk | Variable | QCOW2/RAW/VHDX |
| VM snapshot | ~(guest_mem + device_state) | Migration checkpoint |

## Extension Points

### Adding New ACPI Feature

1. Define state class in vm_acpi_advanced.ny
2. Implement getter/setter for temperature/state
3. Register callbacks with ACPIAdvancedEventManager
4. Update ACPI table generation
5. Hook into UEFI firmware SMI handler

### Adding New Device Emulation

1. Create Device subclass
2. Implement io_read/io_write (or mmio_read/mmio_write)
3. Implement raise_irq/lower_irq
4. Implement snapshot/restore
5. Register with DeviceBus in init_devices()

### Adding New Metrics

1. Create PerformanceCounter in vm_metrics.ny
2. Increment in appropriate call sites
3. Add to bottleneck detection algorithm
4. Export to monitoring system

## Validation & Testing Strategy

See TESTING_FRAMEWORK.md for comprehensive test suite covering:
- Unit tests (device, hypervisor, features)
- Integration tests (module-to-module)
- System tests (full VM lifecycle)
- Stress tests (stability under load)

## Future Improvements

### Phase 2 (IOMMU Integration) ✅ COMPLETED

```
IOMMU Page Tables
    ├─ 4-level hierarchy (PML4/PDPT/PD/PT)
    ├─ Guest Physical → Host Physical translation
    └─ Per-domain isolation

Device Pass-Through Architecture
    ├─ IOMMU domains (STRICT/SHARED/UNMANAGED)
    ├─ Device assignment to domains
    ├─ Interrupt remapping table
    ├─ DMA fault detection and isolation
    └─ Multi-device coordination

Key Components:
    ├─ IOMMUPageTable: 4-level page table structure
    ├─ IOMMUDomain: Device isolation containers
    ├─ InterruptRemappingTable: MSI translation
    ├─ PassThroughDevice: Physical device wrapper
    ├─ DevicePassThroughManager: Orchestrator
    └─ IOMMUManager: High-level API

Usage Pattern:
    1. Enable IOMMU (Intel VT-d / AMD-Vi compatible)
    2. Create domain with isolation type
    3. Assign device to domain
    4. Setup DMA page mappings
    5. Configure interrupt remapping
    6. Automatic fault detection and device quarantine
```

### Phase 3 (Nested Virtualization)

```
Nested VM (Hypervisor in Guest)
    ├─ Guest hypervisor uses VMX/SVM
    ├─ Host intercepts VMXON/VMLAUNCH
    ├─ Emulate nested VMCS
    └─ Transparent to nested guests
```

### Phase 4 (Performance Optimization)

```
Exit Code Specialization
    ├─ Fast path for frequent exits
    ├─ Batch interrupt delivery
    ├─ Device queue batching
    └─ Adaptive scheduling
```

---

**Nyx Hypervisor v2.0 — Architecture Complete**
