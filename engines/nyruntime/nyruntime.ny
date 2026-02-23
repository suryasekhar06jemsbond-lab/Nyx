# ============================================================
# NYRUNTIME - Nyx Desktop Application Runtime Core
# ============================================================
# Native cross-platform desktop runtime with memory-safe execution,
# GPU-accelerated rendering pipeline, thread orchestration, and
# secure sandboxing. Zero Electron/Chromium dependency.
# Compiles to native static binaries per platform.

let VERSION = "1.0.0";

# ============================================================
# PLATFORM ABSTRACTION
# ============================================================

pub mod platform {
    pub let WINDOWS = "windows";
    pub let MACOS = "macos";
    pub let LINUX = "linux";

    pub class PlatformInfo {
        pub let os: String;
        pub let arch: String;
        pub let version: String;
        pub let display_server: String;
        pub let gpu_vendor: String;
        pub let gpu_name: String;
        pub let cpu_cores: Int;
        pub let total_memory_mb: Int;

        pub fn detect() -> Self {
            let os = native_platform_os();
            let arch = native_platform_arch();
            let version = native_platform_version();
            let display = match os {
                WINDOWS => "win32",
                MACOS => "cocoa",
                LINUX => native_platform_display_server(),
                _ => "unknown"
            };
            return Self {
                os: os,
                arch: arch,
                version: version,
                display_server: display,
                gpu_vendor: native_gpu_vendor(),
                gpu_name: native_gpu_name(),
                cpu_cores: native_cpu_core_count(),
                total_memory_mb: native_total_memory_mb()
            };
        }

        pub fn is_wayland(self) -> Bool {
            return self.display_server == "wayland";
        }

        pub fn is_x11(self) -> Bool {
            return self.display_server == "x11";
        }

        pub fn supports_gpu_acceleration(self) -> Bool {
            return self.gpu_vendor != "unknown";
        }
    }

    pub class NativeWindow {
        pub let handle: Int;
        pub let title: String;
        pub let width: Int;
        pub let height: Int;
        pub let x: Int;
        pub let y: Int;
        pub let visible: Bool;
        pub let fullscreen: Bool;
        pub let resizable: Bool;
        pub let decorated: Bool;
        pub let transparent: Bool;
        pub let always_on_top: Bool;
        pub let min_width: Int;
        pub let min_height: Int;
        pub let max_width: Int;
        pub let max_height: Int;
        pub let dpi_scale: Float;

        pub fn new(title: String, width: Int, height: Int) -> Self {
            let handle = native_window_create(title, width, height);
            return Self {
                handle: handle,
                title: title,
                width: width,
                height: height,
                x: 0,
                y: 0,
                visible: false,
                fullscreen: false,
                resizable: true,
                decorated: true,
                transparent: false,
                always_on_top: false,
                min_width: 200,
                min_height: 150,
                max_width: 0,
                max_height: 0,
                dpi_scale: native_window_dpi_scale(handle)
            };
        }

        pub fn show(self) {
            native_window_show(self.handle);
            self.visible = true;
        }

        pub fn hide(self) {
            native_window_hide(self.handle);
            self.visible = false;
        }

        pub fn close(self) {
            native_window_close(self.handle);
        }

        pub fn set_title(self, title: String) {
            self.title = title;
            native_window_set_title(self.handle, title);
        }

        pub fn resize(self, width: Int, height: Int) {
            self.width = width;
            self.height = height;
            native_window_resize(self.handle, width, height);
        }

        pub fn move_to(self, x: Int, y: Int) {
            self.x = x;
            self.y = y;
            native_window_move(self.handle, x, y);
        }

        pub fn set_fullscreen(self, enabled: Bool) {
            self.fullscreen = enabled;
            native_window_set_fullscreen(self.handle, enabled);
        }

        pub fn set_resizable(self, enabled: Bool) {
            self.resizable = enabled;
            native_window_set_resizable(self.handle, enabled);
        }

        pub fn set_decorated(self, enabled: Bool) {
            self.decorated = enabled;
            native_window_set_decorated(self.handle, enabled);
        }

        pub fn set_transparent(self, enabled: Bool) {
            self.transparent = enabled;
            native_window_set_transparent(self.handle, enabled);
        }

        pub fn set_always_on_top(self, enabled: Bool) {
            self.always_on_top = enabled;
            native_window_set_always_on_top(self.handle, enabled);
        }

        pub fn set_min_size(self, width: Int, height: Int) {
            self.min_width = width;
            self.min_height = height;
            native_window_set_min_size(self.handle, width, height);
        }

        pub fn set_max_size(self, width: Int, height: Int) {
            self.max_width = width;
            self.max_height = height;
            native_window_set_max_size(self.handle, width, height);
        }

        pub fn set_icon(self, icon_path: String) {
            native_window_set_icon(self.handle, icon_path);
        }

        pub fn center(self) {
            native_window_center(self.handle);
        }

        pub fn request_attention(self) {
            native_window_request_attention(self.handle);
        }

        pub fn get_surface_handle(self) -> Int {
            return native_window_get_surface(self.handle);
        }
    }

    pub class Monitor {
        pub let id: Int;
        pub let name: String;
        pub let width: Int;
        pub let height: Int;
        pub let refresh_rate: Int;
        pub let dpi_scale: Float;
        pub let primary: Bool;

        pub fn list() -> List<Monitor> {
            return native_monitor_list();
        }

        pub fn primary() -> Monitor {
            return native_monitor_primary();
        }
    }
}

# ============================================================
# MEMORY MANAGEMENT
# ============================================================

pub mod memory {
    pub class ArenaAllocator {
        pub let id: Int;
        pub let capacity_bytes: Int;
        pub let used_bytes: Int;
        pub let label: String;

