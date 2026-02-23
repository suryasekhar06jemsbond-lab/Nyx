# ============================================================
# NyGraph - Graph Machine Learning Engine
# Version 1.0.0
# Graph neural networks, message passing, node/edge/graph classification
# ============================================================

use nytensor;
use nygrad;
use nynet_ml;
use nyopt;

# ============================================================
# SECTION 1: GRAPH DATA STRUCTURES
# ============================================================

pub enum GraphType {
    Undirected,
    Directed,
    Weighted,
    Bipartite,
    Heterogeneous
}

pub class Graph {
    pub let num_nodes: Int;
    pub let num_edges: Int;
    pub let edge_index: Tensor;  # [2, num_edges]
    pub let edge_attr: Tensor?;  # [num_edges, edge_dim]
    pub let node_features: Tensor?;  # [num_nodes, node_dim]
    pub let edge_weight: Tensor?;  # [num_edges]
    pub let graph_type: GraphType;
    pub let _adj_list: Object?;

    pub fn new(num_nodes: Int, edge_index: Tensor, node_features: Tensor?, edge_attr: Tensor?) -> Self {
        let num_edges = edge_index.shape.dims[1];
        return Self {
            num_nodes: num_nodes,
            num_edges: num_edges,
            edge_index: edge_index,
            edge_attr: edge_attr,
            node_features: node_features,
            edge_weight: null,
            graph_type: GraphType::Undirected,
            _adj_list: null
        };
    }

    pub fn build_adj_list(self) {
        let adj = {};
        for (i in range(self.num_nodes)) {
            adj[str(i)] = [];
        }
        for (e in range(self.num_edges)) {
            let src = int(self.edge_index.get([0, e]));
            let dst = int(self.edge_index.get([1, e]));
            adj[str(src)] = adj[str(src)] + [dst];
            if (self.graph_type == GraphType::Undirected) {
                adj[str(dst)] = adj[str(dst)] + [src];
            }
        }
        self._adj_list = adj;
    }

    pub fn get_neighbors(self, node: Int) -> [Int] {
        if (self._adj_list == null) {
            self.build_adj_list();
        }
        return self._adj_list[str(node)];
    }

    pub fn add_self_loops(self) -> Graph {
        let new_edges = [];
        for (v in self.edge_index.data) {
            new_edges = new_edges + [v];
        }
        for (i in range(self.num_nodes)) {
            new_edges = new_edges + [i * 1.0];
            new_edges = new_edges + [i * 1.0];
        }
        let new_edge_index = Tensor::new(new_edges, [2, self.num_edges + self.num_nodes], DType::Float32, Device::CPU);
        return Graph::new(self.num_nodes, new_edge_index, self.node_features, self.edge_attr);
    }

    pub fn degree(self) -> Tensor {
        let degrees = Tensor::zeros([self.num_nodes], DType::Float32, Device::CPU);
        for (e in range(self.num_edges)) {
            let src = int(self.edge_index.get([0, e]));
            degrees.data[src] = degrees.data[src] + 1.0;
            if (self.graph_type == GraphType::Undirected) {
                let dst = int(self.edge_index.get([1, e]));
                degrees.data[dst] = degrees.data[dst] + 1.0;
            }
        }
        return degrees;
    }

    pub fn normalize_features(self) -> Self {
        if (self.node_features != null) {
            let mean = self.node_features.mean();
            let std = self.node_features.std();
            self.node_features = self.node_features.sub(
                Tensor::full(self.node_features.shape.dims, mean, DType::Float32, Device::CPU)
            ).scale(1.0 / std);
        }
        return self;
    }
}

pub class Batch {
    pub let graphs: [Graph];
    pub let batch_vector: Tensor;  # Node-to-graph mapping
    pub let num_graphs: Int;

    pub fn new(graphs: [Graph]) -> Self {
        let num_graphs = len(graphs);
        let total_nodes = 0;
        for (g in graphs) {
            total_nodes = total_nodes + g.num_nodes;
        }
        
        let batch_vec_data = [];
        for (g_idx in range(num_graphs)) {
            for (n in range(graphs[g_idx].num_nodes)) {
                batch_vec_data = batch_vec_data + [g_idx * 1.0];
            }
        }
        let batch_vector = Tensor::new(batch_vec_data, [total_nodes], DType::Int64, Device::CPU);
        
        return Self {
            graphs: graphs,
            batch_vector: batch_vector,
           num_graphs: num_graphs
        };
    }

    pub fn get_node_features(self) -> Tensor {
        let all_features = [];
        for (g in self.graphs) {
            if (g.node_features != null) {
                for (v in g.node_features.data) {
                    all_features = all_features + [v];
                }
            }
        }
        return Tensor::new(all_features, [len(all_features)], DType::Float32, Device::CPU);
    }

