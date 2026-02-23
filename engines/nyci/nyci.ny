// NyCI - Continuous Integration Engine
// Provides: Pipeline DSL, build automation, test orchestration, artifact generation
// Competes with: Jenkins, GitHub Actions, GitLab CI, CircleCI

use std::collections::HashMap
use std::process

// =============================================================================
// Pipeline Definition DSL
// =============================================================================

enum StageStatus {
    Pending,
    Running,
    Success,
    Failed,
    Skipped
}

struct PipelineStage {
    name: String,
    steps: Vec<PipelineStep>,
    status: StageStatus,
    duration_ms: u64,
    depends_on: Vec<String>
}

struct PipelineStep {
    name: String,
    command: String,
    env: HashMap<String, String>,
    working_dir: Option<String>,
    timeout_seconds: Option<u64>
}

struct Pipeline {
    name: String,
    trigger: PipelineTrigger,
    stages: Vec<PipelineStage>,
    environment: HashMap<String, String>,
    artifacts: Vec<Artifact>
}

enum PipelineTrigger {
    Push(String),          // Branch name
    PullRequest,
    Schedule(String),      // Cron expression
    Manual
}

struct Artifact {
    name: String,
    paths: Vec<String>,
    retention_days: u32
}

class PipelineBuilder {
    pipeline: Pipeline
    
    fn new(name: String) -> PipelineBuilder {
        return PipelineBuilder {
            pipeline: Pipeline {
                name,
                trigger: PipelineTrigger::Manual,
                stages: Vec::new(),
                environment: HashMap::new(),
                artifacts: Vec::new()
            }
        }
    }
    
    fn on_push(&mut self, branch: String) -> &mut PipelineBuilder {
        self.pipeline.trigger = PipelineTrigger::Push(branch)
        return self
    }
    
    fn on_pr(&mut self) -> &mut PipelineBuilder {
        self.pipeline.trigger = PipelineTrigger::PullRequest
        return self
    }
    
    fn on_schedule(&mut self, cron: String) -> &mut PipelineBuilder {
        self.pipeline.trigger = PipelineTrigger::Schedule(cron)
        return self
    }
    
    fn add_stage(&mut self, name: String) -> StageBuilder {
        return StageBuilder::new(self, name)
    }
    
    fn set_env(&mut self, key: String, value: String) -> &mut PipelineBuilder {
        self.pipeline.environment.insert(key, value)
        return self
    }
    
    fn add_artifact(&mut self, name: String, paths: Vec<String>, retention_days: u32) -> &mut PipelineBuilder {
        self.pipeline.artifacts.push(Artifact { name, paths, retention_days })
        return self
    }
    
    fn build(&self) -> Pipeline {
        return self.pipeline.clone()
    }
}

class StageBuilder<'a> {
    pipeline_builder: &'a mut PipelineBuilder,
    stage: PipelineStage
    
    fn new(builder: &'a mut PipelineBuilder, name: String) -> StageBuilder<'a> {
        return StageBuilder {
            pipeline_builder: builder,
            stage: PipelineStage {
                name,
                steps: Vec::new(),
                status: StageStatus::Pending,
                duration_ms: 0,
                depends_on: Vec::new()
            }
        }
    }
    
    fn add_step(&mut self, name: String, command: String) -> &mut StageBuilder<'a> {
        self.stage.steps.push(PipelineStep {
            name,
            command,
            env: HashMap::new(),
            working_dir: None,
            timeout_seconds: None
        })
        return self
    }
    
    fn depends_on(&mut self, stage_name: String) -> &mut StageBuilder<'a> {
        self.stage.depends_on.push(stage_name)
        return self
    }
    
    fn finish(&mut self) -> &mut PipelineBuilder {
        self.pipeline_builder.pipeline.stages.push(self.stage.clone())
        return self.pipeline_builder
    }
}

// =============================================================================
// Build Automation
// =============================================================================

struct BuildConfig {
    source_dir: String,
    output_dir: String,
    build_command: String,
    pre_build: Vec<String>,
    post_build: Vec<String>
}

