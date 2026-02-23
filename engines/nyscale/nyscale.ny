// NyScale Engine - Distributed Training for Nyx ML
// Data/model/pipeline parallelism, fault tolerance, parameter servers, elastic scaling

import nytensor { Tensor, DType, Device }
import nygrad { Variable }
import nyaccel { AccelDevice }

// ── Distributed Enums ──────────────────────────────────────────────

pub enum ParallelStrategy {
    DataParallel,
    ModelParallel,
    PipelineParallel,
    Hybrid,
    ZeRO_Stage1,
    ZeRO_Stage2,
    ZeRO_Stage3
}

pub enum ReduceOp {
    Sum,
    Mean,
    Max,
    Min,
    Product
}

pub enum BackendType {
    NCCL,
    Gloo,
    MPI,
    Custom
}

pub enum WorkerStatus {
    Active,
    Idle,
    Failed,
    Recovering,
    Shutdown
}

// ── Distributed Context ────────────────────────────────────────────

pub class DistConfig {
    pub world_size: Int
    pub rank: Int
    pub local_rank: Int
    pub backend: BackendType
    pub master_addr: String
    pub master_port: Int
    pub init_method: String

    pub fn new(world_size: Int, rank: Int, backend: BackendType = BackendType.NCCL) -> Self {
        return Self {
            world_size: world_size,
            rank: rank,
            local_rank: rank,
            backend: backend,
            master_addr: "localhost",
            master_port: 29500,
            init_method: "env://"
        }
    }
}

pub class DistContext {
    pub config: DistConfig
    _initialized: Bool
    _comm_handle: Any?

    pub fn new(config: DistConfig) -> Self {
        return Self { config: config, _initialized: false, _comm_handle: nil }
    }

    pub fn init(mut self) -> Self {
        self._comm_handle = _init_process_group(
            self.config.backend,
            self.config.master_addr,
            self.config.master_port,
            self.config.world_size,
            self.config.rank
        )
        self._initialized = true
        return self
    }

    pub fn is_initialized(self) -> Bool {
        return self._initialized
    }

    pub fn rank(self) -> Int {
        return self.config.rank
    }

    pub fn world_size(self) -> Int {
        return self.config.world_size
    }

    pub fn is_master(self) -> Bool {
        return self.config.rank == 0
    }

    pub fn barrier(self) {
        assert(self._initialized, "DistContext not initialized")
        _barrier(self._comm_handle)
    }

    pub fn destroy(mut self) {
        if self._initialized {
            _destroy_process_group(self._comm_handle)
            self._initialized = false
        }
    }
}

// ── Collective Operations ──────────────────────────────────────────

pub class CollectiveOps {
    _ctx: DistContext

    pub fn new(ctx: DistContext) -> Self {
        return Self { _ctx: ctx }
    }

    pub fn all_reduce(self, tensor: Tensor, op: ReduceOp = ReduceOp.Sum) -> Tensor {
        return _all_reduce(self._ctx._comm_handle, tensor, op)
    }

    pub fn all_gather(self, tensor: Tensor) -> List[Tensor] {
        return _all_gather(self._ctx._comm_handle, tensor, self._ctx.config.world_size)
    }

    pub fn reduce_scatter(self, tensor: Tensor, op: ReduceOp = ReduceOp.Sum) -> Tensor {
        return _reduce_scatter(self._ctx._comm_handle, tensor, op, self._ctx.config.world_size)
    }

    pub fn broadcast(self, tensor: Tensor, src: Int = 0) -> Tensor {
        return _broadcast(self._ctx._comm_handle, tensor, src)
    }

    pub fn scatter(self, tensor: Tensor, src: Int = 0) -> Tensor {
        return _scatter(self._ctx._comm_handle, tensor, src, self._ctx.config.world_size)
    }

    pub fn gather(self, tensor: Tensor, dst: Int = 0) -> Tensor? {
        return _gather(self._ctx._comm_handle, tensor, dst)
    }

    pub fn send(self, tensor: Tensor, dst: Int) {
        _send(self._ctx._comm_handle, tensor, dst)
    }

    pub fn recv(self, src: Int, shape: List[Int], dtype: DType = DType.Float32) -> Tensor {
        return _recv(self._ctx._comm_handle, src, shape, dtype)
    }
}