        pub fn new(label: String, capacity_bytes: Int) -> Self {
            let id = native_arena_create(capacity_bytes);
            return Self {
                id: id,
                capacity_bytes: capacity_bytes,
                used_bytes: 0,
                label: label
            };
        }

        pub fn alloc(self, size: Int) -> Int {
            let ptr = native_arena_alloc(self.id, size);
            self.used_bytes = self.used_bytes + size;
            return ptr;
        }

        pub fn reset(self) {
            native_arena_reset(self.id);
            self.used_bytes = 0;
        }

        pub fn destroy(self) {
            native_arena_destroy(self.id);
        }

        pub fn usage_percent(self) -> Float {
            return (self.used_bytes as Float / self.capacity_bytes as Float) * 100.0;
        }
    }

    pub class PoolAllocator {
        pub let id: Int;
        pub let block_size: Int;
        pub let block_count: Int;
        pub let free_count: Int;

        pub fn new(block_size: Int, block_count: Int) -> Self {
            let id = native_pool_create(block_size, block_count);
            return Self {
                id: id,
                block_size: block_size,
                block_count: block_count,
                free_count: block_count
            };
        }

        pub fn acquire(self) -> Int {
            let ptr = native_pool_acquire(self.id);
            self.free_count = self.free_count - 1;
            return ptr;
        }

        pub fn release(self, ptr: Int) {
            native_pool_release(self.id, ptr);
            self.free_count = self.free_count + 1;
        }

        pub fn destroy(self) {
            native_pool_destroy(self.id);
        }
    }

    pub class MemoryTracker {
        pub let allocations: Map<String, Int>;
        pub let peak_usage_bytes: Int;
        pub let current_usage_bytes: Int;
        pub let leak_detection: Bool;

        pub fn new() -> Self {
            return Self {
                allocations: {},
                peak_usage_bytes: 0,
                current_usage_bytes: 0,
                leak_detection: true
            };
        }

        pub fn track(self, label: String, bytes: Int) {
            self.allocations[label] = (self.allocations[label] or 0) + bytes;
            self.current_usage_bytes = self.current_usage_bytes + bytes;
            if self.current_usage_bytes > self.peak_usage_bytes {
                self.peak_usage_bytes = self.current_usage_bytes;
            }
        }

        pub fn untrack(self, label: String, bytes: Int) {
            self.allocations[label] = (self.allocations[label] or 0) - bytes;
            self.current_usage_bytes = self.current_usage_bytes - bytes;
        }

        pub fn report(self) -> Map<String, Int> {
            return self.allocations;
        }

        pub fn detect_leaks(self) -> List<String> {
            let leaks = [];
            for entry in self.allocations.entries() {
                if entry.value > 0 {
                    leaks.push(entry.key + ": " + entry.value as String + " bytes");
                }
            }
            return leaks;
        }
    }

    pub class GarbageCollector {
        pub let mode: String;
        pub let threshold_bytes: Int;
        pub let cycle_count: Int;

        pub fn new() -> Self {
            return Self {
                mode: "incremental",
                threshold_bytes: 64 * 1024 * 1024,
                cycle_count: 0
            };
        }

        pub fn collect(self) -> Int {
            self.cycle_count = self.cycle_count + 1;
            return native_gc_collect();
        }

        pub fn collect_full(self) -> Int {
            self.cycle_count = self.cycle_count + 1;
            return native_gc_collect_full();
        }

        pub fn set_mode(self, mode: String) {
            self.mode = mode;
            native_gc_set_mode(mode);
        }

        pub fn pause(self) {
            native_gc_pause();
        }

        pub fn resume(self) {
            native_gc_resume();
        }

        pub fn stats(self) -> Map<String, Int> {
            return native_gc_stats();
        }
    }
}

# ============================================================
# THREAD ORCHESTRATION
# ============================================================

pub mod threading {
    pub class Thread {
        pub let id: Int;
        pub let name: String;
        pub let priority: Int;
        pub let affinity: Int;

        pub fn spawn(name: String, func: Fn) -> Self {
            let id = native_thread_spawn(name, func);
            return Self { id: id, name: name, priority: 0, affinity: -1 };
        }

        pub fn join(self) {
            native_thread_join(self.id);
        }

        pub fn detach(self) {
            native_thread_detach(self.id);
        }

        pub fn set_priority(self, priority: Int) {
            self.priority = priority;
            native_thread_set_priority(self.id, priority);
        }

        pub fn set_affinity(self, core: Int) {
            self.affinity = core;
            native_thread_set_affinity(self.id, core);
        }

        pub fn is_alive(self) -> Bool {
            return native_thread_is_alive(self.id);
        }
    }

    pub class ThreadPool {
        pub let id: Int;
        pub let size: Int;
        pub let active_count: Int;

        pub fn new(size: Int) -> Self {
            let id = native_threadpool_create(size);
            return Self { id: id, size: size, active_count: 0 };
        }

        pub fn submit(self, func: Fn) -> Future {
            return Future::new(native_threadpool_submit(self.id, func));
        }

        pub fn submit_batch(self, tasks: List<Fn>) -> List<Future> {
            let futures = [];
            for task in tasks {
                futures.push(self.submit(task));
            }
            return futures;
        }

        pub fn shutdown(self) {
            native_threadpool_shutdown(self.id);
        }

        pub fn resize(self, new_size: Int) {
            self.size = new_size;
            native_threadpool_resize(self.id, new_size);
        }
    }

    pub class Future {
        pub let id: Int;
        pub let completed: Bool;
        pub let result: Any?;

