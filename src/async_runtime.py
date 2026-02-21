# ================================================================
# NYX ASYNC RUNTIME - Concurrency Model
# ================================================================
# Implements async/await, event loop, and concurrency primitives
# for the Nyx programming language runtime.

import asyncio
import threading
import queue
import time
from typing import Any, Callable, Dict, List, Optional, Coroutine
from dataclasses import dataclass, field
from enum import Enum, auto
from concurrent.futures import Future, ThreadPoolExecutor
import heapq


# ================================================================
# Task States
# ================================================================

class TaskState(Enum):
    PENDING = auto()
    RUNNING = auto()
    COMPLETED = auto()
    FAILED = auto()
    CANCELLED = auto()


# ================================================================
# Async Task
# ================================================================

@dataclass
class AsyncTask:
    """Represents an asynchronous task in the Nyx runtime."""
    id: int
    name: str
    coroutine: Coroutine
    state: TaskState = TaskState.PENDING
    result: Any = None
    error: Optional[Exception] = None
    created_at: float = field(default_factory=time.time)
    started_at: Optional[float] = None
    completed_at: Optional[float] = None
    priority: int = 0
    
    def __lt__(self, other):
        """For priority queue ordering."""
        return self.priority < other.priority


# ================================================================
# Promise (Future-like object)
# ================================================================

class Promise:
    """
    A Promise represents the eventual result of an async operation.
    Similar to JavaScript Promises or Python Futures.
    """
    
    def __init__(self):
        self._state = TaskState.PENDING
        self._result = None
        self._error = None
        self._callbacks: List[Callable] = []
        self._error_callbacks: List[Callable] = []
        self._event = threading.Event()
    
    def resolve(self, value: Any):
        """Resolve the promise with a value."""
        if self._state != TaskState.PENDING:
            return
        self._state = TaskState.COMPLETED
        self._result = value
        self._event.set()
        for callback in self._callbacks:
            callback(value)
    
    def reject(self, error: Exception):
        """Reject the promise with an error."""
        if self._state != TaskState.PENDING:
            return
        self._state = TaskState.FAILED
        self._error = error
        self._event.set()
        for callback in self._error_callbacks:
            callback(error)
    
    def then(self, callback: Callable) -> 'Promise':
        """Chain a callback for successful resolution."""
        new_promise = Promise()
        
        def wrapper(value):
            try:
                result = callback(value)
                if isinstance(result, Promise):
                    result.then(new_promise.resolve).catch(new_promise.reject)
                else:
                    new_promise.resolve(result)
            except Exception as e:
                new_promise.reject(e)
        
        if self._state == TaskState.COMPLETED:
            wrapper(self._result)
        else:
            self._callbacks.append(wrapper)
        
        return new_promise
    
    def catch(self, callback: Callable) -> 'Promise':
        """Chain a callback for error handling."""
        new_promise = Promise()
        
        def wrapper(error):
            try:
                result = callback(error)
                new_promise.resolve(result)
            except Exception as e:
                new_promise.reject(e)
        
        if self._state == TaskState.FAILED:
            wrapper(self._error)
        else:
            self._error_callbacks.append(wrapper)
        
        return new_promise
    
    def wait(self, timeout: Optional[float] = None) -> Any:
        """Block until the promise resolves or times out."""
        if self._event.wait(timeout):
            if self._state == TaskState.COMPLETED:
                return self._result
            elif self._state == TaskState.FAILED:
                raise self._error
        raise TimeoutError("Promise timed out")
    
    @property
    def is_pending(self) -> bool:
        return self._state == TaskState.PENDING
    
    @property
    def is_completed(self) -> bool:
        return self._state == TaskState.COMPLETED
    
    @property
    def is_failed(self) -> bool:
        return self._state == TaskState.FAILED


# ================================================================
# Event Loop
# ================================================================

