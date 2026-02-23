# ===========================================
# Nyx Standard Library - DMA (Direct Memory Access)
# ===========================================
# Hardware DMA abstractions for high-performance I/O
# Zero-copy transfers between memory and peripherals

import systems
import atomics

# ===========================================
# DMA Transfer Modes
# ===========================================

class DMAMode {
    # Memory-to-memory transfer
    let MEM_TO_MEM = 0;
    
    # Memory-to-peripheral transfer
    let MEM_TO_PERIPH = 1;
    
    # Peripheral-to-memory transfer
    let PERIPH_TO_MEM = 2;
    
    # Peripheral-to-peripheral transfer
    let PERIPH_TO_PERIPH = 3;
}

class DMADirection {
    let PERIPHERAL_TO_MEMORY = 0;
    let MEMORY_TO_PERIPHERAL = 1;
    let MEMORY_TO_MEMORY = 2;
}

class DMAPriority {
    let LOW = 0;
    let MEDIUM = 1;
    let HIGH = 2;
    let VERY_HIGH = 3;
}

class DMAWidth {
    let BYTE = 1;       # 8-bit transfers
    let HALFWORD = 2;   # 16-bit transfers
    let WORD = 4;       # 32-bit transfers
    let DOUBLEWORD = 8; # 64-bit transfers
}

# ===========================================
# DMA Channel Configuration
# ===========================================

class DMAChannel {
    fn init(self, channel_id) {
        self.channel_id = channel_id;
        self.enabled = false;
        self.busy = atomics.AtomicBool(false);
        
        # Configuration
        self.source = null;
        self.destination = null;
        self.length = 0;
        self.mode = DMAMode.MEM_TO_MEM;
        self.priority = DMAPriority.MEDIUM;
        self.width = DMAWidth.WORD;
        
        # Increment modes
        self.source_increment = true;
        self.dest_increment = true;
        
        # Circular mode
        self.circular = false;
        
        # Callbacks
        self.on_complete = null;
        self.on_error = null;
        self.on_half_complete = null;
        
        # Statistics
        self.transfers_completed = 0;
        self.bytes_transferred = 0;
        self.errors = 0;
    }
    
    fn configure(self, config) {
        if self.enabled {
            throw "DMAChannel.configure: cannot configure while enabled";
        }
        
        self.source = config["source"];
        self.destination = config["destination"];
        self.length = config["length"];
        
        if "mode" in config {
            self.mode = config["mode"];
        }
        if "priority" in config {
            self.priority = config["priority"];
        }
        if "width" in config {
            self.width = config["width"];
        }
        if "source_increment" in config {
            self.source_increment = config["source_increment"];
        }
        if "dest_increment" in config {
            self.dest_increment = config["dest_increment"];
        }
        if "circular" in config {
            self.circular = config["circular"];
        }
        if "on_complete" in config {
            self.on_complete = config["on_complete"];
        }
        if "on_error" in config {
            self.on_error = config["on_error"];
        }
        if "on_half_complete" in config {
            self.on_half_complete = config["on_half_complete"];
        }
        
        return self;
    }
    
    fn enable(self) {
        if self.source == null || self.destination == null || self.length == 0 {
            throw "DMAChannel.enable: invalid configuration";
        }
        
        self.enabled = true;
        self.busy.store(false, atomics.MemoryOrder.RELEASE);
        
        # Register with hardware DMA controller
        _dma_hw_enable(self.channel_id, {
            "source": self.source,
            "destination": self.destination,
            "length": self.length,
            "mode": self.mode,
            "priority": self.priority,
            "width": self.width,
            "source_increment": self.source_increment,
            "dest_increment": self.dest_increment,
            "circular": self.circular
        });
        
        return self;
    }
    
    fn disable(self) {
        if !self.enabled {
            return;
        }
        
        # Wait for current transfer to complete
        while self.is_busy() {
            _yield();
        }
        
        _dma_hw_disable(self.channel_id);
        self.enabled = false;
        
        return self;
    }
    
    fn start(self) {
        if !self.enabled {
            throw "DMAChannel.start: channel not enabled";
        }
        
        if self.is_busy() {
            throw "DMAChannel.start: transfer already in progress";
        }
        
        self.busy.store(true, atomics.MemoryOrder.RELEASE);
        _dma_hw_start(self.channel_id);
        
        return self;
    }
    
