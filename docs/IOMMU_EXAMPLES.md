# Nyx IOMMU — Production Examples & Recipes

## Quick Start Examples

### Example 1: Single NIC Pass-Through

```nyx
# Minimal configuration: One NIC for direct guest access
let vm = ProductionVMBuilder()
    .memory(4 * 1024**3)
    .cpus(2)
    .uefi("OVMF.fd")
    .disk("guest.qcow2")
    .with_iommu()                           # Enable IOMMU
    .passthrough_device(0x0300, "STRICT")   # Assign NIC (03:00.0)
    .build();

vm.run();

# Expected guest output:
# EthX connected (direct hardware access)
# Latency: < 20us
# Throughput: 95%+ of line rate
```

### Example 2: GPU Workstation

```nyx
# High-performance GPU with direct access
let workstation = ProductionVMBuilder()
    .memory(32 * 1024**3)
    .cpus(16)
    .uefi("OVMF_WORKSTATION.fd")
    .disk("gaming_vm.qcow2")
    .with_iommu()
    .passthrough_device(0x0100, "STRICT")   # Primary GPU
    .passthrough_device(0x0101, "STRICT")   # GPU Audio
    .passthrough_device(0x0200, "STRICT")   # USB Controller
    .with_error_handling()                  # Handle faults gracefully
    .with_metrics()                         # Monitor GPU performance
    .build();

workstation.run();

# Expected performance:
# GPU utilization: 98-99% (near-native)
# Frame rate: 95%+ of bare metal
# Latency: 1-5ms additional per frame
```

### Example 3: Network Appliance (Multi-NIC)

```nyx
# Security appliance with multiple network interfaces
let appliance = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(8)
    .uefi("OVMF.fd")
    .disk("appliance.qcow2")
    .with_iommu()
    # WAN interfaces (strict isolation, different VLANs)
    .passthrough_device(0x0400, "STRICT")   # WAN1 (enp4s0f0)
    .passthrough_device(0x0401, "STRICT")   # WAN2 (enp4s0f1)
    # LAN interface (strict isolation)
    .passthrough_device(0x0500, "STRICT")   # LAN1 (enp5s0)
    # Management (strict isolation)
    .passthrough_device(0x0600, "STRICT")   # MGMT (enp6s0)
    .with_logging()
    .build();

appliance.run();

# Performance:
# - Each NIC independent (no cross-domain latency)
# - Combined throughput: 4 × 10Gbps = 40Gbps
# - Latency per packet: 5-10us (direct hardware)
```

### Example 4: Storage Server (Batch Domains)

```nyx
# NVMe storage server with shared storage domain
let storage_server = ProductionVMBuilder()
    .memory(64 * 1024**3)
    .cpus(24)
    .uefi("OVMF_STORAGE.fd")
    .disk("meta.qcow2")
    .with_iommu()
    # NVMe controllers share domain (related devices)
    .passthrough_device(0x0100, "SHARED")   # NVMe SSD 1
    .passthrough_device(0x0101, "SHARED")   # NVMe SSD 2
    .passthrough_device(0x0102, "SHARED")   # NVMe SSD 3
    .passthrough_device(0x0103, "SHARED")   # NVMe SSD 4
    # Network isolated
    .passthrough_device(0x0200, "STRICT")   # Data NIC
    .passthrough_device(0x0201, "STRICT")   # Replication NIC
    .with_live_migration()                  # State tracking
    .with_error_handling()
    .with_metrics()
    .build();

storage_server.run();

# Domain optimization:
# - 4 devices in 1 domain = 1 IOTLB
# - 2 NICs in separate domains = strict security
# - Overhead: 1 TLB per SHARED change vs 4 for STRICT
```

### Example 5: Container Host with Device Oversubscription

```nyx
# Hypervisor for container platform with GPU scheduling
let container_host = ProductionVMBuilder()
    .memory(128 * 1024**3)
    .cpus(32)
    .uefi("OVMF.fd")
    .disk("container_host.qcow2")
    .with_iommu()
    # GPU 1 (assigned to Container 1)
    .passthrough_device(0x0100, "STRICT")   # GPU A
    # GPU 2 (assigned to Container 2)
    .passthrough_device(0x0101, "STRICT")   # GPU B
    # GPU 3 (shared, time-sliced)
    .passthrough_device(0x0102, "STRICT")   # GPU C (managed by scheduler)
    # Network (assigned to host networking)
    .passthrough_device(0x0300, "SHARED")   # ETH1
    .passthrough_device(0x0301, "SHARED")   # ETH2
    .passthrough_device(0x0302, "SHARED")   # ETH3
    .with_error_handling()
    .with_live_migration()
    .with_metrics()
    .with_snapshot()
    .build();

container_host.run();

# Features:
# - GPU isolation prevents one container from affecting others
# - Network SHARED domain for multi-container communication
# - Metrics enable GPU time accounting per container
```

