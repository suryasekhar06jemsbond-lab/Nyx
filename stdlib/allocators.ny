# ===========================================
# Nyx Standard Library - Memory Allocators
# ===========================================
# Production-grade memory allocator implementations
# Suitable for high-performance systems programming

import systems

# ===========================================
# Arena Allocator (Bump Allocator)
# ===========================================
# Fast O(1) allocation, batch deallocation
# Best for: temporary allocations, parsers, per-frame allocations

class Arena {
    fn init(self, capacity) {
        self.buffer = systems.malloc(capacity);
        self.capacity = capacity;
        self.offset = 0;
        self.allocations = 0;
        
        if self.buffer == null {
            throw "Arena.init: failed to allocate " + capacity + " bytes";
        }
    }
    
    fn alloc(self, size, alignment = 8) {
        # Align offset to boundary
        let aligned_offset = self.align_up(self.offset, alignment);
        
        # Check capacity
        if aligned_offset + size > self.capacity {
            throw "Arena.alloc: out of memory (" + size + " bytes requested, " + 
                  (self.capacity - aligned_offset) + " available)";
        }
        
        # Return pointer and advance
        let ptr = systems.ptr_add(self.buffer, aligned_offset);
        self.offset = aligned_offset + size;
        self.allocations = self.allocations + 1;
        
        return ptr;
    }
    
    fn alloc_zeroed(self, size, alignment = 8) {
        let ptr = self.alloc(size, alignment);
        systems.memset(ptr, 0, size);
        return ptr;
    }
    
    fn alloc_array(self, count, elem_size, alignment = 8) {
        let total_size = count * elem_size;
        return self.alloc(total_size, alignment);
    }
    
    fn reset(self) {
        # Reset offset, keep buffer
        self.offset = 0;
        self.allocations = 0;
    }
    
    fn clear(self) {
        # Zero out memory and reset
        systems.memset(self.buffer, 0, self.capacity);
        self.offset = 0;
        self.allocations = 0;
    }
    
    fn destroy(self) {
        if self.buffer != null {
            systems.free(self.buffer);
            self.buffer = null;
            self.capacity = 0;
            self.offset = 0;
        }
    }
    
    fn used(self) {
        return self.offset;
    }
    
    fn available(self) {
        return self.capacity - self.offset;
    }
    
    fn utilization(self) {
        return self.offset / self.capacity;
    }
    
    fn align_up(self, value, alignment) {
        return ((value + alignment - 1) / alignment) * alignment;
    }
}

# ===========================================
# Pool Allocator (Fixed-Size Blocks)
# ===========================================
# Fast O(1) alloc/free, no fragmentation
# Best for: object pools, particle systems, network buffers

class Pool {
    fn init(self, block_size, block_count) {
        self.block_size = self.align_up(block_size, 8);
        self.block_count = block_count;
        self.total_size = self.block_size * block_count;
        
        # Allocate memory
        self.buffer = systems.malloc(self.total_size);
        if self.buffer == null {
            throw "Pool.init: failed to allocate " + self.total_size + " bytes";
        }
        
        # Initialize free list
        self.free_list = [];
        for i in range(0, block_count) {
            let block_ptr = systems.ptr_add(self.buffer, i * self.block_size);
            push(self.free_list, block_ptr);
        }
        
        self.allocated_count = 0;
    }
    
    fn alloc(self) {
        if len(self.free_list) == 0 {
            throw "Pool.alloc: no blocks available";
        }
        
        let ptr = pop(self.free_list);
        self.allocated_count = self.allocated_count + 1;
        return ptr;
    }
    
    fn alloc_zeroed(self) {
        let ptr = self.alloc();
        systems.memset(ptr, 0, self.block_size);
        return ptr;
    }
    
    fn free(self, ptr) {
        if ptr == null {
            return;
        }
        
        # Verify pointer is within pool bounds
        let offset = systems.ptr_diff(ptr, self.buffer);
        if offset < 0 || offset >= self.total_size {
            throw "Pool.free: pointer not from this pool";
        }
        
        if offset % self.block_size != 0 {
            throw "Pool.free: misaligned pointer";
        }
        
        # Add back to free list
        push(self.free_list, ptr);
        self.allocated_count = self.allocated_count - 1;
    }
    