        pub fn new(id: Int) -> Self {
            return Self { id: id, completed: false, result: null };
        }

        pub fn await(self) -> Any {
            self.result = native_future_await(self.id);
            self.completed = true;
            return self.result;
        }

        pub fn is_done(self) -> Bool {
            return native_future_is_done(self.id);
        }

        pub fn then(self, callback: Fn) -> Future {
            return Future::new(native_future_then(self.id, callback));
        }
    }

    pub class Mutex {
        pub let id: Int;

        pub fn new() -> Self {
            return Self { id: native_mutex_create() };
        }

        pub fn lock(self) {
            native_mutex_lock(self.id);
        }

        pub fn unlock(self) {
            native_mutex_unlock(self.id);
        }

        pub fn try_lock(self) -> Bool {
            return native_mutex_try_lock(self.id);
        }

        pub fn with_lock(self, func: Fn) -> Any {
            self.lock();
            let result = func();
            self.unlock();
            return result;
        }
    }

    pub class RWLock {
        pub let id: Int;

        pub fn new() -> Self {
            return Self { id: native_rwlock_create() };
        }

        pub fn read_lock(self) {
            native_rwlock_read_lock(self.id);
        }

        pub fn write_lock(self) {
            native_rwlock_write_lock(self.id);
        }

        pub fn unlock(self) {
            native_rwlock_unlock(self.id);
        }
    }

    pub class Channel {
        pub let id: Int;
        pub let capacity: Int;

        pub fn new(capacity: Int) -> Self {
            return Self { id: native_channel_create(capacity), capacity: capacity };
        }

        pub fn send(self, value: Any) {
            native_channel_send(self.id, value);
        }

        pub fn receive(self) -> Any {
            return native_channel_receive(self.id);
        }

        pub fn try_receive(self) -> Any? {
            return native_channel_try_receive(self.id);
        }

        pub fn close(self) {
            native_channel_close(self.id);
        }

        pub fn len(self) -> Int {
            return native_channel_len(self.id);
        }
    }

    pub class AtomicInt {
        pub let id: Int;

        pub fn new(initial: Int) -> Self {
            return Self { id: native_atomic_int_create(initial) };
        }

        pub fn load(self) -> Int {
            return native_atomic_int_load(self.id);
        }

        pub fn store(self, value: Int) {
            native_atomic_int_store(self.id, value);
        }

        pub fn fetch_add(self, delta: Int) -> Int {
            return native_atomic_int_fetch_add(self.id, delta);
        }

        pub fn compare_exchange(self, expected: Int, desired: Int) -> Bool {
            return native_atomic_int_compare_exchange(self.id, expected, desired);
        }
    }
}

# ============================================================
# APPLICATION LIFECYCLE
# ============================================================

pub mod lifecycle {
    pub let STATE_CREATED = "created";
    pub let STATE_INITIALIZING = "initializing";
    pub let STATE_RUNNING = "running";
    pub let STATE_SUSPENDED = "suspended";
    pub let STATE_RESUMING = "resuming";
    pub let STATE_SHUTTING_DOWN = "shutting_down";
    pub let STATE_TERMINATED = "terminated";

    pub class AppConfig {
        pub let name: String;
        pub let version: String;
        pub let org: String;
        pub let single_instance: Bool;
        pub let gpu_acceleration: Bool;
        pub let vsync: Bool;
        pub let target_fps: Int;
        pub let high_dpi: Bool;
        pub let dark_mode: String;
        pub let locale: String;
        pub let log_level: String;

        pub fn new(name: String) -> Self {
            return Self {
                name: name,
                version: "1.0.0",
                org: "",
                single_instance: true,
                gpu_acceleration: true,
                vsync: true,
                target_fps: 60,
                high_dpi: true,
                dark_mode: "system",
                locale: "en",
                log_level: "info"
            };
        }

        pub fn with_version(self, version: String) -> Self {
            self.version = version;
            return self;
        }

        pub fn with_org(self, org: String) -> Self {
            self.org = org;
            return self;
        }

        pub fn with_fps(self, fps: Int) -> Self {
            self.target_fps = fps;
            return self;
        }
    }

    pub class LifecycleHooks {
        pub let on_init: Fn?;
        pub let on_ready: Fn?;
        pub let on_suspend: Fn?;
        pub let on_resume: Fn?;
        pub let on_shutdown: Fn?;
        pub let on_error: Fn?;
        pub let on_low_memory: Fn?;

        pub fn new() -> Self {
            return Self {
                on_init: null,
                on_ready: null,
                on_suspend: null,
                on_resume: null,
                on_shutdown: null,
                on_error: null,
                on_low_memory: null
            };
        }
    }

    pub class AppState {
        pub let current: String;
        pub let start_time_ms: Int;
        pub let frame_count: Int;
        pub let uptime_ms: Int;

        pub fn new() -> Self {
            return Self {
                current: STATE_CREATED,
                start_time_ms: 0,
                frame_count: 0,
                uptime_ms: 0
            };
        }

        pub fn transition(self, to: String) {
            self.current = to;
        }
    }
}

# ============================================================
# EVENT LOOP
# ============================================================

pub mod event_loop {
    pub class EventLoop {
        pub let running: Bool;
        pub let frame_budget_ms: Float;
        pub let vsync: Bool;
        pub let handlers: Map<String, List<Fn>>;
        pub let deferred_queue: List<Fn>;

        pub fn new(target_fps: Int, vsync: Bool) -> Self {
            return Self {
                running: false,
                frame_budget_ms: 1000.0 / target_fps as Float,
                vsync: vsync,
                handlers: {},
                deferred_queue: []
            };
        }

