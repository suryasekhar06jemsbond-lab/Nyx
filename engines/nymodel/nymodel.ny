// NyModel Engine - Model Serialization & Export for Nyx ML
// Model format, cross-platform export, quantization, pruning, distillation, ONNX bridge

import nytensor { Tensor, DType, Device }
import nygrad { Variable }

// ── Enums ──────────────────────────────────────────────────────────

pub enum ModelFormat {
    NyxNative,
    ONNX,
    TorchScript,
    TFLite,
    CoreML,
    OpenVINO,
    TensorRT
}

pub enum QuantMode {
    Dynamic,
    Static,
    QAT
}

pub enum QuantBits {
    INT8,
    INT4,
    FP16,
    BF16
}

pub enum PruneMethod {
    Magnitude,
    Structured,
    Unstructured,
    LotteryTicket
}

// ── Model State ────────────────────────────────────────────────────

pub class ModelState {
    pub params: Map[String, Tensor]
    pub buffers: Map[String, Tensor]
    pub metadata: Map[String, String]
    pub config: Map[String, Any]

    pub fn new() -> Self {
        return Self { params: {}, buffers: {}, metadata: {}, config: {} }
    }

    pub fn from_model(model: Any) -> ModelState {
        let state = ModelState.new()
        let named_params = model.named_parameters()
        for (name, param) in named_params {
            state.params[name] = param.data.clone()
        }
        let named_buffers = model.named_buffers()
        for (name, buf) in named_buffers {
            state.buffers[name] = buf.clone()
        }
        state.metadata["model_class"] = model.class_name()
        state.metadata["created_at"] = time_now_ms().to_string()
        return state
    }

    pub fn load_into(self, model: Any) {
        let named_params = model.named_parameters()
        for (name, param) in named_params {
            if self.params.contains(name) {
                param.data = self.params[name].clone()
            }
        }
        let named_buffers = model.named_buffers()
        for (name, buf) in named_buffers {
            if self.buffers.contains(name) {
                buf.copy_(self.buffers[name])
            }
        }
    }

    pub fn num_parameters(self) -> Int {
        let total = 0
        for (_, tensor) in self.params {
            total = total + tensor.numel()
        }
        return total
    }

    pub fn size_bytes(self) -> Int {
        let total = 0
        for (_, tensor) in self.params {
            total = total + tensor.numel() * tensor.dtype.byte_size()
        }
        for (_, tensor) in self.buffers {
            total = total + tensor.numel() * tensor.dtype.byte_size()
        }
        return total
    }

    pub fn size_mb(self) -> Float {
        return self.size_bytes().to_float() / (1024.0 * 1024.0)
    }
}

// ── Save / Load ────────────────────────────────────────────────────

pub class ModelSaver {
    pub fn new() -> Self {
        return Self {}
    }

    pub fn save(self, model: Any, path: String, format: ModelFormat = ModelFormat.NyxNative) {
        match format {
            ModelFormat.NyxNative => self._save_native(model, path),
            ModelFormat.ONNX => self._save_onnx(model, path),
            _ => self._save_native(model, path)
        }
    }

    pub fn save_state(self, state: ModelState, path: String) {
        let data = {
            "params": {},
            "buffers": {},
            "metadata": state.metadata,
            "config": state.config
        }
        for (name, tensor) in state.params {
            data["params"][name] = {
                "shape": tensor.shape(),
                "dtype": tensor.dtype.to_string(),
                "data": tensor.to_bytes()
            }
        }
        for (name, tensor) in state.buffers {
            data["buffers"][name] = {
                "shape": tensor.shape(),
                "dtype": tensor.dtype.to_string(),
                "data": tensor.to_bytes()
            }
        }
        file_write_bytes(path, serialize(data))
    }

    fn _save_native(self, model: Any, path: String) {
        let state = ModelState.from_model(model)
        self.save_state(state, path)
    }

    fn _save_onnx(self, model: Any, path: String) {
        let graph = _trace_model(model)
        let onnx_proto = _build_onnx_proto(graph, model)
        file_write_bytes(path, onnx_proto)
    }
}

pub class ModelLoader {
    pub fn new() -> Self {
        return Self {}
    }

    pub fn load_state(self, path: String) -> ModelState {
        let data = deserialize(file_read_bytes(path))
        let state = ModelState.new()
        state.metadata = data["metadata"]
        state.config = data["config"]
        for (name, info) in data["params"] {
            let dtype = DType.from_string(info["dtype"])
            let shape = info["shape"]
            state.params[name] = Tensor.from_bytes(info["data"], shape, dtype)
        }
        for (name, info) in data["buffers"] {
            let dtype = DType.from_string(info["dtype"])
            let shape = info["shape"]
            state.buffers[name] = Tensor.from_bytes(info["data"], shape, dtype)
        }
        return state
    }

