# ============================================================
# NYSTATE - Nyx Reactive State Management Engine
# ============================================================
# Production-grade reactive state with dependency graph tracking,
# computed properties, time-travel debugging, immutable snapshots,
# middleware pipeline, and store composition. Rivals Redux/MobX/Zustand.

let VERSION = "1.0.0";

# ============================================================
# REACTIVE PRIMITIVES
# ============================================================

pub mod reactive {
    pub class Observable {
        pub let id: Int;
        pub let value: Any;
        pub let subscribers: List<Fn>;
        pub let name: String;
        pub let version: Int;

        pub fn new(initial: Any, name: String) -> Self {
            return Self {
                id: native_state_next_id(),
                value: initial,
                subscribers: [],
                name: name,
                version: 0
            };
        }

        pub fn get(self) -> Any {
            # Track dependency if inside a computed context
            native_state_track_dependency(self.id);
            return self.value;
        }

        pub fn set(self, new_value: Any) {
            if self.value == new_value { return; }
            self.value = new_value;
            self.version = self.version + 1;
            self._notify();
        }

        pub fn update(self, updater: Fn) {
            let new_value = updater(self.value);
            self.set(new_value);
        }

        pub fn subscribe(self, callback: Fn) -> Fn {
            self.subscribers.push(callback);
            let unsub = || {
                self.subscribers = self.subscribers.filter(|s| s != callback);
            };
            return unsub;
        }

        fn _notify(self) {
            for sub in self.subscribers {
                sub(self.value);
            }
            native_state_notify_dependents(self.id);
        }
    }

    pub class Computed {
        pub let id: Int;
        pub let compute_fn: Fn;
        pub let cached_value: Any?;
        pub let dirty: Bool;
        pub let dependencies: List<Int>;
        pub let subscribers: List<Fn>;
        pub let name: String;

        pub fn new(compute_fn: Fn, name: String) -> Self {
            let comp = Self {
                id: native_state_next_id(),
                compute_fn: compute_fn,
                cached_value: null,
                dirty: true,
                dependencies: [],
                subscribers: [],
                name: name
            };
            native_state_register_computed(comp.id, comp);
            return comp;
        }

        pub fn get(self) -> Any {
            native_state_track_dependency(self.id);
            if self.dirty {
                self._recompute();
            }
            return self.cached_value;
        }

        fn _recompute(self) {
            native_state_begin_tracking(self.id);
            let new_value = self.compute_fn();
            self.dependencies = native_state_end_tracking(self.id);
            let changed = self.cached_value != new_value;
            self.cached_value = new_value;
            self.dirty = false;
            if changed {
                for sub in self.subscribers {
                    sub(new_value);
                }
            }
        }

        pub fn invalidate(self) {
            self.dirty = true;
        }

        pub fn subscribe(self, callback: Fn) -> Fn {
            self.subscribers.push(callback);
            return || {
                self.subscribers = self.subscribers.filter(|s| s != callback);
            };
        }
    }

    pub class Effect {
        pub let id: Int;
        pub let effect_fn: Fn;
        pub let cleanup_fn: Fn?;
        pub let dependencies: List<Int>;
        pub let active: Bool;
        pub let name: String;

        pub fn new(effect_fn: Fn, name: String) -> Self {
            let eff = Self {
                id: native_state_next_id(),
                effect_fn: effect_fn,
                cleanup_fn: null,
                dependencies: [],
                active: true,
                name: name
            };
            native_state_register_effect(eff.id, eff);
            eff._run();
            return eff;
        }

        fn _run(self) {
            if not self.active { return; }
            if self.cleanup_fn != null {
                self.cleanup_fn();
            }
            native_state_begin_tracking(self.id);
            self.cleanup_fn = self.effect_fn();
            self.dependencies = native_state_end_tracking(self.id);
        }

        pub fn dispose(self) {
            self.active = false;
            if self.cleanup_fn != null {
                self.cleanup_fn();
            }
            native_state_unregister_effect(self.id);
        }

        pub fn trigger(self) {
            self._run();
        }
    }

    pub class Batch {
        pub fn run(func: Fn) {
            native_state_begin_batch();
            func();
            native_state_end_batch();
        }
    }
}

# ============================================================
# STORE
# ============================================================

pub mod store {
    pub class StoreConfig {
        pub let name: String;
        pub let persistence: Bool;
        pub let persistence_key: String;
        pub let history_enabled: Bool;
        pub let history_limit: Int;
        pub let strict_mode: Bool;
        pub let devtools: Bool;