        pub fn on(self, event_type: String, handler: Fn) {
            if self.handlers[event_type] == null {
                self.handlers[event_type] = [];
            }
            self.handlers[event_type].push(handler);
        }

        pub fn emit(self, event_type: String, data: Any) {
            let list = self.handlers[event_type];
            if list == null { return; }
            for handler in list {
                handler(data);
            }
        }

        pub fn defer(self, func: Fn) {
            self.deferred_queue.push(func);
        }

        pub fn run(self) {
            self.running = true;
            native_event_loop_run(self);
        }

        pub fn stop(self) {
            self.running = false;
            native_event_loop_stop();
        }

        pub fn tick(self) {
            # Process platform events
            native_event_loop_poll();
            # Flush deferred tasks
            let queue = self.deferred_queue;
            self.deferred_queue = [];
            for func in queue {
                func();
            }
        }
    }

    pub class Timer {
        pub let id: Int;
        pub let interval_ms: Int;
        pub let repeating: Bool;
        pub let active: Bool;

        pub fn once(delay_ms: Int, callback: Fn) -> Self {
            let id = native_timer_create(delay_ms, false, callback);
            return Self { id: id, interval_ms: delay_ms, repeating: false, active: true };
        }

        pub fn repeating(interval_ms: Int, callback: Fn) -> Self {
            let id = native_timer_create(interval_ms, true, callback);
            return Self { id: id, interval_ms: interval_ms, repeating: true, active: true };
        }

        pub fn cancel(self) {
            native_timer_cancel(self.id);
            self.active = false;
        }
    }

    pub class AnimationFrame {
        pub let callback: Fn;
        pub let id: Int;

        pub fn request(callback: Fn) -> Self {
            let id = native_request_animation_frame(callback);
            return Self { callback: callback, id: id };
        }

        pub fn cancel(self) {
            native_cancel_animation_frame(self.id);
        }
    }
}

# ============================================================
# GPU CONTEXT
# ============================================================

pub mod gpu {
    pub let BACKEND_AUTO = "auto";
    pub let BACKEND_VULKAN = "vulkan";
    pub let BACKEND_DIRECTX12 = "directx12";
    pub let BACKEND_METAL = "metal";
    pub let BACKEND_OPENGL = "opengl";

    pub class GPUContext {
        pub let backend: String;
        pub let device_name: String;
        pub let vram_mb: Int;
        pub let max_texture_size: Int;
        pub let supports_compute: Bool;
        pub let supports_raytracing: Bool;

        pub fn create(backend: String) -> Self {
            let ctx = native_gpu_context_create(backend);
            return Self {
                backend: ctx.backend,
                device_name: ctx.device_name,
                vram_mb: ctx.vram_mb,
                max_texture_size: ctx.max_texture_size,
                supports_compute: ctx.supports_compute,
                supports_raytracing: ctx.supports_raytracing
            };
        }

        pub fn destroy(self) {
            native_gpu_context_destroy();
        }
    }

    pub class Surface {
        pub let handle: Int;
        pub let width: Int;
        pub let height: Int;
        pub let format: String;

        pub fn from_window(window: platform.NativeWindow) -> Self {
            let handle = native_gpu_surface_create(window.handle);
            return Self {
                handle: handle,
                width: window.width,
                height: window.height,
                format: "bgra8_srgb"
            };
        }

        pub fn resize(self, width: Int, height: Int) {
            self.width = width;
            self.height = height;
            native_gpu_surface_resize(self.handle, width, height);
        }

        pub fn present(self) {
            native_gpu_surface_present(self.handle);
        }
    }

    pub class CommandBuffer {
        pub let id: Int;

        pub fn new() -> Self {
            return Self { id: native_gpu_command_buffer_create() };
        }

        pub fn begin(self) {
            native_gpu_command_buffer_begin(self.id);
        }

        pub fn end(self) {
            native_gpu_command_buffer_end(self.id);
        }

        pub fn submit(self) {
            native_gpu_command_buffer_submit(self.id);
        }
    }
}

# ============================================================
# INPUT SYSTEM
# ============================================================

pub mod input {
    pub class KeyEvent {
        pub let key: String;
        pub let code: Int;
        pub let pressed: Bool;
        pub let repeat: Bool;
        pub let modifiers: Modifiers;
    }

    pub class MouseEvent {
        pub let x: Float;
        pub let y: Float;
        pub let button: Int;
        pub let pressed: Bool;
        pub let delta_x: Float;
        pub let delta_y: Float;
    }

    pub class ScrollEvent {
        pub let delta_x: Float;
        pub let delta_y: Float;
        pub let precise: Bool;
    }

    pub class TouchEvent {
        pub let id: Int;
        pub let x: Float;
        pub let y: Float;
        pub let phase: String;
        pub let pressure: Float;
    }

    pub class Modifiers {
        pub let shift: Bool;
        pub let ctrl: Bool;
        pub let alt: Bool;
        pub let meta: Bool;

        pub fn new() -> Self {
            return Self { shift: false, ctrl: false, alt: false, meta: false };
        }
    }

    pub class InputManager {
        pub let key_states: Map<String, Bool>;
        pub let mouse_x: Float;
        pub let mouse_y: Float;
        pub let mouse_buttons: Map<Int, Bool>;

        pub fn new() -> Self {
            return Self {
                key_states: {},
                mouse_x: 0.0,
                mouse_y: 0.0,
                mouse_buttons: {}
            };
        }

        pub fn is_key_pressed(self, key: String) -> Bool {
            return self.key_states[key] or false;
        }

        pub fn is_mouse_button_pressed(self, button: Int) -> Bool {
            return self.mouse_buttons[button] or false;
        }

