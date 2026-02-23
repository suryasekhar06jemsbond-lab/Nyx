// NyTrack Engine - Dataset & Experiment Tracking for Nyx ML
// Versioning, reproducibility, experiment logging, hyperparameter recording, model comparison

import nytensor { Tensor }

// ── Experiment Status ──────────────────────────────────────────────

pub enum ExperimentStatus {
    Created,
    Running,
    Completed,
    Failed,
    Cancelled
}

pub enum ArtifactType {
    Model,
    Dataset,
    Config,
    Plot,
    Log,
    Checkpoint,
    Custom
}

// ── Metric Entry ───────────────────────────────────────────────────

pub class MetricEntry {
    pub name: String
    pub value: Float
    pub step: Int
    pub timestamp: Int
    pub tags: Map[String, String]

    pub fn new(name: String, value: Float, step: Int = 0) -> Self {
        return Self {
            name: name,
            value: value,
            step: step,
            timestamp: time_now_ms(),
            tags: {}
        }
    }
}

pub class MetricSeries {
    pub name: String
    pub entries: List[MetricEntry]

    pub fn new(name: String) -> Self {
        return Self { name: name, entries: [] }
    }

    pub fn add(mut self, value: Float, step: Int) {
        self.entries.append(MetricEntry.new(self.name, value, step))
    }

    pub fn values(self) -> List[Float] {
        return self.entries.map(fn(e) -> Float { return e.value })
    }

    pub fn steps(self) -> List[Int] {
        return self.entries.map(fn(e) -> Int { return e.step })
    }

    pub fn best(self, mode: String = "min") -> MetricEntry {
        if mode == "min" {
            return self.entries.min_by(fn(e) -> Float { return e.value })
        }
        return self.entries.max_by(fn(e) -> Float { return e.value })
    }

    pub fn last(self) -> MetricEntry {
        return self.entries[self.entries.len() - 1]
    }

    pub fn mean(self) -> Float {
        let sum = 0.0
        for e in self.entries { sum = sum + e.value }
        return sum / self.entries.len().to_float()
    }

    pub fn to_tensor(self) -> Tensor {
        return Tensor.from_list(self.values())
    }
}

// ── Hyperparameters ────────────────────────────────────────────────

pub class HyperParams {
    _params: Map[String, Any]

    pub fn new() -> Self {
        return Self { _params: {} }
    }

    pub fn set(mut self, key: String, value: Any) -> Self {
        self._params[key] = value
        return self
    }

    pub fn get(self, key: String) -> Any? {
        return self._params.get(key)
    }

    pub fn get_int(self, key: String, default: Int = 0) -> Int {
        let v = self._params.get(key)
        return if v != nil { v.to_int() } else { default }
    }

    pub fn get_float(self, key: String, default: Float = 0.0) -> Float {
        let v = self._params.get(key)
        return if v != nil { v.to_float() } else { default }
    }

    pub fn get_string(self, key: String, default: String = "") -> String {
        let v = self._params.get(key)
        return if v != nil { v.to_string() } else { default }
    }

    pub fn get_bool(self, key: String, default: Bool = false) -> Bool {
        let v = self._params.get(key)
        return if v != nil { v.to_bool() } else { default }
    }

    pub fn keys(self) -> List[String] {
        return self._params.keys()
    }

    pub fn to_map(self) -> Map[String, Any] {
        return self._params.clone()
    }

    pub fn from_map(params: Map[String, Any]) -> HyperParams {
        let hp = HyperParams.new()
        hp._params = params
        return hp
    }

    pub fn merge(self, other: HyperParams) -> HyperParams {
        let hp = HyperParams.new()
        hp._params = self._params.clone()
        for (k, v) in other._params {
            hp._params[k] = v
        }
        return hp
    }

    pub fn to_json(self) -> String {
        return json_encode(self._params)
    }

    pub fn from_json(json_str: String) -> HyperParams {
        let hp = HyperParams.new()
        hp._params = json_decode(json_str)
        return hp
    }
}

// ── Artifact ───────────────────────────────────────────────────────

pub class Artifact {
    pub name: String
    pub artifact_type: ArtifactType
    pub path: String
    pub size_bytes: Int
    pub hash: String
    pub metadata: Map[String, String]
    pub created_at: Int

    pub fn new(name: String, artifact_type: ArtifactType, path: String) -> Self {
        return Self {
            name: name,
            artifact_type: artifact_type,
            path: path,
            size_bytes: 0,
            hash: "",
            metadata: {},
            created_at: time_now_ms()
        }
    }

