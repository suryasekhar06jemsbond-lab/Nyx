// NyShell - Advanced Shell Engine
// Provides: Command parsing, pipeline operators, native piping, REPL, structured output
// Competes with: Bash, Zsh, Fish, PowerShell

use std::collections::{HashMap, Vec}
use std::io
use std::process

// =============================================================================
// Core Shell Types
// =============================================================================

enum ShellToken {
    Command(String),
    Argument(String),
    Pipe,              // |
    Redirect(String),  // >, >>, <
    And,               // &&
    Or,                // ||
    Semicolon,         // ;
    Background,        // &
    Substitute(String) // $(command)
}

enum RedirectType {
    StdoutWrite,       // >
    StdoutAppend,      // >>
    StdinRead,         // <
    StderrWrite,       // 2>
    StderrAppend       // 2>>
}

struct CommandNode {
    program: String,
    args: Vec<String>,
    stdin_redirect: Option<String>,
    stdout_redirect: Option<(RedirectType, String)>,
    stderr_redirect: Option<(RedirectType, String)>,
    env_overrides: HashMap<String, String>
}

enum PipelineOp {
    Pipe,       // | - stdout to stdin
    And,        // && - run if previous succeeded
    Or,         // || - run if previous failed
    Sequential  // ; - run regardless
}

struct Pipeline {
    commands: Vec<CommandNode>,
    operators: Vec<PipelineOp>,
    run_background: bool
}

// =============================================================================
// Command Parser
// =============================================================================

class CommandParser {
    fn new() -> CommandParser {
        return CommandParser {}
    }
    
    fn parse(&self, input: String) -> Result<Pipeline, String> {
        let tokens = self.tokenize(input)?
        let commands = Vec::new()
        let operators = Vec::new()
        let run_background = false
        
        let current_cmd = None
        let current_args = Vec::new()
        
        for token in tokens {
            match token {
                ShellToken::Command(cmd) => {
                    if current_cmd.is_some() {
                        commands.push(self.build_command(current_cmd.unwrap(), current_args))
                        current_args = Vec::new()
                    }
                    current_cmd = Some(cmd)
                }
                ShellToken::Argument(arg) => {
                    current_args.push(arg)
                }
                ShellToken::Pipe => {
                    commands.push(self.build_command(current_cmd.unwrap(), current_args))
                    operators.push(PipelineOp::Pipe)
                    current_cmd = None
                    current_args = Vec::new()
                }
                ShellToken::And => {
                    commands.push(self.build_command(current_cmd.unwrap(), current_args))
                    operators.push(PipelineOp::And)
                    current_cmd = None
                    current_args = Vec::new()
                }
                ShellToken::Or => {
                    commands.push(self.build_command(current_cmd.unwrap(), current_args))
                    operators.push(PipelineOp::Or)
                    current_cmd = None
                    current_args = Vec::new()
                }
                ShellToken::Semicolon => {
                    commands.push(self.build_command(current_cmd.unwrap(), current_args))
                    operators.push(PipelineOp::Sequential)
                    current_cmd = None
                    current_args = Vec::new()
                }
                ShellToken::Background => {
                    run_background = true
                }
                _ => {}
            }
        }
        
        if current_cmd.is_some() {
            commands.push(self.build_command(current_cmd.unwrap(), current_args))
        }
        
        return Ok(Pipeline { commands, operators, run_background })
    }
    
    fn tokenize(&self, input: String) -> Result<Vec<ShellToken>, String> {
        let tokens = Vec::new()
        let chars = input.chars()
        let current = String::new()
        let in_quotes = false
        let quote_char = '\0'
        
        // Simplified tokenizer
        let words = input.split_whitespace()
        for word in words {
            if word == "|" {
                tokens.push(ShellToken::Pipe)
            } else if word == "&&" {
                tokens.push(ShellToken::And)
            } else if word == "||" {
                tokens.push(ShellToken::Or)
            } else if word == ";" {
                tokens.push(ShellToken::Semicolon)
            } else if word == "&" {
                tokens.push(ShellToken::Background)
            } else if word.starts_with(">") {
                tokens.push(ShellToken::Redirect(word.to_string()))
            } else if tokens.is_empty() || matches!(tokens.last(), Some(ShellToken::Pipe) | Some(ShellToken::And) | Some(ShellToken::Or) | Some(ShellToken::Semicolon)) {
                tokens.push(ShellToken::Command(word.to_string()))
            } else {
                tokens.push(ShellToken::Argument(word.to_string()))
            }
        }
        
        return Ok(tokens)
    }
    
    fn build_command(&self, program: String, args: Vec<String>) -> CommandNode {
        return CommandNode {
            program,
            args,
            stdin_redirect: None,
            stdout_redirect: None,
            stderr_redirect: None,
            env_overrides: HashMap::new()
        }
    }
}

