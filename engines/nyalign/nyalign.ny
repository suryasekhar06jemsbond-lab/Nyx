# ============================================================
# NYALIGN - Nyx AI Safety & Alignment Engine
# ============================================================
# Policy enforcement, goal constraint validation, ethical rules,
# safety overrides, bias detection, explainability, and
# alignment verification.

let VERSION = "1.0.0";

# ============================================================
# SAFETY POLICIES
# ============================================================

pub mod policy {
    pub class SafetyPolicy {
        pub let id: String;
        pub let name: String;
        pub let description: String;
        pub let rules: List<SafetyRule>;
        pub let priority: Int;
        pub let enabled: Bool;

        pub fn new(id: String, name: String) -> Self {
            return Self {
                id: id, name: name, description: "",
                rules: [], priority: 0, enabled: true
            };
        }

        pub fn add_rule(self, rule: SafetyRule) {
            self.rules.append(rule);
        }

        pub fn evaluate(self, context: Map<String, Any>) -> PolicyResult {
            if !self.enabled {
                return PolicyResult { policy_id: self.id, allowed: true, violations: [], score: 1.0 };
            }
            let violations = [];
            for rule in self.rules {
                let result = rule.check(context);
                if !result { violations.append(rule); }
            }
            return PolicyResult {
                policy_id: self.id,
                allowed: violations.len() == 0,
                violations: violations,
                score: 1.0 - (violations.len() as Float / self.rules.len() as Float)
            };
        }
    }

    pub class SafetyRule {
        pub let id: String;
        pub let description: String;
        pub let check_fn: Fn;
        pub let severity: String;
        pub let category: String;

        pub fn new(id: String, desc: String, check: Fn, severity: String) -> Self {
            return Self {
                id: id, description: desc,
                check_fn: check, severity: severity,
                category: "general"
            };
        }

        pub fn check(self, context: Map<String, Any>) -> Bool {
            return self.check_fn(context);
        }
    }

    pub class PolicyResult {
        pub let policy_id: String;
        pub let allowed: Bool;
        pub let violations: List<SafetyRule>;
        pub let score: Float;
    }

    pub class PolicyEngine {
        pub let policies: List<SafetyPolicy>;
        pub let enforcement_mode: String;
        pub let audit_log: List<Map<String, Any>>;

        pub fn new() -> Self {
            return Self { policies: [], enforcement_mode: "strict", audit_log: [] };
        }

        pub fn add_policy(self, policy: SafetyPolicy) {
            self.policies.append(policy);
            self.policies.sort_by(|a, b| b.priority - a.priority);
        }

        pub fn evaluate(self, context: Map<String, Any>) -> Map<String, Any> {
            let all_results = [];
            let blocked = false;
            let critical_violations = [];
            for policy in self.policies {
                let result = policy.evaluate(context);
                all_results.append(result);
                if !result.allowed {
                    for v in result.violations {
                        if v.severity == "critical" {
                            critical_violations.append(v);
                            blocked = true;
                        }
                    }
                    if self.enforcement_mode == "strict" { blocked = true; }
                }
            }
            self.audit_log.append({
                "timestamp": native_align_now(),
                "context": context, "blocked": blocked,
                "violations": critical_violations.len()
            });
            return { "allowed": !blocked, "results": all_results, "critical": critical_violations };
        }
    }
}

# ============================================================
# GOAL CONSTRAINTS & ALIGNMENT
# ============================================================

pub mod goals {
    pub class GoalConstraint {
        pub let id: String;
        pub let description: String;
        pub let constraint_fn: Fn;
        pub let weight: Float;

        pub fn new(id: String, desc: String, check: Fn) -> Self {
            return Self { id: id, description: desc, constraint_fn: check, weight: 1.0 };
        }

        pub fn satisfied(self, state: Map<String, Any>) -> Bool {
            return self.constraint_fn(state);
        }
    }

    pub class AlignmentSpec {
        pub let primary_goals: List<String>;
        pub let constraints: List<GoalConstraint>;
        pub let forbidden_actions: List<String>;
        pub let required_properties: List<String>;

        pub fn new() -> Self {
            return Self {
                primary_goals: [], constraints: [],
                forbidden_actions: [], required_properties: []
            };
        }

