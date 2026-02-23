# ============================================================
# NYLANG - Nyx Language Intelligence Engine
# ============================================================
# Tokenization, semantic parsing, intent detection, dialogue
# state management, memory context tracking, and multi-modal
# input support for cognitive language interaction.

let VERSION = "1.0.0";

# ============================================================
# TOKENIZATION ENGINE
# ============================================================

pub mod tokenization {
    pub class Token {
        pub let text: String;
        pub let id: Int;
        pub let start: Int;
        pub let end: Int;
        pub let type_name: String;

        pub fn new(text: String, id: Int, start: Int, end: Int) -> Self {
            return Self { text: text, id: id, start: start, end: end, type_name: "word" };
        }
    }

    pub class Tokenizer {
        pub let vocab: Map<String, Int>;
        pub let inv_vocab: Map<Int, String>;
        pub let special_tokens: Map<String, Int>;
        pub let method: String;

        pub fn new(method: String) -> Self {
            return Self {
                vocab: {}, inv_vocab: {},
                special_tokens: { "<PAD>": 0, "<UNK>": 1, "<BOS>": 2, "<EOS>": 3 },
                method: method
            };
        }

        pub fn load_vocab(self, path: String) {
            let data = native_lang_load_vocab(path);
            self.vocab = data.vocab;
            self.inv_vocab = data.inv_vocab;
        }

        pub fn tokenize(self, text: String) -> List<Token> {
            return native_lang_tokenize(text, self.vocab, self.method);
        }

        pub fn encode(self, text: String) -> List<Int> {
            let tokens = self.tokenize(text);
            return tokens.map(|t| t.id);
        }

        pub fn decode(self, ids: List<Int>) -> String {
            let parts = [];
            for id in ids {
                let text = self.inv_vocab.get(id);
                if text != null { parts.push(text); }
            }
            return parts.join("");
        }

        pub fn bpe(vocab_size: Int) -> Self {
            return Self::new("bpe");
        }

        pub fn wordpiece() -> Self {
            return Self::new("wordpiece");
        }

        pub fn sentencepiece() -> Self {
            return Self::new("sentencepiece");
        }
    }
}

# ============================================================
# SEMANTIC PARSING
# ============================================================

pub mod parsing {
    pub class SemanticFrame {
        pub let intent: String;
        pub let slots: Map<String, SlotValue>;
        pub let confidence: Float;

        pub fn new(intent: String) -> Self {
            return Self { intent: intent, slots: {}, confidence: 0.0 };
        }

        pub fn set_slot(self, name: String, value: SlotValue) {
            self.slots[name] = value;
        }
    }

    pub class SlotValue {
        pub let value: Any;
        pub let type_name: String;
        pub let confidence: Float;
        pub let span: List<Int>;

        pub fn new(value: Any, type_name: String) -> Self {
            return Self { value: value, type_name: type_name, confidence: 1.0, span: [0, 0] };
        }
    }

    pub class Entity {
        pub let text: String;
        pub let type_name: String;
        pub let start: Int;
        pub let end: Int;
        pub let confidence: Float;

        pub fn new(text: String, type_name: String, start: Int, end: Int) -> Self {
            return Self { text: text, type_name: type_name, start: start, end: end, confidence: 1.0 };
        }
    }

    pub class SemanticParser {
        pub let model_handle: Int?;
        pub let entity_patterns: Map<String, List<String>>;
        pub let grammar_rules: List<Map<String, Any>>;

        pub fn new() -> Self {
            return Self { model_handle: null, entity_patterns: {}, grammar_rules: [] };
        }

        pub fn load_model(self, path: String) {
            self.model_handle = native_lang_load_parser_model(path);
        }

        pub fn add_entity_pattern(self, type_name: String, patterns: List<String>) {
            self.entity_patterns[type_name] = patterns;
        }

        pub fn parse(self, text: String) -> SemanticFrame {
            return native_lang_semantic_parse(self.model_handle, text, self.entity_patterns);
        }

        pub fn extract_entities(self, text: String) -> List<Entity> {
            return native_lang_extract_entities(self.model_handle, text, self.entity_patterns);
        }

        pub fn dependency_parse(self, text: String) -> List<Map<String, Any>> {
            return native_lang_dep_parse(text);
        }

        pub fn constituency_parse(self, text: String) -> Map<String, Any> {
            return native_lang_constituency_parse(text);
        }
    }
}

# ============================================================
# INTENT DETECTION
# ============================================================

pub mod intent {
    pub class IntentResult {
        pub let intent: String;
        pub let confidence: Float;
        pub let alternatives: List<Map<String, Any>>;

        pub fn new(intent: String, confidence: Float) -> Self {
            return Self { intent: intent, confidence: confidence, alternatives: [] };
        }
    }

    pub class IntentClassifier {
        pub let intents: Map<String, List<String>>;
        pub let model_handle: Int?;
        pub let threshold: Float;

        pub fn new() -> Self {
            return Self { intents: {}, model_handle: null, threshold: 0.5 };
        }

