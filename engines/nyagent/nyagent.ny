# ============================================================
# NYAGENT - Nyx Autonomous Agent Engine
# ============================================================
# Goal-based planning, task decomposition, action chaining,
# environment interaction, multi-agent coordination, agent
# memory, and reflection/self-evaluation loops.
# Outperforms Python-based agent frameworks in speed & stability.

let VERSION = "1.0.0";

# ============================================================
# AGENT CORE
# ============================================================

pub mod core {
    pub class AgentConfig {
        pub let name: String;
        pub let model: String;
        pub let max_steps: Int;
        pub let timeout_ms: Int;
        pub let temperature: Float;
        pub let tools: List<Tool>;
        pub let system_prompt: String;
        pub let memory_enabled: Bool;
        pub let reflection_enabled: Bool;

        pub fn new(name: String) -> Self {
            return Self {
                name: name, model: "default",
                max_steps: 100, timeout_ms: 60000,
                temperature: 0.7, tools: [],
                system_prompt: "", memory_enabled: true,
                reflection_enabled: true
            };
        }
    }

    pub class Tool {
        pub let name: String;
        pub let description: String;
        pub let parameters: Map<String, String>;
        pub let handler: Fn;

        pub fn new(name: String, description: String, handler: Fn) -> Self {
            return Self {
                name: name, description: description,
                parameters: {}, handler: handler
            };
        }

        pub fn add_param(self, name: String, type_name: String) -> Self {
            self.parameters[name] = type_name;
            return self;
        }

        pub fn execute(self, args: Map<String, Any>) -> Any {
            return self.handler(args);
        }
    }

    pub class AgentState {
        pub let status: String;
        pub let current_goal: String?;
        pub let step_count: Int;
        pub let context: Map<String, Any>;
        pub let errors: List<String>;
        pub let started_at: Int;

        pub fn new() -> Self {
            return Self {
                status: "idle", current_goal: null,
                step_count: 0, context: {}, errors: [],
                started_at: 0
            };
        }
    }

    pub class Observation {
        pub let source: String;
        pub let content: Any;
        pub let timestamp: Int;
        pub let type_name: String;

        pub fn new(source: String, content: Any, type_name: String) -> Self {
            return Self {
                source: source, content: content,
                timestamp: native_agent_time_ms(),
                type_name: type_name
            };
        }
    }

    pub class Action {
        pub let tool_name: String;
        pub let arguments: Map<String, Any>;
        pub let reasoning: String;
        pub let result: Any?;
        pub let success: Bool;
        pub let duration_ms: Int;

        pub fn new(tool_name: String, args: Map<String, Any>, reasoning: String) -> Self {
            return Self {
                tool_name: tool_name, arguments: args,
                reasoning: reasoning, result: null,
                success: false, duration_ms: 0
            };
        }
    }
}

# ============================================================
# GOAL-BASED PLANNING
# ============================================================

pub mod planning {
    pub class Goal {
        pub let id: String;
        pub let description: String;
        pub let priority: Int;
        pub let preconditions: List<Fn>;
        pub let success_criteria: Fn;
        pub let sub_goals: List<Goal>;
        pub let status: String;

        pub fn new(description: String) -> Self {
            return Self {
                id: native_agent_uuid(),
                description: description, priority: 0,
                preconditions: [], success_criteria: |_| false,
                sub_goals: [], status: "pending"
            };
        }

        pub fn with_priority(self, p: Int) -> Self {
            self.priority = p;
            return self;
        }

        pub fn requires(self, condition: Fn) -> Self {
            self.preconditions.push(condition);
            return self;
        }

        pub fn success_when(self, criteria: Fn) -> Self {
            self.success_criteria = criteria;
            return self;
        }

        pub fn add_sub_goal(self, sub: Goal) {
            self.sub_goals.push(sub);
        }

        pub fn is_achievable(self, state: core.AgentState) -> Bool {
            for pre in self.preconditions {
                if not pre(state) { return false; }
            }
            return true;
        }

        pub fn is_achieved(self, state: core.AgentState) -> Bool {
            return self.success_criteria(state);
        }
    }

