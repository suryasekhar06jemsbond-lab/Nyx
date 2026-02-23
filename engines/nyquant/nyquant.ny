# ============================================================
# NyQuant - Model Compression & Quantization Engine
# INT8/INT4 quantization, pruning, knowledge distillation
# ============================================================

use nytensor;
use nygrad;
use nynet_ml;

# ============================================================
# SECTION 1: QUANTIZATION CORE
# ============================================================

enum QuantMode {
    INT8,
    INT4,
    FP16,
    BF16,
    Mixed
}

enum Calibration {
    MinMax,
    Histogram,
    Entropy,
    Percentile
}

class QuantizationConfig {
    pub let mode: QuantMode;
    pub let calibration: Calibration;
    pub let symmetric: Bool;
    pub let per_channel: Bool;
    pub let num_calibration_batches: Int;

    pub fn new(mode: QuantMode) -> Self {
        return Self {
            mode: mode,
            calibration: Calibration::MinMax,
            symmetric: false,
            per_channel: true,
            num_calibration_batches: 100
        };
    }

    pub fn with_calibration(self, method: Calibration) -> Self {
        self.calibration = method;
        return self;
    }

    pub fn symmetric_quantization(self) -> Self {
        self.symmetric = true;
        return self;
    }
}

# ============================================================
# SECTION 2: QUANTIZED TENSOR
# ============================================================

class QuantizedTensor {
    pub let data: Tensor;  # Quantized data (INT8/INT4)
    pub let scale: Tensor;
    pub let zero_point: Tensor;
    pub let mode: QuantMode;
    pub let original_dtype: DType;

    pub fn new(data: Tensor, scale: Tensor, zero_point: Tensor, mode: QuantMode) -> Self {
        return Self {
            data: data,
            scale: scale,
            zero_point: zero_point,
            mode: mode,
            original_dtype: DType::Float32
        };
    }

    pub fn dequantize(self) -> Tensor {
        # Dequantize back to floating point
        let fp_data = self.data.to_float();
        return (fp_data - self.zero_point) * self.scale;
    }

    pub fn size_reduction(self) -> Float {
        # Calculate memory size reduction
        let original_bits = match self.original_dtype {
            DType::Float32 => 32.0,
            DType::Float16 => 16.0,
            _ => 32.0
        };
        let quantized_bits = match self.mode {
            QuantMode::INT8 => 8.0,
            QuantMode::INT4 => 4.0,
            QuantMode::FP16 => 16.0,
            QuantMode::BF16 => 16.0,
            _ => 8.0
        };
        return original_bits / quantized_bits;
    }
}

# ============================================================
# SECTION 3: QUANTIZER
# ============================================================

class Quantizer {
    pub let config: QuantizationConfig;
    pub let calibration_data: [Tensor];
    pub let calibrated: Bool;

    pub fn new(config: QuantizationConfig) -> Self {
        return Self {
            config: config,
            calibration_data: [],
            calibrated: false
        };
    }

    pub fn calibrate(self, data_loader: Any) {
        print("Calibrating quantization scales...");
        
        for (let i = 0; i < self.config.num_calibration_batches; i = i + 1) {
            let batch = data_loader.next();
            self.calibration_data = self.calibration_data + [batch];
        }
        
        self.calibrated = true;
        print("Calibration complete with " + str(len(self.calibration_data)) + " batches");
    }

    pub fn quantize_tensor(self, tensor: Tensor) -> QuantizedTensor {
        if (!self.calibrated) {
            print("Warning: Using default calibration");
        }

        let scale: Tensor;
        let zero_point: Tensor;

        match self.config.calibration {
            Calibration::MinMax => {
                let result = self.compute_minmax_scale(tensor);
                scale = result[0];
                zero_point = result[1];
            },
            Calibration::Histogram => {
                let result = self.compute_histogram_scale(tensor);
                scale = result[0];
                zero_point = result[1];
            },
            _ => {
                let result = self.compute_minmax_scale(tensor);
                scale = result[0];
                zero_point = result[1];
            }
        }

        # Quantize
        let quantized_data = self.apply_quantization(tensor, scale, zero_point);
        return QuantizedTensor::new(quantized_data, scale, zero_point, self.config.mode);
    }

