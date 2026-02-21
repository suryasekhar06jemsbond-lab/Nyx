# ============================================================
# NYAI - Nyx NPC Intelligence Engine
# ============================================================
# Hybrid Behavior Tree + GOAP planning with scalable pathfinding,
# crowd logic, policing behaviors, combat coordination, and social simulation.

let VERSION = "1.0.0";

pub class AIConfig {
    pub let think_rate_hz: Int;
    pub let crowd_tick_rate_hz: Int;
    pub let deterministic: Bool;

    pub fn new() -> Self {
        return Self {
            think_rate_hz: 20,
            crowd_tick_rate_hz: 30,
            deterministic: true
        };
    }
}

# ============================================================
# BT + GOAP HYBRID
# ============================================================

pub mod hybrid {
    pub let BT_SUCCESS = "success";
    pub let BT_FAILURE = "failure";
    pub let BT_RUNNING = "running";

    pub class BTNode {
        pub let id: String;
        pub let node_type: String;
        pub let children: List<String>;

        pub fn new(id: String, node_type: String) -> Self {
            return Self { id: id, node_type: node_type, children: [] };
        }
    }

    pub class BehaviorTree {
        pub let root: BTNode;
        pub let nodes: Map<String, BTNode>;

        pub fn new(root: BTNode) -> Self {
            return Self { root: root, nodes: { root.id: root } };
        }

        pub fn tick(self, actor_id: String) -> String {
            # Reactive behavior execution
            return BT_RUNNING;
        }
    }

    pub class Goal {
        pub let id: String;
        pub let priority: Float;

        pub fn new(id: String, priority: Float) -> Self {
            return Self { id: id, priority: priority };
        }
    }

    pub class Action {
        pub let id: String;
        pub let cost: Float;
        pub let preconditions: Map<String, Bool>;
        pub let effects: Map<String, Bool>;

        pub fn new(id: String, cost: Float) -> Self {
            return Self {
                id: id,
                cost: cost,
                preconditions: {},
                effects: {}
            };
        }
    }

    pub class GOAPPlanner {
        pub let actions: List<Action>;

        pub fn new() -> Self {
            return Self { actions: [] };
        }

        pub fn plan(self, world_state: Map<String, Bool>, goal: Goal) -> List<String> {
            # Long-horizon planning
            return [];
        }
    }

    pub class Brain {
        pub let bt: BehaviorTree;
        pub let goap: GOAPPlanner;

        pub fn new(bt: BehaviorTree, goap: GOAPPlanner) -> Self {
            return Self { bt: bt, goap: goap };
        }

        pub fn tick(self, npc_id: String, world_state: Map<String, Bool>, goal: Goal) {
            self.bt.tick(npc_id);
            self.goap.plan(world_state, goal);
        }
    }
}

# ============================================================
# PATHFINDING
# ============================================================

pub mod path {
    pub class Waypoint {
        pub let id: String;
        pub let x: Float;
        pub let y: Float;

        pub fn new(id: String, x: Float, y: Float) -> Self {
            return Self { id: id, x: x, y: y };
        }
    }

    pub class HierarchicalAStar {
        pub let levels: Int;

        pub fn new() -> Self {
            return Self { levels: 3 };
        }

        pub fn find(self, start: String, goal: String) -> List<String> {
            # Hierarchical A* route
            return [start, goal];
        }
    }

    pub class DynamicAvoidance {
        pub let horizon_sec: Float;

        pub fn new() -> Self {
            return Self { horizon_sec: 1.5 };
        }

        pub fn avoid(self, npc_id: String, desired_path: List<String>) -> List<String> {
            # Dynamic obstacle avoidance
            return desired_path;
        }
    }

    pub class RerouteSystem {
        pub fn reroute(self, npc_id: String, current_goal: String) -> List<String> {
            # Real-time rerouting
            return [current_goal];
        }
    }
}

# ============================================================
# CROWD SIMULATION
# ============================================================

pub mod crowd {
    pub class CrowdAgent {
        pub let id: String;
        pub let radius: Float;
        pub let panic_level: Float;

