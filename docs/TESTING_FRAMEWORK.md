# Nyx Hypervisor — Testing & Validation Framework

## Test Categories

### 1. Unit Tests (Component-Level)

#### VM Device Tests
```nyx
test_pic_8259_master_initialization() {
    let pic = vm_devices.PIC8259(true);
    pic.io_write(0x20, 0x11);  # ICW1
    pic.io_write(0x21, 0x08);  # ICW2 - IRQ base 8
    assert(pic.icw_state == 1, "ICW2 expected");
}

test_pic_8259_interrupt_acceptance() {
    let pic = vm_devices.PIC8259(true);
    pic.setup_basic();
    pic.raise_irq(3);  # IRQ3 (COM2)
    assert(pic.irr == 0x08, "IRQ3 should be in IRR");
}

test_pit_timer_frequencies() {
    let pit = vm_devices.PITDevice();
    pit.setup_mode(0, 3);  # Channel 0, Mode 3 (square wave)
    pit.set_count(4);
    let freq = pit.get_output_frequency();
    assert(freq == 1193182 / 4, "Frequency calculation");
}

test_rtc_cmos_storage() {
    let rtc = vm_devices.RTCDevice();
    rtc.io_write(0x70, 0x10);  # NV-RAM address
    rtc.io_write(0x71, 0xAB);  # Write value
    rtc.io_write(0x70, 0x10);  # Read address
    let val = rtc.io_read(0x71);
    assert(val == 0xAB, "CMOS storage failed");
}

test_uart_fifo_operations() {
    let uart = vm_devices.UARTDevice();
    uart.put_char('A');
    uart.put_char('B');
    uart.put_char('C');
    assert(uart.fifo_out.length == 3, "FIFO queue");
    assert(uart.fifo_out[0] == 'A', "FIFO order");
}

test_virtio_block_device_initialization() {
    let vblock = vm_devices.VirtioBlockDevice();
    # Write driver features
    vblock.mmio_write(0x8, 0x00000001);  # RO media
    # Negotiate with device
    let dev_features = vblock.mmio_read(0x0);
    assert(dev_features & 0x00000001 > 0, "RO feature");
}

test_ahci_port_reset() {
    let ahci = vm_devices.AHCIController();
    ahci.io_write(0x500, 0x00000001);  # Port 0 command register - reset
    sleep(100);
    let sts = ahci.io_read(0x508);  # Port 0 status register
    assert(sts & 0x00000080 == 0, "Reset complete");
}

test_e1000_mac_filtering() {
    let e1000 = vm_devices.E1000Device();
    let mac = [0x52, 0x54, 0x00, 0x12, 0x34, 0x56];
    e1000.set_mac(mac);
    let read_mac = e1000.get_mac();
    assert(arrays_equal(mac, read_mac), "MAC address");
}

test_pci_config_space_access() {
    let pci = vm_devices.PCIConfigSpace();
    pci.select_device(0, 0, 0);  # Bus 0, Device 0, Function 0
    pci.write_config(0x00, 0x8086);  # Intel vendor ID
    let vid = pci.read_config(0x00);
    assert(vid == 0x8086, "PCI config RW");
}
```

#### Hypervisor Tests
```nyx
test_vmx_vmxon_vmxoff() {
    let vmx = hypervisor.VMX();
    # This requires actual hardware - test framework provides mock
    assert(vmx.vmx_enabled(), "VMX enabled");
    vmx.vmxon();
    assert(vmx.vmx_active(), "VMXON successful");
    vmx.vmxoff();
    assert(!vmx.vmx_active(), "VMXOFF successful");
}

test_vmx_vmcs_operations() {
    let vmx = hypervisor.VMX();
    vmx.vmxon();
    vmx.vmclear(vmx.vmcs_region);
    vmx.vmptrld(vmx.vmcs_region);
    assert(vmx.current_vmcs == vmx.vmcs_region, "VMCS loaded");
}

test_svm_vmcb_initialization() {
    let svm = hypervisor.SVM();
    let vcpu = svm.create_vcpu();
    assert(vcpu.vmcb != null, "VMCB allocated");
    assert(vcpu.iopm != null, "IO permission map allocated");
    assert(vcpu.msrpm != null, "MSR permission map allocated");
}

test_svm_asid_generation() {
    let svm = hypervisor.SVM();
    let asid1 = svm.get_next_asid();
    let asid2 = svm.get_next_asid();
    assert(asid2 > asid1, "ASID incrementing");
    assert(asid2 - asid1 <= 4096, "ASID generation valid");
}

test_unified_exit_handler_vmx() {
    let exit_info = hypervisor.VMExitInfo(
        exit_reason=3,  # HLT
        rip=0x1000,
        qualification=0
    );
    # Handler should recognize HLT and emulate it
    let result = handle_vmexit(exit_info);
    assert(result.action == EXIT_ACTION_EMULATE, "HLT emulation");
}

test_unified_exit_handler_svm() {
    let exit_code = 0x72;  # SVM HLT equivalent
    # Mapping: SVM 0x72 -> VMX 3 (HLT)
    let vmx_reason = svm_to_vmx_exit_code(exit_code);
    assert(vmx_reason == 3, "Exit code mapping");
}
```

