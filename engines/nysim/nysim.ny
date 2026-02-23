# ============================================================
# NYSIM - Nyx Environment Simulation Engine
# ============================================================
# Physics simulation, virtual environments, multi-agent sandbox,
# time acceleration, scenario testing, and world modeling.

let VERSION = "1.0.0";

# ============================================================
# WORLD MODEL
# ============================================================

pub mod world {
    pub class Vec3 {
        pub let x: Float;
        pub let y: Float;
        pub let z: Float;

        pub fn new(x: Float, y: Float, z: Float) -> Self {
            return Self { x: x, y: y, z: z };
        }

        pub fn zero() -> Self { return Self { x: 0.0, y: 0.0, z: 0.0 }; }

        pub fn add(self, other: Vec3) -> Vec3 {
            return Vec3::new(self.x + other.x, self.y + other.y, self.z + other.z);
        }

        pub fn sub(self, other: Vec3) -> Vec3 {
            return Vec3::new(self.x - other.x, self.y - other.y, self.z - other.z);
        }

        pub fn scale(self, s: Float) -> Vec3 {
            return Vec3::new(self.x * s, self.y * s, self.z * s);
        }

        pub fn dot(self, other: Vec3) -> Float {
            return self.x * other.x + self.y * other.y + self.z * other.z;
        }

        pub fn cross(self, other: Vec3) -> Vec3 {
            return Vec3::new(
                self.y * other.z - self.z * other.y,
                self.z * other.x - self.x * other.z,
                self.x * other.y - self.y * other.x
            );
        }

        pub fn magnitude(self) -> Float {
            return (self.x * self.x + self.y * self.y + self.z * self.z).sqrt();
        }

        pub fn normalize(self) -> Vec3 {
            let m = self.magnitude();
            if m < 1e-12 { return Vec3::zero(); }
            return self.scale(1.0 / m);
        }

        pub fn distance(self, other: Vec3) -> Float {
            return self.sub(other).magnitude();
        }
    }

    pub class Transform {
        pub let position: Vec3;
        pub let rotation: Vec3;
        pub let scale_vec: Vec3;

        pub fn new() -> Self {
            return Self {
                position: Vec3::zero(),
                rotation: Vec3::zero(),
                scale_vec: Vec3::new(1.0, 1.0, 1.0)
            };
        }
    }

    pub class Entity {
        pub let id: String;
        pub let name: String;
        pub let transform: Transform;
        pub let components: Map<String, Any>;
        pub let tags: List<String>;
        pub let active: Bool;

        pub fn new(id: String, name: String) -> Self {
            return Self {
                id: id, name: name,
                transform: Transform::new(),
                components: {}, tags: [], active: true
            };
        }

        pub fn add_component(self, name: String, component: Any) {
            self.components[name] = component;
        }

        pub fn get_component(self, name: String) -> Any? {
            return self.components.get(name);
        }

        pub fn has_tag(self, tag: String) -> Bool {
            return self.tags.contains(tag);
        }
    }

    pub class World {
        pub let entities: Map<String, Entity>;
        pub let time: Float;
        pub let time_scale: Float;
        pub let gravity: Vec3;
        pub let bounds: Map<String, Float>;
        pub let next_id: Int;

        pub fn new() -> Self {
            return Self {
                entities: {}, time: 0.0, time_scale: 1.0,
                gravity: Vec3::new(0.0, -9.81, 0.0),
                bounds: { "min_x": -1000.0, "max_x": 1000.0, "min_y": -1000.0,
                           "max_y": 1000.0, "min_z": -1000.0, "max_z": 1000.0 },
                next_id: 0
            };
        }

        pub fn spawn(self, name: String) -> Entity {
            let id = "entity_" + str(self.next_id);
            self.next_id = self.next_id + 1;
            let entity = Entity::new(id, name);
            self.entities[id] = entity;
            return entity;
        }

        pub fn destroy(self, id: String) {
            self.entities.remove(id);
        }

        pub fn find_by_tag(self, tag: String) -> List<Entity> {
            return self.entities.values().filter(|e| e.has_tag(tag));
        }

        pub fn find_by_name(self, name: String) -> Entity? {
            for e in self.entities.values() {
                if e.name == name { return e; }
            }
            return null;
        }
    }
}

# ============================================================
# PHYSICS SIMULATION
# ============================================================