        pub fn add_constraint(self, constraint: GoalConstraint) {
            self.constraints.append(constraint);
        }

        pub fn add_forbidden(self, action: String) {
            self.forbidden_actions.append(action);
        }

        pub fn is_aligned(self, action: String, state: Map<String, Any>) -> Map<String, Any> {
            if self.forbidden_actions.contains(action) {
                return { "aligned": false, "reason": "forbidden_action", "action": action };
            }
            let violated = [];
            for c in self.constraints {
                if !c.satisfied(state) { violated.append(c.id); }
            }
            return {
                "aligned": violated.len() == 0,
                "violated_constraints": violated,
                "satisfaction": 1.0 - (violated.len() as Float / self.constraints.len() as Float)
            };
        }
    }

    pub class GoalVerifier {
        pub let spec: AlignmentSpec;
        pub let history: List<Map<String, Any>>;

        pub fn new(spec: AlignmentSpec) -> Self {
            return Self { spec: spec, history: [] };
        }

        pub fn verify_action(self, action: String, state: Map<String, Any>) -> Map<String, Any> {
            let result = self.spec.is_aligned(action, state);
            self.history.append({ "action": action, "result": result, "timestamp": native_align_now() });
            return result;
        }

        pub fn alignment_score(self) -> Float {
            if self.history.len() == 0 { return 1.0; }
            let aligned = self.history.filter(|h| h["result"]["aligned"]).len();
            return aligned as Float / self.history.len() as Float;
        }
    }
}

# ============================================================
# BIAS DETECTION & FAIRNESS
# ============================================================

pub mod fairness {
    pub class FairnessMetric {
        pub let name: String;
        pub let compute_fn: Fn;

        pub fn new(name: String, compute: Fn) -> Self {
            return Self { name: name, compute_fn: compute };
        }

        pub fn evaluate(self, predictions: List<Any>, labels: List<Any>,
                        protected: List<Any>) -> Float {
            return self.compute_fn(predictions, labels, protected);
        }
    }

    pub class BiasDetector {
        pub let metrics: List<FairnessMetric>;
        pub let threshold: Float;

        pub fn new(threshold: Float) -> Self {
            return Self { metrics: [], threshold: threshold };
        }

        pub fn add_metric(self, metric: FairnessMetric) {
            self.metrics.append(metric);
        }

        pub fn detect(self, predictions: List<Any>, labels: List<Any>,
                      protected_attr: List<Any>) -> Map<String, Any> {
            let results = {};
            let biased = false;
            for m in self.metrics {
                let score = m.evaluate(predictions, labels, protected_attr);
                results[m.name] = score;
                if score < self.threshold { biased = true; }
            }
            return { "biased": biased, "metrics": results, "threshold": self.threshold };
        }

        pub fn demographic_parity(self, predictions: List<Any>,
                                   protected: List<Any>) -> Float {
            let groups = {};
            for i in 0..predictions.len() {
                let g = str(protected[i]);
                if !groups.contains_key(g) { groups[g] = { "total": 0, "positive": 0 }; }
                groups[g]["total"] = groups[g]["total"] + 1;
                if predictions[i] == 1 { groups[g]["positive"] = groups[g]["positive"] + 1; }
            }
            let rates = [];
            for k, v in groups { rates.append(v["positive"] as Float / v["total"] as Float); }
            if rates.len() < 2 { return 1.0; }
            return rates.min() / rates.max();
        }

        pub fn equalized_odds(self, predictions: List<Any>, labels: List<Any>,
                               protected: List<Any>) -> Float {
            let groups = {};
            for i in 0..predictions.len() {
                let g = str(protected[i]);
                if !groups.contains_key(g) {
                    groups[g] = { "tp": 0, "fp": 0, "tn": 0, "fn": 0 };
                }
                if predictions[i] == 1 && labels[i] == 1 { groups[g]["tp"] = groups[g]["tp"] + 1; }
                if predictions[i] == 1 && labels[i] == 0 { groups[g]["fp"] = groups[g]["fp"] + 1; }
                if predictions[i] == 0 && labels[i] == 0 { groups[g]["tn"] = groups[g]["tn"] + 1; }
                if predictions[i] == 0 && labels[i] == 1 { groups[g]["fn"] = groups[g]["fn"] + 1; }
            }
            let tprs = [];
            for k, v in groups {
                let tpr = if v["tp"] + v["fn"] > 0 { v["tp"] as Float / (v["tp"] + v["fn"]) as Float } else { 0.0 };
                tprs.append(tpr);
            }
            if tprs.len() < 2 { return 1.0; }
            return 1.0 - (tprs.max() - tprs.min()).abs();
        }
    }
}