    pub fn with_metadata(mut self, key: String, value: String) -> Self {
        self.metadata[key] = value
        return self
    }

    pub fn compute_hash(mut self) -> Self {
        self.hash = sha256_file(self.path)
        self.size_bytes = file_size(self.path)
        return self
    }
}

// ── Checkpoint ─────────────────────────────────────────────────────

pub class Checkpoint {
    pub epoch: Int
    pub step: Int
    pub metrics: Map[String, Float]
    pub path: String
    pub timestamp: Int

    pub fn new(epoch: Int, step: Int, path: String) -> Self {
        return Self {
            epoch: epoch,
            step: step,
            metrics: {},
            path: path,
            timestamp: time_now_ms()
        }
    }

    pub fn with_metric(mut self, name: String, value: Float) -> Self {
        self.metrics[name] = value
        return self
    }
}

pub class CheckpointManager {
    pub directory: String
    pub max_to_keep: Int
    pub save_best_only: Bool
    pub monitor: String
    pub mode: String
    _checkpoints: List[Checkpoint]
    _best_value: Float

    pub fn new(directory: String, max_to_keep: Int = 5, save_best_only: Bool = false, monitor: String = "val_loss", mode: String = "min") -> Self {
        ensure_dir(directory)
        return Self {
            directory: directory,
            max_to_keep: max_to_keep,
            save_best_only: save_best_only,
            monitor: monitor,
            mode: mode,
            _checkpoints: [],
            _best_value: if mode == "min" { Float.MAX } else { Float.MIN }
        }
    }

    pub fn save(mut self, model: Any, epoch: Int, step: Int, metrics: Map[String, Float]) -> Checkpoint? {
        if self.save_best_only {
            let current = metrics.get(self.monitor)
            if current == nil { return nil }
            let improved = if self.mode == "min" { current < self._best_value } else { current > self._best_value }
            if !improved { return nil }
            self._best_value = current
        }

        let path = self.directory + "/checkpoint_epoch" + epoch.to_string() + "_step" + step.to_string() + ".ckpt"
        serialize_to_file(model, path)

        let ckpt = Checkpoint.new(epoch, step, path)
        for (k, v) in metrics {
            ckpt.with_metric(k, v)
        }
        self._checkpoints.append(ckpt)

        while self._checkpoints.len() > self.max_to_keep {
            let oldest = self._checkpoints.remove(0)
            if file_exists(oldest.path) {
                file_delete(oldest.path)
            }
        }

        return ckpt
    }

    pub fn load_best(self) -> (Any, Checkpoint)? {
        if self._checkpoints.len() == 0 { return nil }
        let best = self._checkpoints[0]
        for ckpt in self._checkpoints {
            let val = ckpt.metrics.get(self.monitor)
            let best_val = best.metrics.get(self.monitor)
            if val != nil && best_val != nil {
                let better = if self.mode == "min" { val < best_val } else { val > best_val }
                if better { best = ckpt }
            }
        }
        let model = deserialize_from_file(best.path)
        return (model, best)
    }

    pub fn load_latest(self) -> (Any, Checkpoint)? {
        if self._checkpoints.len() == 0 { return nil }
        let latest = self._checkpoints[self._checkpoints.len() - 1]
        let model = deserialize_from_file(latest.path)
        return (model, latest)
    }

    pub fn list_checkpoints(self) -> List[Checkpoint] {
        return self._checkpoints
    }
}

// ── Run (single training run) ──────────────────────────────────────

pub class Run {
    pub id: String
    pub name: String
    pub status: ExperimentStatus
    pub params: HyperParams
    pub tags: Map[String, String]
    pub start_time: Int
    pub end_time: Int?
    _metrics: Map[String, MetricSeries]
    _artifacts: List[Artifact]
    _log_entries: List[String]
    _base_dir: String

    pub fn new(name: String, base_dir: String = "./runs") -> Self {
        let id = generate_uuid()
        let run_dir = base_dir + "/" + id
        ensure_dir(run_dir)
        return Self {
            id: id,
            name: name,
            status: ExperimentStatus.Created,
            params: HyperParams.new(),
            tags: {},
            start_time: time_now_ms(),
            end_time: nil,
            _metrics: {},
            _artifacts: [],
            _log_entries: [],
            _base_dir: run_dir
        }
    }

    pub fn start(mut self) -> Self {
        self.status = ExperimentStatus.Running
        self.start_time = time_now_ms()
        self._log("Run started: " + self.name)
        return self
    }

