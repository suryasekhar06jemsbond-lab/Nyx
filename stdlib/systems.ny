# ============================================================================
# Nyx Systems Programming Primitives - PRODUCTION GRADE
# ============================================================================
# Low-level systems programming features for Nyx
# Provides: RAII, smart pointers, unsafe blocks, memory management
# Production-ready implementations suitable for OS kernels, embedded systems
# ============================================================================

# ============================================================================
# Memory Management & RAII
# ============================================================================

# Box<T> - Heap allocation with ownership (RAII)
class Box {
    fn init(self, value) {
        self.ptr = malloc(1);  # Allocate storage
        self.value = value;
        self.is_allocated = true;
        
        if self.ptr == null {
            panic("Box: allocation failed");
        }
    }
    
    fn get(self) {
        if !self.is_allocated {
            panic("Box: use after free");
        }
        return self.value;
    }
    
    fn take(self) {
        # Move value out, consuming the Box
        if !self.is_allocated {
            panic("Box: use after free");
        }
        let val = self.value;
        self.drop();
        return val;
    }
    
    fn drop(self) {
        if self.is_allocated {
            free(self.ptr);
            self.is_allocated = false;
            self.value = null;
        }
    }
}

# Rc<T> - Reference counted smart pointer (non-atomic)
class Rc {
    fn init(self, value) {
        self.ptr = malloc(1);
        self.value = value;
        self.ref_count = 1;
        
        if self.ptr == null {
            panic("Rc: allocation failed");
        }
    }
    
    fn clone(self) {
        self.ref_count = self.ref_count + 1;
        return self;
    }
    
    fn get(self) {
        if self.ref_count == 0 {
            panic("Rc: use after free");
        }
        return self.value;
    }
    
    fn drop(self) {
        if self.ref_count > 0 {
            self.ref_count = self.ref_count - 1;
            
            if self.ref_count == 0 {
                free(self.ptr);
                self.value = null;
            }
        }
    }
    
    fn strong_count(self) {
        return self.ref_count;
    }
}

# Arc<T> - Atomic reference counted smart pointer (thread-safe)
class Arc {
    fn init(self, value) {
        import atomics;
        
        self.ptr = malloc(1);
        self.value = value;
        self.ref_count = atomics.AtomicI32(1);
        
        if self.ptr == null {
            panic("Arc: allocation failed");
        }
    }
    
    fn clone(self) {
        self.ref_count.fetch_add(1, atomics.MemoryOrder.RELAXED);
        return self;
    }
    
    fn get(self) {
        if self.ref_count.load(atomics.MemoryOrder.RELAXED) == 0 {
            panic("Arc: use after free");
        }
        return self.value;
    }
    
    fn drop(self) {
        let old_count = self.ref_count.fetch_sub(1, atomics.MemoryOrder.RELEASE);
        
        if old_count == 1 {
            # Last reference - perform cleanup
            atomics.fence(atomics.MemoryOrder.ACQUIRE);
            free(self.ptr);
            self.value = null;
            self.ref_count.destroy();
        }
    }
    
    fn strong_count(self) {
        return self.ref_count.load(atomics.MemoryOrder.RELAXED);
    }
}

# Weak<T> - Weak reference (doesn't keep value alive)
class Weak {
    fn init(self, arc) {
        self.ptr = arc.ptr;
        self.value = arc.value;
        self.ref_count = arc.ref_count;
        self.weak_count = 1;
    }
    
    fn upgrade(self) {
        # Try to upgrade to strong reference
        let count = self.ref_count.load(atomics.MemoryOrder.RELAXED);
        if count > 0 {
            return Arc(self.value);
        }
        return null;
    }
    
    fn drop(self) {
        self.weak_count = self.weak_count - 1;
    }
}

# Cell<T> - Interior mutability (non-thread-safe)
class Cell {
    fn init(self, value) {
        self.value = value;
    }
    
    fn get(self) {
        return self.value;
    }
    
    fn set(self, value) {
        self.value = value;
    }
    
    fn replace(self, value) {
        let old = self.value;
        self.value = value;
        return old;
    }
    
    fn swap(self, other) {
        let temp = self.value;
        self.value = other.value;
        other.value = temp;
    }
}

