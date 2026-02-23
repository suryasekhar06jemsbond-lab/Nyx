# ============================================================
# NYEVENT - Nyx Event Propagation & Signal System
# ============================================================
# Production-grade event system with signal-slot model, async
# event dispatch, bubbling/capture propagation, global event bus,
# debounce/throttle, priority queues, and gesture recognition.

let VERSION = "1.0.0";

# ============================================================
# CORE EVENT TYPES
# ============================================================

pub mod core {
    pub let PHASE_CAPTURE = "capture";
    pub let PHASE_TARGET = "target";
    pub let PHASE_BUBBLE = "bubble";

    pub let PRIORITY_CRITICAL = 0;
    pub let PRIORITY_HIGH = 1;
    pub let PRIORITY_NORMAL = 2;
    pub let PRIORITY_LOW = 3;
    pub let PRIORITY_IDLE = 4;

    pub class Event {
        pub let type_name: String;
        pub let timestamp_ms: Int;
        pub let source: String;
        pub let phase: String;
        pub let data: Any?;
        pub let propagation_stopped: Bool;
        pub let default_prevented: Bool;
        pub let immediate_stopped: Bool;
        pub let priority: Int;
        pub let bubbles: Bool;
        pub let cancelable: Bool;

        pub fn new(type_name: String, data: Any?) -> Self {
            return Self {
                type_name: type_name,
                timestamp_ms: native_event_time_ms(),
                source: "",
                phase: PHASE_TARGET,
                data: data,
                propagation_stopped: false,
                default_prevented: false,
                immediate_stopped: false,
                priority: PRIORITY_NORMAL,
                bubbles: true,
                cancelable: true
            };
        }

        pub fn with_priority(self, priority: Int) -> Self {
            self.priority = priority;
            return self;
        }

        pub fn with_source(self, source: String) -> Self {
            self.source = source;
            return self;
        }

        pub fn non_bubbling(self) -> Self {
            self.bubbles = false;
            return self;
        }

        pub fn stop_propagation(self) {
            self.propagation_stopped = true;
        }

        pub fn stop_immediate_propagation(self) {
            self.immediate_stopped = true;
            self.propagation_stopped = true;
        }

        pub fn prevent_default(self) {
            if self.cancelable {
                self.default_prevented = true;
            }
        }
    }

    pub class EventListener {
        pub let id: Int;
        pub let event_type: String;
        pub let handler: Fn;
        pub let phase: String;
        pub let priority: Int;
        pub let once: Bool;
        pub let active: Bool;

        pub fn new(event_type: String, handler: Fn) -> Self {
            return Self {
                id: native_event_next_id(),
                event_type: event_type,
                handler: handler,
                phase: PHASE_BUBBLE,
                priority: PRIORITY_NORMAL,
                once: false,
                active: true
            };
        }

        pub fn capture(self) -> Self {
            self.phase = PHASE_CAPTURE;
            return self;
        }

        pub fn with_priority(self, priority: Int) -> Self {
            self.priority = priority;
            return self;
        }

        pub fn one_shot(self) -> Self {
            self.once = true;
            return self;
        }

        pub fn remove(self) {
            self.active = false;
        }
    }
}

# ============================================================
# EVENT DISPATCHER
# ============================================================

pub mod dispatch {
    pub class EventTarget {
        pub let id: String;
        pub let parent: EventTarget?;
        pub let listeners: Map<String, List<core.EventListener>>;

        pub fn new(id: String) -> Self {
            return Self { id: id, parent: null, listeners: {} };
        }

        pub fn set_parent(self, parent: EventTarget) {
            self.parent = parent;
        }

        pub fn on(self, event_type: String, handler: Fn) -> core.EventListener {
            let listener = core.EventListener::new(event_type, handler);
            if self.listeners[event_type] == null {
                self.listeners[event_type] = [];
            }
            self.listeners[event_type].push(listener);
            return listener;
        }

        pub fn once(self, event_type: String, handler: Fn) -> core.EventListener {
            let listener = core.EventListener::new(event_type, handler).one_shot();
            if self.listeners[event_type] == null {
                self.listeners[event_type] = [];
            }
            self.listeners[event_type].push(listener);
            return listener;
        }