        pub fn mouse_position(self) -> (Float, Float) {
            return (self.mouse_x, self.mouse_y);
        }

        pub fn set_cursor(self, cursor: String) {
            native_set_cursor(cursor);
        }

        pub fn set_cursor_visible(self, visible: Bool) {
            native_set_cursor_visible(visible);
        }

        pub fn capture_mouse(self, capture: Bool) {
            native_capture_mouse(capture);
        }
    }
}

# ============================================================
# CLIPBOARD & DRAG-DROP
# ============================================================

pub mod clipboard {
    pub class Clipboard {
        pub fn get_text() -> String? {
            return native_clipboard_get_text();
        }

        pub fn set_text(text: String) {
            native_clipboard_set_text(text);
        }

        pub fn get_image() -> Bytes? {
            return native_clipboard_get_image();
        }

        pub fn set_image(data: Bytes) {
            native_clipboard_set_image(data);
        }

        pub fn has_text() -> Bool {
            return native_clipboard_has_text();
        }

        pub fn has_image() -> Bool {
            return native_clipboard_has_image();
        }

        pub fn clear() {
            native_clipboard_clear();
        }
    }

    pub class DragDrop {
        pub let accepted_types: List<String>;
        pub let on_drop: Fn?;
        pub let on_hover: Fn?;
        pub let on_leave: Fn?;

        pub fn new() -> Self {
            return Self {
                accepted_types: [],
                on_drop: null,
                on_hover: null,
                on_leave: null
            };
        }

        pub fn accept(self, mime_type: String) {
            self.accepted_types.push(mime_type);
        }

        pub fn enable(self, window: platform.NativeWindow) {
            native_dragdrop_enable(window.handle, self.accepted_types);
        }
    }
}

# ============================================================
# FILE DIALOGS
# ============================================================

pub mod dialogs {
    pub class FileFilter {
        pub let name: String;
        pub let extensions: List<String>;

        pub fn new(name: String, extensions: List<String>) -> Self {
            return Self { name: name, extensions: extensions };
        }
    }

    pub class FileDialog {
        pub let title: String;
        pub let filters: List<FileFilter>;
        pub let initial_dir: String;
        pub let multi_select: Bool;

        pub fn open(title: String) -> Self {
            return Self {
                title: title,
                filters: [],
                initial_dir: "",
                multi_select: false
            };
        }

        pub fn save(title: String) -> Self {
            return Self {
                title: title,
                filters: [],
                initial_dir: "",
                multi_select: false
            };
        }

        pub fn add_filter(self, filter: FileFilter) -> Self {
            self.filters.push(filter);
            return self;
        }

        pub fn set_initial_dir(self, dir: String) -> Self {
            self.initial_dir = dir;
            return self;
        }

        pub fn show_open(self) -> List<String> {
            return native_file_dialog_open(self.title, self.filters, self.initial_dir, self.multi_select);
        }

        pub fn show_save(self) -> String? {
            return native_file_dialog_save(self.title, self.filters, self.initial_dir);
        }
    }

    pub class MessageBox {
        pub fn info(title: String, message: String) {
            native_message_box("info", title, message);
        }

        pub fn warning(title: String, message: String) {
            native_message_box("warning", title, message);
        }

        pub fn error(title: String, message: String) {
            native_message_box("error", title, message);
        }

        pub fn confirm(title: String, message: String) -> Bool {
            return native_message_box_confirm(title, message);
        }
    }
}

# ============================================================
# SYSTEM TRAY & NOTIFICATIONS
# ============================================================

pub mod tray {
    pub class TrayIcon {
        pub let id: Int;
        pub let tooltip: String;
        pub let visible: Bool;

        pub fn new(icon_path: String, tooltip: String) -> Self {
            let id = native_tray_create(icon_path, tooltip);
            return Self { id: id, tooltip: tooltip, visible: true };
        }

        pub fn set_icon(self, icon_path: String) {
            native_tray_set_icon(self.id, icon_path);
        }

        pub fn set_tooltip(self, tooltip: String) {
            self.tooltip = tooltip;
            native_tray_set_tooltip(self.id, tooltip);
        }

        pub fn set_menu(self, menu: TrayMenu) {
            native_tray_set_menu(self.id, menu);
        }

        pub fn show(self) {
            native_tray_show(self.id);
            self.visible = true;
        }

        pub fn hide(self) {
            native_tray_hide(self.id);
            self.visible = false;
        }

        pub fn destroy(self) {
            native_tray_destroy(self.id);
        }
    }

    pub class TrayMenuItem {
        pub let label: String;
        pub let action: Fn?;
        pub let enabled: Bool;
        pub let checked: Bool;
        pub let separator: Bool;

        pub fn new(label: String, action: Fn) -> Self {
            return Self {
                label: label,
                action: action,
                enabled: true,
                checked: false,
                separator: false
            };
        }

        pub fn separator() -> Self {
            return Self {
                label: "",
                action: null,
                enabled: false,
                checked: false,
                separator: true
            };
        }
    }

    pub class TrayMenu {
        pub let items: List<TrayMenuItem>;

        pub fn new() -> Self {
            return Self { items: [] };
        }

        pub fn add(self, item: TrayMenuItem) -> Self {
            self.items.push(item);
            return self;
        }
    }

    pub class Notification {
        pub fn show(title: String, body: String) {
            native_notification_show(title, body, "info");
        }

        pub fn show_with_icon(title: String, body: String, icon_path: String) {
            native_notification_show_with_icon(title, body, icon_path);
        }
    }
}

# ============================================================
# SANDBOXING & SECURITY
# ============================================================

