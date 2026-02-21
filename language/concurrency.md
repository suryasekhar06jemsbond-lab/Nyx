# Nyx Concurrency Model

## Overview

Nyx provides a powerful concurrency model built on the foundations of its ownership system. The language ensures data-race-free concurrent programming through:

- **Async/Await**: Asynchronous programming primitives
- **Green Threads**: Lightweight cooperative multitasking
- **Channels**: Message passing between concurrent tasks
- **Thread Safety**: Send + Sync trait bounds
- **Atomic Operations**: Low-level atomic primitives

---

## Async/Await

### Async Functions

Declare functions as asynchronous with the `async` keyword:

```nyx
async fn fetch_data(url: str) -> Response {
    let response = await http_get(url);
    return response;
}
```

### Await Expressions

Pause execution until a future completes:

```nyx
async fn process() {
    let data = await fetch_data("https://api.example.com");
    print(data);
}
```

### Async Blocks

```nyx
let task = async {
    let result = await some_async_op();
    return result * 2;
};
```

---

## Futures

### Future Basics

Futures represent values that may not be available yet:

```nyx
let future = async { 42 };
let value = await future;  # Blocks until complete
```

### Future Composition

```nyx
# Chaining futures
let result = await some_future.then(|x| x + 1);

# Parallel execution
let (a, b) = await (future1, future2);
```

### Future Combinators

```nyx
# Map
let mapped = future.map(|x| x * 2);

# AndThen
let chained = future.and_then(|x| async { x + 1 });

# OrElse
let fallback = future.or_else(|_| async { 0 });

# CatchError
let handled = future.catch_error(|e| async { default_value });
```

---

## Event Loop

### Event Loop Basics

Nyx uses an event loop for async I/O:

```nyx
let loop = EventLoop::new();
loop.run();
```

### Custom Event Loops

```nyx
class MyLoop {
    tasks: [Task];
    
    fn add_task(self, task) {
        push(self.tasks, task);
    }
    
    fn run(self) {
        while (len(self.tasks) > 0) {
            let task = self.tasks[0];
            self.tasks = self.tasks[1:];
            task.resume();
        }
    }
}
```

---

## Tasks (Green Threads)

### Spawning Tasks

```nyx
# Spawn a new task
spawn(fn() {
    print("Running in new task");
});

# Spawn async task
spawn(async {
    let data = await fetch_data(url);
    process(data);
});
```

### Task Management

```nyx
# Join multiple tasks
await join(task1, task2, task3);

# Select between tasks
select {
    case result <- task1: print(result);
    case result <- task2: print(result);
}
```

---

## Channels

### Creating Channels

```nyx
let (tx, rx) = channel();
```

### Sending and Receiving

```nyx
# Sender side
spawn(fn() {
    tx.send("Hello from task!");
});

# Receiver side
let message = rx.recv();
print(message);
```

### Buffered Channels

```nyx
let (tx, rx) = channel(10);  # Buffer size 10
```

---

## Synchronization Primitives

### Mutex

Mutual exclusion for shared state:

```nyx
let counter = Mutex::new(0);

spawn(fn() {
    let mut c = counter.lock();
    *c = *c + 1;
});

spawn(fn() {
    let mut c = counter.lock();
    *c = *c + 1;
});

await counter.wait_for_unlock();
print(*counter.lock());  # 2
```

### RwLock

Multiple readers, single writer:

```nyx
let data = RwLock::new(initial_value);

# Multiple readers allowed
let r1 = data.read();
let r2 = data.read();

# Writer gets exclusive access
let mut w = data.write();
*w = new_value;
```

### Semaphore

Counting semaphore for resource limiting:

```nyx
let sem = Semaphore::new(3);  # Max 3 concurrent

sem.acquire();
# Do work...
sem.release();
```

---

## Thread Safety

### Send Trait

Types that can be safely transferred between threads:

```nyx
# Primitive types are Send
let x: i32 = 42;  # Send

# Box<T> where T: Send is Send
let boxed: Box<i32> = Box::new(42);  # Send
```

### Sync Trait

Types that can be safely shared between threads via references:

```nyx
# Primitive types are Sync
let x: &i32 = &42;  # Sync

# Arc<T> where T: Send + Sync is Sync
let shared: Arc<i32> = Arc::new(42);  # Sync
```

