# ============================================================
# NYVOICE - Nyx Speech & Voice Engine
# ============================================================
# Speech-to-text, text-to-speech, real-time audio processing,
# wake-word detection, and voice activity detection for
# cognitive interaction systems.

let VERSION = "1.0.0";

# ============================================================
# AUDIO CAPTURE & PROCESSING
# ============================================================

pub mod audio {
    pub class AudioConfig {
        pub let sample_rate: Int;
        pub let channels: Int;
        pub let bit_depth: Int;
        pub let buffer_size: Int;
        pub let format: String;

        pub fn new() -> Self {
            return Self {
                sample_rate: 16000, channels: 1,
                bit_depth: 16, buffer_size: 4096,
                format: "pcm_s16le"
            };
        }

        pub fn high_quality() -> Self {
            return Self {
                sample_rate: 48000, channels: 2,
                bit_depth: 24, buffer_size: 8192,
                format: "pcm_s24le"
            };
        }
    }

    pub class AudioStream {
        pub let config: AudioConfig;
        pub let handle: Int?;
        pub let active: Bool;

        pub fn new(config: AudioConfig) -> Self {
            return Self { config: config, handle: null, active: false };
        }

        pub fn open(self) {
            self.handle = native_voice_audio_open(self.config);
            self.active = true;
        }

        pub fn read(self, num_samples: Int) -> List<Float> {
            return native_voice_audio_read(self.handle, num_samples);
        }

        pub fn write(self, samples: List<Float>) {
            native_voice_audio_write(self.handle, samples);
        }

        pub fn close(self) {
            if self.handle != null { native_voice_audio_close(self.handle); }
            self.active = false;
        }
    }

    pub class AudioBuffer {
        pub let data: List<Float>;
        pub let sample_rate: Int;
        pub let duration_ms: Int;

        pub fn new(sample_rate: Int) -> Self {
            return Self { data: [], sample_rate: sample_rate, duration_ms: 0 };
        }

        pub fn append(self, samples: List<Float>) {
            self.data = self.data + samples;
            self.duration_ms = (self.data.len() as Float / self.sample_rate as Float * 1000.0) as Int;
        }

        pub fn slice(self, start_ms: Int, end_ms: Int) -> List<Float> {
            let start_idx = (start_ms as Float / 1000.0 * self.sample_rate as Float) as Int;
            let end_idx = (end_ms as Float / 1000.0 * self.sample_rate as Float) as Int;
            return self.data.slice(start_idx, end_idx);
        }

        pub fn clear(self) {
            self.data = [];
            self.duration_ms = 0;
        }

        pub fn rms(self) -> Float {
            if self.data.len() == 0 { return 0.0; }
            let sum = 0.0;
            for s in self.data { sum = sum + s * s; }
            return (sum / self.data.len() as Float).sqrt();
        }
    }

    pub class VoiceActivityDetector {
        pub let threshold: Float;
        pub let min_speech_ms: Int;
        pub let min_silence_ms: Int;
        pub let handle: Int?;

        pub fn new() -> Self {
            return Self {
                threshold: 0.02, min_speech_ms: 200,
                min_silence_ms: 500, handle: null
            };
        }

        pub fn init(self, sample_rate: Int) {
            self.handle = native_voice_vad_init(sample_rate, self.threshold);
        }

        pub fn is_speech(self, samples: List<Float>) -> Bool {
            return native_voice_vad_detect(self.handle, samples);
        }

        pub fn segment(self, audio: AudioBuffer) -> List<List<Int>> {
            return native_voice_vad_segment(self.handle, audio.data, audio.sample_rate);
        }
    }
}

# ============================================================
# SPEECH-TO-TEXT
# ============================================================

pub mod stt {
    pub class STTConfig {
        pub let model: String;
        pub let language: String;
        pub let beam_size: Int;
        pub let enable_timestamps: Bool;
        pub let enable_punctuation: Bool;

        pub fn new() -> Self {
            return Self {
                model: "base", language: "en",
                beam_size: 5, enable_timestamps: true,
                enable_punctuation: true
            };
        }
    }

    pub class TranscriptionSegment {
        pub let text: String;
        pub let start_ms: Int;
        pub let end_ms: Int;
        pub let confidence: Float;
        pub let words: List<WordTimestamp>;
    }

    pub class WordTimestamp {
        pub let word: String;
        pub let start_ms: Int;
        pub let end_ms: Int;
        pub let confidence: Float;
    }

    pub class Transcription {
        pub let text: String;
        pub let segments: List<TranscriptionSegment>;
        pub let language: String;
        pub let duration_ms: Int;

        pub fn full_text(self) -> String {
            return self.segments.map(|s| s.text).join(" ");
        }
    }

    pub class SpeechRecognizer {
        pub let config: STTConfig;
        pub let model_handle: Int?;

        pub fn new(config: STTConfig) -> Self {
            return Self { config: config, model_handle: null };
        }

        pub fn load_model(self, path: String) {
            self.model_handle = native_voice_stt_load(path, self.config);
        }

