// ═══════════════════════════════════════════════════════════════════════════
// NySys - System Control Engine
// ═══════════════════════════════════════════════════════════════════════════
// Purpose: Low-level OS and memory control for security tooling
// Score: 10/10 (If you don't control the OS and memory, you lose)
// ═══════════════════════════════════════════════════════════════════════════

use std::ffi::c_void;
use std::ptr;

// ═══════════════════════════════════════════════════════════════════════════
// Section 1: Direct Memory Access
// ═══════════════════════════════════════════════════════════════════════════

pub struct MemoryRegion {
    pub address: usize,
    pub size: usize,
    pub permissions: MemoryPermissions,
}

#[derive(Clone, Copy, Debug)]
pub struct MemoryPermissions {
    pub read: bool,
    pub write: bool,
    pub execute: bool,
}

pub struct MemoryManager;

impl MemoryManager {
    // Allocate raw memory
    pub unsafe fn allocate(size: usize, permissions: MemoryPermissions) -> *mut u8 {
        #[cfg(target_os = "windows")]
        {
            use winapi::um::memoryapi::VirtualAlloc;
            use winapi::um::winnt::{MEM_COMMIT, MEM_RESERVE, PAGE_EXECUTE_READWRITE};
            
            VirtualAlloc(
                ptr::null_mut(),
                size,
                MEM_COMMIT | MEM_RESERVE,
                PAGE_EXECUTE_READWRITE,
            ) as *mut u8
        }
        
        #[cfg(target_os = "linux")]
        {
            use libc::{mmap, MAP_ANONYMOUS, MAP_PRIVATE, PROT_READ, PROT_WRITE, PROT_EXEC};
            
            let prot = if permissions.read { PROT_READ } else { 0 }
                     | if permissions.write { PROT_WRITE } else { 0 }
                     | if permissions.execute { PROT_EXEC } else { 0 };
            
            mmap(
                ptr::null_mut(),
                size,
                prot,
                MAP_PRIVATE | MAP_ANONYMOUS,
                -1,
                0,
            ) as *mut u8
        }
        
        #[cfg(target_os = "macos")]
        {
            use libc::{mmap, MAP_ANON, MAP_PRIVATE, PROT_READ, PROT_WRITE, PROT_EXEC};
            
            let prot = if permissions.read { PROT_READ } else { 0 }
                     | if permissions.write { PROT_WRITE } else { 0 }
                     | if permissions.execute { PROT_EXEC } else { 0 };
            
            mmap(
                ptr::null_mut(),
                size,
                prot,
                MAP_PRIVATE | MAP_ANON,
                -1,
                0,
            ) as *mut u8
        }
    }
    