    fn abort(self) {
        _dma_hw_abort(self.channel_id);
        self.busy.store(false, atomics.MemoryOrder.RELEASE);
        
        return self;
    }
    
    fn is_busy(self) {
        return self.busy.load(atomics.MemoryOrder.ACQUIRE);
    }
    
    fn is_enabled(self) {
        return self.enabled;
    }
    
    fn get_remaining(self) {
        return _dma_hw_get_remaining(self.channel_id);
    }
    
    fn get_progress(self) {
        let remaining = self.get_remaining();
        return 1.0 - (remaining / self.length);
    }
    
    fn handle_complete_interrupt(self) {
        self.busy.store(false, atomics.MemoryOrder.RELEASE);
        self.transfers_completed = self.transfers_completed + 1;
        self.bytes_transferred = self.bytes_transferred + self.length * self.width;
        
        if self.on_complete != null {
            self.on_complete(self);
        }
        
        # Restart if circular mode
        if self.circular {
            self.start();
        }
    }
    
    fn handle_error_interrupt(self, error_code) {
        self.busy.store(false, atomics.MemoryOrder.RELEASE);
        self.errors = self.errors + 1;
        
        if self.on_error != null {
            self.on_error(self, error_code);
        }
    }
    
    fn handle_half_complete_interrupt(self) {
        if self.on_half_complete != null {
            self.on_half_complete(self);
        }
    }
    
    fn get_stats(self) {
        return {
            "transfers_completed": self.transfers_completed,
            "bytes_transferred": self.bytes_transferred,
            "errors": self.errors
        };
    }
    
    fn destroy(self) {
        self.disable();
        self.busy.destroy();
    }
}

# ===========================================
# DMA Controller
# ===========================================

class DMAController {
    fn init(self, num_channels = 8) {
        self.channels = [];
        
        for i in range(0, num_channels) {
            push(self.channels, DMAChannel(i));
        }
        
        self.stats = {
            "total_transfers": atomics.AtomicI64(0),
            "total_bytes": atomics.AtomicI64(0),
            "active_transfers": atomics.AtomicI32(0)
        };
    }
    
    fn get_channel(self, channel_id) {
        if channel_id < 0 || channel_id >= len(self.channels) {
            throw "DMAController.get_channel: invalid channel ID";
        }
        return self.channels[channel_id];
    }
    
    fn allocate_channel(self, priority = DMAPriority.MEDIUM) {
        # Find first available channel
        for i in range(0, len(self.channels)) {
            let channel = self.channels[i];
            if !channel.is_enabled() && !channel.is_busy() {
                return channel;
            }
        }
        
        throw "DMAController.allocate_channel: no channels available";
    }
    
    fn transfer(self, source, destination, length, config = {}) {
        # High-level transfer function
        let channel = self.allocate_channel();
        
        config["source"] = source;
        config["destination"] = destination;
        config["length"] = length;
        
        channel.configure(config);
        channel.enable();
        channel.start();
        
        return channel;
    }
    
    fn wait_for_transfer(self, channel) {
        while channel.is_busy() {
            _yield();
        }
    }
    
    fn wait_for_all(self) {
        for channel in self.channels {
            self.wait_for_transfer(channel);
        }
    }
    
    fn get_active_count(self) {
        let count = 0;
        for channel in self.channels {
            if channel.is_busy() {
                count = count + 1;
            }
        }
        return count;
    }
    
    fn get_global_stats(self) {
        return {
            "total_transfers": self.stats["total_transfers"].load(atomics.MemoryOrder.RELAXED),
            "total_bytes": self.stats["total_bytes"].load(atomics.MemoryOrder.RELAXED),
            "active_transfers": self.get_active_count()
        };
    }
    
    fn destroy(self) {
        for channel in self.channels {
            channel.destroy();
        }
        self.channels = [];
        
        self.stats["total_transfers"].destroy();
        self.stats["total_bytes"].destroy();
        self.stats["active_transfers"].destroy();
    }
}

# ===========================================
# Scatter-Gather DMA
# ===========================================

class ScatterGatherDescriptor {
    fn init(self, source, destination, length) {
        self.source = source;
        self.destination = destination;
        self.length = length;
        self.next = null;
    }
}