    fn destroy(self) {
        if self.buffer != null {
            systems.free(self.buffer);
            self.buffer = null;
            self.free_list = [];
        }
    }
    
    fn available_blocks(self) {
        return len(self.free_list);
    }
    
    fn allocated_blocks(self) {
        return self.allocated_count;
    }
    
    fn utilization(self) {
        return self.allocated_count / self.block_count;
    }
    
    fn align_up(self, value, alignment) {
        return ((value + alignment - 1) / alignment) * alignment;
    }
}

# ===========================================
# Slab Allocator (Multiple Fixed Sizes)
# ===========================================
# Multiple pools for common sizes
# Best for: general allocator, kernel allocators, low fragmentation

class Slab {
    fn init(self) {
        # Common allocation sizes: 16, 32, 64, 128, 256, 512, 1024, 2048, 4096
        self.sizes = [16, 32, 64, 128, 256, 512, 1024, 2048, 4096];
        self.pools = [];
        
        # Create pool for each size
        for size in self.sizes {
            let blocks_per_page = max(1, 4096 / size);
            let pool = Pool(size, blocks_per_page);
            push(self.pools, pool);
        }
        
        self.large_allocations = {};
        self.stats = {
            "small_allocs": 0,
            "large_allocs": 0,
            "total_allocated": 0
        };
    }
    
    fn alloc(self, size) {
        # Find smallest pool that fits
        for i in range(0, len(self.sizes)) {
            if size <= self.sizes[i] {
                let ptr = self.pools[i].alloc();
                self.stats["small_allocs"] = self.stats["small_allocs"] + 1;
                self.stats["total_allocated"] = self.stats["total_allocated"] + self.sizes[i];
                return ptr;
            }
        }
        
        # Too large for pools - use direct allocation
        let ptr = systems.malloc(size);
        if ptr == null {
            throw "Slab.alloc: failed to allocate " + size + " bytes";
        }
        
        self.large_allocations[ptr] = size;
        self.stats["large_allocs"] = self.stats["large_allocs"] + 1;
        self.stats["total_allocated"] = self.stats["total_allocated"] + size;
        return ptr;
    }
    
    fn alloc_zeroed(self, size) {
        let ptr = self.alloc(size);
        
        # Determine actual allocation size
        let actual_size = size;
        for i in range(0, len(self.sizes)) {
            if size <= self.sizes[i] {
                actual_size = self.sizes[i];
                break;
            }
        }
        
        systems.memset(ptr, 0, actual_size);
        return ptr;
    }
    
    fn free(self, ptr, size) {
        if ptr == null {
            return;
        }
        
        # Check if large allocation
        if ptr in self.large_allocations {
            let alloc_size = self.large_allocations[ptr];
            systems.free(ptr);
            delete(self.large_allocations, ptr);
            self.stats["large_allocs"] = self.stats["large_allocs"] - 1;
            self.stats["total_allocated"] = self.stats["total_allocated"] - alloc_size;
            return;
        }
        
        # Find pool and free
        for i in range(0, len(self.sizes)) {
            if size <= self.sizes[i] {
                self.pools[i].free(ptr);
                self.stats["small_allocs"] = self.stats["small_allocs"] - 1;
                self.stats["total_allocated"] = self.stats["total_allocated"] - self.sizes[i];
                return;
            }
        }
        
        throw "Slab.free: could not find pool for size " + size;
    }
    
    fn destroy(self) {
        for pool in self.pools {
            pool.destroy();
        }
        self.pools = [];
        
        # Free large allocations
        for ptr in keys(self.large_allocations) {
            systems.free(ptr);
        }
        self.large_allocations = {};
    }
    
    fn get_stats(self) {
        return self.stats;
    }
}

# ===========================================
# Stack Allocator (LIFO)
# ===========================================
# Fast O(1) alloc/free in LIFO order
# Best for: function call frames, recursive algorithms