    pub fn end(mut self, status: ExperimentStatus = ExperimentStatus.Completed) {
        self.status = status
        self.end_time = time_now_ms()
        self._log("Run ended with status: " + status.to_string())
        self._save_state()
    }

    pub fn set_params(mut self, params: HyperParams) -> Self {
        self.params = params
        return self
    }

    pub fn log_param(mut self, key: String, value: Any) {
        self.params.set(key, value)
    }

    pub fn log_params(mut self, params: Map[String, Any]) {
        for (k, v) in params {
            self.params.set(k, v)
        }
    }

    pub fn log_metric(mut self, name: String, value: Float, step: Int = -1) {
        if !self._metrics.contains(name) {
            self._metrics[name] = MetricSeries.new(name)
        }
        let actual_step = if step == -1 { self._metrics[name].entries.len() } else { step }
        self._metrics[name].add(value, actual_step)
    }

    pub fn log_metrics(mut self, metrics: Map[String, Float], step: Int = -1) {
        for (name, value) in metrics {
            self.log_metric(name, value, step)
        }
    }

    pub fn get_metric(self, name: String) -> MetricSeries? {
        return self._metrics.get(name)
    }

    pub fn log_artifact(mut self, name: String, path: String, artifact_type: ArtifactType = ArtifactType.Custom) {
        let artifact = Artifact.new(name, artifact_type, path).compute_hash()
        self._artifacts.append(artifact)
    }

    pub fn set_tag(mut self, key: String, value: String) {
        self.tags[key] = value
    }

    fn _log(mut self, message: String) {
        let entry = "[" + time_format(time_now_ms()) + "] " + message
        self._log_entries.append(entry)
    }

    fn _save_state(self) {
        let state = {
            "id": self.id,
            "name": self.name,
            "status": self.status.to_string(),
            "params": self.params.to_map(),
            "tags": self.tags,
            "start_time": self.start_time,
            "end_time": self.end_time,
            "metrics": {},
            "artifacts": self._artifacts.len()
        }
        for (name, series) in self._metrics {
            state["metrics"][name] = series.values()
        }
        file_write(self._base_dir + "/run_state.json", json_encode(state))
        file_write(self._base_dir + "/log.txt", self._log_entries.join("\n"))
    }

    pub fn duration_ms(self) -> Int {
        let end = if self.end_time != nil { self.end_time } else { time_now_ms() }
        return end - self.start_time
    }

    pub fn summary(self) -> Map[String, Any] {
        let result = {
            "id": self.id,
            "name": self.name,
            "status": self.status.to_string(),
            "duration_ms": self.duration_ms(),
            "num_params": self.params.keys().len(),
            "num_metrics": self._metrics.len(),
            "num_artifacts": self._artifacts.len()
        }
        for (name, series) in self._metrics {
            let best = series.best("min")
            result["best_" + name] = best.value
            result["last_" + name] = series.last().value
        }
        return result
    }
}

// ── Experiment (group of runs) ─────────────────────────────────────

pub class Experiment {
    pub name: String
    pub description: String
    pub base_dir: String
    _runs: List[Run]
    _active_run: Run?

    pub fn new(name: String, description: String = "", base_dir: String = "./experiments") -> Self {
        let exp_dir = base_dir + "/" + name
        ensure_dir(exp_dir)
        return Self {
            name: name,
            description: description,
            base_dir: exp_dir,
            _runs: [],
            _active_run: nil
        }
    }

    pub fn start_run(mut self, run_name: String = "") -> Run {
        let name = if run_name == "" { "run_" + self._runs.len().to_string() } else { run_name }
        let run = Run.new(name, base_dir: self.base_dir + "/runs")
        run.start()
        self._runs.append(run)
        self._active_run = run
        return run
    }

    pub fn end_run(mut self, status: ExperimentStatus = ExperimentStatus.Completed) {
        if self._active_run != nil {
            self._active_run.end(status)
            self._active_run = nil
        }
    }

    pub fn active_run(self) -> Run? {
        return self._active_run
    }

    pub fn runs(self) -> List[Run] {
        return self._runs
    }

    pub fn get_run(self, id: String) -> Run? {
        for run in self._runs {
            if run.id == id { return run }
        }
        return nil
    }

    pub fn compare_runs(self, metric_name: String, mode: String = "min") -> List[Map[String, Any]] {
        let results = []
        for run in self._runs {
            let series = run.get_metric(metric_name)
            if series != nil {
                let best = series.best(mode)
                results.append({
                    "run_id": run.id,
                    "run_name": run.name,
                    "best_" + metric_name: best.value,
                    "best_step": best.step,
                    "params": run.params.to_map()
                })
            }
        }
        results.sort_by(fn(a, b) {
            if mode == "min" { return a["best_" + metric_name] < b["best_" + metric_name] }
            else { return a["best_" + metric_name] > b["best_" + metric_name] }
        })
        return results
    }

