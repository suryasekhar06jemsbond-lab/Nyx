# Nyx IOMMU & Device Pass-Through Support
# Intel VT-d and AMD-Vi compatible implementation

# ============================================================================
# IOMMU Page Table Structures (4-level hierarchy, 4KB pages)
# ============================================================================

class IOMMUPageTable {
    level = 0;           # 0=PML4, 1=PDPT, 2=PD, 3=PT
    entries = [];        # 512 entries per table (4KB = 512 × 8-byte entries)
    physical_address = 0; # Host physical address where table lives
    
    fn new(level, phys_addr) {
        level = level;
        physical_address = phys_addr;
        entries = array(512);  # 512 entries
        for (i = 0; i < 512; i++) {
            entries[i] = 0;  # Clear initially
        }
        return this;
    }
    
    fn set_entry(index, address, flags) {
        # Entry format: [63:12] = address, [11:0] = flags
        # Flags: present, write, read, cache control
        if (index < 0 or index >= 512) {
            return false;
        }
        entries[index] = (address & 0xFFFFFFFFFFFFF000) | (flags & 0xFFF);
        return true;
    }
    
    fn get_entry(index) {
        if (index < 0 or index >= 512) {
            return null;
        }
        return entries[index];
    }
    
    fn clear_entry(index) {
        if (index >= 0 and index < 512) {
            entries[index] = 0;
        }
    }
    
    fn is_present(entry) {
        return (entry & 0x1) != 0;  # Bit 0: present
    }
    
    fn is_writable(entry) {
        return (entry & 0x2) != 0;  # Bit 1: write enable
    }
    
    fn get_address(entry) {
        return entry & 0xFFFFFFFFFFFFF000;  # Bits [63:12]
    }
}

# ============================================================================
# IOMMU Domain Management
# ============================================================================

class IOMMUDomain {
    domain_id = 0;
    root_table = null;           # Root page table (PML4)
    devices = [];                # List of assigned devices
    isolation_type = "STRICT";   # STRICT, SHARED, UNMANAGED
    cache_invalidations = 0;     # Counter for cache flushes
    
    fn new(id, isolation) {
        domain_id = id;
        isolation_type = isolation;
        root_table = IOMMUPageTable().new(0, allocate_page());
        devices = [];
        return this;
    }
    
    fn assign_device(device) {
        if (device == null) {
            return false;
        }
        devices.append(device);
        device.iommu_domain = domain_id;
        return true;
    }
    
    fn remove_device(device) {
        let idx = devices.index_of(device);
        if (idx >= 0) {
            devices.remove_at(idx);
            device.iommu_domain = null;
            return true;
        }
        return false;
    }
    
    fn map_guest_to_host(guest_physical, host_physical, size, flags) {
        # Map a range of guest physical memory to host physical
        # Returns: success boolean
        
        if (size == 0 or (size & 0xFFF) != 0) {
            return false;  # Must be page-aligned
        }
        
        let pages = size / 4096;
        for (page = 0; page < pages; page++) {
            let gpa = guest_physical + (page * 4096);
            let hpa = host_physical + (page * 4096);
            
            if (!map_single_page(gpa, hpa, flags)) {
                return false;
            }
        }
        return true;
    }
    