# ============================================================
# EXPLAINABILITY
# ============================================================

pub mod explainability {
    pub class Explanation {
        pub let decision: String;
        pub let factors: List<Map<String, Any>>;
        pub let confidence: Float;
        pub let counterfactuals: List<Map<String, Any>>;
        pub let reasoning_chain: List<String>;

        pub fn new(decision: String) -> Self {
            return Self {
                decision: decision, factors: [],
                confidence: 0.0, counterfactuals: [],
                reasoning_chain: []
            };
        }

        pub fn add_factor(self, name: String, importance: Float, value: Any) {
            self.factors.append({ "name": name, "importance": importance, "value": value });
        }

        pub fn add_counterfactual(self, change: String, outcome: String) {
            self.counterfactuals.append({ "change": change, "outcome": outcome });
        }

        pub fn summary(self) -> String {
            let parts = ["Decision: " + self.decision];
            self.factors.sort_by(|a, b| b["importance"] - a["importance"]);
            for f in self.factors.slice(0, 5) {
                parts.append("  - " + f["name"] + " (importance: " + str(f["importance"]) + ")");
            }
            return parts.join("\n");
        }
    }

    pub class ExplainabilityEngine {
        pub let method: String;

        pub fn new(method: String) -> Self {
            return Self { method: method };
        }

        pub fn explain(self, model: Any, input: Map<String, Any>) -> Explanation {
            if self.method == "feature_importance" {
                return self._feature_importance(model, input);
            }
            if self.method == "shap" {
                return self._shap_explain(model, input);
            }
            return Explanation::new("unknown");
        }

        fn _feature_importance(self, model: Any, input: Map<String, Any>) -> Explanation {
            let result = native_align_explain_fi(model, input);
            let exp = Explanation::new(str(result["decision"]));
            exp.confidence = result["confidence"];
            for f in result["importances"] {
                exp.add_factor(f["name"], f["score"], input.get(f["name"]));
            }
            return exp;
        }

        fn _shap_explain(self, model: Any, input: Map<String, Any>) -> Explanation {
            let result = native_align_explain_shap(model, input);
            let exp = Explanation::new(str(result["decision"]));
            exp.confidence = result["confidence"];
            for k, v in result["shap_values"] {
                exp.add_factor(k, v, input.get(k));
            }
            return exp;
        }
    }
}

# ============================================================
# SAFETY OVERRIDES & KILL SWITCH
# ============================================================

pub mod safety {
    pub class SafetyOverride {
        pub let trigger_condition: Fn;
        pub let action: Fn;
        pub let priority: Int;
        pub let description: String;

        pub fn new(desc: String, trigger: Fn, action: Fn, priority: Int) -> Self {
            return Self {
                trigger_condition: trigger, action: action,
                priority: priority, description: desc
            };
        }

        pub fn check_and_act(self, state: Map<String, Any>) -> Bool {
            if self.trigger_condition(state) {
                self.action(state);
                return true;
            }
            return false;
        }
    }

    pub class KillSwitch {
        pub let active: Bool;
        pub let reason: String?;
        pub let triggered_at: Int?;
        pub let on_kill: Fn?;

        pub fn new() -> Self {
            return Self { active: false, reason: null, triggered_at: null, on_kill: null };
        }

        pub fn trigger(self, reason: String) {
            self.active = true;
            self.reason = reason;
            self.triggered_at = native_align_now();
            if self.on_kill != null { self.on_kill(reason); }
        }

        pub fn reset(self, auth_token: String) -> Bool {
            if !native_align_verify_auth(auth_token) { return false; }
            self.active = false;
            self.reason = null;
            return true;
        }

        pub fn is_active(self) -> Bool { return self.active; }
    }