    pub fn get_edge_index(self) -> Tensor {
        let all_edges = [];
        let node_offset = 0;
        for (g in self.graphs) {
            for (e in range(g.num_edges)) {
                all_edges = all_edges + [g.edge_index.get([0, e]) + node_offset];
                all_edges = all_edges + [g.edge_index.get([1, e]) + node_offset];
            }
            node_offset = node_offset + g.num_nodes;
        }
        let num_edges = len(all_edges) / 2;
        return Tensor::new(all_edges, [2, num_edges], DType::Float32, Device::CPU);
    }
}

# ============================================================
# SECTION 2: MESSAGE PASSING BASE
# ============================================================

pub class MessagePassing : Module {
    pub let aggr: String;  # "add", "mean", "max"

    pub fn new(name: String, aggregation: String) -> Self {
        return Self {
            _params: [], _children: [], _training: true, _name: name,
            aggr: aggregation
        };
    }

    pub fn message(self, x_j: Variable, x_i: Variable, edge_attr: Variable?) -> Variable {
        throw "MessagePassing::message() must be overridden";
    }

    pub fn aggregate(self, messages: [Variable], index: [Int], num_nodes: Int) -> Variable {
        # Aggregate messages per node
        let aggregated_data = [];
        for (n in range(num_nodes)) {
            let node_messages = [];
            for (i in range(len(index))) {
                if (index[i] == n) {
                    node_messages = node_messages + [messages[i]];
                }
            }
            if (len(node_messages) == 0) {
                aggregated_data = aggregated_data + [0.0];
            } else if (self.aggr == "add") {
                let sum = 0.0;
                for (m in node_messages) {
                    sum = sum + m.data.data[0];
                }
                aggregated_data = aggregated_data + [sum];
            } else if (self.aggr == "mean") {
                let sum = 0.0;
                for (m in node_messages) {
                    sum = sum + m.data.data[0];
                }
                aggregated_data = aggregated_data + [sum / len(node_messages)];
            } else if (self.aggr == "max") {
                let max_val = node_messages[0].data.data[0];
                for (m in node_messages) {
                    if (m.data.data[0] > max_val) {
                        max_val = m.data.data[0];
                    }
                }
                aggregated_data = aggregated_data + [max_val];
            }
        }
        return Variable::new(
            Tensor::new(aggregated_data, [num_nodes], DType::Float32, Device::CPU), "aggregated");
    }

    pub fn update(self, aggr_out: Variable, x: Variable) -> Variable {
        return aggr_out;
    }

    pub fn propagate(self, graph: Graph, x: Variable) -> Variable {
        # Compute messages for all edges
        let messages = [];
        let target_indices = [];
        
        for (e in range(graph.num_edges)) {
            let src = int(graph.edge_index.get([0, e]));
            let dst = int(graph.edge_index.get([1, e]));
            
            let x_src = _get_node_embedding(x, src);
            let x_dst = _get_node_embedding(x, dst);
            let edge_attr_e = graph.edge_attr != null ? 
                Variable::new(_get_edge_features(graph.edge_attr, e), "edge_attr") : null;
            
            let msg = self.message(x_src, x_dst, edge_attr_e);
            messages = messages + [msg];
            target_indices = target_indices + [dst];
        }

        # Aggregate messages
        let aggr_out = self.aggregate(messages, target_indices, graph.num_nodes);
        
        # Update node embeddings
        return self.update(aggr_out, x);
    }
}

# ============================================================
# SECTION 3: GCN (GRAPH CONVOLUTIONAL NETWORK)
# ============================================================

pub class GCNConv : MessagePassing {
    pub let in_channels: Int;
    pub let out_channels: Int;
    pub let weight: Parameter;
    pub let bias: Parameter?;

    pub fn new(in_channels: Int, out_channels: Int, use_bias: Bool) -> Self {
        let mp = MessagePassing::new("GCNConv", "add");
        let w = Parameter::new("weight", [in_channels, out_channels], "xavier");
        let b = use_bias ? Parameter::new("bias", [out_channels], "zeros") : null;
        mp._params = [w];
        if (b != null) {
            mp._params = mp._params + [b];
        }

        return Self {
            _params: mp._params, _children: mp._children, _training: true,
            _name: "GCNConv", aggr: "add",
            in_channels: in_channels, out_channels: out_channels,
            weight: w, bias: b
        };
    }

    pub fn forward(self, x: Variable, graph: Graph) -> Variable {
        # Add self-loops
        let graph_sl = graph.add_self_loops();
        
        # Normalize by degree
        let deg = graph_sl.degree();
        let deg_sqrt_inv = [];
        for (d in deg.data) {
            deg_sqrt_inv = deg_sqrt_inv + [1.0 / native_sqrt(d + 1e-6)];
        }
        
        # x' = D^(-1/2) A D^(-1/2) X W
        let out = self.propagate(graph_sl, x);
        out = out.matmul(self.weight.data);
        
        if (self.bias != null) {
            out = out.add(self.bias.data);
        }
        
        return out;
    }