class ScatterGatherDMA {
    fn init(self, channel) {
        self.channel = channel;
        self.descriptors = [];
        self.current_index = 0;
    }
    
    fn add_descriptor(self, source, destination, length) {
        push(self.descriptors, ScatterGatherDescriptor(source, destination, length));
        return self;
    }
    
    fn link_descriptors(self) {
        # Link descriptors in hardware format
        for i in range(0, len(self.descriptors) - 1) {
            self.descriptors[i].next = self.descriptors[i + 1];
        }
    }
    
    fn start(self) {
        if len(self.descriptors) == 0 {
            throw "ScatterGatherDMA.start: no descriptors";
        }
        
        self.link_descriptors();
        
        # Configure channel with first descriptor
        let desc = self.descriptors[0];
        self.channel.configure({
            "source": desc.source,
            "destination": desc.destination,
            "length": desc.length,
            "on_complete": fn(ch) {
                self.handle_descriptor_complete(ch);
            }
        });
        
        self.channel.enable();
        self.channel.start();
        self.current_index = 0;
    }
    
    fn handle_descriptor_complete(self, channel) {
        self.current_index = self.current_index + 1;
        
        if self.current_index < len(self.descriptors) {
            # Start next descriptor
            let desc = self.descriptors[self.current_index];
            channel.configure({
                "source": desc.source,
                "destination": desc.destination,
                "length": desc.length
            });
            channel.start();
        } else {
            # All descriptors complete
            channel.disable();
        }
    }
    
    fn is_complete(self) {
        return self.current_index >= len(self.descriptors);
    }
}

# ===========================================
# Zero-Copy Buffer Management
# ===========================================

class DMABuffer {
    fn init(self, size, alignment = 64) {
        # Allocate cache-aligned buffer for DMA
        self.size = size;
        self.raw_ptr = systems.malloc(size + alignment);
        
        if self.raw_ptr == null {
            throw "DMABuffer.init: allocation failed";
        }
        
        # Align pointer
        let addr = systems.ptr_to_int(self.raw_ptr);
        let aligned_addr = ((addr + alignment - 1) / alignment) * alignment;
        self.ptr = systems.int_to_ptr(aligned_addr);
        
        self.accessible = atomics.AtomicBool(true);
    }
    
    fn get_ptr(self) {
        if !self.accessible.load(atomics.MemoryOrder.ACQUIRE) {
            throw "DMABuffer.get_ptr: buffer locked by DMA";
        }
        return self.ptr;
    }
    
    fn lock(self) {
        # Lock buffer for DMA access (CPU should not touch)
        self.accessible.store(false, atomics.MemoryOrder.RELEASE);
        
        # Flush CPU cache to ensure coherency
        _cache_flush(self.ptr, self.size);
    }
    
    fn unlock(self) {
        # Unlock buffer after DMA completes
        # Invalidate CPU cache to see DMA changes
        _cache_invalidate(self.ptr, self.size);
        
        self.accessible.store(true, atomics.MemoryOrder.RELEASE);
    }
    
    fn is_locked(self) {
        return !self.accessible.load(atomics.MemoryOrder.ACQUIRE);
    }
    
    fn destroy(self) {
        if self.raw_ptr != null {
            systems.free(self.raw_ptr);
            self.raw_ptr = null;
            self.ptr = null;
        }
        self.accessible.destroy();
    }
}

class DMABufferPool {
    fn init(self, buffer_size, buffer_count, alignment = 64) {
        self.buffer_size = buffer_size;
        self.buffers = [];
        self.free_list = [];
        
        for i in range(0, buffer_count) {
            let buffer = DMABuffer(buffer_size, alignment);
            push(self.buffers, buffer);
            push(self.free_list, buffer);
        }
        
        self.lock = atomics.Spinlock();
    }
    
    fn acquire(self) {
        self.lock.lock();
        
        if len(self.free_list) == 0 {
            self.lock.unlock();
            throw "DMABufferPool.acquire: no buffers available";
        }
        
        let buffer = pop(self.free_list);
        self.lock.unlock();
        
        return buffer;
    }
    
    fn release(self, buffer) {
        self.lock.lock();
        push(self.free_list, buffer);
        self.lock.unlock();
    }
    