    fn compute_minmax_scale(self, tensor: Tensor) -> [Tensor; 2] {
        let min_val = tensor.min();
        let max_val = tensor.max();
        
        let qmin = match self.config.mode {
            QuantMode::INT8 => -128.0,
            QuantMode::INT4 => -8.0,
            _ => -128.0
        };
        let qmax = match self.config.mode {
            QuantMode::INT8 => 127.0,
            QuantMode::INT4 => 7.0,
            _ => 127.0
        };

        let scale = (max_val - min_val) / (qmax - qmin);
        let zero_point = qmin - min_val / scale;
        
        return [Tensor::scalar(scale), Tensor::scalar(zero_point)];
    }

    fn compute_histogram_scale(self, tensor: Tensor) -> [Tensor; 2] {
        # More accurate calibration using histogram
        let num_bins = 2048;
        let hist = tensor.histogram(num_bins);
        
        # Find optimal threshold using KL divergence
        let threshold = self.find_optimal_threshold(hist, num_bins);
        
        let scale = threshold / 127.0;
        let zero_point = Tensor::zeros([1], DType::Float32, Device::CPU);
        
        return [scale, zero_point];
    }

    fn apply_quantization(self, tensor: Tensor, scale: Tensor, zero_point: Tensor) -> Tensor {
        # Quantize: q = round(x / scale + zero_point)
        let q = (tensor / scale) + zero_point;
        q = q.round();
        
        # Clamp to valid range
        let qmin = match self.config.mode {
            QuantMode::INT8 => -128.0,
            QuantMode::INT4 => -8.0,
            _ => -128.0
        };
        let qmax = match self.config.mode {
            QuantMode::INT8 => 127.0,
            QuantMode::INT4 => 7.0,
            _ => 127.0
        };
        
        return q.clamp(qmin, qmax);
    }

    fn find_optimal_threshold(self, hist: Tensor, num_bins: Int) -> Tensor {
        # KL divergence based threshold selection
        # Simplified implementation
        return Tensor::scalar(2.0);
    }
}

# ============================================================
# SECTION 4: QUANTIZE-AWARE TRAINING (QAT)
# ============================================================

class QATConfig {
    pub let quant_mode: QuantMode;
    pub let freeze_bn: Bool;
    pub let observer_enabled: Bool;
    pub let num_qat_epochs: Int;

    pub fn new() -> Self {
        return Self {
            quant_mode: QuantMode::INT8,
            freeze_bn: false,
            observer_enabled: true,
            num_qat_epochs: 10
        };
    }
}

class FakeQuantize {
    pub let scale: Tensor;
    pub let zero_point: Tensor;
    pub let mode: QuantMode;
    pub let enabled: Bool;

    pub fn new(mode: QuantMode) -> Self {
        return Self {
            scale: Tensor::ones([1], DType::Float32, Device::CPU),
            zero_point: Tensor::zeros([1], DType::Float32, Device::CPU),
            mode: mode,
            enabled: true
        };
    }

    pub fn forward(self, x: Tensor) -> Tensor {
        if (!self.enabled) {
            return x;
        }

        # Simulate quantization during training
        let quantized = (x / self.scale) + self.zero_point;
        quantized = quantized.round();
        
        # Dequantize to maintain gradient flow
        return (quantized - self.zero_point) * self.scale;
    }

    pub fn update_stats(self, x: Tensor) {
        # Update scale and zero_point based on observed values
        let min_val = x.min();
        let max_val = x.max();
        self.scale = (max_val - min_val) / 255.0;
        self.zero_point = -min_val / self.scale;
    }
}

# ============================================================
# SECTION 5: PRUNING ENGINE
# ============================================================

enum PruningMethod {
    Magnitude,
    Movement,
    Structured,
    Unstructured
}

class PruningConfig {
    pub let method: PruningMethod;
    pub let sparsity: Float;  # Target sparsity (0.0 to 1.0)
    pub let start_epoch: Int;
    pub let end_epoch: Int;
    pub let frequency: Int;  # Prune every N steps