        pub fn add_intent(self, name: String, examples: List<String>) {
            self.intents[name] = examples;
        }

        pub fn train(self) {
            self.model_handle = native_lang_train_intent(self.intents);
        }

        pub fn load(self, path: String) {
            self.model_handle = native_lang_load_intent_model(path);
        }

        pub fn classify(self, text: String) -> IntentResult {
            return native_lang_classify_intent(self.model_handle, text, self.threshold);
        }

        pub fn classify_batch(self, texts: List<String>) -> List<IntentResult> {
            return texts.map(|t| self.classify(t));
        }
    }
}

# ============================================================
# DIALOGUE STATE MANAGEMENT
# ============================================================

pub mod dialogue {
    pub class DialogueTurn {
        pub let role: String;
        pub let content: String;
        pub let intent: String?;
        pub let entities: List<parsing.Entity>;
        pub let timestamp: Int;

        pub fn new(role: String, content: String) -> Self {
            return Self {
                role: role, content: content,
                intent: null, entities: [],
                timestamp: native_lang_time_ms()
            };
        }
    }

    pub class DialogueState {
        pub let turns: List<DialogueTurn>;
        pub let slots: Map<String, Any>;
        pub let current_intent: String?;
        pub let context_stack: List<String>;
        pub let completed_intents: List<String>;
        pub let active: Bool;

        pub fn new() -> Self {
            return Self {
                turns: [], slots: {},
                current_intent: null,
                context_stack: [],
                completed_intents: [],
                active: true
            };
        }

        pub fn add_turn(self, turn: DialogueTurn) {
            self.turns.push(turn);
            if turn.intent != null {
                self.current_intent = turn.intent;
            }
            for entity in turn.entities {
                self.slots[entity.type_name] = entity.text;
            }
        }

        pub fn push_context(self, context: String) {
            self.context_stack.push(context);
        }

        pub fn pop_context(self) -> String? {
            if self.context_stack.len() == 0 { return null; }
            return self.context_stack.pop();
        }

        pub fn has_slot(self, name: String) -> Bool {
            return self.slots.has(name);
        }

        pub fn missing_slots(self, required: List<String>) -> List<String> {
            return required.filter(|s| not self.slots.has(s));
        }

        pub fn history(self, n: Int) -> List<DialogueTurn> {
            let start = (self.turns.len() - n).max(0);
            return self.turns.slice(start);
        }

        pub fn reset(self) {
            self.turns = [];
            self.slots = {};
            self.current_intent = null;
            self.context_stack = [];
        }
    }

    pub class DialoguePolicy {
        pub let rules: List<Map<String, Any>>;
        pub let fallback: Fn;

        pub fn new() -> Self {
            return Self { rules: [], fallback: |state| "I'm not sure how to help with that." };
        }

        pub fn add_rule(self, intent: String, required_slots: List<String>, action: Fn) {
            self.rules.push({
                "intent": intent,
                "required_slots": required_slots,
                "action": action
            });
        }

        pub fn decide(self, state: DialogueState) -> String {
            for rule in self.rules {
                if state.current_intent == rule["intent"] {
                    let missing = state.missing_slots(rule["required_slots"]);
                    if missing.len() == 0 {
                        return rule["action"](state);
                    } else {
                        return "I need more information: " + missing.join(", ");
                    }
                }
            }
            return self.fallback(state);
        }
    }
}

# ============================================================
# MEMORY CONTEXT TRACKING
# ============================================================

pub mod context {
    pub class ContextWindow {
        pub let max_tokens: Int;
        pub let messages: List<Map<String, String>>;
        pub let token_count: Int;
        pub let summarizer: Fn?;

        pub fn new(max_tokens: Int) -> Self {
            return Self {
                max_tokens: max_tokens,
                messages: [],
                token_count: 0,
                summarizer: null
            };
        }

        pub fn add(self, role: String, content: String) {
            let tokens = native_lang_count_tokens(content);
            self.messages.push({ "role": role, "content": content });
            self.token_count = self.token_count + tokens;

            while self.token_count > self.max_tokens and self.messages.len() > 2 {
                let removed = self.messages.remove(1);
                self.token_count = self.token_count - native_lang_count_tokens(removed["content"]);
            }
        }

        pub fn summarize_and_compact(self) {
            if self.summarizer != null and self.messages.len() > 4 {
                let old = self.messages.slice(1, self.messages.len() - 2);
                let summary = self.summarizer(old);
                self.messages = [self.messages[0], { "role": "system", "content": summary }] + self.messages.slice(self.messages.len() - 2);
                self.token_count = 0;
                for m in self.messages {
                    self.token_count = self.token_count + native_lang_count_tokens(m["content"]);
                }
            }
        }

        pub fn to_prompt(self) -> List<Map<String, String>> {
            return self.messages;
        }
    }

    pub class ConversationMemory {
        pub let short_term: List<Map<String, String>>;
        pub let long_term: List<Map<String, Any>>;
        pub let facts: Map<String, Any>;

