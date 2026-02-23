# ============================================================
# NYINFRA - Nyx Infrastructure as Code Engine
# ============================================================
# Declarative DSL for cloud resource provisioning, idempotent
# operations, state tracking, drift detection, and multi-cloud.

let VERSION = "1.0.0";

# ============================================================
# RESOURCE MODEL
# ============================================================

pub mod resources {
    pub class ResourceSpec {
        pub let type_: String;
        pub let name: String;
        pub let provider: String;
        pub let properties: Map<String, Any>;
        pub let depends_on: List<String>;
        pub let tags: Map<String, String>;

        pub fn new(type_: String, name: String, provider: String) -> Self {
            return Self {
                type_: type_, name: name, provider: provider,
                properties: {}, depends_on: [], tags: {}
            };
        }

        pub fn set(self, key: String, value: Any) -> Self {
            self.properties[key] = value;
            return self;
        }

        pub fn tag(self, key: String, value: String) -> Self {
            self.tags[key] = value;
            return self;
        }

        pub fn depends(self, resource_name: String) -> Self {
            self.depends_on.append(resource_name);
            return self;
        }

        pub fn resource_id(self) -> String {
            return self.provider + ":" + self.type_ + ":" + self.name;
        }
    }

    pub class ResourceState {
        pub let resource_id: String;
        pub let spec: ResourceSpec;
        pub let status: String;
        pub let outputs: Map<String, Any>;
        pub let physical_id: String?;
        pub let created_at: Int;
        pub let updated_at: Int;

        pub fn new(spec: ResourceSpec) -> Self {
            let now = native_infra_now();
            return Self {
                resource_id: spec.resource_id(),
                spec: spec, status: "pending",
                outputs: {}, physical_id: null,
                created_at: now, updated_at: now
            };
        }
    }
}

# ============================================================
# STACK & DECLARATIVE DSL
# ============================================================

pub mod stack {
    pub class Stack {
        pub let name: String;
        pub let resources: List<resources.ResourceSpec>;
        pub let variables: Map<String, Any>;
        pub let outputs: Map<String, String>;

        pub fn new(name: String) -> Self {
            return Self { name: name, resources: [], variables: {}, outputs: {} };
        }

        pub fn variable(self, name: String, default: Any) -> Self {
            self.variables[name] = default;
            return self;
        }

        pub fn add(self, resource: resources.ResourceSpec) -> Self {
            self.resources.append(resource);
            return self;
        }

        pub fn output(self, name: String, ref: String) -> Self {
            self.outputs[name] = ref;
            return self;
        }

        pub fn compute(self, provider: String, name: String) -> resources.ResourceSpec {
            let r = resources.ResourceSpec::new("compute_instance", name, provider);
            self.resources.append(r);
            return r;
        }

        pub fn network(self, provider: String, name: String) -> resources.ResourceSpec {
            let r = resources.ResourceSpec::new("network", name, provider);
            self.resources.append(r);
            return r;
        }

        pub fn storage(self, provider: String, name: String) -> resources.ResourceSpec {
            let r = resources.ResourceSpec::new("storage_bucket", name, provider);
            self.resources.append(r);
            return r;
        }

        pub fn database(self, provider: String, name: String) -> resources.ResourceSpec {
            let r = resources.ResourceSpec::new("database", name, provider);
            self.resources.append(r);
            return r;
        }

        pub fn load_balancer(self, provider: String, name: String) -> resources.ResourceSpec {
            let r = resources.ResourceSpec::new("load_balancer", name, provider);
            self.resources.append(r);
            return r;
        }

        pub fn dns(self, provider: String, name: String) -> resources.ResourceSpec {
            let r = resources.ResourceSpec::new("dns_record", name, provider);
            self.resources.append(r);
            return r;
        }

        pub fn dependency_order(self) -> List<resources.ResourceSpec> {
            let resolved = [];
            let resolved_names = Set::new();
            let remaining = self.resources.clone();
            while remaining.len() > 0 {
                let batch = [];
                for r in remaining {
                    let deps_met = r.depends_on.all(|d| resolved_names.contains(d));
                    if deps_met { batch.append(r); }
                }
                if batch.len() == 0 && remaining.len() > 0 {
                    break;
                }
                for r in batch {
                    resolved.append(r);
                    resolved_names.add(r.name);
                    remaining = remaining.filter(|x| x.name != r.name);
                }
            }
            return resolved;
        }
    }
}

# ============================================================
# STATE MANAGEMENT & DRIFT DETECTION
# ============================================================

pub mod state {
    pub class StateStore {
        pub let states: Map<String, resources.ResourceState>;
        pub let version: Int;
        pub let last_modified: Int;

        pub fn new() -> Self {
            return Self { states: {}, version: 0, last_modified: native_infra_now() };
        }