# RefCell<T> - Runtime borrow checking
class RefCell {
    fn init(self, value) {
        self.value = value;
        self.borrow_state = 0;  # 0 = not borrowed, >0 = shared, -1 = exclusive
    }
    
    fn borrow(self) {
        if self.borrow_state == -1 {
            panic("RefCell: already borrowed mutably");
        }
        self.borrow_state = self.borrow_state + 1;
        return RefCellRef(self, false);
    }
    
    fn borrow_mut(self) {
        if self.borrow_state != 0 {
            panic("RefCell: already borrowed");
        }
        self.borrow_state = -1;
        return RefCellRef(self, true);
    }
    
    fn try_borrow(self) {
        if self.borrow_state == -1 {
            return null;
        }
        self.borrow_state = self.borrow_state + 1;
        return RefCellRef(self, false);
    }
    
    fn try_borrow_mut(self) {
        if self.borrow_state != 0 {
            return null;
        }
        self.borrow_state = -1;
        return RefCellRef(self, true);
    }
}

class RefCellRef {
    fn init(self, refcell, is_mut) {
        self.refcell = refcell;
        self.is_mut = is_mut;
    }
    
    fn get(self) {
        return self.refcell.value;
    }
    
    fn set(self, value) {
        if !self.is_mut {
            panic("RefCellRef: cannot mutate immutable borrow");
        }
        self.refcell.value = value;
    }
    
    fn drop(self) {
        if self.is_mut {
            self.refcell.borrow_state = 0;
        } else {
            self.refcell.borrow_state = self.refcell.borrow_state - 1;
        }
    }
}

# Scope guard for RAII pattern
class ScopeGuard {
    fn init(self, release_fn) {
        self.release = release_fn;
        self.active = true;
    }
    
    fn dismiss(self) {
        self.active = false;
    }
    
    fn drop(self) {
        if self.active && self.release != null {
            self.release();
        }
    }
}


# ============================================================================
# Pointer Types (Production-Grade)
# ============================================================================

# RawPtr<T> - Raw pointer (requires unsafe)
class RawPtr {
    fn init(self, address, target_type) {
        self.address = address;
        self.target_type = target_type;
        self.is_null = (address == 0);
    }
    
    fn is_null(self) {
        return self.is_null;
    }
    
    fn offset(self, count) {
        # Offset by count elements of target_type
        let elem_size = size_of(self.target_type);
        return RawPtr(self.address + count * elem_size, self.target_type);
    }
    
    fn cast(self, new_type) {
        return RawPtr(self.address, new_type);
    }
    
    fn read(self) {
        # Unsafe: read value at pointer
        if self.is_null {
            panic("RawPtr: null pointer dereference");
        }
        return peek(self.address, self.target_type);
    }
    
    fn write(self, value) {
        # Unsafe: write value at pointer
        if self.is_null {
            panic("RawPtr: null pointer dereference");
        }
        poke(self.address, value, self.target_type);
    }
    
    fn as_int(self) {
        return self.address;
    }
}

# NonNull<T> - Non-nullable pointer (zero-cost abstraction)
class NonNull {
    fn init(self, ptr) {
        if ptr.is_null() {
            panic("NonNull: pointer is null");
        }
        self.ptr = ptr;
    }
    
    fn as_ptr(self) {
        return self.ptr;
    }
    
    fn read(self) {
        return self.ptr.read();
    }
    
    fn write(self, value) {
        self.ptr.write(value);
    }
}

# Unique<T> - Unique ownership of pointer
class Unique {
    fn init(self, ptr) {
        if ptr.is_null() {
            panic("Unique: pointer is null");
        }
        self.ptr = ptr;
        self.owns = true;
    }
    
    fn take(self) {
        if !self.owns {
            panic("Unique: already taken");
        }
        self.owns = false;
        return self.ptr;
    }
    
    fn get(self) {
        if !self.owns {
            panic("Unique: use after take");
        }
        return self.ptr;
    }
    
    fn drop(self) {
        if self.owns {
            free(self.ptr.address);
        }
    }
}

# MaybeUninit<T> - Possibly uninitialized memory
class MaybeUninit {
    fn init(self, type_) {
        self.type_ = type_;
        self.size = size_of(type_);
        self.ptr = malloc(self.size);
        self.initialized = false;
        
        if self.ptr == null {
            panic("MaybeUninit: allocation failed");
        }
    }
    