        pub fn new() -> Self {
            return Self { short_term: [], long_term: [], facts: {} };
        }

        pub fn remember_fact(self, key: String, value: Any) {
            self.facts[key] = value;
        }

        pub fn recall_fact(self, key: String) -> Any? {
            return self.facts.get(key);
        }

        pub fn store_long_term(self, content: String, metadata: Map<String, Any>) {
            let embedding = native_lang_embed(content);
            self.long_term.push({
                "content": content,
                "embedding": embedding,
                "metadata": metadata,
                "timestamp": native_lang_time_ms()
            });
        }

        pub fn search_long_term(self, query: String, top_k: Int) -> List<Map<String, Any>> {
            let query_emb = native_lang_embed(query);
            return native_lang_memory_search(self.long_term, query_emb, top_k);
        }
    }
}

# ============================================================
# MULTI-MODAL INPUT
# ============================================================

pub mod multimodal {
    pub class ModalInput {
        pub let modality: String;
        pub let data: Any;
        pub let metadata: Map<String, Any>;
        pub let timestamp: Int;

        pub fn text(content: String) -> Self {
            return Self { modality: "text", data: content, metadata: {}, timestamp: native_lang_time_ms() };
        }

        pub fn image(pixels: Any, width: Int, height: Int) -> Self {
            return Self { modality: "image", data: pixels, metadata: { "width": width, "height": height }, timestamp: native_lang_time_ms() };
        }

        pub fn audio(samples: List<Float>, sample_rate: Int) -> Self {
            return Self { modality: "audio", data: samples, metadata: { "sample_rate": sample_rate }, timestamp: native_lang_time_ms() };
        }
    }

    pub class MultiModalProcessor {
        pub let encoders: Map<String, Fn>;
        pub let fusion_strategy: String;

        pub fn new() -> Self {
            return Self { encoders: {}, fusion_strategy: "concatenate" };
        }

        pub fn register_encoder(self, modality: String, encoder: Fn) {
            self.encoders[modality] = encoder;
        }

        pub fn process(self, inputs: List<ModalInput>) -> List<Float> {
            let embeddings = [];
            for input in inputs {
                let encoder = self.encoders.get(input.modality);
                if encoder != null {
                    embeddings.push(encoder(input.data));
                }
            }
            return native_lang_fuse_embeddings(embeddings, self.fusion_strategy);
        }
    }
}

# ============================================================
# LANGUAGE ENGINE ORCHESTRATOR
# ============================================================

pub class LanguageEngine {
    pub let tokenizer: tokenization.Tokenizer;
    pub let parser: parsing.SemanticParser;
    pub let intent_classifier: intent.IntentClassifier;
    pub let dialogue: dialogue.DialogueState;
    pub let policy: dialogue.DialoguePolicy;
    pub let context_window: context.ContextWindow;
    pub let memory: context.ConversationMemory;

    pub fn new(max_context_tokens: Int) -> Self {
        return Self {
            tokenizer: tokenization.Tokenizer::new("bpe"),
            parser: parsing.SemanticParser::new(),
            intent_classifier: intent.IntentClassifier::new(),
            dialogue: dialogue.DialogueState::new(),
            policy: dialogue.DialoguePolicy::new(),
            context_window: context.ContextWindow::new(max_context_tokens),
            memory: context.ConversationMemory::new()
        };
    }

    pub fn process_input(self, text: String) -> Map<String, Any> {
        let intent_result = self.intent_classifier.classify(text);
        let entities = self.parser.extract_entities(text);
        let turn = dialogue.DialogueTurn::new("user", text);
        turn.intent = intent_result.intent;
        turn.entities = entities;
        self.dialogue.add_turn(turn);
        self.context_window.add("user", text);

        let response = self.policy.decide(self.dialogue);
        self.context_window.add("assistant", response);

        return {
            "intent": intent_result.intent,
            "confidence": intent_result.confidence,
            "entities": entities,
            "response": response
        };
    }
}

pub fn create_language_engine(max_tokens: Int) -> LanguageEngine {
    return LanguageEngine::new(max_tokens);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_lang_time_ms() -> Int;
native_lang_load_vocab(path: String) -> Any;
native_lang_tokenize(text: String, vocab: Map, method: String) -> List;
native_lang_load_parser_model(path: String) -> Int;
native_lang_semantic_parse(handle: Int, text: String, patterns: Map) -> Any;
native_lang_extract_entities(handle: Int, text: String, patterns: Map) -> List;
native_lang_dep_parse(text: String) -> List;
native_lang_constituency_parse(text: String) -> Map;
native_lang_train_intent(intents: Map) -> Int;
native_lang_load_intent_model(path: String) -> Int;
native_lang_classify_intent(handle: Int, text: String, threshold: Float) -> Any;
native_lang_count_tokens(text: String) -> Int;
native_lang_embed(text: String) -> List;
native_lang_memory_search(memories: List, query: List, top_k: Int) -> List;
native_lang_fuse_embeddings(embeddings: List, strategy: String) -> List;

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
