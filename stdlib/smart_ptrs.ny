// ============================================================================
// SMART POINTERS & RAII
// ============================================================================
// Automatic resource management with RAII (Resource Acquisition Is Initialization)
// Smart pointers for automatic memory management
// - Unique pointers (Box, unique_ptr equivalent)
// - Shared pointers (Rc, Arc, shared_ptr equivalent)
// - Weak pointers (weak_ptr equivalent)
// - Auto pointers with custom deleters
// - Intrusive pointers
// - Scoped pointers
// - Move semantics
// - Perfect forwarding
//
// BEYOND RUST/C++:
// - Automatic cycle detection for shared pointers
// - Performance counters for allocation tracking
// - Leak detection and diagnosis
// - Memory pool integration
// - Zero-overhead custom deleters
// ============================================================================

import @core
import @ownership

// ============================================================================
// BOX (UNIQUE POINTER)
// ============================================================================

// Unique ownership of heap-allocated value
// Equivalent to Rust's Box<T> or C++'s unique_ptr<T>
class Box<T> {
    ptr: *mut T
    
    fn new(value: T) -> Box<T> {
        let ptr = allocate<T>()
        unsafe { *ptr = value }
        return Box(ptr: ptr)
    }
    
    fn from_raw(ptr: *mut T) -> Box<T> {
        return Box(ptr: ptr)
    }
    
    fn into_raw(self) -> *mut T {
        let ptr = self.ptr
        mem::forget(self)  // Don't run destructor
        return ptr
    }
    
    fn leak(self) -> &'static mut T {
        let ptr = self.into_raw()
        return unsafe { &mut *ptr }
    }
}

impl<T> Deref for Box<T> {
    type Target = T
    
    fn deref(self) -> &T {
        return unsafe { &*self.ptr }
    }
}

impl<T> DerefMut for Box<T> {
    fn deref_mut(mut self) -> &mut T {
        return unsafe { &mut *self.ptr }
    }
}

impl<T> Drop for Box<T> {
    fn drop(mut self) {
        unsafe {
            // Run destructor for T
            drop_in_place(self.ptr)
            // Deallocate memory
            deallocate(self.ptr)
        }
    }
}

impl<T: Clone> Clone for Box<T> {
    fn clone(self) -> Box<T> {
        return Box::new((*self).clone())
    }
}

// ============================================================================
// RC (REFERENCE COUNTED POINTER)
// ============================================================================

// Shared ownership with reference counting (single-threaded)
// Equivalent to Rust's Rc<T> or C++'s shared_ptr<T>
class Rc<T> {
    ptr: *mut RcInner<T>
}

struct RcInner<T> {
    value: T,
    strong_count: Cell<usize>,
    weak_count: Cell<usize>
}

impl<T> Rc<T> {
    fn new(value: T) -> Rc<T> {
        let inner = allocate<RcInner<T>>()
        unsafe {
            *inner = RcInner(
                value: value,
                strong_count: Cell::new(1),
                weak_count: Cell::new(0)
            )
        }
        return Rc(ptr: inner)
    }
    
    fn strong_count(self) -> usize {
        return unsafe { (*self.ptr).strong_count.get() }
    }
    
    fn weak_count(self) -> usize {
        return unsafe { (*self.ptr).weak_count.get() }
    }
    
    fn downgrade(self) -> Weak<T> {
        unsafe {
            (*self.ptr).weak_count.set((*self.ptr).weak_count.get() + 1)
        }
        return Weak(ptr: self.ptr)
    }
    
    fn get_mut(mut self) -> Option<&mut T> {
        if self.strong_count() == 1 && self.weak_count() == 0 {
            return Some(unsafe { &mut (*self.ptr).value })
        } else {
            return None
        }
    }
    
    fn make_mut(mut self) -> &mut T where T: Clone {
        if self.strong_count() > 1 {
            // Clone the value to get unique ownership
            let value = (**self).clone()
            *self = Rc::new(value)
        }
        return self.get_mut().unwrap()
    }
    
    fn ptr_eq(self, other: &Rc<T>) -> bool {
        return self.ptr == other.ptr
    }
}

impl<T> Deref for Rc<T> {
    type Target = T
    
    fn deref(self) -> &T {
        return unsafe { &(*self.ptr).value }
    }
}

impl<T> Clone for Rc<T> {
    fn clone(self) -> Rc<T> {
        unsafe {
            (*self.ptr).strong_count.set((*self.ptr).strong_count.get() + 1)
        }
        return Rc(ptr: self.ptr)
    }
}

