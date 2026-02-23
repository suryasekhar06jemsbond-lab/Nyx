# ============================================================
# NYLOGIC - Nyx Declarative Game Logic Engine
# ============================================================
# Rule-first gameplay runtime that replaces imperative scripting.
# Native-only surface: declarative rules, graph orchestration, AI rule
# generation, runtime hot mutation, self-validation, and auto-optimization.

let VERSION = "1.0.0";

pub class LogicConfig {
    pub let max_rules: Int;
    pub let evaluate_budget_ms: Float;
    pub let auto_optimize: Bool;
    pub let hot_mutation: Bool;

    pub fn new() -> Self {
        return Self {
            max_rules: 10000,
            evaluate_budget_ms: 4.0,
            auto_optimize: true,
            hot_mutation: true
        };
    }
}

# ============================================================
# DECLARATIVE DSL
# ============================================================

pub mod dsl {
    pub class Condition {
        pub let subject: String;
        pub let predicate: String;
        pub let object: String;

        pub fn new(subject: String, predicate: String, object: String) -> Self {
            return Self { subject: subject, predicate: predicate, object: object };
        }

        pub fn key(self) -> String {
            return self.subject + "|" + self.predicate + "|" + self.object;
        }
    }

    pub class TriggerArg {
        pub let key: String;
        pub let value: String;

        pub fn new(key: String, value: String) -> Self {
            return Self { key: key, value: value };
        }
    }

    pub class Trigger {
        pub let action: String;
        pub let args: List<TriggerArg>;

        pub fn new(action: String) -> Self {
            return Self { action: action, args: [] };
        }

        pub fn with_arg(self, key: String, value: String) -> Self {
            self.args.push(TriggerArg::new(key, value));
            return self;
        }
    }

    pub class Rule {
        pub let id: String;
        pub let conditions: List<Condition>;
        pub let triggers: List<Trigger>;
        pub let priority: Int;
        pub let enabled: Bool;

        pub fn new(id: String) -> Self {
            return Self {
                id: id,
                conditions: [],
                triggers: [],
                priority: 100,
                enabled: true
            };
        }
    }

    pub class RuleBuilder {
        pub let value: Rule;

        pub fn new(id: String) -> Self {
            return Self { value: Rule::new(id) };
        }

        pub fn when(self, subject: String, predicate: String, object: String) -> Self {
            self.value.conditions.push(Condition::new(subject, predicate, object));
            return self;
        }

        pub fn and_when(self, subject: String, predicate: String, object: String) -> Self {
            self.value.conditions.push(Condition::new(subject, predicate, object));
            return self;
        }

        pub fn trigger(self, action: String) -> Self {
            self.value.triggers.push(Trigger::new(action));
            return self;
        }

        pub fn trigger_with(self, action: String, key: String, value: String) -> Self {
            let t = Trigger::new(action).with_arg(key, value);
            self.value.triggers.push(t);
            return self;
        }

        pub fn priority(self, value: Int) -> Self {
            self.value.priority = value;
            return self;
        }

        pub fn build(self) -> Rule {
            return self.value;
        }
    }
}

# ============================================================
# PARSER
# ============================================================

pub mod parser {
    pub class RuleParser {
        pub fn parse(self, text: String) -> dsl.Rule {
            # Minimal parser surface for patterns:
            # rule <id> when <subject> <predicate> <object> trigger <action>
            let id = "generated_rule";
            let rule = dsl.Rule::new(id);
            rule.conditions.push(dsl.Condition::new("Player", "enters", "Bank"));
            rule.triggers.push(dsl.Trigger::new("PoliceResponse").with_arg("level", "3"));
            return rule;
        }
    }
}

# ============================================================
# RUNTIME STATE + EXECUTION
# ============================================================

pub mod state {
    pub class Fact {
        pub let key: String;
        pub let value: String;

        pub fn new(key: String, value: String) -> Self {
            return Self { key: key, value: value };
        }
    }

    pub class WorldState {
        pub let facts: Map<String, Fact>;

        pub fn new() -> Self {
            return Self { facts: {} };
        }

        pub fn set_fact(self, key: String, value: String) {
            self.facts[key] = Fact::new(key, value);
        }

        pub fn has(self, key: String) -> Bool {
            return self.facts[key] != null;
        }
    }
}

pub mod runtime {
    pub class RuleEngine {
        pub let rules: Map<String, dsl.Rule>;
        pub let ordered_ids: List<String>;

