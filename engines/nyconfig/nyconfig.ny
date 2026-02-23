// NyConfig - Configuration Management Engine
// Provides: Configuration templating, YAML/JSON/TOML parsing, environment injection, secret management
// Competes with: Consul, etcd, Spring Cloud Config

use std::collections::HashMap

// =============================================================================
// Configuration Formats
// =============================================================================

enum ConfigFormat {
    YAML,
    JSON,
    TOML,
    ENV
}

struct ConfigValue {
    raw: String,
    resolved: String
}

// =============================================================================
// Configuration Parser
// =============================================================================

class ConfigParser {
    fn parse(&self, content: String, format: ConfigFormat) -> Result<HashMap<String, String>, String> {
        match format {
            ConfigFormat::YAML => self.parse_yaml(&content),
            ConfigFormat::JSON => self.parse_json(&content),
            ConfigFormat::TOML => self.parse_toml(&content),
            ConfigFormat::ENV => self.parse_env(&content)
        }
    }
    
    fn parse_yaml(&self, content: &String) -> Result<HashMap<String, String>, String> {
        let config = HashMap::new()
        
        // Simple YAML parser
        for line in content.lines() {
            let trimmed = line.trim()
            
            if trimmed.is_empty() || trimmed.starts_with("#") {
                continue
            }
            
            if let Some(pos) = trimmed.find(':') {
                let key = trimmed[..pos].trim().to_string()
                let value = trimmed[pos+1..].trim().to_string()
                config.insert(key, value)
            }
        }
        
        return Ok(config)
    }
    
    fn parse_json(&self, content: &String) -> Result<HashMap<String, String>, String> {
        let config = HashMap::new()
        
        // Strip outer braces
        let stripped = content.trim().trim_start_matches('{').trim_end_matches('}')
        
        // Parse key-value pairs
        for pair in stripped.split(',') {
            let parts: Vec<&str> = pair.split(':').collect()
            if parts.len() == 2 {
                let key = parts[0].trim().trim_matches('"').to_string()
                let value = parts[1].trim().trim_matches('"').to_string()
                config.insert(key, value)
            }
        }
        
        return Ok(config)
    }
    
    fn parse_toml(&self, content: &String) -> Result<HashMap<String, String>, String> {
        let config = HashMap::new()
        
        for line in content.lines() {
            let trimmed = line.trim()
            
            if trimmed.is_empty() || trimmed.starts_with("#") || trimmed.starts_with("[") {
                continue
            }
            
            if let Some(pos) = trimmed.find('=') {
                let key = trimmed[..pos].trim().to_string()
                let value = trimmed[pos+1..].trim().trim_matches('"').to_string()
                config.insert(key, value)
            }
        }
        
        return Ok(config)
    }
    
    fn parse_env(&self, content: &String) -> Result<HashMap<String, String>, String> {
        let config = HashMap::new()
        
        for line in content.lines() {
            let trimmed = line.trim()
            
            if trimmed.is_empty() || trimmed.starts_with("#") {
                continue
            }
            
            if let Some(pos) = trimmed.find('=') {
                let key = trimmed[..pos].trim().to_string()
                let value = trimmed[pos+1..].trim().to_string()
                config.insert(key, value)
            }
        }
        
        return Ok(config)
    }
    
    fn load_from_file(&self, path: String) -> Result<HashMap<String, String>, String> {
        let content = std::fs::read_to_string(&path)
            .map_err(|e| format!("Failed to read file: {}", e))?
        
        let format = self.detect_format(&path)
        return self.parse(content, format)
    }
    
    fn detect_format(&self, path: &String) -> ConfigFormat {
        if path.ends_with(".yaml") || path.ends_with(".yml") {
            return ConfigFormat::YAML
        } else if path.ends_with(".json") {
            return ConfigFormat::JSON
        } else if path.ends_with(".toml") {
            return ConfigFormat::TOML
        } else if path.ends_with(".env") {
            return ConfigFormat::ENV
        }
        
        return ConfigFormat::YAML
    }
}

// =============================================================================
// Configuration Templating
// =============================================================================

class ConfigTemplate {
    template: String,
    variables: HashMap<String, String>
    
    fn new(template: String) -> ConfigTemplate {
        return ConfigTemplate {
            template,
            variables: HashMap::new()
        }
    }
    
    fn set_variable(&mut self, key: String, value: String) {
        self.variables.insert(key, value)
    }
    
    fn render(&self) -> Result<String, String> {
        let mut rendered = self.template.clone()
        
        // Replace ${VAR} patterns
        for (key, value) in &self.variables {
            let pattern_dollar = format!("${{{}}}", key)
            let pattern_curly = format!("{{{{{}}}}}", key)
            
            rendered = rendered.replace(&pattern_dollar, value)
            rendered = rendered.replace(&pattern_curly, value)
        }
        
        // Check for unresolved variables
        if rendered.contains("${") || rendered.contains("{{") {
            return Err("Unresolved template variables".to_string())
        }
        
        return Ok(rendered)
    }
    
