# ============================================================
# NYSERVERLESS - Nyx Function-as-a-Service Engine
# ============================================================
# Cold-start optimization, edge deployment, event triggers,
# function composition, auto-scaling to zero, and sandboxing.

let VERSION = "1.0.0";

# ============================================================
# FUNCTION DEFINITION
# ============================================================

pub mod functions {
    pub class FunctionConfig {
        pub let name: String;
        pub let runtime: String;
        pub let handler: String;
        pub let memory_mb: Int;
        pub let timeout_ms: Int;
        pub let env: Map<String, String>;
        pub let layers: List<String>;
        pub let concurrency_limit: Int;

        pub fn new(name: String, handler: String) -> Self {
            return Self {
                name: name, runtime: "nyx-1.0",
                handler: handler, memory_mb: 128,
                timeout_ms: 30000, env: {},
                layers: [], concurrency_limit: 100
            };
        }

        pub fn with_memory(self, mb: Int) -> Self { self.memory_mb = mb; return self; }
        pub fn with_timeout(self, ms: Int) -> Self { self.timeout_ms = ms; return self; }
        pub fn with_env(self, key: String, value: String) -> Self { self.env[key] = value; return self; }
        pub fn with_layer(self, layer: String) -> Self { self.layers.append(layer); return self; }
    }

    pub class FunctionInstance {
        pub let id: String;
        pub let config: FunctionConfig;
        pub let status: String;
        pub let created_at: Int;
        pub let last_invoked: Int;
        pub let invocation_count: Int;
        pub let warm: Bool;

        pub fn new(config: FunctionConfig) -> Self {
            return Self {
                id: native_serverless_uuid(),
                config: config, status: "cold",
                created_at: native_serverless_now(),
                last_invoked: 0, invocation_count: 0,
                warm: false
            };
        }

        pub fn invoke(self, event: Any, context: InvocationContext) -> InvocationResult {
            let start = native_serverless_now();
            self.last_invoked = start;
            self.invocation_count = self.invocation_count + 1;
            let cold_start = !self.warm;
            if !self.warm {
                self._warm_up();
            }
            let result = native_serverless_execute(self.config.handler, event, context,
                                                    self.config.timeout_ms);
            let duration = native_serverless_now() - start;
            return InvocationResult {
                request_id: context.request_id,
                status: if result.error == null { "success" } else { "error" },
                body: result.body,
                error: result.error,
                duration_ms: duration,
                cold_start: cold_start,
                memory_used_mb: result.memory_used_mb ?? 0,
                billed_duration_ms: ((duration / 100.0).ceil() * 100).to_int()
            };
        }

        fn _warm_up(self) {
            self.warm = true;
            self.status = "warm";
        }

        pub fn cool_down(self) {
            self.warm = false;
            self.status = "cold";
        }
    }

    pub class InvocationContext {
        pub let request_id: String;
        pub let function_name: String;
        pub let memory_mb: Int;
        pub let remaining_ms: Int;
        pub let log_group: String;

        pub fn new(func: FunctionConfig) -> Self {
            return Self {
                request_id: native_serverless_uuid(),
                function_name: func.name,
                memory_mb: func.memory_mb,
                remaining_ms: func.timeout_ms,
                log_group: "/serverless/" + func.name
            };
        }
    }

    pub class InvocationResult {
        pub let request_id: String;
        pub let status: String;
        pub let body: Any?;
        pub let error: String?;
        pub let duration_ms: Int;
        pub let cold_start: Bool;
        pub let memory_used_mb: Int;
        pub let billed_duration_ms: Int;
    }
}

# ============================================================
# EVENT TRIGGERS
# ============================================================

pub mod triggers {
    pub class Trigger {
        pub let type_: String;
        pub let source: String;
        pub let function_name: String;
        pub let config: Map<String, Any>;
        pub let enabled: Bool;