        pub fn get(self, resource_id: String) -> resources.ResourceState? {
            return self.states.get(resource_id);
        }

        pub fn set(self, state: resources.ResourceState) {
            self.states[state.resource_id] = state;
            self.version = self.version + 1;
            self.last_modified = native_infra_now();
        }

        pub fn remove(self, resource_id: String) {
            self.states.remove(resource_id);
            self.version = self.version + 1;
        }

        pub fn all(self) -> List<resources.ResourceState> {
            return self.states.values();
        }

        pub fn save(self, path: String) {
            native_infra_write_state(path, self);
        }

        pub fn load(path: String) -> StateStore {
            let stored = native_infra_read_state(path);
            if stored != null { return stored; }
            return StateStore::new();
        }
    }

    pub class DriftDetector {
        pub fn detect(self, spec: resources.ResourceSpec,
                      current_state: resources.ResourceState) -> List<DriftResult> {
            let diffs = [];
            let live = native_infra_describe(spec.provider, spec.type_, current_state.physical_id);
            if live == null {
                diffs.append(DriftResult { resource_id: spec.resource_id(),
                              field: "_resource", expected: "exists", actual: "deleted" });
                return diffs;
            }
            for key, expected in spec.properties {
                let actual = live.get(key);
                if actual != expected {
                    diffs.append(DriftResult {
                        resource_id: spec.resource_id(),
                        field: key, expected: expected, actual: actual
                    });
                }
            }
            return diffs;
        }
    }

    pub class DriftResult {
        pub let resource_id: String;
        pub let field: String;
        pub let expected: Any;
        pub let actual: Any;
    }
}

# ============================================================
# CLOUD PROVIDERS
# ============================================================

pub mod providers {
    pub class Provider {
        pub let name: String;
        pub let region: String;
        pub let credentials: Map<String, String>;

        pub fn new(name: String, region: String) -> Self {
            return Self { name: name, region: region, credentials: {} };
        }

        pub fn with_credentials(self, creds: Map<String, String>) -> Self {
            self.credentials = creds;
            return self;
        }

        pub fn create(self, type_: String, spec: resources.ResourceSpec) -> Map<String, Any> {
            return native_infra_create(self.name, self.region, type_, spec.properties, self.credentials);
        }

        pub fn update(self, type_: String, physical_id: String,
                      properties: Map<String, Any>) -> Map<String, Any> {
            return native_infra_update(self.name, self.region, type_, physical_id, properties, self.credentials);
        }

        pub fn destroy(self, type_: String, physical_id: String) -> Bool {
            return native_infra_destroy(self.name, self.region, type_, physical_id, self.credentials);
        }

        pub fn describe(self, type_: String, physical_id: String) -> Map<String, Any>? {
            return native_infra_describe(self.name, type_, physical_id);
        }
    }

    pub class ProviderRegistry {
        pub let providers: Map<String, Provider>;

        pub fn new() -> Self {
            return Self { providers: {} };
        }

        pub fn register(self, provider: Provider) {
            self.providers[provider.name] = provider;
        }

        pub fn get(self, name: String) -> Provider? {
            return self.providers.get(name);
        }
    }
}

# ============================================================
# EXECUTION PLAN
# ============================================================

pub mod planner {
    pub class PlanAction {
        pub let action: String;
        pub let resource_id: String;
        pub let spec: resources.ResourceSpec;
        pub let reason: String;

        pub fn new(action: String, spec: resources.ResourceSpec, reason: String) -> Self {
            return Self { action: action, resource_id: spec.resource_id(),
                          spec: spec, reason: reason };
        }
    }

    pub class Plan {
        pub let actions: List<PlanAction>;
        pub let creates: Int;
        pub let updates: Int;
        pub let destroys: Int;
        pub let unchanged: Int;

        pub fn new() -> Self {
            return Self { actions: [], creates: 0, updates: 0, destroys: 0, unchanged: 0 };
        }

        pub fn add_create(self, spec: resources.ResourceSpec) {
            self.actions.append(PlanAction::new("create", spec, "new resource"));
            self.creates = self.creates + 1;
        }

        pub fn add_update(self, spec: resources.ResourceSpec, reason: String) {
            self.actions.append(PlanAction::new("update", spec, reason));
            self.updates = self.updates + 1;
        }

        pub fn add_destroy(self, spec: resources.ResourceSpec) {
            self.actions.append(PlanAction::new("destroy", spec, "removed from stack"));
            self.destroys = self.destroys + 1;
        }

        pub fn summary(self) -> String {
            return "Plan: +" + self.creates.to_string() + " create, ~" +
                   self.updates.to_string() + " update, -" +
                   self.destroys.to_string() + " destroy";
        }