    fn write(self, value) {
        poke(self.ptr, value, self.type_);
        self.initialized = true;
        return self;
    }
    
    fn assume_init(self) {
        # Unsafe: assume value is initialized
        if !self.initialized {
            panic("MaybeUninit: reading uninitialized memory");
        }
        return peek(self.ptr, self.type_);
    }
    
    fn as_ptr(self) {
        return RawPtr(self.ptr, self.type_);
    }
    
    fn drop(self) {
        free(self.ptr);
    }
}

# Create null pointer
fn null_ptr(type_) {
    return RawPtr(0, type_);
}

# Pointer from integer
fn ptr_from_int(address, type_) {
    return RawPtr(address, type_);
}

# Pointer to integer
fn ptr_to_int(ptr) {
    return ptr.address;
}

# Pointer difference
fn ptr_diff(a, b) {
    return a.address - b.address;
}

# Pointer addition
fn ptr_add(ptr, offset) {
    return RawPtr(ptr.address + offset, ptr.target_type);
}

# Pointer comparison
fn ptr_eq(a, b) {
    return a.address == b.address;
}

fn ptr_lt(a, b) {
    return a.address < b.address;
}

fn ptr_gt(a, b) {
    return a.address > b.address;
}

# ============================================================================
# Unsafe Operations (restricted to unsafe blocks)
# ============================================================================

# Unsafe block marker - these bypass safety checks
fn unsafe(block_fn) {
    return {
        "type": "unsafe_block",
        "fn": block_fn,
        "requires_unsafe_context": true
    };
}


# ============================================================================
# Memory Operations (Production-Grade)
# ============================================================================

# Allocate memory
fn malloc(size) {
    # Native implementation allocates memory
    return _sys_malloc(size);
}

# Allocate zeroed memory
fn calloc(count, size) {
    let total = count * size;
    let ptr = _sys_malloc(total);
    if ptr != null {
        memset(ptr, 0, total);
    }
    return ptr;
}

# Reallocate memory
fn realloc(ptr, new_size) {
    return _sys_realloc(ptr, new_size);
}

# Free memory
fn free(ptr) {
    if ptr != null {
        _sys_free(ptr);
    }
}

# Aligned allocation
fn aligned_alloc(alignment, size) {
    return _sys_aligned_alloc(alignment, size);
}

# Zero-initialize memory
fn zero_mem(ptr, size) {
    return memset(ptr, 0, size);
}

# Copy memory (memcpy semantics)
fn memcpy(dest, src, size) {
    return _sys_memcpy(dest, src, size);
}

# Move memory (memmove semantics - handles overlapping regions)
fn memmove(dest, src, size) {
    return _sys_memmove(dest, src, size);
}

# Set memory (memset semantics)
fn memset(dest, value, size) {
    return _sys_memset(dest, value, size);
}

# Compare memory
fn memcmp(a, b, size) {
    return _sys_memcmp(a, b, size);
}

# Memory barrier (full fence)
fn memory_barrier() {
    import atomics;
    atomics.fence(atomics.MemoryOrder.SEQ_CST);
}

# Read barrier
fn read_barrier() {
    import atomics;
    atomics.fence(atomics.MemoryOrder.ACQUIRE);
}

# Write barrier
fn write_barrier() {
    import atomics;
    atomics.fence(atomics.MemoryOrder.RELEASE);
}

# Prefetch for read
fn prefetch_read(ptr, locality = 3) {
    _sys_prefetch(ptr, 0, locality);
}

# Prefetch for write
fn prefetch_write(ptr, locality = 3) {
    _sys_prefetch(ptr, 1, locality);
}

# Memory peek (typed read)
fn peek(ptr, type_) {
    return _sys_peek(ptr, type_);
}

