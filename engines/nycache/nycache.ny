# ============================================================
# NYCACHE - Nyx Distributed Cache Engine
# ============================================================
# Redis-like in-memory store with TTL, LRU/LFU eviction,
# sharded caching, pub/sub, and persistence snapshots.

let VERSION = "1.0.0";

# ============================================================
# CACHE ENTRY & EVICTION
# ============================================================

pub mod store {
    pub class CacheEntry {
        pub let key: String;
        pub let value: Any;
        pub let ttl_ms: Int;
        pub let created_at: Int;
        pub let last_accessed: Int;
        pub let access_count: Int;
        pub let size_bytes: Int;

        pub fn new(key: String, value: Any, ttl_ms: Int) -> Self {
            let now = native_cache_now();
            return Self {
                key: key, value: value,
                ttl_ms: ttl_ms, created_at: now,
                last_accessed: now, access_count: 1,
                size_bytes: native_cache_sizeof(value)
            };
        }

        pub fn is_expired(self) -> Bool {
            if self.ttl_ms <= 0 { return false; }
            return native_cache_now() - self.created_at > self.ttl_ms;
        }

        pub fn touch(self) {
            self.last_accessed = native_cache_now();
            self.access_count = self.access_count + 1;
        }
    }

    pub class LRUEvictor {
        pub let max_entries: Int;

        pub fn new(max_entries: Int) -> Self {
            return Self { max_entries: max_entries };
        }

        pub fn evict(self, entries: Map<String, CacheEntry>) -> List<String> {
            if entries.len() <= self.max_entries { return []; }
            let sorted = entries.values().sorted_by(|a, b| a.last_accessed - b.last_accessed);
            let to_remove = entries.len() - self.max_entries;
            return sorted.slice(0, to_remove).map(|e| e.key);
        }
    }

    pub class LFUEvictor {
        pub let max_entries: Int;

        pub fn new(max_entries: Int) -> Self {
            return Self { max_entries: max_entries };
        }

        pub fn evict(self, entries: Map<String, CacheEntry>) -> List<String> {
            if entries.len() <= self.max_entries { return []; }
            let sorted = entries.values().sorted_by(|a, b| a.access_count - b.access_count);
            let to_remove = entries.len() - self.max_entries;
            return sorted.slice(0, to_remove).map(|e| e.key);
        }
    }

    pub class TTLEvictor {
        pub fn evict(self, entries: Map<String, CacheEntry>) -> List<String> {
            return entries.values().filter(|e| e.is_expired()).map(|e| e.key);
        }
    }
}

# ============================================================
# IN-MEMORY CACHE
# ============================================================

pub mod cache {
    pub class CacheConfig {
        pub let max_entries: Int;
        pub let default_ttl_ms: Int;
        pub let eviction_policy: String;
        pub let max_memory_mb: Int;

        pub fn new() -> Self {
            return Self {
                max_entries: 100000,
                default_ttl_ms: 0,
                eviction_policy: "lru",
                max_memory_mb: 256
            };
        }
    }

    pub class Cache {
        pub let config: CacheConfig;
        pub let entries: Map<String, store.CacheEntry>;
        pub let stats: CacheStats;
        let lru: store.LRUEvictor;
        let lfu: store.LFUEvictor;
        let ttl_evictor: store.TTLEvictor;

        pub fn new(config: CacheConfig) -> Self {
            return Self {
                config: config,
                entries: {},
                stats: CacheStats::new(),
                lru: store.LRUEvictor::new(config.max_entries),
                lfu: store.LFUEvictor::new(config.max_entries),
                ttl_evictor: store.TTLEvictor::new()
            };
        }

        pub fn get(self, key: String) -> Any? {
            if !self.entries.contains_key(key) {
                self.stats.misses = self.stats.misses + 1;
                return null;
            }
            let entry = self.entries[key];
            if entry.is_expired() {
                self.entries.remove(key);
                self.stats.misses = self.stats.misses + 1;
                return null;
            }
            entry.touch();
            self.stats.hits = self.stats.hits + 1;
            return entry.value;
        }

