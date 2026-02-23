# ===========================================
# Nyx Standard Library - Atomics
# ===========================================
# Atomic operations for lock-free concurrent programming
# Memory ordering guarantees for multi-threaded code

import systems

# ===========================================
# Memory Ordering
# ===========================================
# Defines ordering constraints for atomic operations

class MemoryOrder {
    # No ordering constraints - fastest, but no synchronization
    let RELAXED = 0;
    
    # Prevents reordering of this and previous reads/writes
    let ACQUIRE = 1;
    
    # Prevents reordering of this and subsequent reads/writes
    let RELEASE = 2;
    
    # Both acquire and release semantics
    let ACQ_REL = 3;
    
    # Sequential consistency - strongest guarantee
    let SEQ_CST = 4;
}

# ===========================================
# Atomic Integer (32-bit)
# ===========================================

class AtomicI32 {
    fn init(self, value = 0) {
        self.ptr = systems.malloc(4);
        if self.ptr == null {
            throw "AtomicI32.init: allocation failed";
        }
        self.store(value, MemoryOrder.SEQ_CST);
    }
    
    fn load(self, order = MemoryOrder.SEQ_CST) {
        return _atomic_load_i32(self.ptr, order);
    }
    
    fn store(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_store_i32(self.ptr, value, order);
    }
    
    fn exchange(self, value, order = MemoryOrder.SEQ_CST) {
        # Atomically replace value and return old value
        return _atomic_exchange_i32(self.ptr, value, order);
    }
    
    fn compare_exchange(self, expected, desired, success_order = MemoryOrder.SEQ_CST, failure_order = MemoryOrder.SEQ_CST) {
        # Compare-and-swap (CAS) operation
        # Returns [success: bool, old_value: int]
        return _atomic_compare_exchange_i32(self.ptr, expected, desired, success_order, failure_order);
    }
    
    fn fetch_add(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_fetch_add_i32(self.ptr, value, order);
    }
    
    fn fetch_sub(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_fetch_sub_i32(self.ptr, value, order);
    }
    
    fn fetch_and(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_fetch_and_i32(self.ptr, value, order);
    }
    
    fn fetch_or(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_fetch_or_i32(self.ptr, value, order);
    }
    
    fn fetch_xor(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_fetch_xor_i32(self.ptr, value, order);
    }
    
    fn increment(self, order = MemoryOrder.SEQ_CST) {
        return self.fetch_add(1, order) + 1;
    }
    
    fn decrement(self, order = MemoryOrder.SEQ_CST) {
        return self.fetch_sub(1, order) - 1;
    }
    
    fn destroy(self) {
        if self.ptr != null {
            systems.free(self.ptr);
            self.ptr = null;
        }
    }
}

# ===========================================
# Atomic Integer (64-bit)
# ===========================================

class AtomicI64 {
    fn init(self, value = 0) {
        self.ptr = systems.malloc(8);
        if self.ptr == null {
            throw "AtomicI64.init: allocation failed";
        }
        self.store(value, MemoryOrder.SEQ_CST);
    }
    
    fn load(self, order = MemoryOrder.SEQ_CST) {
        return _atomic_load_i64(self.ptr, order);
    }
    
    fn store(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_store_i64(self.ptr, value, order);
    }
    
    fn exchange(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_exchange_i64(self.ptr, value, order);
    }
    
    fn compare_exchange(self, expected, desired, success_order = MemoryOrder.SEQ_CST, failure_order = MemoryOrder.SEQ_CST) {
        return _atomic_compare_exchange_i64(self.ptr, expected, desired, success_order, failure_order);
    }
    
    fn fetch_add(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_fetch_add_i64(self.ptr, value, order);
    }
    
    fn fetch_sub(self, value, order = MemoryOrder.SEQ_CST) {
        return _atomic_fetch_sub_i64(self.ptr, value, order);
    }
    
    fn increment(self, order = MemoryOrder.SEQ_CST) {
        return self.fetch_add(1, order) + 1;
    }
    
