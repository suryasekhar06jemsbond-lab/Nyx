# ============================================================
# NyGrad - Automatic Differentiation Engine
# Version 1.0.0
# Enables training via backpropagation
# ============================================================

use nytensor;

# ============================================================
# SECTION 1: COMPUTATIONAL GRAPH NODES
# ============================================================

pub enum OpType {
    Add,
    Sub,
    Mul,
    Div,
    MatMul,
    Pow,
    Exp,
    Log,
    Sqrt,
    Neg,
    Sum,
    Mean,
    Relu,
    Sigmoid,
    Tanh,
    Softmax,
    Reshape,
    Transpose,
    Slice,
    Cat,
    Conv2d,
    MaxPool,
    BatchNorm,
    Dropout,
    Embedding,
    CrossEntropy,
    MSE,
    Custom,
    Leaf
}

pub class GradNode {
    pub let id: Int;
    pub let op: OpType;
    pub let inputs: [GradNode?];
    pub let tensor: Tensor;
    pub let grad: Tensor?;
    pub let requires_grad: Bool;
    pub let _backward_fn: fn?;
    pub let _name: String;
    pub let _checkpointed: Bool;

    pub fn new(tensor: Tensor, op: OpType, inputs: [GradNode?], name: String) -> Self {
        return Self {
            id: native_next_id(),
            op: op,
            inputs: inputs,
            tensor: tensor,
            grad: null,
            requires_grad: true,
            _backward_fn: null,
            _name: name,
            _checkpointed: false
        };
    }

    pub fn leaf(tensor: Tensor, name: String) -> GradNode {
        let node = GradNode::new(tensor, OpType::Leaf, [], name);
        node.requires_grad = tensor.requires_grad;
        return node;
    }

    pub fn accumulate_grad(self, grad: Tensor) {
        if (self.grad == null) {
            self.grad = grad;
        } else {
            self.grad = self.grad.add(grad);
        }
    }

    pub fn zero_grad(self) {
        self.grad = null;
    }
}

# ============================================================
# SECTION 2: TAPE RECORDER (OPERATION RECORDING)
# ============================================================

pub class Tape {
    pub let operations: [GradNode];
    pub let recording: Bool;
    pub let _node_counter: Int;

    pub fn new() -> Self {
        return Self { operations: [], recording: true, _node_counter: 0 };
    }

    pub fn record(self, node: GradNode) {
        if (self.recording) {
            self.operations = self.operations + [node];
            self._node_counter = self._node_counter + 1;
        }
    }

    pub fn pause(self) { self.recording = false; }
    pub fn resume(self) { self.recording = true; }

    pub fn clear(self) {
        self.operations = [];
        self._node_counter = 0;
    }

    pub fn size(self) -> Int {
        return len(self.operations);
    }
}

# Global tape
let _global_tape = Tape::new();

pub fn get_tape() -> Tape {
    return _global_tape;
}

pub fn reset_tape() {
    _global_tape = Tape::new();
}

# ============================================================
# SECTION 3: AUTOGRAD VARIABLE (TRACKED TENSOR)
# ============================================================

pub class Variable {
    pub let node: GradNode;
    pub let data: Tensor;

    pub fn new(tensor: Tensor, name: String) -> Self {
        let node = GradNode::leaf(tensor.with_grad(), name);
        _global_tape.record(node);
        return Self { node: node, data: tensor };
    }

    pub fn from_node(tensor: Tensor, node: GradNode) -> Self {
        return Self { node: node, data: tensor };
    }

    pub fn grad(self) -> Tensor? {
        return self.node.grad;
    }

    pub fn zero_grad(self) {
        self.node.zero_grad();
    }

    pub fn detach(self) -> Tensor {
        return self.data.detach();
    }

    pub fn shape(self) -> [Int] {
        return self.data.shape.dims;
    }

    # ----- Tracked Arithmetic Operations -----