        pub fn off(self, event_type: String, listener_id: Int) {
            let list = self.listeners[event_type];
            if list == null { return; }
            for listener in list {
                if listener.id == listener_id {
                    listener.remove();
                }
            }
        }

        pub fn off_all(self, event_type: String) {
            self.listeners[event_type] = [];
        }

        pub fn emit(self, event: core.Event) {
            event.source = self.id;
            self._dispatch_local(event, core.PHASE_TARGET);
            if event.bubbles and not event.propagation_stopped and self.parent != null {
                self.parent._bubble(event);
            }
        }

        fn _dispatch_local(self, event: core.Event, phase: String) {
            event.phase = phase;
            let list = self.listeners[event.type_name];
            if list == null { return; }

            # Sort by priority
            let sorted = list.filter(|l| l.active and l.phase == phase or phase == core.PHASE_TARGET);
            sorted.sort(|a, b| a.priority - b.priority);

            let to_remove = [];
            for listener in sorted {
                if event.immediate_stopped { break; }
                listener.handler(event);
                if listener.once {
                    to_remove.push(listener.id);
                }
            }

            for id in to_remove {
                self.off(event.type_name, id);
            }
        }

        fn _bubble(self, event: core.Event) {
            if event.propagation_stopped { return; }
            self._dispatch_local(event, core.PHASE_BUBBLE);
            if not event.propagation_stopped and self.parent != null {
                self.parent._bubble(event);
            }
        }

        fn _capture(self, event: core.Event, path: List<EventTarget>) {
            for target in path {
                if event.propagation_stopped { return; }
                target._dispatch_local(event, core.PHASE_CAPTURE);
            }
        }
    }

    pub class EventDispatcher {
        pub let targets: Map<String, EventTarget>;

        pub fn new() -> Self {
            return Self { targets: {} };
        }

        pub fn register(self, target: EventTarget) {
            self.targets[target.id] = target;
        }

        pub fn unregister(self, id: String) {
            self.targets.remove(id);
        }

        pub fn dispatch(self, target_id: String, event: core.Event) {
            let target = self.targets[target_id];
            if target == null { return; }

            # Build capture path
            let path = [];
            let current = target.parent;
            while current != null {
                path.insert(0, current);
                current = current.parent;
            }

            # Capture phase
            target._capture(event, path);

            # Target phase
            if not event.propagation_stopped {
                target._dispatch_local(event, core.PHASE_TARGET);
            }

            # Bubble phase
            if event.bubbles and not event.propagation_stopped and target.parent != null {
                target.parent._bubble(event);
            }
        }

        pub fn broadcast(self, event: core.Event) {
            for entry in self.targets.entries() {
                if event.propagation_stopped { break; }
                entry.value._dispatch_local(event, core.PHASE_TARGET);
            }
        }
    }
}

# ============================================================
# SIGNAL-SLOT SYSTEM
# ============================================================

pub mod signals {
    pub class Connection {
        pub let id: Int;
        pub let signal_name: String;
        pub let slot: Fn;
        pub let active: Bool;
        pub let once: Bool;

        pub fn new(signal_name: String, slot: Fn) -> Self {
            return Self {
                id: native_event_next_id(),
                signal_name: signal_name,
                slot: slot,
                active: true,
                once: false
            };
        }

        pub fn disconnect(self) {
            self.active = false;
        }
    }

    pub class Signal {
        pub let name: String;
        pub let connections: List<Connection>;
        pub let blocked: Bool;

        pub fn new(name: String) -> Self {
            return Self { name: name, connections: [], blocked: false };
        }

        pub fn connect(self, slot: Fn) -> Connection {
            let conn = Connection::new(self.name, slot);
            self.connections.push(conn);
            return conn;
        }

        pub fn connect_once(self, slot: Fn) -> Connection {
            let conn = Connection::new(self.name, slot);
            conn.once = true;
            self.connections.push(conn);
            return conn;
        }

        pub fn disconnect(self, connection_id: Int) {
            for conn in self.connections {
                if conn.id == connection_id {
                    conn.disconnect();
                }
            }
        }

        pub fn disconnect_all(self) {
            for conn in self.connections {
                conn.disconnect();
            }
        }

        pub fn block(self) {
            self.blocked = true;
        }

        pub fn unblock(self) {
            self.blocked = false;
        }

