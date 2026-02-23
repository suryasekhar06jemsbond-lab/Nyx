# ============================================================
# NYKUBE - Nyx Kubernetes & Container Orchestration Engine
# ============================================================
# Cluster API client, pod/deployment/service management,
# auto-scaling, rolling updates, secrets, and namespaces.

let VERSION = "1.0.0";

# ============================================================
# CORE RESOURCE TYPES
# ============================================================

pub mod resources {
    pub class Metadata {
        pub let name: String;
        pub let namespace: String;
        pub let labels: Map<String, String>;
        pub let annotations: Map<String, String>;
        pub let uid: String;
        pub let created_at: Int;

        pub fn new(name: String, namespace: String) -> Self {
            return Self {
                name: name, namespace: namespace,
                labels: {}, annotations: {},
                uid: native_kube_uuid(),
                created_at: native_kube_now()
            };
        }

        pub fn matches_selector(self, selector: Map<String, String>) -> Bool {
            for key, val in selector {
                if !self.labels.contains_key(key) || self.labels[key] != val {
                    return false;
                }
            }
            return true;
        }
    }

    pub class ContainerSpec {
        pub let name: String;
        pub let image: String;
        pub let command: List<String>;
        pub let ports: List<Int>;
        pub let env: Map<String, String>;
        pub let cpu_limit: Float;
        pub let memory_limit_mb: Int;
        pub let readiness_probe: Map<String, Any>?;
        pub let liveness_probe: Map<String, Any>?;

        pub fn new(name: String, image: String) -> Self {
            return Self {
                name: name, image: image,
                command: [], ports: [], env: {},
                cpu_limit: 1.0, memory_limit_mb: 512,
                readiness_probe: null, liveness_probe: null
            };
        }

        pub fn with_port(self, port: Int) -> Self {
            self.ports.append(port);
            return self;
        }

        pub fn with_env(self, key: String, value: String) -> Self {
            self.env[key] = value;
            return self;
        }

        pub fn with_limits(self, cpu: Float, memory_mb: Int) -> Self {
            self.cpu_limit = cpu;
            self.memory_limit_mb = memory_mb;
            return self;
        }
    }

    pub class Pod {
        pub let metadata: Metadata;
        pub let containers: List<ContainerSpec>;
        pub let status: String;
        pub let restart_count: Int;
        pub let node_name: String?;
        pub let ip: String?;

        pub fn new(name: String, namespace: String, containers: List<ContainerSpec>) -> Self {
            return Self {
                metadata: Metadata::new(name, namespace),
                containers: containers,
                status: "Pending", restart_count: 0,
                node_name: null, ip: null
            };
        }

        pub fn is_ready(self) -> Bool { return self.status == "Running"; }
        pub fn is_failed(self) -> Bool { return self.status == "Failed"; }
    }
}

# ============================================================
# DEPLOYMENTS & REPLICA MANAGEMENT
# ============================================================

pub mod deployments {
    pub class DeploymentSpec {
        pub let replicas: Int;
        pub let selector: Map<String, String>;
        pub let template: resources.ContainerSpec;
        pub let strategy: String;
        pub let max_surge: Int;
        pub let max_unavailable: Int;

        pub fn new(replicas: Int, selector: Map<String, String>,
                   template: resources.ContainerSpec) -> Self {
            return Self {
                replicas: replicas, selector: selector,
                template: template, strategy: "RollingUpdate",
                max_surge: 1, max_unavailable: 0
            };
        }
    }

    pub class Deployment {
        pub let metadata: resources.Metadata;
        pub let spec: DeploymentSpec;
        pub let pods: List<resources.Pod>;
        pub let revision: Int;
        pub let available: Int;
        pub let updated: Int;

        pub fn new(name: String, namespace: String, spec: DeploymentSpec) -> Self {
            return Self {
                metadata: resources.Metadata::new(name, namespace),
                spec: spec, pods: [],
                revision: 1, available: 0, updated: 0
            };
        }