#### Error Handling Tests
```nyx
test_exception_handler_registration() {
    let err_handler = vm_errors.ExceptionHandler();
    let called = false;
    err_handler.register_exception_handler(
        EXCEPTION_PAGE_FAULT,
        fn(ctx) { called = true; return RECOVERY_CONTINUE; }
    );
    let result = err_handler.handle_exception(EXCEPTION_PAGE_FAULT, {});
    assert(called, "Handler invoked");
}

test_recovery_strategy_routing() {
    let err_handler = vm_errors.ExceptionHandler();
    # Page fault should route to RESET_VCPU
    assert(err_handler.default_strategy[EXCEPTION_PAGE_FAULT] == RECOVERY_RESET_VCPU, 
           "Default PF recovery");
    # Machine check should route to SHUTDOWN
    assert(err_handler.default_strategy[EXCEPTION_MACHINE_CHECK] == RECOVERY_SHUTDOWN,
           "Default MC recovery");
}

test_watchdog_timeout_detection() {
    let watchdog = vm_errors.WatchdogTimer(100);  # 100ms timeout
    watchdog.start_timer(0);  # VCPU 0
    sleep(50);
    assert(!watchdog.is_timeout(0), "No timeout yet");
    sleep(60);
    assert(watchdog.is_timeout(0), "Timeout detected");
}

test_state_validator_vmcs_consistency() {
    let validator = vm_errors.StateValidator();
    let vmcs = {CR3: 0x001000, CR0: 0x80010031, RIP: 0x400000};
    assert(validator.validate_vmcs_state(vmcs), "Valid VMCS");
    
    vmcs.CR3 = 0x001001;  # Misaligned page table
    assert(!validator.validate_vmcs_state(vmcs), "Invalid alignment");
}

test_fault_isolation_device_quarantine() {
    let isolation = vm_errors.FaultIsolation(device_id=5, max_faults=3);
    isolation.record_fault();
    isolation.record_fault();
    assert(!isolation.is_isolated(), "Not isolated yet");
    isolation.record_fault();
    assert(isolation.is_isolated(), "Device isolated");
}
```

#### TPM Tests
```nyx
test_tpm2_pcr_extend() {
    let tpm = vm_tpm.TPM2_Device();
    tpm.startup();
    
    # Read initial PCR[0]
    let initial = tpm.pcr_bank[0];
    assert(initial == "0" * 64, "Initial PCR is zeros");
    
    # Extend with new value
    tpm.execute_command(TPM_CMD_PCR_EXTEND, {
        pcr_index: 0,
        hash: "sha256",
        value: "ABCD1234"
    });
    
    let extended = tpm.pcr_bank[0];
    assert(extended != initial, "PCR extended");
}

test_tpm2_nv_storage() {
    let tpm = vm_tpm.TPM2_Device();
    
    # Define NV index
    tpm.execute_command(TPM_CMD_NV_DEFINESPACE, {
        index: 0x1000001,
        size: 64,
        attributes: 0x0000
    });
    
    # Write to NV
    let data = "Hello TPM2.0";
    tpm.execute_command(TPM_CMD_NV_WRITE, {
        index: 0x1000001,
        offset: 0,
        data: data
    });
    
    # Read from NV
    let written = tpm.execute_command(TPM_CMD_NV_READ, {
        index: 0x1000001,
        offset: 0,
        size: length(data)
    });
    
    assert(written == data, "NV storage RW");
}

test_tpm2_handle_management() {
    let handles = vm_tpm.TPM2_HandleManager();
    let h1 = handles.allocate_handle();
    let h2 = handles.allocate_handle();
    assert(h2 > h1, "Handles increment");
    assert((h1 & 0xFF000000) == 0x80000000, "Handle prefix");
    
    handles.flush_handle(h1);
    assert(!handles.is_handle_loaded(h1), "Handle flushed");
}

test_tpm2_command_dispatch() {
    let tpm = vm_tpm.TPM2_Device();
    
    # GetCapability command
    let response = tpm.process_command([
        0x00, 0x01,  # Tag: COMMAND
        0x00, 0x00, 0x00, 0x0D,  # Command size
        0x00, 0x00, 0x01, 0x7A,  # Command: GetCapability
        0x00  # Property group: HANDLES
    ]);
    
    assert(response[0] == 0x80, "Response tag");
    assert(response[2] == 0x00, "No TPM error");
}
```

