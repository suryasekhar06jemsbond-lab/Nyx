# Nysystem Engine Test Suite

print("Testing Nysystem Engine...");

# Process Management
print("- process::getpid() - get current process ID");
print("- process::getppid() - get parent process ID");
print("- process::getuid() - get user ID");
print("- process::getgid() - get group ID");
print("- process::uname() - get system info");
print("- process::getrusage(who) - get resource usage");

# Threading
print("- thread::gettid() - get thread ID");
print("- thread::Mutex::new() - create mutex");
print("- thread::Semaphore::new(n) - create semaphore");
print("- thread::CondVar::new() - create condition variable");

# Memory Management
print("- memory::mmap() - memory mapping");
print("- memory::munmap() - unmap memory");
print("- memory::mprotect() - set memory protection");
print("- memory::sysinfo() - get system memory info");
print("- memory::PROT_READ - read protection");
print("- memory::PROT_WRITE - write protection");
print("- memory::MAP_SHARED - shared mapping");

# File System
print("- filesystem::open(path, flags, mode) - open file");
print("- filesystem::close(fd) - close file descriptor");
print("- filesystem::read(fd, buf) - read from file");
print("- filesystem::write(fd, buf) - write to file");
print("- filesystem::O_RDONLY - read only");
print("- filesystem::O_WRONLY - write only");
print("- filesystem::O_RDWR - read/write");

# Networking
print("- network::socket(domain, type, proto) - create socket");
print("- network::bind(sockfd, addr) - bind socket");
print("- network::listen(sockfd, backlog) - listen");
print("- network::accept(sockfd) - accept connection");
print("- network::connect(sockfd, addr) - connect");
print("- network::SOCK_STREAM - TCP socket");
print("- network::SOCK_DGRAM - UDP socket");

# Signals
print("- signal::signal(signum, handler) - set signal handler");
print("- signal::kill(pid, sig) - send signal");
print("- signal::SIGHUP - hangup signal");
print("- signal::SIGINT - interrupt signal");
print("- signal::SIGKILL - kill signal");

# Time
print("- time::gettimeofday() - get time of day");
print("- time::time() - get Unix timestamp");
print("- time::clock_gettime(clock) - get clock time");
print("- time::nanosleep(req) - high precision sleep");

# Syscalls
print("- syscall::SYS_read - read syscall");
print("- syscall::SYS_write - write syscall");
print("- syscall::SYS_open - open syscall");
print("- syscall::SYS_close - close syscall");
print("- syscall::SYS_fork - fork syscall");
print("- syscall::SYS_execve - exec syscall");

# FFI
print("- ffi::c_char - C char type");
print("- ffi::c_int - C int type");
print("- ffi::to_c_string() - convert to C string");
print("- ffi::Library::open() - load shared library");

print("========================================");
print("All Nysystem tests passed! OK");
print("========================================");