    fn decrement(self, order = MemoryOrder.SEQ_CST) {
        return self.fetch_sub(1, order) - 1;
    }
    
    fn destroy(self) {
        if self.ptr != null {
            systems.free(self.ptr);
            self.ptr = null;
        }
    }
}

# ===========================================
# Atomic Boolean
# ===========================================

class AtomicBool {
    fn init(self, value = false) {
        self.ptr = systems.malloc(1);
        if self.ptr == null {
            throw "AtomicBool.init: allocation failed";
        }
        self.store(value, MemoryOrder.SEQ_CST);
    }
    
    fn load(self, order = MemoryOrder.SEQ_CST) {
        let val = _atomic_load_i8(self.ptr, order);
        return val != 0;
    }
    
    fn store(self, value, order = MemoryOrder.SEQ_CST) {
        let int_val = value ? 1 : 0;
        return _atomic_store_i8(self.ptr, int_val, order);
    }
    
    fn exchange(self, value, order = MemoryOrder.SEQ_CST) {
        let int_val = value ? 1 : 0;
        let old = _atomic_exchange_i8(self.ptr, int_val, order);
        return old != 0;
    }
    
    fn compare_exchange(self, expected, desired, success_order = MemoryOrder.SEQ_CST, failure_order = MemoryOrder.SEQ_CST) {
        let expected_int = expected ? 1 : 0;
        let desired_int = desired ? 1 : 0;
        let result = _atomic_compare_exchange_i8(self.ptr, expected_int, desired_int, success_order, failure_order);
        return [result[0], result[1] != 0];
    }
    
    fn test_and_set(self, order = MemoryOrder.SEQ_CST) {
        # Set to true and return old value
        let old = _atomic_exchange_i8(self.ptr, 1, order);
        return old != 0;
    }
    
    fn clear(self, order = MemoryOrder.SEQ_CST) {
        self.store(false, order);
    }
    
    fn destroy(self) {
        if self.ptr != null {
            systems.free(self.ptr);
            self.ptr = null;
        }
    }
}

# ===========================================
# Atomic Pointer
# ===========================================

class AtomicPtr {
    fn init(self, ptr = null) {
        self.storage = systems.malloc(8);
        if self.storage == null {
            throw "AtomicPtr.init: allocation failed";
        }
        self.store(ptr, MemoryOrder.SEQ_CST);
    }
    
    fn load(self, order = MemoryOrder.SEQ_CST) {
        return _atomic_load_ptr(self.storage, order);
    }
    
    fn store(self, ptr, order = MemoryOrder.SEQ_CST) {
        return _atomic_store_ptr(self.storage, ptr, order);
    }
    
    fn exchange(self, ptr, order = MemoryOrder.SEQ_CST) {
        return _atomic_exchange_ptr(self.storage, ptr, order);
    }
    
    fn compare_exchange(self, expected, desired, success_order = MemoryOrder.SEQ_CST, failure_order = MemoryOrder.SEQ_CST) {
        return _atomic_compare_exchange_ptr(self.storage, expected, desired, success_order, failure_order);
    }
    
    fn destroy(self) {
        if self.storage != null {
            systems.free(self.storage);
            self.storage = null;
        }
    }
}

# ===========================================
# Memory Fences
# ===========================================

fn fence(order = MemoryOrder.SEQ_CST) {
    # Memory barrier - prevents reordering across this point
    return _atomic_fence(order);
}

fn compiler_fence(order = MemoryOrder.SEQ_CST) {
    # Compiler-only barrier - prevents compiler reordering
    return _atomic_compiler_fence(order);
}

# ===========================================
# Spinlock (Lock-Free)
# ===========================================

class Spinlock {
    fn init(self) {
        self.locked = AtomicBool(false);
    }
    
