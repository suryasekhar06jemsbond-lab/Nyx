// NyServe Engine - Model Serving for Nyx ML
// REST/gRPC endpoints, batch/real-time inference, auto-scaling, edge deployment, A/B testing

import nytensor { Tensor, DType, Device }

// ── Enums ──────────────────────────────────────────────────────────

pub enum ServeProtocol {
    REST,
    GRPC,
    WebSocket,
    Custom
}

pub enum InferenceMode {
    RealTime,
    Batch,
    Streaming,
    Async
}

pub enum ModelStatus {
    Loading,
    Ready,
    Serving,
    Draining,
    Error,
    Stopped
}

pub enum HealthStatus {
    Healthy,
    Degraded,
    Unhealthy
}

// ── Request / Response ─────────────────────────────────────────────

pub class InferenceRequest {
    pub id: String
    pub inputs: Map[String, Tensor]
    pub params: Map[String, Any]
    pub timestamp: Int

    pub fn new(inputs: Map[String, Tensor]) -> Self {
        return Self {
            id: generate_uuid(),
            inputs: inputs,
            params: {},
            timestamp: time_now_ms()
        }
    }

    pub fn with_param(mut self, key: String, value: Any) -> Self {
        self.params[key] = value
        return self
    }
}

pub class InferenceResponse {
    pub request_id: String
    pub outputs: Map[String, Tensor]
    pub latency_ms: Float
    pub metadata: Map[String, Any]

    pub fn new(request_id: String, outputs: Map[String, Tensor], latency_ms: Float) -> Self {
        return Self {
            request_id: request_id,
            outputs: outputs,
            latency_ms: latency_ms,
            metadata: {}
        }
    }
}

pub class BatchRequest {
    pub requests: List[InferenceRequest]

    pub fn new() -> Self {
        return Self { requests: [] }
    }

    pub fn add(mut self, req: InferenceRequest) -> Self {
        self.requests.append(req)
        return self
    }

    pub fn size(self) -> Int {
        return self.requests.len()
    }
}

pub class BatchResponse {
    pub responses: List[InferenceResponse]
    pub total_latency_ms: Float

    pub fn new(responses: List[InferenceResponse], total_latency_ms: Float) -> Self {
        return Self { responses: responses, total_latency_ms: total_latency_ms }
    }
}

// ── Model Registry ─────────────────────────────────────────────────

pub class ModelInfo {
    pub name: String
    pub version: String
    pub path: String
    pub device: Device
    pub status: ModelStatus
    pub loaded_at: Int?
    pub metadata: Map[String, String]

    pub fn new(name: String, version: String, path: String, device: Device = Device.CPU) -> Self {
        return Self {
            name: name,
            version: version,
            path: path,
            device: device,
            status: ModelStatus.Loading,
            loaded_at: nil,
            metadata: {}
        }
    }

    pub fn key(self) -> String {
        return self.name + ":" + self.version
    }
}

pub class ModelRegistry {
    _models: Map[String, ModelInfo]
    _loaded_models: Map[String, Any]

    pub fn new() -> Self {
        return Self { _models: {}, _loaded_models: {} }
    }

    pub fn register(mut self, info: ModelInfo) {
        self._models[info.key()] = info
    }

    pub fn load(mut self, name: String, version: String) -> Any? {
        let key = name + ":" + version
        let info = self._models.get(key)
        if info == nil { return nil }

        info.status = ModelStatus.Loading
        let model = deserialize_from_file(info.path)
        model.to(info.device)
        model.eval()

        self._loaded_models[key] = model
        info.status = ModelStatus.Ready
        info.loaded_at = time_now_ms()
        return model
    }

    pub fn get_model(self, name: String, version: String) -> Any? {
        return self._loaded_models.get(name + ":" + version)
    }