    pub class TaskDecomposer {
        pub fn decompose(goal: Goal, context: Map<String, Any>) -> List<Task> {
            return native_agent_decompose(goal, context);
        }

        pub fn replan(goal: Goal, failed_task: Task, context: Map<String, Any>) -> List<Task> {
            return native_agent_replan(goal, failed_task, context);
        }
    }

    pub class Task {
        pub let id: String;
        pub let description: String;
        pub let tool_name: String?;
        pub let arguments: Map<String, Any>;
        pub let dependencies: List<String>;
        pub let status: String;
        pub let result: Any?;
        pub let retry_count: Int;
        pub let max_retries: Int;

        pub fn new(description: String) -> Self {
            return Self {
                id: native_agent_uuid(),
                description: description,
                tool_name: null, arguments: {},
                dependencies: [], status: "pending",
                result: null, retry_count: 0, max_retries: 3
            };
        }

        pub fn using_tool(self, tool: String, args: Map<String, Any>) -> Self {
            self.tool_name = tool;
            self.arguments = args;
            return self;
        }

        pub fn depends_on(self, task_id: String) -> Self {
            self.dependencies.push(task_id);
            return self;
        }

        pub fn can_execute(self, completed: List<String>) -> Bool {
            for dep in self.dependencies {
                if not completed.contains(dep) { return false; }
            }
            return true;
        }
    }

    pub class Planner {
        pub let strategies: Map<String, Fn>;

        pub fn new() -> Self {
            return Self { strategies: {} };
        }

        pub fn add_strategy(self, name: String, strategy: Fn) {
            self.strategies[name] = strategy;
        }

        pub fn plan(self, goal: Goal, state: core.AgentState, strategy: String) -> List<Task> {
            let strat = self.strategies.get(strategy);
            if strat != null { return strat(goal, state); }
            return TaskDecomposer::decompose(goal, state.context);
        }
    }
}

# ============================================================
# AGENT MEMORY
# ============================================================

pub mod memory {
    pub class MemoryEntry {
        pub let id: String;
        pub let content: String;
        pub let embedding: List<Float>;
        pub let importance: Float;
        pub let access_count: Int;
        pub let created_at: Int;
        pub let last_accessed: Int;
        pub let tags: List<String>;

        pub fn new(content: String, importance: Float) -> Self {
            return Self {
                id: native_agent_uuid(),
                content: content,
                embedding: native_agent_embed(content),
                importance: importance,
                access_count: 0,
                created_at: native_agent_time_ms(),
                last_accessed: native_agent_time_ms(),
                tags: []
            };
        }
    }

    pub class ShortTermMemory {
        pub let entries: List<MemoryEntry>;
        pub let max_size: Int;

        pub fn new(max_size: Int) -> Self {
            return Self { entries: [], max_size: max_size };
        }

        pub fn add(self, entry: MemoryEntry) {
            self.entries.push(entry);
            if self.entries.len() > self.max_size {
                self.entries.remove(0);
            }
        }

        pub fn recent(self, n: Int) -> List<MemoryEntry> {
            let start = (self.entries.len() - n).max(0);
            return self.entries.slice(start);
        }

        pub fn clear(self) {
            self.entries = [];
        }
    }

    pub class LongTermMemory {
        pub let entries: Map<String, MemoryEntry>;
        pub let index_handle: Int?;
        pub let dimension: Int;

        pub fn new(dimension: Int) -> Self {
            return Self { entries: {}, index_handle: null, dimension: dimension };
        }

        pub fn store(self, entry: MemoryEntry) {
            self.entries[entry.id] = entry;
            native_agent_memory_index_add(self.index_handle, entry.id, entry.embedding);
        }

        pub fn recall(self, query: String, top_k: Int) -> List<MemoryEntry> {
            let query_vec = native_agent_embed(query);
            let results = native_agent_memory_search(self.index_handle, query_vec, top_k);
            let memories = [];
            for r in results {
                let entry = self.entries.get(r["id"]);
                if entry != null {
                    entry.access_count = entry.access_count + 1;
                    entry.last_accessed = native_agent_time_ms();
                    memories.push(entry);
                }
            }
            return memories;
        }

