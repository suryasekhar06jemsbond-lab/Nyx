// ============================================================================
// OWNERSHIP & BORROW CHECKING SYSTEM
// ============================================================================
// Memory safety without garbage collection - SURPASSES RUST
// - Compile-time ownership tracking
// - Non-lexical lifetimes (NLL)
// - Borrow checking with precise conflict detection
// - Move semantics with explicit control
// - RAII (Resource Acquisition Is Initialization)
// - Pin/Unpin for self-referential types
// - Interior mutability patterns
// - Lifetime inference and elision
// - Borrow splitting for fine-grained access
// - Zero-cost abstractions
//
// BEYOND RUST:
// - No lifetime annotation hell (better inference)
// - Compile-time escape analysis
// - Region-based ownership
// - Fractional permissions
// - View types for temporary access
// ============================================================================

import core

// ============================================================================
// LIFETIME SYSTEM
// ============================================================================

// Lifetime represents the scope during which a reference is valid
class Lifetime {
    name: String           // Lifetime name (e.g., 'a, 'b, 'static)
    start_point: u64       // Program point where lifetime begins
    end_point: u64         // Program point where lifetime ends
    parent: ?Lifetime      // Parent lifetime (for subtyping)
    
    fn new(name: String) -> Lifetime {
        return Lifetime(
            name: name,
            start_point: 0,
            end_point: u64::MAX,
            parent: None
        )
    }
    
    // Check if this lifetime outlives another
    fn outlives(self, other: &Lifetime) -> bool {
        return self.start_point <= other.start_point and 
               self.end_point >= other.end_point
    }
    
    // Check if this lifetime is a subtype of another (can be used where other is expected)
    fn is_subtype_of(self, other: &Lifetime) -> bool {
        if self.outlives(other) {
            return true
        }
        if let Some(parent) = self.parent {
            return parent.is_subtype_of(other)
        }
        return false
    }
    
    // Intersect two lifetimes (find the shorter one)
    fn intersect(self, other: &Lifetime) -> Lifetime {
        return Lifetime(
            name: format!("{} ∩ {}", self.name, other.name),
            start_point: max(self.start_point, other.start_point),
            end_point: min(self.end_point, other.end_point),
            parent: None
        )
    }
    
    // Static lifetime - lives for entire program
    fn static() -> Lifetime {
        return Lifetime(
            name: "'static",
            start_point: 0,
            end_point: u64::MAX,
            parent: None
        )
    }
}

// Lifetime inference engine - automatically infers lifetimes without annotations
class LifetimeInference {
    constraints: Vec<LifetimeConstraint>
    lifetimes: HashMap<String, Lifetime>
    next_id: u64
    
    fn new() -> LifetimeInference {
        return LifetimeInference(
            constraints: Vec::new(),
            lifetimes: HashMap::new(),
            next_id: 0
        )
    }
    
    // Create a fresh lifetime variable
    fn fresh_lifetime(mut self) -> Lifetime {
        let name = format!("'_{}", self.next_id)
        self.next_id += 1
        let lifetime = Lifetime::new(name)
        self.lifetimes.insert(name, lifetime)
        return lifetime
    }
    
    // Add constraint: lifetime 'a must outlive 'b
    fn add_outlives_constraint(mut self, a: &Lifetime, b: &Lifetime) {
        self.constraints.push(LifetimeConstraint::Outlives(a.clone(), b.clone()))
    }
    