    pub fn unload(mut self, name: String, version: String) {
        let key = name + ":" + version
        self._loaded_models.remove(key)
        let info = self._models.get(key)
        if info != nil { info.status = ModelStatus.Stopped }
    }

    pub fn list_models(self) -> List[ModelInfo] {
        return self._models.values()
    }

    pub fn list_loaded(self) -> List[String] {
        return self._loaded_models.keys()
    }
}

// ── Preprocessor / Postprocessor ───────────────────────────────────

pub class Preprocessor {
    _pipeline: List[Fn(Map[String, Tensor]) -> Map[String, Tensor]]

    pub fn new() -> Self {
        return Self { _pipeline: [] }
    }

    pub fn add(mut self, step: Fn(Map[String, Tensor]) -> Map[String, Tensor]) -> Self {
        self._pipeline.append(step)
        return self
    }

    pub fn process(self, inputs: Map[String, Tensor]) -> Map[String, Tensor] {
        let current = inputs
        for step in self._pipeline {
            current = step(current)
        }
        return current
    }
}

pub class Postprocessor {
    _pipeline: List[Fn(Map[String, Tensor]) -> Map[String, Tensor]]

    pub fn new() -> Self {
        return Self { _pipeline: [] }
    }

    pub fn add(mut self, step: Fn(Map[String, Tensor]) -> Map[String, Tensor]) -> Self {
        self._pipeline.append(step)
        return self
    }

    pub fn process(self, outputs: Map[String, Tensor]) -> Map[String, Tensor] {
        let current = outputs
        for step in self._pipeline {
            current = step(current)
        }
        return current
    }
}

// ── Inference Engine ───────────────────────────────────────────────

pub class InferenceEngine {
    pub model: Any
    pub device: Device
    pub preprocessor: Preprocessor?
    pub postprocessor: Postprocessor?
    pub max_batch_size: Int
    _request_count: Int
    _total_latency: Float

    pub fn new(model: Any, device: Device = Device.CPU, max_batch_size: Int = 32) -> Self {
        return Self {
            model: model,
            device: device,
            preprocessor: nil,
            postprocessor: nil,
            max_batch_size: max_batch_size,
            _request_count: 0,
            _total_latency: 0.0
        }
    }

    pub fn with_preprocessor(mut self, pre: Preprocessor) -> Self {
        self.preprocessor = pre
        return self
    }

    pub fn with_postprocessor(mut self, post: Postprocessor) -> Self {
        self.postprocessor = post
        return self
    }

    pub fn predict(mut self, request: InferenceRequest) -> InferenceResponse {
        let start = time_now_ms()

        let inputs = request.inputs
        if self.preprocessor != nil {
            inputs = self.preprocessor.process(inputs)
        }

        for (name, tensor) in inputs {
            inputs[name] = tensor.to(self.device)
        }

        let outputs = {}
        no_grad {
            let result = self.model.forward(inputs)
            if result is Tensor {
                outputs["output"] = result
            } else if result is Map {
                outputs = result
            }
        }

        if self.postprocessor != nil {
            outputs = self.postprocessor.process(outputs)
        }

        let latency = (time_now_ms() - start).to_float()
        self._request_count = self._request_count + 1
        self._total_latency = self._total_latency + latency

        return InferenceResponse.new(request.id, outputs, latency)
    }

    pub fn predict_batch(mut self, batch: BatchRequest) -> BatchResponse {
        let start = time_now_ms()
        let responses = []

        // Dynamic batching: collate inputs
        let batched_inputs = _collate_inputs(batch.requests)
        if self.preprocessor != nil {
            batched_inputs = self.preprocessor.process(batched_inputs)
        }
        for (name, tensor) in batched_inputs {
            batched_inputs[name] = tensor.to(self.device)
        }

        let batched_outputs = {}
        no_grad {
            let result = self.model.forward(batched_inputs)
            if result is Tensor {
                batched_outputs["output"] = result
            } else if result is Map {
                batched_outputs = result
            }
        }

        if self.postprocessor != nil {
            batched_outputs = self.postprocessor.process(batched_outputs)
        }

        // Split back
        for i in range(batch.size()) {
            let single_out = {}
            for (name, tensor) in batched_outputs {
                single_out[name] = tensor[i]
            }
            let latency = (time_now_ms() - start).to_float()
            responses.append(InferenceResponse.new(batch.requests[i].id, single_out, latency))
        }

        let total = (time_now_ms() - start).to_float()
        self._request_count = self._request_count + batch.size()
        self._total_latency = self._total_latency + total
        return BatchResponse.new(responses, total)
    }

