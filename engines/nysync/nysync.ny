# ============================================================
# NYSYNC - Nyx Distributed State Synchronization Engine
# ============================================================
# CRDTs, consensus algorithms, deterministic state merging,
# vector clocks, causal ordering, and partition-tolerant sync.

let VERSION = "1.0.0";

# ============================================================
# VECTOR CLOCKS & CAUSAL ORDERING
# ============================================================

pub mod clocks {
    pub class VectorClock {
        pub let entries: Map<String, Int>;

        pub fn new() -> Self {
            return Self { entries: {} };
        }

        pub fn increment(self, node_id: String) {
            self.entries[node_id] = self.entries.get(node_id, 0) + 1;
        }

        pub fn merge(self, other: VectorClock) {
            for k, v in other.entries {
                self.entries[k] = max(self.entries.get(k, 0), v);
            }
        }

        pub fn happens_before(self, other: VectorClock) -> Bool {
            let dominated = false;
            for k, v in self.entries {
                if v > other.entries.get(k, 0) { return false; }
                if v < other.entries.get(k, 0) { dominated = true; }
            }
            for k, v in other.entries {
                if !self.entries.contains_key(k) && v > 0 { dominated = true; }
            }
            return dominated;
        }

        pub fn concurrent(self, other: VectorClock) -> Bool {
            return !self.happens_before(other) && !other.happens_before(self) && self != other;
        }

        pub fn clone(self) -> VectorClock {
            let c = VectorClock::new();
            for k, v in self.entries { c.entries[k] = v; }
            return c;
        }
    }

    pub class HybridLogicalClock {
        pub let physical: Int;
        pub let logical: Int;
        pub let node_id: String;

        pub fn new(node_id: String) -> Self {
            return Self { physical: 0, logical: 0, node_id: node_id };
        }

        pub fn now(self) -> Self {
            let wall = native_sync_wall_clock();
            if wall > self.physical {
                self.physical = wall;
                self.logical = 0;
            } else {
                self.logical = self.logical + 1;
            }
            return self;
        }

        pub fn receive(self, other_physical: Int, other_logical: Int) {
            let wall = native_sync_wall_clock();
            if wall > self.physical && wall > other_physical {
                self.physical = wall;
                self.logical = 0;
            } else if self.physical == other_physical {
                self.logical = max(self.logical, other_logical) + 1;
            } else if self.physical > other_physical {
                self.logical = self.logical + 1;
            } else {
                self.physical = other_physical;
                self.logical = other_logical + 1;
            }
        }

        pub fn compare(self, other_physical: Int, other_logical: Int) -> Int {
            if self.physical != other_physical { return self.physical - other_physical; }
            return self.logical - other_logical;
        }
    }
}

# ============================================================
# CRDTs - CONFLICT-FREE REPLICATED DATA TYPES
# ============================================================

pub mod crdt {
    pub class GCounter {
        pub let counts: Map<String, Int>;

        pub fn new() -> Self {
            return Self { counts: {} };
        }

        pub fn increment(self, node_id: String) {
            self.counts[node_id] = self.counts.get(node_id, 0) + 1;
        }

        pub fn value(self) -> Int {
            let total = 0;
            for v in self.counts.values() { total = total + v; }
            return total;
        }

        pub fn merge(self, other: GCounter) {
            for k, v in other.counts {
                self.counts[k] = max(self.counts.get(k, 0), v);
            }
        }
    }

    pub class PNCounter {
        pub let positive: GCounter;
        pub let negative: GCounter;

        pub fn new() -> Self {
            return Self { positive: GCounter::new(), negative: GCounter::new() };
        }

        pub fn increment(self, node_id: String) { self.positive.increment(node_id); }
        pub fn decrement(self, node_id: String) { self.negative.increment(node_id); }
        pub fn value(self) -> Int { return self.positive.value() - self.negative.value(); }

        pub fn merge(self, other: PNCounter) {
            self.positive.merge(other.positive);
            self.negative.merge(other.negative);
        }
    }

    pub class GSet {
        pub let elements: Set<Any>;

        pub fn new() -> Self { return Self { elements: {} }; }
        pub fn add(self, elem: Any) { self.elements.add(elem); }
        pub fn contains(self, elem: Any) -> Bool { return self.elements.contains(elem); }
        pub fn merge(self, other: GSet) { self.elements = self.elements.union(other.elements); }
        pub fn value(self) -> Set<Any> { return self.elements; }
    }

    pub class ORSet {
        pub let elements: Map<Any, Set<String>>;
        pub let tombstones: Map<Any, Set<String>>;

        pub fn new() -> Self {
            return Self { elements: {}, tombstones: {} };
        }

        pub fn add(self, elem: Any, tag: String) {
            if !self.elements.contains_key(elem) { self.elements[elem] = {}; }
            self.elements[elem].add(tag);
        }