        pub fn new(name: String) -> Self {
            return Self {
                name: name,
                persistence: false,
                persistence_key: "",
                history_enabled: false,
                history_limit: 100,
                strict_mode: false,
                devtools: false
            };
        }

        pub fn with_persistence(self, key: String) -> Self {
            self.persistence = true;
            self.persistence_key = key;
            return self;
        }

        pub fn with_history(self, limit: Int) -> Self {
            self.history_enabled = true;
            self.history_limit = limit;
            return self;
        }

        pub fn with_devtools(self) -> Self {
            self.devtools = true;
            return self;
        }

        pub fn with_strict(self) -> Self {
            self.strict_mode = true;
            return self;
        }
    }

    pub class Mutation {
        pub let id: Int;
        pub let timestamp_ms: Int;
        pub let path: String;
        pub let old_value: Any;
        pub let new_value: Any;
        pub let action: String;

        pub fn new(path: String, old_value: Any, new_value: Any, action: String) -> Self {
            return Self {
                id: native_state_next_id(),
                timestamp_ms: native_state_time_ms(),
                path: path,
                old_value: old_value,
                new_value: new_value,
                action: action
            };
        }
    }

    pub class Store {
        pub let config: StoreConfig;
        pub let state: Map<String, reactive.Observable>;
        pub let computed: Map<String, reactive.Computed>;
        pub let actions: Map<String, Fn>;
        pub let middleware: List<Fn>;
        pub let history: List<Mutation>;
        pub let history_index: Int;
        pub let subscribers: List<Fn>;
        pub let getters: Map<String, Fn>;

        pub fn new(config: StoreConfig) -> Self {
            let s = Self {
                config: config,
                state: {},
                computed: {},
                actions: {},
                middleware: [],
                history: [],
                history_index: -1,
                subscribers: [],
                getters: {}
            };

            if config.persistence {
                s._load_persisted();
            }

            return s;
        }

        # State management
        pub fn define(self, key: String, initial: Any) -> reactive.Observable {
            let obs = reactive.Observable::new(initial, key);
            self.state[key] = obs;
            return obs;
        }

        pub fn get(self, key: String) -> Any {
            let obs = self.state[key];
            if obs == null { return null; }
            return obs.get();
        }

        pub fn set(self, key: String, value: Any) {
            if self.config.strict_mode {
                if not native_state_in_action() {
                    panic("Cannot mutate state outside of an action in strict mode");
                }
            }

            let obs = self.state[key];
            if obs == null { return; }

            let old = obs.value;

            # Run middleware
            let ctx = { "key": key, "old": old, "new": value, "store": self };
            for mw in self.middleware {
                let result = mw(ctx);
                if result == false { return; }
                if result != null and result != true {
                    value = result;
                }
            }

            obs.set(value);

            # Record mutation
            if self.config.history_enabled {
                let mutation = Mutation::new(key, old, value, "set");
                # Truncate history if we've gone back in time
                if self.history_index < self.history.len() - 1 {
                    self.history = self.history.slice(0, self.history_index + 1);
                }
                self.history.push(mutation);
                if self.history.len() > self.config.history_limit {
                    self.history.remove(0);
                }
                self.history_index = self.history.len() - 1;
            }

            # Persistence
            if self.config.persistence {
                self._persist();
            }

            # Notify store subscribers
            for sub in self.subscribers {
                sub(key, value);
            }
        }

        pub fn update(self, key: String, updater: Fn) {
            let current = self.get(key);
            self.set(key, updater(current));
        }

        # Getters (derived state without reactive tracking)
        pub fn define_getter(self, name: String, getter_fn: Fn) {
            self.getters[name] = getter_fn;
        }

        pub fn getter(self, name: String) -> Any {
            let fn_ref = self.getters[name];
            if fn_ref == null { return null; }
            return fn_ref(self);
        }

        # Computed properties
        pub fn define_computed(self, name: String, compute_fn: Fn) -> reactive.Computed {
            let comp = reactive.Computed::new(compute_fn, name);
            self.computed[name] = comp;
            return comp;
        }

        pub fn computed_value(self, name: String) -> Any {
            let comp = self.computed[name];
            if comp == null { return null; }
            return comp.get();
        }

        # Actions
        pub fn define_action(self, name: String, action_fn: Fn) {
            self.actions[name] = action_fn;
        }

        pub fn dispatch(self, action_name: String, payload: Any?) -> Any {
            let action = self.actions[action_name];
            if action == null { return null; }

            native_state_enter_action();
            reactive.Batch::run(|| {
                action(self, payload);
            });
            native_state_exit_action();
            return null;
        }