        pub fn transcribe(self, audio: audio.AudioBuffer) -> Transcription {
            return native_voice_stt_transcribe(self.model_handle, audio.data, audio.sample_rate);
        }

        pub fn transcribe_file(self, path: String) -> Transcription {
            return native_voice_stt_transcribe_file(self.model_handle, path);
        }

        pub fn stream_start(self) -> Int {
            return native_voice_stt_stream_start(self.model_handle);
        }

        pub fn stream_feed(self, stream_id: Int, samples: List<Float>) -> String? {
            return native_voice_stt_stream_feed(stream_id, samples);
        }

        pub fn stream_end(self, stream_id: Int) -> Transcription {
            return native_voice_stt_stream_end(stream_id);
        }
    }
}

# ============================================================
# TEXT-TO-SPEECH
# ============================================================

pub mod tts {
    pub class TTSConfig {
        pub let voice: String;
        pub let speed: Float;
        pub let pitch: Float;
        pub let volume: Float;
        pub let sample_rate: Int;
        pub let language: String;

        pub fn new() -> Self {
            return Self {
                voice: "default", speed: 1.0,
                pitch: 1.0, volume: 1.0,
                sample_rate: 22050, language: "en"
            };
        }
    }

    pub class Voice {
        pub let id: String;
        pub let name: String;
        pub let language: String;
        pub let gender: String;
        pub let style: String;

        pub fn new(id: String, name: String, language: String) -> Self {
            return Self { id: id, name: name, language: language, gender: "neutral", style: "normal" };
        }
    }

    pub class SpeechSynthesizer {
        pub let config: TTSConfig;
        pub let model_handle: Int?;
        pub let available_voices: List<Voice>;

        pub fn new(config: TTSConfig) -> Self {
            return Self { config: config, model_handle: null, available_voices: [] };
        }

        pub fn load_model(self, path: String) {
            self.model_handle = native_voice_tts_load(path, self.config);
            self.available_voices = native_voice_tts_list_voices(self.model_handle);
        }

        pub fn synthesize(self, text: String) -> audio.AudioBuffer {
            let samples = native_voice_tts_synthesize(self.model_handle, text, self.config);
            let buffer = audio.AudioBuffer::new(self.config.sample_rate);
            buffer.append(samples);
            return buffer;
        }

        pub fn synthesize_ssml(self, ssml: String) -> audio.AudioBuffer {
            let samples = native_voice_tts_ssml(self.model_handle, ssml, self.config);
            let buffer = audio.AudioBuffer::new(self.config.sample_rate);
            buffer.append(samples);
            return buffer;
        }

        pub fn synthesize_to_file(self, text: String, path: String) {
            native_voice_tts_to_file(self.model_handle, text, self.config, path);
        }

        pub fn set_voice(self, voice_id: String) {
            self.config.voice = voice_id;
        }

        pub fn stream_start(self) -> Int {
            return native_voice_tts_stream_start(self.model_handle, self.config);
        }

        pub fn stream_feed(self, stream_id: Int, text: String) -> List<Float> {
            return native_voice_tts_stream_feed(stream_id, text);
        }

        pub fn stream_end(self, stream_id: Int) {
            native_voice_tts_stream_end(stream_id);
        }
    }
}

# ============================================================
# WAKE-WORD DETECTION
# ============================================================

pub mod wakeword {
    pub class WakeWordConfig {
        pub let keywords: List<String>;
        pub let sensitivity: Float;
        pub let model_path: String?;

        pub fn new(keywords: List<String>) -> Self {
            return Self { keywords: keywords, sensitivity: 0.5, model_path: null };
        }
    }

    pub class WakeWordDetector {
        pub let config: WakeWordConfig;
        pub let handle: Int?;
        pub let on_detected: Fn?;
        pub let active: Bool;

        pub fn new(config: WakeWordConfig) -> Self {
            return Self { config: config, handle: null, on_detected: null, active: false };
        }

        pub fn on_wake(self, callback: Fn) -> Self {
            self.on_detected = callback;
            return self;
        }

        pub fn start(self, audio_stream: audio.AudioStream) {
            self.handle = native_voice_wakeword_start(self.config, audio_stream.handle, self.on_detected);
            self.active = true;
        }

        pub fn stop(self) {
            if self.handle != null { native_voice_wakeword_stop(self.handle); }
            self.active = false;
        }

        pub fn detect(self, samples: List<Float>) -> Map<String, Any>? {
            return native_voice_wakeword_detect(self.handle, samples);
        }
    }
}

# ============================================================
# AUDIO EFFECTS & PROCESSING
# ============================================================

pub mod effects {
    pub class NoiseReducer {
        pub let strength: Float;
        pub let handle: Int?;

        pub fn new(strength: Float) -> Self {
            return Self { strength: strength, handle: null };
        }

        pub fn init(self, sample_rate: Int) {
            self.handle = native_voice_noise_init(sample_rate, self.strength);
        }

        pub fn process(self, samples: List<Float>) -> List<Float> {
            return native_voice_noise_reduce(self.handle, samples);
        }
    }

    pub class EchoCanceller {
        pub let handle: Int?;

