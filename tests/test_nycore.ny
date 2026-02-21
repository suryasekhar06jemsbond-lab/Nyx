# NYCORE - Nyx Foundation Engine Test
import "engines/nycore/nycore";

# Test CoreConfig
let config = nycore.CoreConfig::new();
print("Worker threads: ");
print(config.worker_threads);
print("Frame allocator MB: ");
print(config.frame_allocator_mb);
print("NUMA aware: ");
print(config.numa_aware);

# Test ArenaAllocator
let arena = nycore.memory.ArenaAllocator::new(1024);
print("Arena capacity: ");
print(arena.capacity_bytes);
let ptr = arena.alloc(256);
print("Allocated at: ");
print(ptr);

# Test PoolAllocator
let pool = nycore.memory.PoolAllocator::new(64, 4);
print("Pool block size: ");
print(pool.block_size);
print("Pool block count: ");
print(pool.block_count);
let id = pool.alloc();
print("Allocated block: ");
print(id);

# Test FrameAllocator
let frame = nycore.memory.FrameAllocator::new(1);
print("Frame arena capacity: ");
print(frame.arena.capacity_bytes);
frame.begin_frame();
print("Frame reset done");

# Test MemoryManager
let mem = nycore.memory.MemoryManager::new(16);
print("Memory manager frame: ");
print(mem.frame.arena.capacity_bytes);
mem.register_pool("particles", 128, 100);
print("Pool registered: ");
print(mem.pools.len());

print("NYCORE tests completed!");