    fn map_single_page(gpa, hpa, flags) {
        # 4-level page table walk
        # GPA format: [47:39] = L4, [38:30] = L3, [29:21] = L2, [20:12] = L1
        
        let l4_idx = (gpa >> 39) & 0x1FF;
        let l3_idx = (gpa >> 30) & 0x1FF;
        let l2_idx = (gpa >> 21) & 0x1FF;
        let l1_idx = (gpa >> 12) & 0x1FF;
        
        # Walk L4 (PML4)
        let l4_entry = root_table.get_entry(l4_idx);
        let l3_table = null;
        
        if (!root_table.is_present(l4_entry)) {
            # Allocate L3 table
            l3_table = IOMMUPageTable().new(1, allocate_page());
            root_table.set_entry(l4_idx, l3_table.physical_address, 0x3);  # Present + Writable
        } else {
            l3_table = root_table.get_entry(l4_idx);
        }
        
        # Walk L3 (PDPT)
        let l3_entry = l3_table.get_entry(l3_idx);
        let l2_table = null;
        
        if (!l3_table.is_present(l3_entry)) {
            l2_table = IOMMUPageTable().new(2, allocate_page());
            l3_table.set_entry(l3_idx, l2_table.physical_address, 0x3);
        } else {
            l2_table = l3_table.get_entry(l3_idx);
        }
        
        # Walk L2 (PD)
        let l2_entry = l2_table.get_entry(l2_idx);
        let l1_table = null;
        
        if (!l2_table.is_present(l2_entry)) {
            l1_table = IOMMUPageTable().new(3, allocate_page());
            l2_table.set_entry(l2_idx, l1_table.physical_address, 0x3);
        } else {
            l1_table = l2_table.get_entry(l2_idx);
        }
        
        # Set L1 (PT) entry
        l1_table.set_entry(l1_idx, hpa, flags);
        
        return true;
    }
    
    fn unmap_pages(guest_physical, size) {
        # Unmap a range of pages
        let pages = size / 4096;
        for (page = 0; page < pages; page++) {
            let gpa = guest_physical + (page * 4096);
            unmap_single_page(gpa);
        }
        return true;
    }
    
    fn unmap_single_page(gpa) {
        let l4_idx = (gpa >> 39) & 0x1FF;
        let l3_idx = (gpa >> 30) & 0x1FF;
        let l2_idx = (gpa >> 21) & 0x1FF;
        let l1_idx = (gpa >> 12) & 0x1FF;
        
        # Walk to L1 and clear entry
        let l4 = root_table.get_entry(l4_idx);
        if (l4 == null or !root_table.is_present(l4)) {
            return;  # Not mapped
        }
        
        let l3_table = root_table.get_entry(l4_idx);
        let l3 = l3_table.get_entry(l3_idx);
        if (!l3_table.is_present(l3)) {
            return;
        }
        
        let l2_table = l3_table.get_entry(l3_idx);
        let l2 = l2_table.get_entry(l2_idx);
        if (!l2_table.is_present(l2)) {
            return;
        }
        
        let l1_table = l2_table.get_entry(l2_idx);
        l1_table.clear_entry(l1_idx);
    }
    
    fn invalidate_tlb() {
        # Flush TLB cache for this domain
        cache_invalidations += 1;
    }
}

# ============================================================================
# Interrupt Remapping Table (for MSI/MSI-X with DMA remapping)
# ============================================================================

class InterruptRemappingEntry {
    present = false;
    vector = 0;
    delivery_mode = 0;    # 0=fixed, 1=lowest, 2=SMI, 4=NMI, 5=INIT
    destination = 0;       # LAPIC ID or x2APIC ID
    source_id = 0;         # Requester ID (bus/dev/fn)
    
    fn new() {
        return this;
    }
}

class InterruptRemappingTable {
    entries = [];           # Up to 65536 entries
    remapped_interrupts = 0;
    
    fn new(max_entries) {
        entries = array(max_entries);
        for (i = 0; i < max_entries; i++) {
            entries[i] = InterruptRemappingEntry().new();
        }
        return this;
    }
    
    fn set_remap(index, vector, delivery_mode, destination) {
        if (index < 0 or index >= length(entries)) {
            return false;
        }
        
        let entry = entries[index];
        entry.vector = vector;
        entry.delivery_mode = delivery_mode;
        entry.destination = destination;
        entry.present = true;
        remapped_interrupts += 1;
        return true;
    }
    
    fn get_remap(index) {
        if (index < 0 or index >= length(entries)) {
            return null;
        }
        return entries[index];
    }
    
    fn clear_remap(index) {
        if (index >= 0 and index < length(entries)) {
            entries[index].present = false;
            remapped_interrupts -= 1;
        }
    }
    