pub mod sandbox {
    pub class SandboxPolicy {
        pub let allow_filesystem: Bool;
        pub let allow_network: Bool;
        pub let allow_subprocesses: Bool;
        pub let allow_clipboard: Bool;
        pub let allow_camera: Bool;
        pub let allow_microphone: Bool;
        pub let allowed_paths: List<String>;
        pub let allowed_hosts: List<String>;

        pub fn strict() -> Self {
            return Self {
                allow_filesystem: false,
                allow_network: false,
                allow_subprocesses: false,
                allow_clipboard: false,
                allow_camera: false,
                allow_microphone: false,
                allowed_paths: [],
                allowed_hosts: []
            };
        }

        pub fn permissive() -> Self {
            return Self {
                allow_filesystem: true,
                allow_network: true,
                allow_subprocesses: true,
                allow_clipboard: true,
                allow_camera: true,
                allow_microphone: true,
                allowed_paths: [],
                allowed_hosts: []
            };
        }

        pub fn allow_path(self, path: String) -> Self {
            self.allowed_paths.push(path);
            self.allow_filesystem = true;
            return self;
        }

        pub fn allow_host(self, host: String) -> Self {
            self.allowed_hosts.push(host);
            self.allow_network = true;
            return self;
        }
    }

    pub class Sandbox {
        pub let policy: SandboxPolicy;
        pub let violations: List<String>;

        pub fn new(policy: SandboxPolicy) -> Self {
            return Self { policy: policy, violations: [] };
        }

        pub fn enforce(self) {
            native_sandbox_enforce(self.policy);
        }

        pub fn check_filesystem(self, path: String) -> Bool {
            if not self.policy.allow_filesystem { return false; }
            for allowed in self.policy.allowed_paths {
                if path.starts_with(allowed) { return true; }
            }
            return self.policy.allowed_paths.len() == 0;
        }

        pub fn check_network(self, host: String) -> Bool {
            if not self.policy.allow_network { return false; }
            for allowed in self.policy.allowed_hosts {
                if host == allowed or host.ends_with("." + allowed) { return true; }
            }
            return self.policy.allowed_hosts.len() == 0;
        }
    }
}

# ============================================================
# PROCESS & IPC
# ============================================================

pub mod process {
    pub class ChildProcess {
        pub let pid: Int;
        pub let command: String;
        pub let running: Bool;

        pub fn spawn(command: String, args: List<String>) -> Self {
            let pid = native_process_spawn(command, args);
            return Self { pid: pid, command: command, running: true };
        }

        pub fn wait(self) -> Int {
            let code = native_process_wait(self.pid);
            self.running = false;
            return code;
        }

        pub fn kill(self) {
            native_process_kill(self.pid);
            self.running = false;
        }

        pub fn write_stdin(self, data: String) {
            native_process_write_stdin(self.pid, data);
        }

        pub fn read_stdout(self) -> String {
            return native_process_read_stdout(self.pid);
        }

        pub fn read_stderr(self) -> String {
            return native_process_read_stderr(self.pid);
        }
    }

    pub class IpcChannel {
        pub let name: String;
        pub let id: Int;

        pub fn create(name: String) -> Self {
            let id = native_ipc_create(name);
            return Self { name: name, id: id };
        }

        pub fn connect(name: String) -> Self {
            let id = native_ipc_connect(name);
            return Self { name: name, id: id };
        }

        pub fn send(self, message: String) {
            native_ipc_send(self.id, message);
        }

        pub fn receive(self) -> String {
            return native_ipc_receive(self.id);
        }

        pub fn close(self) {
            native_ipc_close(self.id);
        }
    }
}

# ============================================================
# CRASH REPORTING & DIAGNOSTICS
# ============================================================

pub mod diagnostics {
    pub class CrashReporter {
        pub let enabled: Bool;
        pub let dump_path: String;
        pub let upload_url: String;

        pub fn new() -> Self {
            return Self {
                enabled: true,
                dump_path: "",
                upload_url: ""
            };
        }

        pub fn install(self) {
            native_crash_handler_install(self.dump_path);
        }

        pub fn set_metadata(self, key: String, value: String) {
            native_crash_handler_set_metadata(key, value);
        }
    }

    pub class PerformanceMonitor {
        pub let fps: Float;
        pub let frame_time_ms: Float;
        pub let cpu_usage_percent: Float;
        pub let memory_usage_mb: Int;
        pub let gpu_usage_percent: Float;
        pub let gpu_memory_mb: Int;

        pub fn new() -> Self {
            return Self {
                fps: 0.0,
                frame_time_ms: 0.0,
                cpu_usage_percent: 0.0,
                memory_usage_mb: 0,
                gpu_usage_percent: 0.0,
                gpu_memory_mb: 0
            };
        }

        pub fn sample(self) {
            self.fps = native_perf_fps();
            self.frame_time_ms = native_perf_frame_time_ms();
            self.cpu_usage_percent = native_perf_cpu_usage();
            self.memory_usage_mb = native_perf_memory_usage_mb();
            self.gpu_usage_percent = native_perf_gpu_usage();
            self.gpu_memory_mb = native_perf_gpu_memory_mb();
        }

        pub fn report(self) -> Map<String, Any> {
            return {
                "fps": self.fps,
                "frame_time_ms": self.frame_time_ms,
                "cpu_percent": self.cpu_usage_percent,
                "memory_mb": self.memory_usage_mb,
                "gpu_percent": self.gpu_usage_percent,
                "gpu_memory_mb": self.gpu_memory_mb
            };
        }
    }

    pub class Logger {
        pub let level: String;
        pub let file_path: String;

        pub fn new(level: String) -> Self {
            return Self { level: level, file_path: "" };
        }