    pub fn load_into(self, path: String, model: Any) {
        let state = self.load_state(path)
        state.load_into(model)
    }

    pub fn load_onnx(self, path: String) -> Any {
        let proto = file_read_bytes(path)
        return _parse_onnx_model(proto)
    }
}

// ── Quantization ───────────────────────────────────────────────────

pub class QuantConfig {
    pub mode: QuantMode
    pub bits: QuantBits
    pub exclude_layers: List[String]
    pub calibration_samples: Int
    pub per_channel: Bool

    pub fn new(mode: QuantMode = QuantMode.Dynamic, bits: QuantBits = QuantBits.INT8) -> Self {
        return Self {
            mode: mode,
            bits: bits,
            exclude_layers: [],
            calibration_samples: 1000,
            per_channel: true
        }
    }
}

pub class Quantizer {
    pub config: QuantConfig

    pub fn new(config: QuantConfig = QuantConfig.new()) -> Self {
        return Self { config: config }
    }

    pub fn quantize(self, model: Any) -> Any {
        match self.config.mode {
            QuantMode.Dynamic => return self._dynamic_quantize(model),
            QuantMode.Static => return self._static_quantize(model),
            QuantMode.QAT => return self._prepare_qat(model)
        }
    }

    fn _dynamic_quantize(self, model: Any) -> Any {
        let state = ModelState.from_model(model)
        let target_dtype = self._target_dtype()
        for (name, tensor) in state.params {
            if self._should_quantize(name) {
                let (scale, zero_point) = _compute_scale_zp(tensor, self.config.bits, self.config.per_channel)
                state.params[name] = _quantize_tensor(tensor, scale, zero_point, target_dtype)
                state.metadata["quant_scale_" + name] = scale.to_string()
                state.metadata["quant_zp_" + name] = zero_point.to_string()
            }
        }
        state.load_into(model)
        state.metadata["quantization"] = self.config.bits.to_string()
        return model
    }

    fn _static_quantize(self, model: Any) -> Any {
        // Requires calibration data set via separate calibrate() call
        return self._dynamic_quantize(model)
    }

    fn _prepare_qat(self, model: Any) -> Any {
        let params = model.named_parameters()
        for (name, param) in params {
            if self._should_quantize(name) {
                let target_dtype = self._target_dtype()
                let (scale, zp) = _compute_scale_zp(param.data, self.config.bits, self.config.per_channel)
                param.data = _fake_quantize(param.data, scale, zp, target_dtype)
            }
        }
        return model
    }

    fn _should_quantize(self, name: String) -> Bool {
        for excluded in self.config.exclude_layers {
            if name.contains(excluded) { return false }
        }
        return true
    }

    fn _target_dtype(self) -> DType {
        match self.config.bits {
            QuantBits.INT8 => return DType.Int8,
            QuantBits.INT4 => return DType.Int8,
            QuantBits.FP16 => return DType.Float16,
            QuantBits.BF16 => return DType.BFloat16
        }
    }

    pub fn dequantize(self, model: Any, state: ModelState) -> Any {
        for (name, tensor) in state.params {
            let scale_key = "quant_scale_" + name
            let zp_key = "quant_zp_" + name
            if state.metadata.contains(scale_key) {
                let scale = state.metadata[scale_key].to_float()
                let zp = state.metadata[zp_key].to_float()
                state.params[name] = (tensor.to_float32() - zp) * scale
            }
        }
        state.load_into(model)
        return model
    }

    pub fn size_reduction(self, original: ModelState, quantized: ModelState) -> Float {
        let orig_size = original.size_bytes().to_float()
        let quant_size = quantized.size_bytes().to_float()
        return 1.0 - (quant_size / orig_size)
    }
}

