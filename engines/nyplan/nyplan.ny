# ============================================================
# NYPLAN - Nyx Planning & Decision Engine
# ============================================================
# A* search, heuristic optimization, constraint satisfaction,
# Markov Decision Processes, multi-objective optimization,
# and real-time decision policies.

let VERSION = "1.0.0";

# ============================================================
# SEARCH ALGORITHMS
# ============================================================

pub mod search {
    pub class SearchNode {
        pub let state: Any;
        pub let parent: SearchNode?;
        pub let action: Any?;
        pub let g_cost: Float;
        pub let h_cost: Float;
        pub let depth: Int;

        pub fn new(state: Any) -> Self {
            return Self {
                state: state, parent: null, action: null,
                g_cost: 0.0, h_cost: 0.0, depth: 0
            };
        }

        pub fn f_cost(self) -> Float { return self.g_cost + self.h_cost; }

        pub fn path(self) -> List<Any> {
            let actions = [];
            let current = self;
            while current.parent != null {
                actions.push(current.action);
                current = current.parent;
            }
            actions.reverse();
            return actions;
        }
    }

    pub class SearchProblem {
        pub let initial_state: Any;
        pub let goal_test: Fn;
        pub let successors: Fn;
        pub let step_cost: Fn;
        pub let heuristic: Fn;

        pub fn new(initial: Any) -> Self {
            return Self {
                initial_state: initial,
                goal_test: |_| false,
                successors: |_| [],
                step_cost: |_, _| 1.0,
                heuristic: |_| 0.0
            };
        }
    }

    pub class AStarSearch {
        pub let expanded: Int;
        pub let max_nodes: Int;

        pub fn new() -> Self {
            return Self { expanded: 0, max_nodes: 100000 };
        }

        pub fn search(self, problem: SearchProblem) -> SearchNode? {
            self.expanded = 0;
            let open_set = native_plan_priority_queue_new();
            let closed_set = {};
            let start = SearchNode::new(problem.initial_state);
            start.h_cost = problem.heuristic(start.state);
            native_plan_pq_push(open_set, start, start.f_cost());

            while not native_plan_pq_empty(open_set) and self.expanded < self.max_nodes {
                let current = native_plan_pq_pop(open_set);
                self.expanded = self.expanded + 1;

                if problem.goal_test(current.state) { return current; }

                let state_key = native_plan_hash_state(current.state);
                if closed_set.has(state_key) { continue; }
                closed_set[state_key] = true;

                let succ = problem.successors(current.state);
                for s in succ {
                    let child = SearchNode::new(s.state);
                    child.parent = current;
                    child.action = s.action;
                    child.g_cost = current.g_cost + problem.step_cost(current.state, s.action);
                    child.h_cost = problem.heuristic(s.state);
                    child.depth = current.depth + 1;

                    let key = native_plan_hash_state(s.state);
                    if not closed_set.has(key) {
                        native_plan_pq_push(open_set, child, child.f_cost());
                    }
                }
            }
            return null;
        }
    }

    pub class BeamSearch {
        pub let beam_width: Int;

        pub fn new(width: Int) -> Self {
            return Self { beam_width: width };
        }

        pub fn search(self, problem: SearchProblem) -> SearchNode? {
            let beam = [SearchNode::new(problem.initial_state)];

            for depth in 0..1000 {
                let candidates = [];
                for node in beam {
                    if problem.goal_test(node.state) { return node; }
                    let succ = problem.successors(node.state);
                    for s in succ {
                        let child = SearchNode::new(s.state);
                        child.parent = node;
                        child.action = s.action;
                        child.g_cost = node.g_cost + problem.step_cost(node.state, s.action);
                        child.h_cost = problem.heuristic(s.state);
                        child.depth = depth + 1;
                        candidates.push(child);
                    }
                }
                if candidates.len() == 0 { break; }
                candidates.sort(|a, b| a.f_cost() - b.f_cost());
                beam = candidates.slice(0, self.beam_width);
            }
            return null;
        }
    }

    pub class IterativeDeepeningSearch {
        pub let max_depth: Int;

        pub fn new(max_depth: Int) -> Self {
            return Self { max_depth: max_depth };
        }