        pub fn new(id: String) -> Self {
            return Self { id: id, radius: 0.4, panic_level: 0.0 };
        }
    }

    pub class CrowdSystem {
        pub let agents: Map<String, CrowdAgent>;
        pub let density_limit: Float;

        pub fn new() -> Self {
            return Self { agents: {}, density_limit: 3.5 };
        }

        pub fn local_avoidance(self, dt: Float) {
            # Local collision avoidance
        }

        pub fn enforce_density(self) {
            # Density control
        }

        pub fn panic_wave(self, epicenter_x: Float, epicenter_y: Float, intensity: Float) {
            # Panic behavior model
        }
    }
}

# ============================================================
# POLICE SYSTEM
# ============================================================

pub mod police {
    pub class HeatState {
        pub let level: Int;
        pub let score: Float;

        pub fn new() -> Self {
            return Self { level: 0, score: 0.0 };
        }

        pub fn escalate(self, delta: Float) {
            self.score = self.score + delta;
            if self.score > 25.0 { self.level = 1; }
            if self.score > 50.0 { self.level = 2; }
            if self.score > 80.0 { self.level = 3; }
            if self.score > 120.0 { self.level = 4; }
            if self.score > 180.0 { self.level = 5; }
        }
    }

    pub class RoadblockPlanner {
        pub fn plan(self, suspect_route: List<String>) -> List<String> {
            # Strategic roadblocks
            return suspect_route;
        }
    }

    pub class HelicopterTracker {
        pub let active: Bool;

        pub fn new() -> Self {
            return Self { active: false };
        }

        pub fn assign_target(self, target_id: String) {
            self.active = true;
        }
    }

    pub class PoliceDirector {
        pub let heat: HeatState;
        pub let roadblocks: RoadblockPlanner;
        pub let helicopter: HelicopterTracker;

        pub fn new() -> Self {
            return Self {
                heat: HeatState::new(),
                roadblocks: RoadblockPlanner(),
                helicopter: HelicopterTracker::new()
            };
        }
    }
}

# ============================================================
# COMBAT AI
# ============================================================

pub mod combat {
    pub class CoverPoint {
        pub let id: String;
        pub let quality: Float;

        pub fn new(id: String, quality: Float) -> Self {
            return Self { id: id, quality: quality };
        }
    }

    pub class CoverSystem {
        pub let points: List<CoverPoint>;

        pub fn new() -> Self {
            return Self { points: [] };
        }

        pub fn pick_cover(self, npc_id: String) -> String {
            return self.points.len() > 0 ? self.points[0].id : "none";
        }
    }

    pub class FlankPlanner {
        pub fn compute(self, squad_ids: List<String>, enemy_id: String) -> Map<String, String> {
            # Tactical flanking plan
            return {};
        }
    }

    pub class SquadComms {
        pub fn broadcast(self, squad_ids: List<String>, message: String) {
            # Squad communication channel
        }
    }

    pub class CombatDirector {
        pub let cover: CoverSystem;
        pub let flank: FlankPlanner;
        pub let comms: SquadComms;

        pub fn new() -> Self {
            return Self {
                cover: CoverSystem::new(),
                flank: FlankPlanner(),
                comms: SquadComms()
            };
        }
    }
}

# ============================================================
# SOCIAL SIMULATION
# ============================================================

pub mod social {
    pub class MemoryEvent {
        pub let timestamp: Int;
        pub let summary: String;
        pub let valence: Float;

        pub fn new(timestamp: Int, summary: String, valence: Float) -> Self {
            return Self { timestamp: timestamp, summary: summary, valence: valence };
        }
    }

    pub class NPCMemory {
        pub let events: List<MemoryEvent>;

        pub fn new() -> Self {
            return Self { events: [] };
        }

        pub fn remember(self, event: MemoryEvent) {
            self.events.push(event);
        }
    }

    pub class RelationshipGraph {
        pub let edges: Map<String, Float>;

        pub fn new() -> Self {
            return Self { edges: {} };
        }

        pub fn set_affinity(self, a: String, b: String, value: Float) {
            self.edges[a + "->" + b] = value;
        }
    }