// =============================================================================
// Pipeline Executor
// =============================================================================

struct CommandResult {
    exit_code: i32,
    stdout: String,
    stderr: String,
    duration_ms: u64
}

class PipelineExecutor {
    fn new() -> PipelineExecutor {
        return PipelineExecutor {}
    }
    
    fn execute(&self, pipeline: Pipeline) -> Result<Vec<CommandResult>, String> {
        let results = Vec::new()
        let previous_stdout = None
        let should_continue = true
        
        for (i, cmd) in pipeline.commands.iter().enumerate() {
            if !should_continue {
                break
            }
            
            let operator = if i > 0 { pipeline.operators.get(i - 1) } else { None }
            
            let result = self.execute_command(cmd, previous_stdout)?
            
            // Handle operators
            match operator {
                Some(PipelineOp::And) => {
                    if result.exit_code != 0 {
                        should_continue = false
                    }
                }
                Some(PipelineOp::Or) => {
                    if result.exit_code == 0 {
                        should_continue = false
                    }
                }
                Some(PipelineOp::Pipe) => {
                    previous_stdout = Some(result.stdout.clone())
                }
                _ => {}
            }
            
            results.push(result)
        }
        
        return Ok(results)
    }
    
    fn execute_command(&self, cmd: &CommandNode, stdin_data: Option<String>) -> Result<CommandResult, String> {
        let start = std::time::now()
        
        // Spawn process
        let mut process = process::Command::new(&cmd.program)
        
        for arg in &cmd.args {
            process.arg(arg)
        }
        
        // Handle stdin
        if stdin_data.is_some() {
            process.stdin(process::Stdio::piped())
        }
        
        // Set environment overrides
        for (key, value) in &cmd.env_overrides {
            process.env(key, value)
        }
        
        let output = process.output()?
        
        let duration = std::time::now() - start
        
        return Ok(CommandResult {
            exit_code: output.status.code().unwrap_or(-1),
            stdout: String::from_utf8_lossy(&output.stdout).to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).to_string(),
            duration_ms: duration.as_millis()
        })
    }
}

// =============================================================================
// Interactive REPL
// =============================================================================

struct ReplState {
    history: Vec<String>,
    variables: HashMap<String, String>,
    aliases: HashMap<String, String>,
    last_exit_code: i32,
    prompt: String
}

class ShellRepl {
    state: ReplState,
    parser: CommandParser,
    executor: PipelineExecutor
    
    fn new() -> ShellRepl {
        return ShellRepl {
            state: ReplState {
                history: Vec::new(),
                variables: HashMap::new(),
                aliases: HashMap::new(),
                last_exit_code: 0,
                prompt: "nysh> ".to_string()
            },
            parser: CommandParser::new(),
            executor: PipelineExecutor::new()
        }
    }
    
    fn run(&mut self) {
        println!("NyShell v1.0 - Type 'exit' to quit")
        
        loop {
            print!("{}", self.state.prompt)
            io::flush()
            
            let input = io::read_line()
            
            if input.trim() == "exit" {
                break
            }
            
            if input.trim().is_empty() {
                continue
            }
            
            self.state.history.push(input.clone())
            
            // Handle built-in commands
            if self.handle_builtin(&input) {
                continue
            }
            
            // Parse and execute
            match self.parser.parse(input) {
                Ok(pipeline) => {
                    match self.executor.execute(pipeline) {
                        Ok(results) => {
                            for result in results {
                                if !result.stdout.is_empty() {
                                    print!("{}", result.stdout)
                                }
                                if !result.stderr.is_empty() {
                                    eprint!("{}", result.stderr)
                                }
                                self.state.last_exit_code = result.exit_code
                            }
                        }
                        Err(e) => {
                            eprintln!("Execution error: {}", e)
                        }
                    }
                }
                Err(e) => {
                    eprintln!("Parse error: {}", e)
                }
            }
        }
    }
    
    fn handle_builtin(&mut self, input: &String) -> bool {
        let parts = input.split_whitespace().collect::<Vec<_>>()
        
        if parts.is_empty() {
            return false
        }
        
        match parts[0] {
            "cd" => {
                if parts.len() > 1 {
                    std::env::set_current_dir(parts[1])
                }
                return true
            }
            "export" => {
                if parts.len() > 1 {
                    let kv = parts[1].split('=').collect::<Vec<_>>()
                    if kv.len() == 2 {
                        self.state.variables.insert(kv[0].to_string(), kv[1].to_string())
                        std::env::set_var(kv[0], kv[1])
                    }
                }
                return true
            }
            "alias" => {
                if parts.len() > 1 {
                    let kv = parts[1].split('=').collect::<Vec<_>>()
                    if kv.len() == 2 {
                        self.state.aliases.insert(kv[0].to_string(), kv[1].to_string())
                    }
                }
                return true
            }
            "history" => {
                for (i, cmd) in self.state.history.iter().enumerate() {
                    println!("{}: {}", i + 1, cmd)
                }
                return true
            }
            _ => return false
        }
    }
}