// ── Data Parallel ──────────────────────────────────────────────────

pub class DataParallelWrapper {
    pub model: Any
    pub ctx: DistContext
    pub sync_every: Int
    _ops: CollectiveOps
    _step_count: Int

    pub fn new(model: Any, ctx: DistContext, sync_every: Int = 1) -> Self {
        let ops = CollectiveOps.new(ctx)
        _broadcast_parameters(model, ops)
        return Self {
            model: model,
            ctx: ctx,
            sync_every: sync_every,
            _ops: ops,
            _step_count: 0
        }
    }

    pub fn forward(self, input: Tensor) -> Tensor {
        return self.model.forward(input)
    }

    pub fn sync_gradients(mut self) {
        self._step_count = self._step_count + 1
        if self._step_count % self.sync_every != 0 { return }

        let params = self.model.parameters()
        for param in params {
            if param.grad != nil {
                let avg_grad = self._ops.all_reduce(param.grad, ReduceOp.Sum)
                param.grad = avg_grad / self.ctx.world_size().to_float()
            }
        }
    }
}

fn _broadcast_parameters(model: Any, ops: CollectiveOps) {
    let params = model.parameters()
    for param in params {
        let synced = ops.broadcast(param.data, src: 0)
        param.data = synced
    }
}

// ── Model Parallel ─────────────────────────────────────────────────

pub class ModelParallelWrapper {
    pub layers_by_device: Map[Int, List[Any]]
    pub ctx: DistContext
    _ops: CollectiveOps

    pub fn new(ctx: DistContext) -> Self {
        return Self {
            layers_by_device: {},
            ctx: ctx,
            _ops: CollectiveOps.new(ctx)
        }
    }

    pub fn assign(mut self, device_rank: Int, layers: List[Any]) -> Self {
        self.layers_by_device[device_rank] = layers
        return self
    }

    pub fn forward(self, input: Tensor) -> Tensor {
        let current = input
        for rank in range(self.ctx.world_size()) {
            if rank == self.ctx.rank() {
                let layers = self.layers_by_device.get(rank)
                if layers != nil {
                    for layer in layers {
                        current = layer.forward(current)
                    }
                }
                if rank < self.ctx.world_size() - 1 {
                    self._ops.send(current, rank + 1)
                }
            } else if rank == self.ctx.rank() - 1 {
                current = self._ops.recv(rank, current.shape())
            }
        }
        return current
    }
}

// ── Pipeline Parallel ──────────────────────────────────────────────

pub class PipelineStage {
    pub stage_id: Int
    pub layers: List[Any]
    pub device: Device

    pub fn new(stage_id: Int, layers: List[Any], device: Device) -> Self {
        return Self { stage_id: stage_id, layers: layers, device: device }
    }

    pub fn forward(self, input: Tensor) -> Tensor {
        let x = input.to(self.device)
        for layer in self.layers {
            x = layer.forward(x)
        }
        return x
    }
}

pub class PipelineParallelWrapper {
    pub stages: List[PipelineStage]
    pub num_microbatches: Int
    pub ctx: DistContext
    _ops: CollectiveOps

    pub fn new(ctx: DistContext, num_microbatches: Int = 4) -> Self {
        return Self {
            stages: [],
            num_microbatches: num_microbatches,
            ctx: ctx,
            _ops: CollectiveOps.new(ctx)
        }
    }

    pub fn add_stage(mut self, stage: PipelineStage) -> Self {
        self.stages.append(stage)
        return self
    }

    pub fn forward(self, input: Tensor) -> Tensor {
        let micro_size = input.shape()[0] / self.num_microbatches
        let outputs = []

        for mb in range(self.num_microbatches) {
            let start = mb * micro_size
            let end = min((mb + 1) * micro_size, input.shape()[0])
            let micro_input = input[start:end]

            let current = micro_input
            for stage in self.stages {
                if stage.stage_id == self.ctx.rank() {
                    current = stage.forward(current)
                    if stage.stage_id < self.stages.len() - 1 {
                        self._ops.send(current, stage.stage_id + 1)
                    }
                } else if stage.stage_id == self.ctx.rank() && stage.stage_id > 0 {
                    current = self._ops.recv(stage.stage_id - 1, current.shape())
                    current = stage.forward(current)
                }
            }
            outputs.append(current)
        }

        return Tensor.cat(outputs, dim: 0)
    }
}