    pub fn add(self, other: Variable) -> Variable {
        let result = self.data.add(other.data);
        let node = GradNode::new(result, OpType::Add, [self.node, other.node], "add");
        node._backward_fn = fn(grad: Tensor) {
            self.node.accumulate_grad(grad);
            other.node.accumulate_grad(grad);
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn sub(self, other: Variable) -> Variable {
        let result = self.data.sub(other.data);
        let node = GradNode::new(result, OpType::Sub, [self.node, other.node], "sub");
        node._backward_fn = fn(grad: Tensor) {
            self.node.accumulate_grad(grad);
            other.node.accumulate_grad(grad.neg());
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn mul(self, other: Variable) -> Variable {
        let result = self.data.mul(other.data);
        let node = GradNode::new(result, OpType::Mul, [self.node, other.node], "mul");
        node._backward_fn = fn(grad: Tensor) {
            self.node.accumulate_grad(grad.mul(other.data));
            other.node.accumulate_grad(grad.mul(self.data));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn div(self, other: Variable) -> Variable {
        let result = self.data.div(other.data);
        let node = GradNode::new(result, OpType::Div, [self.node, other.node], "div");
        node._backward_fn = fn(grad: Tensor) {
            self.node.accumulate_grad(grad.div(other.data));
            let neg_a_over_b2 = self.data.neg().div(other.data.mul(other.data));
            other.node.accumulate_grad(grad.mul(neg_a_over_b2));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn matmul(self, other: Variable) -> Variable {
        let result = linalg::matmul(self.data, other.data);
        let node = GradNode::new(result, OpType::MatMul, [self.node, other.node], "matmul");
        node._backward_fn = fn(grad: Tensor) {
            self.node.accumulate_grad(linalg::matmul(grad, other.data.transpose()));
            other.node.accumulate_grad(linalg::matmul(self.data.transpose(), grad));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn pow(self, exponent: Float) -> Variable {
        let result = self.data.pow(exponent);
        let node = GradNode::new(result, OpType::Pow, [self.node], "pow");
        node._backward_fn = fn(grad: Tensor) {
            let local_grad = self.data.pow(exponent - 1.0).scale(exponent);
            self.node.accumulate_grad(grad.mul(local_grad));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn exp(self) -> Variable {
        let result = self.data.exp();
        let node = GradNode::new(result, OpType::Exp, [self.node], "exp");
        node._backward_fn = fn(grad: Tensor) {
            self.node.accumulate_grad(grad.mul(result));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn log(self) -> Variable {
        let result = self.data.log();
        let node = GradNode::new(result, OpType::Log, [self.node], "log");
        node._backward_fn = fn(grad: Tensor) {
            let inv = Tensor::ones(self.data.shape.dims, self.data.dtype, self.data.device).div(self.data);
            self.node.accumulate_grad(grad.mul(inv));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn sqrt(self) -> Variable {
        let result = self.data.sqrt();
        let node = GradNode::new(result, OpType::Sqrt, [self.node], "sqrt");
        node._backward_fn = fn(grad: Tensor) {
            let inv_2sqrt = result.scale(2.0);
            let local_grad = Tensor::ones(result.shape.dims, result.dtype, result.device).div(inv_2sqrt);
            self.node.accumulate_grad(grad.mul(local_grad));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn neg(self) -> Variable {
        let result = self.data.neg();
        let node = GradNode::new(result, OpType::Neg, [self.node], "neg");
        node._backward_fn = fn(grad: Tensor) {
            self.node.accumulate_grad(grad.neg());
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    # ----- Tracked Activation Functions -----

    pub fn relu(self) -> Variable {
        let result = self.data.relu();
        let node = GradNode::new(result, OpType::Relu, [self.node], "relu");
        node._backward_fn = fn(grad: Tensor) {
            let mask_data = [];
            for (v in self.data.data) {
                mask_data = mask_data + [v > 0.0 ? 1.0 : 0.0];
            }
            let mask = Tensor::new(mask_data, self.data.shape.dims, self.data.dtype, self.data.device);
            self.node.accumulate_grad(grad.mul(mask));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn sigmoid(self) -> Variable {
        let result = self.data.sigmoid();
        let node = GradNode::new(result, OpType::Sigmoid, [self.node], "sigmoid");
        node._backward_fn = fn(grad: Tensor) {
            let one_minus = Tensor::ones(result.shape.dims, result.dtype, result.device).sub(result);
            let local_grad = result.mul(one_minus);
            self.node.accumulate_grad(grad.mul(local_grad));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn tanh_act(self) -> Variable {
        let result = self.data.tanh();
        let node = GradNode::new(result, OpType::Tanh, [self.node], "tanh");
        node._backward_fn = fn(grad: Tensor) {
            let sq = result.mul(result);
            let local_grad = Tensor::ones(result.shape.dims, result.dtype, result.device).sub(sq);
            self.node.accumulate_grad(grad.mul(local_grad));
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn softmax(self) -> Variable {
        let max_val = self.data.max();
        let shifted = self.data.add_scalar(-max_val);
        let e = shifted.exp();
        let s = e.sum();
        let result = e.scale(1.0 / s);
        let node = GradNode::new(result, OpType::Softmax, [self.node], "softmax");
        node._backward_fn = fn(grad: Tensor) {
            let ds = grad.mul(result);
            let sum_ds = ds.sum();
            let data = [];
            for (i in range(result.numel())) {
                data = data + [result.data[i] * (grad.data[i] - sum_ds)];
            }
            let local_grad = Tensor::new(data, result.shape.dims, result.dtype, result.device);
            self.node.accumulate_grad(local_grad);
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    # ----- Tracked Reductions -----

    pub fn sum(self) -> Variable {
        let val = self.data.sum();
        let result = Tensor::new([val], [1], self.data.dtype, self.data.device);
        let node = GradNode::new(result, OpType::Sum, [self.node], "sum");
        node._backward_fn = fn(grad: Tensor) {
            let expanded = Tensor::full(self.data.shape.dims, grad.data[0], self.data.dtype, self.data.device);
            self.node.accumulate_grad(expanded);
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }

    pub fn mean(self) -> Variable {
        let val = self.data.mean();
        let result = Tensor::new([val], [1], self.data.dtype, self.data.device);
        let node = GradNode::new(result, OpType::Mean, [self.node], "mean");
        node._backward_fn = fn(grad: Tensor) {
            let scale = 1.0 / self.data.numel();
            let expanded = Tensor::full(self.data.shape.dims, grad.data[0] * scale, self.data.dtype, self.data.device);
            self.node.accumulate_grad(expanded);
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }
}

# ============================================================
# SECTION 4: BACKWARD PASS ENGINE
# ============================================================

pub fn backward(output: Variable, retain_graph: Bool) {
    let tape = get_tape();
    let ops = tape.operations;

    # Seed gradient with ones
    if (output.node.grad == null) {
        output.node.grad = Tensor::ones(output.data.shape.dims, output.data.dtype, output.data.device);
    }

    # Reverse topological traversal
    for (i in range(len(ops) - 1, -1, -1)) {
        let node = ops[i];
        if (node.grad == null) {
            continue;
        }
        if (node._backward_fn != null) {
            node._backward_fn(node.grad);
        }
    }

    if (!retain_graph) {
        reset_tape();
    }
}

pub fn grad(output: Variable, inputs: [Variable], retain_graph: Bool) -> [Tensor] {
    backward(output, retain_graph);
    let grads = [];
    for (inp in inputs) {
        if (inp.node.grad != null) {
            grads = grads + [inp.node.grad];
        } else {
            grads = grads + [Tensor::zeros(inp.data.shape.dims, inp.data.dtype, inp.data.device)];
        }
    }
    return grads;
}

# ============================================================
# SECTION 5: GRADIENT CHECKPOINTING
# ============================================================

pub class CheckpointSegment {
    pub let fn_to_run: fn;
    pub let inputs: [Variable];

    pub fn new(func: fn, inputs: [Variable]) -> Self {
        return Self { fn_to_run: func, inputs: inputs };
    }

    pub fn forward(self) -> Variable {
        # Run forward without recording
        let tape = get_tape();
        tape.pause();
        let result = self.fn_to_run(self.inputs);
        tape.resume();

        # Mark as checkpointed
        let node = GradNode::new(result.data, OpType::Custom, [], "checkpoint");
        node._checkpointed = true;
        node._backward_fn = fn(grad: Tensor) {
            # Recompute forward to get gradients
            reset_tape();
            let recomputed = self.fn_to_run(self.inputs);
            backward(recomputed, false);
        };
        tape.record(node);
        return Variable::from_node(result.data, node);
    }
}

pub fn checkpoint(func: fn, inputs: [Variable]) -> Variable {
    let segment = CheckpointSegment::new(func, inputs);
    return segment.forward();
}

# ============================================================
# SECTION 6: STATIC GRAPH COMPILATION
# ============================================================

pub class StaticGraph {
    pub let nodes: [GradNode];
    pub let compiled: Bool;
    pub let _execution_order: [Int];

    pub fn new() -> Self {
        return Self { nodes: [], compiled: false, _execution_order: [] };
    }

    pub fn trace(self, func: fn, sample_inputs: [Variable]) -> Self {
        reset_tape();
        let output = func(sample_inputs);
        let tape = get_tape();
        self.nodes = tape.operations;
        self._compile();
        return self;
    }

    pub fn _compile(self) {
        # Topological sort for optimal execution order
        let visited = {};
        let order = [];
        for (i in range(len(self.nodes))) {
            if (!has(visited, str(i))) {
                self._topo_visit(i, visited, order);
            }
        }
        self._execution_order = order;
        self.compiled = true;
    }

    pub fn _topo_visit(self, idx: Int, visited: Object, order: [Int]) {
        visited[str(idx)] = true;
        let node = self.nodes[idx];
        for (inp in node.inputs) {
            if (inp != null) {
                for (j in range(len(self.nodes))) {
                    if (self.nodes[j].id == inp.id && !has(visited, str(j))) {
                        self._topo_visit(j, visited, order);
                    }
                }
            }
        }
        order = order + [idx];
    }

    pub fn execute(self, inputs: [Variable]) -> Variable {
        if (!self.compiled) {
            throw "StaticGraph: not compiled, call trace() first";
        }
        # Execute operations in compiled order
        let tape = get_tape();
        for (idx in self._execution_order) {
            let node = self.nodes[idx];
            if (node._backward_fn != null) {
                tape.record(node);
            }
        }
        return Variable::from_node(self.nodes[len(self.nodes) - 1].tensor,
                                    self.nodes[len(self.nodes) - 1]);
    }
}

# ============================================================
# SECTION 7: HIGHER-ORDER GRADIENTS
# ============================================================

pub fn grad_of_grad(func: fn, x: Variable) -> Tensor {
    # Compute second-order gradient (Hessian diagonal)
    reset_tape();
    let y = func(x);
    backward(y, true);
    let first_grad = x.node.grad;
    if (first_grad == null) {
        throw "grad_of_grad: first gradient is null";
    }

    # Wrap first gradient as variable and differentiate again
    let grad_var = Variable::new(first_grad, "first_grad");
    reset_tape();
    let grad_sum = grad_var.sum();
    backward(grad_sum, false);
    let second_grad = grad_var.node.grad;
    if (second_grad == null) {
        return Tensor::zeros(x.data.shape.dims, x.data.dtype, x.data.device);
    }
    return second_grad;
}

pub fn jacobian(func: fn, x: Variable) -> Tensor {
    let n = x.data.numel();
    let rows = [];
    for (i in range(n)) {
        reset_tape();
        let y = func(x);
        let grad_mask = Tensor::zeros(y.data.shape.dims, y.data.dtype, y.data.device);
        grad_mask.data[i] = 1.0;
        y.node.grad = grad_mask;
        backward(y, false);
        let g = x.node.grad ?? Tensor::zeros(x.data.shape.dims, x.data.dtype, x.data.device);
        for (v in g.data) {
            rows = rows + [v];
        }
    }
    let m = len(rows) / n;
    return Tensor::new(rows, [n, m], x.data.dtype, x.data.device);
}

# ============================================================
# SECTION 8: CUSTOM GRADIENT DEFINITIONS
# ============================================================

pub class CustomFunction {
    pub let forward_fn: fn;
    pub let backward_fn: fn;
    pub let _name: String;

    pub fn new(name: String, forward_fn: fn, backward_fn: fn) -> Self {
        return Self {
            forward_fn: forward_fn,
            backward_fn: backward_fn,
            _name: name
        };
    }

    pub fn apply(self, inputs: [Variable]) -> Variable {
        let result = self.forward_fn(inputs);
        let input_nodes = [];
        for (inp in inputs) {
            input_nodes = input_nodes + [inp.node];
        }
        let node = GradNode::new(result, OpType::Custom, input_nodes, self._name);
        let bfn = self.backward_fn;
        node._backward_fn = fn(grad: Tensor) {
            let grads = bfn(grad, inputs);
            for (i in range(len(inputs))) {
                if (i < len(grads)) {
                    inputs[i].node.accumulate_grad(grads[i]);
                }
            }
        };
        _global_tape.record(node);
        return Variable::from_node(result, node);
    }
}

# ============================================================
# SECTION 9: GRADIENT ACCUMULATOR
# ============================================================

pub class GradAccumulator {
    pub let accumulation_steps: Int;
    pub let current_step: Int;
    pub let _stored_grads: [Object];

    pub fn new(steps: Int) -> Self {
        return Self {
            accumulation_steps: steps,
            current_step: 0,
            _stored_grads: []
        };
    }

    pub fn accumulate(self, params: [Variable]) {
        self.current_step = self.current_step + 1;
        if (len(self._stored_grads) == 0) {
            for (p in params) {
                self._stored_grads = self._stored_grads + [{"grad": p.node.grad}];
            }
        } else {
            for (i in range(len(params))) {
                let g = params[i].node.grad;
                if (g != null && self._stored_grads[i]["grad"] != null) {
                    self._stored_grads[i]["grad"] = self._stored_grads[i]["grad"].add(g);
                }
            }
        }
    }

    pub fn should_step(self) -> Bool {
        return self.current_step >= self.accumulation_steps;
    }

    pub fn get_averaged_grads(self) -> [Tensor] {
        let grads = [];
        for (sg in self._stored_grads) {
            if (sg["grad"] != null) {
                grads = grads + [sg["grad"].scale(1.0 / self.accumulation_steps)];
            } else {
                grads = grads + [null];
            }
        }
        return grads;
    }

    pub fn reset(self) {
        self.current_step = 0;
        self._stored_grads = [];
    }
}

# ============================================================
# SECTION 10: NO-GRAD CONTEXT
# ============================================================

pub fn no_grad(func: fn) {
    let tape = get_tape();
    tape.pause();
    func();
    tape.resume();
}

pub fn is_grad_enabled() -> Bool {
    return get_tape().recording;
}

# ============================================================
# NATIVE FFI
# ============================================================

native_next_id() -> Int;

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    "Variable": Variable,
    "GradNode": GradNode,
    "Tape": Tape,
    "StaticGraph": StaticGraph,
    "CheckpointSegment": CheckpointSegment,
    "CustomFunction": CustomFunction,
    "GradAccumulator": GradAccumulator,
    "OpType": OpType,
    "backward": backward,
    "grad": grad,
    "grad_of_grad": grad_of_grad,
    "jacobian": jacobian,
    "checkpoint": checkpoint,
    "no_grad": no_grad,
    "is_grad_enabled": is_grad_enabled,
    "get_tape": get_tape,
    "reset_tape": reset_tape
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