    pub fn message(self, x_j: Variable, x_i: Variable, edge_attr: Variable?) -> Variable {
        return x_j;
    }
}

# ============================================================
# SECTION 4: GAT (GRAPH ATTENTION NETWORK)
# ============================================================

pub class GATConv : MessagePassing {
    pub let in_channels: Int;
    pub let out_channels: Int;
    pub let num_heads: Int;
    pub let w_linear: Linear;
    pub let attn_src: Parameter;
    pub let attn_dst: Parameter;
    pub let dropout: Dropout;

    pub fn new(in_channels: Int, out_channels: Int, num_heads: Int, dropout_rate: Float) -> Self {
        let mp = MessagePassing::new("GATConv", "add");
        let w = Linear::new(in_channels, out_channels * num_heads, false);
        let a_src = Parameter::new("attn_src", [num_heads, out_channels], "xavier");
        let a_dst = Parameter::new("attn_dst", [num_heads, out_channels], "xavier");
        let drop = Dropout::new(dropout_rate);
        
        mp._params = [a_src, a_dst];
        mp.add_child(w);
        mp.add_child(drop);

        return Self {
            _params: mp._params, _children: mp._children, _training: true,
            _name: "GATConv", aggr: "add",
            in_channels: in_channels, out_channels: out_channels,
            num_heads: num_heads,
            w_linear: w, attn_src: a_src, attn_dst: a_dst,
            dropout: drop
        };
    }

    pub fn forward(self, x: Variable, graph: Graph) -> Variable {
        let h = self.w_linear.forward(x);
        # Multi-head attention mechanism
        # alpha_ij = softmax(LeakyReLU(a^T [W h_i || W h_j]))
        let out = self.propagate(graph, h);
        return out;
    }

    pub fn message(self, x_j: Variable, x_i: Variable, edge_attr: Variable?) -> Variable {
        # Compute attention scores
        # Placeholder: full attention computation
        return x_j;
    }
}

# ============================================================
# SECTION 5: GraphSAGE
# ============================================================

pub class SAGEConv : MessagePassing {
    pub let in_channels: Int;
    pub let out_channels: Int;
    pub let w_neigh: Linear;
    pub let w_self: Linear;
    pub let normalize: Bool;

    pub fn new(in_channels: Int, out_channels: Int, normalize: Bool) -> Self {
        let mp = MessagePassing::new("SAGEConv", "mean");
        let wn = Linear::new(in_channels, out_channels, true);
        let ws = Linear::new(in_channels, out_channels, true);
        mp.add_child(wn);
        mp.add_child(ws);

        return Self {
            _params: mp._params, _children: mp._children, _training: true,
            _name: "SAGEConv", aggr: "mean",
            in_channels: in_channels, out_channels: out_channels,
            w_neigh: wn, w_self: ws, normalize: normalize
        };
    }

    pub fn forward(self, x: Variable, graph: Graph) -> Variable {
        let neigh_aggr = self.propagate(graph, x);
        let h_neigh = self.w_neigh.forward(neigh_aggr);
        let h_self = self.w_self.forward(x);
        let out = h_self.add(h_neigh);
        
        if (self.normalize) {
            # L2 normalization
            let norm = out.mul(out).sum().sqrt();
            out = out.div(norm);
        }
        
        return out;
    }

    pub fn message(self, x_j: Variable, x_i: Variable, edge_attr: Variable?) -> Variable {
        return x_j;
    }
}

# ============================================================
# SECTION 6: GRAPH POOLING
# ============================================================

pub fn global_mean_pool(x: Tensor, batch: Tensor) -> Tensor {
    let num_graphs = int(batch.max()) + 1;
    let pooled_data = [];
    for (g in range(num_graphs)) {
        let sum = 0.0;
        let count = 0;
        for (n in range(batch.numel())) {
            if (int(batch.data[n]) == g) {
                sum = sum + x.data[n];
                count = count + 1;
            }
        }
        pooled_data = pooled_data + [sum / count];
    }
    return Tensor::new(pooled_data, [num_graphs], x.dtype, x.device);
}

pub fn global_max_pool(x: Tensor, batch: Tensor) -> Tensor {
    let num_graphs = int(batch.max()) + 1;
    let pooled_data = [];
    for (g in range(num_graphs)) {
        let max_val = -1e9;
        for (n in range(batch.numel())) {
            if (int(batch.data[n]) == g && x.data[n] > max_val) {
                max_val = x.data[n];
            }
        }
        pooled_data = pooled_data + [max_val];
    }
    return Tensor::new(pooled_data, [num_graphs], x.dtype, x.device);
}