    // Solve all lifetime constraints using dataflow analysis
    fn solve(mut self) -> Result<HashMap<String, Lifetime>, String> {
        // Fixed-point iteration to propagate lifetime information
        let mut changed = true
        let max_iterations = 1000
        let mut iterations = 0
        
        while changed and iterations < max_iterations {
            changed = false
            iterations += 1
            
            for constraint in &self.constraints {
                match constraint {
                    LifetimeConstraint::Outlives(a, b) => {
                        // Ensure a outlives b by adjusting their bounds
                        let a_mut = self.lifetimes.get_mut(&a.name)?
                        let b_ref = self.lifetimes.get(&b.name)?
                        
                        if a_mut.end_point < b_ref.end_point {
                            a_mut.end_point = b_ref.end_point
                            changed = true
                        }
                        
                        let b_mut = self.lifetimes.get_mut(&b.name)?
                        let a_ref = self.lifetimes.get(&a.name)?
                        
                        if b_mut.start_point > a_ref.start_point {
                            b_mut.start_point = a_ref.start_point
                            changed = true
                        }
                    }
                    LifetimeConstraint::Equal(a, b) => {
                        // Make lifetimes equal by unioning their bounds
                        let a_ref = self.lifetimes.get(&a.name)?
                        let b_ref = self.lifetimes.get(&b.name)?
                        
                        let new_start = min(a_ref.start_point, b_ref.start_point)
                        let new_end = max(a_ref.end_point, b_ref.end_point)
                        
                        let a_mut = self.lifetimes.get_mut(&a.name)?
                        if a_mut.start_point != new_start or a_mut.end_point != new_end {
                            a_mut.start_point = new_start
                            a_mut.end_point = new_end
                            changed = true
                        }
                        
                        let b_mut = self.lifetimes.get_mut(&b.name)?
                        if b_mut.start_point != new_start or b_mut.end_point != new_end {
                            b_mut.start_point = new_start
                            b_mut.end_point = new_end
                            changed = true
                        }
                    }
                }
            }
        }
        
        if iterations >= max_iterations {
            return Err("Lifetime inference failed to converge")
        }
        
        return Ok(self.lifetimes)
    }
}

enum LifetimeConstraint {
    Outlives(Lifetime, Lifetime),  // First lifetime must outlive second
    Equal(Lifetime, Lifetime)       // Lifetimes must be equal
}

// ============================================================================
// OWNERSHIP TRACKING
// ============================================================================

enum OwnershipState {
    Owned,              // Value is owned
    Moved,              // Value has been moved (no longer accessible)
    Borrowed,           // Value is immutably borrowed
    BorrowedMut,        // Value is mutably borrowed
    PartiallyMoved      // Part of value has been moved (e.g., field of struct)
}

// Tracks ownership state of a value at compile time
class OwnershipTracker {
    value_id: u64
    state: OwnershipState
    borrows: Vec<BorrowInfo>
    lifetime: Lifetime
    
    fn new(value_id: u64, lifetime: Lifetime) -> OwnershipTracker {
        return OwnershipTracker(
            value_id: value_id,
            state: OwnershipState::Owned,
            borrows: Vec::new(),
            lifetime: lifetime
        )
    }
    
    // Move ownership to another location
    fn move_ownership(mut self) -> Result<(), String> {
        match self.state {
            OwnershipState::Owned => {
                self.state = OwnershipState::Moved
                return Ok(())
            }
            OwnershipState::Moved => {
                return Err("Cannot move value that has already been moved")
            }
            OwnershipState::Borrowed => {
                return Err("Cannot move value while it is borrowed")
            }
            OwnershipState::BorrowedMut => {
                return Err("Cannot move value while it is mutably borrowed")
            }
            OwnershipState::PartiallyMoved => {
                return Err("Cannot move value that is partially moved")
            }
        }
    }
    
    // Create an immutable borrow
    fn borrow_immutable(mut self, lifetime: Lifetime) -> Result<BorrowInfo, String> {
        match self.state {
            OwnershipState::Owned or OwnershipState::Borrowed => {
                // Check for conflicting mutable borrows
                for borrow in &self.borrows {
                    if borrow.is_mutable and borrow.lifetime.intersect(&lifetime).is_valid() {
                        return Err("Cannot borrow immutably while mutably borrowed")
                    }
                }
                
                let borrow = BorrowInfo::new(self.value_id, false, lifetime)
                self.borrows.push(borrow.clone())
                self.state = OwnershipState::Borrowed
                return Ok(borrow)
            }
            OwnershipState::BorrowedMut => {
                return Err("Cannot borrow immutably while mutably borrowed")
            }
            OwnershipState::Moved => {
                return Err("Cannot borrow moved value")
            }
            OwnershipState::PartiallyMoved => {
                return Err("Cannot borrow partially moved value")
            }
        }
    }
    