        pub fn search(self, problem: SearchProblem) -> SearchNode? {
            for depth in 0..self.max_depth {
                let result = self._dls(SearchNode::new(problem.initial_state), problem, depth);
                if result != null { return result; }
            }
            return null;
        }

        fn _dls(self, node: SearchNode, problem: SearchProblem, limit: Int) -> SearchNode? {
            if problem.goal_test(node.state) { return node; }
            if limit == 0 { return null; }
            for s in problem.successors(node.state) {
                let child = SearchNode::new(s.state);
                child.parent = node;
                child.action = s.action;
                child.depth = node.depth + 1;
                let result = self._dls(child, problem, limit - 1);
                if result != null { return result; }
            }
            return null;
        }
    }
}

# ============================================================
# CONSTRAINT SATISFACTION
# ============================================================

pub mod constraints {
    pub class Variable {
        pub let name: String;
        pub let domain: List<Any>;

        pub fn new(name: String, domain: List<Any>) -> Self {
            return Self { name: name, domain: domain };
        }
    }

    pub class Constraint {
        pub let variables: List<String>;
        pub let check: Fn;

        pub fn new(variables: List<String>, check: Fn) -> Self {
            return Self { variables: variables, check: check };
        }

        pub fn is_satisfied(self, assignment: Map<String, Any>) -> Bool {
            for v in self.variables {
                if not assignment.has(v) { return true; }
            }
            return self.check(assignment);
        }
    }

    pub class CSPSolver {
        pub let variables: List<Variable>;
        pub let constraints: List<Constraint>;
        pub let propagation: Bool;

        pub fn new() -> Self {
            return Self { variables: [], constraints: [], propagation: true };
        }

        pub fn add_variable(self, variable: Variable) {
            self.variables.push(variable);
        }

        pub fn add_constraint(self, constraint: Constraint) {
            self.constraints.push(constraint);
        }

        pub fn solve(self) -> Map<String, Any>? {
            return self._backtrack({}, 0);
        }

        pub fn solve_all(self) -> List<Map<String, Any>> {
            let solutions = [];
            self._backtrack_all({}, 0, solutions);
            return solutions;
        }

        fn _backtrack(self, assignment: Map<String, Any>, idx: Int) -> Map<String, Any>? {
            if idx == self.variables.len() { return assignment; }
            let variable = self.variables[idx];
            for value in variable.domain {
                assignment[variable.name] = value;
                if self._is_consistent(assignment) {
                    let result = self._backtrack(assignment, idx + 1);
                    if result != null { return result; }
                }
                assignment.remove(variable.name);
            }
            return null;
        }

        fn _backtrack_all(self, assignment: Map<String, Any>, idx: Int, solutions: List<Map<String, Any>>) {
            if idx == self.variables.len() {
                solutions.push(assignment.clone());
                return;
            }
            let variable = self.variables[idx];
            for value in variable.domain {
                assignment[variable.name] = value;
                if self._is_consistent(assignment) {
                    self._backtrack_all(assignment, idx + 1, solutions);
                }
                assignment.remove(variable.name);
            }
        }

        fn _is_consistent(self, assignment: Map<String, Any>) -> Bool {
            for c in self.constraints {
                if not c.is_satisfied(assignment) { return false; }
            }
            return true;
        }
    }
}

# ============================================================
# MARKOV DECISION PROCESSES
# ============================================================

pub mod mdp {
    pub class MDP {
        pub let states: List<Any>;
        pub let actions: List<Any>;
        pub let transition: Fn;
        pub let reward: Fn;
        pub let discount: Float;
        pub let terminal: Fn;

        pub fn new() -> Self {
            return Self {
                states: [], actions: [],
                transition: |s, a| [],
                reward: |s, a, s2| 0.0,
                discount: 0.99,
                terminal: |s| false
            };
        }
    }

    pub class ValueIteration {
        pub let values: Map<String, Float>;
        pub let policy: Map<String, Any>;
        pub let convergence_threshold: Float;
        pub let max_iterations: Int;

        pub fn new() -> Self {
            return Self {
                values: {}, policy: {},
                convergence_threshold: 0.001,
                max_iterations: 1000
            };
        }