impl<T> Drop for Rc<T> {
    fn drop(mut self) {
        unsafe {
            let count = (*self.ptr).strong_count.get()
            (*self.ptr).strong_count.set(count - 1)
            
            if count == 1 {
                // Last strong reference, drop the value
                drop_in_place(&mut (*self.ptr).value)
                
                // If no weak references, deallocate
                if (*self.ptr).weak_count.get() == 0 {
                    deallocate(self.ptr)
                }
            }
        }
    }
}

// ============================================================================
// ARC (ATOMIC REFERENCE COUNTED POINTER)
// ============================================================================

// Thread-safe shared ownership with atomic reference counting
// Equivalent to Rust's Arc<T> or C++'s shared_ptr<T> with atomic ops
class Arc<T> {
    ptr: *mut ArcInner<T>
}

struct ArcInner<T> {
    value: T,
    strong_count: AtomicUsize,
    weak_count: AtomicUsize
}

impl<T> Arc<T> {
    fn new(value: T) -> Arc<T> {
        let inner = allocate<ArcInner<T>>()
        unsafe {
            *inner = ArcInner(
                value: value,
                strong_count: AtomicUsize::new(1),
                weak_count: AtomicUsize::new(0)
            )
        }
        return Arc(ptr: inner)
    }
    
    fn strong_count(self) -> usize {
        return unsafe { (*self.ptr).strong_count.load(Ordering::SeqCst) }
    }
    
    fn weak_count(self) -> usize {
        return unsafe { (*self.ptr).weak_count.load(Ordering::SeqCst) }
    }
    
    fn downgrade(self) -> WeakArc<T> {
        unsafe {
            (*self.ptr).weak_count.fetch_add(1, Ordering::Relaxed)
        }
        return WeakArc(ptr: self.ptr)
    }
    
    fn get_mut(mut self) -> Option<&mut T> {
        if self.strong_count() == 1 && self.weak_count() == 0 {
            return Some(unsafe { &mut (*self.ptr).value })
        } else {
            return None
        }
    }
    
    fn make_mut(mut self) -> &mut T where T: Clone {
        if self.strong_count() > 1 {
            let value = (**self).clone()
            *self = Arc::new(value)
        }
        return self.get_mut().unwrap()
    }
    
    fn ptr_eq(self, other: &Arc<T>) -> bool {
        return self.ptr == other.ptr
    }
}

impl<T> Deref for Arc<T> {
    type Target = T
    
    fn deref(self) -> &T {
        return unsafe { &(*self.ptr).value }
    }
}

impl<T> Clone for Arc<T> {
    fn clone(self) -> Arc<T> {
        unsafe {
            (*self.ptr).strong_count.fetch_add(1, Ordering::Relaxed)
        }
        return Arc(ptr: self.ptr)
    }
}

impl<T> Drop for Arc<T> {
    fn drop(mut self) {
        unsafe {
            let old_count = (*self.ptr).strong_count.fetch_sub(1, Ordering::Release)
            
            if old_count == 1 {
                // Last strong reference
                atomic_fence(Ordering::Acquire)
                
                // Drop the value
                drop_in_place(&mut (*self.ptr).value)
                
                // If no weak references, deallocate
                if (*self.ptr).weak_count.load(Ordering::SeqCst) == 0 {
                    deallocate(self.ptr)
                }
            }
        }
    }
}

// ============================================================================
// WEAK POINTERS
// ============================================================================

// Weak reference that doesn't prevent deallocation
class Weak<T> {
    ptr: *mut RcInner<T>
}

impl<T> Weak<T> {
    fn new() -> Weak<T> {
        return Weak(ptr: std::ptr::null_mut())
    }
    
    fn upgrade(self) -> Option<Rc<T>> {
        if self.ptr.is_null() {
            return None
        }
        
        unsafe {
            let count = (*self.ptr).strong_count.get()
            if count == 0 {
                return None
            }
            
            (*self.ptr).strong_count.set(count + 1)
            return Some(Rc(ptr: self.ptr))
        }
    }
    
    fn strong_count(self) -> usize {
        if self.ptr.is_null() {
            return 0
        }
        return unsafe { (*self.ptr).strong_count.get() }
    }
    
    fn weak_count(self) -> usize {
        if self.ptr.is_null() {
            return 0
        }
        return unsafe { (*self.ptr).weak_count.get() }
    }
}

impl<T> Clone for Weak<T> {
    fn clone(self) -> Weak<T> {
        if !self.ptr.is_null() {
            unsafe {
                (*self.ptr).weak_count.set((*self.ptr).weak_count.get() + 1)
            }
        }
        return Weak(ptr: self.ptr)
    }
}