// ── ZeRO Optimizer ─────────────────────────────────────────────────

pub class ZeROOptimizer {
    pub optimizer: Any
    pub stage: Int
    pub ctx: DistContext
    _ops: CollectiveOps
    _param_partitions: Map[Int, List[Any]]
    _grad_partitions: Map[Int, List[Tensor]]
    _state_partitions: Map[Int, Map[String, Any]]

    pub fn new(optimizer: Any, stage: Int, ctx: DistContext) -> Self {
        let zero = Self {
            optimizer: optimizer,
            stage: stage,
            ctx: ctx,
            _ops: CollectiveOps.new(ctx),
            _param_partitions: {},
            _grad_partitions: {},
            _state_partitions: {}
        }
        zero._partition()
        return zero
    }

    fn _partition(mut self) {
        let params = self.optimizer.parameters()
        let per_rank = (params.len() + self.ctx.world_size() - 1) / self.ctx.world_size()
        for rank in range(self.ctx.world_size()) {
            let start = rank * per_rank
            let end = min((rank + 1) * per_rank, params.len())
            self._param_partitions[rank] = params[start:end]
        }
    }

    pub fn step(mut self) {
        match self.stage {
            1 => self._step_stage1(),
            2 => self._step_stage2(),
            3 => self._step_stage3(),
            _ => self._step_stage1()
        }
    }

    fn _step_stage1(mut self) {
        // Stage 1: Partition optimizer states
        let my_params = self._param_partitions[self.ctx.rank()]
        self.optimizer.step_subset(my_params)
        // All-gather updated parameters
        for param in self.optimizer.parameters() {
            param.data = self._ops.all_reduce(param.data, ReduceOp.Sum)
        }
    }

    fn _step_stage2(mut self) {
        // Stage 2: Partition optimizer states + gradients
        let all_params = self.optimizer.parameters()
        for param in all_params {
            if param.grad != nil {
                param.grad = self._ops.reduce_scatter(param.grad, ReduceOp.Sum)
            }
        }
        let my_params = self._param_partitions[self.ctx.rank()]
        self.optimizer.step_subset(my_params)
        for param in all_params {
            param.data = self._ops.all_reduce(param.data, ReduceOp.Sum)
        }
    }

    fn _step_stage3(mut self) {
        // Stage 3: Partition everything
        let all_params = self.optimizer.parameters()
        for param in all_params {
            if param.grad != nil {
                param.grad = self._ops.reduce_scatter(param.grad, ReduceOp.Sum)
            }
        }
        let my_params = self._param_partitions[self.ctx.rank()]
        self.optimizer.step_subset(my_params)
        // All-gather reconstructed parameters
        let gathered = self._ops.all_gather(Tensor.cat(my_params.map(fn(p) { return p.data.flatten() })))
        let offset = 0
        for param in all_params {
            let size = param.data.numel()
            param.data = gathered[offset:offset + size].reshape(param.data.shape())
            offset = offset + size
        }
    }

    pub fn zero_grad(self) {
        self.optimizer.zero_grad()
    }
}

// ── Gradient Compression ───────────────────────────────────────────

pub class GradientCompressor {
    pub compression_ratio: Float
    pub method: String
    _error_feedback: Map[String, Tensor]

    pub fn new(compression_ratio: Float = 0.01, method: String = "topk") -> Self {
        return Self { compression_ratio: compression_ratio, method: method, _error_feedback: {} }
    }

    pub fn compress(mut self, name: String, gradient: Tensor) -> (Tensor, Tensor) {
        let grad = gradient
        if self._error_feedback.contains(name) {
            grad = grad + self._error_feedback[name]
        }

        match self.method {
            "topk" => {
                let k = max(1, (grad.numel().to_float() * self.compression_ratio).to_int())
                let (values, indices) = grad.flatten().abs().topk(k)
                let mask = Tensor.zeros(grad.shape()).flatten()
                mask[indices] = 1.0
                let compressed = grad.flatten() * mask
                self._error_feedback[name] = grad - compressed.reshape(grad.shape())
                return (compressed.reshape(grad.shape()), mask.reshape(grad.shape()))
            },
            "random" => {
                let mask = Tensor.rand(grad.shape()) < self.compression_ratio
                let compressed = grad * mask.to_float()
                self._error_feedback[name] = grad - compressed
                return (compressed, mask.to_float())
            },
            _ => {
                return (grad, Tensor.ones(grad.shape()))
            }
        }
    }