    pub fn avg_latency_ms(self) -> Float {
        if self._request_count == 0 { return 0.0 }
        return self._total_latency / self._request_count.to_float()
    }

    pub fn throughput_rps(self) -> Float {
        if self._total_latency == 0.0 { return 0.0 }
        return self._request_count.to_float() / (self._total_latency / 1000.0)
    }
}

fn _collate_inputs(requests: List[InferenceRequest]) -> Map[String, Tensor] {
    let result = {}
    let first = requests[0]
    for name in first.inputs.keys() {
        let tensors = requests.map(fn(r) { return r.inputs[name] })
        result[name] = Tensor.stack(tensors, dim: 0)
    }
    return result
}

// ── Dynamic Batcher ────────────────────────────────────────────────

pub class DynamicBatcher {
    pub max_batch_size: Int
    pub max_wait_ms: Int
    _queue: Queue[InferenceRequest]
    _engine: InferenceEngine

    pub fn new(engine: InferenceEngine, max_batch_size: Int = 32, max_wait_ms: Int = 50) -> Self {
        return Self {
            max_batch_size: max_batch_size,
            max_wait_ms: max_wait_ms,
            _queue: Queue.new(),
            _engine: engine
        }
    }

    pub fn submit(mut self, request: InferenceRequest) -> InferenceResponse {
        self._queue.push(request)
        return self._process_queue()
    }

    fn _process_queue(mut self) -> InferenceResponse {
        let batch = BatchRequest.new()
        let deadline = time_now_ms() + self.max_wait_ms

        while batch.size() < self.max_batch_size && time_now_ms() < deadline {
            let req = self._queue.try_pop()
            if req == nil { break }
            batch.add(req)
        }

        if batch.size() == 0 { return nil }
        let result = self._engine.predict_batch(batch)
        return result.responses[result.responses.len() - 1]
    }
}

// ── A/B Testing ────────────────────────────────────────────────────

pub class ABTestConfig {
    pub name: String
    pub model_a: String
    pub model_b: String
    pub split_ratio: Float
    pub seed: Int

    pub fn new(name: String, model_a: String, model_b: String, split_ratio: Float = 0.5) -> Self {
        return Self { name: name, model_a: model_a, model_b: model_b, split_ratio: split_ratio, seed: 42 }
    }
}

pub class ABTestRouter {
    pub config: ABTestConfig
    _engine_a: InferenceEngine
    _engine_b: InferenceEngine
    _count_a: Int
    _count_b: Int

    pub fn new(config: ABTestConfig, engine_a: InferenceEngine, engine_b: InferenceEngine) -> Self {
        return Self {
            config: config,
            _engine_a: engine_a,
            _engine_b: engine_b,
            _count_a: 0,
            _count_b: 0
        }
    }

    pub fn route(mut self, request: InferenceRequest) -> (InferenceResponse, String) {
        let hash = hash_string(request.id + self.config.seed.to_string())
        let use_a = (hash % 100).to_float() / 100.0 < self.config.split_ratio

        if use_a {
            self._count_a = self._count_a + 1
            return (self._engine_a.predict(request), self.config.model_a)
        } else {
            self._count_b = self._count_b + 1
            return (self._engine_b.predict(request), self.config.model_b)
        }
    }