        pub fn emit(self, args: Any?) {
            if self.blocked { return; }
            let to_remove = [];
            for conn in self.connections {
                if not conn.active { continue; }
                conn.slot(args);
                if conn.once {
                    to_remove.push(conn.id);
                }
            }
            for id in to_remove {
                self.disconnect(id);
            }
        }

        pub fn connection_count(self) -> Int {
            let count = 0;
            for conn in self.connections {
                if conn.active { count = count + 1; }
            }
            return count;
        }
    }

    pub class SignalEmitter {
        pub let signals: Map<String, Signal>;

        pub fn new() -> Self {
            return Self { signals: {} };
        }

        pub fn define_signal(self, name: String) -> Signal {
            let signal = Signal::new(name);
            self.signals[name] = signal;
            return signal;
        }

        pub fn signal(self, name: String) -> Signal? {
            return self.signals[name];
        }

        pub fn emit(self, name: String, args: Any?) {
            let sig = self.signals[name];
            if sig != null {
                sig.emit(args);
            }
        }

        pub fn connect(self, name: String, slot: Fn) -> Connection? {
            let sig = self.signals[name];
            if sig == null { return null; }
            return sig.connect(slot);
        }
    }
}

# ============================================================
# GLOBAL EVENT BUS
# ============================================================

pub mod bus {
    pub class EventFilter {
        pub let type_pattern: String;
        pub let source_pattern: String;
        pub let min_priority: Int;

        pub fn new() -> Self {
            return Self {
                type_pattern: "*",
                source_pattern: "*",
                min_priority: core.PRIORITY_IDLE
            };
        }

        pub fn for_type(self, pattern: String) -> Self {
            self.type_pattern = pattern;
            return self;
        }

        pub fn for_source(self, pattern: String) -> Self {
            self.source_pattern = pattern;
            return self;
        }

        pub fn min_priority(self, priority: Int) -> Self {
            self.min_priority = priority;
            return self;
        }

        pub fn matches(self, event: core.Event) -> Bool {
            if event.priority > self.min_priority { return false; }
            if self.type_pattern != "*" and not event.type_name.matches(self.type_pattern) {
                return false;
            }
            if self.source_pattern != "*" and not event.source.matches(self.source_pattern) {
                return false;
            }
            return true;
        }
    }

    pub class Subscription {
        pub let id: Int;
        pub let filter: EventFilter;
        pub let handler: Fn;
        pub let active: Bool;

        pub fn new(filter: EventFilter, handler: Fn) -> Self {
            return Self {
                id: native_event_next_id(),
                filter: filter,
                handler: handler,
                active: true
            };
        }

        pub fn unsubscribe(self) {
            self.active = false;
        }
    }

    pub class EventBus {
        pub let subscriptions: List<Subscription>;
        pub let history: List<core.Event>;
        pub let history_limit: Int;
        pub let paused: Bool;
        pub let interceptors: List<Fn>;

        pub fn new() -> Self {
            return Self {
                subscriptions: [],
                history: [],
                history_limit: 1000,
                paused: false,
                interceptors: []
            };
        }

        pub fn subscribe(self, event_type: String, handler: Fn) -> Subscription {
            let filter = EventFilter::new().for_type(event_type);
            let sub = Subscription::new(filter, handler);
            self.subscriptions.push(sub);
            return sub;
        }

        pub fn subscribe_filtered(self, filter: EventFilter, handler: Fn) -> Subscription {
            let sub = Subscription::new(filter, handler);
            self.subscriptions.push(sub);
            return sub;
        }

        pub fn unsubscribe(self, subscription_id: Int) {
            for sub in self.subscriptions {
                if sub.id == subscription_id {
                    sub.unsubscribe();
                }
            }
        }

        pub fn add_interceptor(self, interceptor: Fn) {
            self.interceptors.push(interceptor);
        }

        pub fn publish(self, event: core.Event) {
            if self.paused { return; }

            # Run interceptors
            for interceptor in self.interceptors {
                let result = interceptor(event);
                if result == false { return; }
            }

            # Record in history
            self.history.push(event);
            if self.history.len() > self.history_limit {
                self.history.remove(0);
            }

            # Dispatch to matching subscriptions
            for sub in self.subscriptions {
                if not sub.active { continue; }
                if sub.filter.matches(event) {
                    sub.handler(event);
                }
            }
        }