        pub fn forget(self, id: String) {
            self.entries.remove(id);
            native_agent_memory_index_remove(self.index_handle, id);
        }

        pub fn consolidate(self, threshold: Float) {
            let to_remove = [];
            for entry in self.entries.values() {
                let recency = native_agent_time_ms() - entry.last_accessed;
                let score = entry.importance * entry.access_count as Float / (recency as Float + 1.0);
                if score < threshold {
                    to_remove.push(entry.id);
                }
            }
            for id in to_remove { self.forget(id); }
        }
    }

    pub class EpisodicMemory {
        pub let episodes: List<Episode>;

        pub fn new() -> Self {
            return Self { episodes: [] };
        }

        pub fn record_episode(self, goal: String, actions: List<core.Action>, outcome: String, success: Bool) {
            self.episodes.push(Episode {
                id: native_agent_uuid(),
                goal: goal,
                actions: actions,
                outcome: outcome,
                success: success,
                timestamp: native_agent_time_ms()
            });
        }

        pub fn recall_similar(self, goal: String, top_k: Int) -> List<Episode> {
            return native_agent_recall_episodes(self.episodes, goal, top_k);
        }

        pub fn success_rate(self) -> Float {
            if self.episodes.len() == 0 { return 0.0; }
            let successes = self.episodes.filter(|e| e.success).len();
            return successes as Float / self.episodes.len() as Float;
        }
    }

    pub class Episode {
        pub let id: String;
        pub let goal: String;
        pub let actions: List<core.Action>;
        pub let outcome: String;
        pub let success: Bool;
        pub let timestamp: Int;
    }
}

# ============================================================
# REFLECTION & SELF-EVALUATION
# ============================================================

pub mod reflection {
    pub class ReflectionResult {
        pub let success: Bool;
        pub let reasoning: String;
        pub let lessons: List<String>;
        pub let improvements: List<String>;
        pub let confidence: Float;
    }

    pub class Reflector {
        pub let reflection_prompt: String;
        pub let min_confidence: Float;

        pub fn new() -> Self {
            return Self {
                reflection_prompt: "Evaluate the actions taken and results achieved.",
                min_confidence: 0.5
            };
        }

        pub fn reflect(self, goal: String, actions: List<core.Action>, outcome: Any) -> ReflectionResult {
            return native_agent_reflect(self.reflection_prompt, goal, actions, outcome);
        }

        pub fn should_retry(self, result: ReflectionResult) -> Bool {
            return not result.success and result.confidence > self.min_confidence;
        }

        pub fn critique(self, plan: List<planning.Task>, context: Map<String, Any>) -> Map<String, Any> {
            return native_agent_critique_plan(plan, context);
        }
    }
}

# ============================================================
# MULTI-AGENT COORDINATION
# ============================================================

pub mod coordination {
    pub class Message {
        pub let from: String;
        pub let to: String;
        pub let type_name: String;
        pub let content: Any;
        pub let timestamp: Int;

        pub fn new(from: String, to: String, type_name: String, content: Any) -> Self {
            return Self {
                from: from, to: to, type_name: type_name,
                content: content, timestamp: native_agent_time_ms()
            };
        }
    }

    pub class AgentRegistry {
        pub let agents: Map<String, Agent>;
        pub let message_queue: List<Message>;

        pub fn new() -> Self {
            return Self { agents: {}, message_queue: [] };
        }

        pub fn register(self, agent: Agent) {
            self.agents[agent.config.name] = agent;
        }

        pub fn unregister(self, name: String) {
            self.agents.remove(name);
        }

        pub fn send(self, message: Message) {
            self.message_queue.push(message);
            let target = self.agents.get(message.to);
            if target != null {
                target.receive(message);
            }
        }

        pub fn broadcast(self, from: String, type_name: String, content: Any) {
            for entry in self.agents.entries() {
                if entry.key != from {
                    self.send(Message::new(from, entry.key, type_name, content));
                }
            }
        }

        pub fn delegate(self, from: String, to: String, goal: planning.Goal) -> Any {
            let target = self.agents.get(to);
            if target == null { return null; }
            return target.pursue(goal);
        }
    }
}

# ============================================================
# AGENT ORCHESTRATOR
# ============================================================