    pub fn stats(self) -> Map[String, Any] {
        return {
            "test_name": self.config.name,
            "model_a": self.config.model_a,
            "model_b": self.config.model_b,
            "count_a": self._count_a,
            "count_b": self._count_b,
            "avg_latency_a": self._engine_a.avg_latency_ms(),
            "avg_latency_b": self._engine_b.avg_latency_ms()
        }
    }
}

// ── Serving Server ─────────────────────────────────────────────────

pub class ServeConfig {
    pub host: String
    pub port: Int
    pub protocol: ServeProtocol
    pub workers: Int
    pub max_concurrent: Int
    pub timeout_ms: Int
    pub cors_origins: List[String]

    pub fn new(host: String = "0.0.0.0", port: Int = 8080) -> Self {
        return Self {
            host: host,
            port: port,
            protocol: ServeProtocol.REST,
            workers: 4,
            max_concurrent: 100,
            timeout_ms: 30000,
            cors_origins: ["*"]
        }
    }
}

pub class ServingServer {
    pub config: ServeConfig
    _engine: InferenceEngine
    _registry: ModelRegistry
    _running: Bool
    _health: HealthStatus
    _middleware: List[Fn(InferenceRequest) -> InferenceRequest]

    pub fn new(config: ServeConfig, engine: InferenceEngine) -> Self {
        return Self {
            config: config,
            _engine: engine,
            _registry: ModelRegistry.new(),
            _running: false,
            _health: HealthStatus.Healthy,
            _middleware: []
        }
    }

    pub fn add_middleware(mut self, mw: Fn(InferenceRequest) -> InferenceRequest) -> Self {
        self._middleware.append(mw)
        return self
    }

    pub fn start(mut self) {
        self._running = true
        match self.config.protocol {
            ServeProtocol.REST => self._start_rest(),
            ServeProtocol.GRPC => self._start_grpc(),
            ServeProtocol.WebSocket => self._start_ws(),
            _ => self._start_rest()
        }
    }

    fn _start_rest(mut self) {
        let server = HttpServer.new(self.config.host, self.config.port)

        server.post("/v1/predict", fn(ctx) {
            let inputs = _parse_tensor_inputs(ctx.body())
            let req = InferenceRequest.new(inputs)
            for mw in self._middleware { req = mw(req) }
            let resp = self._engine.predict(req)
            ctx.json(200, _serialize_response(resp))
        })

        server.post("/v1/predict/batch", fn(ctx) {
            let batch = _parse_batch_request(ctx.body())
            let resp = self._engine.predict_batch(batch)
            ctx.json(200, _serialize_batch_response(resp))
        })

        server.get("/v1/health", fn(ctx) {
            ctx.json(200, {
                "status": self._health.to_string(),
                "avg_latency_ms": self._engine.avg_latency_ms(),
                "throughput_rps": self._engine.throughput_rps()
            })
        })

        server.get("/v1/models", fn(ctx) {
            let models = self._registry.list_models().map(fn(m) {
                return {"name": m.name, "version": m.version, "status": m.status.to_string()}
            })
            ctx.json(200, {"models": models})
        })

        server.start()
    }

    fn _start_grpc(self) {
        let server = GrpcServer.new(self.config.host, self.config.port)
        server.register_service("InferenceService", {
            "Predict": fn(req_bytes) {
                let inputs = protobuf_decode_tensors(req_bytes)
                let req = InferenceRequest.new(inputs)
                let resp = self._engine.predict(req)
                return protobuf_encode_response(resp)
            }
        })
        server.start()
    }

    fn _start_ws(self) {
        let server = WebSocketServer.new(self.config.host, self.config.port)
        server.on_message(fn(ws, data) {
            let inputs = json_decode_tensors(data)
            let req = InferenceRequest.new(inputs)
            let resp = self._engine.predict(req)
            ws.send(json_encode_response(resp))
        })
        server.start()
    }