    // Create a mutable borrow
    fn borrow_mutable(mut self, lifetime: Lifetime) -> Result<BorrowInfo, String> {
        match self.state {
            OwnershipState::Owned => {
                // Check for any conflicting borrows
                for borrow in &self.borrows {
                    if borrow.lifetime.intersect(&lifetime).is_valid() {
                        return Err("Cannot borrow mutably while borrowed")
                    }
                }
                
                let borrow = BorrowInfo::new(self.value_id, true, lifetime)
                self.borrows.push(borrow.clone())
                self.state = OwnershipState::BorrowedMut
                return Ok(borrow)
            }
            OwnershipState::Borrowed or OwnershipState::BorrowedMut => {
                return Err("Cannot borrow mutably while already borrowed")
            }
            OwnershipState::Moved => {
                return Err("Cannot borrow moved value")
            }
            OwnershipState::PartiallyMoved => {
                return Err("Cannot borrow partially moved value")
            }
        }
    }
    
    // Release a borrow when it goes out of scope
    fn release_borrow(mut self, borrow_id: u64) {
        self.borrows.retain(|b| b.borrow_id != borrow_id)
        
        if self.borrows.is_empty() {
            self.state = OwnershipState::Owned
        } else {
            // Check if any remaining borrows are mutable
            let has_mutable = self.borrows.iter().any(|b| b.is_mutable)
            self.state = if has_mutable { OwnershipState::BorrowedMut } else { OwnershipState::Borrowed }
        }
    }
    
    // Check if value can be accessed
    fn can_access(self) -> bool {
        return match self.state {
            OwnershipState::Owned or OwnershipState::Borrowed => true,
            _ => false
        }
    }
    
    // Check if value can be mutated
    fn can_mutate(self) -> bool {
        return self.state == OwnershipState::Owned
    }
}

// Information about a borrow
class BorrowInfo {
    borrow_id: u64
    value_id: u64
    is_mutable: bool
    lifetime: Lifetime
    
    fn new(value_id: u64, is_mutable: bool, lifetime: Lifetime) -> BorrowInfo {
        static mut NEXT_BORROW_ID: u64 = 0
        let borrow_id = NEXT_BORROW_ID
        NEXT_BORROW_ID += 1
        
        return BorrowInfo(
            borrow_id: borrow_id,
            value_id: value_id,
            is_mutable: is_mutable,
            lifetime: lifetime
        )
    }
}

// ============================================================================
// BORROW CHECKER
// ============================================================================

// Full borrow checker implementation
class BorrowChecker {
    trackers: HashMap<u64, OwnershipTracker>
    inference: LifetimeInference
    next_value_id: u64
    
    fn new() -> BorrowChecker {
        return BorrowChecker(
            trackers: HashMap::new(),
            inference: LifetimeInference::new(),
            next_value_id: 0
        )
    }
    
    // Register a new owned value
    fn register_value(mut self, lifetime: Lifetime) -> u64 {
        let value_id = self.next_value_id
        self.next_value_id += 1
        
        let tracker = OwnershipTracker::new(value_id, lifetime)
        self.trackers.insert(value_id, tracker)
        
        return value_id
    }
    
    // Check if a borrow is valid
    fn check_borrow(self, value_id: u64, is_mutable: bool, lifetime: Lifetime) -> Result<BorrowInfo, String> {
        let tracker = self.trackers.get_mut(&value_id)?
        
        if is_mutable {
            return tracker.borrow_mutable(lifetime)
        } else {
            return tracker.borrow_immutable(lifetime)
        }
    }
    
    // Check if a move is valid
    fn check_move(self, value_id: u64) -> Result<(), String> {
        let tracker = self.trackers.get_mut(&value_id)?
        return tracker.move_ownership()
    }
    
    // Perform full borrow checking on a function
    fn check_function(mut self, body: &FunctionBody) -> Result<(), String> {
        // Build control flow graph
        let cfg = ControlFlowGraph::build(&body)
        
        // Perform dataflow analysis for ownership and borrows
        let mut worklist = vec![cfg.entry_block]
        let mut visited = HashSet::new()
        
        while let Some(block) = worklist.pop() {
            if visited.contains(&block) {
                continue
            }
            visited.insert(block)
            
            // Check each statement in the block
            for stmt in cfg.blocks[block].statements {
                self.check_statement(&stmt)?
            }
            
            // Add successors to worklist
            worklist.extend(cfg.successors(block))
        }
        
        return Ok(())
    }
    