        pub fn set_file(self, path: String) {
            self.file_path = path;
        }

        pub fn debug(self, msg: String) {
            if self.level == "debug" {
                native_log("DEBUG", msg);
            }
        }

        pub fn info(self, msg: String) {
            native_log("INFO", msg);
        }

        pub fn warn(self, msg: String) {
            native_log("WARN", msg);
        }

        pub fn error(self, msg: String) {
            native_log("ERROR", msg);
        }
    }
}

# ============================================================
# APPLICATION ORCHESTRATOR
# ============================================================

pub class Application {
    pub let config: lifecycle.AppConfig;
    pub let platform: platform.PlatformInfo;
    pub let window: platform.NativeWindow?;
    pub let gpu_context: gpu.GPUContext?;
    pub let surface: gpu.Surface?;
    pub let event_loop: event_loop.EventLoop;
    pub let input: input.InputManager;
    pub let state: lifecycle.AppState;
    pub let hooks: lifecycle.LifecycleHooks;
    pub let memory_tracker: memory.MemoryTracker;
    pub let gc: memory.GarbageCollector;
    pub let thread_pool: threading.ThreadPool;
    pub let crash_reporter: diagnostics.CrashReporter;
    pub let perf_monitor: diagnostics.PerformanceMonitor;
    pub let logger: diagnostics.Logger;
    pub let sandbox_policy: sandbox.SandboxPolicy?;

    pub fn new(config: lifecycle.AppConfig) -> Self {
        let plat = platform.PlatformInfo::detect();
        return Self {
            config: config,
            platform: plat,
            window: null,
            gpu_context: null,
            surface: null,
            event_loop: event_loop.EventLoop::new(config.target_fps, config.vsync),
            input: input.InputManager::new(),
            state: lifecycle.AppState::new(),
            hooks: lifecycle.LifecycleHooks::new(),
            memory_tracker: memory.MemoryTracker::new(),
            gc: memory.GarbageCollector::new(),
            thread_pool: threading.ThreadPool::new(plat.cpu_cores),
            crash_reporter: diagnostics.CrashReporter::new(),
            perf_monitor: diagnostics.PerformanceMonitor::new(),
            logger: diagnostics.Logger::new(config.log_level),
            sandbox_policy: null
        };
    }

    pub fn create_window(self, title: String, width: Int, height: Int) -> platform.NativeWindow {
        let win = platform.NativeWindow::new(title, width, height);
        self.window = win;
        if self.config.gpu_acceleration {
            self.gpu_context = gpu.GPUContext::create(gpu.BACKEND_AUTO);
            self.surface = gpu.Surface::from_window(win);
        }
        return win;
    }

    pub fn on_init(self, func: Fn) {
        self.hooks.on_init = func;
    }

    pub fn on_ready(self, func: Fn) {
        self.hooks.on_ready = func;
    }

    pub fn on_shutdown(self, func: Fn) {
        self.hooks.on_shutdown = func;
    }

    pub fn set_sandbox(self, policy: sandbox.SandboxPolicy) {
        self.sandbox_policy = policy;
        sandbox.Sandbox::new(policy).enforce();
    }

    pub fn run(self) {
        self.state.transition(lifecycle.STATE_INITIALIZING);
        self.crash_reporter.install();

        if self.hooks.on_init != null {
            self.hooks.on_init();
        }

        self.state.transition(lifecycle.STATE_RUNNING);
        self.state.start_time_ms = native_time_ms();

        if self.hooks.on_ready != null {
            self.hooks.on_ready();
        }

        if self.window != null {
            self.window.show();
        }

        self.event_loop.run();
    }

    pub fn quit(self) {
        self.state.transition(lifecycle.STATE_SHUTTING_DOWN);

        if self.hooks.on_shutdown != null {
            self.hooks.on_shutdown();
        }

        self.event_loop.stop();
        self.thread_pool.shutdown();

        if self.surface != null { native_gpu_surface_destroy(self.surface.handle); }
        if self.gpu_context != null { self.gpu_context.destroy(); }
        if self.window != null { self.window.close(); }

        self.state.transition(lifecycle.STATE_TERMINATED);
    }
}

# ============================================================
# CONVENIENCE API
# ============================================================

pub fn create_app(name: String) -> Application {
    return Application::new(lifecycle.AppConfig::new(name));
}

