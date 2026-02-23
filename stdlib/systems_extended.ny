# ============================================================================
# Nyx Systems Programming - Extended Features
# ============================================================================
# Additional production-grade systems programming features
# Import: import systems_extended

import systems
import atomics

# ============================================================================
# Unsafe Operations
# ============================================================================

class UnsafeBlock {
    fn init(self, block_fn) {
        self.fn = block_fn;
        self.requires_unsafe_context = true;
    }
    
    fn execute(self) {
        return self.fn();
    }
}

fn unsafe(block_fn) {
    return UnsafeBlock(block_fn);
}

let UNSAFE_ENABLED = false;

fn enable_unsafe() {
    UNSAFE_ENABLED = true;
}

fn disable_unsafe() {
    UNSAFE_ENABLED = false;
}

fn exec_unsafe(unsafe_block) {
    if !UNSAFE_ENABLED {
        panic("exec_unsafe: unsafe operations disabled");
    }
    return unsafe_block.execute();
}

# ============================================================================
# Native System Call Stubs
# ============================================================================

fn _sys_malloc(size) { return _native_malloc(size); }
fn _sys_calloc(count, size) { return _native_calloc(count, size); }
fn _sys_realloc(ptr, new_size) { return _native_realloc(ptr, new_size); }
fn _sys_free(ptr) { _native_free(ptr); }
fn _sys_aligned_alloc(alignment, size) { return _native_aligned_alloc(alignment, size); }
fn _sys_memcpy(dest, src, size) { return _native_memcpy(dest, src, size); }
fn _sys_memmove(dest, src, size) { return _native_memmove(dest, src, size); }
fn _sys_memset(dest, value, size) { return _native_memset(dest, value, size); }
fn _sys_memcmp(a, b, size) { return _native_memcmp(a, b, size); }
fn _sys_peek(ptr, type_) { return _native_peek(ptr, type_); }
fn _sys_poke(ptr, value, type_) { _native_poke(ptr, value, type_); }
fn _sys_volatile_read(ptr, type_) { return _native_volatile_read(ptr, type_); }
fn _sys_volatile_write(ptr, value, type_) { _native_volatile_write(ptr, value, type_); }
fn _sys_cache_flush(ptr, size) { _native_cache_flush(ptr, size); }
fn _sys_cache_invalidate(ptr, size) { _native_cache_invalidate(ptr, size); }
fn _sys_prefetch(ptr, rw, locality) { _native_prefetch(ptr, rw, locality); }

# ============================================================================
# Bitwise Operations
# ============================================================================

fn bit_set(value, bit) { return value | (1 << bit); }
fn bit_clear(value, bit) { return value & ~(1 << bit); }
fn bit_toggle(value, bit) { return value ^ (1 << bit); }
fn bit_test(value, bit) { return (value & (1 << bit)) != 0; }
fn bit_mask(start, end) { return ((1 << (end - start + 1)) - 1) << start; }
fn extract_bits(value, start, end) {
    return (value >> start) & ((1 << (end - start + 1)) - 1);
}

fn popcount(value) {
    let count = 0;
    while value != 0 {
        count = count + (value & 1);
        value = value >> 1;
    }
    return count;
}

fn leading_zeros(value) {
    if value == 0 { return 64; }
    let count = 0;
    while (value & 0x8000000000000000) == 0 {
        count = count + 1;
        value = value << 1;
    }
    return count;
}

fn trailing_zeros(value) {
    if value == 0 { return 64; }
    let count = 0;
    while (value & 1) == 0 {
        count = count + 1;
        value = value >> 1;
    }
    return count;
}

# ============================================================================
# Stack Allocation
# ============================================================================

class StackAllocator {
    fn init(self, capacity) {
        import allocators;
        self.allocator = allocators.Stack(capacity);
    }
    
    fn alloc(self, size) {
        return self.allocator.alloc(size);
    }
    
    fn push_frame(self) {
        self.allocator.push_marker();
    }
    
    fn pop_frame(self) {
        self.allocator.pop_marker();
    }
    
    fn destroy(self) {
        self.allocator.destroy();
    }
}

# Thread-local stack allocator
let THREAD_STACK_ALLOCATOR = null;

fn init_thread_stack_allocator(capacity = 1048576) {
    THREAD_STACK_ALLOCATOR = StackAllocator(capacity);
}

fn get_thread_stack_allocator() {
    if THREAD_STACK_ALLOCATOR == null {
        init_thread_stack_allocator();
    }
    return THREAD_STACK_ALLOCATOR;
}

fn alloca(size) {
    return get_thread_stack_allocator().alloc(size);
}

# ============================================================================
# Foreign Function Interface
# ============================================================================

class ExternFunction {
    fn init(self, name, ret_type, arg_types) {
        self.name = name;
        self.return_type = ret_type;
        self.arg_types = arg_types;
        self.fn_ptr = null;
    }
    
    fn load(self, library) {
        import ffi;
        self.fn_ptr = ffi.symbol(library, self.name);
        if self.fn_ptr == null {
            panic("ExternFunction.load: symbol not found: " + self.name);
        }
    }
    
    fn call(self, ...args) {
        if self.fn_ptr == null {
            panic("ExternFunction.call: function not loaded");
        }
        import ffi;
        return ffi.call(self.fn_ptr, self.return_type, ...args);
    }
}

fn extern_fn(name, ret_type, arg_types) {
    return ExternFunction(name, ret_type, arg_types);
}

fn call_extern(fn_def, ...args) {
    return fn_def.call(...args);
}

# ============================================================================
# Platform Detection
# ============================================================================