    fn translate_msi(msi_address, msi_data) {
        # MSI format:
        # Address: [63:20] = 0xFEExx, [19:12] = 0xA0, [11:0] = routing
        # Data: [15:8] = vector, [10:8] = delivery mode
        
        let vector = (msi_data >> 8) & 0xFF;
        let delivery_mode = (msi_data >> 8) & 0x7;
        let destination = (msi_address >> 12) & 0xFF;
        
        return {
            vector: vector,
            delivery_mode: delivery_mode,
            destination: destination
        };
    }
}

# ============================================================================
# Device Pass-Through Manager
# ============================================================================

class PassThroughDevice {
    device_id = 0;        # PCI bus/dev/fn
    bus = 0;
    device = 0;
    function = 0;
    iommu_domain = null;
    host_device = null;   # Reference to actual physical device (stub)
    guest_device = null;  # Virtual wrapper
    passthrough_active = false;
    fault_count = 0;
    max_faults = 10;
    
    fn new(pci_id) {
        device_id = pci_id;
        bus = (pci_id >> 8) & 0xFF;
        device = (pci_id >> 3) & 0x1F;
        function = pci_id & 0x7;
        return this;
    }
    
    fn bind_iommu_domain(domain) {
        iommu_domain = domain;
        return domain.assign_device(this);
    }
    
    fn activate_passthrough() {
        if (iommu_domain == null) {
            return false;  # Must have IOMMU domain
        }
        passthrough_active = true;
        return true;
    }
    
    fn deactivate_passthrough() {
        passthrough_active = false;
        if (iommu_domain != null) {
            iommu_domain.remove_device(this);
        }
        return true;
    }
    
    fn record_fault() {
        fault_count += 1;
        if (fault_count >= max_faults) {
            deactivate_passthrough();  # Auto-disable on excessive faults
        }
    }
    
    fn is_operational() {
        return passthrough_active and fault_count < max_faults;
    }
}

class DevicePassThroughManager {
    domains = [];              # IOMMU domains
    passthrough_devices = [];  # Assigned devices
    irq_remap = null;          # Interrupt remapping table
    dmar_units = 0;            # DMAR unit count (typically 1-4)
    
    fn new() {
        irq_remap = InterruptRemappingTable().new(65536);
        return this;
    }
    
    fn create_domain(domain_id, isolation_type) {
        let domain = IOMMUDomain().new(domain_id, isolation_type);
        domains.append(domain);
        return domain;
    }
    
    fn get_domain(domain_id) {
        for (domain in domains) {
            if (domain.domain_id == domain_id) {
                return domain;
            }
        }
        return null;
    }
    
    fn assign_device_to_domain(device_id, domain_id) {
        # Assign a PCI device to an IOMMU domain
        
        let domain = get_domain(domain_id);
        if (domain == null) {
            return false;
        }
        
        let pt_device = PassThroughDevice().new(device_id);
        if (!pt_device.bind_iommu_domain(domain)) {
            return false;
        }
        
        if (!pt_device.activate_passthrough()) {
            return false;
        }
        
        passthrough_devices.append(pt_device);
        return true;
    }
    
    fn remove_device_from_domain(device_id) {
        # Remove a device from pass-through
        
        let idx = find_passthrough_device(device_id);
        if (idx < 0) {
            return false;
        }
        
        let device = passthrough_devices[idx];
        device.deactivate_passthrough();
        passthrough_devices.remove_at(idx);
        return true;
    }
    
    fn find_passthrough_device(device_id) {
        for (i = 0; i < length(passthrough_devices); i++) {
            if (passthrough_devices[i].device_id == device_id) {
                return i;
            }
        }
        return -1;
    }
    
    fn get_passthrough_device(device_id) {
        let idx = find_passthrough_device(device_id);
        if (idx >= 0) {
            return passthrough_devices[idx];
        }
        return null;
    }
    
    fn map_guest_memory(domain_id, guest_phys, host_phys, size, flags) {
        # Map guest memory to host for DMA
        
        let domain = get_domain(domain_id);
        if (domain == null) {
            return false;
        }
        
        return domain.map_guest_to_host(guest_phys, host_phys, size, flags);
    }
    