pub mod physics {
    pub class RigidBody {
        pub let mass: Float;
        pub let velocity: world.Vec3;
        pub let acceleration: world.Vec3;
        pub let angular_velocity: world.Vec3;
        pub let force_accum: world.Vec3;
        pub let restitution: Float;
        pub let friction: Float;
        pub let is_static: Bool;

        pub fn new(mass: Float) -> Self {
            return Self {
                mass: mass,
                velocity: world.Vec3::zero(),
                acceleration: world.Vec3::zero(),
                angular_velocity: world.Vec3::zero(),
                force_accum: world.Vec3::zero(),
                restitution: 0.5, friction: 0.3,
                is_static: mass <= 0.0
            };
        }

        pub fn apply_force(self, force: world.Vec3) {
            if self.is_static { return; }
            self.force_accum = self.force_accum.add(force);
        }

        pub fn apply_impulse(self, impulse: world.Vec3) {
            if self.is_static { return; }
            self.velocity = self.velocity.add(impulse.scale(1.0 / self.mass));
        }

        pub fn integrate(self, dt: Float, gravity: world.Vec3) {
            if self.is_static { return; }
            let total_accel = gravity.add(self.force_accum.scale(1.0 / self.mass));
            self.velocity = self.velocity.add(total_accel.scale(dt));
            self.force_accum = world.Vec3::zero();
        }
    }

    pub class Collider {
        pub let shape: String;
        pub let radius: Float;
        pub let half_extents: world.Vec3;
        pub let is_trigger: Bool;

        pub fn sphere(radius: Float) -> Self {
            return Self { shape: "sphere", radius: radius, half_extents: world.Vec3::zero(), is_trigger: false };
        }

        pub fn box(hx: Float, hy: Float, hz: Float) -> Self {
            return Self { shape: "box", radius: 0.0, half_extents: world.Vec3::new(hx, hy, hz), is_trigger: false };
        }
    }

    pub class Collision {
        pub let entity_a: String;
        pub let entity_b: String;
        pub let normal: world.Vec3;
        pub let depth: Float;
        pub let point: world.Vec3;
    }

    pub class PhysicsEngine {
        pub let substeps: Int;
        pub let collision_pairs: List<Collision>;

        pub fn new() -> Self {
            return Self { substeps: 4, collision_pairs: [] };
        }

        pub fn step(self, w: world.World, dt: Float) {
            let sub_dt = dt / self.substeps as Float;
            for s in 0..self.substeps {
                for id, entity in w.entities {
                    let rb = entity.get_component("rigidbody");
                    if rb == null { continue; }
                    rb.integrate(sub_dt, w.gravity);
                    entity.transform.position = entity.transform.position.add(
                        rb.velocity.scale(sub_dt));
                }
                self.collision_pairs = self._detect_collisions(w);
                self._resolve_collisions(w);
            }
        }

        fn _detect_collisions(self, w: world.World) -> List<Collision> {
            let collisions = [];
            let entities = w.entities.values().filter(|e| e.get_component("collider") != null);
            for i in 0..entities.len() {
                for j in (i + 1)..entities.len() {
                    let col = self._test_pair(entities[i], entities[j]);
                    if col != null { collisions.append(col); }
                }
            }
            return collisions;
        }

        fn _test_pair(self, a: world.Entity, b: world.Entity) -> Collision? {
            let ca = a.get_component("collider");
            let cb = b.get_component("collider");
            if ca.shape == "sphere" && cb.shape == "sphere" {
                let dist = a.transform.position.distance(b.transform.position);
                let min_dist = ca.radius + cb.radius;
                if dist < min_dist {
                    let normal = b.transform.position.sub(a.transform.position).normalize();
                    return Collision {
                        entity_a: a.id, entity_b: b.id,
                        normal: normal, depth: min_dist - dist,
                        point: a.transform.position.add(normal.scale(ca.radius))
                    };
                }
            }
            return null;
        }

        fn _resolve_collisions(self, w: world.World) {
            for col in self.collision_pairs {
                let ea = w.entities[col.entity_a];
                let eb = w.entities[col.entity_b];
                let ra = ea.get_component("rigidbody");
                let rb = eb.get_component("rigidbody");
                if ra == null || rb == null { continue; }
                let rel_vel = ra.velocity.sub(rb.velocity);
                let vel_along = rel_vel.dot(col.normal);
                if vel_along > 0.0 { continue; }
                let e = min(ra.restitution, rb.restitution);
                let inv_mass_a = if ra.is_static { 0.0 } else { 1.0 / ra.mass };
                let inv_mass_b = if rb.is_static { 0.0 } else { 1.0 / rb.mass };
                let j = -(1.0 + e) * vel_along / (inv_mass_a + inv_mass_b);
                ra.apply_impulse(col.normal.scale(j));
                rb.apply_impulse(col.normal.scale(-j));
                let correction = col.normal.scale(col.depth * 0.8 / (inv_mass_a + inv_mass_b));
                ea.transform.position = ea.transform.position.add(correction.scale(inv_mass_a));
                eb.transform.position = eb.transform.position.sub(correction.scale(inv_mass_b));
            }
        }
    }
}