        pub fn has_changes(self) -> Bool {
            return self.creates > 0 || self.updates > 0 || self.destroys > 0;
        }
    }

    pub fn compute_plan(desired: stack.Stack, current: state.StateStore) -> Plan {
        let plan = Plan::new();
        let ordered = desired.dependency_order();
        let desired_ids = Set::new();
        for spec in ordered {
            let rid = spec.resource_id();
            desired_ids.add(rid);
            let existing = current.get(rid);
            if existing == null {
                plan.add_create(spec);
            } else {
                let changed = false;
                for key, val in spec.properties {
                    if existing.spec.properties.get(key) != val {
                        changed = true;
                        break;
                    }
                }
                if changed {
                    plan.add_update(spec, "properties changed");
                } else {
                    plan.unchanged = plan.unchanged + 1;
                }
            }
        }
        for rid, st in current.states {
            if !desired_ids.contains(rid) {
                plan.add_destroy(st.spec);
            }
        }
        return plan;
    }
}

# ============================================================
# INFRA ENGINE ORCHESTRATOR
# ============================================================

pub class InfraEngine {
    pub let provider_registry: providers.ProviderRegistry;
    pub let state_store: state.StateStore;
    pub let state_path: String;
    pub let drift_detector: state.DriftDetector;

    pub fn new(state_path: String) -> Self {
        return Self {
            provider_registry: providers.ProviderRegistry::new(),
            state_store: state.StateStore::load(state_path),
            state_path: state_path,
            drift_detector: state.DriftDetector::new()
        };
    }

    pub fn register_provider(self, provider: providers.Provider) {
        self.provider_registry.register(provider);
    }

    pub fn plan(self, desired: stack.Stack) -> planner.Plan {
        return planner.compute_plan(desired, self.state_store);
    }

    pub fn apply(self, desired: stack.Stack) -> Map<String, Any> {
        let plan = self.plan(desired);
        let results = { "created": 0, "updated": 0, "destroyed": 0, "errors": [] };
        for action in plan.actions {
            let provider = self.provider_registry.get(action.spec.provider);
            if provider == null {
                results["errors"].append("No provider: " + action.spec.provider);
                continue;
            }
            if action.action == "create" {
                let result = provider.create(action.spec.type_, action.spec);
                let rs = resources.ResourceState::new(action.spec);
                rs.status = "created";
                rs.physical_id = result.get("id");
                rs.outputs = result;
                self.state_store.set(rs);
                results["created"] = results["created"] + 1;
            } else if action.action == "update" {
                let existing = self.state_store.get(action.resource_id);
                if existing != null && existing.physical_id != null {
                    let result = provider.update(action.spec.type_, existing.physical_id, action.spec.properties);
                    existing.spec = action.spec;
                    existing.outputs = result;
                    existing.updated_at = native_infra_now();
                    self.state_store.set(existing);
                    results["updated"] = results["updated"] + 1;
                }
            } else if action.action == "destroy" {
                let existing = self.state_store.get(action.resource_id);
                if existing != null && existing.physical_id != null {
                    provider.destroy(action.spec.type_, existing.physical_id);
                    self.state_store.remove(action.resource_id);
                    results["destroyed"] = results["destroyed"] + 1;
                }
            }
        }
        self.state_store.save(self.state_path);
        return results;
    }

    pub fn destroy_all(self) {
        let empty = stack.Stack::new("empty");
        self.apply(empty);
    }

    pub fn detect_drift(self) -> List<state.DriftResult> {
        let all_drifts = [];
        for rid, rs in self.state_store.states {
            let drifts = self.drift_detector.detect(rs.spec, rs);
            all_drifts = all_drifts + drifts;
        }
        return all_drifts;
    }

    pub fn repair_drift(self) {
        for rid, rs in self.state_store.states {
            let drifts = self.drift_detector.detect(rs.spec, rs);
            if drifts.len() > 0 {
                let provider = self.provider_registry.get(rs.spec.provider);
                if provider != null && rs.physical_id != null {
                    provider.update(rs.spec.type_, rs.physical_id, rs.spec.properties);
                }
            }
        }
    }
}

pub fn create_infra(state_path: String) -> InfraEngine {
    return InfraEngine::new(state_path);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_infra_now() -> Int;
native_infra_write_state(path: String, state: Any);
native_infra_read_state(path: String) -> Any?;
native_infra_create(provider: String, region: String, type_: String, props: Map<String, Any>, creds: Map<String, String>) -> Map<String, Any>;
native_infra_update(provider: String, region: String, type_: String, id: String, props: Map<String, Any>, creds: Map<String, String>) -> Map<String, Any>;
native_infra_destroy(provider: String, region: String, type_: String, id: String, creds: Map<String, String>) -> Bool;
native_infra_describe(provider: String, type_: String, id: String?) -> Map<String, Any>?;

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
