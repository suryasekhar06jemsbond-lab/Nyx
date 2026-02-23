# ===========================================
# Performance Monitoring & Metrics — Production Grade
# ===========================================
# Real-time performance metrics, resource monitoring,
# event counting, profiling, and bottleneck analysis.

import systems
import hardware

# ===========================================
# Performance Counters
# ===========================================

class PerformanceCounter {
    fn init(self, name, counter_type) {
        self.name = name;
        self.counter_type = counter_type;  # "event_count", "gauge", "histogram"
        self.value = 0;
        self.start_time = 0;
        self.sample_count = 0;
        self.min_value = 0x7FFFFFFFFFFFFFFF;
        self.max_value = 0;
        self.total_value = 0;
    }

    fn increment(self) {
        self.value = self.value + 1;
        self.sample_count = self.sample_count + 1;
        self.total_value = self.total_value + 1;
        self.update_minmax(1);
    }

    fn add(self, delta) {
        self.value = self.value + delta;
        self.sample_count = self.sample_count + 1;
        self.total_value = self.total_value + delta;
        self.update_minmax(delta);
    }

    fn set(self, val) {
        self.value = val;
        self.update_minmax(val);
    }

    fn update_minmax(self, val) {
        if val < self.min_value { self.min_value = val; }
        if val > self.max_value { self.max_value = val; }
    }

    fn get_average(self) {
        if self.sample_count == 0 { return 0; }
        return self.total_value / self.sample_count;
    }

    fn reset(self) {
        self.value = 0;
        self.sample_count = 0;
        self.total_value = 0;
        self.min_value = 0x7FFFFFFFFFFFFFFF;
        self.max_value = 0;
    }

    fn get_stats(self) {
        return {
            "name": self.name,
            "value": self.value,
            "average": self.get_average(),
            "min": self.min_value,
            "max": self.max_value,
            "samples": self.sample_count
        };
    }
}

# ===========================================
# VM Metrics Collector
# ===========================================

class VMMetricsCollector {
    fn init(self) {
        self.counters = {};
        self.collection_enabled = false;
        self.collection_interval = 1000;  # ms
        self.last_collection = hardware.rdtsc();
        self.snapshots = [];
        self.max_snapshots = 1000;
    }

    fn register_counter(self, name, counter_type) {
        self.counters[name] = PerformanceCounter(name, counter_type);
    }

    fn increment_counter(self, name) {
        if name in self.counters {
            self.counters[name].increment();
        }
    }

    fn add_counter(self, name, delta) {
        if name in self.counters {
            self.counters[name].add(delta);
        }
    }

    fn set_counter(self, name, value) {
        if name in self.counters {
            self.counters[name].set(value);
        }
    }

    fn enable_collection(self) {
        self.collection_enabled = true;
        self.last_collection = hardware.rdtsc();
    }

    fn disable_collection(self) {
        self.collection_enabled = false;
    }

    fn collect_snapshot(self) {
        if !self.collection_enabled { return; }

        let snapshot = {
            "timestamp": hardware.rdtsc(),
            "counters": {}
        };

        for counter_name in self.counters {
            let counter = self.counters[counter_name];
            snapshot["counters"][counter_name] = counter.get_stats();
        }

        push(self.snapshots, snapshot);

        # Keep snapshots bounded
        if len(self.snapshots) > self.max_snapshots {
            self.snapshots = self.snapshots[1..];
        }
    }

    fn get_metric(self, name) {
        if name in self.counters {
            return self.counters[name].get_stats();
        }
        return null;
    }

    fn get_all_metrics(self) {
        let metrics = {};
        for name in self.counters {
            metrics[name] = self.counters[name].get_stats();
        }
        return metrics;
    }

    fn get_snapshots(self, filter_name) {
        if filter_name == null { return self.snapshots; }

        let filtered = [];
        for snapshot in self.snapshots {
            if filter_name in snapshot["counters"] {
                push(filtered, snapshot);
            }
        }
        return filtered;
    }

    fn reset_all(self) {
        for name in self.counters {
            self.counters[name].reset();
        }
    }
}

# ===========================================
# VM Performance Monitor
# ===========================================

class VMPerformanceMonitor {
    fn init(self) {
        self.metrics = VMMetricsCollector();
        self.vcpu_metrics = [];
        self.device_metrics = {};
        self.memory_metrics = null;
        self.disk_io_metrics = null;
        self.network_metrics = null;
        
        # Register standard counters
        self.setup_standard_counters();
    }