    pub fn decompress(self, compressed: Tensor, mask: Tensor) -> Tensor {
        return compressed
    }
}

// ── Elastic Scaling ────────────────────────────────────────────────

pub class ElasticConfig {
    pub min_workers: Int
    pub max_workers: Int
    pub scale_up_threshold: Float
    pub scale_down_threshold: Float
    pub cooldown_seconds: Int
    pub health_check_interval: Int

    pub fn new(min_workers: Int = 1, max_workers: Int = 8) -> Self {
        return Self {
            min_workers: min_workers,
            max_workers: max_workers,
            scale_up_threshold: 0.8,
            scale_down_threshold: 0.3,
            cooldown_seconds: 300,
            health_check_interval: 30
        }
    }
}

pub class ElasticManager {
    pub config: ElasticConfig
    pub ctx: DistContext
    _worker_status: Map[Int, WorkerStatus]
    _last_scale_time: Int

    pub fn new(config: ElasticConfig, ctx: DistContext) -> Self {
        let status = {}
        for i in range(ctx.world_size()) {
            status[i] = WorkerStatus.Active
        }
        return Self {
            config: config,
            ctx: ctx,
            _worker_status: status,
            _last_scale_time: time_now_ms()
        }
    }

    pub fn check_health(mut self) -> Map[Int, WorkerStatus] {
        for rank in range(self.ctx.world_size()) {
            let alive = _ping_worker(rank, self.ctx._comm_handle)
            if !alive {
                self._worker_status[rank] = WorkerStatus.Failed
            }
        }
        return self._worker_status
    }

    pub fn handle_failure(mut self, failed_rank: Int) {
        self._worker_status[failed_rank] = WorkerStatus.Recovering
        let active = self._active_count()
        if active < self.config.min_workers {
            self._spawn_replacement(failed_rank)
        }
        self._redistribute_work(active)
    }

    pub fn should_scale_up(self, utilization: Float) -> Bool {
        let elapsed = time_now_ms() - self._last_scale_time
        if elapsed < self.config.cooldown_seconds * 1000 { return false }
        return utilization > self.config.scale_up_threshold && self._active_count() < self.config.max_workers
    }

    pub fn should_scale_down(self, utilization: Float) -> Bool {
        let elapsed = time_now_ms() - self._last_scale_time
        if elapsed < self.config.cooldown_seconds * 1000 { return false }
        return utilization < self.config.scale_down_threshold && self._active_count() > self.config.min_workers
    }

    pub fn scale_up(mut self, count: Int = 1) {
        let new_size = min(self._active_count() + count, self.config.max_workers)
        for i in range(self._active_count(), new_size) {
            _spawn_worker(i, self.ctx._comm_handle)
            self._worker_status[i] = WorkerStatus.Active
        }
        self._last_scale_time = time_now_ms()
    }

    pub fn scale_down(mut self, count: Int = 1) {
        let target = max(self._active_count() - count, self.config.min_workers)
        let active_ranks = self._active_ranks()
        for i in range(target, active_ranks.len()) {
            let rank = active_ranks[i]
            _shutdown_worker(rank, self.ctx._comm_handle)
            self._worker_status[rank] = WorkerStatus.Shutdown
        }
        self._last_scale_time = time_now_ms()
    }

    fn _active_count(self) -> Int {
        let count = 0
        for (_, status) in self._worker_status {
            if status == WorkerStatus.Active { count = count + 1 }
        }
        return count
    }

    fn _active_ranks(self) -> List[Int] {
        let ranks = []
        for (rank, status) in self._worker_status {
            if status == WorkerStatus.Active { ranks.append(rank) }
        }
        return ranks.sort()
    }

    fn _spawn_replacement(mut self, rank: Int) {
        _spawn_worker(rank, self.ctx._comm_handle)
        self._worker_status[rank] = WorkerStatus.Active
    }