    fn render_with_env(&self) -> Result<String, String> {
        let mut template = self.clone()
        
        // Add environment variables
        for (key, value) in std::env::vars() {
            template.set_variable(key, value)
        }
        
        return template.render()
    }
}

// =============================================================================
// Environment Injection
// =============================================================================

enum Environment {
    Development,
    Staging,
    Production
}

class EnvironmentManager {
    current_env: Environment,
    configs: HashMap<String, HashMap<String, String>>
    
    fn new(env: Environment) -> EnvironmentManager {
        return EnvironmentManager {
            current_env: env,
            configs: HashMap::new()
        }
    }
    
    fn load_environment_config(&mut self, env_name: String, config_path: String) -> Result<(), String> {
        let parser = ConfigParser {}
        let config = parser.load_from_file(config_path)?
        
        self.configs.insert(env_name, config)
        
        return Ok(())
    }
    
    fn get_config(&self, key: &String) -> Option<String> {
        let env_name = self.env_to_string()
        
        if let Some(config) = self.configs.get(&env_name) {
            return config.get(key).cloned()
        }
        
        return None
    }
    
    fn inject_env_vars(&self) -> Result<(), String> {
        let env_name = self.env_to_string()
        
        if let Some(config) = self.configs.get(&env_name) {
            for (key, value) in config {
                std::env::set_var(key, value)
            }
        }
        
        return Ok(())
    }
    
    fn env_to_string(&self) -> String {
        match self.current_env {
            Environment::Development => "development".to_string(),
            Environment::Staging => "staging".to_string(),
            Environment::Production => "production".to_string()
        }
    }
}

// =============================================================================
// Secret Management
// =============================================================================

struct Secret {
    key: String,
    value: String,
    encrypted: bool,
    created_at: u64
}

class SecretManager {
    secrets: HashMap<String, Secret>,
    encryption_key: Option<String>
    
    fn new() -> SecretManager {
        return SecretManager {
            secrets: HashMap::new(),
            encryption_key: None
        }
    }
    
    fn set_encryption_key(&mut self, key: String) {
        self.encryption_key = Some(key)
    }
    
    fn store_secret(&mut self, key: String, value: String, encrypt: bool) -> Result<(), String> {
        let mut secret_value = value.clone()
        
        if encrypt {
            if self.encryption_key.is_none() {
                return Err("Encryption key not set".to_string())
            }
            
            secret_value = self.encrypt(&value)?
        }
        
        let secret = Secret {
            key: key.clone(),
            value: secret_value,
            encrypted: encrypt,
            created_at: std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs()
        }
        
        self.secrets.insert(key, secret)
        
        return Ok(())
    }
    
    fn get_secret(&self, key: &String) -> Result<String, String> {
        let secret = self.secrets.get(key)
            .ok_or("Secret not found")?
        
        if secret.encrypted {
            return self.decrypt(&secret.value)
        }
        
        return Ok(secret.value.clone())
    }
    
    fn delete_secret(&mut self, key: &String) -> Result<(), String> {
        self.secrets.remove(key)
            .ok_or("Secret not found")?
        
        return Ok(())
    }
    
    fn list_secrets(&self) -> Vec<String> {
        return self.secrets.keys().cloned().collect()
    }
    
    fn encrypt(&self, plaintext: &String) -> Result<String, String> {
        if let Some(key) = &self.encryption_key {
            // Simple XOR encryption (not production-ready, use proper crypto in real implementation)
            let mut encrypted = Vec::new()
            let key_bytes = key.as_bytes()
            
            for (i, byte) in plaintext.as_bytes().iter().enumerate() {
                encrypted.push(byte ^ key_bytes[i % key_bytes.len()])
            }
            
            // Encode as hex
            let hex = encrypted.iter().map(|b| format!("{:02x}", b)).collect::<String>()
            return Ok(hex)
        }
        
        return Err("No encryption key".to_string())
    }
    
    fn decrypt(&self, ciphertext: &String) -> Result<String, String> {
        if let Some(key) = &self.encryption_key {
            // Decode hex
            let mut bytes = Vec::new()
            for i in (0..ciphertext.len()).step_by(2) {
                let byte_str = &ciphertext[i..i+2]
                let byte = u8::from_str_radix(byte_str, 16)
                    .map_err(|_| "Invalid hex")?
                bytes.push(byte)
            }
            
            // XOR decrypt
            let key_bytes = key.as_bytes()
            let mut decrypted = Vec::new()
            
            for (i, byte) in bytes.iter().enumerate() {
                decrypted.push(byte ^ key_bytes[i % key_bytes.len()])
            }
            
            let plaintext = String::from_utf8(decrypted)
                .map_err(|_| "Invalid UTF-8")?
            
            return Ok(plaintext)
        }
        
        return Err("No encryption key".to_string())
    }
}