class Stack {
    fn init(self, capacity) {
        self.buffer = systems.malloc(capacity);
        self.capacity = capacity;
        self.offset = 0;
        self.markers = [];
        
        if self.buffer == null {
            throw "Stack.init: failed to allocate " + capacity + " bytes";
        }
    }
    
    fn alloc(self, size, alignment = 8) {
        # Align offset
        let aligned_offset = self.align_up(self.offset, alignment);
        
        if aligned_offset + size > self.capacity {
            throw "Stack.alloc: stack overflow";
        }
        
        let ptr = systems.ptr_add(self.buffer, aligned_offset);
        self.offset = aligned_offset + size;
        return ptr;
    }
    
    fn free(self, ptr) {
        # Calculate new offset
        let offset = systems.ptr_diff(ptr, self.buffer);
        if offset < 0 || offset > self.offset {
            throw "Stack.free: invalid pointer";
        }
        
        self.offset = offset;
    }
    
    fn push_marker(self) {
        push(self.markers, self.offset);
    }
    
    fn pop_marker(self) {
        if len(self.markers) == 0 {
            throw "Stack.pop_marker: no markers";
        }
        
        self.offset = pop(self.markers);
    }
    
    fn clear(self) {
        self.offset = 0;
        self.markers = [];
    }
    
    fn destroy(self) {
        if self.buffer != null {
            systems.free(self.buffer);
            self.buffer = null;
        }
    }
    
    fn align_up(self, value, alignment) {
        return ((value + alignment - 1) / alignment) * alignment;
    }
}

# ===========================================
# Free List Allocator
# ===========================================
# Variable-size allocations with free list
# Best for: general purpose allocator, variable sizes

class FreeList {
    fn init(self, capacity) {
        self.buffer = systems.malloc(capacity);
        self.capacity = capacity;
        
        if self.buffer == null {
            throw "FreeList.init: failed to allocate " + capacity + " bytes";
        }
        
        # Initialize with one large free block
        self.free_blocks = [{
            "ptr": self.buffer,
            "size": capacity
        }];
        
        self.allocated_blocks = {};
    }
    
    fn alloc(self, size, alignment = 8) {
        # Add header size
        let header_size = 16;
        let total_size = size + header_size;
        total_size = self.align_up(total_size, alignment);
        
        # Find first fit
        for i in range(0, len(self.free_blocks)) {
            let block = self.free_blocks[i];
            
            if block["size"] >= total_size {
                # Found a fit
                let ptr = block["ptr"];
                
                # Split block if remainder is large enough
                if block["size"] - total_size >= 32 {
                    let remainder_ptr = systems.ptr_add(ptr, total_size);
                    let remainder_size = block["size"] - total_size;
                    
                    # Update free block
                    block["ptr"] = remainder_ptr;
                    block["size"] = remainder_size;
                } else {
                    # Use entire block
                    total_size = block["size"];
                    remove_at(self.free_blocks, i);
                }
                
                # Track allocation
                self.allocated_blocks[ptr] = total_size;
                
                # Return pointer after header
                return systems.ptr_add(ptr, header_size);
            }
        }
        
        throw "FreeList.alloc: out of memory";
    }
    
    fn free(self, ptr) {
        if ptr == null {
            return;
        }
        
        # Get actual allocation pointer (before header)
        let header_size = 16;
        let actual_ptr = systems.ptr_add(ptr, -header_size);
        
        # Find allocation size
        if actual_ptr not in self.allocated_blocks {
            throw "FreeList.free: pointer not allocated";
        }
        
        let size = self.allocated_blocks[actual_ptr];
        delete(self.allocated_blocks, actual_ptr);
        
        # Add to free list (coalescing could be added here)
        push(self.free_blocks, {
            "ptr": actual_ptr,
            "size": size
        });
        
        # Sort free blocks by address for coalescing
        self.coalesce();
    }
    