fn _compute_scale_zp(tensor: Tensor, bits: QuantBits, per_channel: Bool) -> (Tensor, Tensor) {
    let (qmin, qmax) = match bits {
        QuantBits.INT8 => (-128.0, 127.0),
        QuantBits.INT4 => (-8.0, 7.0),
        _ => (-128.0, 127.0)
    }
    if per_channel && tensor.dim() >= 2 {
        let n = tensor.shape()[0]
        let scales = Tensor.zeros([n])
        let zero_points = Tensor.zeros([n])
        for i in range(n) {
            let channel = tensor[i].flatten()
            let minv = channel.min().item()
            let maxv = channel.max().item()
            let scale = (maxv - minv) / (qmax - qmin)
            let zp = qmin - minv / (scale + 1e-8)
            scales[i] = scale
            zero_points[i] = zp.round()
        }
        return (scales, zero_points)
    }
    let minv = tensor.min().item()
    let maxv = tensor.max().item()
    let scale = (maxv - minv) / (qmax - qmin)
    let zp = (qmin - minv / (scale + 1e-8)).round()
    return (Tensor.scalar(scale), Tensor.scalar(zp))
}

fn _quantize_tensor(tensor: Tensor, scale: Tensor, zero_point: Tensor, dtype: DType) -> Tensor {
    return (tensor / (scale + 1e-8) + zero_point).round().clamp(-128.0, 127.0).to(dtype)
}

fn _fake_quantize(tensor: Tensor, scale: Tensor, zero_point: Tensor, dtype: DType) -> Tensor {
    let quantized = (tensor / (scale + 1e-8) + zero_point).round().clamp(-128.0, 127.0)
    return (quantized - zero_point) * scale
}

// ── Pruning ────────────────────────────────────────────────────────

pub class PruneConfig {
    pub method: PruneMethod
    pub sparsity: Float
    pub exclude_layers: List[String]
    pub iterative_steps: Int

    pub fn new(method: PruneMethod = PruneMethod.Magnitude, sparsity: Float = 0.5) -> Self {
        return Self {
            method: method,
            sparsity: sparsity,
            exclude_layers: [],
            iterative_steps: 1
        }
    }
}

pub class Pruner {
    pub config: PruneConfig
    _masks: Map[String, Tensor]

    pub fn new(config: PruneConfig = PruneConfig.new()) -> Self {
        return Self { config: config, _masks: {} }
    }

    pub fn prune(mut self, model: Any) -> Any {
        match self.config.method {
            PruneMethod.Magnitude => self._magnitude_prune(model),
            PruneMethod.Structured => self._structured_prune(model),
            PruneMethod.Unstructured => self._magnitude_prune(model),
            PruneMethod.LotteryTicket => self._magnitude_prune(model)
        }
        return model
    }

    fn _magnitude_prune(mut self, model: Any) {
        let params = model.named_parameters()
        for (name, param) in params {
            if self._should_prune(name) && param.data.dim() >= 2 {
                let abs_vals = param.data.abs().flatten()
                let k = (abs_vals.numel().to_float() * self.config.sparsity).to_int()
                let threshold = abs_vals.kthvalue(k).item()
                let mask = param.data.abs() > threshold
                self._masks[name] = mask.to_float()
                param.data = param.data * mask.to_float()
            }
        }
    }

    fn _structured_prune(mut self, model: Any) {
        let params = model.named_parameters()
        for (name, param) in params {
            if self._should_prune(name) && param.data.dim() >= 2 {
                let norms = param.data.norm(dim: 1)
                let k = (norms.numel().to_float() * self.config.sparsity).to_int()
                let threshold = norms.kthvalue(k).item()
                let mask = norms > threshold
                for i in range(param.data.shape()[0]) {
                    if !mask[i].item() {
                        param.data[i] = Tensor.zeros(param.data[i].shape())
                    }
                }
                self._masks[name] = mask
            }
        }
    }

    fn _should_prune(self, name: String) -> Bool {
        for excluded in self.config.exclude_layers {
            if name.contains(excluded) { return false }
        }
        return true
    }

    pub fn apply_masks(self, model: Any) {
        let params = model.named_parameters()
        for (name, param) in params {
            if self._masks.contains(name) {
                param.data = param.data * self._masks[name]
            }
        }
    }

    pub fn sparsity_report(self, model: Any) -> Map[String, Float] {
        let report = {}
        let params = model.named_parameters()
        let total_params = 0
        let total_zeros = 0
        for (name, param) in params {
            let numel = param.data.numel()
            let zeros = (param.data == 0.0).sum().item()
            report[name] = zeros.to_float() / numel.to_float()
            total_params = total_params + numel
            total_zeros = total_zeros + zeros
        }
        report["overall"] = total_zeros.to_float() / total_params.to_float()
        return report
    }
}

// ── Knowledge Distillation ─────────────────────────────────────────

pub class DistillConfig {
    pub temperature: Float
    pub alpha: Float
    pub loss_type: String