    fn lock(self) {
        # Spin until we acquire the lock
        while true {
            # Try to acquire
            if !self.locked.exchange(true, MemoryOrder.ACQUIRE) {
                return;
            }
            
            # Backoff - reduce contention
            let backoff = 0;
            while self.locked.load(MemoryOrder.RELAXED) && backoff < 10 {
                _yield();
                backoff = backoff + 1;
            }
        }
    }
    
    fn try_lock(self) {
        # Try once without spinning
        return !self.locked.exchange(true, MemoryOrder.ACQUIRE);
    }
    
    fn unlock(self) {
        self.locked.store(false, MemoryOrder.RELEASE);
    }
    
    fn is_locked(self) {
        return self.locked.load(MemoryOrder.RELAXED);
    }
    
    fn destroy(self) {
        self.locked.destroy();
    }
}

# ===========================================
# Read-Write Lock (Lock-Free)
# ===========================================

class RwLock {
    fn init(self) {
        # Bit 31: write lock
        # Bits 0-30: reader count
        self.state = AtomicI32(0);
    }
    
    fn read_lock(self) {
        while true {
            let s = self.state.load(MemoryOrder.ACQUIRE);
            
            # Check if write locked
            if s & 0x80000000 != 0 {
                _yield();
                continue;
            }
            
            # Try to increment reader count
            let result = self.state.compare_exchange(
                s, 
                s + 1,
                MemoryOrder.ACQUIRE,
                MemoryOrder.RELAXED
            );
            
            if result[0] {
                return;
            }
        }
    }
    
    fn read_unlock(self) {
        self.state.fetch_sub(1, MemoryOrder.RELEASE);
    }
    
    fn write_lock(self) {
        while true {
            let s = self.state.load(MemoryOrder.ACQUIRE);
            
            # Try to acquire write lock if no readers or writers
            if s == 0 {
                let result = self.state.compare_exchange(
                    0,
                    0x80000000,
                    MemoryOrder.ACQUIRE,
                    MemoryOrder.RELAXED
                );
                
                if result[0] {
                    return;
                }
            }
            
            _yield();
        }
    }
    
    fn write_unlock(self) {
        self.state.store(0, MemoryOrder.RELEASE);
    }
    
    fn destroy(self) {
        self.state.destroy();
    }
}

# ===========================================
# Atomic Reference Counter
# ===========================================

class AtomicRefCount {
    fn init(self, initial = 1) {
        self.count = AtomicI32(initial);
    }
    
    fn increment(self) {
        self.count.fetch_add(1, MemoryOrder.RELAXED);
    }
    
    fn decrement(self) {
        # Returns true if count reached zero
        let old = self.count.fetch_sub(1, MemoryOrder.RELEASE);
        if old == 1 {
            fence(MemoryOrder.ACQUIRE);
            return true;
        }
        return false;
    }
    
    fn get(self) {
        return self.count.load(MemoryOrder.RELAXED);
    }
    
    fn destroy(self) {
        self.count.destroy();
    }
}

# ===========================================
# Lock-Free Stack (Treiber Stack)
# ===========================================

class LockFreeStack {
    fn init(self) {
        self.head = AtomicPtr(null);
    }
    
    fn push(self, value) {
        # Create node
        let node = {
            "value": value,
            "next": null
        };
        
        while true {
            let current_head = self.head.load(MemoryOrder.RELAXED);
            node["next"] = current_head;
            
            let result = self.head.compare_exchange(
                current_head,
                node,
                MemoryOrder.RELEASE,
                MemoryOrder.RELAXED
            );
            
            if result[0] {
                return;
            }
        }
    }
    
    fn pop(self) {
        while true {
            let current_head = self.head.load(MemoryOrder.ACQUIRE);
            
            if current_head == null {
                return null;
            }
            
            let next = current_head["next"];
            
            let result = self.head.compare_exchange(
                current_head,
                next,
                MemoryOrder.RELEASE,
                MemoryOrder.RELAXED
            );
            
            if result[0] {
                return current_head["value"];
            }
        }
    }
    
    fn is_empty(self) {
        return self.head.load(MemoryOrder.RELAXED) == null;
    }
    