## Advanced Configuration Examples

### Example 6: Fail-Over Configuration

```nyx
# Primary VM with automatic failover support
let primary_vm = ProductionVMBuilder()
    .memory(16 * 1024**3)
    .cpus(8)
    .uefi("OVMF.fd")
    .disk("primary.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")
    .with_live_migration()       # Enable state tracking
    .with_error_handling()       # Auto-restart on failure
    .with_snapshot()             # State backup
    .with_metrics()
    .build();

# Configure HA manager
let ha = SystemHAManager();
ha.register_vm("primary", primary_vm);
ha.set_failover_target("backup", "192.168.1.100");
ha.set_checkpoint_interval_ms(5000);  # 5 seconds between snapshots

# Failure flow:
# Primary crash → Error handler detects
#               → Snapshot taken
#               → Replicate to backup
#               → Failover triggered
#               → Guest continues on backup
#               → Recovery on primary completed
#               → Failback initiated
```

### Example 7: Device Hotplug with IOMMU

```nyx
# Dynamic device assignment during VM run
let flexible_vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .disk("flexible.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")  # Initial device
    .with_error_handling()
    .with_logging()
    .build();

vm.run();

# Later: Add device at runtime
wait_ms(10000);  # Wait 10 seconds

# Prepare device (unbind from host if needed)
# Then hotplug
let status = vm.iommu_mgr.assign_device(0x0400, "STRICT");
if (status == true) {
    log("Device 0x0400 added to VM");
    # Guest detects via ACPI hotplug event
}

# Check status
let info = vm.iommu_mgr.get_passthrough_device(0x0400);
log("Device operational: " + info.is_operational());

# Later: Remove device
vm.iommu_mgr.remove_device(0x0400);
# Guest receives ACPI eject event
# Device removed after guest acknowledges
```

### Example 8: Device Isolation Hierarchy

```nyx
# Complex device hierarchy with granular isolation
let complex_vm = ProductionVMBuilder()
    .memory(32 * 1024**3)
    .cpus(16)
    .uefi("OVMF.fd")
    .disk("complex.qcow2")
    .with_iommu()
    # High-security devices (isolated domains)
    .passthrough_device(0x0100, "STRICT")   # HSM (Hardware Security Module)
    .passthrough_device(0x0200, "STRICT")   # Trusted IO Controller
    # Performance-critical (related in shared domain)
    .passthrough_device(0x0300, "SHARED")   # Storage Controller 1
    .passthrough_device(0x0301, "SHARED")   # Storage Controller 2
    # Managed networking (separate domains for security)
    .passthrough_device(0x0400, "STRICT")   # Data NIC
    .passthrough_device(0x0401, "STRICT")   # OOB NIC
    .passthrough_device(0x0402, "STRICT")   # Heartbeat NIC
    .with_tpm()                              # Pair with TPM for attestation
    .with_error_handling()
    .with_metrics()
    .build();

# Domain layout:
# STRICT Domain 1: 0x0100 (HSM)
# STRICT Domain 2: 0x0200 (Trusted IO)
# SHARED Domain 3: 0x0300, 0x0301 (Storage)
# STRICT Domain 4: 0x0400 (Data NIC)
# STRICT Domain 5: 0x0401 (OOB NIC)
# STRICT Domain 6: 0x0402 (Heartbeat NIC)
#
# Fault isolation:
# - HSM fault → Only HSM isolated (security-critical)
# - Storage fault → Both controllers affected (related)
# - NIC fault → Only that NIC isolated (independent)
```

### Example 9: Performance Optimization

```nyx
# Tuned configuration for maximum throughput
let perf_optimized = ProductionVMBuilder()
    .memory(64 * 1024**3)
    .cpus(32)
    .uefi("OVMF_PERF.fd")
    .disk("perf.qcow2")
    .with_iommu()
    # Large page support (reduces TLB misses)
    .iommu_large_pages(true)      # Use 2MB/1GB pages where possible
    # Interrupt coalescing (reduce interrupt overhead)
    .iommu_interrupt_coalescing(true)
    # Batch IOTLB invalidations
    .iommu_batch_invalidation(true)
    .passthrough_device(0x0300, "SHARED")   # Multi-queue NIC
    .passthrough_device(0x0301, "SHARED")   # NIC IOMMU batching
    # CPU pinning for locality
    .cpu_affinity([0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15])
    .with_metrics()
    .build();

# Expected performance:
# - IOTLB efficiency: 99.5% (large pages + batching)
# - DMA throughput: 99% of max
# - Latency: p99 < 5us
# - CPU overhead: < 1% for IOMMU operations
```