struct BuildResult {
    success: bool,
    exit_code: i32,
    output: String,
    errors: String,
    duration_ms: u64,
    artifacts: Vec<String>
}

class BuildAutomation {
    fn run_build(&self, config: &BuildConfig) -> Result<BuildResult, String> {
        let start = std::time::now()
        
        // Run pre-build steps
        for cmd in &config.pre_build {
            self.execute_command(cmd, &config.source_dir)?
        }
        
        // Run main build
        let build_output = self.execute_command(&config.build_command, &config.source_dir)?
        
        // Run post-build steps
        for cmd in &config.post_build {
            self.execute_command(cmd, &config.source_dir)?
        }
        
        let duration = std::time::now() - start
        
        // Collect artifacts
        let artifacts = self.collect_artifacts(&config.output_dir)?
        
        return Ok(BuildResult {
            success: true,
            exit_code: 0,
            output: build_output,
            errors: String::new(),
            duration_ms: duration.as_millis(),
            artifacts
        })
    }
    
    fn execute_command(&self, command: &String, working_dir: &String) -> Result<String, String> {
        let output = process::Command::new("sh")
            .arg("-c")
            .arg(command)
            .current_dir(working_dir)
            .output()
            .map_err(|e| format!("Command failed: {}", e))?
        
        if output.status.success() {
            return Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            return Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    }
    
    fn collect_artifacts(&self, output_dir: &String) -> Result<Vec<String>, String> {
        let artifacts = Vec::new()
        
        // Walk output directory and collect files
        let paths = std::fs::read_dir(output_dir)
            .map_err(|e| format!("Failed to read output dir: {}", e))?
        
        for entry in paths {
            if let Ok(entry) = entry {
                artifacts.push(entry.path().to_string_lossy().to_string())
            }
        }
        
        return Ok(artifacts)
    }
}

// =============================================================================
// Test Orchestration
// =============================================================================

enum TestStatus {
    Passed,
    Failed,
    Skipped,
    Error
}

struct TestResult {
    name: String,
    status: TestStatus,
    duration_ms: u64,
    message: Option<String>
}

struct TestSuite {
    name: String,
    tests: Vec<TestResult>,
    total_passed: u32,
    total_failed: u32,
    total_skipped: u32
}

class TestOrchestrator {
    fn run_tests(&self, test_command: String, working_dir: String) -> Result<TestSuite, String> {
        let start = std::time::now()
        
        let output = process::Command::new("sh")
            .arg("-c")
            .arg(&test_command)
            .current_dir(&working_dir)
            .output()
            .map_err(|e| format!("Test execution failed: {}", e))?
        
        let duration = std::time::now() - start
        
        // Parse test output
        let test_results = self.parse_test_output(&String::from_utf8_lossy(&output.stdout).to_string())
        
        let total_passed = test_results.iter().filter(|t| matches!(t.status, TestStatus::Passed)).count() as u32
        let total_failed = test_results.iter().filter(|t| matches!(t.status, TestStatus::Failed)).count() as u32
        let total_skipped = test_results.iter().filter(|t| matches!(t.status, TestStatus::Skipped)).count() as u32
        
        return Ok(TestSuite {
            name: "Test Suite".to_string(),
            tests: test_results,
            total_passed,
            total_failed,
            total_skipped
        })
    }
    
    fn parse_test_output(&self, output: &String) -> Vec<TestResult> {
        let tests = Vec::new()
        
        // Simple parser - look for test patterns
        for line in output.lines() {
            if line.contains("PASSED") {
                tests.push(TestResult {
                    name: line.to_string(),
                    status: TestStatus::Passed,
                    duration_ms: 0,
                    message: None
                })
            } else if line.contains("FAILED") {
                tests.push(TestResult {
                    name: line.to_string(),
                    status: TestStatus::Failed,
                    duration_ms: 0,
                    message: Some("Test failed".to_string())
                })
            }
        }
        
        return tests
    }
    