        pub fn publish_async(self, event: core.Event) {
            native_event_defer(|| {
                self.publish(event);
            });
        }

        pub fn pause(self) {
            self.paused = true;
        }

        pub fn resume(self) {
            self.paused = false;
        }

        pub fn clear_history(self) {
            self.history = [];
        }

        pub fn replay(self, from_index: Int) {
            for i in from_index..self.history.len() {
                self.publish(self.history[i]);
            }
        }
    }

    # Global singleton bus
    let _global_bus = EventBus::new();

    pub fn global() -> EventBus {
        return _global_bus;
    }
}

# ============================================================
# DEBOUNCE & THROTTLE
# ============================================================

pub mod timing {
    pub class Debouncer {
        pub let delay_ms: Int;
        pub let timer_id: Int?;
        pub let callback: Fn;
        pub let leading: Bool;
        pub let trailing: Bool;

        pub fn new(delay_ms: Int, callback: Fn) -> Self {
            return Self {
                delay_ms: delay_ms,
                timer_id: null,
                callback: callback,
                leading: false,
                trailing: true
            };
        }

        pub fn leading_edge(self) -> Self {
            self.leading = true;
            self.trailing = false;
            return self;
        }

        pub fn both_edges(self) -> Self {
            self.leading = true;
            self.trailing = true;
            return self;
        }

        pub fn call(self, args: Any?) {
            if self.timer_id != null {
                native_timer_cancel(self.timer_id);
            }
            if self.leading and self.timer_id == null {
                self.callback(args);
            }
            if self.trailing {
                self.timer_id = native_timer_create(self.delay_ms, false, || {
                    self.callback(args);
                    self.timer_id = null;
                });
            }
        }

        pub fn cancel(self) {
            if self.timer_id != null {
                native_timer_cancel(self.timer_id);
                self.timer_id = null;
            }
        }

        pub fn flush(self, args: Any?) {
            self.cancel();
            self.callback(args);
        }
    }

    pub class Throttle {
        pub let interval_ms: Int;
        pub let callback: Fn;
        pub let last_call_ms: Int;
        pub let pending: Bool;

        pub fn new(interval_ms: Int, callback: Fn) -> Self {
            return Self {
                interval_ms: interval_ms,
                callback: callback,
                last_call_ms: 0,
                pending: false
            };
        }

        pub fn call(self, args: Any?) {
            let now = native_event_time_ms();
            let elapsed = now - self.last_call_ms;
            if elapsed >= self.interval_ms {
                self.callback(args);
                self.last_call_ms = now;
                self.pending = false;
            } else if not self.pending {
                self.pending = true;
                native_timer_create(self.interval_ms - elapsed, false, || {
                    self.callback(args);
                    self.last_call_ms = native_event_time_ms();
                    self.pending = false;
                });
            }
        }

        pub fn cancel(self) {
            self.pending = false;
        }
    }

    pub class RateLimiter {
        pub let max_events: Int;
        pub let window_ms: Int;
        pub let timestamps: List<Int>;

        pub fn new(max_events: Int, window_ms: Int) -> Self {
            return Self {
                max_events: max_events,
                window_ms: window_ms,
                timestamps: []
            };
        }

        pub fn try_acquire(self) -> Bool {
            let now = native_event_time_ms();
            # Prune old timestamps
            self.timestamps = self.timestamps.filter(|t| now - t < self.window_ms);
            if self.timestamps.len() >= self.max_events {
                return false;
            }
            self.timestamps.push(now);
            return true;
        }

        pub fn reset(self) {
            self.timestamps = [];
        }
    }
}

# ============================================================
# GESTURE RECOGNITION
# ============================================================

pub mod gestures {
    pub let GESTURE_TAP = "tap";
    pub let GESTURE_DOUBLE_TAP = "double_tap";
    pub let GESTURE_LONG_PRESS = "long_press";
    pub let GESTURE_PAN = "pan";
    pub let GESTURE_PINCH = "pinch";
    pub let GESTURE_ROTATE = "rotate";
    pub let GESTURE_SWIPE = "swipe";