# ============================================================
# AGENT SANDBOX
# ============================================================

pub mod sandbox {
    pub class SimAgent {
        pub let id: String;
        pub let entity_id: String;
        pub let policy: Fn?;
        pub let observations: Map<String, Any>;
        pub let actions_taken: List<Map<String, Any>>;
        pub let reward: Float;

        pub fn new(id: String, entity_id: String) -> Self {
            return Self {
                id: id, entity_id: entity_id,
                policy: null, observations: {},
                actions_taken: [], reward: 0.0
            };
        }

        pub fn set_policy(self, policy: Fn) {
            self.policy = policy;
        }

        pub fn observe(self, w: world.World) {
            let entity = w.entities[self.entity_id];
            self.observations["position"] = entity.transform.position;
            self.observations["time"] = w.time;
            let nearby = [];
            for id, e in w.entities {
                if id == self.entity_id { continue; }
                let dist = entity.transform.position.distance(e.transform.position);
                if dist < 100.0 { nearby.append({ "id": id, "distance": dist, "name": e.name }); }
            }
            self.observations["nearby"] = nearby;
        }

        pub fn act(self, w: world.World) -> Map<String, Any>? {
            if self.policy == null { return null; }
            let action = self.policy(self.observations);
            self.actions_taken.append(action);
            return action;
        }
    }

    pub class Sandbox {
        pub let world: world.World;
        pub let agents: Map<String, SimAgent>;
        pub let physics_engine: physics.PhysicsEngine;
        pub let step_count: Int;
        pub let max_steps: Int;
        pub let reward_fn: Fn?;

        pub fn new() -> Self {
            return Self {
                world: world.World::new(),
                agents: {},
                physics_engine: physics.PhysicsEngine::new(),
                step_count: 0, max_steps: 10000,
                reward_fn: null
            };
        }

        pub fn add_agent(self, name: String, policy: Fn?) -> SimAgent {
            let entity = self.world.spawn(name);
            entity.tags.append("agent");
            let agent = SimAgent::new("agent_" + name, entity.id);
            if policy != null { agent.set_policy(policy); }
            self.agents[agent.id] = agent;
            return agent;
        }

        pub fn step(self, dt: Float) {
            for id, agent in self.agents {
                agent.observe(self.world);
                let action = agent.act(self.world);
                if action != null { self._apply_action(agent, action); }
            }
            self.physics_engine.step(self.world, dt);
            self.world.time = self.world.time + dt * self.world.time_scale;
            self.step_count = self.step_count + 1;
            if self.reward_fn != null {
                for id, agent in self.agents {
                    agent.reward = agent.reward + self.reward_fn(agent, self.world);
                }
            }
        }

        fn _apply_action(self, agent: SimAgent, action: Map<String, Any>) {
            let entity = self.world.entities[agent.entity_id];
            if action.contains_key("move") {
                let rb = entity.get_component("rigidbody");
                if rb != null { rb.apply_force(action["move"]); }
                else { entity.transform.position = entity.transform.position.add(action["move"]); }
            }
        }

        pub fn run(self, dt: Float, steps: Int) -> Map<String, Any> {
            for i in 0..steps { self.step(dt); }
            let results = {};
            for id, agent in self.agents {
                results[id] = { "reward": agent.reward, "actions": agent.actions_taken.len() };
            }
            return results;
        }

        pub fn reset(self) {
            self.world = world.World::new();
            self.agents = {};
            self.step_count = 0;
        }
    }
}

# ============================================================
# SCENARIO TESTING
# ============================================================

pub mod scenario {
    pub class ScenarioConfig {
        pub let name: String;
        pub let description: String;
        pub let parameters: Map<String, Any>;
        pub let setup_fn: Fn;
        pub let success_criteria: Fn;
        pub let max_time: Float;