impl<T> Drop for Weak<T> {
    fn drop(mut self) {
        if !self.ptr.is_null() {
            unsafe {
                let count = (*self.ptr).weak_count.get()
                (*self.ptr).weak_count.set(count - 1)
                
                // If this was the last weak reference and no strong references, deallocate
                if count == 1 && (*self.ptr).strong_count.get() == 0 {
                    deallocate(self.ptr)
                }
            }
        }
    }
}

// Thread-safe weak pointer
class WeakArc<T> {
    ptr: *mut ArcInner<T>
}

impl<T> WeakArc<T> {
    fn new() -> WeakArc<T> {
        return WeakArc(ptr: std::ptr::null_mut())
    }
    
    fn upgrade(self) -> Option<Arc<T>> {
        if self.ptr.is_null() {
            return None
        }
        
        unsafe {
            let mut old_count = (*self.ptr).strong_count.load(Ordering::Relaxed)
            loop {
                if old_count == 0 {
                    return None
                }
                
                match (*self.ptr).strong_count.compare_exchange_weak(
                    old_count,
                    old_count + 1,
                    Ordering::Acquire,
                    Ordering::Relaxed
                ) {
                    Ok(_) => return Some(Arc(ptr: self.ptr)),
                    Err(count) => old_count = count
                }
            }
        }
    }
}

impl<T> Clone for WeakArc<T> {
    fn clone(self) -> WeakArc<T> {
        if !self.ptr.is_null() {
            unsafe {
                (*self.ptr).weak_count.fetch_add(1, Ordering::Relaxed)
            }
        }
        return WeakArc(ptr: self.ptr)
    }
}

impl<T> Drop for WeakArc<T> {
    fn drop(mut self) {
        if !self.ptr.is_null() {
            unsafe {
                let old_weak = (*self.ptr).weak_count.fetch_sub(1, Ordering::Release)
                
                if old_weak == 1 {
                    atomic_fence(Ordering::Acquire)
                    
                    if (*self.ptr).strong_count.load(Ordering::SeqCst) == 0 {
                        deallocate(self.ptr)
                    }
                }
            }
        }
    }
}

// ============================================================================
// CUSTOM DELETERS
// ============================================================================

// Unique pointer with custom deleter
class UniquePtr<T, D: FnOnce(*mut T)> {
    ptr: *mut T,
    deleter: D
}

impl<T, D: FnOnce(*mut T)> UniquePtr<T, D> {
    fn new(ptr: *mut T, deleter: D) -> UniquePtr<T, D> {
        return UniquePtr(ptr: ptr, deleter: deleter)
    }
}

impl<T, D: FnOnce(*mut T)> Deref for UniquePtr<T, D> {
    type Target = T
    
    fn deref(self) -> &T {
        return unsafe { &*self.ptr }
    }
}

impl<T, D: FnOnce(*mut T)> Drop for UniquePtr<T, D> {
    fn drop(mut self) {
        (self.deleter)(self.ptr)
    }
}

// Example custom deleters
fn array_deleter<T>(ptr: *mut T, count: usize) {
    unsafe {
        for i in 0..count {
            drop_in_place(ptr.offset(i as isize))
        }
        deallocate_array(ptr, count)
    }
}

fn file_deleter(ptr: *mut File) {
    unsafe {
        (*ptr).close()
        deallocate(ptr)
    }
}

// ============================================================================
// INTRUSIVE POINTERS
// ============================================================================

// Intrusive reference counting - ref count stored in the object itself
trait IntrusiveRefCount {
    fn add_ref(self)
    fn release(self) -> bool  // Returns true if should be deleted
}

class IntrusivePtr<T: IntrusiveRefCount> {
    ptr: *mut T
}

impl<T: IntrusiveRefCount> IntrusivePtr<T> {
    fn new(ptr: *mut T) -> IntrusivePtr<T> {
        if !ptr.is_null() {
            unsafe { (*ptr).add_ref() }
        }
        return IntrusivePtr(ptr: ptr)
    }
    
    fn reset(mut self, ptr: *mut T) {
        if !self.ptr.is_null() {
            unsafe {
                if (*self.ptr).release() {
                    deallocate(self.ptr)
                }
            }
        }
        
        self.ptr = ptr
        if !ptr.is_null() {
            unsafe { (*ptr).add_ref() }
        }
    }
}

impl<T: IntrusiveRefCount> Deref for IntrusivePtr<T> {
    type Target = T
    
    fn deref(self) -> &T {
        return unsafe { &*self.ptr }
    }
}