        pub fn solve(self, mdp: MDP) -> Map<String, Any> {
            for state in mdp.states {
                let key = native_plan_hash_state(state);
                self.values[key] = 0.0;
            }

            for iter in 0..self.max_iterations {
                let max_delta = 0.0;

                for state in mdp.states {
                    if mdp.terminal(state) { continue; }
                    let key = native_plan_hash_state(state);
                    let old_value = self.values[key];
                    let best_value = -999999.0;
                    let best_action = null;

                    for action in mdp.actions {
                        let transitions = mdp.transition(state, action);
                        let value = 0.0;
                        for t in transitions {
                            let s2_key = native_plan_hash_state(t.state);
                            let r = mdp.reward(state, action, t.state);
                            value = value + t.prob * (r + mdp.discount * (self.values.get(s2_key) or 0.0));
                        }
                        if value > best_value {
                            best_value = value;
                            best_action = action;
                        }
                    }

                    self.values[key] = best_value;
                    self.policy[key] = best_action;
                    let delta = (best_value - old_value).abs();
                    if delta > max_delta { max_delta = delta; }
                }

                if max_delta < self.convergence_threshold { break; }
            }

            return self.policy;
        }

        pub fn get_action(self, state: Any) -> Any? {
            let key = native_plan_hash_state(state);
            return self.policy.get(key);
        }
    }

    pub class PolicyIteration {
        pub fn solve(mdp: MDP) -> Map<String, Any> {
            return native_plan_policy_iteration(mdp);
        }
    }

    pub class MonteCarloTreeSearch {
        pub let simulations: Int;
        pub let exploration: Float;

        pub fn new(simulations: Int) -> Self {
            return Self { simulations: simulations, exploration: 1.414 };
        }

        pub fn best_action(self, mdp: MDP, state: Any) -> Any {
            return native_plan_mcts(mdp, state, self.simulations, self.exploration);
        }
    }
}

# ============================================================
# MULTI-OBJECTIVE OPTIMIZATION
# ============================================================

pub mod optimization {
    pub class Objective {
        pub let name: String;
        pub let evaluate: Fn;
        pub let minimize: Bool;
        pub let weight: Float;

        pub fn new(name: String, evaluate: Fn, minimize: Bool) -> Self {
            return Self { name: name, evaluate: evaluate, minimize: minimize, weight: 1.0 };
        }
    }

    pub class Solution {
        pub let variables: List<Float>;
        pub let objectives: Map<String, Float>;
        pub let feasible: Bool;
        pub let rank: Int;
        pub let crowding_distance: Float;

        pub fn new(variables: List<Float>) -> Self {
            return Self {
                variables: variables, objectives: {},
                feasible: true, rank: 0, crowding_distance: 0.0
            };
        }

        pub fn dominates(self, other: Solution) -> Bool {
            let dominated = false;
            for key in self.objectives.keys() {
                if self.objectives[key] > other.objectives[key] { return false; }
                if self.objectives[key] < other.objectives[key] { dominated = true; }
            }
            return dominated;
        }
    }

    pub class NSGA2 {
        pub let population_size: Int;
        pub let generations: Int;
        pub let mutation_rate: Float;
        pub let crossover_rate: Float;
        pub let objectives: List<Objective>;

        pub fn new(pop_size: Int, generations: Int) -> Self {
            return Self {
                population_size: pop_size, generations: generations,
                mutation_rate: 0.1, crossover_rate: 0.8, objectives: []
            };
        }

        pub fn add_objective(self, obj: Objective) {
            self.objectives.push(obj);
        }

        pub fn optimize(self, bounds: List<List<Float>>) -> List<Solution> {
            return native_plan_nsga2(self.objectives, bounds, self.population_size, self.generations, self.mutation_rate, self.crossover_rate);
        }

        pub fn pareto_front(self, solutions: List<Solution>) -> List<Solution> {
            return solutions.filter(|s| s.rank == 0);
        }
    }

    pub class SimulatedAnnealing {
        pub let initial_temp: Float;
        pub let cooling_rate: Float;
        pub let min_temp: Float;
        pub let iterations_per_temp: Int;

