# Nyx IOMMU Production Deployment Checklist

## Pre-Deployment Phase (1-2 days)

### Hardware Verification

- [ ] Verify CPU supports IOMMU
  - Intel: Check for "VT-d" in `cat /proc/cpuinfo` or CPUID
  - AMD: Check model (Opteron, EPYC, Ryzen) in systeminfo
  - Reference: [IOMMU_SPECIFICATION.md - 6.1 & 6.2](IOMMU_SPECIFICATION.md#6-hardware-compatibility)

- [ ] Check BIOS version is current
  - [ ] Visit motherboard manufacturer website
  - [ ] Check current BIOS version: `sudo dmidecode -s bios-version`
  - [ ] Download latest BIOS if available
  - [ ] Schedule maintenance window for BIOS update

- [ ] Document motherboard model
  - [ ] Record: `sudo dmidecode -s system-product-name`
  - [ ] Record: `sudo dmidecode -s baseboard-product-name`
  - [ ] Keep for reference during BIOS configuration

- [ ] Identify devices for pass-through
  - [ ] Run: `lspci -v` to list all PCI devices
  - [ ] Identify target devices (NIC, GPU, storage)
  - [ ] Note PCI IDs in format: `BB:DD.F` (e.g., 03:00.0)
  - [ ] Verify devices are IOMMU-capable

### BIOS/EFI Configuration

- [ ] Reboot and enter BIOS/EFI setup
  - [ ] Typical keys: DEL, F2, F10, F12 (depends on manufacturer)

- [ ] Intel System Configuration:
  - [ ] Advanced → Processor → Virtualization Technology → Enabled
  - [ ] Advanced → System Agent → VMX → Enabled  
  - [ ] Advanced → Integrated I/O → Intel VT-d → **Enabled**
  - [ ] Advanced → Integrated I/O → Interrupt Remapping → **Enabled**
  - [ ] Advanced → Integrated I/O → DMA Remapping → **Enabled**
  - [ ] Advanced → Integrated I/O → Access Control Services → **Enabled**
  - [ ] Boot → CSM → Disabled (for UEFI boot)
  - [ ] Security → Secure Boot → Disabled (if issues occur)

- [ ] AMD System Configuration:
  - [ ] Advanced → CPU Configuration → Virtualization Options → Enabled
  - [ ] Advanced → AMD I/O → IOMMU/SVM → **Enabled**
  - [ ] Advanced → AMD I/O → I/O TLB → **Enabled**
  - [ ] Advanced → AMD I/O → Interrupt Remapping → **Enabled**
  - [ ] Boot → CSM → Disabled (for UEFI boot)

- [ ] Storage Configuration:
  - [ ] Storage → SATA Mode → AHCI (if using SATA)
  - [ ] PCIe → Resizable BAR → Disabled (if issues occur)

- [ ] Power Configuration:
  - [ ] Power Management → ErP/EuP → **Disabled**
  - [ ] Power Management → PCIe Power Management → Disabled

- [ ] Save settings and exit (typically F10)
- [ ] System reboots

### Kernel/Driver Setup

- [ ] Boot into Linux and verify IOMMU enabled
  ```bash
  # For Intel VT-d:
  grep -i "Intel-IOMMU\|IOMMU" dmesg
  
  # For AMD-Vi:
  grep -i "AMD-Vi\|IOMMU" dmesg
  
  # Should show: "IOMMU: ... successfully initialized"
  ```

- [ ] Enable IOMMU in kernel parameters (grub)
  ```bash
  # Intel:
  sudo nano /etc/default/grub
  # Find: GRUB_CMDLINE_LINUX="..."
  # Add: intel_iommu=on iommu=pt
  
  # AMD:
  # Add: amd_iommu=on iommu=pt
  
  sudo update-grub
  sudo reboot
  ```
  - Reference: [IOMMU_SPECIFICATION.md - 9.2](IOMMU_SPECIFICATION.md#92-kernel-requirements)

- [ ] Verify kernel modules loaded
  ```bash
  lsmod | grep iommu          # Check IOMMU module
  lsmod | grep kvm            # Check KVM modules
  lsmod | grep vfio           # Check vfio (for pass-through)
  ```

- [ ] Check IOMMU device groups
  ```bash
  for d in /sys/kernel/iommu_groups/*/devices/*; do
    echo "$(lspci -nns ${d##*/})"
  done
  ```
  - Devices in same group may affect pass-through options

### Network & Storage Setup

- [ ] Configure management network separate from pass-through
  - [ ] Management NIC → Host (NOT passed through)
  - [ ] Dedicated NIC → VM (passed through if applicable)

- [ ] Prepare storage for VM
  - [ ] [ ] Allocate space for qcow2/vmdk disk image (minimum: 20GB)
  - [ ] [ ] Set permissions: `chmod 644 image.qcow2`
  - [ ] [ ] Or use physical LVM: `/dev/vg0/vm_volume`

- [ ] Prepare boot image
  - [ ] [ ] Download OVMF.fd (UEFI firmware)
  - [ ] [ ] Or use BIOS if UEFI not available
  - [ ] [ ] Verify image exists and is readable

---

## Deployment Phase (1-2 hours)

### Build Single-Device Test VM

- [ ] Create initial VM configuration (from [IOMMU_EXAMPLES.md - Example 1](IOMMU_EXAMPLES.md#example-1-single-nic-pass-through))
  ```nyx
  let test_vm = ProductionVMBuilder()
      .memory(4 * 1024**3)
      .cpus(2)
      .uefi("OVMF.fd")
      .disk("test_vm.qcow2")
      .with_iommu()
      .passthrough_device(0x0300, "STRICT")
      .with_logging()
      .with_error_handling()
      .build();
  ```

- [ ] Start VM and verify basic operation
  - [ ] [ ] Monitor console for boot messages
  - [ ] [ ] Expected: "Booting from disk"
  - [ ] [ ] VM should reach login prompt

- [ ] Verify IOMMU from guest
  ```bash
  # Inside guest:
  dmesg | grep -i iommu
  # Expected: "IOMMU" references or silence (if hidden from guest)
  ```

- [ ] Verify device is accessible
  ```bash
  # Inside guest:
  lspci | grep -i "network\|ethernet"
  # Should show the passed-through NIC
  
  ip link show
  # Should show network interface from device (e.g., eth0)
  ```

- [ ] Test basic connectivity
  ```bash
  # From guest:
  ping <router gateway>
  # Should work (if NIC was passed through)
  
  # Check basic throughput:
  iperf3 -c <server>
  # Record baseline throughput
  ```

- [ ] Verify IOMMU status from host
  ```bash
  # From host, query Nyx hypervisor:
  vm.iommu_mgr.get_status()
  # Should show: enabled=true, devices=1, domains=1, fault_events=0
  ```

### Monitor for Faults

- [ ] Watch for IOMMU faults during initial operation
  - [ ] Run for 1-2 minutes without load
  - [ ] Fault count should remain 0
  - [ ] Reference: [IOMMU_GUIDE.md - Troubleshooting](IOMMU_GUIDE.md#troubleshooting)

- [ ] If faults detected:
  - [ ] [ ] Check device is actually IOMMU-capable: `lspci -v <device>`
  - [ ] [ ] Look for "IOMMU Group" in output
  - [ ] [ ] Review BIOS settings (re-enable IOMMU options)
  - [ ] [ ] Check if device needs driver from guest
  - [ ] [ ] Try different isolation type (SHARED instead of STRICT)

### Performance Baseline

- [ ] Record baseline performance metrics
  ```bash
  # From guest with device assigned:
  
  # Network throughput:
  iperf3 -c <server>
  # Save result: __________ Mbps
  
  # Storage throughput (if storage device passed):
  fio --name=seqread --rw=read --bs=1m --numjobs=2
  # Save result: __________ MB/s
  
  # Latency:
  ping -c 100 <destination>
  # Save result: avg latency = __________ ms
  ```

- [ ] Expected performance:
  - Network: 95-98% of non-IOMMU throughput
  - Storage: 90-95% of non-IOMMU throughput
  - Latency: +1-5μs overhead

---

## Testing Phase (4-8 hours)

### Stress Testing

- [ ] Run sustained load test
  ```bash
  # From guest, 1-hour load test:
  iperf3 -c <server> -t 3600 &
  
  # Monitor CPU, memory, errors:
  watch -n 1 'free -h && vmstat 1 2 | tail -1'
  ```
  - [ ] No errors should occur
  - [ ] No fault count increase
  - [ ] Throughput should remain consistent

- [ ] Fault injection test (if test infrastructure available)
  ```bash
  # Simulate device errors and recovery:
  # (configure from test framework in IOMMU_TESTING.md)
  ```
  - [ ] Device should auto-isolate
  - [ ] Host should remain stable
  - [ ] Manual reset should restore device

### Security Validation

- [ ] Verify device isolation
  - [ ] If multiple devices: Ensure fault in one doesn't affect other
  - [ ] Reference: [IOMMU_TESTING.md - Section 6](IOMMU_TESTING.md#6-security-tests--isolation-validation)

- [ ] Verify memory protection
  - [ ] Device cannot access host memory (hypervisor)
  - [ ] Device cannot access other VM memory
  - [ ] Only mapped guest memory accessible

### Error Handling

- [ ] Test graceful degradation
  ```bash
  # Intentionally cause error:
  # (depends on specific device, consult documentation)
  
  # Verify:
  # - VM continues running
  # - Device isolated but host stable
  # - Fault logged
  ```

- [ ] Test device reset
  ```bash
  # From Nyx:
  vm.iommu_mgr.reset_device(0x0300);
  
  # Verify device reconnects in guest
  ip link show  # From guest
  # Interface should come back online
  ```

---

## Production Deployment Phase (2-4 hours)

### Multi-Device Configuration

- [ ] Review topology from [IOMMU_EXAMPLES.md](IOMMU_EXAMPLES.md)
  - [ ] Choose STRICT vs SHARED isolation per device
  - [ ] Design domain hierarchy
  - [ ] Document in deployment plan

- [ ] Build production VM from appropriate example
  - Example reference: [IOMMU_EXAMPLES.md](IOMMU_EXAMPLES.md)
  - Add all required devices:
    ```nyx
    let prod_vm = ProductionVMBuilder()
        .memory(8 * 1024**3)
        .cpus(4)
        .uefi("OVMF.fd")
        .disk("production.qcow2")
        .with_iommu()
        .passthrough_device(0x0300, "STRICT")  # Device 1
        .passthrough_device(0x0301, "STRICT")  # Device 2
        .with_live_migration()                 # Enable migration
        .with_error_handling()                 # Error recovery
        .with_logging()                        # Operational logging
        .with_metrics()                        # Performance tracking
        .build();
    ```

### Enable Monitoring & Observability

- [ ] Enable metrics collection
  - [ ] Reference: [IOMMU_EXAMPLES.md - Example 13](IOMMU_EXAMPLES.md#example-13-iommu-metrics-dashboard)
  - [ ] Setup monitoring dashboard
  - [ ] Configure alerting thresholds:
    - [ ] Alert if fault_count > 5/hour
    - [ ] Alert if IOTLB hit rate < 90%
    - [ ] Alert if device status becomes inoperational

- [ ] Setup logging
  - [ ] Configure log level: DEBUG for first 24h, INFO after
  - [ ] Rotate logs: daily, keep for 30 days
  - [ ] Centralize logs if possible (syslog, ELK)

- [ ] Create runbooks for common issues
  - Reference: [IOMMU_GUIDE.md - Troubleshooting](IOMMU_GUIDE.md#troubleshooting)

### Failover/HA Configuration (if required)

- [ ] Setup live migration target
  - Reference: [IOMMU_EXAMPLES.md - Example 6](IOMMU_EXAMPLES.md#example-6-fail-over-configuration)

- [ ] Test failover scenario
  - [ ] Initiate controlled migration
  - [ ] Verify VM continues running on destination
  - [ ] Device state serialized correctly
  - [ ] Guest network connectivity maintained

- [ ] Configure automatic recovery
  - [ ] Watchdog timer
  - [ ] Automatic restart on target if primary fails

### Documentation

- [ ] Document final configuration
  - [ ] Device assignment (device_id → domain_id)
  - [ ] Isolation hierarchy
  - [ ] Management IPs and credentials
  - [ ] Recovery procedures
  - [ ] Escalation contacts

- [ ] Create operational runbook
  - [ ] How to monitor device status
  - [ ] How to respond to faults
  - [ ] How to add/remove devices
  - [ ] How to perform maintenance

---

## Post-Deployment Monitoring (Ongoing)

### First 24 Hours

- [ ] Continuous monitoring
  - [ ] check every 1 hour: fault_count (should be 0)
  - [ ] check every 1 hour: device operational status (should be true)
  - [ ] check every 1 hour: IOTLB hit rate (should be > 95%)

- [ ] Performance validation
  - [ ] Throughput meets SLA targets
  - [ ] Latency within acceptable range
  - [ ] No drops in performance over time

- [ ] Error handling validation
  - [ ] Any errors are logged properly
  - [ ] Alerts trigger for configured thresholds
  - [ ] Escalation procedures work

### First Week

- [ ] Review metrics and logs daily
  - [ ] Look for patterns or trends
  - [ ] Any fault spikes?
  - [ ] Device stability patterns?

- [ ] Weekly performance report
  - [ ] Reference: [IOMMU_EXAMPLES.md - Example 14](IOMMU_EXAMPLES.md#example-14-automated-reporting)
  - [ ] Generate automated report
  - [ ] Review with team

### Ongoing (Weekly/Monthly)

- [ ] Weekly health check
  - [ ] Verify monitoring still active
  - [ ] Check for any drift in performance
  - [ ] Review logs for warnings

- [ ] Monthly review
  - [ ] Analyze trends over 1 month
  - [ ] Capacity planning (additional devices?)
  - [ ] Update runbooks if needed

---

## Troubleshooting Checklist

### Device Not Visible in Guest

- [ ] Verify device assigned:
  ```bash
  vm.iommu_mgr.get_passthrough_device(0x0300);
  # Should return non-null
  ```

- [ ] Verify device not quarantined:
  ```bash
  device.is_operational();
  # Should return true
  ```

- [ ] Check guest BIOS/EFI sees device:
  ```bash
  # From guest: lspci | grep <device description>
  # Should appear in listing
  ```

- [ ] Check guest driver loaded:
  ```bash
  # From guest: lsmod | grep <driver name>
  # Or: sudo modprobe <driver>
  ```

- [ ] Call [IOMMU_GUIDE.md - Troubleshooting](IOMMU_GUIDE.md#guest-cant-access-device)

### High Fault Rate

- [ ] Verify BIOS IOMMU settings enabled
  - [ ] Re-enter BIOS, double-check VT-d/IOMMU enabled

- [ ] Check device compatibility
  - [ ] Verify device has IOMMU capability
  - [ ] Check device is in IOMMU group

- [ ] Increase fault threshold temporarily
  ```nyx
  device.max_faults = 20;  # Increase from default 10
  ```

- [ ] Enable DEBUG logging:
  ```nyx
  set_logger_level("DEBUG");
  ```

- [ ] Call [IOMMU_EXAMPLES.md - Example 11](IOMMU_EXAMPLES.md#example-11-debugging-high-fault-rate)

### Device Becomes Inoperational (Quarantined)

- [ ] Check fault history:
  ```bash
  device.get_recent_faults();
  # Review fault types and addresses
  ```

- [ ] Attempt manual reset:
  ```bash
  vm.iommu_mgr.reset_device(0x0300);
  ```

- [ ] If reset fails:
  - [ ] Shutdown guest gracefully
  - [ ] Remove device from VM config
  - [ ] Restart guest without device
  - [ ] Investigate device hardware

- [ ] Call [IOMMU_EXAMPLES.md - Example 12](IOMMU_EXAMPLES.md#example-12-recovery-from-device-isolation)

---

## Rollback Procedure

If IOMMU causes issues and must be disabled:

- [ ] Remove from VM configuration:
  ```nyx
  # Remove .with_iommu() from builder
  # Remove .passthrough_device(...) calls
  # VM will use emulated devices instead
  ```

- [ ] Revert BIOS settings (optional):
  - [ ] Re-enter BIOS
  - [ ] Set IOMMU to Disabled
  - [ ] Reboot

- [ ] Restart VM with standard devices
  - [ ] Performance will be lower but stability ensured

- [ ] Investigate root cause during maintenance window

---

## Sign-Off Checklist

### Technical Review

- [ ] Architecture design reviewed
  - [ ] Device grouping strategy approved
  - [ ] Isolation hierarchy documented
  - [ ] Fault handling procedures verified

- [ ] Testing completed
  - [ ] All 50+ test cases passed
  - [ ] Performance baselines met
  - [ ] Security validation complete
  - [ ] Failover/recovery tested

- [ ] Documentation reviewed
  - [ ] Operational runbook complete
  - [ ] Troubleshooting procedures documented
  - [ ] Monitoring configured
  - [ ] Escalation paths defined

### Operational Readiness

- [ ] Monitoring in place
  - [ ] Metrics collection active
  - [ ] Alerting configured
  - [ ] Dashboards setup

- [ ] Runbooks prepared
  - [ ] Common procedures documented
  - [ ] Escalation contacts listed
  - [ ] Recovery procedures tested

- [ ] Team trained
  - [ ] Operations team familiar with IOMMU
  - [ ] Incident response practiced
  - [ ] Documentation accessible

### Sign-Off

- [ ] Technical Lead: _________________ Date: _____
- [ ] Operations Manager: _________________ Date: _____
- [ ] Security Team: _________________ Date: _____

---

## Quick Reference Links

- **Concepts:** [IOMMU_GUIDE.md](IOMMU_GUIDE.md)
- **Technical Details:** [IOMMU_SPECIFICATION.md](IOMMU_SPECIFICATION.md)
- **Examples:** [IOMMU_EXAMPLES.md](IOMMU_EXAMPLES.md)
- **Testing:** [IOMMU_TESTING.md](IOMMU_TESTING.md)
- **Navigation:** [IOMMU_DOCUMENTATION_INDEX.md](IOMMU_DOCUMENTATION_INDEX.md)
- **Summary:** [IOMMU_SUMMARY.md](IOMMU_SUMMARY.md)

---

**Nyx IOMMU Production Deployment Checklist** v1.0