    pub class EconomyInteraction {
        pub fn transact(self, npc_id: String, vendor_id: String, amount: Float) {
            # Economy interaction event
        }
    }

    pub class RumorNetwork {
        pub let rumor_speed: Float;

        pub fn new() -> Self {
            return Self { rumor_speed: 1.0 };
        }

        pub fn propagate(self, source_npc: String, rumor: String) {
            # Dynamic rumor propagation
        }
    }

    pub class SocialDirector {
        pub let memory: Map<String, NPCMemory>;
        pub let relations: RelationshipGraph;
        pub let economy: EconomyInteraction;
        pub let rumors: RumorNetwork;

        pub fn new() -> Self {
            return Self {
                memory: {},
                relations: RelationshipGraph::new(),
                economy: EconomyInteraction(),
                rumors: RumorNetwork::new()
            };
        }
    }
}

# ============================================================
# AI ORCHESTRATOR
# ============================================================

pub class AIEngine {
    pub let config: AIConfig;
    pub let brains: Map<String, hybrid.Brain>;
    pub let astar: path.HierarchicalAStar;
    pub let avoidance: path.DynamicAvoidance;
    pub let reroute: path.RerouteSystem;
    pub let crowd: crowd.CrowdSystem;
    pub let police: police.PoliceDirector;
    pub let combat: combat.CombatDirector;
    pub let social: social.SocialDirector;

    pub fn new(config: AIConfig) -> Self {
        return Self {
            config: config,
            brains: {},
            astar: path.HierarchicalAStar::new(),
            avoidance: path.DynamicAvoidance::new(),
            reroute: path.RerouteSystem(),
            crowd: crowd.CrowdSystem::new(),
            police: police.PoliceDirector::new(),
            combat: combat.CombatDirector::new(),
            social: social.SocialDirector::new()
        };
    }

    pub fn tick(self, dt: Float) {
        self.crowd.local_avoidance(dt);
        self.crowd.enforce_density();
    }

    pub fn register_brain(self, npc_id: String, brain: hybrid.Brain) {
        self.brains[npc_id] = brain;
    }
}

pub fn create_ai(config: AIConfig) -> AIEngine {
    return AIEngine::new(config);
}

# ============================================================
# WORLD CLASS EXTENSIONS - NYAI
# ============================================================

pub mod perception {
    pub class VisionSensor {
        pub let fov_deg: Float;
        pub let range_m: Float;

        pub fn new() -> Self {
            return Self { fov_deg: 120.0, range_m: 60.0 };
        }

        pub fn scan(self, npc_id: String) -> List<String> {
            # Visibility query
            return [];
        }
    }

    pub class HearingSensor {
        pub let range_m: Float;

        pub fn new() -> Self {
            return Self { range_m: 45.0 };
        }

        pub fn sample(self, npc_id: String) -> List<String> {
            # Sound event query
            return [];
        }
    }

    pub class ThreatEstimator {
        pub fn score(self, actor_id: String, target_id: String) -> Float {
            # Threat scoring model
            return 0.0;
        }
    }

    pub class PerceptionStack {
        pub let vision: VisionSensor;
        pub let hearing: HearingSensor;
        pub let threat: ThreatEstimator;

        pub fn new() -> Self {
            return Self {
                vision: VisionSensor::new(),
                hearing: HearingSensor::new(),
                threat: ThreatEstimator()
            };
        }
    }
}

pub mod utility {
    pub class UtilityConsideration {
        pub let name: String;
        pub let weight: Float;

        pub fn new(name: String, weight: Float) -> Self {
            return Self { name: name, weight: weight };
        }

        pub fn evaluate(self, context: Map<String, Float>) -> Float {
            return (context[self.name] or 0.0) * self.weight;
        }
    }

    pub class UtilityAction {
        pub let id: String;
        pub let considerations: List<UtilityConsideration>;

        pub fn new(id: String) -> Self {
            return Self { id: id, considerations: [] };
        }

        pub fn score(self, context: Map<String, Float>) -> Float {
            let total = 0.0;
            for c in self.considerations {
                total = total + c.evaluate(context);
            }
            return total;
        }
    }