#### ACPI Tests
```nyx
test_acpi_s_state_transition() {
    let acpi = vm_acpi_advanced.ACPIPowerStateManager();
    assert(acpi.current_state == ACPI_STATE_S0, "Initial state S0");
    
    acpi.transition_to_state(ACPI_STATE_S3);
    assert(acpi.current_state == ACPI_STATE_S3, "S3 transition");
    assert(acpi.energy_consumption() < acpi.energy_in_s0(), "Lower power");
    
    acpi.transition_to_state(ACPI_STATE_S0);
    assert(acpi.current_state == ACPI_STATE_S0, "Wake from S3");
}

test_acpi_thermal_zone_cooling() {
    let thermal = vm_acpi_advanced.ACPIThermalZone("CPU", 0);
    thermal.set_temperature(85);  # 85°C
    thermal.set_trip_point("passive", 80);
    thermal.set_trip_point("critical", 100);
    
    let action = thermal.get_required_action();
    assert(action == THERMAL_ACTION_PASSIVE, "Passive cooling");
    
    thermal.set_temperature(105);
    action = thermal.get_required_action();
    assert(action == THERMAL_ACTION_CRITICAL, "Critical action");
}

test_acpi_battery_state_transitions() {
    let battery = vm_acpi_advanced.ACPIBatteryDevice();
    battery.set_charge(100);
    battery.set_state(BATTERY_STATE_CHARGING);
    
    battery.set_charge(80);
    assert(battery.get_state() == BATTERY_STATE_CHARGING, "Still charging");
    
    battery.set_state(BATTERY_STATE_DISCHARGING);
    battery.set_charge(5);
    assert(battery.get_state() == BATTERY_STATE_CRITICAL, "Critical level");
}

test_acpi_button_events() {
    let manager = vm_acpi_advanced.ACPIAdvancedEventManager();
    let events = [];
    
    manager.register_callback(fn(event) {
        events.append(event);
    });
    
    manager.power_button.press();
    assert(events[-1].type == EVENT_POWER_BUTTON, "Power button event");
    
    manager.lid_switch.open();
    assert(events[-1].type == EVENT_LID_OPEN, "Lid open event");
}
```

#### Migration Tests
```nyx
test_dirty_page_tracking_basic() {
    let tracker = vm_migration.DirtyPageTracker(
        memory_size=1024*1024*1024,  # 1GB
        page_size=4096
    );
    
    tracker.enable_tracking();
    tracker.mark_page_dirty(0x001000);
    tracker.mark_page_dirty(0x002000);
    
    let dirty = tracker.get_dirty_pages();
    assert(length(dirty) == 2, "Dirty pages tracked");
    assert(0x001000 in dirty, "Page 1 dirty");
    assert(0x002000 in dirty, "Page 2 dirty");
}

test_dirty_page_generation_counter() {
    let tracker = vm_migration.DirtyPageTracker(memory_size=1*1024**3);
    tracker.enable_tracking();
    
    tracker.mark_page_dirty(0x001000);
    let gen1 = tracker.generation;
    
    tracker.clear_dirty_map();
    let gen2 = tracker.generation;
    
    assert(gen2 > gen1, "Generation incremented");
}

test_live_migration_precopy() {
    let migration = vm_migration.LiveMigration();
    let vm = VirtualMachine({memory_size: 100*1024*1024});  # 100MB for testing
    
    let result = migration.start_iterative_precopy(
        vm,
        "dest_host",
        {max_iterations: 3}
    );
    
    assert(result.success, "Precopy started");
    assert(result.iterations_completed <= 3, "Iteration limit");
    assert(result.converged or result.iterations_completed == 3, "Convergence or limit");
}

test_vm_state_serialization() {
    let serializer = vm_migration.VMStateSerializer();
    let vm = VirtualMachine({memory_size: 10*1024*1024});
    
    # Fill some memory
    vm.memory.write(0x100000, [0xAA, 0xBB, 0xCC, 0xDD]);
    
    # Serialize
    let state = serializer.serialize(vm);
    assert(state.has_key("memory"), "Memory in state");
    assert(state.has_key("vcpu"), "vCPU state in serialization");
    assert(state.has_key("devices"), "Device state");
    
    # Deserialize to new VM
    let new_vm = VirtualMachine({memory_size: 10*1024*1024});
    serializer.deserialize(new_vm, state);
    
    let data = new_vm.memory.read(0x100000, 4);
    assert(arrays_equal(data, [0xAA, 0xBB, 0xCC, 0xDD]), "State restored");
}
```