class NyxEventLoop:
    """
    Custom event loop for Nyx async operations.
    Manages task scheduling, I/O polling, and timer events.
    """
    
    _instance = None
    _lock = threading.Lock()
    
    def __new__(cls):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
                cls._instance._initialized = False
            return cls._instance
    
    def __init__(self):
        if self._initialized:
            return
        self._initialized = True
        
        self._tasks: Dict[int, AsyncTask] = {}
        self._task_queue: queue.PriorityQueue = queue.PriorityQueue()
        self._timer_heap: List[tuple] = []  # (time, task_id)
        self._next_task_id = 0
        self._running = False
        self._loop_thread: Optional[threading.Thread] = None
        self._executor = ThreadPoolExecutor(max_workers=4)
        self._async_loop: Optional[asyncio.AbstractEventLoop] = None
        self._io_handlers: Dict[str, Callable] = {}
        self._lock = threading.RLock()
    
    def start(self):
        """Start the event loop in a background thread."""
        if self._running:
            return
        
        self._running = True
        self._loop_thread = threading.Thread(target=self._run_loop, daemon=True)
        self._loop_thread.start()
    
    def stop(self):
        """Stop the event loop."""
        self._running = False
        if self._async_loop:
            self._async_loop.call_soon_threadsafe(self._async_loop.stop)
        if self._loop_thread:
            self._loop_thread.join(timeout=5)
        self._executor.shutdown(wait=False)
    
    def _run_loop(self):
        """Main event loop implementation."""
        # Create a new asyncio event loop for this thread
        self._async_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self._async_loop)
        
        try:
            self._async_loop.run_forever()
        except Exception as e:
            print(f"[EventLoop] Error: {e}")
        finally:
            self._async_loop.close()
    
    def spawn(self, coro: Coroutine, name: str = "", priority: int = 0) -> AsyncTask:
        """Spawn a new async task."""
        with self._lock:
            task_id = self._next_task_id
            self._next_task_id += 1
            
            task = AsyncTask(
                id=task_id,
                name=name or f"task_{task_id}",
                coroutine=coro,
                priority=priority
            )
            
            self._tasks[task_id] = task
            self._task_queue.put(task)
            
            # Schedule on asyncio loop
            if self._async_loop and self._running:
                future = asyncio.run_coroutine_threadsafe(coro, self._async_loop)
                task.state = TaskState.RUNNING
                task.started_at = time.time()
                
                def on_done(f):
                    task.completed_at = time.time()
                    try:
                        task.result = f.result()
                        task.state = TaskState.COMPLETED
                    except Exception as e:
                        task.error = e
                        task.state = TaskState.FAILED
                
                future.add_done_callback(on_done)
            
            return task
    
    def spawn_blocking(self, func: Callable, *args, **kwargs) -> Promise:
        """Run a blocking function in a thread pool."""
        promise = Promise()
        
        def wrapper():
            try:
                result = func(*args, **kwargs)
                promise.resolve(result)
            except Exception as e:
                promise.reject(e)
        
        self._executor.submit(wrapper)
        return promise
    
    def sleep(self, seconds: float) -> Promise:
        """Async sleep for the specified duration."""
        promise = Promise()
        
        def timer_callback():
            promise.resolve(None)
        
        if self._async_loop:
            self._async_loop.call_later(seconds, timer_callback)
        else:
            threading.Timer(seconds, timer_callback).start()
        
        return promise
    
    def set_timeout(self, callback: Callable, delay: float) -> int:
        """Schedule a callback after a delay. Returns timer ID."""
        if self._async_loop:
            handle = self._async_loop.call_later(delay, callback)
            return id(handle)
        else:
            timer = threading.Timer(delay, callback)
            timer.start()
            return id(timer)
    
    def set_interval(self, callback: Callable, interval: float) -> int:
        """Schedule a recurring callback. Returns timer ID."""
        def recurring():
            callback()
            self.set_interval(callback, interval)
        
        return self.set_timeout(recurring, interval)
    
    def clear_timeout(self, timer_id: int):
        """Cancel a scheduled timeout."""
        # Implementation depends on how timers are stored
        pass
    
    def get_task(self, task_id: int) -> Optional[AsyncTask]:
        """Get a task by ID."""
        return self._tasks.get(task_id)
    
    def get_all_tasks(self) -> List[AsyncTask]:
        """Get all tasks."""
        return list(self._tasks.values())
    
    def register_io_handler(self, event: str, handler: Callable):
        """Register an I/O event handler."""
        self._io_handlers[event] = handler
    
    def emit_io_event(self, event: str, data: Any = None):
        """Emit an I/O event to registered handlers."""
        handler = self._io_handlers.get(event)
        if handler:
            if self._async_loop:
                self._async_loop.call_soon_threadsafe(lambda: handler(data))
            else:
                handler(data)


# ================================================================
# Async Utilities
# ================================================================

class AsyncUtils:
    """Utility functions for async operations."""
    
    @staticmethod
    def all_promises(promises: List[Promise]) -> Promise:
        """Wait for all promises to complete."""
        result_promise = Promise()
        results = [None] * len(promises)
        completed = [0]
        errors = []
        
        def on_complete(index, value):
            results[index] = value
            completed[0] += 1
            if completed[0] == len(promises):
                if errors:
                    result_promise.reject(errors[0])
                else:
                    result_promise.resolve(results)
        
        def on_error(error):
            errors.append(error)
            completed[0] += 1
            if completed[0] == len(promises):
                result_promise.reject(errors[0])
        
        for i, promise in enumerate(promises):
            promise.then(lambda v, idx=i: on_complete(idx, v))
            promise.catch(lambda e, idx=i: on_error(e))
        
        return result_promise
    
    @staticmethod
    def race_promises(promises: List[Promise]) -> Promise:
        """Return the first promise to complete."""
        result_promise = Promise()
        
        for promise in promises:
            promise.then(result_promise.resolve)
            promise.catch(result_promise.reject)
        
        return result_promise
    
    @staticmethod
    def promise_all_settled(promises: List[Promise]) -> Promise:
        """Wait for all promises and return their statuses."""
        result_promise = Promise()
        results = [None] * len(promises)
        completed = [0]
        
        def on_settle(index, status, value=None, error=None):
            results[index] = {
                'status': status,
                'value': value,
                'error': error
            }
            completed[0] += 1
            if completed[0] == len(promises):
                result_promise.resolve(results)
        
        for i, promise in enumerate(promises):
            promise.then(lambda v, idx=i: on_settle(idx, 'fulfilled', value=v))
            promise.catch(lambda e, idx=i: on_settle(idx, 'rejected', error=e))
        
        return result_promise