        pub fn remove(self, elem: Any) {
            if self.elements.contains_key(elem) {
                if !self.tombstones.contains_key(elem) { self.tombstones[elem] = {}; }
                self.tombstones[elem] = self.tombstones[elem].union(self.elements[elem]);
                self.elements.remove(elem);
            }
        }

        pub fn contains(self, elem: Any) -> Bool {
            if !self.elements.contains_key(elem) { return false; }
            let active = self.elements[elem];
            let removed = self.tombstones.get(elem, {});
            return active.difference(removed).len() > 0;
        }

        pub fn merge(self, other: ORSet) {
            for elem, tags in other.elements {
                if !self.elements.contains_key(elem) { self.elements[elem] = {}; }
                self.elements[elem] = self.elements[elem].union(tags);
            }
            for elem, tags in other.tombstones {
                if !self.tombstones.contains_key(elem) { self.tombstones[elem] = {}; }
                self.tombstones[elem] = self.tombstones[elem].union(tags);
            }
        }
    }

    pub class LWWRegister {
        pub let value: Any?;
        pub let timestamp: Int;
        pub let node_id: String;

        pub fn new(node_id: String) -> Self {
            return Self { value: null, timestamp: 0, node_id: node_id };
        }

        pub fn set(self, value: Any, ts: Int) {
            if ts > self.timestamp {
                self.value = value;
                self.timestamp = ts;
            }
        }

        pub fn merge(self, other: LWWRegister) {
            if other.timestamp > self.timestamp {
                self.value = other.value;
                self.timestamp = other.timestamp;
                self.node_id = other.node_id;
            }
        }
    }

    pub class LWWMap {
        pub let entries: Map<String, LWWRegister>;

        pub fn new(node_id: String) -> Self {
            return Self { entries: {} };
        }

        pub fn set(self, key: String, value: Any, ts: Int, node_id: String) {
            if !self.entries.contains_key(key) {
                self.entries[key] = LWWRegister::new(node_id);
            }
            self.entries[key].set(value, ts);
        }

        pub fn get(self, key: String) -> Any? {
            if !self.entries.contains_key(key) { return null; }
            return self.entries[key].value;
        }

        pub fn merge(self, other: LWWMap) {
            for k, reg in other.entries {
                if !self.entries.contains_key(k) {
                    self.entries[k] = reg;
                } else {
                    self.entries[k].merge(reg);
                }
            }
        }
    }
}

# ============================================================
# ANTI-ENTROPY & GOSSIP PROTOCOL
# ============================================================

pub mod gossip {
    pub class GossipConfig {
        pub let fanout: Int;
        pub let interval_ms: Int;
        pub let max_transmissions: Int;

        pub fn new() -> Self {
            return Self { fanout: 3, interval_ms: 200, max_transmissions: 10 };
        }
    }

    pub class GossipMessage {
        pub let key: String;
        pub let value: Any;
        pub let version: Int;
        pub let origin: String;
        pub let ttl: Int;
    }

    pub class GossipProtocol {
        pub let node_id: String;
        pub let config: GossipConfig;
        pub let state: Map<String, Any>;
        pub let versions: Map<String, Int>;
        pub let peers: List<String>;

        pub fn new(node_id: String, config: GossipConfig) -> Self {
            return Self {
                node_id: node_id, config: config,
                state: {}, versions: {}, peers: []
            };
        }

        pub fn update(self, key: String, value: Any) {
            self.state[key] = value;
            self.versions[key] = self.versions.get(key, 0) + 1;
        }

        pub fn gossip_round(self) -> List<GossipMessage> {
            let targets = self._select_peers();
            let messages = [];
            for key, value in self.state {
                for target in targets {
                    messages.append(GossipMessage {
                        key: key, value: value,
                        version: self.versions[key],
                        origin: self.node_id,
                        ttl: self.config.max_transmissions
                    });
                }
            }
            return messages;
        }

        pub fn receive(self, msg: GossipMessage) -> Bool {
            let current = self.versions.get(msg.key, 0);
            if msg.version > current {
                self.state[msg.key] = msg.value;
                self.versions[msg.key] = msg.version;
                return true;
            }
            return false;
        }

        fn _select_peers(self) -> List<String> {
            let shuffled = self.peers.clone();
            native_sync_shuffle(shuffled);
            return shuffled.slice(0, self.config.fanout.min(shuffled.len()));
        }
    }
}

# ============================================================
# REPLICATION LOG & EVENT SOURCING
# ============================================================

pub mod replication {
    pub class LogEntry {
        pub let sequence: Int;
        pub let term: Int;
        pub let operation: String;
        pub let key: String;
        pub let value: Any;
        pub let timestamp: Int;
        pub let node_id: String;
    }

    pub class ReplicationLog {
        pub let entries: List<LogEntry>;
        pub let committed_idx: Int;
        pub let applied_idx: Int;

        pub fn new() -> Self {
            return Self { entries: [], committed_idx: -1, applied_idx: -1 };
        }