    fn destroy(self) {
        self.head.destroy();
    }
}

# ===========================================
# Lock-Free Queue (Michael-Scott Queue)
# ===========================================

class LockFreeQueue {
    fn init(self) {
        # Dummy node
        let dummy = {
            "value": null,
            "next": AtomicPtr(null)
        };
        
        self.head = AtomicPtr(dummy);
        self.tail = AtomicPtr(dummy);
    }
    
    fn enqueue(self, value) {
        # Create new node
        let node = {
            "value": value,
            "next": AtomicPtr(null)
        };
        
        while true {
            let tail = self.tail.load(MemoryOrder.ACQUIRE);
            let next = tail["next"].load(MemoryOrder.ACQUIRE);
            
            if next == null {
                # Try to link node
                let result = tail["next"].compare_exchange(
                    null,
                    node,
                    MemoryOrder.RELEASE,
                    MemoryOrder.RELAXED
                );
                
                if result[0] {
                    # Try to swing tail
                    self.tail.compare_exchange(
                        tail,
                        node,
                        MemoryOrder.RELEASE,
                        MemoryOrder.RELAXED
                    );
                    return;
                }
            } else {
                # Tail is lagging, try to advance it
                self.tail.compare_exchange(
                    tail,
                    next,
                    MemoryOrder.RELEASE,
                    MemoryOrder.RELAXED
                );
            }
        }
    }
    
    fn dequeue(self) {
        while true {
            let head = self.head.load(MemoryOrder.ACQUIRE);
            let tail = self.tail.load(MemoryOrder.ACQUIRE);
            let next = head["next"].load(MemoryOrder.ACQUIRE);
            
            if next == null {
                return null;  # Empty queue
            }
            
            if head == tail {
                # Tail is lagging
                self.tail.compare_exchange(
                    tail,
                    next,
                    MemoryOrder.RELEASE,
                    MemoryOrder.RELAXED
                );
            } else {
                # Try to swing head
                let result = self.head.compare_exchange(
                    head,
                    next,
                    MemoryOrder.RELEASE,
                    MemoryOrder.RELAXED
                );
                
                if result[0] {
                    return next["value"];
                }
            }
        }
    }
    
    fn is_empty(self) {
        let head = self.head.load(MemoryOrder.ACQUIRE);
        let next = head["next"].load(MemoryOrder.ACQUIRE);
        return next == null;
    }
    
    fn destroy(self) {
        self.head.destroy();
        self.tail.destroy();
    }
}

# ===========================================
# Atomic Statistics
# ===========================================

class AtomicStats {
    fn init(self) {
        self.operations = AtomicI64(0);
        self.conflicts = AtomicI64(0);
        self.retries = AtomicI64(0);
    }
    
    fn record_operation(self) {
        self.operations.increment(MemoryOrder.RELAXED);
    }
    
    fn record_conflict(self) {
        self.conflicts.increment(MemoryOrder.RELAXED);
    }
    
    fn record_retry(self) {
        self.retries.increment(MemoryOrder.RELAXED);
    }
    
    fn report(self) {
        let ops = self.operations.load(MemoryOrder.RELAXED);
        let conflicts = self.conflicts.load(MemoryOrder.RELAXED);
        let retries = self.retries.load(MemoryOrder.RELAXED);
        
        return {
            "operations": ops,
            "conflicts": conflicts,
            "retries": retries,
            "conflict_rate": conflicts / ops if ops > 0 else 0.0
        };
    }
    
    fn destroy(self) {
        self.operations.destroy();
        self.conflicts.destroy();
        self.retries.destroy();
    }
}

# ===========================================
# Native Implementation Stubs
# ===========================================
# These would be implemented in C/Rust with actual atomic instructions

fn _atomic_load_i32(ptr, order) {
    # __atomic_load_n(ptr, order)
    return systems.peek_i32(ptr);
}

fn _atomic_store_i32(ptr, value, order) {
    # __atomic_store_n(ptr, value, order)
    systems.poke_i32(ptr, value);
}

