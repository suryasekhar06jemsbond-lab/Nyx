# ============================================================
# NYGRAPH - Nyx Knowledge & Relationship Engine
# ============================================================
# Large-scale graph database with semantic search, relationship
# traversal, graph inference, dynamic updates, and distributed
# graph storage for AI agent knowledge systems.

let VERSION = "1.0.0";

# ============================================================
# GRAPH CORE
# ============================================================

pub mod core {
    pub class Node {
        pub let id: String;
        pub let labels: List<String>;
        pub let properties: Map<String, Any>;
        pub let created_at: Int;
        pub let updated_at: Int;

        pub fn new(id: String) -> Self {
            let now = native_graph_time_ms();
            return Self {
                id: id, labels: [], properties: {},
                created_at: now, updated_at: now
            };
        }

        pub fn add_label(self, label: String) -> Self {
            self.labels.push(label);
            return self;
        }

        pub fn set(self, key: String, value: Any) -> Self {
            self.properties[key] = value;
            self.updated_at = native_graph_time_ms();
            return self;
        }

        pub fn get(self, key: String) -> Any? {
            return self.properties.get(key);
        }

        pub fn has_label(self, label: String) -> Bool {
            return self.labels.contains(label);
        }
    }

    pub class Edge {
        pub let id: String;
        pub let source: String;
        pub let target: String;
        pub let relation: String;
        pub let properties: Map<String, Any>;
        pub let weight: Float;
        pub let directed: Bool;

        pub fn new(source: String, target: String, relation: String) -> Self {
            return Self {
                id: native_graph_uuid(),
                source: source, target: target,
                relation: relation, properties: {},
                weight: 1.0, directed: true
            };
        }

        pub fn set(self, key: String, value: Any) -> Self {
            self.properties[key] = value;
            return self;
        }

        pub fn with_weight(self, w: Float) -> Self {
            self.weight = w;
            return self;
        }

        pub fn bidirectional(self) -> Self {
            self.directed = false;
            return self;
        }
    }

    pub class Graph {
        pub let nodes: Map<String, Node>;
        pub let edges: Map<String, Edge>;
        pub let adjacency: Map<String, List<String>>;
        pub let reverse_adj: Map<String, List<String>>;

        pub fn new() -> Self {
            return Self {
                nodes: {}, edges: {},
                adjacency: {}, reverse_adj: {}
            };
        }

        pub fn add_node(self, node: Node) {
            self.nodes[node.id] = node;
            if not self.adjacency.has(node.id) { self.adjacency[node.id] = []; }
            if not self.reverse_adj.has(node.id) { self.reverse_adj[node.id] = []; }
        }

        pub fn add_edge(self, edge: Edge) {
            self.edges[edge.id] = edge;
            self.adjacency[edge.source].push(edge.id);
            self.reverse_adj[edge.target].push(edge.id);
            if not edge.directed {
                self.adjacency[edge.target].push(edge.id);
                self.reverse_adj[edge.source].push(edge.id);
            }
        }

        pub fn remove_node(self, id: String) {
            let edge_ids = (self.adjacency.get(id) or []) + (self.reverse_adj.get(id) or []);
            for eid in edge_ids {
                self.edges.remove(eid);
            }
            self.nodes.remove(id);
            self.adjacency.remove(id);
            self.reverse_adj.remove(id);
        }

        pub fn remove_edge(self, id: String) {
            let edge = self.edges.get(id);
            if edge != null {
                self.adjacency[edge.source] = self.adjacency[edge.source].filter(|e| e != id);
                self.reverse_adj[edge.target] = self.reverse_adj[edge.target].filter(|e| e != id);
                self.edges.remove(id);
            }
        }

        pub fn get_node(self, id: String) -> Node? {
            return self.nodes.get(id);
        }

        pub fn neighbors(self, node_id: String) -> List<Node> {
            let edge_ids = self.adjacency.get(node_id) or [];
            let result = [];
            for eid in edge_ids {
                let edge = self.edges[eid];
                let neighbor_id = if edge.source == node_id { edge.target } else { edge.source };
                let node = self.nodes.get(neighbor_id);
                if node != null { result.push(node); }
            }
            return result;
        }

        pub fn edges_from(self, node_id: String) -> List<Edge> {
            let edge_ids = self.adjacency.get(node_id) or [];
            return edge_ids.map(|eid| self.edges[eid]);
        }