### Example 10: Multi-Tenant Isolation

```nyx
# Security-focused: Multiple independent tenants
let tenant1_vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .disk("tenant1.qcow2")
    .with_iommu()
    # Each tenant gets isolated devices
    .passthrough_device(0x0300, "STRICT")   # Tenant 1 NIC (isolated domain)
    .with_error_handling()
    .with_logging()
    .build();

let tenant2_vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .disk("tenant2.qcow2")
    .with_iommu()
    # Each tenant independent
    .passthrough_device(0x0301, "STRICT")   # Tenant 2 NIC (different domain)
    .with_error_handling()
    .with_logging()
    .build();

# Isolation guarantees:
# STRICT isolation per tenant
#   Tenant 1 fault → Tenant 1 device disabled
#   Tenant 1 DMA → Only Tenant 1 memory accessible
#   Tenant 2 completely unaffected
#   Host completely unaffected

# Deployment:
vmm.spawn_vm(tenant1_vm);
vmm.spawn_vm(tenant2_vm);
# Each has independent IOMMU state
```

## Troubleshooting Examples

### Example 11: Debugging High Fault Rate

```nyx
# Diagnose and fix high IOMMU fault rate
let vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .disk("debug.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")
    .with_logging()              # Enable detailed logging
    .with_metrics()
    .build();

vm.run();

# Check status periodically
while (true) {
    wait_ms(1000);
    
    let status = vm.iommu_mgr.get_status();
    printf("Fault events: %d\n", status.fault_events);
    
    let device = vm.iommu_mgr.get_passthrough_device(0x0300);
    if (device != null) {
        printf("Device 0x0300 faults: %d\n", device.fault_count);
        printf("Device operational: %s\n", device.is_operational());
        
        if (device.fault_count > 5) {
            printf("HIGH FAULT RATE DETECTED\n");
            
            # Diagnostic steps:
            log_level = get_logger_level();
            set_logger_level("DEBUG");  # More verbose
            
            # Get fault details
            faults = device.get_recent_faults();
            for fault in faults {
                printf("Fault: %s at GPA=0x%X\n", fault.type, fault.address);
            }
            
            # Options:
            # 1. Increase fault threshold
            device.max_faults = 20;
            
            # 2. Reset device
            vm.iommu_mgr.reset_device(0x0300);
            
            # 3. Disable device temporarily
            # vm.iommu_mgr.remove_device(0x0300);
        }
    }
}
```

### Example 12: Recovery from Device Isolation

```nyx
# Detect and recover from device being quarantined
let vm = ProductionVMBuilder()
    .memory(4 * 1024**3)
    .cpus(2)
    .uefi("OVMF.fd")
    .disk("recovery.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")
    .with_error_handling()
    .build();

vm.run();

# Monitoring loop
for i in 0..600 {  # 10 minutes
    wait_ms(1000);
    
    let device = vm.iommu_mgr.get_passthrough_device(0x0300);
    
    if (device.is_operational() == false) {
        printf("Device quarantined at iteration %d\n", i);
        
        # Recovery strategy:
        # Step 1: Log state for analysis
        save_diagnostic_dump("device_0x0300_fault.log");
        
        # Step 2: Notify guest (via ACPI)
        notify_guest_device_error(0x0300);
        wait_ms(1000);  # Give guest time to handle
        
        # Step 3: Reset device
        printf("Attempting device recovery...\n");
        vm.iommu_mgr.reset_device(0x0300);
        wait_ms(2000);  # Stabilization time
        
        # Step 4: Verify recovery
        if (device.is_operational()) {
            printf("Device recovered successfully\n");
            set_alert_level("NORMAL");
        } else {
            printf("Recovery failed, escalating...\n");
            set_alert_level("CRITICAL");
            # Invoke failover or VM restart
        }
    }
}
```

## Monitoring & Observability

### Example 13: IOMMU Metrics Dashboard

```nyx
# Real-time IOMMU health monitoring
let dashboard = IOMMUDashboard();

# Collect metrics
let iommu_metrics = IOMMUMetricsCollector(vm);

# Dashboard loop
while (true) {
    wait_ms(5000);  # Update every 5 seconds
    
    let metrics = iommu_metrics.collect();
    
    dashboard.display(metrics);
    # Shows:
    # - Domains: 3
    # - Devices: 4
    # - IOTLB hit rate: 97.3%
    # - Fault events (total): 0
    # - Device faults (0x0300): 0
    # - Average DMA latency: 2.3us
    # - Peak DMA latency (p99): 8.5us
    # - Interrupts/sec: 145,230
    # - Interrupt remapping latency: 850ns avg
    
    # Export for external monitoring
    prometheus_push_metrics(metrics);
}
```