        pub fn reconcile(self) {
            let current = self.pods.filter(|p| p.status != "Terminated").len();
            if current < self.spec.replicas {
                let needed = self.spec.replicas - current;
                for i in 0..needed {
                    let pod_name = self.metadata.name + "-" + native_kube_uuid().slice(0, 8);
                    let pod = resources.Pod::new(pod_name, self.metadata.namespace,
                                                 [self.spec.template]);
                    pod.metadata.labels = self.spec.selector.clone();
                    self.pods.append(pod);
                }
            } else if current > self.spec.replicas {
                let excess = current - self.spec.replicas;
                let removed = 0;
                for pod in self.pods {
                    if removed >= excess { break; }
                    if pod.status != "Terminated" {
                        pod.status = "Terminated";
                        removed = removed + 1;
                    }
                }
            }
            self.available = self.pods.filter(|p| p.is_ready()).len();
            self.updated = self.pods.len();
        }

        pub fn rolling_update(self, new_template: resources.ContainerSpec) {
            self.revision = self.revision + 1;
            self.spec.template = new_template;
            let batch = self.spec.max_surge;
            for pod in self.pods {
                if pod.status != "Terminated" {
                    pod.status = "Terminated";
                    batch = batch - 1;
                    if batch <= 0 { break; }
                }
            }
            self.reconcile();
        }

        pub fn scale(self, replicas: Int) {
            self.spec.replicas = replicas;
            self.reconcile();
        }

        pub fn rollback(self) {
            if self.revision > 1 {
                self.revision = self.revision - 1;
                self.reconcile();
            }
        }
    }
}

# ============================================================
# SERVICES & NETWORKING
# ============================================================

pub mod services {
    pub class ServicePort {
        pub let name: String;
        pub let port: Int;
        pub let target_port: Int;
        pub let protocol: String;

        pub fn new(port: Int, target_port: Int) -> Self {
            return Self { name: "default", port: port, target_port: target_port, protocol: "TCP" };
        }
    }

    pub class Service {
        pub let metadata: resources.Metadata;
        pub let selector: Map<String, String>;
        pub let ports: List<ServicePort>;
        pub let type_: String;
        pub let cluster_ip: String?;
        pub let external_ip: String?;

        pub fn new(name: String, namespace: String, selector: Map<String, String>) -> Self {
            return Self {
                metadata: resources.Metadata::new(name, namespace),
                selector: selector, ports: [],
                type_: "ClusterIP",
                cluster_ip: native_kube_allocate_ip(),
                external_ip: null
            };
        }

        pub fn add_port(self, port: Int, target_port: Int) -> Self {
            self.ports.append(ServicePort::new(port, target_port));
            return self;
        }

        pub fn as_load_balancer(self) -> Self {
            self.type_ = "LoadBalancer";
            self.external_ip = native_kube_allocate_external_ip();
            return self;
        }

        pub fn as_node_port(self) -> Self {
            self.type_ = "NodePort";
            return self;
        }

        pub fn resolve_endpoints(self, pods: List<resources.Pod>) -> List<String> {
            let endpoints = [];
            for pod in pods {
                if pod.is_ready() && pod.metadata.matches_selector(self.selector) {
                    if pod.ip != null {
                        for sp in self.ports {
                            endpoints.append(pod.ip + ":" + sp.target_port.to_string());
                        }
                    }
                }
            }
            return endpoints;
        }
    }

    pub class Ingress {
        pub let metadata: resources.Metadata;
        pub let rules: List<IngressRule>;

        pub fn new(name: String, namespace: String) -> Self {
            return Self { metadata: resources.Metadata::new(name, namespace), rules: [] };
        }

        pub fn add_rule(self, host: String, path: String, service: String, port: Int) {
            self.rules.append(IngressRule { host: host, path: path,
                                            service_name: service, service_port: port });
        }
    }

    pub class IngressRule {
        pub let host: String;
        pub let path: String;
        pub let service_name: String;
        pub let service_port: Int;
    }
}

# ============================================================
# AUTO-SCALING
# ============================================================

pub mod autoscaling {
    pub class HPAConfig {
        pub let min_replicas: Int;
        pub let max_replicas: Int;
        pub let target_cpu_percent: Float;
        pub let target_memory_percent: Float;
        pub let scale_down_stabilization_s: Int;
        pub let scale_up_stabilization_s: Int;