        pub fn new(type_: String, source: String, function_name: String) -> Self {
            return Self {
                type_: type_, source: source,
                function_name: function_name,
                config: {}, enabled: true
            };
        }
    }

    pub fn http_trigger(path: String, method: String, function_name: String) -> Trigger {
        let t = Trigger::new("http", path, function_name);
        t.config["method"] = method;
        t.config["path"] = path;
        return t;
    }

    pub fn schedule_trigger(cron: String, function_name: String) -> Trigger {
        let t = Trigger::new("schedule", cron, function_name);
        t.config["cron"] = cron;
        return t;
    }

    pub fn queue_trigger(queue_name: String, function_name: String,
                          batch_size: Int) -> Trigger {
        let t = Trigger::new("queue", queue_name, function_name);
        t.config["queue"] = queue_name;
        t.config["batch_size"] = batch_size;
        return t;
    }

    pub fn storage_trigger(bucket: String, event: String,
                            function_name: String) -> Trigger {
        let t = Trigger::new("storage", bucket, function_name);
        t.config["bucket"] = bucket;
        t.config["event"] = event;
        return t;
    }

    pub fn event_trigger(topic: String, function_name: String) -> Trigger {
        let t = Trigger::new("event", topic, function_name);
        t.config["topic"] = topic;
        return t;
    }

    pub class TriggerRouter {
        pub let triggers: List<Trigger>;

        pub fn new() -> Self {
            return Self { triggers: [] };
        }

        pub fn add(self, trigger: Trigger) { self.triggers.append(trigger); }

        pub fn match_http(self, path: String, method: String) -> String? {
            for t in self.triggers {
                if t.type_ == "http" && t.enabled {
                    if t.config["path"] == path && t.config["method"] == method {
                        return t.function_name;
                    }
                }
            }
            return null;
        }

        pub fn match_event(self, source_type: String, source: String) -> List<String> {
            let matches = [];
            for t in self.triggers {
                if t.type_ == source_type && t.source == source && t.enabled {
                    matches.append(t.function_name);
                }
            }
            return matches;
        }
    }
}

# ============================================================
# AUTO-SCALING & INSTANCE POOL
# ============================================================

pub mod scaling {
    pub class ScalingConfig {
        pub let min_instances: Int;
        pub let max_instances: Int;
        pub let scale_to_zero: Bool;
        pub let idle_timeout_ms: Int;
        pub let provisioned_concurrency: Int;
        pub let warm_pool_size: Int;

        pub fn new() -> Self {
            return Self {
                min_instances: 0, max_instances: 1000,
                scale_to_zero: true, idle_timeout_ms: 300000,
                provisioned_concurrency: 0, warm_pool_size: 0
            };
        }
    }

    pub class InstancePool {
        pub let function_name: String;
        pub let config: ScalingConfig;
        pub let instances: List<functions.FunctionInstance>;
        pub let active_invocations: Int;

        pub fn new(function_name: String, config: ScalingConfig) -> Self {
            return Self {
                function_name: function_name, config: config,
                instances: [], active_invocations: 0
            };
        }

        pub fn acquire(self, func_config: functions.FunctionConfig) -> functions.FunctionInstance {
            for inst in self.instances {
                if inst.warm && inst.status != "busy" {
                    inst.status = "busy";
                    self.active_invocations = self.active_invocations + 1;
                    return inst;
                }
            }
            if self.instances.len() < self.config.max_instances {
                let inst = functions.FunctionInstance::new(func_config);
                self.instances.append(inst);
                inst.status = "busy";
                self.active_invocations = self.active_invocations + 1;
                return inst;
            }
            return self.instances[0];
        }

        pub fn release(self, instance: functions.FunctionInstance) {
            instance.status = "warm";
            self.active_invocations = max(0, self.active_invocations - 1);
        }