        # Middleware
        pub fn use_middleware(self, middleware_fn: Fn) {
            self.middleware.push(middleware_fn);
        }

        # Subscriptions
        pub fn subscribe(self, callback: Fn) -> Fn {
            self.subscribers.push(callback);
            return || {
                self.subscribers = self.subscribers.filter(|s| s != callback);
            };
        }

        pub fn watch(self, key: String, callback: Fn) -> Fn {
            let obs = self.state[key];
            if obs == null { return || {}; }
            return obs.subscribe(callback);
        }

        # Persistence
        fn _persist(self) {
            let snapshot = {};
            for entry in self.state.entries() {
                snapshot[entry.key] = entry.value.value;
            }
            native_state_persist(self.config.persistence_key, snapshot);
        }

        fn _load_persisted(self) {
            let data = native_state_load_persisted(self.config.persistence_key);
            if data == null { return; }
            for entry in data.entries() {
                if self.state[entry.key] != null {
                    self.state[entry.key].value = entry.value;
                }
            }
        }

        # Snapshot
        pub fn snapshot(self) -> Map<String, Any> {
            let snap = {};
            for entry in self.state.entries() {
                snap[entry.key] = entry.value.value;
            }
            return snap;
        }

        pub fn restore(self, snapshot: Map<String, Any>) {
            reactive.Batch::run(|| {
                for entry in snapshot.entries() {
                    self.set(entry.key, entry.value);
                }
            });
        }

        pub fn reset(self) {
            self.history = [];
            self.history_index = -1;
        }
    }
}

# ============================================================
# TIME-TRAVEL DEBUGGING
# ============================================================

pub mod timetravel {
    pub class TimeTravelDebugger {
        pub let store_ref: store.Store;
        pub let snapshots: List<Map<String, Any>>;
        pub let labels: List<String>;
        pub let current_index: Int;
        pub let recording: Bool;

        pub fn new(store_ref: store.Store) -> Self {
            return Self {
                store_ref: store_ref,
                snapshots: [],
                labels: [],
                current_index: -1,
                recording: true
            };
        }

        pub fn checkpoint(self, label: String) {
            if not self.recording { return; }
            # Truncate forward history
            if self.current_index < self.snapshots.len() - 1 {
                self.snapshots = self.snapshots.slice(0, self.current_index + 1);
                self.labels = self.labels.slice(0, self.current_index + 1);
            }
            self.snapshots.push(self.store_ref.snapshot());
            self.labels.push(label);
            self.current_index = self.snapshots.len() - 1;
        }

        pub fn go_to(self, index: Int) {
            if index < 0 or index >= self.snapshots.len() { return; }
            self.current_index = index;
            self.store_ref.restore(self.snapshots[index]);
        }

        pub fn undo(self) -> Bool {
            if self.current_index <= 0 { return false; }
            self.go_to(self.current_index - 1);
            return true;
        }

        pub fn redo(self) -> Bool {
            if self.current_index >= self.snapshots.len() - 1 { return false; }
            self.go_to(self.current_index + 1);
            return true;
        }

        pub fn can_undo(self) -> Bool {
            return self.current_index > 0;
        }

        pub fn can_redo(self) -> Bool {
            return self.current_index < self.snapshots.len() - 1;
        }

        pub fn history(self) -> List<String> {
            return self.labels;
        }

        pub fn current_label(self) -> String {
            if self.current_index < 0 { return ""; }
            return self.labels[self.current_index];
        }

        pub fn clear(self) {
            self.snapshots = [];
            self.labels = [];
            self.current_index = -1;
        }

        pub fn pause(self) {
            self.recording = false;
        }

        pub fn resume(self) {
            self.recording = true;
        }

        pub fn export_timeline(self) -> String {
            return native_state_serialize(self.snapshots);
        }

        pub fn import_timeline(self, data: String) {
            let imported = native_state_deserialize(data);
            self.snapshots = imported.snapshots;
            self.labels = imported.labels;
            self.current_index = imported.snapshots.len() - 1;
        }
    }
}

# ============================================================
# STORE COMPOSITION
# ============================================================

pub mod compose {
    pub class ModuleDefinition {
        pub let name: String;
        pub let initial_state: Map<String, Any>;
        pub let actions: Map<String, Fn>;
        pub let getters: Map<String, Fn>;

        pub fn new(name: String) -> Self {
            return Self {
                name: name,
                initial_state: {},
                actions: {},
                getters: {}
            };
        }