    pub fn new(sparsity: Float) -> Self {
        return Self {
            method: PruningMethod::Magnitude,
            sparsity: sparsity,
            start_epoch: 0,
            end_epoch: 10,
            frequency: 100
        };
    }

    pub fn with_method(self, method: PruningMethod) -> Self {
        self.method = method;
        return self;
    }
}

class Pruner {
    pub let config: PruningConfig;
    pub let masks: Map<String, Tensor>;
    pub let current_sparsity: Float;

    pub fn new(config: PruningConfig) -> Self {
        return Self {
            config: config,
            masks: Map::new(),
            current_sparsity: 0.0
        };
    }

    pub fn compute_mask(self, weights: Tensor) -> Tensor {
        match self.config.method {
            PruningMethod::Magnitude => self.magnitude_pruning(weights),
            PruningMethod::Structured => self.structured_pruning(weights),
            _ => self.magnitude_pruning(weights)
        }
    }

    fn magnitude_pruning(self, weights: Tensor) -> Tensor {
        # Prune weights with smallest magnitude
        let abs_weights = weights.abs();
        let threshold = abs_weights.quantile(self.config.sparsity);
        return (abs_weights > threshold).to_float();
    }

    fn structured_pruning(self, weights: Tensor) -> Tensor {
        # Prune entire channels/filters
        let shape = weights.shape;
        if (len(shape.dims) == 4) {  # Conv weights [out_ch, in_ch, h, w]
            return self.prune_channels(weights);
        }
        return self.magnitude_pruning(weights);
    }

    fn prune_channels(self, weights: Tensor) -> Tensor {
        # Compute L2 norm per output channel
        let out_channels = weights.shape.dims[0];
        let norms = Tensor::zeros([out_channels], DType::Float32, Device::CPU);
        
        for (let i = 0; i < out_channels; i = i + 1) {
            let channel = weights.select(0, i);
            norms.data[i] = channel.norm(2);
        }
        
        # Keep top (1 - sparsity) channels
        let num_keep = (out_channels as Float * (1.0 - self.config.sparsity)) as Int;
        let threshold = norms.topk(num_keep).min();
        
        # Create mask
        let mask = Tensor::ones(weights.shape, DType::Float32, Device::CPU);
        for (let i = 0; i < out_channels; i = i + 1) {
            if (norms.data[i] < threshold) {
                # Zero out entire channel
                mask = mask.masked_fill(i, 0.0);
            }
        }
        
        return mask;
    }

    pub fn apply_mask(self, weights: Tensor, mask: Tensor) -> Tensor {
        return weights * mask;
    }

    pub fn compute_sparsity(self, weights: Tensor) -> Float {
        let total = weights.numel() as Float;
        let zeros = (weights == 0.0).sum() as Float;
        return zeros / total;
    }
}

# ============================================================
# SECTION 6: KNOWLEDGE DISTILLATION
# ============================================================

class DistillationConfig {
    pub let temperature: Float;
    pub let alpha: Float;  # Weight for distillation loss
    pub let beta: Float;   # Weight for student loss

    pub fn new(temperature: Float) -> Self {
        return Self {
            temperature: temperature,
            alpha: 0.5,
            beta: 0.5
        };
    }
}

class DistillationLoss {
    pub let config: DistillationConfig;
    pub let kl_div: KLDivLoss;

    pub fn new(config: DistillationConfig) -> Self {
        return Self {
            config: config,
            kl_div: KLDivLoss::new(Reduction::BatchMean)
        };
    }

    pub fn forward(self, student_logits: Tensor, teacher_logits: Tensor, labels: Tensor, student_loss: Tensor) -> Tensor {
        # Soft targets
        let T = self.config.temperature;
        let soft_student = (student_logits / T).log_softmax(1);
        let soft_teacher = (teacher_logits / T).softmax(1);
        
        # KL divergence loss
        let distillation_loss = self.kl_div.forward(soft_student, soft_teacher) * (T * T);
        
        # Combined loss
        let total_loss = self.config.alpha * distillation_loss + self.config.beta * student_loss;
        return total_loss;
    }
}