    fn unmap_guest_memory(domain_id, guest_phys, size) {
        let domain = get_domain(domain_id);
        if (domain == null) {
            return false;
        }
        
        return domain.unmap_pages(guest_phys, size);
    }
    
    fn setup_interrupt_remap(device_id, irq_index, vector, destination) {
        # Setup interrupt remapping for device MSI
        
        let device = get_passthrough_device(device_id);
        if (device == null or !device.is_operational()) {
            return false;
        }
        
        return irq_remap.set_remap(irq_index, vector, 0, destination);
    }
    
    fn get_interrupt_remap(irq_index) {
        return irq_remap.get_remap(irq_index);
    }
    
    fn report_dma_fault(device_id) {
        # Device reported DMA fault
        let device = get_passthrough_device(device_id);
        if (device != null) {
            device.record_fault();
            if (!device.is_operational()) {
                return "DEVICE_ISOLATED";
            }
        }
        return "FAULT_RECORDED";
    }
    
    fn get_passthrough_status() {
        return {
            total_domains: length(domains),
            assigned_devices: length(passthrough_devices),
            fault_events: count_faults(),
            irq_remappings: irq_remap.remapped_interrupts
        };
    }
    
    fn count_faults() {
        let total = 0;
        for (device in passthrough_devices) {
            total += device.fault_count;
        }
        return total;
    }
}

# ============================================================================
# IOMMU Controller (Hardware Simulation)
# ============================================================================

class IOMMUController {
    # Intel VT-d / AMD-Vi compatible
    
    base_address = 0xFED90000;  # Standard IOMMU base
    capabilities = 0x0;           # Capability register
    version = 0x01;               # Version 1.0
    
    dmar_enabled = false;         # DMA Remapping enabled
    irte_enabled = false;         # Interrupt Remapping enabled
    
    context_entries = [];         # Context table
    irq_table = null;             # Interrupt remapping table
    passt_mgr = null;             # Pass-through manager
    
    fn new() {
        passt_mgr = DevicePassThroughManager().new();
        irq_table = InterruptRemappingTable().new(65536);
        setup_capabilities();
        return this;
    }
    
    fn setup_capabilities() {
        # Set capability bits
        # Bit 0: DMA Remap
        # Bit 1: Interrupt Remap
        # Bit 2: Device IOTLB
        capabilities = 0x7;  # All supported
    }
    
    fn enable_dma_remapping() {
        dmar_enabled = true;
        return true;
    }
    
    fn enable_interrupt_remapping() {
        irte_enabled = true;
        return true;
    }
    
    fn disable_dma_remapping() {
        dmar_enabled = false;
        return true;
    }
    
    fn mmio_read(offset) {
        # Read IOMMU register
        # 0x00: Capabilities
        # 0x04: Extended capabilities
        # 0x08: Global Status
        # 0x0C: Global Control
        # 0x10: Context Command
        
        if (offset == 0x00) {
            return capabilities;
        } else if (offset == 0x04) {
            return version;
        } else if (offset == 0x08) {
            # Global Status Register
            let status = 0x0;
            if (dmar_enabled) {
                status |= 0x1;  # DMA Remapping enabled
            }
            if (irte_enabled) {
                status |= 0x2;  # Interrupt Remapping enabled
            }
            return status;
        } else if (offset == 0x0C) {
            # Global Control Register
            let control = 0x0;
            if (dmar_enabled) {
                control |= 0x1;
            }
            if (irte_enabled) {
                control |= 0x2;
            }
            return control;
        }
        return 0;
    }
    
    fn mmio_write(offset, value) {
        # Write IOMMU register
        if (offset == 0x0C) {  # Global Control
            if ((value & 0x1) != 0) {
                enable_dma_remapping();
            } else {
                disable_dma_remapping();
            }
            
            if ((value & 0x2) != 0) {
                enable_interrupt_remapping();
            }
        }
    }
    
    fn get_passthrough_manager() {
        return passt_mgr;
    }
}