### Thread Safety Checker

The compiler verifies Send + Sync bounds:

```nyx
fn spawn_and_use<T: Send>(value: T) {
    spawn(fn() {
        use_value(value);
    });
}
```

---

## Atomics

### Atomic Types

```nyx
let atomic_counter = AtomicI64::new(0);

# Fetch-and-add
atomic_counter.fetch_add(1);

# Load
let value = atomic_counter.load();
```

### Atomic Operations

| Operation | Description |
|-----------|-------------|
| `load` | Read atomic value |
| `store` | Write atomic value |
| `fetch_add` | Atomically add and return old value |
| `fetch_sub` | Atomically subtract and return old value |
| `compare_exchange` | Atomic compare-and-swap |

---

## Data Race Prevention

### Compile-Time Guarantees

The type system prevents data races at compile time:

```nyx
# This is SAFE - no aliasing with mutation
let data = Arc::new(Mutex::new(0));

spawn(fn() {
    let mut d = data.lock();
    *d = *d + 1;
});

spawn(fn() {
    let mut d = data.lock();
    *d = *d + 1;
});
```

### Runtime Race Detection

The runtime can detect remaining races:

```nyx
# Enable race detection
nyx --race-detector program.ny
```

---

## Structured Concurrency

### Task Groups

```nyx
let group = TaskGroup::new();

group.spawn(async { /* task 1 */ });
group.spawn(async { /* task 2 */ });
group.spawn(async { /* task 3 */ });

await group.join_all();  # Wait for all
```

### Scoped Threads

```nyx
# Threads are guaranteed to complete before returning
scope(|s| {
    s.spawn(|| { /* work */ });
    s.spawn(|| { /* work */ });
});
# All spawned threads have completed here
```

---

## Error Handling in Concurrent Code

### Result in Async

```nyx
async fn might_fail() -> Result<int, Error> {
    let data = await read_file("data.txt")?;
    return parse_int(data);
}

# Handle errors
match (await might_fail()) {
    Ok(value) => print(value),
    Err(e) => print("Error: " + e),
}
```

### Cancellation

```nyx
let task = spawn(async {
    while (true) {
        await check_for_cancel()?;
        do_work();
    }
});

# Cancel the task
task.cancel();
await task;  # Wait for clean shutdown
```

---

## Performance Considerations

### Task Stack Size

```nyx
spawn_with_stack(fn(), 4096);  # 4KB stack
```

### Work Stealing

The scheduler uses work-stealing for load balancing:

```nyx
# Tasks are automatically distributed across cores
for (i in range(1000)) {
    spawn(expensive_task());
}
```

### Affinity

Pin tasks to specific cores:

```nyx
spawn_on(fn(), cpu_id: 0);  # Pin to CPU 0
```

---

## Best Practices

### Do

- Use channels for communication between tasks
- Wrap shared state in synchronization primitives
- Use `Arc` for sharing data across tasks
- Use `Send` and `Sync` trait bounds appropriately
- Handle errors in async functions

### Don't

- Don't share raw pointers between threads
- Don't use locks unnecessarily (prefer channels)
- Don't forget to handle cancellation
- Don't block in async context

---

## Standard Library Support

### Async I/O

```nyx
async fn read_file(path: str) -> Result<str, Error> {
    let file = await open_async(path);
    return await file.read_to_string();
}

async fn write_file(path: str, content: str) -> Result<void, Error> {
    let file = await open_async(path);
    return await file.write_string(content);
}
```

### Timers

```nyx
async fn sleep(duration: Duration) {
    Timer::after(duration).await;
}

async fn timeout<T>(duration: Duration, future: Future<T>) -> Result<T, TimeoutError> {
    select {
        result <- future => Ok(result),
        _ <- sleep(duration) => Err(TimeoutError),
    }
}
```

---

## Summary

| Feature | Description |
|---------|-------------|
| `async/await` | Asynchronous programming |
| `spawn` | Create new tasks |
| `Future` | Represent async values |
| `Channel` | Message passing |
| `Mutex` | Mutual exclusion |
| `RwLock` | Read-write lock |
| `Atomic*` | Atomic operations |
| `Arc` | Thread-safe sharing |
| Send + Sync | Thread safety traits |