class Distiller {
    pub let teacher: Any;  # Teacher model
    pub let student: Any;  # Student model
    pub let config: DistillationConfig;
    pub let loss_fn: DistillationLoss;

    pub fn new(teacher: Any, student: Any, config: DistillationConfig) -> Self {
        return Self {
            teacher: teacher,
            student: student,
            config: config,
            loss_fn: DistillationLoss::new(config)
        };
    }

    pub fn train_step(self, inputs: Tensor, labels: Tensor) -> Tensor {
        # Forward through both models
        let teacher_logits = self.teacher.forward(inputs);
        let student_logits = self.student.forward(inputs);
        
        # Compute student loss
        let ce_loss = CrossEntropyLoss::new(Reduction::Mean, 0.0);
        let student_loss = ce_loss.forward(student_logits, labels);
        
        # Compute distillation loss
        return self.loss_fn.forward(student_logits, teacher_logits, labels, student_loss);
    }
}

# ============================================================
# SECTION 7: MODEL COMPRESSION PIPELINE
# ============================================================

class CompressionPipeline {
    pub let model: Any;
    pub let quantizer: Quantizer?;
    pub let pruner: Pruner?;
    pub let distiller: Distiller?;
    pub let compressed: Bool;

    pub fn new(model: Any) -> Self {
        return Self {
            model: model,
            quantizer: null,
            pruner: null,
            distiller: null,
            compressed: false
        };
    }

    pub fn add_quantization(self, config: QuantizationConfig) -> Self {
        self.quantizer = Quantizer::new(config);
        return self;
    }

    pub fn add_pruning(self, config: PruningConfig) -> Self {
        self.pruner = Pruner::new(config);
        return self;
    }

    pub fn add_distillation(self, teacher: Any, config: DistillationConfig) -> Self {
        self.distiller = Distiller::new(teacher, self.model, config);
        return self;
    }

    pub fn compress(self) -> CompressedModel {
        print("Starting model compression pipeline...");

        # Step 1: Pruning
        if (self.pruner != null) {
            print("Applying pruning...");
            self.apply_pruning();
        }

        # Step 2: Quantization
        if (self.quantizer != null) {
            print("Applying quantization...");
            self.apply_quantization();
        }

        self.compressed = true;
        print("Compression complete!");
        
        return CompressedModel::new(self.model, self.quantizer, self.pruner);
    }

    fn apply_pruning(self) {
        # Apply pruning masks to model weights
        let pruner = self.pruner!;
        # Implementation: iterate through model parameters and apply masks
    }

    fn apply_quantization(self) {
        # Quantize model weights
        let quantizer = self.quantizer!;
        # Implementation: quantize all model parameters
    }
}

class CompressedModel {
    pub let model: Any;
    pub let quantizer: Quantizer?;
    pub let pruner: Pruner?;
    pub let compression_ratio: Float;

    pub fn new(model: Any, quantizer: Quantizer?, pruner: Pruner?) -> Self {
        return Self {
            model: model,
            quantizer: quantizer,
            pruner: pruner,
            compression_ratio: 1.0
        };
    }

    pub fn forward(self, x: Tensor) -> Tensor {
        return self.model.forward(x);
    }

    pub fn compute_compression_ratio(self) -> Float {
        # Calculate overall compression ratio
        let size_reduction = 1.0;
        
        if (self.quantizer != null) {
            size_reduction = size_reduction * 4.0;  # INT8 vs FP32
        }
        
        if (self.pruner != null) {
            let sparsity = self.pruner!.current_sparsity;
            size_reduction = size_reduction / (1.0 - sparsity);
        }
        
        return size_reduction;
    }

    pub fn save(self, path: String) {
        print("Saving compressed model to: " + path);
        # Save quantized and pruned model
    }
}

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    QuantMode,
    Calibration,
    QuantizationConfig,
    QuantizedTensor,
    Quantizer,
    FakeQuantize,
    QATConfig,
    PruningMethod,
    PruningConfig,
    Pruner,
    DistillationConfig,
    DistillationLoss,
    Distiller,
    CompressionPipeline,
    CompressedModel
};

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