        pub fn set(self, key: String, value: Any, ttl_ms: Int?) {
            let actual_ttl = ttl_ms ?? self.config.default_ttl_ms;
            self.entries[key] = store.CacheEntry::new(key, value, actual_ttl);
            self._maybe_evict();
        }

        pub fn delete(self, key: String) -> Bool {
            if self.entries.contains_key(key) {
                self.entries.remove(key);
                return true;
            }
            return false;
        }

        pub fn exists(self, key: String) -> Bool {
            if !self.entries.contains_key(key) { return false; }
            if self.entries[key].is_expired() {
                self.entries.remove(key);
                return false;
            }
            return true;
        }

        pub fn incr(self, key: String, delta: Int) -> Int {
            let current = self.get(key) ?? 0;
            let new_val = current + delta;
            self.set(key, new_val, null);
            return new_val;
        }

        pub fn decr(self, key: String, delta: Int) -> Int {
            return self.incr(key, -delta);
        }

        pub fn keys(self, pattern: String) -> List<String> {
            return self.entries.keys().filter(|k| native_cache_match(k, pattern));
        }

        pub fn flush(self) {
            self.entries = {};
            self.stats = CacheStats::new();
        }

        pub fn size(self) -> Int { return self.entries.len(); }

        fn _maybe_evict(self) {
            let expired = self.ttl_evictor.evict(self.entries);
            for key in expired {
                self.entries.remove(key);
                self.stats.evictions = self.stats.evictions + 1;
            }
            let to_evict = if self.config.eviction_policy == "lfu" {
                self.lfu.evict(self.entries)
            } else {
                self.lru.evict(self.entries)
            };
            for key in to_evict {
                self.entries.remove(key);
                self.stats.evictions = self.stats.evictions + 1;
            }
        }
    }

    pub class CacheStats {
        pub let hits: Int;
        pub let misses: Int;
        pub let evictions: Int;

        pub fn new() -> Self {
            return Self { hits: 0, misses: 0, evictions: 0 };
        }

        pub fn hit_rate(self) -> Float {
            let total = self.hits + self.misses;
            if total == 0 { return 0.0; }
            return self.hits.to_float() / total.to_float();
        }
    }
}

# ============================================================
# SHARDING
# ============================================================

pub mod sharding {
    pub class ShardedCache {
        pub let shards: List<cache.Cache>;
        pub let shard_count: Int;

        pub fn new(shard_count: Int, config: cache.CacheConfig) -> Self {
            let shards = [];
            for i in 0..shard_count {
                let shard_config = cache.CacheConfig::new();
                shard_config.max_entries = config.max_entries / shard_count;
                shard_config.eviction_policy = config.eviction_policy;
                shard_config.default_ttl_ms = config.default_ttl_ms;
                shards.append(cache.Cache::new(shard_config));
            }
            return Self { shards: shards, shard_count: shard_count };
        }

        pub fn get(self, key: String) -> Any? {
            return self._shard(key).get(key);
        }

        pub fn set(self, key: String, value: Any, ttl_ms: Int?) {
            self._shard(key).set(key, value, ttl_ms);
        }

        pub fn delete(self, key: String) -> Bool {
            return self._shard(key).delete(key);
        }

        pub fn flush(self) {
            for shard in self.shards { shard.flush(); }
        }

        pub fn total_size(self) -> Int {
            return self.shards.map(|s| s.size()).sum();
        }

        pub fn aggregate_stats(self) -> cache.CacheStats {
            let stats = cache.CacheStats::new();
            for shard in self.shards {
                stats.hits = stats.hits + shard.stats.hits;
                stats.misses = stats.misses + shard.stats.misses;
                stats.evictions = stats.evictions + shard.stats.evictions;
            }
            return stats;
        }

        fn _shard(self, key: String) -> cache.Cache {
            let hash = native_cache_hash(key);
            let idx = hash % self.shard_count;
            return self.shards[idx];
        }
    }
}