    pub class GestureEvent {
        pub let gesture_type: String;
        pub let x: Float;
        pub let y: Float;
        pub let delta_x: Float;
        pub let delta_y: Float;
        pub let scale: Float;
        pub let rotation: Float;
        pub let velocity_x: Float;
        pub let velocity_y: Float;
        pub let direction: String;
        pub let state: String;

        pub fn new(gesture_type: String) -> Self {
            return Self {
                gesture_type: gesture_type,
                x: 0.0, y: 0.0,
                delta_x: 0.0, delta_y: 0.0,
                scale: 1.0, rotation: 0.0,
                velocity_x: 0.0, velocity_y: 0.0,
                direction: "",
                state: "began"
            };
        }
    }

    pub class GestureRecognizer {
        pub let gesture_type: String;
        pub let handler: Fn;
        pub let enabled: Bool;
        pub let min_touches: Int;
        pub let max_touches: Int;

        pub fn new(gesture_type: String, handler: Fn) -> Self {
            return Self {
                gesture_type: gesture_type,
                handler: handler,
                enabled: true,
                min_touches: 1,
                max_touches: 1
            };
        }

        pub fn enable(self) { self.enabled = true; }
        pub fn disable(self) { self.enabled = false; }
    }

    pub class TapRecognizer {
        pub let recognizer: GestureRecognizer;
        pub let required_taps: Int;
        pub let max_duration_ms: Int;

        pub fn new(handler: Fn) -> Self {
            return Self {
                recognizer: GestureRecognizer::new(GESTURE_TAP, handler),
                required_taps: 1,
                max_duration_ms: 300
            };
        }

        pub fn double_tap(handler: Fn) -> Self {
            let rec = Self::new(handler);
            rec.required_taps = 2;
            rec.recognizer.gesture_type = GESTURE_DOUBLE_TAP;
            return rec;
        }
    }

    pub class PanRecognizer {
        pub let recognizer: GestureRecognizer;
        pub let min_distance: Float;

        pub fn new(handler: Fn) -> Self {
            return Self {
                recognizer: GestureRecognizer::new(GESTURE_PAN, handler),
                min_distance: 10.0
            };
        }
    }

    pub class PinchRecognizer {
        pub let recognizer: GestureRecognizer;

        pub fn new(handler: Fn) -> Self {
            return Self {
                recognizer: GestureRecognizer::new(GESTURE_PINCH, handler)
            };
        }
    }

    pub class SwipeRecognizer {
        pub let recognizer: GestureRecognizer;
        pub let min_velocity: Float;
        pub let directions: List<String>;

        pub fn new(handler: Fn) -> Self {
            return Self {
                recognizer: GestureRecognizer::new(GESTURE_SWIPE, handler),
                min_velocity: 300.0,
                directions: ["left", "right", "up", "down"]
            };
        }
    }

    pub class GestureArena {
        pub let recognizers: List<GestureRecognizer>;
        pub let active_recognizer: GestureRecognizer?;

        pub fn new() -> Self {
            return Self { recognizers: [], active_recognizer: null };
        }

        pub fn add(self, recognizer: GestureRecognizer) {
            self.recognizers.push(recognizer);
        }

        pub fn process_touch(self, touch_event: Any) {
            # Gesture disambiguation - only one recognizer wins
            for rec in self.recognizers {
                if not rec.enabled { continue; }
                # Native gesture matching
                if native_gesture_matches(rec.gesture_type, touch_event) {
                    self.active_recognizer = rec;
                    rec.handler(touch_event);
                    break;
                }
            }
        }

        pub fn reset(self) {
            self.active_recognizer = null;
        }
    }
}

# ============================================================
# KEYBOARD SHORTCUTS
# ============================================================

pub mod shortcuts {
    pub class Shortcut {
        pub let id: String;
        pub let keys: String;
        pub let handler: Fn;
        pub let enabled: Bool;
        pub let context: String;
        pub let description: String;

        pub fn new(id: String, keys: String, handler: Fn) -> Self {
            return Self {
                id: id,
                keys: keys,
                handler: handler,
                enabled: true,
                context: "global",
                description: ""
            };
        }

        pub fn with_context(self, context: String) -> Self {
            self.context = context;
            return self;
        }

        pub fn with_description(self, desc: String) -> Self {
            self.description = desc;
            return self;
        }
    }

    pub class ShortcutManager {
        pub let shortcuts: Map<String, Shortcut>;
        pub let active_context: String;