        pub fn new(min_r: Int, max_r: Int) -> Self {
            return Self {
                min_replicas: min_r, max_replicas: max_r,
                target_cpu_percent: 80.0, target_memory_percent: 80.0,
                scale_down_stabilization_s: 300,
                scale_up_stabilization_s: 0
            };
        }
    }

    pub class HPA {
        pub let config: HPAConfig;
        pub let deployment_name: String;
        pub let current_metrics: Map<String, Float>;
        pub let last_scale_time: Int;

        pub fn new(deployment_name: String, config: HPAConfig) -> Self {
            return Self {
                config: config, deployment_name: deployment_name,
                current_metrics: {}, last_scale_time: 0
            };
        }

        pub fn evaluate(self, deployment: deployments.Deployment) -> Int? {
            let cpu = self.current_metrics.get("cpu_percent") ?? 0.0;
            let desired = (cpu / self.config.target_cpu_percent * deployment.spec.replicas.to_float()).ceil().to_int();
            let clamped = max(self.config.min_replicas, min(self.config.max_replicas, desired));
            if clamped != deployment.spec.replicas {
                let now = native_kube_now();
                if clamped > deployment.spec.replicas {
                    if now - self.last_scale_time >= self.config.scale_up_stabilization_s {
                        self.last_scale_time = now;
                        return clamped;
                    }
                } else {
                    if now - self.last_scale_time >= self.config.scale_down_stabilization_s {
                        self.last_scale_time = now;
                        return clamped;
                    }
                }
            }
            return null;
        }
    }

    pub class VPA {
        pub let deployment_name: String;
        pub let recommendations: Map<String, Map<String, Any>>;

        pub fn new(deployment_name: String) -> Self {
            return Self { deployment_name: deployment_name, recommendations: {} };
        }

        pub fn analyze(self, usage_history: List<Map<String, Float>>) {
            if usage_history.len() == 0 { return; }
            let cpu_vals = usage_history.map(|u| u.get("cpu") ?? 0.0);
            let mem_vals = usage_history.map(|u| u.get("memory_mb") ?? 0.0);
            let p95_cpu = percentile(cpu_vals, 95.0);
            let p95_mem = percentile(mem_vals, 95.0);
            self.recommendations = {
                "cpu": { "target": p95_cpu * 1.15, "lower": p95_cpu * 0.5, "upper": p95_cpu * 2.0 },
                "memory_mb": { "target": p95_mem * 1.15, "lower": p95_mem * 0.5, "upper": p95_mem * 2.0 }
            };
        }
    }

    fn percentile(values: List<Float>, p: Float) -> Float {
        let sorted = values.sorted();
        let idx = ((p / 100.0) * (sorted.len() - 1).to_float()).to_int();
        return sorted[idx];
    }
}

# ============================================================
# SECRETS & CONFIG MANAGEMENT
# ============================================================

pub mod secrets {
    pub class Secret {
        pub let metadata: resources.Metadata;
        pub let data: Map<String, String>;
        pub let type_: String;

        pub fn new(name: String, namespace: String) -> Self {
            return Self {
                metadata: resources.Metadata::new(name, namespace),
                data: {}, type_: "Opaque"
            };
        }

        pub fn set(self, key: String, value: String) {
            self.data[key] = native_kube_base64_encode(value);
        }

        pub fn get(self, key: String) -> String? {
            if !self.data.contains_key(key) { return null; }
            return native_kube_base64_decode(self.data[key]);
        }
    }

    pub class ConfigMap {
        pub let metadata: resources.Metadata;
        pub let data: Map<String, String>;

        pub fn new(name: String, namespace: String) -> Self {
            return Self { metadata: resources.Metadata::new(name, namespace), data: {} };
        }

        pub fn set(self, key: String, value: String) { self.data[key] = value; }
        pub fn get(self, key: String) -> String? { return self.data.get(key); }
    }
}

# ============================================================
# NAMESPACE & RESOURCE QUOTAS
# ============================================================