pub class Agent {
    pub let config: core.AgentConfig;
    pub let state: core.AgentState;
    pub let planner: planning.Planner;
    pub let short_memory: memory.ShortTermMemory;
    pub let long_memory: memory.LongTermMemory;
    pub let episodic: memory.EpisodicMemory;
    pub let reflector: reflection.Reflector;
    pub let inbox: List<coordination.Message>;
    pub let action_history: List<core.Action>;

    pub fn new(config: core.AgentConfig) -> Self {
        return Self {
            config: config,
            state: core.AgentState::new(),
            planner: planning.Planner::new(),
            short_memory: memory.ShortTermMemory::new(50),
            long_memory: memory.LongTermMemory::new(768),
            episodic: memory.EpisodicMemory::new(),
            reflector: reflection.Reflector::new(),
            inbox: [],
            action_history: []
        };
    }

    pub fn pursue(self, goal: planning.Goal) -> Any {
        self.state.status = "running";
        self.state.current_goal = goal.description;
        self.state.started_at = native_agent_time_ms();

        let tasks = self.planner.plan(goal, self.state, "default");
        let completed_ids = [];
        let final_result = null;

        for step in 0..self.config.max_steps {
            self.state.step_count = step;

            let runnable = tasks.filter(|t| t.status == "pending" and t.can_execute(completed_ids));
            if runnable.len() == 0 { break; }

            let task = runnable[0];
            task.status = "running";

            let action = core.Action::new(task.tool_name or "think", task.arguments, task.description);
            let start = native_agent_time_ms();

            let result = self._execute_task(task);
            action.duration_ms = native_agent_time_ms() - start;
            action.result = result;
            action.success = result != null;
            self.action_history.push(action);

            if action.success {
                task.status = "completed";
                task.result = result;
                completed_ids.push(task.id);
                final_result = result;

                self.short_memory.add(memory.MemoryEntry::new(
                    "Completed: " + task.description, 0.7
                ));
            } else {
                task.retry_count = task.retry_count + 1;
                if task.retry_count >= task.max_retries {
                    task.status = "failed";
                    if self.config.reflection_enabled {
                        let ref_result = self.reflector.reflect(goal.description, self.action_history, "Task failed: " + task.description);
                        let new_tasks = planning.TaskDecomposer::replan(goal, task, self.state.context);
                        tasks = tasks + new_tasks;
                    }
                } else {
                    task.status = "pending";
                }
            }

            if goal.is_achieved(self.state) { break; }
        }

        let success = goal.is_achieved(self.state);
        self.episodic.record_episode(goal.description, self.action_history, final_result.to_string() or "null", success);

        if self.config.reflection_enabled {
            let reflection = self.reflector.reflect(goal.description, self.action_history, final_result);
            for lesson in reflection.lessons {
                self.long_memory.store(memory.MemoryEntry::new(lesson, 0.9));
            }
        }

        self.state.status = if success { "completed" } else { "failed" };
        return final_result;
    }

    pub fn receive(self, message: coordination.Message) {
        self.inbox.push(message);
    }

    fn _execute_task(self, task: planning.Task) -> Any? {
        if task.tool_name == null { return null; }
        for tool in self.config.tools {
            if tool.name == task.tool_name {
                return tool.execute(task.arguments);
            }
        }
        return null;
    }
}

pub fn create_agent(name: String) -> Agent {
    return Agent::new(core.AgentConfig::new(name));
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_agent_time_ms() -> Int;
native_agent_uuid() -> String;
native_agent_embed(text: String) -> List;
native_agent_decompose(goal: Any, context: Map) -> List;
native_agent_replan(goal: Any, failed: Any, context: Map) -> List;
native_agent_reflect(prompt: String, goal: String, actions: List, outcome: Any) -> Any;
native_agent_critique_plan(plan: List, context: Map) -> Map;
native_agent_recall_episodes(episodes: List, goal: String, top_k: Int) -> List;
native_agent_memory_index_add(handle: Int, id: String, embedding: List);
native_agent_memory_search(handle: Int, query: List, top_k: Int) -> List;
native_agent_memory_index_remove(handle: Int, id: String);

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
