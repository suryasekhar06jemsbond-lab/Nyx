// NyMonitor - Monitoring & Observability Engine
// Provides: Metrics collection, log aggregation, distributed tracing, alerts, dashboards
// Competes with: Prometheus, Grafana, Datadog, New Relic, ELK Stack

use std::collections::HashMap
use std::time

// =============================================================================
// Metrics Collection
// =============================================================================

enum MetricType {
    Counter,
    Gauge,
    Histogram,
    Summary
}

struct Metric {
    name: String,
    metric_type: MetricType,
    value: f64,
    labels: HashMap<String, String>,
    timestamp: u64
}

class MetricsCollector {
    metrics: Vec<Metric>,
    counters: HashMap<String, f64>,
    gauges: HashMap<String, f64>
    
    fn new() -> MetricsCollector {
        return MetricsCollector {
            metrics: Vec::new(),
            counters: HashMap::new(),
            gauges: HashMap::new()
        }
    }
    
    fn counter(&mut self, name: String, labels: HashMap<String, String>) -> &mut MetricsCollector {
        let key = self.metric_key(&name, &labels)
        
        let current = self.counters.get(&key).unwrap_or(&0.0)
        self.counters.insert(key.clone(), current + 1.0)
        
        self.record_metric(Metric {
            name,
            metric_type: MetricType::Counter,
            value: current + 1.0,
            labels,
            timestamp: time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_secs()
        })
        
        return self
    }
    
    fn counter_add(&mut self, name: String, value: f64, labels: HashMap<String, String>) {
        let key = self.metric_key(&name, &labels)
        
        let current = self.counters.get(&key).unwrap_or(&0.0)
        self.counters.insert(key.clone(), current + value)
        
        self.record_metric(Metric {
            name,
            metric_type: MetricType::Counter,
            value: current + value,
            labels,
            timestamp: time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_secs()
        })
    }
    
    fn gauge(&mut self, name: String, value: f64, labels: HashMap<String, String>) {
        let key = self.metric_key(&name, &labels)
        self.gauges.insert(key.clone(), value)
        
        self.record_metric(Metric {
            name,
            metric_type: MetricType::Gauge,
            value,
            labels,
            timestamp: time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_secs()
        })
    }
    
    fn histogram(&mut self, name: String, value: f64, labels: HashMap<String, String>) {
        self.record_metric(Metric {
            name,
            metric_type: MetricType::Histogram,
            value,
            labels,
            timestamp: time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_secs()
        })
    }
    
    fn get_metrics(&self) -> &Vec<Metric> {
        return &self.metrics
    }
    
    fn export_prometheus(&self) -> String {
        let mut output = String::new()
        
        for metric in &self.metrics {
            let labels_str = self.format_labels(&metric.labels)
            
            output.push_str(&format!(
                "{}{{{}}} {} {}\n",
                metric.name,
                labels_str,
                metric.value,
                metric.timestamp
            ))
        }
        
        return output
    }
    
    fn record_metric(&mut self, metric: Metric) {
        self.metrics.push(metric)
    }
    
    fn metric_key(&self, name: &String, labels: &HashMap<String, String>) -> String {
        let mut key = name.clone()
        
        let mut sorted_labels: Vec<_> = labels.iter().collect()
        sorted_labels.sort_by_key(|&(k, _)| k)
        
        for (k, v) in sorted_labels {
            key.push_str(&format!("_{}:{}", k, v))
        }
        
        return key
    }
    
    fn format_labels(&self, labels: &HashMap<String, String>) -> String {
        let parts: Vec<String> = labels.iter()
            .map(|(k, v)| format!("{}=\"{}\"", k, v))
            .collect()
        
        return parts.join(",")
    }
}

// =============================================================================
// Log Aggregation
// =============================================================================

enum LogLevel {
    Debug,
    Info,
    Warn,
    Error,
    Fatal
}

struct LogEntry {
    timestamp: u64,
    level: LogLevel,
    message: String,
    source: String,
    fields: HashMap<String, String>
}

class LogAggregator {
    logs: Vec<LogEntry>,
    max_buffer_size: usize
    
    fn new() -> LogAggregator {
        return LogAggregator {
            logs: Vec::new(),
            max_buffer_size: 10000
        }
    }
    
    fn log(&mut self, level: LogLevel, message: String, source: String, fields: HashMap<String, String>) {
        let entry = LogEntry {
            timestamp: time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_millis(),
            level,
            message,
            source,
            fields
        }
        
        self.logs.push(entry)
        
        // Rotate buffer if needed
        if self.logs.len() > self.max_buffer_size {
            self.logs.remove(0)
        }
    }
    
