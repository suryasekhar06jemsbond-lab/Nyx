# ============================================================
# NYAPI - Nyx API Framework Engine
# ============================================================
# REST/GraphQL routing, middleware pipeline, dependency
# injection, authentication, JSON serialization, rate limiting,
# and OpenAPI auto-generation.

let VERSION = "1.0.0";

# ============================================================
# HTTP TYPES
# ============================================================

pub mod http {
    pub class Request {
        pub let method: String;
        pub let path: String;
        pub let headers: Map<String, String>;
        pub let query: Map<String, String>;
        pub let params: Map<String, String>;
        pub let body: Any?;
        pub let raw_body: String?;
        pub let remote_addr: String?;
        pub let content_type: String?;

        pub fn new(method: String, path: String) -> Self {
            return Self {
                method: method, path: path,
                headers: {}, query: {}, params: {},
                body: null, raw_body: null,
                remote_addr: null, content_type: null
            };
        }

        pub fn header(self, name: String) -> String? {
            return self.headers.get(name.lower());
        }
    }

    pub class Response {
        pub let status: Int;
        pub let headers: Map<String, String>;
        pub let body: Any?;

        pub fn new(status: Int) -> Self {
            return Self { status: status, headers: {}, body: null };
        }

        pub fn ok(body: Any) -> Self {
            return Self { status: 200, headers: { "content-type": "application/json" }, body: body };
        }

        pub fn created(body: Any) -> Self {
            return Self { status: 201, headers: { "content-type": "application/json" }, body: body };
        }

        pub fn no_content() -> Self {
            return Self { status: 204, headers: {}, body: null };
        }

        pub fn bad_request(msg: String) -> Self {
            return Self { status: 400, headers: { "content-type": "application/json" }, body: { "error": msg } };
        }

        pub fn unauthorized(msg: String) -> Self {
            return Self { status: 401, headers: { "content-type": "application/json" }, body: { "error": msg } };
        }

        pub fn forbidden() -> Self {
            return Self { status: 403, headers: { "content-type": "application/json" }, body: { "error": "forbidden" } };
        }

        pub fn not_found() -> Self {
            return Self { status: 404, headers: { "content-type": "application/json" }, body: { "error": "not found" } };
        }

        pub fn internal_error(msg: String) -> Self {
            return Self { status: 500, headers: { "content-type": "application/json" }, body: { "error": msg } };
        }

        pub fn set_header(self, name: String, value: String) -> Self {
            self.headers[name] = value;
            return self;
        }
    }

    pub class Context {
        pub let request: Request;
        pub let response: Response;
        pub let state: Map<String, Any>;
        pub let params: Map<String, String>;

        pub fn new(req: Request) -> Self {
            return Self {
                request: req,
                response: Response::new(200),
                state: {},
                params: req.params
            };
        }

        pub fn get_state(self, key: String) -> Any? { return self.state.get(key); }
        pub fn set_state(self, key: String, value: Any) { self.state[key] = value; }
    }
}

# ============================================================
# ROUTER
# ============================================================

pub mod router {
    pub class Route {
        pub let method: String;
        pub let path: String;
        pub let handler: Fn;
        pub let middleware: List<Fn>;
        pub let name: String?;

        pub fn new(method: String, path: String, handler: Fn) -> Self {
            return Self { method: method, path: path, handler: handler, middleware: [], name: null };
        }
    }

    pub class RouteGroup {
        pub let prefix: String;
        pub let routes: List<Route>;
        pub let middleware: List<Fn>;

        pub fn new(prefix: String) -> Self {
            return Self { prefix: prefix, routes: [], middleware: [] };
        }

        pub fn get(self, path: String, handler: Fn) -> Self {
            self.routes.append(Route::new("GET", self.prefix + path, handler));
            return self;
        }

        pub fn post(self, path: String, handler: Fn) -> Self {
            self.routes.append(Route::new("POST", self.prefix + path, handler));
            return self;
        }

        pub fn put(self, path: String, handler: Fn) -> Self {
            self.routes.append(Route::new("PUT", self.prefix + path, handler));
            return self;
        }