#### Hotplug Tests
```nyx
test_pci_hotplug_device_addition() {
    let vm = VirtualMachine({});
    vm.dynamic_devices.enable_pci_hotplug();
    
    let nic = vm_devices.E1000Device();
    vm.dynamic_devices.add_pci_device(nic);
    
    assert(vm.dynamic_devices.devices.length > 0, "Device added");
    assert(vm.dynamic_devices.get_pci_slot_for_device(nic) != null, "Slot assigned");
}

test_pci_hotplug_device_removal() {
    let vm = VirtualMachine({});
    vm.dynamic_devices.enable_pci_hotplug();
    
    let nic = vm_devices.E1000Device();
    vm.dynamic_devices.add_pci_device(nic);
    let slot = vm.dynamic_devices.get_pci_slot_for_device(nic);
    
    vm.dynamic_devices.remove_pci_device(slot);
    assert(!vm.dynamic_devices.get_pci_slot_for_device(nic), "Device removed");
}

test_pci_hotplug_irq_event() {
    let controller = vm_hotplug.PCIHotplugController();
    let events = [];
    
    controller.register_event_callback(fn(event) {
        events.append(event);
    });
    
    let slot = vm_hotplug.PCIHotplugSlot();
    slot.insert_device();
    
    assert(events.length > 0, "Event queued");
}
```

#### Logging Tests
```nyx
test_logger_severity_filtering() {
    let logger = vm_logging.Logger();
    logger.set_level(LOG_LEVEL_WARN);
    
    let output = [];
    logger.register_output(fn(level, comp, msg) {
        output.append({level: level, msg: msg});
    });
    
    logger.trace("test", "Message1");  # Should be filtered
    logger.warn("test", "Message2");   # Should pass
    logger.error("test", "Message3");  # Should pass
    
    assert(output.length == 2, "Trace filtered");
    assert(output[0].level == LOG_LEVEL_WARN, "Warn passed");
}

test_logger_ring_buffer() {
    let logger = vm_logging.Logger();
    
    # Fill buffer beyond capacity (default 10000)
    for (i = 0; i < 15000; i++) {
        logger.info("test", "Message " + i);
    }
    
    assert(logger.ring_buffer.length <= 10000, "Ring buffer bounded");
    assert(logger.ring_buffer[-1].message.contains("14999"), "Latest preserved");
}

test_performance_tracer_spans() {
    let tracer = vm_logging.PerformanceTracer();
    
    tracer.start_span("Operation A");
    sleep(10);
    tracer.add_event("SubEvent 1");
    sleep(10);
    tracer.end_span();
    
    let stats = tracer.get_statistics();
    assert(stats.slowest_spans[-1].name == "Operation A", "Span tracked");
    assert(stats.slowest_spans[-1].duration_us >= 20000, "Duration recorded");
}

test_breakpoint_hit_counting() {
    let bp = vm_logging.BreakpointManager();
    bp.add_instruction_breakpoint(0x401000);
    
    for (i = 0; i < 5; i++) {
        assert(bp.should_break_at(0x401000), "Breakpoint hit");
    }
    
    assert(bp.get_hit_count(0x401000) == 5, "Hit count");
}

test_debug_symbol_lookup() {
    let symbols = vm_logging.DebugSymbolManager();
    symbols.register_symbol(0x401000, "main", "function");
    symbols.register_symbol(0x401234, "helper", "function");
    
    let sym1 = symbols.lookup_symbol(0x401000);
    assert(sym1.name == "main", "Symbol found");
    
    # Address within function
    let sym2 = symbols.lookup_symbol(0x401010);
    assert(sym2.name == "main", "Nearest symbol");
    assert(sym2.offset == 0x10, "Offset calculated");
}
```