        pub fn edges_to(self, node_id: String) -> List<Edge> {
            let edge_ids = self.reverse_adj.get(node_id) or [];
            return edge_ids.map(|eid| self.edges[eid]);
        }

        pub fn node_count(self) -> Int { return self.nodes.len(); }
        pub fn edge_count(self) -> Int { return self.edges.len(); }

        pub fn nodes_by_label(self, label: String) -> List<Node> {
            return self.nodes.values().filter(|n| n.has_label(label)).to_list();
        }

        pub fn find_edges(self, relation: String) -> List<Edge> {
            return self.edges.values().filter(|e| e.relation == relation).to_list();
        }
    }
}

# ============================================================
# TRAVERSAL & PATH FINDING
# ============================================================

pub mod traversal {
    pub class PathResult {
        pub let nodes: List<String>;
        pub let edges: List<String>;
        pub let total_weight: Float;
    }

    pub class Traversal {
        pub let graph: core.Graph;

        pub fn new(graph: core.Graph) -> Self {
            return Self { graph: graph };
        }

        pub fn bfs(self, start: String, visitor: Fn) -> List<String> {
            let visited = {};
            let queue = [start];
            let result = [];
            visited[start] = true;

            while queue.len() > 0 {
                let current = queue.remove(0);
                result.push(current);
                visitor(self.graph.get_node(current));

                for neighbor in self.graph.neighbors(current) {
                    if not visited.has(neighbor.id) {
                        visited[neighbor.id] = true;
                        queue.push(neighbor.id);
                    }
                }
            }
            return result;
        }

        pub fn dfs(self, start: String, visitor: Fn) -> List<String> {
            let visited = {};
            let result = [];
            self._dfs_recursive(start, visited, result, visitor);
            return result;
        }

        fn _dfs_recursive(self, node_id: String, visited: Map, result: List, visitor: Fn) {
            if visited.has(node_id) { return; }
            visited[node_id] = true;
            result.push(node_id);
            visitor(self.graph.get_node(node_id));

            for neighbor in self.graph.neighbors(node_id) {
                self._dfs_recursive(neighbor.id, visited, result, visitor);
            }
        }

        pub fn shortest_path(self, start: String, end: String) -> PathResult? {
            return native_graph_dijkstra(self.graph, start, end);
        }

        pub fn a_star(self, start: String, end: String, heuristic: Fn) -> PathResult? {
            return native_graph_a_star(self.graph, start, end, heuristic);
        }

        pub fn all_paths(self, start: String, end: String, max_depth: Int) -> List<PathResult> {
            return native_graph_all_paths(self.graph, start, end, max_depth);
        }

        pub fn topological_sort(self) -> List<String>? {
            return native_graph_topo_sort(self.graph);
        }

        pub fn connected_components(self) -> List<List<String>> {
            return native_graph_components(self.graph);
        }

        pub fn strongly_connected(self) -> List<List<String>> {
            return native_graph_scc(self.graph);
        }

        pub fn page_rank(self, damping: Float, iterations: Int) -> Map<String, Float> {
            return native_graph_pagerank(self.graph, damping, iterations);
        }

        pub fn betweenness_centrality(self) -> Map<String, Float> {
            return native_graph_betweenness(self.graph);
        }

        pub fn community_detection(self) -> List<List<String>> {
            return native_graph_communities(self.graph);
        }
    }
}

# ============================================================
# SEMANTIC SEARCH
# ============================================================

pub mod search {
    pub class EmbeddingIndex {
        pub let dimension: Int;
        pub let index_handle: Int?;

        pub fn new(dimension: Int) -> Self {
            return Self { dimension: dimension, index_handle: null };
        }

        pub fn build(self, nodes: List<core.Node>, embed_fn: Fn) {
            let embeddings = [];
            for node in nodes {
                let vec = embed_fn(node);
                embeddings.push({ "id": node.id, "vector": vec });
            }
            self.index_handle = native_graph_build_index(embeddings, self.dimension);
        }

        pub fn search(self, query_vec: List<Float>, top_k: Int) -> List<Map<String, Any>> {
            return native_graph_ann_search(self.index_handle, query_vec, top_k);
        }

        pub fn add(self, id: String, vector: List<Float>) {
            native_graph_index_add(self.index_handle, id, vector);
        }

        pub fn remove(self, id: String) {
            native_graph_index_remove(self.index_handle, id);
        }
    }

    pub class SemanticSearch {
        pub let graph: core.Graph;
        pub let index: EmbeddingIndex;
        pub let embed_fn: Fn;