# ============================================================
# PUB/SUB
# ============================================================

pub mod pubsub {
    pub class PubSub {
        pub let channels: Map<String, List<Fn(String, Any)>>;

        pub fn new() -> Self {
            return Self { channels: {} };
        }

        pub fn subscribe(self, channel: String, handler: Fn(String, Any)) {
            if !self.channels.contains_key(channel) {
                self.channels[channel] = [];
            }
            self.channels[channel].append(handler);
        }

        pub fn unsubscribe(self, channel: String) {
            self.channels.remove(channel);
        }

        pub fn publish(self, channel: String, message: Any) -> Int {
            if !self.channels.contains_key(channel) { return 0; }
            let handlers = self.channels[channel];
            for handler in handlers {
                handler(channel, message);
            }
            return handlers.len();
        }

        pub fn channels_list(self) -> List<String> {
            return self.channels.keys();
        }

        pub fn subscriber_count(self, channel: String) -> Int {
            if !self.channels.contains_key(channel) { return 0; }
            return self.channels[channel].len();
        }
    }
}

# ============================================================
# PERSISTENCE
# ============================================================

pub mod persistence {
    pub class Snapshot {
        pub let timestamp: Int;
        pub let data: Map<String, Any>;
        pub let checksum: String;

        pub fn new(entries: Map<String, store.CacheEntry>) -> Self {
            let data = {};
            for key, entry in entries {
                if !entry.is_expired() {
                    data[key] = {
                        "value": entry.value,
                        "ttl_ms": entry.ttl_ms,
                        "created_at": entry.created_at
                    };
                }
            }
            let checksum = native_cache_checksum(data);
            return Self { timestamp: native_cache_now(), data: data, checksum: checksum };
        }
    }

    pub class PersistenceManager {
        pub let path: String;
        pub let auto_save_interval_ms: Int;
        pub let last_save: Int;

        pub fn new(path: String) -> Self {
            return Self { path: path, auto_save_interval_ms: 60000, last_save: 0 };
        }

        pub fn save(self, entries: Map<String, store.CacheEntry>) {
            let snap = Snapshot::new(entries);
            native_cache_write(self.path, snap);
            self.last_save = snap.timestamp;
        }

        pub fn load(self) -> Map<String, Any>? {
            let snap = native_cache_read(self.path);
            if snap == null { return null; }
            let verify = native_cache_checksum(snap.data);
            if verify != snap.checksum { return null; }
            return snap.data;
        }

        pub fn should_auto_save(self) -> Bool {
            return native_cache_now() - self.last_save >= self.auto_save_interval_ms;
        }
    }
}

# ============================================================
# DATA STRUCTURES
# ============================================================

pub mod structures {
    pub class CacheList {
        pub let key: String;
        pub let items: List<Any>;

        pub fn new(key: String) -> Self {
            return Self { key: key, items: [] };
        }

        pub fn lpush(self, value: Any) { self.items.insert(0, value); }
        pub fn rpush(self, value: Any) { self.items.append(value); }
        pub fn lpop(self) -> Any? { if self.items.len() == 0 { return null; } return self.items.remove(0); }
        pub fn rpop(self) -> Any? { if self.items.len() == 0 { return null; } return self.items.remove(self.items.len() - 1); }
        pub fn lrange(self, start: Int, stop: Int) -> List<Any> { return self.items.slice(start, stop + 1); }
        pub fn llen(self) -> Int { return self.items.len(); }
    }

    pub class CacheSet {
        pub let key: String;
        pub let members: Set<Any>;

        pub fn new(key: String) -> Self {
            return Self { key: key, members: Set::new() };
        }

        pub fn sadd(self, value: Any) -> Bool { return self.members.add(value); }
        pub fn srem(self, value: Any) -> Bool { return self.members.remove(value); }
        pub fn sismember(self, value: Any) -> Bool { return self.members.contains(value); }
        pub fn smembers(self) -> List<Any> { return self.members.to_list(); }
        pub fn scard(self) -> Int { return self.members.len(); }
    }