        pub fn new() -> Self {
            return Self {
                initial_temp: 1000.0, cooling_rate: 0.995,
                min_temp: 0.001, iterations_per_temp: 100
            };
        }

        pub fn optimize(self, initial: List<Float>, objective: Fn, neighbor: Fn) -> List<Float> {
            return native_plan_simulated_annealing(
                initial, objective, neighbor,
                self.initial_temp, self.cooling_rate, self.min_temp, self.iterations_per_temp
            );
        }
    }

    pub class GeneticAlgorithm {
        pub let population_size: Int;
        pub let generations: Int;
        pub let mutation_rate: Float;
        pub let crossover_rate: Float;
        pub let elitism: Float;

        pub fn new(pop_size: Int, generations: Int) -> Self {
            return Self {
                population_size: pop_size, generations: generations,
                mutation_rate: 0.05, crossover_rate: 0.8, elitism: 0.1
            };
        }

        pub fn optimize(self, fitness: Fn, bounds: List<List<Float>>) -> List<Float> {
            return native_plan_genetic(fitness, bounds, self.population_size, self.generations, self.mutation_rate, self.crossover_rate, self.elitism);
        }
    }
}

# ============================================================
# DECISION POLICIES
# ============================================================

pub mod policies {
    pub class DecisionPolicy {
        pub let name: String;
        pub let evaluate: Fn;

        pub fn new(name: String, evaluate: Fn) -> Self {
            return Self { name: name, evaluate: evaluate };
        }
    }

    pub class PolicyEngine {
        pub let policies: Map<String, DecisionPolicy>;
        pub let default_policy: String?;

        pub fn new() -> Self {
            return Self { policies: {}, default_policy: null };
        }

        pub fn add_policy(self, policy: DecisionPolicy) {
            self.policies[policy.name] = policy;
            if self.default_policy == null {
                self.default_policy = policy.name;
            }
        }

        pub fn decide(self, state: Any, policy_name: String?) -> Any {
            let name = policy_name or self.default_policy;
            let policy = self.policies.get(name);
            if policy == null { return null; }
            return policy.evaluate(state);
        }

        pub fn evaluate_all(self, state: Any) -> Map<String, Any> {
            let results = {};
            for entry in self.policies.entries() {
                results[entry.key] = entry.value.evaluate(state);
            }
            return results;
        }
    }
}

# ============================================================
# PLANNER ORCHESTRATOR
# ============================================================

pub class PlanEngine {
    pub let a_star: search.AStarSearch;
    pub let csp: constraints.CSPSolver;
    pub let value_iter: mdp.ValueIteration;
    pub let mcts: mdp.MonteCarloTreeSearch;
    pub let nsga2: optimization.NSGA2;
    pub let policy_engine: policies.PolicyEngine;

    pub fn new() -> Self {
        return Self {
            a_star: search.AStarSearch::new(),
            csp: constraints.CSPSolver::new(),
            value_iter: mdp.ValueIteration::new(),
            mcts: mdp.MonteCarloTreeSearch::new(1000),
            nsga2: optimization.NSGA2::new(100, 200),
            policy_engine: policies.PolicyEngine::new()
        };
    }
}

pub fn create_planner() -> PlanEngine {
    return PlanEngine::new();
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_plan_priority_queue_new() -> Any;
native_plan_pq_push(pq: Any, item: Any, priority: Float);
native_plan_pq_pop(pq: Any) -> Any;
native_plan_pq_empty(pq: Any) -> Bool;
native_plan_hash_state(state: Any) -> String;
native_plan_policy_iteration(mdp: Any) -> Map;
native_plan_mcts(mdp: Any, state: Any, sims: Int, explore: Float) -> Any;
native_plan_nsga2(objectives: List, bounds: List, pop: Int, gen: Int, mut_rate: Float, cross: Float) -> List;
native_plan_simulated_annealing(initial: List, obj: Fn, neighbor: Fn, temp: Float, cool: Float, min_temp: Float, iters: Int) -> List;
native_plan_genetic(fitness: Fn, bounds: List, pop: Int, gen: Int, mut_rate: Float, cross: Float, elite: Float) -> List;

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