        pub fn new(graph: core.Graph, dimension: Int, embed_fn: Fn) -> Self {
            let idx = EmbeddingIndex::new(dimension);
            idx.build(graph.nodes.values().to_list(), embed_fn);
            return Self { graph: graph, index: idx, embed_fn: embed_fn };
        }

        pub fn search(self, query: String, top_k: Int) -> List<core.Node> {
            let query_vec = self.embed_fn(query);
            let results = self.index.search(query_vec, top_k);
            return results.map(|r| self.graph.get_node(r["id"])).filter(|n| n != null);
        }

        pub fn similar(self, node_id: String, top_k: Int) -> List<core.Node> {
            let node = self.graph.get_node(node_id);
            if node == null { return []; }
            let vec = self.embed_fn(node);
            let results = self.index.search(vec, top_k + 1);
            return results.filter(|r| r["id"] != node_id)
                          .map(|r| self.graph.get_node(r["id"]))
                          .filter(|n| n != null)
                          .slice(0, top_k);
        }
    }
}

# ============================================================
# GRAPH INFERENCE
# ============================================================

pub mod inference {
    pub class GraphReasoner {
        pub let graph: core.Graph;

        pub fn new(graph: core.Graph) -> Self {
            return Self { graph: graph };
        }

        pub fn transitive_closure(self, relation: String) -> List<core.Edge> {
            return native_graph_transitive_closure(self.graph, relation);
        }

        pub fn infer_links(self, relation: String, confidence_threshold: Float) -> List<Map<String, Any>> {
            return native_graph_link_prediction(self.graph, relation, confidence_threshold);
        }

        pub fn classify_node(self, node_id: String, label_prop: String) -> String {
            return native_graph_label_propagation(self.graph, node_id, label_prop);
        }

        pub fn knowledge_completion(self, head: String, relation: String) -> List<Map<String, Any>> {
            return native_graph_kg_completion(self.graph, head, relation);
        }

        pub fn pattern_match(self, pattern: core.Graph) -> List<Map<String, String>> {
            return native_graph_subgraph_match(self.graph, pattern);
        }

        pub fn embeddings(self, dimension: Int, method: String) -> Map<String, List<Float>> {
            return native_graph_node_embeddings(self.graph, dimension, method);
        }
    }
}

# ============================================================
# QUERY LANGUAGE
# ============================================================

pub mod query {
    pub class GraphQuery {
        pub let graph: core.Graph;
        pub let steps: List<Map<String, Any>>;

        pub fn new(graph: core.Graph) -> Self {
            return Self { graph: graph, steps: [] };
        }

        pub fn match_node(self, label: String) -> Self {
            self.steps.push({ "type": "match_node", "label": label });
            return self;
        }

        pub fn where_prop(self, key: String, op: String, value: Any) -> Self {
            self.steps.push({ "type": "where", "key": key, "op": op, "value": value });
            return self;
        }

        pub fn traverse(self, relation: String) -> Self {
            self.steps.push({ "type": "traverse", "relation": relation });
            return self;
        }

        pub fn traverse_in(self, relation: String) -> Self {
            self.steps.push({ "type": "traverse_in", "relation": relation });
            return self;
        }

        pub fn depth(self, min: Int, max: Int) -> Self {
            self.steps.push({ "type": "depth", "min": min, "max": max });
            return self;
        }

        pub fn limit(self, n: Int) -> Self {
            self.steps.push({ "type": "limit", "n": n });
            return self;
        }

        pub fn order_by(self, key: String, asc: Bool) -> Self {
            self.steps.push({ "type": "order", "key": key, "asc": asc });
            return self;
        }

        pub fn select(self, fields: List<String>) -> Self {
            self.steps.push({ "type": "select", "fields": fields });
            return self;
        }

        pub fn execute(self) -> List<Map<String, Any>> {
            return native_graph_execute_query(self.graph, self.steps);
        }

        pub fn count(self) -> Int {
            self.steps.push({ "type": "count" });
            let result = native_graph_execute_query(self.graph, self.steps);
            return result[0]["count"] or 0;
        }
    }
}

# ============================================================
# DISTRIBUTED GRAPH STORAGE
# ============================================================

pub mod distributed {
    pub class Partition {
        pub let id: Int;
        pub let node_ids: List<String>;
        pub let host: String;

        pub fn new(id: Int, host: String) -> Self {
            return Self { id: id, node_ids: [], host: host };
        }
    }