pub fn create_app_with_config(config: lifecycle.AppConfig) -> Application {
    return Application::new(config);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

# Platform
native_platform_os() -> String;
native_platform_arch() -> String;
native_platform_version() -> String;
native_platform_display_server() -> String;
native_gpu_vendor() -> String;
native_gpu_name() -> String;
native_cpu_core_count() -> Int;
native_total_memory_mb() -> Int;

# Window
native_window_create(title: String, width: Int, height: Int) -> Int;
native_window_show(handle: Int);
native_window_hide(handle: Int);
native_window_close(handle: Int);
native_window_set_title(handle: Int, title: String);
native_window_resize(handle: Int, width: Int, height: Int);
native_window_move(handle: Int, x: Int, y: Int);
native_window_set_fullscreen(handle: Int, enabled: Bool);
native_window_set_resizable(handle: Int, enabled: Bool);
native_window_set_decorated(handle: Int, enabled: Bool);
native_window_set_transparent(handle: Int, enabled: Bool);
native_window_set_always_on_top(handle: Int, enabled: Bool);
native_window_set_min_size(handle: Int, width: Int, height: Int);
native_window_set_max_size(handle: Int, width: Int, height: Int);
native_window_set_icon(handle: Int, icon_path: String);
native_window_center(handle: Int);
native_window_request_attention(handle: Int);
native_window_get_surface(handle: Int) -> Int;
native_window_dpi_scale(handle: Int) -> Float;
native_monitor_list() -> List;
native_monitor_primary() -> Any;

# Memory
native_arena_create(capacity: Int) -> Int;
native_arena_alloc(id: Int, size: Int) -> Int;
native_arena_reset(id: Int);
native_arena_destroy(id: Int);
native_pool_create(block_size: Int, block_count: Int) -> Int;
native_pool_acquire(id: Int) -> Int;
native_pool_release(id: Int, ptr: Int);
native_pool_destroy(id: Int);
native_gc_collect() -> Int;
native_gc_collect_full() -> Int;
native_gc_set_mode(mode: String);
native_gc_pause();
native_gc_resume();
native_gc_stats() -> Map;

# Threading
native_thread_spawn(name: String, func: Fn) -> Int;
native_thread_join(id: Int);
native_thread_detach(id: Int);
native_thread_set_priority(id: Int, priority: Int);
native_thread_set_affinity(id: Int, core: Int);
native_thread_is_alive(id: Int) -> Bool;
native_threadpool_create(size: Int) -> Int;
native_threadpool_submit(pool_id: Int, func: Fn) -> Int;
native_threadpool_shutdown(pool_id: Int);
native_threadpool_resize(pool_id: Int, size: Int);
native_future_await(id: Int) -> Any;
native_future_is_done(id: Int) -> Bool;
native_future_then(id: Int, callback: Fn) -> Int;
native_mutex_create() -> Int;
native_mutex_lock(id: Int);
native_mutex_unlock(id: Int);
native_mutex_try_lock(id: Int) -> Bool;
native_rwlock_create() -> Int;
native_rwlock_read_lock(id: Int);
native_rwlock_write_lock(id: Int);
native_rwlock_unlock(id: Int);
native_channel_create(capacity: Int) -> Int;
native_channel_send(id: Int, value: Any);
native_channel_receive(id: Int) -> Any;
native_channel_try_receive(id: Int) -> Any;
native_channel_close(id: Int);
native_channel_len(id: Int) -> Int;
native_atomic_int_create(initial: Int) -> Int;
native_atomic_int_load(id: Int) -> Int;
native_atomic_int_store(id: Int, value: Int);
native_atomic_int_fetch_add(id: Int, delta: Int) -> Int;
native_atomic_int_compare_exchange(id: Int, expected: Int, desired: Int) -> Bool;

# Event Loop
native_event_loop_run(loop_ref: Any);
native_event_loop_stop();
native_event_loop_poll();
native_timer_create(ms: Int, repeating: Bool, callback: Fn) -> Int;
native_timer_cancel(id: Int);
native_request_animation_frame(callback: Fn) -> Int;
native_cancel_animation_frame(id: Int);
native_time_ms() -> Int;

# GPU
native_gpu_context_create(backend: String) -> Any;
native_gpu_context_destroy();
native_gpu_surface_create(window_handle: Int) -> Int;
native_gpu_surface_resize(handle: Int, width: Int, height: Int);
native_gpu_surface_present(handle: Int);
native_gpu_surface_destroy(handle: Int);
native_gpu_command_buffer_create() -> Int;
native_gpu_command_buffer_begin(id: Int);
native_gpu_command_buffer_end(id: Int);
native_gpu_command_buffer_submit(id: Int);

# Input
native_set_cursor(cursor: String);
native_set_cursor_visible(visible: Bool);
native_capture_mouse(capture: Bool);

# Clipboard
native_clipboard_get_text() -> String;
native_clipboard_set_text(text: String);
native_clipboard_get_image() -> Bytes;
native_clipboard_set_image(data: Bytes);
native_clipboard_has_text() -> Bool;
native_clipboard_has_image() -> Bool;
native_clipboard_clear();
native_dragdrop_enable(window_handle: Int, types: List);

# Dialogs
native_file_dialog_open(title: String, filters: List, dir: String, multi: Bool) -> List;
native_file_dialog_save(title: String, filters: List, dir: String) -> String;
native_message_box(kind: String, title: String, message: String);
native_message_box_confirm(title: String, message: String) -> Bool;

# Tray
native_tray_create(icon: String, tooltip: String) -> Int;
native_tray_set_icon(id: Int, icon: String);
native_tray_set_tooltip(id: Int, tooltip: String);
native_tray_set_menu(id: Int, menu: Any);
native_tray_show(id: Int);
native_tray_hide(id: Int);
native_tray_destroy(id: Int);
native_notification_show(title: String, body: String, kind: String);
native_notification_show_with_icon(title: String, body: String, icon: String);

# Sandbox
native_sandbox_enforce(policy: Any);

# Process
native_process_spawn(cmd: String, args: List) -> Int;
native_process_wait(pid: Int) -> Int;
native_process_kill(pid: Int);
native_process_write_stdin(pid: Int, data: String);
native_process_read_stdout(pid: Int) -> String;
native_process_read_stderr(pid: Int) -> String;
native_ipc_create(name: String) -> Int;
native_ipc_connect(name: String) -> Int;
native_ipc_send(id: Int, msg: String);
native_ipc_receive(id: Int) -> String;
native_ipc_close(id: Int);

# Crash & Diagnostics
native_crash_handler_install(dump_path: String);
native_crash_handler_set_metadata(key: String, value: String);
native_perf_fps() -> Float;
native_perf_frame_time_ms() -> Float;
native_perf_cpu_usage() -> Float;
native_perf_memory_usage_mb() -> Int;
native_perf_gpu_usage() -> Float;
native_perf_gpu_memory_mb() -> Int;
native_log(level: String, msg: String);

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