    pub fn best_run(self, metric_name: String, mode: String = "min") -> Run? {
        let comparison = self.compare_runs(metric_name, mode)
        if comparison.len() == 0 { return nil }
        return self.get_run(comparison[0]["run_id"])
    }

    pub fn summary(self) -> Map[String, Any] {
        return {
            "name": self.name,
            "description": self.description,
            "total_runs": self._runs.len(),
            "completed": self._runs.filter(fn(r) { return r.status == ExperimentStatus.Completed }).len(),
            "failed": self._runs.filter(fn(r) { return r.status == ExperimentStatus.Failed }).len(),
            "running": self._runs.filter(fn(r) { return r.status == ExperimentStatus.Running }).len()
        }
    }
}

// ── Dataset Versioning ─────────────────────────────────────────────

pub class DatasetVersion {
    pub name: String
    pub version: String
    pub hash: String
    pub path: String
    pub num_samples: Int
    pub schema_hash: String
    pub created_at: Int
    pub parent_version: String?
    pub tags: Map[String, String]

    pub fn new(name: String, version: String, path: String) -> Self {
        return Self {
            name: name,
            version: version,
            hash: "",
            path: path,
            num_samples: 0,
            schema_hash: "",
            created_at: time_now_ms(),
            parent_version: nil,
            tags: {}
        }
    }

    pub fn compute_hash(mut self) -> Self {
        self.hash = sha256_file(self.path)
        return self
    }
}

pub class DatasetRegistry {
    pub base_dir: String
    _versions: Map[String, List[DatasetVersion]]

    pub fn new(base_dir: String = "./dataset_registry") -> Self {
        ensure_dir(base_dir)
        return Self { base_dir: base_dir, _versions: {} }
    }

    pub fn register(mut self, version: DatasetVersion) {
        let key = version.name
        if !self._versions.contains(key) {
            self._versions[key] = []
        }
        version.compute_hash()
        self._versions[key].append(version)
        self._save_registry()
    }

    pub fn get_latest(self, name: String) -> DatasetVersion? {
        let versions = self._versions.get(name)
        if versions == nil || versions.len() == 0 { return nil }
        return versions[versions.len() - 1]
    }

    pub fn get_version(self, name: String, version: String) -> DatasetVersion? {
        let versions = self._versions.get(name)
        if versions == nil { return nil }
        for v in versions {
            if v.version == version { return v }
        }
        return nil
    }

    pub fn list_datasets(self) -> List[String] {
        return self._versions.keys()
    }

    pub fn list_versions(self, name: String) -> List[DatasetVersion] {
        return self._versions.get(name) ?? []
    }

    pub fn diff(self, name: String, v1: String, v2: String) -> Map[String, Any] {
        let ver1 = self.get_version(name, v1)
        let ver2 = self.get_version(name, v2)
        if ver1 == nil || ver2 == nil { return {"error": "version not found"} }
        return {
            "name": name,
            "v1": v1,
            "v2": v2,
            "hash_changed": ver1.hash != ver2.hash,
            "schema_changed": ver1.schema_hash != ver2.schema_hash,
            "samples_diff": ver2.num_samples - ver1.num_samples
        }
    }

    fn _save_registry(self) {
        let state = {}
        for (name, versions) in self._versions {
            state[name] = versions.map(fn(v) {
                return {
                    "version": v.version,
                    "hash": v.hash,
                    "path": v.path,
                    "num_samples": v.num_samples,
                    "created_at": v.created_at
                }
            })
        }
        file_write(self.base_dir + "/registry.json", json_encode(state))
    }
}

// ── Reproducibility ────────────────────────────────────────────────

pub class ReproConfig {
    pub seed: Int
    pub deterministic: Bool
    pub env_vars: Map[String, String]
    pub nyx_version: String
    pub engine_versions: Map[String, String]
    pub git_hash: String?

    pub fn new(seed: Int = 42) -> Self {
        return Self {
            seed: seed,
            deterministic: true,
            env_vars: {},
            nyx_version: nyx_version(),
            engine_versions: {},
            git_hash: git_head_hash()
        }
    }

    pub fn apply(self) {
        set_global_seed(self.seed)
        if self.deterministic {
            set_deterministic_mode(true)
        }
        for (k, v) in self.env_vars {
            set_env(k, v)
        }
    }