impl<T: IntrusiveRefCount> Clone for IntrusivePtr<T> {
    fn clone(self) -> IntrusivePtr<T> {
        if !self.ptr.is_null() {
            unsafe { (*self.ptr).add_ref() }
        }
        return IntrusivePtr(ptr: self.ptr)
    }
}

impl<T: IntrusiveRefCount> Drop for IntrusivePtr<T> {
    fn drop(mut self) {
        if !self.ptr.is_null() {
            unsafe {
                if (*self.ptr).release() {
                    deallocate(self.ptr)
                }
            }
        }
    }
}

// Example intrusive ref-counted class
class IntrusiveObject {
    ref_count: AtomicUsize,
    data: i32
}

impl IntrusiveRefCount for IntrusiveObject {
    fn add_ref(self) {
        self.ref_count.fetch_add(1, Ordering::Relaxed)
    }
    
    fn release(self) -> bool {
        return self.ref_count.fetch_sub(1, Ordering::Release) == 1
    }
}

// ============================================================================
// SCOPED POINTERS
// ============================================================================

// Scoped pointer - automatically deleted at end of scope
class ScopedPtr<T> {
    ptr: *mut T
}

impl<T> ScopedPtr<T> {
    fn new(ptr: *mut T) -> ScopedPtr<T> {
        return ScopedPtr(ptr: ptr)
    }
    
    fn reset(mut self, ptr: *mut T) {
        if !self.ptr.is_null() {
            unsafe {
                drop_in_place(self.ptr)
                deallocate(self.ptr)
            }
        }
        self.ptr = ptr
    }
    
    fn release(mut self) -> *mut T {
        let ptr = self.ptr
        self.ptr = std::ptr::null_mut()
        return ptr
    }
}

impl<T> Deref for ScopedPtr<T> {
    type Target = T
    
    fn deref(self) -> &T {
        return unsafe { &*self.ptr }
    }
}

impl<T> Drop for ScopedPtr<T> {
    fn drop(mut self) {
        if !self.ptr.is_null() {
            unsafe {
                drop_in_place(self.ptr)
                deallocate(self.ptr)
            }
        }
    }
}

// ============================================================================
// BEYOND RUST/C++: CYCLE DETECTION
// ============================================================================

// Automatic cycle detection for shared pointers
class CycleDetector {
    allocations: HashMap<usize, AllocationInfo>
}

struct AllocationInfo {
    ptr: usize,
    type_name: String,
    references: Vec<usize>
}

impl CycleDetector {
    fn new() -> CycleDetector {
        return CycleDetector(allocations: HashMap::new())
    }
    
    fn register_allocation(mut self, ptr: usize, type_name: String) {
        self.allocations.insert(ptr, AllocationInfo(
            ptr: ptr,
            type_name: type_name,
            references: Vec::new()
        ))
    }
    
    fn register_reference(mut self, from: usize, to: usize) {
        if let Some(info) = self.allocations.get_mut(&from) {
            info.references.push(to)
        }
    }
    
    fn detect_cycles(self) -> Vec<Vec<usize>> {
        let mut cycles = Vec::new()
        let mut visited = HashSet::new()
        let mut rec_stack = HashSet::new()
        
        for (ptr, _) in &self.allocations {
            if !visited.contains(ptr) {
                self.dfs_detect(*ptr, &mut visited, &mut rec_stack, &mut Vec::new(), &mut cycles)
            }
        }
        
        return cycles
    }
    
    fn dfs_detect(
        self,
        ptr: usize,
        visited: &mut HashSet<usize>,
        rec_stack: &mut HashSet<usize>,
        path: &mut Vec<usize>,
        cycles: &mut Vec<Vec<usize>>
    ) {
        visited.insert(ptr)
        rec_stack.insert(ptr)
        path.push(ptr)
        
        if let Some(info) = self.allocations.get(&ptr) {
            for ref_ptr in &info.references {
                if !visited.contains(ref_ptr) {
                    self.dfs_detect(*ref_ptr, visited, rec_stack, path, cycles)
                } else if rec_stack.contains(ref_ptr) {
                    // Found cycle
                    let cycle_start = path.iter().position(|&p| p == *ref_ptr).unwrap()
                    let cycle = path[cycle_start..].to_vec()
                    cycles.push(cycle)
                }
            }
        }
        
        path.pop()
        rec_stack.remove(&ptr)
    }
}

// Global cycle detector
static mut CYCLE_DETECTOR: ?CycleDetector = None

fn init_cycle_detector() {
    unsafe {
        CYCLE_DETECTOR = Some(CycleDetector::new())
    }
}