    pub class UtilitySelector {
        pub let actions: List<UtilityAction>;

        pub fn new() -> Self {
            return Self { actions: [] };
        }

        pub fn choose(self, context: Map<String, Float>) -> String {
            let best_id = "none";
            let best_score = -9999.0;
            for action in self.actions {
                let score = action.score(context);
                if score > best_score {
                    best_score = score;
                    best_id = action.id;
                }
            }
            return best_id;
        }
    }
}

pub mod knowledge {
    pub class Blackboard {
        pub let values: Map<String, Any>;

        pub fn new() -> Self {
            return Self { values: {} };
        }

        pub fn set(self, key: String, value: Any) {
            self.values[key] = value;
        }

        pub fn get(self, key: String) -> Any {
            return self.values[key];
        }
    }

    pub class SharedKnowledge {
        pub let facts: Map<String, Float>;

        pub fn new() -> Self {
            return Self { facts: {} };
        }

        pub fn publish(self, fact: String, confidence: Float) {
            self.facts[fact] = confidence;
        }
    }

    pub class MemoryDecay {
        pub let half_life_sec: Float;

        pub fn new() -> Self {
            return Self { half_life_sec: 180.0 };
        }

        pub fn decay(self, value: Float, dt: Float) -> Float {
            let k = dt / self.half_life_sec;
            return value * (1.0 - k);
        }
    }
}

pub mod narrative {
    pub class DialogueLine {
        pub let id: String;
        pub let text: String;
        pub let emotion: String;

        pub fn new(id: String, text: String, emotion: String) -> Self {
            return Self { id: id, text: text, emotion: emotion };
        }
    }

    pub class DialogueDirector {
        pub let lines: Map<String, DialogueLine>;

        pub fn new() -> Self {
            return Self { lines: {} };
        }

        pub fn choose(self, npc_id: String, context: Map<String, String>) -> DialogueLine? {
            for line in self.lines.values() {
                return line;
            }
            return null;
        }
    }

    pub class MissionDirector {
        pub let active_missions: List<String>;

        pub fn new() -> Self {
            return Self { active_missions: [] };
        }

        pub fn tick(self, dt: Float) {
            # Dynamic mission and encounter direction
        }
    }
}

pub mod training {
    pub class BehaviorTelemetry {
        pub let npc_id: String;
        pub let decision: String;
        pub let reward: Float;

        pub fn new(npc_id: String, decision: String, reward: Float) -> Self {
            return Self { npc_id: npc_id, decision: decision, reward: reward };
        }
    }

    pub class ReplayDataset {
        pub let items: List<BehaviorTelemetry>;

        pub fn new() -> Self {
            return Self { items: [] };
        }

        pub fn push(self, item: BehaviorTelemetry) {
            self.items.push(item);
        }
    }

    pub class OnlineAdaptation {
        pub let enabled: Bool;

        pub fn new() -> Self {
            return Self { enabled: false };
        }

        pub fn update(self, data: ReplayDataset) {
            # Optional online behavior adaptation
        }
    }
}

pub mod debugging {
    pub class Explainability {
        pub fn explain(self, npc_id: String, decision: String) -> String {
            return "npc=" + npc_id + ", decision=" + decision;
        }
    }

    pub class BudgetController {
        pub let max_ms: Float;

        pub fn new() -> Self {
            return Self { max_ms: 2.5 };
        }

        pub fn enforce(self) {
            # AI budget and throttling control
        }
    }
}

pub class WorldClassAISuite {
    pub let perception: perception.PerceptionStack;
    pub let utility: utility.UtilitySelector;
    pub let blackboards: Map<String, knowledge.Blackboard>;
    pub let shared_knowledge: knowledge.SharedKnowledge;
    pub let memory_decay: knowledge.MemoryDecay;
    pub let dialogue: narrative.DialogueDirector;
    pub let missions: narrative.MissionDirector;
    pub let dataset: training.ReplayDataset;
    pub let adaptation: training.OnlineAdaptation;
    pub let explain: debugging.Explainability;
    pub let budgets: debugging.BudgetController;