    fn coalesce(self) {
        # Sort free blocks by address
        self.free_blocks = sort(self.free_blocks, fn(a, b) {
            return systems.ptr_diff(a["ptr"], b["ptr"]) < 0;
        });
        
        # Merge adjacent blocks
        let i = 0;
        while i < len(self.free_blocks) - 1 {
            let current = self.free_blocks[i];
            let next = self.free_blocks[i + 1];
            
            let current_end = systems.ptr_add(current["ptr"], current["size"]);
            
            if current_end == next["ptr"] {
                # Merge blocks
                current["size"] = current["size"] + next["size"];
                remove_at(self.free_blocks, i + 1);
            } else {
                i = i + 1;
            }
        }
    }
    
    fn destroy(self) {
        if self.buffer != null {
            systems.free(self.buffer);
            self.buffer = null;
            self.free_blocks = [];
            self.allocated_blocks = {};
        }
    }
    
    fn align_up(self, value, alignment) {
        return ((value + alignment - 1) / alignment) * alignment;
    }
}

# ===========================================
# Cache-Aligned Allocator
# ===========================================
# Allocations aligned to cache line boundaries
# Best for: concurrent data structures, cache-friendly code

let CACHE_LINE_SIZE = 64;

class CacheAligned {
    fn init(self) {
        self.allocations = {};
    }
    
    fn alloc(self, size) {
        # Allocate extra for alignment
        let total_size = size + CACHE_LINE_SIZE;
        let raw_ptr = systems.malloc(total_size);
        
        if raw_ptr == null {
            throw "CacheAligned.alloc: allocation failed";
        }
        
        # Align to cache line
        let addr = systems.ptr_to_int(raw_ptr);
        let aligned_addr = self.align_up(addr, CACHE_LINE_SIZE);
        let aligned_ptr = systems.int_to_ptr(aligned_addr);
        
        # Store raw pointer for deallocation
        self.allocations[aligned_ptr] = raw_ptr;
        
        return aligned_ptr;
    }
    
    fn free(self, ptr) {
        if ptr == null {
            return;
        }
        
        if ptr not in self.allocations {
            throw "CacheAligned.free: pointer not allocated";
        }
        
        let raw_ptr = self.allocations[ptr];
        systems.free(raw_ptr);
        delete(self.allocations, ptr);
    }
    
    fn destroy(self) {
        for ptr in keys(self.allocations) {
            systems.free(self.allocations[ptr]);
        }
        self.allocations = {};
    }
    
    fn align_up(self, value, alignment) {
        return ((value + alignment - 1) / alignment) * alignment;
    }
}

# ===========================================
# Global Allocator Instance (Thread-Local)
# ===========================================

let GLOBAL_ALLOCATOR = null;

fn set_global_allocator(allocator) {
    GLOBAL_ALLOCATOR = allocator;
}

fn get_global_allocator() {
    if GLOBAL_ALLOCATOR == null {
        throw "No global allocator set";
    }
    return GLOBAL_ALLOCATOR;
}

# Convenience functions using global allocator
fn alloc(size) {
    return get_global_allocator().alloc(size);
}

fn alloc_zeroed(size) {
    return get_global_allocator().alloc_zeroed(size);
}

fn free(ptr, size = 0) {
    return get_global_allocator().free(ptr, size);
}

# ===========================================
# Allocator Statistics
# ===========================================

class AllocatorStats {
    fn init(self) {
        self.allocations = 0;
        self.deallocations = 0;
        self.bytes_allocated = 0;
        self.bytes_freed = 0;
        self.peak_usage = 0;
        self.current_usage = 0;
    }
    
    fn track_alloc(self, size) {
        self.allocations = self.allocations + 1;
        self.bytes_allocated = self.bytes_allocated + size;
        self.current_usage = self.current_usage + size;
        
        if self.current_usage > self.peak_usage {
            self.peak_usage = self.current_usage;
        }
    }
    
    fn track_free(self, size) {
        self.deallocations = self.deallocations + 1;
        self.bytes_freed = self.bytes_freed + size;
        self.current_usage = self.current_usage - size;
    }
    
    fn report(self) {
        return {
            "allocations": self.allocations,
            "deallocations": self.deallocations,
            "bytes_allocated": self.bytes_allocated,
            "bytes_freed": self.bytes_freed,
            "peak_usage": self.peak_usage,
            "current_usage": self.current_usage,
            "leak_count": self.allocations - self.deallocations
        };
    }
}