    fn setup_standard_counters(self) {
        # Hypervisor level counters
        self.metrics.register_counter("total_vmexits", "event_count");
        self.metrics.register_counter("cpuid_exits", "event_count");
        self.metrics.register_counter("io_exits", "event_count");
        self.metrics.register_counter("mmio_exits", "event_count");
        self.metrics.register_counter("msr_exits", "event_count");
        self.metrics.register_counter("interrupt_injections", "event_count");
        
        # Memory metrics
        self.memory_metrics = {
            "guest_memory_allocated": 0,
            "dirty_pages": 0,
            "balloon_size": 0
        };
        
        # I/O metrics
        self.disk_io_metrics = {
            "read_ops": PerformanceCounter("disk_reads", "event_count"),
            "write_ops": PerformanceCounter("disk_writes", "event_count"),
            "read_bytes": PerformanceCounter("disk_read_bytes", "gauge"),
            "write_bytes": PerformanceCounter("disk_write_bytes", "gauge"),
            "avg_read_latency": 0,
            "avg_write_latency": 0
        };
        
        # Network metrics
        self.network_metrics = {
            "rx_packets": PerformanceCounter("rx_packets", "event_count"),
            "tx_packets": PerformanceCounter("tx_packets", "event_count"),
            "rx_bytes": PerformanceCounter("rx_bytes", "gauge"),
            "tx_bytes": PerformanceCounter("tx_bytes", "gauge"),
            "rx_errors": PerformanceCounter("rx_errors", "event_count"),
            "tx_errors": PerformanceCounter("tx_errors", "event_count"),
            "dropped_packets": PerformanceCounter("dropped_packets", "event_count")
        };
    }

    fn record_vmexit(self, exit_reason) {
        self.metrics.increment_counter("total_vmexits");
        
        # Record specific exit type
        if exit_reason == 10 { self.metrics.increment_counter("cpuid_exits"); }
        else if exit_reason == 30 { self.metrics.increment_counter("io_exits"); }
        else if exit_reason == 48 { self.metrics.increment_counter("mmio_exits"); }
        else if exit_reason == 31 or exit_reason == 32 { self.metrics.increment_counter("msr_exits"); }
    }

    fn record_interrupt_injection(self) {
        self.metrics.increment_counter("interrupt_injections");
    }

    fn record_disk_read(self, bytes, latency_us) {
        self.disk_io_metrics["read_ops"].increment();
        self.disk_io_metrics["read_bytes"].add(bytes);
        self.disk_io_metrics["avg_read_latency"] = latency_us;
    }

    fn record_disk_write(self, bytes, latency_us) {
        self.disk_io_metrics["write_ops"].increment();
        self.disk_io_metrics["write_bytes"].add(bytes);
        self.disk_io_metrics["avg_write_latency"] = latency_us;
    }

    fn record_network_rx(self, bytes) {
        self.network_metrics["rx_packets"].increment();
        self.network_metrics["rx_bytes"].add(bytes);
    }

    fn record_network_tx(self, bytes) {
        self.network_metrics["tx_packets"].increment();
        self.network_metrics["tx_bytes"].add(bytes);
    }

    fn record_device_io(self, device_name, op_type, size) {
        if device_name not in self.device_metrics {
            self.device_metrics[device_name] = {
                "reads": PerformanceCounter(device_name + "_reads", "event_count"),
                "writes": PerformanceCounter(device_name + "_writes", "event_count"),
                "total_bytes": PerformanceCounter(device_name + "_bytes", "gauge")
            };
        }

        if op_type == "read" {
            self.device_metrics[device_name]["reads"].increment();
        } else if op_type == "write" {
            self.device_metrics[device_name]["writes"].increment();
        }
        
        self.device_metrics[device_name]["total_bytes"].add(size);
    }

    fn get_performance_report(self) {
        let report = {
            "timestamp": hardware.rdtsc(),
            "hypervisor_metrics": self.metrics.get_all_metrics(),
            "disk_io": {
                "reads": self.disk_io_metrics["read_ops"].get_stats(),
                "writes": self.disk_io_metrics["write_ops"].get_stats(),
                "avg_read_latency": self.disk_io_metrics["avg_read_latency"],
                "avg_write_latency": self.disk_io_metrics["avg_write_latency"]
            },
            "network": {
                "rx_packets": self.network_metrics["rx_packets"].get_stats(),
                "tx_packets": self.network_metrics["tx_packets"].get_stats(),
                "rx_bytes": self.network_metrics["rx_bytes"].get_stats(),
                "tx_bytes": self.network_metrics["tx_bytes"].get_stats()
            },
            "memory": self.memory_metrics,
            "device_io": {}
        };

        for device_name in self.device_metrics {
            report["device_io"][device_name] = {
                "reads": self.device_metrics[device_name]["reads"].get_stats(),
                "writes": self.device_metrics[device_name]["writes"].get_stats()
            };
        }

        return report;
    }

    fn get_top_vm_exits(self, limit) {
        # Return most common exit types
        let top = [];
        let metrics = self.metrics.get_all_metrics();
        
        let sorted = [];
        for metric_name in metrics {
            if "exit" in metric_name {
                push(sorted, metrics[metric_name]);
            }
        }

        # Sort by value (descending) - simplified
        return sorted;
    }

    fn identify_bottleneck(self) {
        # Identify performance bottlenecks
        let report = self.get_performance_report();
        
        let bottlenecks = [];
        
        # Check for high exit rate
        if report["hypervisor_metrics"]["total_vmexits"]["value"] > 100000 {
            push(bottlenecks, {
                "type": "high_exit_rate",
                "severity": "high",
                "suggestion": "Consider using passthrough or batching"
            });
        }

        # Check for high I/O latency
        if report["disk_io"]["avg_read_latency"] > 1000 {
            push(bottlenecks, {
                "type": "high_disk_read_latency",
                "severity": "medium",
                "suggestion": "Enable device caching or SSD pool"
            });
        }

        return bottlenecks;
    }

    fn reset_metrics(self) {
        self.metrics.reset_all();
    }
}