        pub fn delete(self, path: String, handler: Fn) -> Self {
            self.routes.append(Route::new("DELETE", self.prefix + path, handler));
            return self;
        }

        pub fn use_middleware(self, mw: Fn) -> Self {
            self.middleware.append(mw);
            return self;
        }
    }

    pub class Router {
        pub let routes: List<Route>;
        pub let groups: List<RouteGroup>;

        pub fn new() -> Self {
            return Self { routes: [], groups: [] };
        }

        pub fn get(self, path: String, handler: Fn) -> Self {
            self.routes.append(Route::new("GET", path, handler));
            return self;
        }

        pub fn post(self, path: String, handler: Fn) -> Self {
            self.routes.append(Route::new("POST", path, handler));
            return self;
        }

        pub fn put(self, path: String, handler: Fn) -> Self {
            self.routes.append(Route::new("PUT", path, handler));
            return self;
        }

        pub fn delete(self, path: String, handler: Fn) -> Self {
            self.routes.append(Route::new("DELETE", path, handler));
            return self;
        }

        pub fn group(self, prefix: String) -> RouteGroup {
            let g = RouteGroup::new(prefix);
            self.groups.append(g);
            return g;
        }

        pub fn match_route(self, method: String, path: String) -> Route? {
            let all = self.routes.clone();
            for g in self.groups { all = all + g.routes; }
            for route in all {
                if route.method == method && self._match_path(route.path, path) {
                    return route;
                }
            }
            return null;
        }

        fn _match_path(self, pattern: String, path: String) -> Bool {
            return native_api_match_path(pattern, path);
        }
    }
}

# ============================================================
# MIDDLEWARE
# ============================================================

pub mod middleware {
    pub fn cors(allowed_origins: List<String>) -> Fn {
        return |ctx: http.Context, next: Fn| {
            ctx.response.set_header("Access-Control-Allow-Origin", allowed_origins.join(","));
            ctx.response.set_header("Access-Control-Allow-Methods", "GET,POST,PUT,DELETE,OPTIONS");
            ctx.response.set_header("Access-Control-Allow-Headers", "Content-Type,Authorization");
            if ctx.request.method == "OPTIONS" {
                ctx.response.status = 204;
                return ctx.response;
            }
            return next(ctx);
        };
    }

    pub fn rate_limiter(max_requests: Int, window_ms: Int) -> Fn {
        let counters = {};
        return |ctx: http.Context, next: Fn| {
            let key = ctx.request.remote_addr;
            let now = native_api_now();
            if !counters.contains_key(key) { counters[key] = { "count": 0, "reset": now + window_ms }; }
            if now > counters[key]["reset"] {
                counters[key] = { "count": 0, "reset": now + window_ms };
            }
            counters[key]["count"] = counters[key]["count"] + 1;
            if counters[key]["count"] > max_requests {
                return http.Response::new(429).set_header("Retry-After", str(window_ms / 1000));
            }
            return next(ctx);
        };
    }

    pub fn logger() -> Fn {
        return |ctx: http.Context, next: Fn| {
            let start = native_api_now();
            let resp = next(ctx);
            let elapsed = native_api_now() - start;
            native_api_log(ctx.request.method + " " + ctx.request.path + " " + str(resp.status) + " " + str(elapsed) + "ms");
            return resp;
        };
    }

    pub fn json_parser() -> Fn {
        return |ctx: http.Context, next: Fn| {
            if ctx.request.raw_body != null && ctx.request.content_type == "application/json" {
                ctx.request.body = native_api_json_parse(ctx.request.raw_body);
            }
            return next(ctx);
        };
    }

    pub fn auth_bearer(validator: Fn) -> Fn {
        return |ctx: http.Context, next: Fn| {
            let auth = ctx.request.header("authorization");
            if auth == null || !auth.starts_with("Bearer ") {
                return http.Response::unauthorized("missing token");
            }
            let token = auth.slice(7, auth.len());
            let user = validator(token);
            if user == null {
                return http.Response::unauthorized("invalid token");
            }
            ctx.set_state("user", user);
            return next(ctx);
        };
    }
}