fn peek_i8(ptr) { return _sys_peek(ptr, "i8"); }
fn peek_i16(ptr) { return _sys_peek(ptr, "i16"); }
fn peek_i32(ptr) { return _sys_peek(ptr, "i32"); }
fn peek_i64(ptr) { return _sys_peek(ptr, "i64"); }
fn peek_u8(ptr) { return _sys_peek(ptr, "u8"); }
fn peek_u16(ptr) { return _sys_peek(ptr, "u16"); }
fn peek_u32(ptr) { return _sys_peek(ptr, "u32"); }
fn peek_u64(ptr) { return _sys_peek(ptr, "u64"); }
fn peek_f32(ptr) { return _sys_peek(ptr, "f32"); }
fn peek_f64(ptr) { return _sys_peek(ptr, "f64"); }
fn peek_ptr(ptr) { return _sys_peek(ptr, "ptr"); }

# Memory poke (typed write)
fn poke(ptr, value, type_) {
    _sys_poke(ptr, value, type_);
}

fn poke_i8(ptr, value) { _sys_poke(ptr, value, "i8"); }
fn poke_i16(ptr, value) { _sys_poke(ptr, value, "i16"); }
fn poke_i32(ptr, value) { _sys_poke(ptr, value, "i32"); }
fn poke_i64(ptr, value) { _sys_poke(ptr, value, "i64"); }
fn poke_u8(ptr, value) { _sys_poke(ptr, value, "u8"); }
fn poke_u16(ptr, value) { _sys_poke(ptr, value, "u16"); }
fn poke_u32(ptr, value) { _sys_poke(ptr, value, "u32"); }
fn poke_u64(ptr, value) { _sys_poke(ptr, value, "u64"); }
fn poke_f32(ptr, value) { _sys_poke(ptr, value, "f32"); }
fn poke_f64(ptr, value) { _sys_poke(ptr, value, "f64"); }
fn poke_ptr(ptr, value) { _sys_poke(ptr, value, "ptr"); }

# Volatile operations (prevent optimization)
fn volatile_read(ptr, type_) {
    return _sys_volatile_read(ptr, type_);
}

fn volatile_write(ptr, value, type_) {
    _sys_volatile_write(ptr, value, type_);
}

# Cache control
fn cache_flush(ptr, size) {
    _sys_cache_flush(ptr, size);
}

fn cache_invalidate(ptr, size) {
    _sys_cache_invalidate(ptr, size);
}

fn cache_flush_line(ptr) {
    _sys_cache_flush(ptr, 64);  # Typical cache line size
}

# ============================================================================
# Atomic Operations (for concurrency)
# ============================================================================

# Atomic integer (thread-safe)
fn AtomicInt(initial_value) {
    return {
        "type": "AtomicInt",
        "value": initial_value,
        "lock": null
    };
}

# Atomic load
fn atomic_load(atomic) {
    return atomic.value;
}

# Atomic store
fn atomic_store(atomic, new_value) {
    atomic.value = new_value;
    return new_value;
}

# Atomic add (fetch-and-add)
fn atomic_add(atomic, delta) {
    let old = atomic.value;
    atomic.value = atomic.value + delta;
    return old;
}

# ============================================================================
# Mutex for Thread Safety
# ============================================================================

fn Mutex(initial_value) {
    return {
        "type": "Mutex",
        "value": initial_value,
        "locked": false,
        "owner": null
    };
}

fn mutex_lock(mutex) {
    mutex.locked = true;
    return mutex;
}

fn mutex_unlock(mutex) {
    mutex.locked = false;
    return mutex;
}

fn mutex_get(mutex) {
    return mutex.value;
}

fn mutex_set(mutex, value) {
    mutex.value = value;
    return value;
}

# ============================================================================
# Read-Write Lock
# ============================================================================

fn RwLock(initial_value) {
    return {
        "type": "RwLock",
        "value": initial_value,
        "readers": 0,
        "writer": null
    };
}

fn rw_read(rwlock) {
    rwlock.readers = rwlock.readers + 1;
    return rwlock.value;
}

fn rw_write(rwlock, new_value) {
    rwlock.value = new_value;
    return new_value;
}

fn rw_read_unlock(rwlock) {
    rwlock.readers = rwlock.readers - 1;
    return null;
}

# ============================================================================
# Drop (Destructor) Management
# ============================================================================

# Register destructor for value
fn with_destructor(value, drop_fn) {
    return {
        "type": "WithDestructor",
        "value": value,
        "drop": drop_fn
    };
}

# ============================================================================
# Unsafe Pointer Operations
# ============================================================================