# ============================================================================
# IOMMU Integration Helper
# ============================================================================

class IOMMUManager {
    # High-level IOMMU management for VirtualMachine integration
    
    iommu_controllers = [];      # One per socket typically
    passthrough_enabled = false;
    default_domain = null;
    
    fn new() {
        return this;
    }
    
    fn enable_iommu() {
        if (length(iommu_controllers) == 0) {
            let controller = IOMMUController().new();
            iommu_controllers.append(controller);
        }
        
        for (controller in iommu_controllers) {
            controller.enable_dma_remapping();
            controller.enable_interrupt_remapping();
        }
        
        passthrough_enabled = true;
        return true;
    }
    
    fn disable_iommu() {
        for (controller in iommu_controllers) {
            controller.disable_dma_remapping();
        }
        passthrough_enabled = false;
        return true;
    }
    
    fn create_domain(isolation_type) {
        if (length(iommu_controllers) == 0) {
            return null;
        }
        
        let controller = iommu_controllers[0];
        let domain_id = length(controller.passt_mgr.domains);
        return controller.passt_mgr.create_domain(domain_id, isolation_type);
    }
    
    fn assign_device(device_id, domain_id) {
        if (length(iommu_controllers) == 0) {
            return false;
        }
        
        let controller = iommu_controllers[0];
        return controller.passt_mgr.assign_device_to_domain(device_id, domain_id);
    }
    
    fn remove_device(device_id) {
        if (length(iommu_controllers) == 0) {
            return false;
        }
        
        let controller = iommu_controllers[0];
        return controller.passt_mgr.remove_device_from_domain(device_id);
    }
    
    fn get_status() {
        if (length(iommu_controllers) == 0) {
            return {
                enabled: false,
                controllers: 0,
                domains: 0,
                devices: 0
            };
        }
        
        let controller = iommu_controllers[0];
        let status = controller.passt_mgr.get_passthrough_status();
        return {
            enabled: passthrough_enabled,
            controllers: length(iommu_controllers),
            domains: status.total_domains,
            devices: status.assigned_devices,
            fault_events: status.fault_events
        };
    }
    
    fn report_dma_fault(device_id) {
        if (length(iommu_controllers) == 0) {
            return "NO_IOMMU";
        }
        
        let controller = iommu_controllers[0];
        return controller.passt_mgr.report_dma_fault(device_id);
    }
}

# ============================================================================
# Example: Device Pass-Through Workflow
# ============================================================================

fn example_setup_device_passthrough() {
    # Create IOMMU manager
    let iommu = IOMMUManager().new();
    iommu.enable_iommu();
    
    # Create isolation domain for device
    let domain = iommu.create_domain("STRICT");
    
    # Assign device (e.g., NIC at 0x03:00.0 = device_id 0x0300)
    iommu.assign_device(0x0300, 0);
    
    # Map guest memory for DMA
    # Guest physical 0x10000000 → Host physical 0x40000000, 256MB
    let controller = iommu.iommu_controllers[0];
    controller.passt_mgr.map_guest_memory(0, 0x10000000, 0x40000000, 0x10000000, 0x3);
    
    # Setup interrupt remapping
    controller.passt_mgr.setup_interrupt_remap(0x0300, 0, 32, 0);  # Vector 32, LAPIC 0
    
    return iommu;
}

# ============================================================================
# Integration with ProductionVMBuilder (fluent API extension)
# ============================================================================

# These functions should be added to ProductionVMBuilder in vm_production.ny

fn vm_builder_with_iommu(vm_config) {
    # Add to ProductionVMBuilder:
    # vm.iommu_mgr = IOMMUManager().new();
    # vm.iommu_mgr.enable_iommu();
    return vm_config;
}

fn vm_builder_passthrough_device(vm_config, pci_id, isolation) {
    # Add to ProductionVMBuilder:
    # let domain = vm.iommu_mgr.create_domain(isolation);
    # vm.iommu_mgr.assign_device(pci_id, domain.domain_id);
    return vm_config;
}

# End of vm_iommu.ny