#### Metrics Tests
```nyx
test_performance_counter_types() {
    let counter_event = vm_metrics.PerformanceCounter("exits", "event_count");
    counter_event.increment();
    counter_event.increment();
    assert(counter_event.value == 2, "Event counting");
    
    let counter_latency = vm_metrics.PerformanceCounter("io_latency", "histogram");
    counter_latency.record_value(100);
    counter_latency.record_value(200);
    assert(counter_latency.average() == 150, "Average calculation");
}

test_metrics_collector_snapshots() {
    let collector = vm_metrics.VMMetricsCollector();
    collector.counters["exits"] = vm_metrics.PerformanceCounter("exits", "event_count");
    collector.counters["exits"].increment_by(100);
    
    let snap1 = collector.take_snapshot();
    sleep(100);
    
    collector.counters["exits"].increment_by(50);
    let snap2 = collector.take_snapshot();
    
    assert(snap2.timestamp > snap1.timestamp, "Timestamp progression");
    assert(snap2.counters["exits"] == 150, "Counter accumulation");
}

test_performance_monitor_bottleneck_detection() {
    let monitor = vm_metrics.VMPerformanceMonitor();
    
    # Simulate high exit rate
    for (i = 0; i < 200000; i++) {
        monitor.record_exit();
    }
    
    let bottlenecks = monitor.identify_bottleneck();
    let has_exit_bottleneck = false;
    for (bn in bottlenecks) {
        if (bn[0] == "vm_exit_rate") {
            has_exit_bottleneck = true;
        }
    }
    assert(has_exit_bottleneck, "Exit bottleneck detected");
}
```

### 2. Integration Tests (Module-to-Module)

```nyx
test_hypervisor_to_device_communication() {
    let hyp = hypervisor.Hypervisor();
    let vm = VirtualMachine({});
    
    # I/O to PIC
    hyp.emulate_io_out(0x20, 0x20);  # Send EOI to PIC master
    # PIC should update its state
    assert(vm.bus.devices["pic_master"].in_service_register_updated, "Device updated");
}

test_vm_to_device_bus_routing() {
    let vm = VirtualMachine({});
    let device = DummyDevice();
    vm.bus.register_io_device(0x3F8, 0x8, device);
    
    # Access should route through bus
    vm.bus.io_write(0x3F8, 0xAA);
    assert(device.last_write == 0xAA, "Device received write");
}

test_error_handler_to_recovery() {
    let vm = VirtualMachine({});
    let original_rip = vm.vcpus[0].rip;
    
    # Trigger page fault with recovery
    vm.error_handler.handle_exception(
        EXCEPTION_PAGE_FAULT,
        {guest_rip: original_rip}
    );
    
    # Should attempt recovery (e.g., reset VCPU)
    # Actual recovery depends on strategy
    assert(vm.error_handler.last_exception == EXCEPTION_PAGE_FAULT, "Exception recorded");
}

test_migration_with_dirty_tracking() {
    let vm = VirtualMachine({memory_size: 100*1024*1024});
    vm.dirty_tracker.enable_tracking();
    
    # Simulate guest modifying memory
    vm.memory.write(0x100000, 0xFF);
    let dirty_pages = vm.dirty_tracker.get_dirty_pages();
    
    assert(0x100000 in dirty_pages, "Dirty page detected");
}

test_hotplug_with_error_handling() {
    let vm = VirtualMachine({});
    vm.dynamic_devices.enable_pci_hotplug();
    vm.error_handler = vm_errors.ExceptionHandler();
    
    let faulty_device = FaultyDevice();
    vm.dynamic_devices.add_pci_device(faulty_device);
    
    # Device fails - should be isolated
    if (faulty_device.fault_count >= 3) {
        vm.error_handler.handle_fault(faulty_device);
        # Device should be isolated
        assert(vm.dynamic_devices.is_device_isolated(faulty_device), "Faulty device isolated");
    }
}

test_logging_across_modules() {
    let vm = VirtualMachine({});
    let logger = vm_logging.Logger();
    
    # Multiple modules share same logger
    vm._logger = logger;
    
    vm.handle_device_io();
    vm.handle_interrupt();
    vm.handle_migration();
    
    let logs = logger.get_logs("device");
    assert(logs.length > 0, "Device logs present");
}

test_metrics_collection_during_migration() {
    let vm = VirtualMachine({memory_size: 100*1024*1024});
    let metrics = vm.metrics;
    metrics.metrics.enable_collection();
    
    # Start migration
    vm.migration_mgr.start_iterative_precopy(vm, "dest");
    
    # Metrics should record migration activity
    let report = metrics.get_performance_report();
    assert(report.migration_memory_transferred > 0, "Migration tracked");
}
```