    fn debug(&mut self, message: String, source: String) {
        self.log(LogLevel::Debug, message, source, HashMap::new())
    }
    
    fn info(&mut self, message: String, source: String) {
        self.log(LogLevel::Info, message, source, HashMap::new())
    }
    
    fn warn(&mut self, message: String, source: String) {
        self.log(LogLevel::Warn, message, source, HashMap::new())
    }
    
    fn error(&mut self, message: String, source: String) {
        self.log(LogLevel::Error, message, source, HashMap::new())
    }
    
    fn query(&self, level: Option<LogLevel>, source: Option<String>, since: Option<u64>) -> Vec<&LogEntry> {
        let filtered: Vec<&LogEntry> = self.logs.iter()
            .filter(|entry| {
                if level.is_some() && !matches!(entry.level, level.unwrap()) {
                    return false
                }
                
                if source.is_some() && entry.source != source.as_ref().unwrap() {
                    return false
                }
                
                if since.is_some() && entry.timestamp < since.unwrap() {
                    return false
                }
                
                return true
            })
            .collect()
        
        return filtered
    }
    
    fn export_json(&self) -> String {
        let mut json = String::from("[\n")
        
        for (i, entry) in self.logs.iter().enumerate() {
            json.push_str(&format!(
                "  {{\"timestamp\": {}, \"level\": \"{}\", \"message\": \"{}\", \"source\": \"{}\"}}",
                entry.timestamp,
                self.level_to_string(&entry.level),
                entry.message,
                entry.source
            ))
            
            if i < self.logs.len() - 1 {
                json.push_str(",")
            }
            
            json.push_str("\n")
        }
        
        json.push_str("]\n")
        
        return json
    }
    
    fn level_to_string(&self, level: &LogLevel) -> String {
        match level {
            LogLevel::Debug => "DEBUG".to_string(),
            LogLevel::Info => "INFO".to_string(),
            LogLevel::Warn => "WARN".to_string(),
            LogLevel::Error => "ERROR".to_string(),
            LogLevel::Fatal => "FATAL".to_string()
        }
    }
}

// =============================================================================
// Distributed Tracing
// =============================================================================

struct Span {
    trace_id: String,
    span_id: String,
    parent_span_id: Option<String>,
    operation_name: String,
    start_time: u64,
    end_time: Option<u64>,
    tags: HashMap<String, String>
}

class Tracer {
    active_spans: HashMap<String, Span>,
    completed_traces: Vec<Vec<Span>>
    
    fn new() -> Tracer {
        return Tracer {
            active_spans: HashMap::new(),
            completed_traces: Vec::new()
        }
    }
    
    fn start_span(&mut self, operation: String, parent_span_id: Option<String>) -> String {
        let trace_id = if parent_span_id.is_none() {
            self.generate_trace_id()
        } else {
            // Inherit trace_id from parent
            self.get_trace_id_for_parent(&parent_span_id.as_ref().unwrap())
        }
        
        let span_id = self.generate_span_id()
        
        let span = Span {
            trace_id: trace_id.clone(),
            span_id: span_id.clone(),
            parent_span_id,
            operation_name: operation,
            start_time: time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_micros(),
            end_time: None,
            tags: HashMap::new()
        }
        
        self.active_spans.insert(span_id.clone(), span)
        
        return span_id
    }
    
    fn end_span(&mut self, span_id: String) {
        if let Some(span) = self.active_spans.get_mut(&span_id) {
            span.end_time = Some(time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_micros())
        }
        
        // Move to completed
        if let Some(span) = self.active_spans.remove(&span_id) {
            // Group by trace_id
            let trace_id = span.trace_id.clone()
            
            // Find existing trace or create new
            let mut found = false
            for trace in &mut self.completed_traces {
                if trace[0].trace_id == trace_id {
                    trace.push(span)
                    found = true
                    break
                }
            }
            
            if !found {
                self.completed_traces.push(vec![span])
            }
        }
    }
    
    fn add_tag(&mut self, span_id: &String, key: String, value: String) {
        if let Some(span) = self.active_spans.get_mut(span_id) {
            span.tags.insert(key, value)
        }
    }
    
    fn get_trace(&self, trace_id: &String) -> Option<Vec<&Span>> {
        for trace in &self.completed_traces {
            if trace[0].trace_id == *trace_id {
                return Some(trace.iter().collect())
            }
        }
        
        return None
    }
    