# ================================================================
# Channel (for inter-task communication)
# ================================================================

class Channel:
    """
    A channel for communication between async tasks.
    Similar to Go channels or Python asyncio.Queue.
    """
    
    def __init__(self, maxsize: int = 0):
        self._queue = queue.Queue(maxsize=maxsize)
        self._closed = False
        self._waiters: List[Promise] = []
    
    def send(self, value: Any) -> Promise:
        """Send a value to the channel."""
        promise = Promise()
        
        if self._closed:
            promise.reject(ValueError("Channel is closed"))
            return promise
        
        try:
            self._queue.put_nowait(value)
            promise.resolve(None)
        except queue.Full:
            # Wait for space
            def wait_and_send():
                try:
                    self._queue.put(value, timeout=1.0)
                    promise.resolve(None)
                except queue.Full:
                    promise.reject(TimeoutError("Channel send timeout"))
            
            threading.Thread(target=wait_and_send, daemon=True).start()
        
        return promise
    
    def receive(self) -> Promise:
        """Receive a value from the channel."""
        promise = Promise()
        
        if self._closed and self._queue.empty():
            promise.reject(ValueError("Channel is closed and empty"))
            return promise
        
        try:
            value = self._queue.get_nowait()
            promise.resolve(value)
        except queue.Empty:
            # Wait for value
            def wait_and_receive():
                try:
                    value = self._queue.get(timeout=1.0)
                    promise.resolve(value)
                except queue.Empty:
                    if self._closed:
                        promise.reject(ValueError("Channel is closed"))
                    else:
                        promise.reject(TimeoutError("Channel receive timeout"))
            
            threading.Thread(target=wait_and_receive, daemon=True).start()
        
        return promise
    
    def close(self):
        """Close the channel."""
        self._closed = True
    
    @property
    def is_closed(self) -> bool:
        return self._closed
    
    @property
    def size(self) -> int:
        return self._queue.qsize()


# ================================================================
# Mutex (for synchronization)
# ================================================================

class Mutex:
    """A mutual exclusion lock for async operations."""
    
    def __init__(self):
        self._locked = False
        self._waiters: List[Promise] = []
        self._lock = threading.Lock()
    
    def lock(self) -> Promise:
        """Acquire the lock."""
        promise = Promise()
        
        with self._lock:
            if not self._locked:
                self._locked = True
                promise.resolve(None)
            else:
                self._waiters.append(promise)
        
        return promise
    
    def unlock(self):
        """Release the lock."""
        with self._lock:
            if self._waiters:
                next_promise = self._waiters.pop(0)
                next_promise.resolve(None)
            else:
                self._locked = False
    
    @property
    def is_locked(self) -> bool:
        return self._locked


# ================================================================
# WaitGroup (for waiting on multiple tasks)
# ================================================================

class WaitGroup:
    """A WaitGroup for waiting on multiple tasks to complete."""
    
    def __init__(self):
        self._count = 0
        self._promise = Promise()
        self._lock = threading.Lock()
    
    def add(self, delta: int = 1):
        """Add to the counter."""
        with self._lock:
            self._count += delta
    
    def done(self):
        """Decrement the counter."""
        with self._lock:
            self._count -= 1
            if self._count <= 0:
                self._promise.resolve(None)
    
    def wait(self) -> Promise:
        """Wait for the counter to reach zero."""
        with self._lock:
            if self._count <= 0:
                p = Promise()
                p.resolve(None)
                return p
            return self._promise


# ================================================================
# Global Event Loop Instance
# ================================================================

# Singleton event loop
_event_loop: Optional[NyxEventLoop] = None


def get_event_loop() -> NyxEventLoop:
    """Get the global event loop instance."""
    global _event_loop
    if _event_loop is None:
        _event_loop = NyxEventLoop()
    return _event_loop


def start_event_loop():
    """Start the global event loop."""
    get_event_loop().start()


def stop_event_loop():
    """Stop the global event loop."""
    global _event_loop
    if _event_loop:
        _event_loop.stop()
        _event_loop = None


# ================================================================
# Convenience Functions
# ================================================================

def spawn(coro: Coroutine, name: str = "", priority: int = 0) -> AsyncTask:
    """Spawn a new async task on the global event loop."""
    return get_event_loop().spawn(coro, name, priority)


def sleep(seconds: float) -> Promise:
    """Async sleep on the global event loop."""
    return get_event_loop().sleep(seconds)


def set_timeout(callback: Callable, delay: float) -> int:
    """Set a timeout on the global event loop."""
    return get_event_loop().set_timeout(callback, delay)


def set_interval(callback: Callable, interval: float) -> int:
    """Set an interval on the global event loop."""
    return get_event_loop().set_interval(callback, interval)


def run_blocking(func: Callable, *args, **kwargs) -> Promise:
    """Run a blocking function in the thread pool."""
    return get_event_loop().spawn_blocking(func, *args, **kwargs)