    pub class DistributedGraph {
        pub let name: String;
        pub let partitions: List<Partition>;
        pub let replication_factor: Int;
        pub let partition_strategy: String;

        pub fn new(name: String) -> Self {
            return Self {
                name: name, partitions: [],
                replication_factor: 2,
                partition_strategy: "hash"
            };
        }

        pub fn add_partition(self, host: String) -> Partition {
            let p = Partition::new(self.partitions.len(), host);
            self.partitions.push(p);
            return p;
        }

        pub fn put_node(self, node: core.Node) {
            let partition = self._route(node.id);
            native_graph_dist_put_node(partition.host, self.name, node);
        }

        pub fn put_edge(self, edge: core.Edge) {
            native_graph_dist_put_edge(self.partitions, self.name, edge);
        }

        pub fn get_node(self, id: String) -> core.Node? {
            let partition = self._route(id);
            return native_graph_dist_get_node(partition.host, self.name, id);
        }

        pub fn query(self, q: query.GraphQuery) -> List<Map<String, Any>> {
            return native_graph_dist_query(self.partitions, self.name, q.steps);
        }

        pub fn sync(self) {
            native_graph_dist_sync(self.partitions, self.name);
        }

        fn _route(self, key: String) -> Partition {
            let hash = native_graph_hash(key);
            let idx = hash % self.partitions.len();
            return self.partitions[idx];
        }
    }
}

# ============================================================
# KNOWLEDGE GRAPH ORCHESTRATOR
# ============================================================

pub class KnowledgeGraph {
    pub let graph: core.Graph;
    pub let traversal: traversal.Traversal;
    pub let reasoner: inference.GraphReasoner;

    pub fn new() -> Self {
        let g = core.Graph::new();
        return Self {
            graph: g,
            traversal: traversal.Traversal::new(g),
            reasoner: inference.GraphReasoner::new(g)
        };
    }

    pub fn add_entity(self, id: String, label: String, props: Map<String, Any>) -> core.Node {
        let node = core.Node::new(id).add_label(label);
        for entry in props.entries() { node.set(entry.key, entry.value); }
        self.graph.add_node(node);
        return node;
    }

    pub fn add_relation(self, from: String, to: String, relation: String) -> core.Edge {
        let edge = core.Edge::new(from, to, relation);
        self.graph.add_edge(edge);
        return edge;
    }

    pub fn query(self) -> query.GraphQuery {
        return query.GraphQuery::new(self.graph);
    }
}

pub fn create_knowledge_graph() -> KnowledgeGraph {
    return KnowledgeGraph::new();
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_graph_time_ms() -> Int;
native_graph_uuid() -> String;
native_graph_hash(key: String) -> Int;
native_graph_dijkstra(graph: Any, start: String, end: String) -> Any;
native_graph_a_star(graph: Any, start: String, end: String, heuristic: Fn) -> Any;
native_graph_all_paths(graph: Any, start: String, end: String, max_depth: Int) -> List;
native_graph_topo_sort(graph: Any) -> List;
native_graph_components(graph: Any) -> List;
native_graph_scc(graph: Any) -> List;
native_graph_pagerank(graph: Any, damping: Float, iterations: Int) -> Map;
native_graph_betweenness(graph: Any) -> Map;
native_graph_communities(graph: Any) -> List;
native_graph_build_index(embeddings: List, dim: Int) -> Int;
native_graph_ann_search(handle: Int, query: List, top_k: Int) -> List;
native_graph_index_add(handle: Int, id: String, vector: List);
native_graph_index_remove(handle: Int, id: String);
native_graph_transitive_closure(graph: Any, relation: String) -> List;
native_graph_link_prediction(graph: Any, relation: String, threshold: Float) -> List;
native_graph_label_propagation(graph: Any, node_id: String, label_prop: String) -> String;
native_graph_kg_completion(graph: Any, head: String, relation: String) -> List;
native_graph_subgraph_match(graph: Any, pattern: Any) -> List;
native_graph_node_embeddings(graph: Any, dimension: Int, method: String) -> Map;
native_graph_execute_query(graph: Any, steps: List) -> List;
native_graph_dist_put_node(host: String, name: String, node: Any);
native_graph_dist_put_edge(partitions: List, name: String, edge: Any);
native_graph_dist_get_node(host: String, name: String, id: String) -> Any;
native_graph_dist_query(partitions: List, name: String, steps: List) -> List;
native_graph_dist_sync(partitions: List, name: String);

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