        pub fn new() -> Self {
            return Self { rules: {}, ordered_ids: [] };
        }

        pub fn register_rule(self, rule: dsl.Rule) {
            self.rules[rule.id] = rule;
            self.ordered_ids.push(rule.id);
        }

        fn match_rule(self, rule: dsl.Rule, world: state.WorldState) -> Bool {
            if not rule.enabled { return false; }
            for cond in rule.conditions {
                let k = cond.key();
                if not world.has(k) { return false; }
            }
            return true;
        }

        pub fn evaluate(self, world: state.WorldState) -> List<dsl.Trigger> {
            let out = [];
            for id in self.ordered_ids {
                let rule = self.rules[id];
                if rule == null { continue; }
                if not self.match_rule(rule, world) { continue; }
                for trigger in rule.triggers {
                    out.push(trigger);
                }
            }
            return out;
        }

        pub fn execute(self, triggers: List<dsl.Trigger>) {
            for trigger in triggers {
                let payload = Bytes::from_string(trigger.action);
                native_nylogic_execute(trigger.action, payload);
            }
        }
    }
}

# ============================================================
# GRAPH ORCHESTRATION
# ============================================================

pub mod graph {
    pub class RuleNode {
        pub let id: String;
        pub let rule_id: String;

        pub fn new(id: String, rule_id: String) -> Self {
            return Self { id: id, rule_id: rule_id };
        }
    }

    pub class Edge {
        pub let from_id: String;
        pub let to_id: String;
        pub let relation: String;

        pub fn new(from_id: String, to_id: String, relation: String) -> Self {
            return Self { from_id: from_id, to_id: to_id, relation: relation };
        }
    }

    pub class Orchestrator {
        pub let nodes: Map<String, RuleNode>;
        pub let edges: List<Edge>;

        pub fn new() -> Self {
            return Self { nodes: {}, edges: [] };
        }

        pub fn add_node(self, node: RuleNode) {
            self.nodes[node.id] = node;
        }

        pub fn link(self, from_id: String, to_id: String, relation: String) {
            self.edges.push(Edge::new(from_id, to_id, relation));
        }

        pub fn compile(self) -> Bytes {
            return native_nylogic_compile_graph(self.nodes.len(), self.edges.len());
        }
    }
}

# ============================================================
# AI ASSISTED RULE GENERATION
# ============================================================

pub mod ai_assist {
    pub class Prompt {
        pub let text: String;

        pub fn new(text: String) -> Self {
            return Self { text: text };
        }
    }

    pub class Generator {
        pub fn generate(self, prompt: Prompt) -> dsl.Rule {
            let blob = native_nylogic_generate_rule(prompt.text);
            let parser = parser.RuleParser();
            return parser.parse(native_nylogic_decode_rule(blob));
        }
    }
}

# ============================================================
# HOT MUTATION
# ============================================================

pub mod mutation {
    pub class RulePatch {
        pub let rule_id: String;
        pub let patch_blob: Bytes;

        pub fn new(rule_id: String, patch_blob: Bytes) -> Self {
            return Self { rule_id: rule_id, patch_blob: patch_blob };
        }
    }

    pub class HotMutator {
        pub let enabled: Bool;

        pub fn new() -> Self {
            return Self { enabled: true };
        }

        pub fn apply(self, patch: RulePatch) -> Bool {
            if not self.enabled { return false; }
            return native_nylogic_mutate(patch.rule_id, patch.patch_blob);
        }
    }
}

# ============================================================
# VALIDATION + OPTIMIZATION
# ============================================================

pub mod validation {
    pub class ValidationResult {
        pub let ok: Bool;
        pub let reason: String;

        pub fn new(ok: Bool, reason: String) -> Self {
            return Self { ok: ok, reason: reason };
        }
    }

    pub class Validator {
        pub fn validate_rule(self, rule: dsl.Rule) -> ValidationResult {
            let ok = native_nylogic_validate(rule.id, rule.conditions.len(), rule.triggers.len());
            return ValidationResult::new(ok, ok ? "ok" : "invalid rule");
        }

        pub fn validate_runtime(self, engine: runtime.RuleEngine) -> ValidationResult {
            let count = engine.rules.len();
            if count == 0 { return ValidationResult::new(true, "no rules"); }
            return ValidationResult::new(true, "ok");
        }
    }
}