    fn run_parallel_tests(&self, test_commands: Vec<String>, working_dir: String, parallelism: usize) -> Result<Vec<TestSuite>, String> {
        let results = Vec::new()
        
        // Run tests in parallel
        let handles = Vec::new()
        
        for command in test_commands {
            let wd = working_dir.clone()
            let handle = std::thread::spawn(move || {
                let orchestrator = TestOrchestrator {}
                return orchestrator.run_tests(command, wd)
            })
            handles.push(handle)
        }
        
        for handle in handles {
            if let Ok(suite) = handle.join() {
                if let Ok(suite) = suite {
                    results.push(suite)
                }
            }
        }
        
        return Ok(results)
    }
}

// =============================================================================
// Artifact Generation
// =============================================================================

struct ArtifactMetadata {
    name: String,
    version: String,
    build_number: u32,
    commit_sha: String,
    build_timestamp: u64,
    size_bytes: u64
}

class ArtifactGenerator {
    output_dir: String
    
    fn new(output_dir: String) -> ArtifactGenerator {
        return ArtifactGenerator { output_dir }
    }
    
    fn generate(&self, sources: Vec<String>, artifact_name: String, metadata: ArtifactMetadata) -> Result<String, String> {
        let artifact_path = format!("{}/{}", self.output_dir, artifact_name)
        
        // Create output directory
        std::fs::create_dir_all(&self.output_dir)
            .map_err(|e| format!("Failed to create output dir: {}", e))?
        
        // Package sources into artifact
        self.package_sources(&sources, &artifact_path)?
        
        // Write metadata
        self.write_metadata(&metadata, &artifact_path)?
        
        return Ok(artifact_path)
    }
    
    fn package_sources(&self, sources: &Vec<String>, output: &String) -> Result<(), String> {
        // Use tar or zip to package
        let mut cmd = vec!["tar", "czf", output]
        
        for source in sources {
            cmd.push(source)
        }
        
        let result = process::Command::new(cmd[0])
            .args(&cmd[1..])
            .output()
            .map_err(|e| format!("Packaging failed: {}", e))?
        
        if result.status.success() {
            return Ok(())
        } else {
            return Err(String::from_utf8_lossy(&result.stderr).to_string())
        }
    }
    