        pub fn scale_check(self) {
            let now = native_serverless_now();
            if self.config.scale_to_zero && self.active_invocations == 0 {
                for inst in self.instances {
                    if inst.warm && now - inst.last_invoked > self.config.idle_timeout_ms {
                        inst.cool_down();
                    }
                }
                self.instances = self.instances.filter(|i| i.warm || i.status == "busy");
            }
            while self.instances.len() < self.config.provisioned_concurrency {
                let inst = functions.FunctionInstance::new(
                    functions.FunctionConfig::new(self.function_name, "handler"));
                inst._warm_up();
                self.instances.append(inst);
            }
        }
    }
}

# ============================================================
# FUNCTION COMPOSITION
# ============================================================

pub mod composition {
    pub class Step {
        pub let name: String;
        pub let function_name: String;
        pub let type_: String;
        pub let next: String?;
        pub let branches: Map<String, String>;
        pub let retry_count: Int;

        pub fn new(name: String, function_name: String) -> Self {
            return Self {
                name: name, function_name: function_name,
                type_: "task", next: null,
                branches: {}, retry_count: 0
            };
        }

        pub fn then(self, next_step: String) -> Self {
            self.next = next_step;
            return self;
        }

        pub fn choice(self, condition: String, target: String) -> Self {
            self.type_ = "choice";
            self.branches[condition] = target;
            return self;
        }

        pub fn with_retry(self, count: Int) -> Self {
            self.retry_count = count;
            return self;
        }
    }

    pub class Pipeline {
        pub let name: String;
        pub let steps: Map<String, Step>;
        pub let start_step: String;

        pub fn new(name: String) -> Self {
            return Self { name: name, steps: {}, start_step: "" };
        }

        pub fn add_step(self, step: Step) -> Self {
            if self.steps.len() == 0 { self.start_step = step.name; }
            self.steps[step.name] = step;
            return self;
        }

        pub fn execute(self, input: Any, invoker: Fn(String, Any) -> Any) -> Any {
            let current = self.start_step;
            let data = input;
            while current != null && current != "" {
                let step = self.steps.get(current);
                if step == null { break; }
                let attempts = 0;
                let result = null;
                while attempts <= step.retry_count {
                    result = invoker(step.function_name, data);
                    if result != null { break; }
                    attempts = attempts + 1;
                }
                data = result;
                if step.type_ == "choice" {
                    let matched = false;
                    for condition, target in step.branches {
                        if _evaluate_condition(condition, data) {
                            current = target;
                            matched = true;
                            break;
                        }
                    }
                    if !matched { current = step.next; }
                } else {
                    current = step.next;
                }
            }
            return data;
        }
    }

    fn _evaluate_condition(condition: String, data: Any) -> Bool {
        return native_serverless_eval_condition(condition, data);
    }
}

# ============================================================
# EDGE DEPLOYMENT
# ============================================================

pub mod edge {
    pub class EdgeLocation {
        pub let region: String;
        pub let zone: String;
        pub let latency_ms: Float;
        pub let capacity: Int;
        pub let deployed_functions: List<String>;

        pub fn new(region: String, zone: String) -> Self {
            return Self {
                region: region, zone: zone,
                latency_ms: 0.0, capacity: 100,
                deployed_functions: []
            };
        }
    }

    pub class EdgeRouter {
        pub let locations: List<EdgeLocation>;

        pub fn new() -> Self {
            return Self { locations: [] };
        }

        pub fn add_location(self, loc: EdgeLocation) {
            self.locations.append(loc);
        }

        pub fn deploy_to_edge(self, function_name: String, regions: List<String>) {
            for loc in self.locations {
                if regions.contains(loc.region) {
                    loc.deployed_functions.append(function_name);
                }
            }
        }

        pub fn nearest(self, client_region: String) -> EdgeLocation? {
            let best = null;
            let best_latency = 999999.0;
            for loc in self.locations {
                if loc.latency_ms < best_latency {
                    best = loc;
                    best_latency = loc.latency_ms;
                }
            }
            return best;
        }