    pub fn save(self, path: String) {
        let state = {
            "seed": self.seed,
            "deterministic": self.deterministic,
            "env_vars": self.env_vars,
            "nyx_version": self.nyx_version,
            "engine_versions": self.engine_versions,
            "git_hash": self.git_hash
        }
        file_write(path, json_encode(state))
    }

    pub fn load(path: String) -> ReproConfig {
        let state = json_decode(file_read(path))
        let config = ReproConfig.new(seed: state["seed"])
        config.deterministic = state["deterministic"]
        config.env_vars = state["env_vars"]
        config.nyx_version = state["nyx_version"]
        config.engine_versions = state["engine_versions"]
        config.git_hash = state["git_hash"]
        return config
    }
}

// ── EarlyStopping ──────────────────────────────────────────────────

pub class EarlyStopping {
    pub monitor: String
    pub patience: Int
    pub min_delta: Float
    pub mode: String
    _counter: Int
    _best_value: Float
    pub stopped: Bool

    pub fn new(monitor: String = "val_loss", patience: Int = 10, min_delta: Float = 0.0, mode: String = "min") -> Self {
        return Self {
            monitor: monitor,
            patience: patience,
            min_delta: min_delta,
            mode: mode,
            _counter: 0,
            _best_value: if mode == "min" { Float.MAX } else { Float.MIN },
            stopped: false
        }
    }

    pub fn check(mut self, metrics: Map[String, Float]) -> Bool {
        let current = metrics.get(self.monitor)
        if current == nil { return false }

        let improved = if self.mode == "min" {
            current < self._best_value - self.min_delta
        } else {
            current > self._best_value + self.min_delta
        }

        if improved {
            self._best_value = current
            self._counter = 0
        } else {
            self._counter = self._counter + 1
            if self._counter >= self.patience {
                self.stopped = true
                return true
            }
        }
        return false
    }

    pub fn reset(mut self) {
        self._counter = 0
        self._best_value = if self.mode == "min" { Float.MAX } else { Float.MIN }
        self.stopped = false
    }
}

// ── Logger ─────────────────────────────────────────────────────────

pub class TrainingLogger {
    pub log_dir: String
    _entries: List[Map[String, Any]]

    pub fn new(log_dir: String = "./logs") -> Self {
        ensure_dir(log_dir)
        return Self { log_dir: log_dir, _entries: [] }
    }

    pub fn log(mut self, epoch: Int, metrics: Map[String, Float], extra: Map[String, Any] = {}) {
        let entry = {
            "epoch": epoch,
            "timestamp": time_now_ms(),
            "metrics": metrics
        }
        for (k, v) in extra {
            entry[k] = v
        }
        self._entries.append(entry)
        self._flush()
    }

    pub fn log_text(mut self, message: String) {
        let entry = {
            "type": "text",
            "message": message,
            "timestamp": time_now_ms()
        }
        self._entries.append(entry)
    }

    fn _flush(self) {
        file_write(self.log_dir + "/training_log.json", json_encode(self._entries))
    }

    pub fn print_summary(self) {
        if self._entries.len() == 0 { return }
        let last = self._entries[self._entries.len() - 1]
        print("Epoch: " + last["epoch"].to_string())
        for (name, value) in last["metrics"] {
            print("  " + name + ": " + value.to_string())
        }
    }
}

// ── Progress Bar ───────────────────────────────────────────────────

pub class ProgressBar {
    pub total: Int
    pub width: Int
    pub prefix: String
    _current: Int

    pub fn new(total: Int, width: Int = 40, prefix: String = "") -> Self {
        return Self { total: total, width: width, prefix: prefix, _current: 0 }
    }

    pub fn update(mut self, n: Int = 1) {
        self._current = self._current + n
        let pct = self._current.to_float() / self.total.to_float()
        let filled = (pct * self.width.to_float()).to_int()
        let bar = "█" * filled + "░" * (self.width - filled)
        let msg = self.prefix + " |" + bar + "| " + (pct * 100.0).to_int().to_string() + "% " + self._current.to_string() + "/" + self.total.to_string()
        print_inline("\r" + msg)
    }

    pub fn finish(self) {
        print("")
    }
}

export {
    ExperimentStatus, ArtifactType,
    MetricEntry, MetricSeries,
    HyperParams,
    Artifact, Checkpoint, CheckpointManager,
    Run, Experiment,
    DatasetVersion, DatasetRegistry,
    ReproConfig, EarlyStopping,
    TrainingLogger, ProgressBar
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