    pub fn stop(mut self) {
        self._running = false
        self._health = HealthStatus.Unhealthy
    }

    pub fn health(self) -> HealthStatus {
        return self._health
    }
}

fn _parse_tensor_inputs(body: Map[String, Any]) -> Map[String, Tensor] {
    let inputs = {}
    for (name, data) in body["inputs"] {
        inputs[name] = Tensor.from_nested_list(data)
    }
    return inputs
}

fn _serialize_response(resp: InferenceResponse) -> Map[String, Any] {
    let outputs = {}
    for (name, tensor) in resp.outputs {
        outputs[name] = tensor.to_list()
    }
    return {
        "request_id": resp.request_id,
        "outputs": outputs,
        "latency_ms": resp.latency_ms
    }
}

fn _parse_batch_request(body: Map[String, Any]) -> BatchRequest {
    let batch = BatchRequest.new()
    for item in body["requests"] {
        batch.add(InferenceRequest.new(_parse_tensor_inputs(item)))
    }
    return batch
}

fn _serialize_batch_response(resp: BatchResponse) -> Map[String, Any] {
    return {
        "responses": resp.responses.map(fn(r) { return _serialize_response(r) }),
        "total_latency_ms": resp.total_latency_ms
    }
}

// ── Edge Runtime ───────────────────────────────────────────────────

pub class EdgeRuntime {
    pub model_path: String
    pub device: Device
    pub quantized: Bool
    _model: Any?
    _engine: InferenceEngine?

    pub fn new(model_path: String, device: Device = Device.CPU, quantized: Bool = false) -> Self {
        return Self {
            model_path: model_path,
            device: device,
            quantized: quantized,
            _model: nil,
            _engine: nil
        }
    }

    pub fn load(mut self) -> Self {
        self._model = deserialize_from_file(self.model_path)
        self._model.to(self.device)
        self._model.eval()
        self._engine = InferenceEngine.new(self._model, self.device, max_batch_size: 1)
        return self
    }

    pub fn predict(self, inputs: Map[String, Tensor]) -> Map[String, Tensor] {
        let req = InferenceRequest.new(inputs)
        let resp = self._engine.predict(req)
        return resp.outputs
    }

    pub fn benchmark(self, inputs: Map[String, Tensor], n_runs: Int = 100) -> Map[String, Float] {
        let latencies = []
        for _ in range(n_runs) {
            let start = time_now_ms()
            self.predict(inputs)
            latencies.append((time_now_ms() - start).to_float())
        }
        latencies.sort()
        return {
            "mean_ms": latencies.sum() / n_runs.to_float(),
            "p50_ms": latencies[n_runs / 2],
            "p95_ms": latencies[(n_runs * 95) / 100],
            "p99_ms": latencies[(n_runs * 99) / 100],
            "min_ms": latencies[0],
            "max_ms": latencies[n_runs - 1]
        }
    }
}

// ── Convenience ────────────────────────────────────────────────────

pub fn serve(model: Any, host: String = "0.0.0.0", port: Int = 8080, device: Device = Device.CPU) -> ServingServer {
    let engine = InferenceEngine.new(model, device)
    let config = ServeConfig.new(host, port)
    let server = ServingServer.new(config, engine)
    server.start()
    return server
}

pub fn serve_edge(model_path: String, device: Device = Device.CPU) -> EdgeRuntime {
    return EdgeRuntime.new(model_path, device).load()
}

export {
    ServeProtocol, InferenceMode, ModelStatus, HealthStatus,
    InferenceRequest, InferenceResponse, BatchRequest, BatchResponse,
    ModelInfo, ModelRegistry,
    Preprocessor, Postprocessor,
    InferenceEngine, DynamicBatcher,
    ABTestConfig, ABTestRouter,
    ServeConfig, ServingServer,
    EdgeRuntime,
    serve, serve_edge
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