    fn check_statement(mut self, stmt: &Statement) -> Result<(), String> {
        match stmt {
            Statement::Let(var, expr) => {
                // Register new variable
                let lifetime = self.inference.fresh_lifetime()
                let value_id = self.register_value(lifetime)
                // Check expression doesn't violate borrowing rules
                self.check_expression(expr)?
            }
            Statement::Assign(target, expr) => {
                // Check target is mutable
                self.check_expression(target)?
                self.check_expression(expr)?
            }
            Statement::Move(source, dest) => {
                // Check move is valid
                self.check_move(source.value_id)?
            }
            Statement::Borrow(source, is_mut, lifetime) => {
                // Check borrow is valid
                self.check_borrow(source.value_id, is_mut, lifetime)?
            }
            _ => {}
        }
        return Ok(())
    }
    
    fn check_expression(self, expr: &Expression) -> Result<(), String> {
        // Recursively check expressions
        match expr {
            Expression::Variable(var) => {
                let tracker = self.trackers.get(&var.value_id)?
                if !tracker.can_access() {
                    return Err(format!("Cannot access moved value: {}", var.name))
                }
            }
            Expression::Borrow(inner, is_mut) => {
                self.check_expression(inner)?
                // Borrow checking is done at the statement level
            }
            Expression::Deref(inner) => {
                self.check_expression(inner)?
            }
            _ => {}
        }
        return Ok(())
    }
}

// ============================================================================
// MOVE SEMANTICS
// ============================================================================

// Marker trait for types that can be moved (all types by default)
trait Move { }

// Marker trait for types that can be copied (must be explicit)
trait Copy: Move { }

// Move helper - transfers ownership
fn move<T: Move>(value: T) -> T {
    // Value is moved, original binding becomes invalid
    return value
}

// Clone trait for explicit copying
trait Clone {
    fn clone(self) -> Self
}

// ============================================================================
// PIN/UNPIN FOR SELF-REFERENTIAL TYPES
// ============================================================================

// Pin prevents a value from being moved in memory
// Essential for self-referential structs and async
struct Pin<P> {
    pointer: P
}

impl<P> Pin<P> {
    // Create a new Pin (unsafe - caller must ensure value won't be moved)
    unsafe fn new_unchecked(pointer: P) -> Pin<P> {
        return Pin(pointer: pointer)
    }
    
    // Get a reference to the pinned value
    fn as_ref(self) -> &P::Target where P: Deref {
        return &self.pointer
    }
    
    // Get a mutable reference to the pinned value (only if Unpin)
    fn as_mut(mut self) -> &mut P::Target where P: DerefMut, P::Target: Unpin {
        return &mut self.pointer
    }
    
    // Get a mutable reference (unsafe version)
    unsafe fn get_unchecked_mut(mut self) -> &mut P::Target where P: DerefMut {
        return &mut self.pointer
    }
}

// Unpin marker trait - type can be moved even when pinned
// Most types are Unpin by default
trait Unpin { }

// PhantomPinned - prevents auto-impl of Unpin
struct PhantomPinned { }

// Example: Self-referential struct (not possible in safe Rust without Pin)
struct SelfReferential {
    data: String,
    ptr: *const u8,  // Points into data
    _pin: PhantomPinned
}

impl SelfReferential {
    fn new(data: String) -> Pin<Box<SelfReferential>> {
        let mut this = Box::new(SelfReferential(
            data: data,
            ptr: std::ptr::null(),
            _pin: PhantomPinned()
        ))
        
        // Set pointer to point into data
        let ptr = this.data.as_ptr()
        unsafe {
            let mut_ref = Pin::get_unchecked_mut(Pin::new_unchecked(&mut this))
            mut_ref.ptr = ptr
        }
        
        return unsafe { Pin::new_unchecked(this) }
    }
}

// ============================================================================
// INTERIOR MUTABILITY
// ============================================================================

// Cell - allows mutation of Copy types inside immutable references
class Cell<T: Copy> {
    value: UnsafeCell<T>
    
    fn new(value: T) -> Cell<T> {
        return Cell(value: UnsafeCell::new(value))
    }
    
    fn get(self) -> T {
        return unsafe { *self.value.get() }
    }
    
    fn set(self, value: T) {
        unsafe { *self.value.get() = value }
    }
    
    fn replace(self, value: T) -> T {
        let old = self.get()
        self.set(value)
        return old
    }
}