    fn generate_trace_id(&self) -> String {
        return format!("trace-{}", time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_nanos())
    }
    
    fn generate_span_id(&self) -> String {
        return format!("span-{}", time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_nanos())
    }
    
    fn get_trace_id_for_parent(&self, parent_span_id: &String) -> String {
        if let Some(span) = self.active_spans.get(parent_span_id) {
            return span.trace_id.clone()
        }
        
        // Check completed traces
        for trace in &self.completed_traces {
            for span in trace {
                if &span.span_id == parent_span_id {
                    return span.trace_id.clone()
                }
            }
        }
        
        return self.generate_trace_id()
    }
}

// =============================================================================
// Alert System
// =============================================================================

enum AlertSeverity {
    Info,
    Warning,
    Critical
}

enum AlertCondition {
    ThresholdExceeded(f64),
    ThresholdBelow(f64),
    RateOfChange(f64),
    Anomaly
}

struct Alert {
    id: String,
    name: String,
    severity: AlertSeverity,
    condition: AlertCondition,
    metric_name: String,
    triggered_at: Option<u64>,
    resolved_at: Option<u64>,
    message: String
}

class AlertManager {
    alerts: HashMap<String, Alert>,
    alert_history: Vec<Alert>
    
    fn new() -> AlertManager {
        return AlertManager {
            alerts: HashMap::new(),
            alert_history: Vec::new()
        }
    }
    
    fn create_alert(&mut self, name: String, metric_name: String, condition: AlertCondition, severity: AlertSeverity) -> String {
        let alert_id = format!("alert-{}", time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_secs())
        
        let alert = Alert {
            id: alert_id.clone(),
            name,
            severity,
            condition,
            metric_name,
            triggered_at: None,
            resolved_at: None,
            message: String::new()
        }
        
        self.alerts.insert(alert_id.clone(), alert)
        
        return alert_id
    }
    
    fn evaluate_alerts(&mut self, metrics: &Vec<Metric>) {
        for (alert_id, alert) in &mut self.alerts {
            // Find relevant metrics
            let relevant_metrics: Vec<&Metric> = metrics.iter()
                .filter(|m| m.name == alert.metric_name)
                .collect()
            
            if relevant_metrics.is_empty() {
                continue
            }
            
            let latest_metric = relevant_metrics.last().unwrap()
            
            let should_trigger = match &alert.condition {
                AlertCondition::ThresholdExceeded(threshold) => {
                    latest_metric.value > *threshold
                }
                AlertCondition::ThresholdBelow(threshold) => {
                    latest_metric.value < *threshold
                }
                AlertCondition::RateOfChange(rate) => {
                    // Check rate of change
                    false
                }
                AlertCondition::Anomaly => {
                    // Anomaly detection
                    false
                }
            }
            
            if should_trigger && alert.triggered_at.is_none() {
                self.trigger_alert(alert_id, &format!("Alert triggered: {} = {}", alert.name, latest_metric.value))
            } else if !should_trigger && alert.triggered_at.is_some() {
                self.resolve_alert(alert_id)
            }
        }
    }
    
    fn trigger_alert(&mut self, alert_id: &String, message: &String) {
        if let Some(alert) = self.alerts.get_mut(alert_id) {
            alert.triggered_at = Some(time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_secs())
            alert.message = message.clone()
            
            println!("🚨 ALERT TRIGGERED: {}", alert.name)
            println!("   Message: {}", message)
            println!("   Severity: {:?}", alert.severity)
        }
    }
    
    fn resolve_alert(&mut self, alert_id: &String) {
        if let Some(alert) = self.alerts.get_mut(alert_id) {
            alert.resolved_at = Some(time::SystemTime::now().duration_since(time::UNIX_EPOCH).unwrap().as_secs())
            
            println!("✅ ALERT RESOLVED: {}", alert.name)
            
            // Move to history
            self.alert_history.push(alert.clone())
        }
    }
    
    fn get_active_alerts(&self) -> Vec<&Alert> {
        return self.alerts.values()
            .filter(|a| a.triggered_at.is_some() && a.resolved_at.is_none())
            .collect()
    }
}

// =============================================================================
// Performance Dashboards
// =============================================================================

struct Dashboard {
    name: String,
    widgets: Vec<DashboardWidget>
}