### 3. System Tests (Full VM Lifecycle)

```nyx
test_vm_bios_boot_sequence() {
    let vm = ProductionVMBuilder()
        .memory(256 * 1024 * 1024)  # 256MB
        .cpus(1)
        .bios("seabios.bin")
        .build();
    
    # Run until first HLT
    let exit_count = 0;
    while (exit_count < 10000) {
        vm.run_one_tick();
        exit_count++;
        if (vm.vcpus[0].halted) break;
    }
    
    assert(vm.vcpus[0].halted, "Boot completed with HLT");
    assert(vm.memory.read(0x5E0, 2) != [0, 0], "EBDA configured");
}

test_vm_uefi_boot_sequence() {
    let vm = ProductionVMBuilder()
        .memory(512 * 1024 * 1024)  # 512MB for UEFI
        .cpus(2)
        .uefi("OVMF.fd")
        .disk("test.img")
        .with_logging()
        .build();
    
    let success_markers = 0;
    let max_cycles = 50000;
    
    for (i = 0; i < max_cycles; i++) {
        vm.run_one_tick();
        
        # Check for success markers
        if (vm.dcx.current_state == STATE_RUNNING) {
            success_markers++;
        }
        if (success_markers > 100) break;
    }
    
    assert(success_markers > 100, "UEFI boot progressing");
}

test_vm_multiprocessor_boot() {
    let vm = ProductionVMBuilder()
        .cpus(4)
        .uefi("OVMF.fd")
        .build();
    
    # Boot BSP first
    while (!vm.vcpus[0].running) {
        vm.run_one_tick();
    }
    
    # AP bring-up via SIPI
    for (ap_id = 1; ap_id < 4; ap_id++) {
        vm.send_sipi(ap_id);
    }
    
    # Wait for APs
    sleep(1000);
    for (ap_id = 1; ap_id < 4; ap_id++) {
        assert(vm.vcpus[ap_id].running, "AP" + ap_id + " started");
    }
}

test_vm_device_interrupt_delivery() {
    let vm = VirtualMachine({});
    vm.init_devices();
    
    # Simulate device interrupt
    vm.bus.devices["pit"].raise_irq(0);
    
    # vCPU should be notified
    assert(vm.vcpus[0].pending_interrupts > 0, "Interrupt annotated");
    
    # VM exit to handle interrupt
    vm.run_one_tick();
    
    # Check if interrupt delivered
    assert(vm.vcpus[0].rip != 0, "Interrupt vector fetched");
}

test_vm_i_o_operations() {
    let vm = ProductionVMBuilder()
        .disk("test.qcow2")
        .build();
    
    # Attempt I/O operation
    vm.bus.io_write(0x1F0, 0xEC);  # IDENTIFY_DEVICE on IDE
    
    let disk_state = vm.bus.devices["storage"].state;
    assert(disk_state != null, "Disk responded");
}

test_vm_error_recovery_page_fault() {
    let vm = ProductionVMBuilder()
        .with_error_handling()
        .with_logging()
        .build();
    
    # Simulate page fault
    let vcpu = vm.vcpus[0];
    vcpu.rip = 0x100000;
    
    # Inject page fault exception
    vm.error_handler.handle_exception(
        EXCEPTION_PAGE_FAULT,
        {
            guest_rip: vcpu.rip,
            error_code: page_not_present | write_access
        }
    );
    
    # VM should recover or pause
    assert(vm.running or vm.paused, "VM recovered or paused");
}

test_vm_live_migration_workflow() {
    let source_vm = ProductionVMBuilder()
        .memory(100 * 1024 * 1024)
        .with_live_migration()
        .build();
    
    # Run source VM briefly
    for (i = 0; i < 1000; i++) {
        source_vm.run_one_tick();
    }
    
    # Start migration
    let migration = source_vm.migration_mgr;
    let success = migration.start_iterative_precopy(source_vm, "dest_host");
    assert(success.success, "Migration started");
    
    # When converged, do stop-and-copy
    if (success.converged) {
        source_vm.pause();
        success = migration.start_stop_and_copy(source_vm, "dest_host");
        assert(success.success, "Stop-and-copy completed");
    }
}

test_vm_pci_hotplug_device() {
    let vm = ProductionVMBuilder()
        .with_pci_hotplug()
        .build();
    
    # Initial device count
    let initial_count = vm.dynamic_devices.devices.length;
    
    # Hotplug new NIC
    let new_nic = vm_devices.E1000Device();
    vm.dynamic_devices.add_pci_device(new_nic);
    
    assert(vm.dynamic_devices.devices.length == initial_count + 1, "Device added");
    
    # Guest should see new device via PCI enumeration
    let pci_devices = vm.bus.enumerate_pci_devices();
    assert(length(pci_devices) > 0, "PCI device visible");
}

test_vm_tpm_secure_boot() {
    let vm = ProductionVMBuilder()
        .uefi("OVMF_SECUREBOOT.fd")
        .with_tpm()
        .build();
    
    # Check TPM is initialized
    assert(vm.tpm != null, "TPM available");
    
    # PCRs should be extended during boot
    let pcr0_after_boot = vm.tpm.read_pcr(0);
    assert(pcr0_after_boot != "0" * 64, "PCR0 extended");
}

test_vm_performance_metrics_collection() {
    let vm = ProductionVMBuilder()
        .with_metrics()
        .build();
    
    # Run VM
    for (i = 0; i < 10000; i++) {
        vm.run_one_tick();
    }
    
    # Get metrics
    let report = vm.metrics.get_performance_report();
    assert(report.total_exits > 0, "Exits counted");
    assert(report.avg_exit_time_us > 0, "Exit time measured");
    
    # Check for bottlenecks
    let bottlenecks = vm.metrics.identify_bottleneck();
    # May or may not have bottlenecks, but should return list
    assert(typeof(bottlenecks) == "array", "Bottleneck detection");
}
```