    fn _redistribute_work(self, active_count: Int) {
        // Rebalance data shards across active workers
        let ops = CollectiveOps.new(self.ctx)
        ops.broadcast(Tensor.from_list([active_count.to_float()]), src: 0)
    }
}

// ── Distributed Training Loop ──────────────────────────────────────

pub class DistributedTrainer {
    pub model: Any
    pub optimizer: Any
    pub loss_fn: Any
    pub ctx: DistContext
    pub strategy: ParallelStrategy
    _dp_wrapper: DataParallelWrapper?
    _zero_optimizer: ZeROOptimizer?
    _compressor: GradientCompressor?

    pub fn new(
        model: Any,
        optimizer: Any,
        loss_fn: Any,
        ctx: DistContext,
        strategy: ParallelStrategy = ParallelStrategy.DataParallel
    ) -> Self {
        let trainer = Self {
            model: model,
            optimizer: optimizer,
            loss_fn: loss_fn,
            ctx: ctx,
            strategy: strategy,
            _dp_wrapper: nil,
            _zero_optimizer: nil,
            _compressor: nil
        }
        trainer._setup()
        return trainer
    }

    fn _setup(mut self) {
        match self.strategy {
            ParallelStrategy.DataParallel => {
                self._dp_wrapper = DataParallelWrapper.new(self.model, self.ctx)
            },
            ParallelStrategy.ZeRO_Stage1 => {
                self._dp_wrapper = DataParallelWrapper.new(self.model, self.ctx)
                self._zero_optimizer = ZeROOptimizer.new(self.optimizer, 1, self.ctx)
            },
            ParallelStrategy.ZeRO_Stage2 => {
                self._dp_wrapper = DataParallelWrapper.new(self.model, self.ctx)
                self._zero_optimizer = ZeROOptimizer.new(self.optimizer, 2, self.ctx)
            },
            ParallelStrategy.ZeRO_Stage3 => {
                self._zero_optimizer = ZeROOptimizer.new(self.optimizer, 3, self.ctx)
            },
            _ => {}
        }
    }

    pub fn with_compression(mut self, ratio: Float = 0.01) -> Self {
        self._compressor = GradientCompressor.new(compression_ratio: ratio)
        return self
    }

    pub fn train_step(mut self, batch_features: Tensor, batch_labels: Tensor) -> Float {
        self.optimizer.zero_grad()

        let output = if self._dp_wrapper != nil {
            self._dp_wrapper.forward(batch_features)
        } else {
            self.model.forward(batch_features)
        }

        let loss = self.loss_fn.forward(output, batch_labels)
        loss.backward()

        if self._compressor != nil {
            let params = self.model.parameters()
            for i in range(params.len()) {
                if params[i].grad != nil {
                    let (compressed, mask) = self._compressor.compress("p" + i.to_string(), params[i].grad)
                    params[i].grad = compressed
                }
            }
        }

        if self._dp_wrapper != nil {
            self._dp_wrapper.sync_gradients()
        }

        if self._zero_optimizer != nil {
            self._zero_optimizer.step()
        } else {
            self.optimizer.step()
        }

        return loss.item()
    }
}

// ── Convenience Launchers ──────────────────────────────────────────

pub fn launch_distributed(world_size: Int, fn_per_rank: Fn(DistContext) -> Void, backend: BackendType = BackendType.NCCL) {
    for rank in range(world_size) {
        let config = DistConfig.new(world_size, rank, backend)
        let ctx = DistContext.new(config).init()
        spawn { fn_per_rank(ctx) }
    }
}

pub fn init_dist(world_size: Int, rank: Int, backend: BackendType = BackendType.NCCL) -> DistContext {
    let config = DistConfig.new(world_size, rank, backend)
    return DistContext.new(config).init()
}

export {
    ParallelStrategy, ReduceOp, BackendType, WorkerStatus,
    DistConfig, DistContext, CollectiveOps,
    DataParallelWrapper, ModelParallelWrapper,
    PipelineStage, PipelineParallelWrapper,
    ZeROOptimizer, GradientCompressor,
    ElasticConfig, ElasticManager,
    DistributedTrainer,
    launch_distributed, init_dist
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