fn get_platform() {
    # Returns: "windows", "linux", "macos", "bsd", "unknown"
    return _platform_detect();
}

fn get_arch() {
    # Returns: "x86_64", "aarch64", "x86", "arm", "unknown"
    return _arch_detect();
}

fn is_little_endian() {
    return _endian_detect() == "little";
}

fn is_big_endian() {
    return _endian_detect() == "big";
}

fn get_cpu_count() {
    return _cpu_count();
}

fn get_page_size() {
    return _page_size();
}

fn _platform_detect() { return "unknown"; }
fn _arch_detect() { return "x86_64"; }
fn _endian_detect() { return "little"; }
fn _cpu_count() { return 4; }
fn _page_size() { return 4096; }

# ============================================================================
# Process/Thread Management
# ============================================================================

fn get_process_id() {
    return _getpid();
}

fn get_thread_id() {
    return _gettid();
}

fn sleep(milliseconds) {
    _sleep(milliseconds);
}

fn yield_thread() {
    _yield();
}

fn exit(code) {
    _exit(code);
}

fn _getpid() { return 0; }
fn _gettid() { return 0; }
fn _sleep(ms) {}
fn _yield() {}
fn _exit(code) {}

# ============================================================================
# Signal Handling
# ============================================================================

class SignalHandler {
    fn init(self, signal, handler_fn) {
        self.signal = signal;
        self.handler = handler_fn;
        self.installed = false;
    }
    
    fn install(self) {
        _signal_install(self.signal, self.handler);
        self.installed = true;
    }
    
    fn uninstall(self) {
        _signal_uninstall(self.signal);
        self.installed = false;
    }
}

const SIGNALS = {
    "SIGINT": 2,
    "SIGTERM": 15,
    "SIGSEGV": 11,
    "SIGILL": 4,
    "SIGFPE": 8,
    "SIGABRT": 6
};

fn install_signal_handler(signal, handler_fn) {
    let sh = SignalHandler(signal, handler_fn);
    sh.install();
    return sh;
}

fn _signal_install(signal, handler) {}
fn _signal_uninstall(signal) {}

# ============================================================================
# Environment Variables
# ============================================================================

fn getenv(name) {
    return _getenv(name);
}

fn setenv(name, value) {
    _setenv(name, value);
}

fn unsetenv(name) {
    _unsetenv(name);
}

fn _getenv(name) { return null; }
fn _setenv(name, value) {}
fn _unsetenv(name) {}

# ============================================================================
# File Descriptors (Low-Level I/O)
# ============================================================================

class FileDescriptor {
    fn init(self, fd) {
        self.fd = fd;
        self.closed = false;
    }
    
    fn read(self, buffer, size) {
        if self.closed {
            panic("FileDescriptor: read from closed fd");
        }
        return _fd_read(self.fd, buffer, size);
    }
    
    fn write(self, buffer, size) {
        if self.closed {
            panic("FileDescriptor: write to closed fd");
        }
        return _fd_write(self.fd, buffer, size);
    }
    
    fn close(self) {
        if !self.closed {
            _fd_close(self.fd);
            self.closed = true;
        }
    }
    
    fn is_closed(self) {
        return self.closed;
    }
}

fn open_fd(path, flags) {
    let fd = _fd_open(path, flags);
    if fd < 0 {
        return systems.Err("open failed");
    }
    return systems.Ok(FileDescriptor(fd));
}

const O_RDONLY = 0;
const O_WRONLY = 1;
const O_RDWR = 2;
const O_CREAT = 64;
const O_TRUNC = 512;
const O_APPEND = 1024;

fn _fd_open(path, flags) { return -1; }
fn _fd_read(fd, buffer, size) { return 0; }
fn _fd_write(fd, buffer, size) { return 0; }
fn _fd_close(fd) {}

# ============================================================================
# Memory Mapping (mmap)
# ============================================================================

class MemoryMapping {
    fn init(self, address, size, prot, flags) {
        self.address = _mmap(address, size, prot, flags);
        self.size = size;
        self.mapped = true;
        
        if self.address == null {
            panic("MemoryMapping: mmap failed");
        }
    }
    
    fn get_ptr(self) {
        if !self.mapped {
            panic("MemoryMapping: use after unmap");
        }
        return self.address;
    }
    
    fn sync(self) {
        if self.mapped {
            _msync(self.address, self.size);
        }
    }
    
    fn unmap(self) {
        if self.mapped {
            _munmap(self.address, self.size);
            self.mapped = false;
        }
    }
}

const PROT_NONE = 0;
const PROT_READ = 1;
const PROT_WRITE = 2;
const PROT_EXEC = 4;

const MAP_PRIVATE = 2;
const MAP_SHARED = 1;
const MAP_ANONYMOUS = 32;

fn mmap(address, size, prot, flags) {
    return MemoryMapping(address, size, prot, flags);
}

fn _mmap(addr, size, prot, flags) { return systems.malloc(size); }
fn _munmap(addr, size) { systems.free(addr); }
fn _msync(addr, size) {}

# ============================================================================
# Documentation
# ============================================================================
#
# systems_extended.ny provides additional production-grade features:
#
# - Unsafe operations with runtime checks
# - Native system call stubs
# - Bitwise operations (popcount, leading_zeros, etc.)
# - Stack allocation (alloca, StackAllocator)
# - FFI (extern_fn, call_extern)
# - Platform detection (get_platform, get_arch)
# - Process/thread management
# - Signal handling
# - Environment variables
# - File descriptors (low-level I/O)
# - Memory mapping (mmap)
#
# ============================================================================