### 4. Stress Tests (Stability Under Load)

```nyx
test_vm_cpu_stress() {
    let vm = ProductionVMBuilder()
        .cpus(8)
        .build();
    
    # Heavy compute workload
    for (i = 0; i < 100000; i++) {
        vm.run_one_tick();
        # All vCPUs running
        assert(vm.active_vcpu_count() > 0, "vCPUs active");
    }
    
    assert(!vm.crashed, "VM stable under CPU stress");
}

test_vm_memory_stress() {
    let vm = ProductionVMBuilder()
        .memory(1024 * 1024 * 1024)  # 1GB
        .build();
    
    # Simulate memory access patterns
    let addrs = [0x100000, 0x200000, 0x300000, 0x400000];
    for (iteration = 0; iteration < 10000; iteration++) {
        for (addr in addrs) {
            vm.memory.write(addr, random_value());
        }
    }
    
    assert(!vm.crashed, "VM stable under memory stress");
}

test_vm_i_o_stress() {
    let vm = ProductionVMBuilder()
        .disk("test.img")
        .nic("e1000")
        .build();
    
    # Rapid I/O operations
    for (i = 0; i < 10000; i++) {
        vm.bus.io_write(0x1F0, 0xAA);  # Disk I/O
        vm.bus.io_write(0x100, 0xBB);  # Network I/O
    }
    
    assert(!vm.crashed, "VM stable under I/O stress");
}

test_vm_exception_handling_stress() {
    let vm = ProductionVMBuilder()
        .with_error_handling()
        .build();
    
    # Inject many exceptions
    for (i = 0; i < 1000; i++) {
        vm.error_handler.handle_exception(
            EXCEPTION_PAGE_FAULT,
            {guest_rip: 0x400000 + i * 0x1000}
        );
    }
    
    assert(vm.error_handler.ring_buffer.length <= 1024, "Ring buffer bounded");
    assert(!vm.crashed, "VM stable under exception stress");
}

test_vm_logging_stress() {
    let vm = ProductionVMBuilder()
        .with_logging()
        .build();
    
    # Rapid logging
    for (i = 0; i < 100000; i++) {
        vm.logger.info("VM", "Message " + i);
    }
    
    assert(vm.logger.ring_buffer.length <= 10000, "Ring buffer size");
    assert(!vm.crashed, "Logging doesn't crash VM");
}

test_vm_migration_stress() {
    let vm = ProductionVMBuilder()
        .memory(500 * 1024 * 1024)
        .with_live_migration()
        .build();
    
    # Perform multiple migrations
    for (migration_cycle = 0; migration_cycle < 5; migration_cycle++) {
        vm.dirty_tracker.enable_tracking();
        vm.migration_mgr.start_iterative_precopy(vm, "dest_" + migration_cycle);
        vm.migration_mgr.reset_migration_state();
    }
    
    assert(!vm.crashed, "VM stable after repeated migrations");
}
```