# ============================================================
# DEPENDENCY INJECTION
# ============================================================

pub mod di {
    pub class Container {
        pub let singletons: Map<String, Any>;
        pub let factories: Map<String, Fn>;

        pub fn new() -> Self {
            return Self { singletons: {}, factories: {} };
        }

        pub fn register_singleton(self, name: String, instance: Any) {
            self.singletons[name] = instance;
        }

        pub fn register_factory(self, name: String, factory: Fn) {
            self.factories[name] = factory;
        }

        pub fn resolve(self, name: String) -> Any? {
            if self.singletons.contains_key(name) { return self.singletons[name]; }
            if self.factories.contains_key(name) {
                let instance = self.factories[name](self);
                return instance;
            }
            return null;
        }
    }
}

# ============================================================
# OPENAPI GENERATION
# ============================================================

pub mod openapi {
    pub class SchemaBuilder {
        pub let paths: Map<String, Any>;
        pub let components: Map<String, Any>;
        pub let info: Map<String, String>;

        pub fn new(title: String, version: String) -> Self {
            return Self {
                paths: {},
                components: {},
                info: { "title": title, "version": version }
            };
        }

        pub fn add_path(self, path: String, method: String, spec: Map<String, Any>) {
            if !self.paths.contains_key(path) { self.paths[path] = {}; }
            self.paths[path][method.lower()] = spec;
        }

        pub fn generate(self) -> Map<String, Any> {
            return {
                "openapi": "3.0.3",
                "info": self.info,
                "paths": self.paths,
                "components": self.components
            };
        }
    }
}

# ============================================================
# API ENGINE ORCHESTRATOR
# ============================================================

pub class APIEngine {
    pub let router_inst: router.Router;
    pub let middleware_stack: List<Fn>;
    pub let container: di.Container;
    pub let schema: openapi.SchemaBuilder;
    pub let handle: Int?;

    pub fn new(title: String) -> Self {
        return Self {
            router_inst: router.Router::new(),
            middleware_stack: [],
            container: di.Container::new(),
            schema: openapi.SchemaBuilder::new(title, "1.0.0"),
            handle: null
        };
    }

    pub fn use_middleware(self, mw: Fn) -> Self {
        self.middleware_stack.append(mw);
        return self;
    }

    pub fn get(self, path: String, handler: Fn) -> Self {
        self.router_inst.get(path, handler);
        return self;
    }

    pub fn post(self, path: String, handler: Fn) -> Self {
        self.router_inst.post(path, handler);
        return self;
    }

    pub fn put(self, path: String, handler: Fn) -> Self {
        self.router_inst.put(path, handler);
        return self;
    }

    pub fn delete(self, path: String, handler: Fn) -> Self {
        self.router_inst.delete(path, handler);
        return self;
    }

    pub fn group(self, prefix: String) -> router.RouteGroup {
        return self.router_inst.group(prefix);
    }

    pub fn handle_request(self, req: http.Request) -> http.Response {
        let ctx = http.Context::new(req);
        let route = self.router_inst.match_route(req.method, req.path);
        if route == null { return http.Response::not_found(); }
        ctx.params = req.params;
        let handler = route.handler;
        let chain = self.middleware_stack.clone();
        let idx = 0;
        let run_next = null;
        run_next = |c| {
            if idx < chain.len() {
                let mw = chain[idx];
                idx = idx + 1;
                return mw(c, run_next);
            }
            return handler(c);
        };
        return run_next(ctx);
    }

    pub fn listen(self, host: String, port: Int) {
        self.handle = native_api_listen(host, port, |req| self.handle_request(req));
    }

    pub fn close(self) {
        if self.handle != null { native_api_close(self.handle); }
    }
}

pub fn create_api(title: String) -> APIEngine {
    return APIEngine::new(title);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_api_match_path(pattern: String, path: String) -> Bool;
native_api_now() -> Int;
native_api_log(msg: String);
native_api_json_parse(raw: String) -> Any;
native_api_listen(host: String, port: Int, handler: Fn) -> Int;
native_api_close(handle: Int);

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