        pub fn append(self, entry: LogEntry) -> Int {
            self.entries.append(entry);
            return self.entries.len() - 1;
        }

        pub fn commit(self, idx: Int) {
            if idx > self.committed_idx { self.committed_idx = idx; }
        }

        pub fn get_uncommitted(self) -> List<LogEntry> {
            return self.entries.slice(self.committed_idx + 1, self.entries.len());
        }

        pub fn get_since(self, sequence: Int) -> List<LogEntry> {
            return self.entries.filter(|e| e.sequence > sequence);
        }

        pub fn snapshot(self) -> Map<String, Any> {
            let state = {};
            for i in 0..self.applied_idx + 1 {
                let e = self.entries[i];
                if e.operation == "set" { state[e.key] = e.value; }
                if e.operation == "delete" { state.remove(e.key); }
            }
            return state;
        }
    }

    pub class StateMachine {
        pub let state: Map<String, Any>;
        pub let log: ReplicationLog;
        pub let version: Int;

        pub fn new() -> Self {
            return Self { state: {}, log: ReplicationLog::new(), version: 0 };
        }

        pub fn apply(self, entry: LogEntry) {
            if entry.operation == "set" {
                self.state[entry.key] = entry.value;
            } else if entry.operation == "delete" {
                self.state.remove(entry.key);
            }
            self.version = self.version + 1;
            self.log.applied_idx = self.log.applied_idx + 1;
        }

        pub fn apply_committed(self) {
            while self.log.applied_idx < self.log.committed_idx {
                let next = self.log.applied_idx + 1;
                self.apply(self.log.entries[next]);
            }
        }
    }
}

# ============================================================
# PARTITION DETECTION & HEALING
# ============================================================

pub mod partition {
    pub class PartitionDetector {
        pub let nodes: Map<String, Int>;
        pub let timeout_ms: Int;

        pub fn new(timeout_ms: Int) -> Self {
            return Self { nodes: {}, timeout_ms: timeout_ms };
        }

        pub fn heartbeat(self, node_id: String) {
            self.nodes[node_id] = native_sync_wall_clock();
        }

        pub fn detect_partitions(self) -> List<List<String>> {
            let now = native_sync_wall_clock();
            let alive = [];
            let dead = [];
            for id, ts in self.nodes {
                if now - ts < self.timeout_ms { alive.append(id); }
                else { dead.append(id); }
            }
            let partitions = [alive];
            if dead.len() > 0 { partitions.append(dead); }
            return partitions;
        }
    }

    pub class PartitionHealer {
        pub let merge_strategy: String;

        pub fn new(strategy: String) -> Self {
            return Self { merge_strategy: strategy };
        }

        pub fn heal(self, local_state: Map<String, Any>, remote_state: Map<String, Any>,
                     local_versions: Map<String, Int>, remote_versions: Map<String, Int>) -> Map<String, Any> {
            let merged = {};
            let all_keys = local_state.keys() + remote_state.keys();
            for key in all_keys {
                let lv = local_versions.get(key, 0);
                let rv = remote_versions.get(key, 0);
                if lv > rv { merged[key] = local_state[key]; }
                else if rv > lv { merged[key] = remote_state[key]; }
                else { merged[key] = local_state.get(key, remote_state[key]); }
            }
            return merged;
        }
    }
}

# ============================================================
# SYNC ENGINE ORCHESTRATOR
# ============================================================

pub class SyncEngine {
    pub let node_id: String;
    pub let clock: clocks.VectorClock;
    pub let hlc: clocks.HybridLogicalClock;
    pub let gossip_proto: gossip.GossipProtocol;
    pub let state_machine: replication.StateMachine;
    pub let partition_detector: partition.PartitionDetector;

    pub fn new(node_id: String) -> Self {
        return Self {
            node_id: node_id,
            clock: clocks.VectorClock::new(),
            hlc: clocks.HybridLogicalClock::new(node_id),
            gossip_proto: gossip.GossipProtocol::new(node_id, gossip.GossipConfig::new()),
            state_machine: replication.StateMachine::new(),
            partition_detector: partition.PartitionDetector::new(5000)
        };
    }

    pub fn set(self, key: String, value: Any) {
        self.clock.increment(self.node_id);
        self.hlc.now();
        let entry = replication.LogEntry {
            sequence: self.state_machine.log.entries.len(),
            term: 0, operation: "set",
            key: key, value: value,
            timestamp: self.hlc.physical,
            node_id: self.node_id
        };
        self.state_machine.log.append(entry);
        self.gossip_proto.update(key, value);
    }

    pub fn get(self, key: String) -> Any? {
        return self.state_machine.state.get(key);
    }

    pub fn sync(self) -> List<gossip.GossipMessage> {
        return self.gossip_proto.gossip_round();
    }
}

pub fn create_sync_engine(node_id: String) -> SyncEngine {
    return SyncEngine::new(node_id);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_sync_wall_clock() -> Int;
native_sync_shuffle(list: List);

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