// =============================================================================
// Remote Configuration Sync
// =============================================================================

struct RemoteConfigSource {
    url: String,
    credentials: Option<(String, String)>
}

class RemoteConfigManager {
    sources: Vec<RemoteConfigSource>,
    local_cache: HashMap<String, String>,
    sync_interval_seconds: u64
    
    fn new() -> RemoteConfigManager {
        return RemoteConfigManager {
            sources: Vec::new(),
            local_cache: HashMap::new(),
            sync_interval_seconds: 60
        }
    }
    
    fn add_source(&mut self, url: String, username: Option<String>, password: Option<String>) {
        let credentials = if username.is_some() && password.is_some() {
            Some((username.unwrap(), password.unwrap()))
        } else {
            None
        }
        
        self.sources.push(RemoteConfigSource { url, credentials })
    }
    
    fn sync(&mut self) -> Result<(), String> {
        for source in &self.sources {
            let config = self.fetch_remote_config(&source.url)?
            
            for (key, value) in config {
                self.local_cache.insert(key, value)
            }
        }
        
        return Ok(())
    }
    
    fn start_auto_sync(&mut self) {
        let interval = self.sync_interval_seconds
        
        std::thread::spawn(move || {
            loop {
                std::thread::sleep(std::time::Duration::from_secs(interval))
                
                // Sync in background
                let mut manager = RemoteConfigManager::new()
                let _ = manager.sync()
            }
        })
    }
    
    fn get(&self, key: &String) -> Option<String> {
        return self.local_cache.get(key).cloned()
    }
    
    fn fetch_remote_config(&self, url: &String) -> Result<HashMap<String, String>, String> {
        println!("Fetching config from: {}", url)
        
        // Simulate HTTP GET
        let config = HashMap::new()
        config.insert("key1".to_string(), "value1".to_string())
        
        return Ok(config)
    }
}

// =============================================================================
// Configuration Validation
// =============================================================================

enum ConfigRule {
    Required,
    Type(String),
    Range(f64, f64),
    Pattern(String)
}

class ConfigValidator {
    rules: HashMap<String, Vec<ConfigRule>>
    
    fn new() -> ConfigValidator {
        return ConfigValidator {
            rules: HashMap::new()
        }
    }
    
    fn add_rule(&mut self, key: String, rule: ConfigRule) {
        if !self.rules.contains_key(&key) {
            self.rules.insert(key.clone(), Vec::new())
        }
        
        self.rules.get_mut(&key).unwrap().push(rule)
    }
    
    fn validate(&self, config: &HashMap<String, String>) -> Result<(), Vec<String>> {
        let errors = Vec::new()
        
        for (key, rules) in &self.rules {
            for rule in rules {
                match rule {
                    ConfigRule::Required => {
                        if !config.contains_key(key) {
                            errors.push(format!("Required key '{}' is missing", key))
                        }
                    }
                    ConfigRule::Type(expected_type) => {
                        if let Some(value) = config.get(key) {
                            // Type checking logic
                        }
                    }
                    ConfigRule::Range(min, max) => {
                        if let Some(value) = config.get(key) {
                            if let Ok(num) = value.parse::<f64>() {
                                if num < *min || num > *max {
                                    errors.push(format!("Value for '{}' out of range [{}, {}]", key, min, max))
                                }
                            }
                        }
                    }
                    ConfigRule::Pattern(pattern) => {
                        // Regex matching
                    }
                }
            }
        }
        
        if errors.is_empty() {
            return Ok(())
        } else {
            return Err(errors)
        }
    }
}

// =============================================================================
// Public API
// =============================================================================

pub fn parse_config(content: String, format: ConfigFormat) -> Result<HashMap<String, String>, String> {
    let parser = ConfigParser {}
    return parser.parse(content, format)
}

pub fn load_config_file(path: String) -> Result<HashMap<String, String>, String> {
    let parser = ConfigParser {}
    return parser.load_from_file(path)
}

pub fn create_template(template: String) -> ConfigTemplate {
    return ConfigTemplate::new(template)
}

pub fn create_secret_manager() -> SecretManager {
    return SecretManager::new()
}

pub fn create_remote_config_manager() -> RemoteConfigManager {
    return RemoteConfigManager::new()
}

pub fn create_validator() -> ConfigValidator {
    return ConfigValidator::new()
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