        pub fn new() -> Self {
            return Self { handle: null };
        }

        pub fn init(self, sample_rate: Int, frame_size: Int) {
            self.handle = native_voice_echo_init(sample_rate, frame_size);
        }

        pub fn process(self, input: List<Float>, reference: List<Float>) -> List<Float> {
            return native_voice_echo_cancel(self.handle, input, reference);
        }
    }

    pub class AudioResampler {
        pub fn resample(samples: List<Float>, from_rate: Int, to_rate: Int) -> List<Float> {
            return native_voice_resample(samples, from_rate, to_rate);
        }
    }

    pub class GainControl {
        pub let target_db: Float;
        pub let handle: Int?;

        pub fn new(target_db: Float) -> Self {
            return Self { target_db: target_db, handle: null };
        }

        pub fn init(self, sample_rate: Int) {
            self.handle = native_voice_agc_init(sample_rate, self.target_db);
        }

        pub fn process(self, samples: List<Float>) -> List<Float> {
            return native_voice_agc_process(self.handle, samples);
        }
    }
}

# ============================================================
# VOICE ENGINE ORCHESTRATOR
# ============================================================

pub class VoiceEngine {
    pub let audio_config: audio.AudioConfig;
    pub let recognizer: stt.SpeechRecognizer;
    pub let synthesizer: tts.SpeechSynthesizer;
    pub let wake_detector: wakeword.WakeWordDetector?;
    pub let vad: audio.VoiceActivityDetector;
    pub let noise_reducer: effects.NoiseReducer;

    pub fn new() -> Self {
        let aconfig = audio.AudioConfig::new();
        return Self {
            audio_config: aconfig,
            recognizer: stt.SpeechRecognizer::new(stt.STTConfig::new()),
            synthesizer: tts.SpeechSynthesizer::new(tts.TTSConfig::new()),
            wake_detector: null,
            vad: audio.VoiceActivityDetector::new(),
            noise_reducer: effects.NoiseReducer::new(0.5)
        };
    }

    pub fn listen_and_transcribe(self, duration_ms: Int) -> String {
        let stream = audio.AudioStream::new(self.audio_config);
        stream.open();
        let buffer = audio.AudioBuffer::new(self.audio_config.sample_rate);
        let samples_needed = (duration_ms as Float / 1000.0 * self.audio_config.sample_rate as Float) as Int;
        let samples = stream.read(samples_needed);
        let clean = self.noise_reducer.process(samples);
        buffer.append(clean);
        stream.close();
        let result = self.recognizer.transcribe(buffer);
        return result.text;
    }

    pub fn speak(self, text: String) {
        let buffer = self.synthesizer.synthesize(text);
        let stream = audio.AudioStream::new(self.audio_config);
        stream.open();
        stream.write(buffer.data);
        stream.close();
    }
}

pub fn create_voice_engine() -> VoiceEngine {
    return VoiceEngine::new();
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_voice_audio_open(config: Any) -> Int;
native_voice_audio_read(handle: Int, num_samples: Int) -> List;
native_voice_audio_write(handle: Int, samples: List);
native_voice_audio_close(handle: Int);
native_voice_vad_init(sample_rate: Int, threshold: Float) -> Int;
native_voice_vad_detect(handle: Int, samples: List) -> Bool;
native_voice_vad_segment(handle: Int, data: List, sample_rate: Int) -> List;
native_voice_stt_load(path: String, config: Any) -> Int;
native_voice_stt_transcribe(handle: Int, data: List, sample_rate: Int) -> Any;
native_voice_stt_transcribe_file(handle: Int, path: String) -> Any;
native_voice_stt_stream_start(handle: Int) -> Int;
native_voice_stt_stream_feed(stream: Int, samples: List) -> String;
native_voice_stt_stream_end(stream: Int) -> Any;
native_voice_tts_load(path: String, config: Any) -> Int;
native_voice_tts_list_voices(handle: Int) -> List;
native_voice_tts_synthesize(handle: Int, text: String, config: Any) -> List;
native_voice_tts_ssml(handle: Int, ssml: String, config: Any) -> List;
native_voice_tts_to_file(handle: Int, text: String, config: Any, path: String);
native_voice_tts_stream_start(handle: Int, config: Any) -> Int;
native_voice_tts_stream_feed(stream: Int, text: String) -> List;
native_voice_tts_stream_end(stream: Int);
native_voice_wakeword_start(config: Any, stream: Int, callback: Fn) -> Int;
native_voice_wakeword_stop(handle: Int);
native_voice_wakeword_detect(handle: Int, samples: List) -> Any;
native_voice_noise_init(sample_rate: Int, strength: Float) -> Int;
native_voice_noise_reduce(handle: Int, samples: List) -> List;
native_voice_echo_init(sample_rate: Int, frame_size: Int) -> Int;
native_voice_echo_cancel(handle: Int, input: List, reference: List) -> List;
native_voice_resample(samples: List, from_rate: Int, to_rate: Int) -> List;
native_voice_agc_init(sample_rate: Int, target_db: Float) -> Int;
native_voice_agc_process(handle: Int, samples: List) -> List;

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