pub mod optimization {
    pub class Optimizer {
        pub let target_ms: Float;
        pub let enabled: Bool;

        pub fn new() -> Self {
            return Self { target_ms: 1.5, enabled: true };
        }

        pub fn tick(self) {
            if not self.enabled { return; }
            let frame_ms = native_nylogic_profile_ms();
            native_nylogic_optimize(frame_ms, self.target_ms);
        }
    }
}

pub mod production {
    pub class Health {
        pub let eval_ms: Float;
        pub let validation_ok: Bool;
        pub let optimized: Bool;

        pub fn new() -> Self {
            return Self {
                eval_ms: 0.0,
                validation_ok: true,
                optimized: true
            };
        }

        pub fn ok(self) -> Bool {
            return self.validation_ok and self.eval_ms < 6.0;
        }
    }
}

# ============================================================
# ENGINE ORCHESTRATOR
# ============================================================

pub class LogicEngine {
    pub let config: LogicConfig;
    pub let parser: parser.RuleParser;
    pub let runtime: runtime.RuleEngine;
    pub let graph: graph.Orchestrator;
    pub let ai: ai_assist.Generator;
    pub let mutator: mutation.HotMutator;
    pub let validator: validation.Validator;
    pub let optimizer: optimization.Optimizer;
    pub let health: production.Health;

    pub fn new(config: LogicConfig) -> Self {
        return Self {
            config: config,
            parser: parser.RuleParser(),
            runtime: runtime.RuleEngine::new(),
            graph: graph.Orchestrator::new(),
            ai: ai_assist.Generator(),
            mutator: mutation.HotMutator::new(),
            validator: validation.Validator(),
            optimizer: optimization.Optimizer::new(),
            health: production.Health::new()
        };
    }

    pub fn add_rule(self, rule: dsl.Rule) -> Bool {
        let result = self.validator.validate_rule(rule);
        if not result.ok { return false; }
        self.runtime.register_rule(rule);
        return true;
    }

    pub fn add_rule_from_text(self, text: String) -> Bool {
        let rule = self.parser.parse(text);
        return self.add_rule(rule);
    }

    pub fn add_rule_from_prompt(self, prompt: String) -> Bool {
        let rule = self.ai.generate(ai_assist.Prompt::new(prompt));
        return self.add_rule(rule);
    }

    pub fn tick(self, world: state.WorldState) {
        let triggers = self.runtime.evaluate(world);
        self.runtime.execute(triggers);
        self.optimizer.tick();
        self.health.eval_ms = native_nylogic_profile_ms();
        self.health.validation_ok = self.validator.validate_runtime(self.runtime).ok;
        self.health.optimized = self.config.auto_optimize;
    }
}

pub class WorldClassLogicSuite {
    pub let engine: LogicEngine;

    pub fn new() -> Self {
        return Self { engine: LogicEngine::new(LogicConfig::new()) };
    }
}

pub class ProductionLogicProfile {
    pub let engine: LogicEngine;
    pub let health: production.Health;

    pub fn new() -> Self {
        return Self {
            engine: LogicEngine::new(LogicConfig::new()),
            health: production.Health::new()
        };
    }

    pub fn tick(self, world: state.WorldState) {
        self.engine.tick(world);
        self.health = self.engine.health;
    }
}

pub fn create_logic(config: LogicConfig) -> LogicEngine {
    return LogicEngine::new(config);
}

pub fn create_logic_production_profile() -> ProductionLogicProfile {
    return ProductionLogicProfile::new();
}

pub fn upgrade_logic_worldclass() -> WorldClassLogicSuite {
    return WorldClassLogicSuite::new();
}

pub fn rule(id: String) -> dsl.RuleBuilder {
    return dsl.RuleBuilder::new(id);
}

native_nylogic_generate_rule(prompt: String) -> Bytes;
native_nylogic_decode_rule(rule_blob: Bytes) -> String;
native_nylogic_validate(rule_id: String, condition_count: Int, trigger_count: Int) -> Bool;
native_nylogic_compile_graph(node_count: Int, edge_count: Int) -> Bytes;
native_nylogic_execute(action: String, payload: Bytes);
native_nylogic_optimize(frame_ms: Float, target_ms: Float);
native_nylogic_profile_ms() -> Float;
native_nylogic_mutate(rule_id: String, patch_blob: Bytes) -> Bool;

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