        pub fn state(self, key: String, value: Any) -> Self {
            self.initial_state[key] = value;
            return self;
        }

        pub fn action(self, name: String, action_fn: Fn) -> Self {
            self.actions[name] = action_fn;
            return self;
        }

        pub fn getter(self, name: String, getter_fn: Fn) -> Self {
            self.getters[name] = getter_fn;
            return self;
        }
    }

    pub class ComposedStore {
        pub let modules: Map<String, store.Store>;
        pub let root: store.Store;

        pub fn new(root_config: store.StoreConfig) -> Self {
            return Self {
                modules: {},
                root: store.Store::new(root_config)
            };
        }

        pub fn add_module(self, definition: ModuleDefinition) {
            let config = store.StoreConfig::new(definition.name);
            let mod_store = store.Store::new(config);

            for entry in definition.initial_state.entries() {
                mod_store.define(entry.key, entry.value);
            }
            for entry in definition.actions.entries() {
                mod_store.define_action(entry.key, entry.value);
            }
            for entry in definition.getters.entries() {
                mod_store.define_getter(entry.key, entry.value);
            }

            self.modules[definition.name] = mod_store;
        }

        pub fn module(self, name: String) -> store.Store? {
            return self.modules[name];
        }

        pub fn get(self, module_name: String, key: String) -> Any {
            let mod_store = self.modules[module_name];
            if mod_store == null { return null; }
            return mod_store.get(key);
        }

        pub fn dispatch(self, module_name: String, action: String, payload: Any?) {
            let mod_store = self.modules[module_name];
            if mod_store == null { return; }
            mod_store.dispatch(action, payload);
        }

        pub fn snapshot_all(self) -> Map<String, Map<String, Any>> {
            let result = {};
            result["root"] = self.root.snapshot();
            for entry in self.modules.entries() {
                result[entry.key] = entry.value.snapshot();
            }
            return result;
        }

        pub fn restore_all(self, snapshots: Map<String, Map<String, Any>>) {
            if snapshots["root"] != null {
                self.root.restore(snapshots["root"]);
            }
            for entry in self.modules.entries() {
                if snapshots[entry.key] != null {
                    entry.value.restore(snapshots[entry.key]);
                }
            }
        }
    }
}

# ============================================================
# MIDDLEWARE LIBRARY
# ============================================================

pub mod middleware {
    pub fn logger() -> Fn {
        return |ctx| {
            native_state_log("STATE", ctx.key + ": " + ctx.old as String + " -> " + ctx.new as String);
            return true;
        };
    }

    pub fn validator(rules: Map<String, Fn>) -> Fn {
        return |ctx| {
            let rule = rules[ctx.key];
            if rule == null { return true; }
            return rule(ctx.new);
        };
    }

    pub fn freezer() -> Fn {
        return |ctx| {
            return native_state_deep_freeze(ctx.new);
        };
    }

    pub fn throttle(interval_ms: Int) -> Fn {
        let last_times = {};
        return |ctx| {
            let now = native_state_time_ms();
            let last = last_times[ctx.key] or 0;
            if now - last < interval_ms { return false; }
            last_times[ctx.key] = now;
            return true;
        };
    }

    pub fn persistence_sync(storage_key: String) -> Fn {
        return |ctx| {
            native_state_persist_key(storage_key, ctx.key, ctx.new);
            return true;
        };
    }

    pub fn undo_recorder(history: List<store.Mutation>) -> Fn {
        return |ctx| {
            history.push(store.Mutation::new(ctx.key, ctx.old, ctx.new, "middleware"));
            return true;
        };
    }
}

# ============================================================
# BINDINGS (UI INTEGRATION)
# ============================================================

pub mod bindings {
    pub class Binding {
        pub let source: reactive.Observable;
        pub let target_id: String;
        pub let property: String;
        pub let transform: Fn?;
        pub let unsubscribe: Fn?;

        pub fn new(source: reactive.Observable, target_id: String, property: String) -> Self {
            let binding = Self {
                source: source,
                target_id: target_id,
                property: property,
                transform: null,
                unsubscribe: null
            };
            binding._activate();
            return binding;
        }

        pub fn with_transform(self, transform: Fn) -> Self {
            self.transform = transform;
            return self;
        }

        fn _activate(self) {
            self.unsubscribe = self.source.subscribe(|value| {
                let final_value = value;
                if self.transform != null {
                    final_value = self.transform(value);
                }
                native_state_update_ui(self.target_id, self.property, final_value);
            });
        }