    fn available_count(self) {
        return len(self.free_list);
    }
    
    fn destroy(self) {
        for buffer in self.buffers {
            buffer.destroy();
        }
        self.buffers = [];
        self.free_list = [];
        self.lock.destroy();
    }
}

# ===========================================
# Hardware Abstraction Stubs
# ===========================================

fn _dma_hw_enable(channel_id, config) {
    # Configure hardware DMA registers
    # Map to platform-specific DMA controller
}

fn _dma_hw_disable(channel_id) {
    # Disable DMA channel
}

fn _dma_hw_start(channel_id) {
    # Trigger DMA transfer
}

fn _dma_hw_abort(channel_id) {
    # Abort ongoing transfer
}

fn _dma_hw_get_remaining(channel_id) {
    # Read remaining transfer count from hardware
    return 0;
}

fn _cache_flush(ptr, size) {
    # Flush CPU cache to memory
    # x86: CLFLUSH
    # ARM: DC CVAU
}

fn _cache_invalidate(ptr, size) {
    # Invalidate CPU cache lines
    # x86: CLFLUSH + memory barrier
    # ARM: DC IVAU
}

fn _yield() {
    # Platform-specific yield
}

# ===========================================
# Global DMA Controller Instance
# ===========================================

let GLOBAL_DMA = DMAController(8);

fn dma_transfer(source, destination, length, config = {}) {
    return GLOBAL_DMA.transfer(source, destination, length, config);
}

fn dma_wait_all() {
    return GLOBAL_DMA.wait_for_all();
}

fn dma_allocate_channel(priority = DMAPriority.MEDIUM) {
    return GLOBAL_DMA.allocate_channel(priority);
}

fn dma_get_stats() {
    return GLOBAL_DMA.get_global_stats();
}

# ===========================================
# Convenience Functions
# ===========================================

fn memcpy_dma(dest, src, size) {
    # DMA-accelerated memcpy
    let channel = dma_transfer(src, dest, size, {
        "mode": DMAMode.MEM_TO_MEM,
        "width": DMAWidth.WORD,
        "priority": DMAPriority.HIGH
    });
    
    GLOBAL_DMA.wait_for_transfer(channel);
    channel.disable();
}

fn memset_dma(dest, value, size) {
    # DMA-accelerated memset using memory-to-memory with fixed source
    let value_buffer = systems.malloc(4);
    systems.poke_i32(value_buffer, value);
    
    let channel = dma_transfer(value_buffer, dest, size / 4, {
        "mode": DMAMode.MEM_TO_MEM,
        "width": DMAWidth.WORD,
        "source_increment": false,
        "dest_increment": true,
        "priority": DMAPriority.HIGH
    });
    
    GLOBAL_DMA.wait_for_transfer(channel);
    channel.disable();
    systems.free(value_buffer);
}

# ===========================================
# DMA Performance Counters
# ===========================================

class DMAPerformanceCounters {
    fn init(self) {
        self.total_bytes = atomics.AtomicI64(0);
        self.total_transfers = atomics.AtomicI64(0);
        self.errors = atomics.AtomicI32(0);
        self.start_time = time();
    }
    
    fn record_transfer(self, bytes) {
        self.total_bytes.fetch_add(bytes, atomics.MemoryOrder.RELAXED);
        self.total_transfers.fetch_add(1, atomics.MemoryOrder.RELAXED);
    }
    
    fn record_error(self) {
        self.errors.fetch_add(1, atomics.MemoryOrder.RELAXED);
    }
    
    fn get_throughput(self) {
        let elapsed = time() - self.start_time;
        let bytes = self.total_bytes.load(atomics.MemoryOrder.RELAXED);
        return bytes / elapsed;  # bytes per second
    }
    
    fn report(self) {
        return {
            "total_bytes": self.total_bytes.load(atomics.MemoryOrder.RELAXED),
            "total_transfers": self.total_transfers.load(atomics.MemoryOrder.RELAXED),
            "errors": self.errors.load(atomics.MemoryOrder.RELAXED),
            "throughput_bps": self.get_throughput()
        };
    }
    
    fn destroy(self) {
        self.total_bytes.destroy();
        self.total_transfers.destroy();
        self.errors.destroy();
    }
}