    // Free memory
    pub unsafe fn free(address: *mut u8, size: usize) {
        #[cfg(target_os = "windows")]
        {
            use winapi::um::memoryapi::VirtualFree;
            use winapi::um::winnt::MEM_RELEASE;
            VirtualFree(address as *mut c_void, 0, MEM_RELEASE);
        }
        
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            use libc::munmap;
            munmap(address as *mut c_void, size);
        }
    }
    
    // Change memory protection
    pub unsafe fn protect(address: *mut u8, size: usize, permissions: MemoryPermissions) -> bool {
        #[cfg(target_os = "windows")]
        {
            use winapi::um::memoryapi::VirtualProtect;
            use winapi::um::winnt::PAGE_EXECUTE_READWRITE;
            
            let mut old_protect = 0;
            VirtualProtect(
                address as *mut c_void,
                size,
                PAGE_EXECUTE_READWRITE,
                &mut old_protect,
            ) != 0
        }
        
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            use libc::{mprotect, PROT_READ, PROT_WRITE, PROT_EXEC};
            
            let prot = if permissions.read { PROT_READ } else { 0 }
                     | if permissions.write { PROT_WRITE } else { 0 }
                     | if permissions.execute { PROT_EXEC } else { 0 };
            
            mprotect(address as *mut c_void, size, prot) == 0
        }
    }
    
    // Read process memory (cross-process)
    pub unsafe fn read_process_memory(
        pid: u32,
        address: usize,
        buffer: &mut [u8],
    ) -> Result<usize, String> {
        #[cfg(target_os = "windows")]
        {
            use winapi::um::processthreadsapi::OpenProcess;
            use winapi::um::memoryapi::ReadProcessMemory;
            use winapi::um::winnt::PROCESS_VM_READ;
            
            let handle = OpenProcess(PROCESS_VM_READ, 0, pid);
            if handle.is_null() {
                return Err("Failed to open process".to_string());
            }
            
            let mut bytes_read = 0;
            let success = ReadProcessMemory(
                handle,
                address as *const c_void,
                buffer.as_mut_ptr() as *mut c_void,
                buffer.len(),
                &mut bytes_read,
            );
            
            if success != 0 {
                Ok(bytes_read)
            } else {
                Err("ReadProcessMemory failed".to_string())
            }
        }
        
        #[cfg(target_os = "linux")]
        {
            use std::fs::File;
            use std::io::{Read, Seek, SeekFrom};
            
            let mem_path = format!("/proc/{}/mem", pid);
            let mut file = File::open(mem_path).map_err(|e| e.to_string())?;
            file.seek(SeekFrom::Start(address as u64)).map_err(|e| e.to_string())?;
            file.read(buffer).map_err(|e| e.to_string())
        }
        
        #[cfg(target_os = "macos")]
        {
            // macOS requires vm_read_overwrite
            Err("Not implemented for macOS".to_string())
        }
    }
    
    // Write process memory
    pub unsafe fn write_process_memory(
        pid: u32,
        address: usize,
        data: &[u8],
    ) -> Result<usize, String> {
        #[cfg(target_os = "windows")]
        {
            use winapi::um::processthreadsapi::OpenProcess;
            use winapi::um::memoryapi::WriteProcessMemory;
            use winapi::um::winnt::PROCESS_VM_WRITE;
            
            let handle = OpenProcess(PROCESS_VM_WRITE, 0, pid);
            if handle.is_null() {
                return Err("Failed to open process".to_string());
            }
            
            let mut bytes_written = 0;
            let success = WriteProcessMemory(
                handle,
                address as *mut c_void,
                data.as_ptr() as *const c_void,
                data.len(),
                &mut bytes_written,
            );
            
            if success != 0 {
                Ok(bytes_written)
            } else {
                Err("WriteProcessMemory failed".to_string())
            }
        }
        
        #[cfg(target_os = "linux")]
        {
            use std::fs::OpenOptions;
            use std::io::{Write, Seek, SeekFrom};
            
            let mem_path = format!("/proc/{}/mem", pid);
            let mut file = OpenOptions::new()
                .write(true)
                .open(mem_path)
                .map_err(|e| e.to_string())?;
            file.seek(SeekFrom::Start(address as u64)).map_err(|e| e.to_string())?;
            file.write(data).map_err(|e| e.to_string())
        }
        
        #[cfg(target_os = "macos")]
        {
            Err("Not implemented for macOS".to_string())
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section 2: Pointer Manipulation
// ═══════════════════════════════════════════════════════════════════════════

pub struct Pointer<T> {
    address: *mut T,
}

impl<T> Pointer<T> {
    pub unsafe fn new(address: usize) -> Self {
        Self {
            address: address as *mut T,
        }
    }
    
    pub fn from_raw(ptr: *mut T) -> Self {
        Self { address: ptr }
    }
    
    pub fn address(&self) -> usize {
        self.address as usize
    }
    
    pub unsafe fn read(&self) -> T {
        ptr::read(self.address)
    }
    
    pub unsafe fn write(&mut self, value: T) {
        ptr::write(self.address, value);
    }
    
    pub unsafe fn offset(&self, count: isize) -> Self {
        Self {
            address: self.address.offset(count),
        }
    }
    
    pub unsafe fn deref(&self) -> &T {
        &*self.address
    }
    
    pub unsafe fn deref_mut(&mut self) -> &mut T {
        &mut *self.address
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section 3: Process Injection APIs
// ═══════════════════════════════════════════════════════════════════════════

pub struct ProcessInjector;

impl ProcessInjector {
    // DLL Injection (Windows)
    #[cfg(target_os = "windows")]
    pub unsafe fn inject_dll(pid: u32, dll_path: &str) -> Result<(), String> {
        use winapi::um::processthreadsapi::{OpenProcess, CreateRemoteThread};
        use winapi::um::memoryapi::{VirtualAllocEx, WriteProcessMemory};
        use winapi::um::libloaderapi::{GetModuleHandleA, GetProcAddress};
        use winapi::um::winnt::{PROCESS_ALL_ACCESS, MEM_COMMIT, PAGE_READWRITE};
        use std::ffi::CString;
        
        // Open target process
        let handle = OpenProcess(PROCESS_ALL_ACCESS, 0, pid);
        if handle.is_null() {
            return Err("Failed to open process".to_string());
        }
        
        // Allocate memory in target process
        let dll_path_cstr = CString::new(dll_path).unwrap();
        let dll_path_len = dll_path_cstr.as_bytes_with_nul().len();
        
        let remote_string = VirtualAllocEx(
            handle,
            ptr::null_mut(),
            dll_path_len,
            MEM_COMMIT,
            PAGE_READWRITE,
        );
        
        if remote_string.is_null() {
            return Err("VirtualAllocEx failed".to_string());
        }
        
        // Write DLL path to target process
        let mut bytes_written = 0;
        WriteProcessMemory(
            handle,
            remote_string,
            dll_path_cstr.as_ptr() as *const c_void,
            dll_path_len,
            &mut bytes_written,
        );
        
        // Get LoadLibraryA address
        let kernel32 = GetModuleHandleA(b"kernel32.dll\0".as_ptr() as *const i8);
        let load_library = GetProcAddress(kernel32, b"LoadLibraryA\0".as_ptr() as *const i8);
        
        // Create remote thread to call LoadLibraryA
        CreateRemoteThread(
            handle,
            ptr::null_mut(),
            0,
            Some(std::mem::transmute(load_library)),
            remote_string,
            0,
            ptr::null_mut(),
        );
        
        Ok(())
    }
    
    // Shellcode Injection
    pub unsafe fn inject_shellcode(pid: u32, shellcode: &[u8]) -> Result<(), String> {
        #[cfg(target_os = "windows")]
        {
            use winapi::um::processthreadsapi::{OpenProcess, CreateRemoteThread};
            use winapi::um::memoryapi::VirtualAllocEx;
            use winapi::um::winnt::{PROCESS_ALL_ACCESS, MEM_COMMIT, PAGE_EXECUTE_READWRITE};
            
            let handle = OpenProcess(PROCESS_ALL_ACCESS, 0, pid);
            if handle.is_null() {
                return Err("Failed to open process".to_string());
            }
            
            // Allocate executable memory
            let remote_mem = VirtualAllocEx(
                handle,
                ptr::null_mut(),
                shellcode.len(),
                MEM_COMMIT,
                PAGE_EXECUTE_READWRITE,
            );
            
            if remote_mem.is_null() {
                return Err("VirtualAllocEx failed".to_string());
            }
            
            // Write shellcode
            MemoryManager::write_process_memory(pid, remote_mem as usize, shellcode)?;
            
            // Execute via remote thread
            CreateRemoteThread(
                handle,
                ptr::null_mut(),
                0,
                Some(std::mem::transmute(remote_mem)),
                ptr::null_mut(),
                0,
                ptr::null_mut(),
            );
            
            Ok(())
        }
        
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            // Linux/macOS: use ptrace
            Err("Not implemented for Linux/macOS".to_string())
        }
    }
    
    // Process Hollowing
    #[cfg(target_os = "windows")]
    pub unsafe fn process_hollow(
        target_path: &str,
        payload: &[u8],
    ) -> Result<u32, String> {
        // Create suspended process
        // Unmap original executable
        // Write malicious code
        // Resume thread
        Err("Process hollowing not fully implemented".to_string())
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section 4: Thread Control
// ═══════════════════════════════════════════════════════════════════════════

pub struct ThreadController;

impl ThreadController {
    // Enumerate threads
    pub fn enumerate_threads(pid: u32) -> Vec<u32> {
        let mut threads = Vec::new();
        
        #[cfg(target_os = "windows")]
        {
            use winapi::um::tlhelp32::{
                CreateToolhelp32Snapshot, Thread32First, Thread32Next,
                THREADENTRY32, TH32CS_SNAPTHREAD,
            };
            
            unsafe {
                let snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
                let mut te32 = THREADENTRY32 {
                    dwSize: std::mem::size_of::<THREADENTRY32>() as u32,
                    cntUsage: 0,
                    th32ThreadID: 0,
                    th32OwnerProcessID: 0,
                    tpBasePri: 0,
                    tpDeltaPri: 0,
                    dwFlags: 0,
                };
                
                if Thread32First(snapshot, &mut te32) != 0 {
                    loop {
                        if te32.th32OwnerProcessID == pid {
                            threads.push(te32.th32ThreadID);
                        }
                        if Thread32Next(snapshot, &mut te32) == 0 {
                            break;
                        }
                    }
                }
            }
        }
        
        #[cfg(target_os = "linux")]
        {
            use std::fs;
            let task_dir = format!("/proc/{}/task", pid);
            if let Ok(entries) = fs::read_dir(task_dir) {
                for entry in entries.flatten() {
                    if let Ok(tid) = entry.file_name().to_string_lossy().parse::<u32>() {
                        threads.push(tid);
                    }
                }
            }
        }
        
        threads
    }
    
    // Suspend thread
    pub fn suspend_thread(tid: u32) -> Result<(), String> {
        #[cfg(target_os = "windows")]
        {
            use winapi::um::processthreadsapi::{OpenThread, SuspendThread};
            use winapi::um::winnt::THREAD_SUSPEND_RESUME;
            
            unsafe {
                let handle = OpenThread(THREAD_SUSPEND_RESUME, 0, tid);
                if handle.is_null() {
                    return Err("Failed to open thread".to_string());
                }
                SuspendThread(handle);
                Ok(())
            }
        }
        
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            Err("Not implemented for Linux/macOS".to_string())
        }
    }
    
    // Resume thread
    pub fn resume_thread(tid: u32) -> Result<(), String> {
        #[cfg(target_os = "windows")]
        {
            use winapi::um::processthreadsapi::{OpenThread, ResumeThread};
            use winapi::um::winnt::THREAD_SUSPEND_RESUME;
            
            unsafe {
                let handle = OpenThread(THREAD_SUSPEND_RESUME, 0, tid);
                if handle.is_null() {
                    return Err("Failed to open thread".to_string());
                }
                ResumeThread(handle);
                Ok(())
            }
        }
        
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            Err("Not implemented for Linux/macOS".to_string())
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section 5: File Descriptor Management
// ═══════════════════════════════════════════════════════════════════════════

pub struct FileDescriptorManager;

impl FileDescriptorManager {
    // List open file descriptors
    pub fn list_fds(pid: u32) -> Vec<i32> {
        let mut fds = Vec::new();
        
        #[cfg(target_os = "linux")]
        {
            use std::fs;
            let fd_dir = format!("/proc/{}/fd", pid);
            if let Ok(entries) = fs::read_dir(fd_dir) {
                for entry in entries.flatten() {
                    if let Ok(fd) = entry.file_name().to_string_lossy().parse::<i32>() {
                        fds.push(fd);
                    }
                }
            }
        }
        
        fds
    }
    
    // Duplicate file descriptor
    #[cfg(any(target_os = "linux", target_os = "macos"))]
    pub fn duplicate_fd(fd: i32) -> Result<i32, String> {
        use libc::dup;
        
        unsafe {
            let new_fd = dup(fd);
            if new_fd == -1 {
                Err("dup failed".to_string())
            } else {
                Ok(new_fd)
            }
        }
    }
    
    // Close file descriptor
    pub fn close_fd(fd: i32) -> Result<(), String> {
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            use libc::close;
            unsafe {
                if close(fd) == 0 {
                    Ok(())
                } else {
                    Err("close failed".to_string())
                }
            }
        }
        
        #[cfg(target_os = "windows")]
        {
            use winapi::um::handleapi::CloseHandle;
            unsafe {
                CloseHandle(fd as *mut c_void);
                Ok(())
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section 6: Raw Socket Access
// ═══════════════════════════════════════════════════════════════════════════

pub struct RawSocket {
    fd: i32,
}

impl RawSocket {
    // Create raw socket
    pub fn new(protocol: SocketProtocol) -> Result<Self, String> {
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            use libc::{socket, AF_INET, SOCK_RAW, IPPROTO_RAW, IPPROTO_TCP, IPPROTO_UDP};
            
            let proto = match protocol {
                SocketProtocol::Raw => IPPROTO_RAW,
                SocketProtocol::TCP => IPPROTO_TCP,
                SocketProtocol::UDP => IPPROTO_UDP,
                SocketProtocol::ICMP => 1, // IPPROTO_ICMP
            };
            
            unsafe {
                let fd = socket(AF_INET, SOCK_RAW, proto);
                if fd == -1 {
                    Err("Failed to create raw socket".to_string())
                } else {
                    Ok(Self { fd })
                }
            }
        }
        
        #[cfg(target_os = "windows")]
        {
            Err("Raw socket creation on Windows requires WinSock".to_string())
        }
    }
    
    // Send raw packet
    pub fn send(&self, packet: &[u8], dest_addr: &str, dest_port: u16) -> Result<usize, String> {
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            use libc::{sendto, sockaddr_in, AF_INET};
            use std::net::IpAddr;
            
            let ip: IpAddr = dest_addr.parse().map_err(|e| format!("Invalid IP: {}", e))?;
            
            unsafe {
                let addr = sockaddr_in {
                    sin_family: AF_INET as u16,
                    sin_port: dest_port.to_be(),
                    sin_addr: match ip {
                        IpAddr::V4(v4) => libc::in_addr {
                            s_addr: u32::from(v4).to_be(),
                        },
                        _ => return Err("Only IPv4 supported".to_string()),
                    },
                    sin_zero: [0; 8],
                };
                
                let sent = sendto(
                    self.fd,
                    packet.as_ptr() as *const c_void,
                    packet.len(),
                    0,
                    &addr as *const sockaddr_in as *const libc::sockaddr,
                    std::mem::size_of::<sockaddr_in>() as u32,
                );
                
                if sent == -1 {
                    Err("sendto failed".to_string())
                } else {
                    Ok(sent as usize)
                }
            }
        }
        
        #[cfg(target_os = "windows")]
        {
            Err("Not implemented for Windows".to_string())
        }
    }
}

pub enum SocketProtocol {
    Raw,
    TCP,
    UDP,
    ICMP,
}

// ═══════════════════════════════════════════════════════════════════════════
// Section 7: Syscall Interface
// ═══════════════════════════════════════════════════════════════════════════

pub struct Syscall;

impl Syscall {
    // Direct syscall (Linux x86_64)
    #[cfg(all(target_os = "linux", target_arch = "x86_64"))]
    pub unsafe fn invoke(
        syscall_number: u64,
        arg1: u64,
        arg2: u64,
        arg3: u64,
        arg4: u64,
        arg5: u64,
        arg6: u64,
    ) -> i64 {
        let result: i64;
        
        asm!(
            "syscall",
            inout("rax") syscall_number => result,
            in("rdi") arg1,
            in("rsi") arg2,
            in("rdx") arg3,
            in("r10") arg4,
            in("r8") arg5,
            in("r9") arg6,
            lateout("rcx") _,
            lateout("r11") _,
        );
        
        result
    }
    
    // Common syscalls
    #[cfg(target_os = "linux")]
    pub unsafe fn sys_open(path: &str, flags: i32, mode: u32) -> Result<i32, String> {
        use std::ffi::CString;
        let path_cstr = CString::new(path).unwrap();
        let fd = Self::invoke(2, path_cstr.as_ptr() as u64, flags as u64, mode as u64, 0, 0, 0);
        
        if fd < 0 {
            Err("sys_open failed".to_string())
        } else {
            Ok(fd as i32)
        }
    }
    
    #[cfg(target_os = "linux")]
    pub unsafe fn sys_read(fd: i32, buffer: &mut [u8]) -> Result<usize, String> {
        let bytes_read = Self::invoke(
            0,
            fd as u64,
            buffer.as_mut_ptr() as u64,
            buffer.len() as u64,
            0,
            0,
            0,
        );
        
        if bytes_read < 0 {
            Err("sys_read failed".to_string())
        } else {
            Ok(bytes_read as usize)
        }
    }
    
    #[cfg(target_os = "linux")]
    pub unsafe fn sys_write(fd: i32, data: &[u8]) -> Result<usize, String> {
        let bytes_written = Self::invoke(
            1,
            fd as u64,
            data.as_ptr() as u64,
            data.len() as u64,
            0,
            0,
            0,
        );
        
        if bytes_written < 0 {
            Err("sys_write failed".to_string())
        } else {
            Ok(bytes_written as usize)
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Section 8: Cross-Platform Abstraction
// ═══════════════════════════════════════════════════════════════════════════

pub struct Platform;

impl Platform {
    pub fn os_name() -> &'static str {
        #[cfg(target_os = "windows")]
        return "Windows";
        
        #[cfg(target_os = "linux")]
        return "Linux";
        
        #[cfg(target_os = "macos")]
        return "macOS";
    }
    
    pub fn arch() -> &'static str {
        #[cfg(target_arch = "x86_64")]
        return "x86_64";
        
        #[cfg(target_arch = "x86")]
        return "x86";
        
        #[cfg(target_arch = "aarch64")]
        return "aarch64";
        
        #[cfg(target_arch = "arm")]
        return "arm";
    }
    
    pub fn page_size() -> usize {
        #[cfg(target_os = "windows")]
        {
            use winapi::um::sysinfoapi::{GetSystemInfo, SYSTEM_INFO};
            unsafe {
                let mut sys_info: SYSTEM_INFO = std::mem::zeroed();
                GetSystemInfo(&mut sys_info);
                sys_info.dwPageSize as usize
            }
        }
        
        #[cfg(any(target_os = "linux", target_os = "macos"))]
        {
            use libc::sysconf;
            unsafe { sysconf(libc::_SC_PAGESIZE) as usize }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Module Exports
// ═══════════════════════════════════════════════════════════════════════════

pub use {
    MemoryRegion,
    MemoryPermissions,
    MemoryManager,
    Pointer,
    ProcessInjector,
    ThreadController,
    FileDescriptorManager,
    RawSocket,
    SocketProtocol,
    Syscall,
    Platform,
};

# ============================================================
# PRODUCTION-READY INFRASTRUCTURE
# ============================================================

pub mod production {

    pub class HealthStatus {
        pub let status: String;
        pub let uptime_ms: Int;
        pub let checks: Map;
        pub let version: String;

        pub fn new() -> Self {
            return Self {
                status: "healthy",
                uptime_ms: 0,
                checks: {},
                version: VERSION
            };
        }

        pub fn is_healthy(self) -> Bool {
            return self.status == "healthy";
        }

        pub fn add_check(self, name: String, passed: Bool, detail: String) {
            self.checks[name] = { "passed": passed, "detail": detail };
            if !passed { self.status = "degraded"; }
        }
    }

    pub class MetricsCollector {
        pub let counters: Map;
        pub let gauges: Map;
        pub let histograms: Map;
        pub let start_time: Int;

        pub fn new() -> Self {
            return Self {
                counters: {},
                gauges: {},
                histograms: {},
                start_time: native_production_time_ms()
            };
        }

        pub fn increment(self, name: String, value: Int) {
            self.counters[name] = (self.counters[name] or 0) + value;
        }

        pub fn gauge_set(self, name: String, value: Float) {
            self.gauges[name] = value;
        }

        pub fn histogram_observe(self, name: String, value: Float) {
            if self.histograms[name] == null { self.histograms[name] = []; }
            self.histograms[name].push(value);
        }

        pub fn snapshot(self) -> Map {
            return {
                "counters": self.counters,
                "gauges": self.gauges,
                "uptime_ms": native_production_time_ms() - self.start_time
            };
        }

        pub fn reset(self) {
            self.counters = {};
            self.gauges = {};
            self.histograms = {};
        }
    }

    pub class Logger {
        pub let level: String;
        pub let buffer: List;
        pub let max_buffer: Int;

        pub fn new(level: String) -> Self {
            return Self { level: level, buffer: [], max_buffer: 10000 };
        }

        pub fn debug(self, msg: String, context: Map?) {
            if self.level == "debug" { self._log("DEBUG", msg, context); }
        }

        pub fn info(self, msg: String, context: Map?) {
            if self.level != "error" and self.level != "warn" {
                self._log("INFO", msg, context);
            }
        }

        pub fn warn(self, msg: String, context: Map?) {
            if self.level != "error" { self._log("WARN", msg, context); }
        }

        pub fn error(self, msg: String, context: Map?) {
            self._log("ERROR", msg, context);
        }

        fn _log(self, lvl: String, msg: String, context: Map?) {
            let entry = {
                "ts": native_production_time_ms(),
                "level": lvl,
                "msg": msg,
                "ctx": context
            };
            self.buffer.push(entry);
            if self.buffer.len() > self.max_buffer {
                self.buffer = self.buffer[self.max_buffer / 2..];
            }
        }

        pub fn flush(self) -> List {
            let out = self.buffer;
            self.buffer = [];
            return out;
        }
    }

    pub class CircuitBreaker {
        pub let state: String;
        pub let failure_count: Int;
        pub let threshold: Int;
        pub let reset_timeout_ms: Int;
        pub let last_failure_time: Int;

        pub fn new(threshold: Int, reset_timeout_ms: Int) -> Self {
            return Self {
                state: "closed",
                failure_count: 0,
                threshold: threshold,
                reset_timeout_ms: reset_timeout_ms,
                last_failure_time: 0
            };
        }

        pub fn allow_request(self) -> Bool {
            if self.state == "closed" { return true; }
            if self.state == "open" {
                let elapsed = native_production_time_ms() - self.last_failure_time;
                if elapsed >= self.reset_timeout_ms {
                    self.state = "half-open";
                    return true;
                }
                return false;
            }
            return true;
        }

        pub fn record_success(self) {
            self.failure_count = 0;
            self.state = "closed";
        }

        pub fn record_failure(self) {
            self.failure_count = self.failure_count + 1;
            self.last_failure_time = native_production_time_ms();
            if self.failure_count >= self.threshold {
                self.state = "open";
            }
        }
    }

    pub class RetryPolicy {
        pub let max_retries: Int;
        pub let base_delay_ms: Int;
        pub let max_delay_ms: Int;
        pub let backoff_multiplier: Float;

        pub fn new(max_retries: Int) -> Self {
            return Self {
                max_retries: max_retries,
                base_delay_ms: 100,
                max_delay_ms: 30000,
                backoff_multiplier: 2.0
            };
        }

        pub fn get_delay(self, attempt: Int) -> Int {
            let delay = self.base_delay_ms;
            for _ in 0..attempt { delay = (delay * self.backoff_multiplier).to_int(); }
            if delay > self.max_delay_ms { delay = self.max_delay_ms; }
            return delay;
        }
    }

    pub class RateLimiter {
        pub let max_requests: Int;
        pub let window_ms: Int;
        pub let requests: List;

        pub fn new(max_requests: Int, window_ms: Int) -> Self {
            return Self { max_requests: max_requests, window_ms: window_ms, requests: [] };
        }

        pub fn allow(self) -> Bool {
            let now = native_production_time_ms();
            self.requests = self.requests.filter(fn(t) { t > now - self.window_ms });
            if self.requests.len() >= self.max_requests { return false; }
            self.requests.push(now);
            return true;
        }
    }

    pub class GracefulShutdown {
        pub let hooks: List;
        pub let timeout_ms: Int;
        pub let is_shutting_down: Bool;

        pub fn new(timeout_ms: Int) -> Self {
            return Self { hooks: [], timeout_ms: timeout_ms, is_shutting_down: false };
        }

        pub fn register(self, name: String, hook: Fn) {
            self.hooks.push({ "name": name, "hook": hook });
        }

        pub fn shutdown(self) {
            self.is_shutting_down = true;
            for entry in self.hooks {
                entry.hook();
            }
        }
    }

    pub class ProductionRuntime {
        pub let health: HealthStatus;
        pub let metrics: MetricsCollector;
        pub let logger: Logger;
        pub let circuit_breaker: CircuitBreaker;
        pub let rate_limiter: RateLimiter;
        pub let shutdown: GracefulShutdown;

        pub fn new() -> Self {
            return Self {
                health: HealthStatus::new(),
                metrics: MetricsCollector::new(),
                logger: Logger::new("info"),
                circuit_breaker: CircuitBreaker::new(5, 30000),
                rate_limiter: RateLimiter::new(1000, 60000),
                shutdown: GracefulShutdown::new(30000)
            };
        }

        pub fn check_health(self) -> HealthStatus {
            self.health.uptime_ms = native_production_time_ms() - self.metrics.start_time;
            return self.health;
        }

        pub fn get_metrics(self) -> Map {
            return self.metrics.snapshot();
        }

        pub fn is_ready(self) -> Bool {
            return self.health.is_healthy() and !self.shutdown.is_shutting_down;
        }
    }
}

native_production_time_ms() -> Int;

# ============================================================
# OBSERVABILITY & ERROR HANDLING
# ============================================================

pub mod observability {

    pub class Span {
        pub let trace_id: String;
        pub let span_id: String;
        pub let parent_id: String?;
        pub let operation: String;
        pub let start_time: Int;
        pub let end_time: Int?;
        pub let tags: Map;
        pub let status: String;

        pub fn new(operation: String, parent_id: String?) -> Self {
            return Self {
                trace_id: native_production_time_ms().to_string(),
                span_id: native_production_time_ms().to_string(),
                parent_id: parent_id,
                operation: operation,
                start_time: native_production_time_ms(),
                end_time: null,
                tags: {},
                status: "ok"
            };
        }

        pub fn set_tag(self, key: String, value: String) {
            self.tags[key] = value;
        }

        pub fn finish(self) {
            self.end_time = native_production_time_ms();
        }

        pub fn finish_with_error(self, error: String) {
            self.end_time = native_production_time_ms();
            self.status = "error";
            self.tags["error"] = error;
        }

        pub fn duration_ms(self) -> Int {
            if self.end_time == null { return 0; }
            return self.end_time - self.start_time;
        }
    }

    pub class Tracer {
        pub let spans: List;
        pub let active_span: Span?;
        pub let service_name: String;

        pub fn new(service_name: String) -> Self {
            return Self { spans: [], active_span: null, service_name: service_name };
        }

        pub fn start_span(self, operation: String) -> Span {
            let parent = if self.active_span != null { self.active_span.span_id } else { null };
            let span = Span::new(operation, parent);
            span.set_tag("service", self.service_name);
            self.active_span = span;
            return span;
        }

        pub fn finish_span(self, span: Span) {
            span.finish();
            self.spans.push(span);
            self.active_span = null;
        }

        pub fn get_traces(self) -> List {
            return self.spans;
        }
    }

    pub class AlertRule {
        pub let name: String;
        pub let condition: Fn;
        pub let severity: String;
        pub let cooldown_ms: Int;
        pub let last_fired: Int;

        pub fn new(name: String, condition: Fn, severity: String) -> Self {
            return Self {
                name: name,
                condition: condition,
                severity: severity,
                cooldown_ms: 60000,
                last_fired: 0
            };
        }

        pub fn evaluate(self, metrics: Map) -> Bool {
            let now = native_production_time_ms();
            if now - self.last_fired < self.cooldown_ms { return false; }
            if self.condition(metrics) {
                self.last_fired = now;
                return true;
            }
            return false;
        }
    }

    pub class AlertManager {
        pub let rules: List;
        pub let alerts: List;

        pub fn new() -> Self {
            return Self { rules: [], alerts: [] };
        }

        pub fn add_rule(self, rule: AlertRule) {
            self.rules.push(rule);
        }

        pub fn evaluate_all(self, metrics: Map) -> List {
            let fired = [];
            for rule in self.rules {
                if rule.evaluate(metrics) {
                    let alert = {
                        "name": rule.name,
                        "severity": rule.severity,
                        "time": native_production_time_ms()
                    };
                    self.alerts.push(alert);
                    fired.push(alert);
                }
            }
            return fired;
        }
    }
}

pub mod error_handling {

    pub class EngineError {
        pub let code: String;
        pub let message: String;
        pub let context: Map;
        pub let timestamp: Int;
        pub let recoverable: Bool;

        pub fn new(code: String, message: String, recoverable: Bool) -> Self {
            return Self {
                code: code,
                message: message,
                context: {},
                timestamp: native_production_time_ms(),
                recoverable: recoverable
            };
        }

        pub fn with_context(self, key: String, value: Any) -> Self {
            self.context[key] = value;
            return self;
        }
    }

    pub class ErrorRegistry {
        pub let errors: List;
        pub let max_errors: Int;

        pub fn new(max_errors: Int) -> Self {
            return Self { errors: [], max_errors: max_errors };
        }

        pub fn record(self, error: EngineError) {
            self.errors.push(error);
            if self.errors.len() > self.max_errors {
                self.errors = self.errors[self.errors.len() - self.max_errors..];
            }
        }

        pub fn get_recent(self, count: Int) -> List {
            let start = if self.errors.len() > count { self.errors.len() - count } else { 0 };
            return self.errors[start..];
        }

        pub fn count_by_code(self, code: String) -> Int {
            return self.errors.filter(fn(e) { e.code == code }).len();
        }
    }

    pub class RecoveryStrategy {
        pub let name: String;
        pub let max_attempts: Int;
        pub let handler: Fn;

        pub fn new(name: String, max_attempts: Int, handler: Fn) -> Self {
            return Self { name: name, max_attempts: max_attempts, handler: handler };
        }
    }

    pub class ErrorHandler {
        pub let registry: ErrorRegistry;
        pub let strategies: Map;
        pub let fallback: Fn?;

        pub fn new() -> Self {
            return Self {
                registry: ErrorRegistry::new(1000),
                strategies: {},
                fallback: null
            };
        }

        pub fn register_strategy(self, code: String, strategy: RecoveryStrategy) {
            self.strategies[code] = strategy;
        }

        pub fn set_fallback(self, handler: Fn) {
            self.fallback = handler;
        }

        pub fn handle(self, error: EngineError) -> Any? {
            self.registry.record(error);
            if error.recoverable and self.strategies[error.code] != null {
                let strategy = self.strategies[error.code];
                return strategy.handler(error);
            }
            if self.fallback != null { return self.fallback(error); }
            return null;
        }
    }
}

# ============================================================
# CONFIGURATION & LIFECYCLE MANAGEMENT
# ============================================================

pub mod config_management {

    pub class EnvConfig {
        pub let values: Map;
        pub let defaults: Map;
        pub let required_keys: List;

        pub fn new() -> Self {
            return Self { values: {}, defaults: {}, required_keys: [] };
        }

        pub fn set_default(self, key: String, value: Any) {
            self.defaults[key] = value;
        }

        pub fn set(self, key: String, value: Any) {
            self.values[key] = value;
        }

        pub fn require(self, key: String) {
            self.required_keys.push(key);
        }

        pub fn get(self, key: String) -> Any? {
            if self.values[key] != null { return self.values[key]; }
            return self.defaults[key];
        }

        pub fn get_int(self, key: String) -> Int {
            let v = self.get(key);
            if v == null { return 0; }
            return v.to_int();
        }

        pub fn get_bool(self, key: String) -> Bool {
            let v = self.get(key);
            if v == null { return false; }
            return v == true or v == "true" or v == "1";
        }

        pub fn validate(self) -> List {
            let missing = [];
            for key in self.required_keys {
                if self.get(key) == null { missing.push(key); }
            }
            return missing;
        }

        pub fn from_map(self, map: Map) {
            for key in map.keys() { self.values[key] = map[key]; }
        }
    }

    pub class FeatureFlag {
        pub let name: String;
        pub let enabled: Bool;
        pub let rollout_pct: Float;
        pub let metadata: Map;

        pub fn new(name: String, enabled: Bool) -> Self {
            return Self { name: name, enabled: enabled, rollout_pct: 100.0, metadata: {} };
        }

        pub fn is_enabled(self) -> Bool {
            return self.enabled;
        }

        pub fn is_enabled_for(self, user_id: String) -> Bool {
            if !self.enabled { return false; }
            if self.rollout_pct >= 100.0 { return true; }
            let hash = user_id.len() % 100;
            return hash < self.rollout_pct.to_int();
        }
    }

    pub class FeatureFlagManager {
        pub let flags: Map;

        pub fn new() -> Self {
            return Self { flags: {} };
        }

        pub fn register(self, flag: FeatureFlag) {
            self.flags[flag.name] = flag;
        }

        pub fn is_enabled(self, name: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled();
        }

        pub fn is_enabled_for(self, name: String, user_id: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled_for(user_id);
        }
    }
}

pub mod lifecycle {

    pub class Phase {
        pub let name: String;
        pub let order: Int;
        pub let handler: Fn;
        pub let completed: Bool;

        pub fn new(name: String, order: Int, handler: Fn) -> Self {
            return Self { name: name, order: order, handler: handler, completed: false };
        }
    }

    pub class LifecycleManager {
        pub let phases: List;
        pub let current_phase: String;
        pub let state: String;
        pub let hooks: Map;

        pub fn new() -> Self {
            return Self {
                phases: [],
                current_phase: "init",
                state: "created",
                hooks: {}
            };
        }

        pub fn add_phase(self, phase: Phase) {
            self.phases.push(phase);
            self.phases.sort_by(fn(a, b) { a.order - b.order });
        }

        pub fn on(self, event: String, handler: Fn) {
            if self.hooks[event] == null { self.hooks[event] = []; }
            self.hooks[event].push(handler);
        }

        pub fn start(self) {
            self.state = "starting";
            self._emit("before_start");
            for phase in self.phases {
                self.current_phase = phase.name;
                phase.handler();
                phase.completed = true;
            }
            self.state = "running";
            self._emit("after_start");
        }

        pub fn stop(self) {
            self.state = "stopping";
            self._emit("before_stop");
            for phase in self.phases.reverse() {
                self.current_phase = "teardown_" + phase.name;
            }
            self.state = "stopped";
            self._emit("after_stop");
        }

        fn _emit(self, event: String) {
            if self.hooks[event] != null {
                for handler in self.hooks[event] { handler(); }
            }
        }

        pub fn is_running(self) -> Bool {
            return self.state == "running";
        }
    }

    pub class ResourcePool {
        pub let name: String;
        pub let resources: List;
        pub let max_size: Int;
        pub let in_use: Int;

        pub fn new(name: String, max_size: Int) -> Self {
            return Self { name: name, resources: [], max_size: max_size, in_use: 0 };
        }

        pub fn acquire(self) -> Any? {
            if self.resources.len() > 0 {
                self.in_use = self.in_use + 1;
                return self.resources.pop();
            }
            if self.in_use < self.max_size {
                self.in_use = self.in_use + 1;
                return {};
            }
            return null;
        }

        pub fn release(self, resource: Any) {
            self.in_use = self.in_use - 1;
            self.resources.push(resource);
        }

        pub fn available(self) -> Int {
            return self.max_size - self.in_use;
        }
    }
}