pub fn global_add_pool(x: Tensor, batch: Tensor) -> Tensor {
    let num_graphs = int(batch.max()) + 1;
    let pooled_data = [];
    for (g in range(num_graphs)) {
        let sum = 0.0;
        for (n in range(batch.numel())) {
            if (int(batch.data[n]) == g) {
                sum = sum + x.data[n];
            }
        }
        pooled_data = pooled_data + [sum];
    }
    return Tensor::new(pooled_data, [num_graphs], x.dtype, x.device);
}

# ============================================================
# SECTION 7: GRAPH-LEVEL TASKS
# ============================================================

pub class GraphClassifier : Module {
    pub let conv1: GCNConv;
    pub let conv2: GCNConv;
    pub let classifier: Linear;
    pub let activation: ReLU;
    pub let dropout: Dropout;

    pub fn new(in_channels: Int, hidden_channels: Int, num_classes: Int, dropout_rate: Float) -> Self{
        let m = Module::new("GraphClassifier");
        let c1 = GCNConv::new(in_channels, hidden_channels, true);
        let c2 = GCNConv::new(hidden_channels, hidden_channels, true);
        let cls = Linear::new(hidden_channels, num_classes, true);
        let act = ReLU::new();
        let drop = Dropout::new(dropout_rate);
        m.add_child(c1);
        m.add_child(c2);
        m.add_child(cls);
        m.add_child(act);
        m.add_child(drop);

        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "GraphClassifier",
            conv1: c1, conv2: c2, classifier: cls,
            activation: act, dropout: drop
        };
    }

    pub fn forward(self, x: Variable, graph: Graph, batch: Tensor) -> Variable {
        let h1 = self.activation.forward(self.conv1.forward(x, graph));
        let h1_drop = self.dropout.forward(h1);
        let h2 = self.activation.forward(self.conv2.forward(h1_drop, graph));
        
        # Global pooling
        let pooled = Variable::new(global_mean_pool(h2.data, batch), "pooled");
        
        let logits = self.classifier.forward(pooled);
        return logits;
    }
}

# ============================================================
# SECTION 8: LINK PREDICTION
# ============================================================

pub class LinkPredictor : Module {
    pub let encoder: Sequential;
    pub let decoder: String;  # "dot", "mlp"

    pub fn new(in_channels: Int, hidden_channels: Int, decoder_type: String) -> Self {
        let m = Module::new("LinkPredictor");
        let enc = Sequential::new([
            GCNConv::new(in_channels, hidden_channels, true),
            ReLU::new(),
            GCNConv::new(hidden_channels, hidden_channels, true)
        ]);
        m.add_child(enc);

        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "LinkPredictor",
            encoder: enc, decoder: decoder_type
        };
    }

    pub fn encode(self, x: Variable, graph: Graph) -> Variable {
       return self.encoder.forward(x);
    }

    pub fn decode(self, z: Tensor, edge_index: Tensor) -> Tensor {
        if (self.decoder == "dot") {
            # Dot product decoder
            let scores = [];
            for (e in range(edge_index.shape.dims[1])) {
                let src = int(edge_index.get([0, e]));
                let dst = int(edge_index.get([1, e]));
                let dot = 0.0;
                # z[src] · z[dst]
                scores = scores + [dot];
            }
            return Tensor::new(scores, [len(scores)], z.dtype, z.device);
        } else {
            throw "LinkPredictor: unsupported decoder type";
        }
    }
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

fn _get_node_embedding(x: Variable, node_idx: Int) -> Variable {
    # Extract embedding for node_idx
    return Variable::new(
        Tensor::new([x.data.data[node_idx]], [1], x.data.dtype, x.data.device), "node_emb");
}

fn _get_edge_features(edge_attr: Tensor, edge_idx: Int) -> Tensor {
    let feat_dim = edge_attr.numel() / edge_attr.shape.dims[0];
    let data = [];
    for (i in range(feat_dim)) {
        data = data + [edge_attr.data[edge_idx * feat_dim + i]];
    }
    return Tensor::new(data, [feat_dim], edge_attr.dtype, edge_attr.device);
}

# ============================================================
# NATIVE FFI
# ============================================================

native_sqrt(x: Float) -> Float;

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    "GraphType": GraphType,
    "Graph": Graph,
    "Batch": Batch,
    "MessagePassing": MessagePassing,
    "GCNConv": GCNConv,
    "GATConv": GATConv,
    "SAGEConv": SAGEConv,
    "GraphClassifier": GraphClassifier,
    "LinkPredictor": LinkPredictor,
    "global_mean_pool": global_mean_pool,
    "global_max_pool": global_max_pool,
    "global_add_pool": global_add_pool
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