        pub fn new() -> Self {
            return Self {
                shortcuts: {},
                active_context: "global"
            };
        }

        pub fn register(self, shortcut: Shortcut) {
            self.shortcuts[shortcut.id] = shortcut;
        }

        pub fn unregister(self, id: String) {
            self.shortcuts.remove(id);
        }

        pub fn set_context(self, context: String) {
            self.active_context = context;
        }

        pub fn handle_key(self, key_event: core.Event) -> Bool {
            let key_combo = self._build_combo(key_event);
            for entry in self.shortcuts.entries() {
                let shortcut = entry.value;
                if not shortcut.enabled { continue; }
                if shortcut.keys == key_combo {
                    if shortcut.context == "global" or shortcut.context == self.active_context {
                        shortcut.handler(key_event);
                        return true;
                    }
                }
            }
            return false;
        }

        fn _build_combo(self, event: core.Event) -> String {
            let parts = [];
            if event.data.ctrl { parts.push("Ctrl"); }
            if event.data.shift { parts.push("Shift"); }
            if event.data.alt { parts.push("Alt"); }
            if event.data.meta { parts.push("Meta"); }
            parts.push(event.data.key);
            return parts.join("+");
        }

        pub fn list(self) -> List<Shortcut> {
            let result = [];
            for entry in self.shortcuts.entries() {
                result.push(entry.value);
            }
            return result;
        }
    }
}

# ============================================================
# COMMAND PATTERN
# ============================================================

pub mod commands {
    pub class Command {
        pub let id: String;
        pub let name: String;
        pub let execute: Fn;
        pub let undo: Fn?;
        pub let can_undo: Bool;

        pub fn new(id: String, name: String, execute: Fn) -> Self {
            return Self {
                id: id,
                name: name,
                execute: execute,
                undo: null,
                can_undo: false
            };
        }

        pub fn with_undo(self, undo_fn: Fn) -> Self {
            self.undo = undo_fn;
            self.can_undo = true;
            return self;
        }
    }

    pub class CommandHistory {
        pub let stack: List<Command>;
        pub let redo_stack: List<Command>;
        pub let max_size: Int;

        pub fn new(max_size: Int) -> Self {
            return Self { stack: [], redo_stack: [], max_size: max_size };
        }

        pub fn execute(self, command: Command) {
            command.execute();
            if command.can_undo {
                self.stack.push(command);
                if self.stack.len() > self.max_size {
                    self.stack.remove(0);
                }
                self.redo_stack = [];
            }
        }

        pub fn undo(self) -> Bool {
            if self.stack.len() == 0 { return false; }
            let command = self.stack.pop();
            if command.undo != null {
                command.undo();
                self.redo_stack.push(command);
            }
            return true;
        }

        pub fn redo(self) -> Bool {
            if self.redo_stack.len() == 0 { return false; }
            let command = self.redo_stack.pop();
            command.execute();
            self.stack.push(command);
            return true;
        }

        pub fn can_undo(self) -> Bool {
            return self.stack.len() > 0;
        }

        pub fn can_redo(self) -> Bool {
            return self.redo_stack.len() > 0;
        }

        pub fn clear(self) {
            self.stack = [];
            self.redo_stack = [];
        }
    }

    pub class CommandPalette {
        pub let commands: Map<String, Command>;

        pub fn new() -> Self {
            return Self { commands: {} };
        }

        pub fn register(self, command: Command) {
            self.commands[command.id] = command;
        }

        pub fn execute(self, id: String) -> Bool {
            let cmd = self.commands[id];
            if cmd == null { return false; }
            cmd.execute();
            return true;
        }

        pub fn search(self, query: String) -> List<Command> {
            let results = [];
            let query_lower = query.to_lower();
            for entry in self.commands.entries() {
                if entry.value.name.to_lower().contains(query_lower) {
                    results.push(entry.value);
                }
            }
            return results;
        }
    }
}

# ============================================================
# ASYNC EVENT STREAMS
# ============================================================

pub mod streams {
    pub class EventStream {
        pub let source_type: String;
        pub let handlers: List<Fn>;
        pub let transforms: List<Fn>;
        pub let active: Bool;