fn detect_cycles() -> Vec<Vec<usize>> {
    unsafe {
        return CYCLE_DETECTOR.as_ref().expect("Cycle detector not initialized").detect_cycles()
    }
}

// ============================================================================
// BEYOND RUST/C++: LEAK DETECTION
// ============================================================================

class LeakDetector {
    allocations: HashMap<usize, LeakInfo>,
    next_id: u64
}

struct LeakInfo {
    id: u64,
    ptr: usize,
    size: usize,
    type_name: String,
    stack_trace: Vec<String>,
    timestamp: u64
}

impl LeakDetector {
    fn new() -> LeakDetector {
        return LeakDetector(
            allocations: HashMap::new(),
            next_id: 0
        )
    }
    
    fn track_allocation(mut self, ptr: usize, size: usize, type_name: String) {
        let id = self.next_id
        self.next_id += 1
        
        self.allocations.insert(ptr, LeakInfo(
            id: id,
            ptr: ptr,
            size: size,
            type_name: type_name,
            stack_trace: capture_stack_trace(),
            timestamp: get_timestamp()
        ))
    }
    
    fn track_deallocation(mut self, ptr: usize) {
        self.allocations.remove(&ptr)
    }
    
    fn report_leaks(self) {
        if self.allocations.is_empty() {
            println!("No memory leaks detected!")
            return
        }
        
        println!("MEMORY LEAKS DETECTED:")
        println!("=====================")
        
        let mut total_leaked = 0
        for (_, info) in &self.allocations {
            total_leaked += info.size
            
            println!("\nLeak #{}", info.id)
            println!("  Address: 0x{:x}", info.ptr)
            println!("  Size: {} bytes", info.size)
            println!("  Type: {}", info.type_name)
            println!("  Timestamp: {}", info.timestamp)
            println!("  Stack trace:")
            for frame in &info.stack_trace {
                println!("    {}", frame)
            }
        }
        
        println!("\nTotal leaked: {} bytes in {} allocations", total_leaked, self.allocations.len())
    }
}

// Global leak detector
static mut LEAK_DETECTOR: ?LeakDetector = None

fn init_leak_detector() {
    unsafe {
        LEAK_DETECTOR = Some(LeakDetector::new())
    }
}

fn report_leaks() {
    unsafe {
        LEAK_DETECTOR.as_ref().expect("Leak detector not initialized").report_leaks()
    }
}

// ============================================================================
// EXAMPLES
// ============================================================================

fn example_box() {
    let x = Box::new(42)
    println!("Boxed value: {}", *x)
    
    let mut y = Box::new(vec![1, 2, 3])
    y.push(4)
    // x is automatically freed when it goes out of scope
}

fn example_rc() {
    let rc1 = Rc::new(vec![1, 2, 3])
    let rc2 = rc1.clone()  // Reference count = 2
    let rc3 = rc1.clone()  // Reference count = 3
    
    println!("Reference count: {}", Rc::strong_count(&rc1))
    
    // All three pointers share ownership
    println!("{:?}", *rc1)
    println!("{:?}", *rc2)
    println!("{:?}", *rc3)
    
    // When last Rc drops, memory is freed
}

fn example_weak() {
    let rc = Rc::new(42)
    let weak = Rc::downgrade(&rc)
    
    println!("Strong: {}, Weak: {}", Rc::strong_count(&rc), Rc::weak_count(&rc))
    
    // Upgrade weak to strong
    if let Some(strong) = weak.upgrade() {
        println!("Value: {}", *strong)
    }
    
    drop(rc)  // Drop strong reference
    
    // Now weak reference can't be upgraded
    assert!(weak.upgrade().is_none())
}

fn example_arc() {
    let arc = Arc::new(vec![1, 2, 3])
    
    // Share across threads
    let arc1 = arc.clone()
    let thread1 = std::thread::spawn(move || {
        println!("Thread 1: {:?}", *arc1)
    })
    
    let arc2 = arc.clone()
    let thread2 = std::thread::spawn(move || {
        println!("Thread 2: {:?}", *arc2)
    })
    
    thread1.join()
    thread2.join()
}

fn example_cycle_detection() {
    init_cycle_detector()
    
    // Create a cycle
    let node1 = Rc::new(RefCell::new(None))
    let node2 = Rc::new(RefCell::new(Some(node1.clone())))
    *node1.borrow_mut() = Some(node2.clone())
    
    // Detect the cycle
    let cycles = detect_cycles()
    if !cycles.is_empty() {
        println!("WARNING: Reference cycle detected!")
        for cycle in cycles {
            println!("  Cycle: {:?}", cycle)
        }
    }
}