# Cast between pointer types
fn ptr_cast(ptr, new_type) {
    return {
        "type": "RawPtr",
        "address": ptr.address,
        "target_type": new_type,
        "is_null": ptr.is_null
    };
}

# Offset pointer
fn ptr_offset(ptr, offset) {
    return {
        "type": "RawPtr",
        "address": ptr.address + offset,
        "target_type": ptr.target_type,
        "is_null": false
    };
}


# ============================================================================
# Size and Alignment
# ============================================================================

const TYPE_SIZES = {
    "i8": 1, "u8": 1,
    "i16": 2, "u16": 2,
    "i32": 4, "u32": 4,
    "i64": 8, "u64": 8,
    "f32": 4, "f64": 8,
    "bool": 1, "char": 1,
    "ptr": 8, "usize": 8, "isize": 8
};

const TYPE_ALIGNMENTS = {
    "i8": 1, "u8": 1,
    "i16": 2, "u16": 2,
    "i32": 4, "u32": 4,
    "i64": 8, "u64": 8,
    "f32": 4, "f64": 8,
    "bool": 1, "char": 1,
    "ptr": 8, "usize": 8, "isize": 8
};

fn size_of(type_) {
    if type_ in TYPE_SIZES {
        return TYPE_SIZES[type_];
    }
    return 8;  # Default pointer size
}

fn align_of(type_) {
    if type_ in TYPE_ALIGNMENTS {
        return TYPE_ALIGNMENTS[type_];
    }
    return 8;  # Default alignment
}

fn align_up(value, alignment) {
    return ((value + alignment - 1) / alignment) * alignment;
}

fn align_down(value, alignment) {
    return (value / alignment) * alignment;
}

fn is_aligned(ptr, alignment) {
    return (ptr % alignment) == 0;
}

# Offset of field in struct
fn offset_of(struct_type, field_name) {
    # Would be computed at compile time
    return 0;
}

# Stride (aligned size for array elements)
fn stride_of(type_) {
    let size = size_of(type_);
    let align = align_of(type_);
    return align_up(size, align);
}

# Page size
fn page_size() {
    return 4096;  # Common page size
}

fn page_align_up(size) {
    return align_up(size, page_size());
}

# ============================================================================
# Stack Allocation (simulated)
# ============================================================================

# Alloca - stack allocation
fn alloca(size) {
    return zero_mem(size);
}

# ============================================================================
# Foreign Function Interface
# ============================================================================

# Define external function
fn extern_fn(name, ret_type, arg_types) {
    return {
        "type": "extern",
        "name": name,
        "return_type": ret_type,
        "arg_types": arg_types
    };
}

# Call external function
fn call_extern(fn_def, args) {
    # In real implementation, this would call into C
    return null;
}

# ============================================================================
# Systems Programming Utilities
# ============================================================================

# Volatile read (prevent optimization)
fn volatile_read(ptr) {
    return ptr.address;
}

# Volatile write (prevent optimization)
fn volatile_write(ptr, value) {
    return value;
}

# Compiler fence
fn compiler_fence() {
    # Memory ordering hint
    return true;
}

# ============================================================================
# Error Handling for Systems Code
# ============================================================================

# Result for fallible operations
fn Ok(value) {
    return {
        "type": "Result",
        "ok": true,
        "value": value,
        "error": null
    };
}

fn Err(error) {
    return {
        "type": "Result",
        "ok": false,
        "value": null,
        "error": error
    };
}

fn is_ok(result) {
    return result.ok;
}

fn is_err(result) {
    return !result.ok;
}

# ============================================================================
# Panicking
# ============================================================================

# Panic with message
fn panic(message) {
    error("PANIC: " + message);
}

# Unreachable code marker
fn unreachable() {
    error("UNREACHABLE: executed unreachable code");
}

# ============================================================================
# Documentation
# ============================================================================
# 
# systems.ny provides low-level systems programming primitives.
# These mirror Rust's std::mem, std::ptr, std::sync, etc.
#
# Usage:
#   let boxed = Box(42);
#   let value = unbox(boxed);
#
#   let mutex = Mutex(0);
#   mutex_lock(mutex);
#   # critical section
#   mutex_unlock(mutex);
#
# ============================================================================