        pub fn dispose(self) {
            if self.unsubscribe != null {
                self.unsubscribe();
            }
        }
    }

    pub class TwoWayBinding {
        pub let source: reactive.Observable;
        pub let target_id: String;
        pub let property: String;
        pub let forward_unsub: Fn?;

        pub fn new(source: reactive.Observable, target_id: String, property: String) -> Self {
            let binding = Self {
                source: source,
                target_id: target_id,
                property: property,
                forward_unsub: null
            };
            binding._activate();
            return binding;
        }

        fn _activate(self) {
            # Source -> UI
            self.forward_unsub = self.source.subscribe(|value| {
                native_state_update_ui(self.target_id, self.property, value);
            });
            # UI -> Source
            native_state_bind_ui_change(self.target_id, self.property, |value| {
                self.source.set(value);
            });
        }

        pub fn dispose(self) {
            if self.forward_unsub != null {
                self.forward_unsub();
            }
            native_state_unbind_ui_change(self.target_id, self.property);
        }
    }
}

# ============================================================
# DEVTOOLS
# ============================================================

pub mod devtools {
    pub class StateInspector {
        pub let store_ref: store.Store;
        pub let time_travel: timetravel.TimeTravelDebugger;
        pub let mutation_log: List<store.Mutation>;
        pub let performance_marks: Map<String, Float>;

        pub fn new(store_ref: store.Store) -> Self {
            let inspector = Self {
                store_ref: store_ref,
                time_travel: timetravel.TimeTravelDebugger::new(store_ref),
                mutation_log: [],
                performance_marks: {}
            };

            # Auto-record mutations
            store_ref.use_middleware(middleware.undo_recorder(inspector.mutation_log));

            return inspector;
        }

        pub fn state_tree(self) -> Map<String, Any> {
            return self.store_ref.snapshot();
        }

        pub fn mutation_count(self) -> Int {
            return self.mutation_log.len();
        }

        pub fn recent_mutations(self, count: Int) -> List<store.Mutation> {
            let start = self.mutation_log.len() - count;
            if start < 0 { start = 0; }
            return self.mutation_log.slice(start, self.mutation_log.len());
        }

        pub fn dependency_graph(self) -> Map<String, List<String>> {
            return native_state_dependency_graph();
        }

        pub fn performance_report(self) -> Map<String, Float> {
            return self.performance_marks;
        }

        pub fn export_state(self) -> String {
            return native_state_serialize(self.store_ref.snapshot());
        }

        pub fn import_state(self, data: String) {
            let snapshot = native_state_deserialize(data);
            self.store_ref.restore(snapshot);
        }
    }
}

# ============================================================
# CONVENIENCE API
# ============================================================

pub fn create_store(name: String) -> store.Store {
    return store.Store::new(store.StoreConfig::new(name));
}

pub fn create_store_with_config(config: store.StoreConfig) -> store.Store {
    return store.Store::new(config);
}

pub fn observable(initial: Any, name: String) -> reactive.Observable {
    return reactive.Observable::new(initial, name);
}

pub fn computed(compute_fn: Fn, name: String) -> reactive.Computed {
    return reactive.Computed::new(compute_fn, name);
}

pub fn effect(effect_fn: Fn, name: String) -> reactive.Effect {
    return reactive.Effect::new(effect_fn, name);
}

pub fn batch(func: Fn) {
    reactive.Batch::run(func);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_state_next_id() -> Int;
native_state_time_ms() -> Int;
native_state_track_dependency(id: Int);
native_state_notify_dependents(id: Int);
native_state_register_computed(id: Int, comp: Any);
native_state_register_effect(id: Int, eff: Any);
native_state_unregister_effect(id: Int);
native_state_begin_tracking(id: Int);
native_state_end_tracking(id: Int) -> List;
native_state_begin_batch();
native_state_end_batch();
native_state_enter_action();
native_state_exit_action();
native_state_in_action() -> Bool;
native_state_persist(key: String, data: Any);
native_state_load_persisted(key: String) -> Any;
native_state_persist_key(storage_key: String, key: String, value: Any);
native_state_serialize(data: Any) -> String;
native_state_deserialize(data: String) -> Any;
native_state_deep_freeze(value: Any) -> Any;
native_state_log(tag: String, msg: String);
native_state_dependency_graph() -> Map;
native_state_update_ui(target_id: String, property: String, value: Any);
native_state_bind_ui_change(target_id: String, property: String, callback: Fn);
native_state_unbind_ui_change(target_id: String, property: String);

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