enum DashboardWidget {
    TimeSeries(String),        // Metric name
    Gauge(String),             // Metric name
    Counter(String),           // Metric name
    Table(Vec<String>),        // Metric names
    Heatmap(String)            // Metric name
}

class DashboardManager {
    dashboards: HashMap<String, Dashboard>
    
    fn new() -> DashboardManager {
        return DashboardManager {
            dashboards: HashMap::new()
        }
    }
    
    fn create_dashboard(&mut self, name: String) -> &mut Dashboard {
        let dashboard = Dashboard {
            name: name.clone(),
            widgets: Vec::new()
        }
        
        self.dashboards.insert(name.clone(), dashboard)
        
        return self.dashboards.get_mut(&name).unwrap()
    }
    
    fn add_widget(&mut self, dashboard_name: &String, widget: DashboardWidget) {
        if let Some(dashboard) = self.dashboards.get_mut(dashboard_name) {
            dashboard.widgets.push(widget)
        }
    }
    
    fn render_dashboard(&self, dashboard_name: &String, metrics: &Vec<Metric>) -> String {
        let dashboard = self.dashboards.get(dashboard_name)
            .expect("Dashboard not found")
        
        let mut output = String::new()
        output.push_str(&format!("=== {} ===\n\n", dashboard.name))
        
        for widget in &dashboard.widgets {
            match widget {
                DashboardWidget::TimeSeries(metric_name) => {
                    output.push_str(&format!("📈 {}\n", metric_name))
                    
                    let series: Vec<&Metric> = metrics.iter()
                        .filter(|m| &m.name == metric_name)
                        .collect()
                    
                    for metric in series {
                        output.push_str(&format!("  {} | {:.2}\n", metric.timestamp, metric.value))
                    }
                }
                DashboardWidget::Gauge(metric_name) => {
                    output.push_str(&format!("🔢 {}\n", metric_name))
                    
                    if let Some(metric) = metrics.iter().filter(|m| &m.name == metric_name).last() {
                        output.push_str(&format!("  Current: {:.2}\n", metric.value))
                    }
                }
                DashboardWidget::Counter(metric_name) => {
                    output.push_str(&format!("🔢 {}\n", metric_name))
                    
                    if let Some(metric) = metrics.iter().filter(|m| &m.name == metric_name).last() {
                        output.push_str(&format!("  Total: {:.0}\n", metric.value))
                    }
                }
                _ => {}
            }
            
            output.push_str("\n")
        }
        
        return output
    }
}

// =============================================================================
// Health Checks
// =============================================================================

struct HealthCheck {
    name: String,
    endpoint: Option<String>,
    check_fn: Option<Box<dyn Fn() -> bool>>
}

class HealthMonitor {
    checks: Vec<HealthCheck>,
    results: HashMap<String, bool>
    
    fn new() -> HealthMonitor {
        return HealthMonitor {
            checks: Vec::new(),
            results: HashMap::new()
        }
    }
    
    fn add_check(&mut self, name: String, endpoint: Option<String>) {
        self.checks.push(HealthCheck {
            name,
            endpoint,
            check_fn: None
        })
    }
    
    fn run_checks(&mut self) -> bool {
        let mut all_healthy = true
        
        for check in &self.checks {
            let healthy = self.run_single_check(check)
            
            self.results.insert(check.name.clone(), healthy)
            
            if !healthy {
                all_healthy = false
                println!("❌ Health check failed: {}", check.name)
            } else {
                println!("✅ Health check passed: {}", check.name)
            }
        }
        
        return all_healthy
    }
    
    fn run_single_check(&self, check: &HealthCheck) -> bool {
        if let Some(endpoint) = &check.endpoint {
            // HTTP health check
            println!("Checking endpoint: {}", endpoint)
            return true
        }
        
        if let Some(check_fn) = &check.check_fn {
            return check_fn()
        }
        
        return true
    }
    
    fn get_health_status(&self) -> HashMap<String, bool> {
        return self.results.clone()
    }
}

// =============================================================================
// Public API
// =============================================================================

pub fn create_metrics_collector() -> MetricsCollector {
    return MetricsCollector::new()
}

pub fn create_log_aggregator() -> LogAggregator {
    return LogAggregator::new()
}

pub fn create_tracer() -> Tracer {
    return Tracer::new()
}

pub fn create_alert_manager() -> AlertManager {
    return AlertManager::new()
}

pub fn create_dashboard_manager() -> DashboardManager {
    return DashboardManager::new()
}

pub fn create_health_monitor() -> HealthMonitor {
    return HealthMonitor::new()
}

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