    pub class CacheHash {
        pub let key: String;
        pub let fields: Map<String, Any>;

        pub fn new(key: String) -> Self {
            return Self { key: key, fields: {} };
        }

        pub fn hset(self, field: String, value: Any) { self.fields[field] = value; }
        pub fn hget(self, field: String) -> Any? { return self.fields.get(field); }
        pub fn hdel(self, field: String) -> Bool { return self.fields.remove(field) != null; }
        pub fn hexists(self, field: String) -> Bool { return self.fields.contains_key(field); }
        pub fn hkeys(self) -> List<String> { return self.fields.keys(); }
        pub fn hvals(self) -> List<Any> { return self.fields.values(); }
        pub fn hlen(self) -> Int { return self.fields.len(); }
    }

    pub class SortedSet {
        pub let key: String;
        pub let members: List<ScoredMember>;

        pub fn new(key: String) -> Self {
            return Self { key: key, members: [] };
        }

        pub fn zadd(self, score: Float, member: Any) {
            self.zrem(member);
            self.members.append(ScoredMember { score: score, member: member });
            self.members = self.members.sorted_by(|a, b| (a.score - b.score).sign());
        }

        pub fn zrem(self, member: Any) -> Bool {
            let idx = self.members.find_index(|m| m.member == member);
            if idx >= 0 { self.members.remove(idx); return true; }
            return false;
        }

        pub fn zrange(self, start: Int, stop: Int) -> List<ScoredMember> {
            return self.members.slice(start, stop + 1);
        }

        pub fn zscore(self, member: Any) -> Float? {
            let found = self.members.find(|m| m.member == member);
            if found != null { return found.score; }
            return null;
        }

        pub fn zcard(self) -> Int { return self.members.len(); }
    }

    pub class ScoredMember {
        pub let score: Float;
        pub let member: Any;
    }
}

# ============================================================
# CACHE ENGINE ORCHESTRATOR
# ============================================================

pub class CacheEngine {
    pub let cache: sharding.ShardedCache;
    pub let pubsub: pubsub.PubSub;
    pub let persistence_mgr: persistence.PersistenceManager?;

    pub fn new(shard_count: Int) -> Self {
        let config = cache.CacheConfig::new();
        return Self {
            cache: sharding.ShardedCache::new(shard_count, config),
            pubsub: pubsub.PubSub::new(),
            persistence_mgr: null
        };
    }

    pub fn with_persistence(self, path: String) -> Self {
        self.persistence_mgr = persistence.PersistenceManager::new(path);
        return self;
    }

    pub fn get(self, key: String) -> Any? { return self.cache.get(key); }
    pub fn set(self, key: String, value: Any, ttl_ms: Int?) { self.cache.set(key, value, ttl_ms); }
    pub fn delete(self, key: String) -> Bool { return self.cache.delete(key); }

    pub fn subscribe(self, channel: String, handler: Fn(String, Any)) {
        self.pubsub.subscribe(channel, handler);
    }

    pub fn publish(self, channel: String, message: Any) -> Int {
        return self.pubsub.publish(channel, message);
    }

    pub fn stats(self) -> cache.CacheStats { return self.cache.aggregate_stats(); }
    pub fn size(self) -> Int { return self.cache.total_size(); }
    pub fn flush(self) { self.cache.flush(); }

    pub fn save(self) {
        if self.persistence_mgr != null {
            self.persistence_mgr.save(self.cache.shards[0].entries);
        }
    }
}

pub fn create_cache(shard_count: Int) -> CacheEngine {
    return CacheEngine::new(shard_count);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_cache_now() -> Int;
native_cache_sizeof(value: Any) -> Int;
native_cache_hash(key: String) -> Int;
native_cache_match(key: String, pattern: String) -> Bool;
native_cache_checksum(data: Any) -> String;
native_cache_write(path: String, data: Any);
native_cache_read(path: String) -> Any?;

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