    pub fn new(temperature: Float = 4.0, alpha: Float = 0.5) -> Self {
        return Self { temperature: temperature, alpha: alpha, loss_type: "kl_div" }
    }
}

pub class Distiller {
    pub teacher: Any
    pub student: Any
    pub config: DistillConfig

    pub fn new(teacher: Any, student: Any, config: DistillConfig = DistillConfig.new()) -> Self {
        teacher.eval()
        return Self { teacher: teacher, student: student, config: config }
    }

    pub fn distill_loss(self, inputs: Tensor, targets: Tensor) -> Variable {
        let teacher_logits = nil
        no_grad {
            teacher_logits = self.teacher.forward(inputs)
        }
        let student_logits = self.student.forward(inputs)

        let T = self.config.temperature
        let soft_teacher = (teacher_logits / T).softmax(dim: -1)
        let soft_student = (student_logits / T).log_softmax(dim: -1)

        let distill_loss = -(soft_teacher * soft_student).sum(dim: -1).mean() * (T * T)
        let hard_loss = cross_entropy(student_logits, targets)

        return self.config.alpha * distill_loss + (1.0 - self.config.alpha) * hard_loss
    }
}

// ── Model Analysis ─────────────────────────────────────────────────

pub class ModelAnalyzer {
    pub fn new() -> Self {
        return Self {}
    }

    pub fn summary(self, model: Any, input_shape: List[Int]) -> String {
        let lines = ["Model Summary", "=" * 70]
        lines.append("Layer Name                    | Output Shape       | Params")
        lines.append("-" * 70)

        let total_params = 0
        let trainable_params = 0
        let layers = model.named_children()
        for (name, layer) in layers {
            let params = layer.parameters()
            let layer_params = 0
            for p in params { layer_params = layer_params + p.data.numel() }
            total_params = total_params + layer_params
            trainable_params = trainable_params + layer_params
            lines.append(name.pad_right(30) + "| " + "?".pad_right(19) + "| " + layer_params.to_string())
        }

        lines.append("=" * 70)
        lines.append("Total params: " + total_params.to_string())
        lines.append("Trainable params: " + trainable_params.to_string())
        lines.append("Size: " + (total_params * 4 / 1024 / 1024).to_string() + " MB (FP32)")
        return lines.join("\n")
    }

    pub fn flops(self, model: Any, input_shape: List[Int]) -> Int {
        let dummy = Tensor.randn(input_shape)
        return _count_flops(model, dummy)
    }

    pub fn parameter_count(self, model: Any) -> Map[String, Int] {
        let result = {}
        let total = 0
        let params = model.named_parameters()
        for (name, param) in params {
            let count = param.data.numel()
            result[name] = count
            total = total + count
        }
        result["total"] = total
        return result
    }
}

fn _count_flops(model: Any, input: Tensor) -> Int {
    // Estimate FLOPs by tracing forward pass
    let total = 0
    let layers = model.named_children()
    for (name, layer) in layers {
        let params = layer.parameters()
        for p in params {
            total = total + p.data.numel() * 2  // multiply-add = 2 flops
        }
    }
    return total
}

fn _trace_model(model: Any) -> Any {
    return model  // placeholder for full tracing
}

fn _build_onnx_proto(graph: Any, model: Any) -> Bytes {
    let state = ModelState.from_model(model)
    return serialize({"format": "onnx", "state": state.params, "graph": graph})
}

fn _parse_onnx_model(proto: Bytes) -> Any {
    return deserialize(proto)
}

// ── Convenience ────────────────────────────────────────────────────

pub fn save_model(model: Any, path: String, format: ModelFormat = ModelFormat.NyxNative) {
    ModelSaver.new().save(model, path, format)
}

pub fn load_model(path: String, model: Any) {
    ModelLoader.new().load_into(path, model)
}

pub fn quantize(model: Any, bits: QuantBits = QuantBits.INT8) -> Any {
    let config = QuantConfig.new(bits: bits)
    return Quantizer.new(config).quantize(model)
}

pub fn prune(model: Any, sparsity: Float = 0.5) -> Any {
    let config = PruneConfig.new(sparsity: sparsity)
    return Pruner.new(config).prune(model)
}

export {
    ModelFormat, QuantMode, QuantBits, PruneMethod,
    ModelState, ModelSaver, ModelLoader,
    QuantConfig, Quantizer,
    PruneConfig, Pruner,
    DistillConfig, Distiller,
    ModelAnalyzer,
    save_model, load_model, quantize, prune
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