        pub fn new(name: String, setup: Fn, criteria: Fn) -> Self {
            return Self {
                name: name, description: "",
                parameters: {}, setup_fn: setup,
                success_criteria: criteria, max_time: 60.0
            };
        }
    }

    pub class ScenarioResult {
        pub let name: String;
        pub let success: Bool;
        pub let elapsed_time: Float;
        pub let steps: Int;
        pub let metrics: Map<String, Float>;
        pub let log: List<String>;
    }

    pub class ScenarioRunner {
        pub let scenarios: List<ScenarioConfig>;
        pub let results: List<ScenarioResult>;

        pub fn new() -> Self {
            return Self { scenarios: [], results: [] };
        }

        pub fn add(self, config: ScenarioConfig) {
            self.scenarios.append(config);
        }

        pub fn run(self, scenario_name: String, dt: Float) -> ScenarioResult {
            let config = self.scenarios.filter(|s| s.name == scenario_name)[0];
            let sb = sandbox.Sandbox::new();
            config.setup_fn(sb);
            let log = [];
            let steps = 0;
            let elapsed = 0.0;
            while elapsed < config.max_time {
                sb.step(dt);
                steps = steps + 1;
                elapsed = elapsed + dt;
                if config.success_criteria(sb) {
                    let result = ScenarioResult {
                        name: config.name, success: true,
                        elapsed_time: elapsed, steps: steps,
                        metrics: {}, log: log
                    };
                    self.results.append(result);
                    return result;
                }
            }
            let result = ScenarioResult {
                name: config.name, success: false,
                elapsed_time: elapsed, steps: steps,
                metrics: {}, log: log
            };
            self.results.append(result);
            return result;
        }

        pub fn run_all(self, dt: Float) -> List<ScenarioResult> {
            for s in self.scenarios { self.run(s.name, dt); }
            return self.results;
        }
    }
}

# ============================================================
# TIME CONTROL
# ============================================================

pub mod time_control {
    pub class TimeController {
        pub let real_time: Float;
        pub let sim_time: Float;
        pub let time_scale: Float;
        pub let paused: Bool;
        pub let checkpoints: List<Map<String, Any>>;

        pub fn new() -> Self {
            return Self {
                real_time: 0.0, sim_time: 0.0,
                time_scale: 1.0, paused: false,
                checkpoints: []
            };
        }

        pub fn set_speed(self, scale: Float) {
            self.time_scale = scale;
        }

        pub fn pause(self) { self.paused = true; }
        pub fn resume(self) { self.paused = false; }

        pub fn advance(self, real_dt: Float) -> Float {
            if self.paused { return 0.0; }
            self.real_time = self.real_time + real_dt;
            let sim_dt = real_dt * self.time_scale;
            self.sim_time = self.sim_time + sim_dt;
            return sim_dt;
        }

        pub fn checkpoint(self, label: String, state: Any) {
            self.checkpoints.append({
                "label": label, "sim_time": self.sim_time,
                "real_time": self.real_time, "state": state
            });
        }

        pub fn restore(self, label: String) -> Any? {
            for cp in self.checkpoints {
                if cp["label"] == label {
                    self.sim_time = cp["sim_time"];
                    return cp["state"];
                }
            }
            return null;
        }
    }
}

# ============================================================
# SIMULATION ENGINE ORCHESTRATOR
# ============================================================

pub class SimEngine {
    pub let world: world.World;
    pub let physics_engine: physics.PhysicsEngine;
    pub let sandbox_env: sandbox.Sandbox;
    pub let scenario_runner: scenario.ScenarioRunner;
    pub let time_ctrl: time_control.TimeController;

    pub fn new() -> Self {
        return Self {
            world: world.World::new(),
            physics_engine: physics.PhysicsEngine::new(),
            sandbox_env: sandbox.Sandbox::new(),
            scenario_runner: scenario.ScenarioRunner::new(),
            time_ctrl: time_control.TimeController::new()
        };
    }

    pub fn step(self, real_dt: Float) {
        let sim_dt = self.time_ctrl.advance(real_dt);
        if sim_dt > 0.0 {
            self.physics_engine.step(self.world, sim_dt);
            self.world.time = self.world.time + sim_dt;
        }
    }

    pub fn run_for(self, duration: Float, dt: Float) {
        let elapsed = 0.0;
        while elapsed < duration {
            self.step(dt);
            elapsed = elapsed + dt;
        }
    }
}

pub fn create_sim_engine() -> SimEngine {
    return SimEngine::new();
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