        pub fn from_event(event_type: String) -> Self {
            return Self {
                source_type: event_type,
                handlers: [],
                transforms: [],
                active: true
            };
        }

        pub fn map(self, transform: Fn) -> Self {
            self.transforms.push(transform);
            return self;
        }

        pub fn filter(self, predicate: Fn) -> Self {
            self.transforms.push(|event| {
                if predicate(event) { return event; }
                return null;
            });
            return self;
        }

        pub fn debounce(self, ms: Int) -> Self {
            let debouncer = timing.Debouncer::new(ms, |event| {
                self._emit_to_handlers(event);
            });
            self.transforms.push(|event| {
                debouncer.call(event);
                return null;
            });
            return self;
        }

        pub fn throttle(self, ms: Int) -> Self {
            let throttle = timing.Throttle::new(ms, |event| {
                self._emit_to_handlers(event);
            });
            self.transforms.push(|event| {
                throttle.call(event);
                return null;
            });
            return self;
        }

        pub fn take(self, count: Int) -> Self {
            let remaining = count;
            self.transforms.push(|event| {
                if remaining <= 0 {
                    self.active = false;
                    return null;
                }
                remaining = remaining - 1;
                return event;
            });
            return self;
        }

        pub fn subscribe(self, handler: Fn) {
            self.handlers.push(handler);
        }

        pub fn dispose(self) {
            self.active = false;
            self.handlers = [];
        }

        fn _emit_to_handlers(self, event: Any) {
            for handler in self.handlers {
                handler(event);
            }
        }

        pub fn _process(self, event: Any) {
            if not self.active { return; }
            let current = event;
            for transform in self.transforms {
                current = transform(current);
                if current == null { return; }
            }
            self._emit_to_handlers(current);
        }
    }

    pub class MergedStream {
        pub let sources: List<EventStream>;
        pub let handlers: List<Fn>;

        pub fn merge(streams: List<EventStream>) -> Self {
            let merged = Self { sources: streams, handlers: [] };
            for stream in streams {
                stream.subscribe(|event| {
                    for handler in merged.handlers {
                        handler(event);
                    }
                });
            }
            return merged;
        }

        pub fn subscribe(self, handler: Fn) {
            self.handlers.push(handler);
        }
    }
}

# ============================================================
# EVENT SYSTEM ORCHESTRATOR
# ============================================================

pub class EventSystem {
    pub let dispatcher: dispatch.EventDispatcher;
    pub let bus: bus.EventBus;
    pub let shortcut_manager: shortcuts.ShortcutManager;
    pub let command_history: commands.CommandHistory;
    pub let command_palette: commands.CommandPalette;
    pub let gesture_arena: gestures.GestureArena;

    pub fn new() -> Self {
        return Self {
            dispatcher: dispatch.EventDispatcher::new(),
            bus: bus.EventBus::new(),
            shortcut_manager: shortcuts.ShortcutManager::new(),
            command_history: commands.CommandHistory::new(100),
            command_palette: commands.CommandPalette::new(),
            gesture_arena: gestures.GestureArena::new()
        };
    }

    pub fn on(self, event_type: String, handler: Fn) -> bus.Subscription {
        return self.bus.subscribe(event_type, handler);
    }

    pub fn emit(self, event_type: String, data: Any?) {
        self.bus.publish(core.Event::new(event_type, data));
    }

    pub fn register_shortcut(self, id: String, keys: String, handler: Fn) {
        self.shortcut_manager.register(shortcuts.Shortcut::new(id, keys, handler));
    }

    pub fn register_command(self, id: String, name: String, execute: Fn) {
        self.command_palette.register(commands.Command::new(id, name, execute));
    }

    pub fn execute_command(self, id: String) -> Bool {
        return self.command_palette.execute(id);
    }

    pub fn undo(self) -> Bool {
        return self.command_history.undo();
    }

    pub fn redo(self) -> Bool {
        return self.command_history.redo();
    }
}

pub fn create_event_system() -> EventSystem {
    return EventSystem::new();
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_event_time_ms() -> Int;
native_event_next_id() -> Int;
native_event_defer(func: Fn);
native_timer_create(ms: Int, repeating: Bool, callback: Fn) -> Int;
native_timer_cancel(id: Int);
native_gesture_matches(gesture_type: String, event: Any) -> Bool;

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