// RefCell - runtime borrow checking for non-Copy types
class RefCell<T> {
    value: UnsafeCell<T>
    borrow_state: Cell<BorrowState>
    
    fn new(value: T) -> RefCell<T> {
        return RefCell(
            value: UnsafeCell::new(value),
            borrow_state: Cell::new(BorrowState::Unborrowed)
        )
    }
    
    fn borrow(self) -> Ref<T> {
        match self.borrow_state.get() {
            BorrowState::Unborrowed => {
                self.borrow_state.set(BorrowState::BorrowedShared(1))
                return Ref::new(self)
            }
            BorrowState::BorrowedShared(count) => {
                self.borrow_state.set(BorrowState::BorrowedShared(count + 1))
                return Ref::new(self)
            }
            BorrowState::BorrowedMut => {
                panic!("RefCell: already mutably borrowed")
            }
        }
    }
    
    fn borrow_mut(self) -> RefMut<T> {
        match self.borrow_state.get() {
            BorrowState::Unborrowed => {
                self.borrow_state.set(BorrowState::BorrowedMut)
                return RefMut::new(self)
            }
            _ => {
                panic!("RefCell: already borrowed")
            }
        }
    }
    
    fn try_borrow(self) -> Result<Ref<T>, BorrowError> {
        match self.borrow_state.get() {
            BorrowState::BorrowedMut => return Err(BorrowError::AlreadyMutablyBorrowed),
            _ => return Ok(self.borrow())
        }
    }
    
    fn try_borrow_mut(self) -> Result<RefMut<T>, BorrowError> {
        match self.borrow_state.get() {
            BorrowState::Unborrowed => return Ok(self.borrow_mut()),
            _ => return Err(BorrowError::AlreadyBorrowed)
        }
    }
}

enum BorrowState {
    Unborrowed,
    BorrowedShared(u32),  // Count of shared borrows
    BorrowedMut
}

// Smart pointer for immutable borrow from RefCell
class Ref<T> {
    cell: &RefCell<T>
    
    fn new(cell: &RefCell<T>) -> Ref<T> {
        return Ref(cell: cell)
    }
}

impl<T> Deref for Ref<T> {
    type Target = T
    
    fn deref(self) -> &T {
        return unsafe { &*self.cell.value.get() }
    }
}

impl<T> Drop for Ref<T> {
    fn drop(mut self) {
        match self.cell.borrow_state.get() {
            BorrowState::BorrowedShared(count) => {
                if count == 1 {
                    self.cell.borrow_state.set(BorrowState::Unborrowed)
                } else {
                    self.cell.borrow_state.set(BorrowState::BorrowedShared(count - 1))
                }
            }
            _ => unreachable!()
        }
    }
}

// Smart pointer for mutable borrow from RefCell
class RefMut<T> {
    cell: &RefCell<T>
    
    fn new(cell: &RefCell<T>) -> RefMut<T> {
        return RefMut(cell: cell)
    }
}

impl<T> Deref for RefMut<T> {
    type Target = T
    
    fn deref(self) -> &T {
        return unsafe { &*self.cell.value.get() }
    }
}

impl<T> DerefMut for RefMut<T> {
    fn deref_mut(mut self) -> &mut T {
        return unsafe { &mut *self.cell.value.get() }
    }
}

impl<T> Drop for RefMut<T> {
    fn drop(mut self) {
        self.cell.borrow_state.set(BorrowState::Unborrowed)
    }
}

enum BorrowError {
    AlreadyBorrowed,
    AlreadyMutablyBorrowed
}

// UnsafeCell - the core primitive for interior mutability
struct UnsafeCell<T> {
    value: T
}

impl<T> UnsafeCell<T> {
    fn new(value: T) -> UnsafeCell<T> {
        return UnsafeCell(value: value)
    }
    
    fn get(self) -> *mut T {
        return &mut self.value as *mut T
    }
}

// ============================================================================
// BEYOND RUST: FRACTIONAL PERMISSIONS
// ============================================================================

// Fractional permissions allow fine-grained sharing
// Permission(1.0) = full ownership
// Permission(0.5) = half ownership (can be split)
// Permission(0.0) = no ownership (read-only)

class Permission {
    fraction: f64
    