## Test Execution Framework

```nyx
class TestRunner {
    tests = [];
    results = {passed: 0, failed: 0, errors: []};
    
    register_test(name, test_fn) {
        tests.append({name: name, fn: test_fn});
    }
    
    run_all() {
        for (test in tests) {
            try {
                test.fn();
                results.passed += 1;
                printf("✓ %s\n", test.name);
            } catch (err) {
                results.failed += 1;
                results.errors.append({test: test.name, error: err});
                printf("✗ %s: %s\n", test.name, err);
            }
        }
        print_summary();
    }
    
    print_summary() {
        printf("\n=== Test Results ===\n");
        printf("Passed: %d\n", results.passed);
        printf("Failed: %d\n", results.failed);
        printf("Total:  %d\n", results.passed + results.failed);
        
        if (results.failed > 0) {
            printf("\nFailures:\n");
            for (error in results.errors) {
                printf("  - %s: %s\n", error.test, error.error);
            }
        }
    }
}

fn main() {
    let runner = TestRunner();
    
    # Register all tests
    runner.register_test("PIC 8259 Init", test_pic_8259_master_initialization);
    runner.register_test("PIT Frequencies", test_pit_timer_frequencies);
    runner.register_test("RTC CMOS", test_rtc_cmos_storage);
    runner.register_test("UART FIFO", test_uart_fifo_operations);
    runner.register_test("VMX Operations", test_vmx_vmcs_operations);
    runner.register_test("SVM Setup", test_svm_vmcb_initialization);
    runner.register_test("Exception Handler", test_exception_handler_registration);
    runner.register_test("TPM PCR Extend", test_tpm2_pcr_extend);
    runner.register_test("ACPI States", test_acpi_s_state_transition);
    runner.register_test("Dirty Tracking", test_dirty_page_tracking_basic);
    runner.register_test("Hotplug Add", test_pci_hotplug_device_addition);
    runner.register_test("Logging Filter", test_logger_severity_filtering);
    runner.register_test("Metrics Collection", test_performance_counter_types);
    runner.register_test("VM BIOS Boot", test_vm_bios_boot_sequence);
    runner.register_test("VM UEFI Boot", test_vm_uefi_boot_sequence);
    runner.register_test("CPU Stress", test_vm_cpu_stress);
    runner.register_test("Memory Stress", test_vm_memory_stress);
    
    # Run all tests
    runner.run_all();
    
    # Exit with appropriate code
    if (runner.results.failed > 0) {
        exit(1);
    } else {
        exit(0);
    }
}
```

## Continuous Validation Checklist

- [ ] Unit tests pass (96+ tests)
- [ ] Integration tests pass (8+ tests)
- [ ] System tests pass (8+ boot scenarios)
- [ ] Stress tests pass (5+ stress scenarios)
- [ ] No memory leaks (valgrind clean)
- [ ] No undefined behavior (UBSAN clean)
- [ ] Address sanitizer clean
- [ ] Thread sanitizer clean
- [ ] Performance metrics within 10% baseline
- [ ] Error logs ≤ 5 expected exceptions
- [ ] Crash dumps cleared

---

**Nyx Hypervisor v2.0 — Enterprise Test Suite**