        pub fn route(self, function_name: String, client_region: String) -> EdgeLocation? {
            let candidates = self.locations.filter(|l| l.deployed_functions.contains(function_name));
            if candidates.len() == 0 { return null; }
            return candidates.min_by(|l| l.latency_ms);
        }
    }
}

# ============================================================
# SERVERLESS ENGINE ORCHESTRATOR
# ============================================================

pub class ServerlessEngine {
    pub let functions: Map<String, functions.FunctionConfig>;
    pub let pools: Map<String, scaling.InstancePool>;
    pub let trigger_router: triggers.TriggerRouter;
    pub let edge_router: edge.EdgeRouter;
    pub let metrics: Map<String, List<functions.InvocationResult>>;

    pub fn new() -> Self {
        return Self {
            functions: {}, pools: {},
            trigger_router: triggers.TriggerRouter::new(),
            edge_router: edge.EdgeRouter::new(),
            metrics: {}
        };
    }

    pub fn register(self, config: functions.FunctionConfig) {
        self.functions[config.name] = config;
        let scaling_config = scaling.ScalingConfig::new();
        self.pools[config.name] = scaling.InstancePool::new(config.name, scaling_config);
        self.metrics[config.name] = [];
    }

    pub fn add_trigger(self, trigger: triggers.Trigger) {
        self.trigger_router.add(trigger);
    }

    pub fn invoke(self, function_name: String, event: Any) -> functions.InvocationResult? {
        let config = self.functions.get(function_name);
        if config == null { return null; }
        let pool = self.pools[function_name];
        let instance = pool.acquire(config);
        let context = functions.InvocationContext::new(config);
        let result = instance.invoke(event, context);
        pool.release(instance);
        self.metrics[function_name].append(result);
        return result;
    }

    pub fn handle_http(self, path: String, method: String, body: Any) -> functions.InvocationResult? {
        let func_name = self.trigger_router.match_http(path, method);
        if func_name == null { return null; }
        let event = { "path": path, "method": method, "body": body };
        return self.invoke(func_name, event);
    }

    pub fn handle_event(self, source_type: String, source: String,
                         payload: Any) -> List<functions.InvocationResult> {
        let func_names = self.trigger_router.match_event(source_type, source);
        let results = [];
        for name in func_names {
            let result = self.invoke(name, payload);
            if result != null { results.append(result); }
        }
        return results;
    }

    pub fn create_pipeline(self, name: String) -> composition.Pipeline {
        return composition.Pipeline::new(name);
    }

    pub fn run_pipeline(self, pipeline: composition.Pipeline, input: Any) -> Any {
        return pipeline.execute(input, |name, data| {
            let result = self.invoke(name, data);
            if result != null && result.status == "success" { return result.body; }
            return null;
        });
    }

    pub fn tick(self) {
        for name, pool in self.pools {
            pool.scale_check();
        }
    }

    pub fn cold_start_stats(self, function_name: String) -> Map<String, Any> {
        let results = self.metrics.get(function_name) ?? [];
        let cold = results.filter(|r| r.cold_start);
        let warm = results.filter(|r| !r.cold_start);
        return {
            "total_invocations": results.len(),
            "cold_starts": cold.len(),
            "cold_start_rate": if results.len() > 0 { cold.len().to_float() / results.len().to_float() } else { 0.0 },
            "avg_cold_ms": if cold.len() > 0 { cold.map(|r| r.duration_ms).sum().to_float() / cold.len().to_float() } else { 0.0 },
            "avg_warm_ms": if warm.len() > 0 { warm.map(|r| r.duration_ms).sum().to_float() / warm.len().to_float() } else { 0.0 }
        };
    }
}

pub fn create_serverless() -> ServerlessEngine {
    return ServerlessEngine::new();
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_serverless_now() -> Int;
native_serverless_uuid() -> String;
native_serverless_execute(handler: String, event: Any, context: Any, timeout_ms: Int) -> Map<String, Any>;
native_serverless_eval_condition(condition: String, data: Any) -> Bool;

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