### Example 14: Automated Reporting

```nyx
# Daily IOMMU health report
let reporter = IOMMUReporter(vm);

fn generate_daily_report() {
    let report = {
        timestamp = current_time(),
        iommu_enabled = vm.iommu_mgr.get_status().enabled,
        devices_assigned = vm.iommu_mgr.get_status().devices,
        domains_in_use = vm.iommu_mgr.get_status().domains,
        total_fault_events = vm.iommu_mgr.get_status().fault_events,
        peak_fault_rate = reporter.calculate_peak_fault_rate(),
        avg_dma_latency_us = reporter.calculate_avg_dma_latency(),
        iotlb_efficiency = reporter.calculate_iotlb_hit_rate(),
        device_status = {}
    };
    
    # Per-device status
    for device_id in vm.iommu_mgr.list_devices() {
        device = vm.iommu_mgr.get_passthrough_device(device_id);
        report.device_status[device_id] = {
            operational = device.is_operational(),
            faults = device.fault_count,
            last_fault = device.last_fault_time,
            domain = device.domain_id
        };
    }
    
    # Save report
    save_json("/var/log/iommu_report_" + date_today() + ".json", report);
    
    # Generate human-readable summary
    println("=== IOMMU Daily Report ===");
    println("Status: " + (report.iommu_enabled ? "ENABLED" : "DISABLED"));
    println("Devices: " + report.devices_assigned);
    println("Domains: " + report.domains_in_use);
    println("Total Faults: " + report.total_fault_events);
    println("IOTLB Efficiency: " + report.iotlb_efficiency + "%");
    println("Avg DMA Latency: " + report.avg_dma_latency_us + "us");
    
    # Send via email if issues detected
    if (report.total_fault_events > 10) {
        send_email("alerts@example.com", 
            "IOMMU Alert: High fault count detected", 
            JSON.stringify(report, null, 2));
    }
}

# Run daily at 2 AM
scheduler.add_daily_task("0 2 * * *", generate_daily_report);
```

## Integration Examples

### Example 15: IOMMU + Live Migration

```nyx
# Migrate VM with pass-through devices
let source_vm = ProductionVMBuilder()
    .memory(8 * 1024**3)
    .cpus(4)
    .uefi("OVMF.fd")
    .disk("migratable.qcow2")
    .with_iommu()
    .passthrough_device(0x0300, "STRICT")
    .with_live_migration()      # Enable state tracking
    .with_error_handling()
    .build();

source_vm.run();

# Later: Initiate migration
wait_ms(30000);

# Start migration to destination host
let migration = source_vm.migration_mgr.start_precopy(
    destination_host = "192.168.1.200",
    max_downtime_ms = 1000,
    bandwidth_limit_mbps = 1000
);

# Monitor migration progress
while (!migration.complete) {
    wait_ms(1000);
    
    let progress = migration.get_progress();
    printf("Migrated: %.1f%%, Downtime: %dms\n", 
           progress.percent_complete,
           progress.downtime_ms);
}

# Migration includes:
# - Guest memory dirty pages
# - Device state (registers, queues)
# - IOMMU page table state
# - Interrupt mapping tables

# Destination receives:
# - VM + device state snapshot
# - Devices reassigned to domains
# - IOMMU state reconstructed
# - Guest resumes with minimal downtime
```

## Best Practices Summary

1. **Use STRICT isolation when:**
   - Device is security-critical
   - Device has history of faults
   - Multi-tenant environments
   
2. **Use SHARED isolation when:**
   - Devices naturally grouped (storage controllers)
   - Performance is critical
   - Related devices under same trust domain

3. **Monitoring essentials:**
   - Track device fault rate (should be ~0)
   - Monitor IOTLB hit rate (should be > 95%)
   - Alert on high DMA latency (> 100us)
   - Verify device operational status regularly

4. **Configuration tips:**
   - Enable logging during initial deployment
   - Monitor for 24 hours before production
   - Keep IOMMU firmware updated
   - Document device grouping for audit

5. **Troubleshooting priorities:**
   - Check kernel logs for IOMMU errors
   - Verify BIOS IOMMU settings
   - Confirm device is IOMMU-capable
   - Test with single device first, scale gradually

---

**Nyx IOMMU — Production Deployment Examples**