    fn write_metadata(&self, metadata: &ArtifactMetadata, artifact_path: &String) -> Result<(), String> {
        let metadata_path = format!("{}.metadata.json", artifact_path)
        
        let json = format!(
            r#"{{"name": "{}", "version": "{}", "build_number": {}, "commit_sha": "{}", "build_timestamp": {}, "size_bytes": {}}}"#,
            metadata.name, metadata.version, metadata.build_number, metadata.commit_sha, metadata.build_timestamp, metadata.size_bytes
        )
        
        std::fs::write(&metadata_path, json)
            .map_err(|e| format!("Failed to write metadata: {}", e))?
        
        return Ok(())
    }
}

// =============================================================================
// Version Tagging
// =============================================================================

class VersionTagger {
    fn tag_release(&self, version: String, message: String) -> Result<(), String> {
        // Git tag
        let output = process::Command::new("git")
            .args(&["tag", "-a", &version, "-m", &message])
            .output()
            .map_err(|e| format!("Git tag failed: {}", e))?
        
        if output.status.success() {
            return Ok(())
        } else {
            return Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    }
    
    fn push_tags(&self) -> Result<(), String> {
        let output = process::Command::new("git")
            .args(&["push", "--tags"])
            .output()
            .map_err(|e| format!("Git push failed: {}", e))?
        
        if output.status.success() {
            return Ok(())
        } else {
            return Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    }
    
    fn get_latest_tag(&self) -> Result<String, String> {
        let output = process::Command::new("git")
            .args(&["describe", "--tags", "--abbrev=0"])
            .output()
            .map_err(|e| format!("Git describe failed: {}", e))?
        
        if output.status.success() {
            return Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
        } else {
            return Err("No tags found".to_string())
        }
    }
}

// =============================================================================
// Rollback Automation
// =============================================================================

struct RollbackPoint {
    id: String,
    timestamp: u64,
    version: String,
    commit_sha: String,
    artifacts: Vec<String>
}

class RollbackManager {
    rollback_points: Vec<RollbackPoint>
    
    fn new() -> RollbackManager {
        return RollbackManager {
            rollback_points: Vec::new()
        }
    }
    
    fn create_checkpoint(&mut self, version: String, commit_sha: String, artifacts: Vec<String>) -> String {
        let id = format!("rb-{}", std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs())
        
        let point = RollbackPoint {
            id: id.clone(),
            timestamp: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
            version,
            commit_sha,
            artifacts
        }
        
        self.rollback_points.push(point)
        return id
    }
    
    fn rollback_to(&self, checkpoint_id: &String) -> Result<(), String> {
        let point = self.rollback_points.iter()
            .find(|p| &p.id == checkpoint_id)
            .ok_or("Checkpoint not found")?
        
        // Git reset to commit
        let output = process::Command::new("git")
            .args(&["reset", "--hard", &point.commit_sha])
            .output()
            .map_err(|e| format!("Git reset failed: {}", e))?
        
        if !output.status.success() {
            return Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
        
        // Restore artifacts
        for artifact in &point.artifacts {
            // Restore artifact from backup
        }
        
        return Ok(())
    }
}

// =============================================================================
// Pipeline Executor
// =============================================================================

class PipelineExecutor {
    fn execute(&self, pipeline: &Pipeline) -> Result<Vec<PipelineStage>, String> {
        let mut executed_stages = Vec::new()
        
        for stage in &pipeline.stages {
            // Check dependencies
            let deps_met = stage.depends_on.iter().all(|dep_name| {
                executed_stages.iter().any(|s: &PipelineStage| &s.name == dep_name && matches!(s.status, StageStatus::Success))
            })
            
            if !deps_met {
                let mut skipped_stage = stage.clone()
                skipped_stage.status = StageStatus::Skipped
                executed_stages.push(skipped_stage)
                continue
            }
            
            // Execute stage
            let start = std::time::now()
            let mut current_stage = stage.clone()
            current_stage.status = StageStatus::Running
            
            let mut all_success = true
            
            for step in &stage.steps {
                let result = self.execute_step(step, &pipeline.environment)
                
                if result.is_err() {
                    all_success = false
                    break
                }
            }
            
            let duration = std::time::now() - start
            current_stage.duration_ms = duration.as_millis()
            current_stage.status = if all_success { StageStatus::Success } else { StageStatus::Failed }
            
            executed_stages.push(current_stage)
            
            if !all_success {
                break
            }
        }
        
        return Ok(executed_stages)
    }
    
    fn execute_step(&self, step: &PipelineStep, env: &HashMap<String, String>) -> Result<String, String> {
        let mut cmd = process::Command::new("sh")
        cmd.arg("-c").arg(&step.command)
        
        // Set environment
        for (key, value) in env {
            cmd.env(key, value)
        }
        for (key, value) in &step.env {
            cmd.env(key, value)
        }
        
        if let Some(wd) = &step.working_dir {
            cmd.current_dir(wd)
        }
        
        let output = cmd.output()
            .map_err(|e| format!("Step execution failed: {}", e))?
        
        if output.status.success() {
            return Ok(String::from_utf8_lossy(&output.stdout).to_string())
        } else {
            return Err(String::from_utf8_lossy(&output.stderr).to_string())
        }
    }
}

// =============================================================================
// Public API
// =============================================================================

pub fn create_pipeline(name: String) -> PipelineBuilder {
    return PipelineBuilder::new(name)
}

pub fn execute_pipeline(pipeline: &Pipeline) -> Result<Vec<PipelineStage>, String> {
    let executor = PipelineExecutor {}
    return executor.execute(pipeline)
}

pub fn create_build_automation() -> BuildAutomation {
    return BuildAutomation {}
}

pub fn create_test_orchestrator() -> TestOrchestrator {
    return TestOrchestrator {}
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