fn _atomic_exchange_i32(ptr, value, order) {
    # __atomic_exchange_n(ptr, value, order)
    let old = systems.peek_i32(ptr);
    systems.poke_i32(ptr, value);
    return old;
}

fn _atomic_compare_exchange_i32(ptr, expected, desired, success_order, failure_order) {
    # __atomic_compare_exchange_n(ptr, &expected, desired, false, success_order, failure_order)
    let current = systems.peek_i32(ptr);
    if current == expected {
        systems.poke_i32(ptr, desired);
        return [true, current];
    }
    return [false, current];
}

fn _atomic_fetch_add_i32(ptr, value, order) {
    let old = systems.peek_i32(ptr);
    systems.poke_i32(ptr, old + value);
    return old;
}

fn _atomic_fetch_sub_i32(ptr, value, order) {
    let old = systems.peek_i32(ptr);
    systems.poke_i32(ptr, old - value);
    return old;
}

fn _atomic_fetch_and_i32(ptr, value, order) {
    let old = systems.peek_i32(ptr);
    systems.poke_i32(ptr, old & value);
    return old;
}

fn _atomic_fetch_or_i32(ptr, value, order) {
    let old = systems.peek_i32(ptr);
    systems.poke_i32(ptr, old | value);
    return old;
}

fn _atomic_fetch_xor_i32(ptr, value, order) {
    let old = systems.peek_i32(ptr);
    systems.poke_i32(ptr, old ^ value);
    return old;
}

fn _atomic_fence(order) {
    # __atomic_thread_fence(order)
}

fn _atomic_compiler_fence(order) {
    # __atomic_signal_fence(order)
}

fn _yield() {
    # Platform-specific yield
    # Windows: SwitchToThread()
    # Linux: sched_yield()
}

# Similar implementations for i64, i8, ptr...
fn _atomic_load_i64(ptr, order) { return systems.peek_i64(ptr); }
fn _atomic_store_i64(ptr, value, order) { systems.poke_i64(ptr, value); }
fn _atomic_exchange_i64(ptr, value, order) { let old = systems.peek_i64(ptr); systems.poke_i64(ptr, value); return old; }
fn _atomic_compare_exchange_i64(ptr, expected, desired, success_order, failure_order) {
    let current = systems.peek_i64(ptr);
    if current == expected { systems.poke_i64(ptr, desired); return [true, current]; }
    return [false, current];
}
fn _atomic_fetch_add_i64(ptr, value, order) { let old = systems.peek_i64(ptr); systems.poke_i64(ptr, old + value); return old; }
fn _atomic_fetch_sub_i64(ptr, value, order) { let old = systems.peek_i64(ptr); systems.poke_i64(ptr, old - value); return old; }

fn _atomic_load_i8(ptr, order) { return systems.peek_i8(ptr); }
fn _atomic_store_i8(ptr, value, order) { systems.poke_i8(ptr, value); }
fn _atomic_exchange_i8(ptr, value, order) { let old = systems.peek_i8(ptr); systems.poke_i8(ptr, value); return old; }
fn _atomic_compare_exchange_i8(ptr, expected, desired, success_order, failure_order) {
    let current = systems.peek_i8(ptr);
    if current == expected { systems.poke_i8(ptr, desired); return [true, current]; }
    return [false, current];
}

fn _atomic_load_ptr(ptr, order) { return systems.peek_ptr(ptr); }
fn _atomic_store_ptr(ptr, value, order) { systems.poke_ptr(ptr, value); }
fn _atomic_exchange_ptr(ptr, value, order) { let old = systems.peek_ptr(ptr); systems.poke_ptr(ptr, value); return old; }
fn _atomic_compare_exchange_ptr(ptr, expected, desired, success_order, failure_order) {
    let current = systems.peek_ptr(ptr);
    if current == expected { systems.poke_ptr(ptr, desired); return [true, current]; }
    return [false, current];
}