    pub class SafetyMonitor {
        pub let overrides: List<SafetyOverride>;
        pub let kill_switch: KillSwitch;
        pub let anomaly_threshold: Float;
        pub let incident_log: List<Map<String, Any>>;

        pub fn new() -> Self {
            return Self {
                overrides: [], kill_switch: KillSwitch::new(),
                anomaly_threshold: 0.95, incident_log: []
            };
        }

        pub fn add_override(self, override_rule: SafetyOverride) {
            self.overrides.append(override_rule);
            self.overrides.sort_by(|a, b| b.priority - a.priority);
        }

        pub fn check(self, state: Map<String, Any>) -> Map<String, Any> {
            if self.kill_switch.is_active() {
                return { "blocked": true, "reason": "kill_switch_active: " + str(self.kill_switch.reason) };
            }
            for ovr in self.overrides {
                if ovr.check_and_act(state) {
                    self.incident_log.append({
                        "timestamp": native_align_now(),
                        "override": ovr.description,
                        "state": state
                    });
                    return { "blocked": true, "reason": "safety_override: " + ovr.description };
                }
            }
            return { "blocked": false };
        }
    }
}

# ============================================================
# ETHICAL REASONING
# ============================================================

pub mod ethics {
    pub class EthicalFramework {
        pub let name: String;
        pub let principles: List<Map<String, Any>>;

        pub fn new(name: String) -> Self {
            return Self { name: name, principles: [] };
        }

        pub fn add_principle(self, name: String, weight: Float, check: Fn) {
            self.principles.append({ "name": name, "weight": weight, "check": check });
        }

        pub fn evaluate(self, action: Map<String, Any>) -> Map<String, Any> {
            let total_score = 0.0;
            let total_weight = 0.0;
            let details = [];
            for p in self.principles {
                let score = p["check"](action);
                total_score = total_score + score * p["weight"];
                total_weight = total_weight + p["weight"];
                details.append({ "principle": p["name"], "score": score, "weight": p["weight"] });
            }
            let final_score = if total_weight > 0.0 { total_score / total_weight } else { 0.0 };
            return { "score": final_score, "acceptable": final_score >= 0.5, "details": details };
        }
    }
}

# ============================================================
# ALIGNMENT ENGINE ORCHESTRATOR
# ============================================================

pub class AlignEngine {
    pub let policy_engine: policy.PolicyEngine;
    pub let goal_verifier: goals.GoalVerifier;
    pub let bias_detector: fairness.BiasDetector;
    pub let explainer: explainability.ExplainabilityEngine;
    pub let safety_monitor: safety.SafetyMonitor;
    pub let ethical_framework: ethics.EthicalFramework;

    pub fn new(spec: goals.AlignmentSpec) -> Self {
        return Self {
            policy_engine: policy.PolicyEngine::new(),
            goal_verifier: goals.GoalVerifier::new(spec),
            bias_detector: fairness.BiasDetector::new(0.8),
            explainer: explainability.ExplainabilityEngine::new("feature_importance"),
            safety_monitor: safety.SafetyMonitor::new(),
            ethical_framework: ethics.EthicalFramework::new("default")
        };
    }

    pub fn check_action(self, action: String, state: Map<String, Any>) -> Map<String, Any> {
        let safety = self.safety_monitor.check(state);
        if safety["blocked"] { return { "allowed": false, "reason": safety["reason"] }; }
        let policy = self.policy_engine.evaluate(state);
        if !policy["allowed"] { return { "allowed": false, "reason": "policy_violation" }; }
        let alignment = self.goal_verifier.verify_action(action, state);
        if !alignment["aligned"] { return { "allowed": false, "reason": "misaligned", "details": alignment }; }
        return { "allowed": true, "alignment_score": alignment["satisfaction"] };
    }

    pub fn kill(self, reason: String) {
        self.safety_monitor.kill_switch.trigger(reason);
    }
}

pub fn create_align_engine(spec: goals.AlignmentSpec) -> AlignEngine {
    return AlignEngine::new(spec);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_align_now() -> Int;
native_align_verify_auth(token: String) -> Bool;
native_align_explain_fi(model: Any, input: Map) -> Map;
native_align_explain_shap(model: Any, input: Map) -> Map;

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