    pub fn new() -> Self {
        return Self {
            perception: perception.PerceptionStack::new(),
            utility: utility.UtilitySelector::new(),
            blackboards: {},
            shared_knowledge: knowledge.SharedKnowledge::new(),
            memory_decay: knowledge.MemoryDecay::new(),
            dialogue: narrative.DialogueDirector::new(),
            missions: narrative.MissionDirector::new(),
            dataset: training.ReplayDataset::new(),
            adaptation: training.OnlineAdaptation::new(),
            explain: debugging.Explainability(),
            budgets: debugging.BudgetController::new()
        };
    }

    pub fn tick(self, engine: AIEngine, dt: Float) {
        self.budgets.enforce();
        self.missions.tick(dt);
        engine.tick(dt);
    }
}

pub fn upgrade_ai_worldclass() -> WorldClassAISuite {
    return WorldClassAISuite::new();
}

# ============================================================
# PRODUCTION HARDENING EXTENSIONS - NYAI
# ============================================================

pub mod persistence {
    pub class PersistentEvent {
        pub let npc_id: String;
        pub let key: String;
        pub let value: String;

        pub fn new(npc_id: String, key: String, value: String) -> Self {
            return Self { npc_id: npc_id, key: key, value: value };
        }
    }

    pub class LongTermMemoryDB {
        pub let events: List<PersistentEvent>;

        pub fn new() -> Self {
            return Self { events: [] };
        }

        pub fn write(self, npc_id: String, key: String, value: String) {
            self.events.push(PersistentEvent::new(npc_id, key, value));
        }

        pub fn query(self, npc_id: String, key: String) -> String {
            for item in self.events {
                if item.npc_id == npc_id and item.key == key {
                    return item.value;
                }
            }
            return "";
        }
    }
}

pub mod budget {
    pub class FrameBudget {
        pub let max_ms: Float;
        pub let used_ms: Float;

        pub fn new(max_ms: Float) -> Self {
            return Self { max_ms: max_ms, used_ms: 0.0 };
        }

        pub fn reset(self) {
            self.used_ms = 0.0;
        }

        pub fn charge(self, cost_ms: Float) -> Bool {
            self.used_ms = self.used_ms + cost_ms;
            return self.used_ms <= self.max_ms;
        }
    }

    pub class BudgetGovernor {
        pub let full_ai_budget: FrameBudget;
        pub let mid_ai_budget: FrameBudget;
        pub let far_ai_budget: FrameBudget;

        pub fn new() -> Self {
            return Self {
                full_ai_budget: FrameBudget::new(4.0),
                mid_ai_budget: FrameBudget::new(2.0),
                far_ai_budget: FrameBudget::new(0.8)
            };
        }

        pub fn begin_frame(self) {
            self.full_ai_budget.reset();
            self.mid_ai_budget.reset();
            self.far_ai_budget.reset();
        }
    }
}

pub mod production {
    pub class Health {
        pub let decision_ms: Float;
        pub let budget_ok: Bool;
        pub let persistent_events: Int;

        pub fn new() -> Self {
            return Self {
                decision_ms: 0.0,
                budget_ok: true,
                persistent_events: 0
            };
        }

        pub fn ok(self) -> Bool {
            return self.budget_ok and self.decision_ms < 8.0;
        }
    }
}

pub class ProductionAIProfile {
    pub let memory_db: persistence.LongTermMemoryDB;
    pub let governor: budget.BudgetGovernor;
    pub let health: production.Health;

    pub fn new() -> Self {
        return Self {
            memory_db: persistence.LongTermMemoryDB::new(),
            governor: budget.BudgetGovernor::new(),
            health: production.Health::new()
        };
    }

    pub fn tick(self, engine: AIEngine, dt: Float) {
        self.governor.begin_frame();
        engine.tick(dt);
        self.health.decision_ms = native_ai_frame_time_ms();
        self.health.budget_ok = self.governor.full_ai_budget.used_ms <= self.governor.full_ai_budget.max_ms;
        self.health.persistent_events = self.memory_db.events.len();
    }
}

pub fn create_ai_production_profile() -> ProductionAIProfile {
    return ProductionAIProfile::new();
}