pub mod namespaces {
    pub class Namespace {
        pub let name: String;
        pub let labels: Map<String, String>;
        pub let status: String;

        pub fn new(name: String) -> Self {
            return Self { name: name, labels: {}, status: "Active" };
        }
    }

    pub class ResourceQuota {
        pub let namespace: String;
        pub let limits: Map<String, Any>;
        pub let used: Map<String, Any>;

        pub fn new(namespace: String) -> Self {
            return Self {
                namespace: namespace,
                limits: { "pods": 100, "cpu": 16.0, "memory_gb": 64 },
                used: { "pods": 0, "cpu": 0.0, "memory_gb": 0 }
            };
        }

        pub fn can_allocate(self, resource: String, amount: Any) -> Bool {
            let current = self.used.get(resource) ?? 0;
            let limit = self.limits.get(resource) ?? 0;
            return current + amount <= limit;
        }
    }
}

# ============================================================
# KUBE ENGINE ORCHESTRATOR
# ============================================================

pub class KubeEngine {
    pub let namespaces: Map<String, namespaces.Namespace>;
    pub let deployments: Map<String, deployments.Deployment>;
    pub let services_map: Map<String, services.Service>;
    pub let hpas: Map<String, autoscaling.HPA>;
    pub let secrets_store: Map<String, secrets.Secret>;
    pub let config_maps: Map<String, secrets.ConfigMap>;

    pub fn new() -> Self {
        let ns = {};
        ns["default"] = namespaces.Namespace::new("default");
        return Self {
            namespaces: ns,
            deployments: {},
            services_map: {},
            hpas: {},
            secrets_store: {},
            config_maps: {}
        };
    }

    pub fn create_namespace(self, name: String) -> namespaces.Namespace {
        let ns = namespaces.Namespace::new(name);
        self.namespaces[name] = ns;
        return ns;
    }

    pub fn create_deployment(self, name: String, namespace: String,
                              image: String, replicas: Int) -> deployments.Deployment {
        let container = resources.ContainerSpec::new(name, image);
        let selector = { "app": name };
        let spec = deployments.DeploymentSpec::new(replicas, selector, container);
        let dep = deployments.Deployment::new(name, namespace, spec);
        dep.reconcile();
        self.deployments[namespace + "/" + name] = dep;
        return dep;
    }

    pub fn create_service(self, name: String, namespace: String,
                           selector: Map<String, String>, port: Int,
                           target_port: Int) -> services.Service {
        let svc = services.Service::new(name, namespace, selector);
        svc.add_port(port, target_port);
        self.services_map[namespace + "/" + name] = svc;
        return svc;
    }

    pub fn expose(self, deployment_name: String, namespace: String,
                   port: Int) -> services.Service {
        let selector = { "app": deployment_name };
        return self.create_service(deployment_name, namespace, selector, port, port);
    }

    pub fn scale(self, deployment_name: String, namespace: String, replicas: Int) {
        let key = namespace + "/" + deployment_name;
        if self.deployments.contains_key(key) {
            self.deployments[key].scale(replicas);
        }
    }

    pub fn setup_hpa(self, deployment_name: String, namespace: String,
                      min_r: Int, max_r: Int) -> autoscaling.HPA {
        let config = autoscaling.HPAConfig::new(min_r, max_r);
        let hpa = autoscaling.HPA::new(deployment_name, config);
        self.hpas[namespace + "/" + deployment_name] = hpa;
        return hpa;
    }

    pub fn reconcile_all(self) {
        for key, dep in self.deployments {
            dep.reconcile();
            if self.hpas.contains_key(key) {
                let desired = self.hpas[key].evaluate(dep);
                if desired != null {
                    dep.scale(desired);
                }
            }
        }
    }
}

pub fn create_kube() -> KubeEngine {
    return KubeEngine::new();
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_kube_now() -> Int;
native_kube_uuid() -> String;
native_kube_allocate_ip() -> String;
native_kube_allocate_external_ip() -> String;
native_kube_base64_encode(data: String) -> String;
native_kube_base64_decode(data: String) -> String;

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