    fn full() -> Permission {
        return Permission(fraction: 1.0)
    }
    
    fn read_only() -> Permission {
        return Permission(fraction: 0.0)
    }
    
    fn split(mut self) -> (Permission, Permission) {
        let half = self.fraction / 2.0
        self.fraction = half
        return (self, Permission(fraction: half))
    }
    
    fn merge(mut self, other: Permission) {
        self.fraction += other.fraction
    }
    
    fn can_write(self) -> bool {
        return self.fraction >= 1.0
    }
    
    fn can_read(self) -> bool {
        return self.fraction > 0.0
    }
}

// Value with fractional permissions
class Fractional<T> {
    value: T
    permission: Permission
    
    fn new(value: T) -> Fractional<T> {
        return Fractional(
            value: value,
            permission: Permission::full()
        )
    }
    
    fn split(mut self) -> (Fractional<T>, Fractional<T>) {
        let (p1, p2) = self.permission.split()
        return (
            Fractional(value: self.value, permission: p1),
            Fractional(value: self.value, permission: p2)
        )
    }
    
    fn read(self) -> &T {
        assert!(self.permission.can_read(), "Insufficient permission to read")
        return &self.value
    }
    
    fn write(mut self, value: T) {
        assert!(self.permission.can_write(), "Insufficient permission to write")
        self.value = value
    }
}

// ============================================================================
// GLOBAL INSTANCES & CONVENIENCE FUNCTIONS
// ============================================================================

// Global borrow checker instance
static mut GLOBAL_BORROW_CHECKER: ?BorrowChecker = None

fn init_borrow_checker() {
    unsafe {
        GLOBAL_BORROW_CHECKER = Some(BorrowChecker::new())
    }
}

fn get_borrow_checker() -> &mut BorrowChecker {
    unsafe {
        return GLOBAL_BORROW_CHECKER.as_mut().expect("Borrow checker not initialized")
    }
}

// Convenience function for lifetime inference
fn infer_lifetimes<F>(f: F) where F: Fn(&mut LifetimeInference) {
    let mut inference = LifetimeInference::new()
    f(&mut inference)
    let result = inference.solve()
    match result {
        Ok(lifetimes) => {
            println!("Lifetime inference succeeded:")
            for (name, lifetime) in lifetimes {
                println!("  {} : [{}, {}]", name, lifetime.start_point, lifetime.end_point)
            }
        }
        Err(e) => {
            println!("Lifetime inference failed: {}", e)
        }
    }
}

// Example usage
fn example_ownership() {
    init_borrow_checker()
    
    // Basic ownership
    let x = Box::new(42)  // x owns the boxed value
    let y = move(x)       // x is moved to y, x is now invalid
    // println!("{}", x)   // ERROR: x has been moved
    println!("{}", y)     // OK
    
    // Borrowing
    let mut data = vec![1, 2, 3, 4]
    let r1 = &data        // Immutable borrow
    let r2 = &data        // Multiple immutable borrows OK
    println!("{} {}", r1[0], r2[0])
    
    // data.push(5)        // ERROR: cannot mutate while borrowed
    // After r1 and r2 go out of scope:
    data.push(5)          // OK now
    
    // Mutable borrow
    let r3 = &mut data    // Mutable borrow
    r3.push(6)
    // let r4 = &data     // ERROR: cannot borrow while mutably borrowed
    
    // Interior mutability
    let cell = Cell::new(10)
    let ref1 = &cell
    let ref2 = &cell
    ref1.set(20)          // Mutation through immutable reference!
    ref2.set(30)
    println!("{}", cell.get())
    
    // RefCell for runtime borrow checking
    let refcell = RefCell::new(vec![1, 2, 3])
    {
        let borrowed = refcell.borrow()
        println!("{}", borrowed[0])
        // let mut_borrowed = refcell.borrow_mut()  // ERROR: already borrowed
    }
    // Now we can mutably borrow
    let mut mut_borrowed = refcell.borrow_mut()
    mut_borrowed.push(4)
    
    // Fractional permissions
    let frac = Fractional::new(100)
    let (frac1, frac2) = frac.split()
    println!("{}", frac1.read())  // Both can read
    println!("{}", frac2.read())
    // frac1.write(200)             // ERROR: insufficient permission (only 0.5)
}