native_ai_frame_time_ms() -> Float;

# ============================================================
# DECLARATIVE NO-CODE EXTENSIONS - NYAI
# ============================================================

pub mod intent_authoring {
    pub class IntentProfile {
        pub let id: String;
        pub let stance: String;
        pub let aggression: Float;
        pub let caution: Float;
        pub let persistence: Float;
        pub let cooperation: Float;

        pub fn new(id: String, stance: String) -> Self {
            return Self {
                id: id,
                stance: stance,
                aggression: 0.5,
                caution: 0.5,
                persistence: 0.5,
                cooperation: 0.5
            };
        }
    }

    pub class IntentCompiler {
        pub fn compile(self, profile: IntentProfile) -> Bytes {
            return native_nyai_build_hybrid_from_intent(profile.stance);
        }
    }
}

pub mod memory_graph {
    pub class MemoryEvent {
        pub let id: String;
        pub let event_type: String;
        pub let actor_id: String;
        pub let target_id: String;
        pub let fear_delta: Float;
        pub let trust_delta: Float;

        pub fn new(id: String, event_type: String, actor_id: String, target_id: String) -> Self {
            return Self {
                id: id,
                event_type: event_type,
                actor_id: actor_id,
                target_id: target_id,
                fear_delta: 0.0,
                trust_delta: 0.0
            };
        }
    }

    pub class RelationshipEdge {
        pub let from_npc: String;
        pub let to_npc: String;
        pub let trust: Float;
        pub let fear: Float;

        pub fn new(from_npc: String, to_npc: String) -> Self {
            return Self { from_npc: from_npc, to_npc: to_npc, trust: 0.0, fear: 0.0 };
        }
    }

    pub class Graph {
        pub let events: Map<String, MemoryEvent>;
        pub let relationships: Map<String, RelationshipEdge>;

        pub fn new() -> Self {
            return Self { events: {}, relationships: {} };
        }

        pub fn push_event(self, event: MemoryEvent) {
            self.events[event.id] = event;
        }

        pub fn set_relationship(self, edge: RelationshipEdge) {
            self.relationships[edge.from_npc + "->" + edge.to_npc] = edge;
        }
    }
}

pub mod sandbox {
    pub class SandboxScenario {
        pub let id: String;
        pub let world_seed: Int;
        pub let npc_count: Int;
        pub let duration_steps: Int;

        pub fn new(id: String) -> Self {
            return Self {
                id: id,
                world_seed: 42,
                npc_count: 128,
                duration_steps: 600
            };
        }
    }

    pub class SandboxResult {
        pub let summary: Bytes;
        pub let divergence_score: Float;

        pub fn new(summary: Bytes, divergence_score: Float) -> Self {
            return Self { summary: summary, divergence_score: divergence_score };
        }
    }

    pub class Simulator {
        pub let active: Bool;

        pub fn new() -> Self {
            return Self { active: true };
        }

        pub fn run(self, scenario: SandboxScenario) -> SandboxResult {
            let summary = native_nyai_run_sandbox(scenario.duration_steps);
            return SandboxResult::new(summary, 0.0);
        }
    }
}

pub class NoCodeAIRuntime {
    pub let compiler: intent_authoring.IntentCompiler;
    pub let memory: memory_graph.Graph;
    pub let simulator: sandbox.Simulator;

    pub fn new() -> Self {
        return Self {
            compiler: intent_authoring.IntentCompiler(),
            memory: memory_graph.Graph::new(),
            simulator: sandbox.Simulator::new()
        };
    }

    pub fn build_behavior(self, profile: intent_authoring.IntentProfile) -> Bytes {
        return self.compiler.compile(profile);
    }

    pub fn run_sandbox(self, id: String) -> sandbox.SandboxResult {
        return self.simulator.run(sandbox.SandboxScenario::new(id));
    }
}

pub fn create_nocode_ai_runtime() -> NoCodeAIRuntime {
    return NoCodeAIRuntime::new();
}

native_nyai_build_hybrid_from_intent(intent: String) -> Bytes;
native_nyai_run_sandbox(step_count: Int) -> Bytes;