// =============================================================================
// Structured Output (JSON-native)
// =============================================================================

class StructuredOutput {
    fn format_json(&self, result: &CommandResult) -> String {
        return format!(
            r#"{{"exit_code": {}, "stdout": "{}", "stderr": "{}", "duration_ms": {}}}"#,
            result.exit_code,
            self.escape_json(&result.stdout),
            self.escape_json(&result.stderr),
            result.duration_ms
        )
    }
    
    fn format_table(&self, results: &Vec<CommandResult>) -> String {
        let output = String::new()
        output.push_str("┌─────────────┬────────────┬──────────────┐\n")
        output.push_str("│ Exit Code   │ Duration   │ Output       │\n")
        output.push_str("├─────────────┼────────────┼──────────────┤\n")
        
        for result in results {
            output.push_str(&format!(
                "│ {:11} │ {:10} │ {:12} │\n",
                result.exit_code,
                format!("{}ms", result.duration_ms),
                &result.stdout[..result.stdout.len().min(12)]
            ))
        }
        
        output.push_str("└─────────────┴────────────┴──────────────┘\n")
        return output
    }
    
    fn escape_json(&self, s: &String) -> String {
        return s.replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t")
    }
}

// =============================================================================
// Shell Script Interpreter
// =============================================================================

class ShellScriptInterpreter {
    parser: CommandParser,
    executor: PipelineExecutor
    
    fn new() -> ShellScriptInterpreter {
        return ShellScriptInterpreter {
            parser: CommandParser::new(),
            executor: PipelineExecutor::new()
        }
    }
    
    fn run_script(&self, script_path: String) -> Result<i32, String> {
        let content = std::fs::read_to_string(script_path)?
        let lines = content.lines()
        
        let last_exit_code = 0
        
        for line in lines {
            let trimmed = line.trim()
            
            // Skip comments and empty lines
            if trimmed.starts_with("#") || trimmed.is_empty() {
                continue
            }
            
            // Parse and execute
            let pipeline = self.parser.parse(trimmed.to_string())?
            let results = self.executor.execute(pipeline)?
            
            if let Some(last_result) = results.last() {
                last_exit_code = last_result.exit_code
                
                // Print output
                if !last_result.stdout.is_empty() {
                    print!("{}", last_result.stdout)
                }
                if !last_result.stderr.is_empty() {
                    eprint!("{}", last_result.stderr)
                }
            }
        }
        
        return Ok(last_exit_code)
    }
}

// =============================================================================
// Package Manager Integration
// =============================================================================

class PackageManagerCommands {
    fn install(&self, package: String) -> Result<CommandResult, String> {
        // Integrate with NyPM
        let cmd = CommandNode {
            program: "nypm".to_string(),
            args: vec!["install".to_string(), package],
            stdin_redirect: None,
            stdout_redirect: None,
            stderr_redirect: None,
            env_overrides: HashMap::new()
        }
        
        let executor = PipelineExecutor::new()
        return executor.execute_command(&cmd, None)
    }
    
    fn update(&self) -> Result<CommandResult, String> {
        let cmd = CommandNode {
            program: "nypm".to_string(),
            args: vec!["update".to_string()],
            stdin_redirect: None,
            stdout_redirect: None,
            stderr_redirect: None,
            env_overrides: HashMap::new()
        }
        
        let executor = PipelineExecutor::new()
        return executor.execute_command(&cmd, None)
    }
    
    fn list(&self) -> Result<CommandResult, String> {
        let cmd = CommandNode {
            program: "nypm".to_string(),
            args: vec!["list".to_string()],
            stdin_redirect: None,
            stdout_redirect: None,
            stderr_redirect: None,
            env_overrides: HashMap::new()
        }
        
        let executor = PipelineExecutor::new()
        return executor.execute_command(&cmd, None)
    }
}

// =============================================================================
// Public API
// =============================================================================

pub fn parse_command(input: String) -> Result<Pipeline, String> {
    let parser = CommandParser::new()
    return parser.parse(input)
}

pub fn execute_pipeline(pipeline: Pipeline) -> Result<Vec<CommandResult>, String> {
    let executor = PipelineExecutor::new()
    return executor.execute(pipeline)
}

pub fn start_repl() {
    let mut repl = ShellRepl::new()
    repl.run()
}

pub fn run_script(path: String) -> Result<i32, String> {
    let interpreter = ShellScriptInterpreter::new()
    return interpreter.run_script(path)
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
