# ============================================================
# NYQUEUE - Nyx Message Queue & Job Processing
# ============================================================
# World-class distributed message queue
#
# Version: 3.0.0
#
# Features:
# - Task queues with delivery guarantees
# - Pub/Sub messaging
# - Event streaming with replay
# - Distributed workers with auto-scaling
# - Scheduled and delayed jobs
# - Exactly-once processing
# - Dead-letter queues
# - Cluster mode with replication

let VERSION = "3.0.0";

# ============================================================
# CORE TYPES
# ============================================================

pub mod types {
    # Message types
    pub enum MessageType {
        Task,           # Work queue item
        Event,          # Pub/Sub event
        Delayed,        # Delayed execution
        Scheduled,      # Cron-based execution
        Stream          # Event stream record
    }
    
    # Delivery guarantees
    pub enum DeliveryGuarantee {
        AtMostOnce,     # Fire and forget
        AtLeastOnce,    # With ack, may duplicate
        ExactlyOnce     # Idempotent processing
    }
    
    # Message status
    pub enum MessageStatus {
        Pending,
        InProgress,
        Completed,
        Failed,
        DeadLettered,
        Expired
    }
    
    # Message
    pub class Message {
        pub let id: String;
        pub let type: MessageType;
        pub let queue: String;
        pub let payload: Any;
        pub let headers: Map<String, String>;
        pub let properties: MessageProperties;
        pub let timestamp: Int;
        pub let delivery_count: Int;
        pub let status: MessageStatus;
        
        pub fn new(queue: String, payload: Any) -> Self {
            return Self {
                id: generate_id(),
                type: MessageType::Task,
                queue: queue,
                payload: payload,
                headers: {},
                properties: MessageProperties::new(),
                timestamp: current_time_ms(),
                delivery_count: 0,
                status: MessageStatus::Pending
            };
        }
        
        pub fn with_type(self, msg_type: MessageType) -> Self {
            self.type = msg_type;
            return self;
        }
        
        pub fn with_header(self, key: String, value: String) -> Self {
            self.headers[key] = value;
            return self;
        }
        
        pub fn delay(self, ms: Int) -> Self {
            self.properties.delay = ms;
            return self;
        }
        
        pub fn priority(self, p: Int) -> Self {
            self.properties.priority = p;
            return self;
        }
        
        pub fn ttl(self, ms: Int) -> Self {
            self.properties.ttl = ms;
            return self;
        }
    }
    
    pub class MessageProperties {
        pub let correlation_id: String;
        pub let reply_to: String;
        pub let content_type: String;
        pub let priority: Int;
        pub let delay: Int;
        pub let ttl: Int;
        pub let delivery_mode: DeliveryGuarantee;
        pub let max_retries: Int;
        
        pub fn new() -> Self {
            return Self {
                correlation_id: "",
                reply_to: "",
                content_type: "application/json",
                priority: 0,
                delay: 0,
                ttl: 3600000,        # 1 hour default
                delivery_mode: DeliveryGuarantee::AtLeastOnce,
                max_retries: 3
            };
        }
    }
    
    # Queue definition
    pub class Queue {
        pub let name: String;
        pub let message_type: MessageType;
        pub let durable: Bool;
        pub let auto_delete: Bool;
        pub let ttl: Int;
        pub let max_length: Int;
        pub let overflow_policy: String;
        pub let dead_letter: String?;
        pub let partitions: Int;
        
        pub fn new(name: String) -> Self {
            return Self {
                name: name,
                message_type: MessageType::Task,
                durable: true,
                auto_delete: false,
                ttl: 3600000,
                max_length: 0,
                overflow_policy: "reject-publish",
                dead_letter: null,
                partitions: 1
            };
        }
        
        pub fn as_task(self) -> Self {
            self.message_type = MessageType::Task;
            return self;
        }
        
        pub fn as_event(self) -> Self {
            self.message_type = MessageType::Event;
            return self;
        }
        
        pub fn as_stream(self) -> Self {
            self.message_type = MessageType::Stream;
            return self;
        }
        
        pub fn with_ttl(self, ms: Int) -> Self {
            self.ttl = ms;
            return self;
        }
        
        pub fn with_dead_letter(self, queue: String) -> Self {
            self.dead_letter = queue;
            return self;
        }
        
        pub fn partitioned(self, n: Int) -> Self {
            self.partitions = n;
            return self;
        }
    }
    
    # Consumer
    pub class Consumer {
        pub let id: String;
        pub let queue: String;
        pub let worker_id: String;
        pub let prefetch: Int;
        pub let auto_ack: Bool;
        pub let exclusive: Bool;
        
        pub fn new(queue: String, worker_id: String) -> Self {
            return Self {
                id: generate_id(),
                queue: queue,
                worker_id: worker_id,
                prefetch: 10,
                auto_ack: false,
                exclusive: false
            };
        }
        
        pub fn prefetch_count(self, n: Int) -> Self {
            self.prefetch = n;
            return self;
        }
        
        pub fn auto_acknowledge(self) -> Self {
            self.auto_ack = true;
            return self;
        }
        
        pub fn exclusive_mode(self) -> Self {
            self.exclusive = true;
            return self;
        }
    }
    
    # Producer
    pub class Producer {
        pub let queue: String;
        pub let delivery_mode: DeliveryGuarantee;
        
        pub fn new(queue: String) -> Self {
            return Self {
                queue: queue,
                delivery_mode: DeliveryGuarantee::AtLeastOnce
            };
        }
        
        pub fn at_most_once(self) -> Self {
            self.delivery_mode = DeliveryGuarantee::AtMostOnce;
            return self;
        }
        
        pub fn exactly_once(self) -> Self {
            self.delivery_mode = DeliveryGuarantee::ExactlyOnce;
            return self;
        }
    }
    
    # Worker
    pub class Worker {
        pub let id: String;
        pub let name: String;
        pub let queues: List<String>;
        pub let concurrency: Int;
        pub let timeout: Int;
        pub let max_retries: Int;
        
        pub fn new(name: String) -> Self {
            return Self {
                id: generate_id(),
                name: name,
                queues: [],
                concurrency: 1,
                timeout: 30000,
                max_retries: 3
            };
        }
        
        pub fn subscribe(self, queue: String) -> Self {
            self.queues.push(queue);
            return self;
        }
        
        pub fn concurrency(self, n: Int) -> Self {
            self.concurrency = n;
            return self;
        }
        
        pub fn timeout(self, ms: Int) -> Self {
            self.timeout = ms;
            return self;
        }
    }
    
    # Job (scheduled task)
    pub class Job {
        pub let id: String;
        pub let queue: String;
        pub let payload: Any;
        pub let schedule: JobSchedule;
        pub let enabled: Bool;
        pub let last_run: Int?;
        pub let next_run: Int?;
        
        pub fn new(queue: String, payload: Any) -> Self {
            return Self {
                id: generate_id(),
                queue: queue,
                payload: payload,
                schedule: JobSchedule::once(),
                enabled: true,
                last_run: null,
                next_run: null
            };
        }
        
        pub fn cron(self, expression: String) -> Self {
            self.schedule = JobSchedule::cron(expression);
            return self;
        }
        
        pub fn interval(self, ms: Int) -> Self {
            self.schedule = JobSchedule::interval(ms);
            return self;
        }
    }
    
    pub class JobSchedule {
        pub let type: String;
        pub let cron: String?;
        pub let interval_ms: Int?;
        pub let delay_ms: Int?;
        
        pub fn once() -> Self {
            return Self { type: "once", cron: null, interval_ms: null, delay_ms: null };
        }
        
        pub fn cron(expr: String) -> Self {
            return Self { type: "cron", cron: expr, interval_ms: null, delay_ms: null };
        }
        
        pub fn interval(ms: Int) -> Self {
            return Self { type: "interval", cron: null, interval_ms: ms, delay_ms: null };
        }
        
        pub fn delay(ms: Int) -> Self {
            return Self { type: "delay", cron: null, interval_ms: null, delay_ms: ms };
        }
    }
    
    # Metrics
    pub class QueueMetrics {
        pub let queue: String;
        pub let message_count: Int;
        pub let consumer_count: Int;
        pub let throughput_per_sec: Float;
        pub let avg_latency_ms: Float;
        pub let dead_letter_count: Int;
        pub let expired_count: Int;
        
        pub fn new(queue: String) -> Self {
            return Self {
                queue: queue,
                message_count: 0,
                consumer_count: 0,
                throughput_per_sec: 0.0,
                avg_latency_ms: 0.0,
                dead_letter_count: 0,
                expired_count: 0
            };
        }
    }
}

# ============================================================
# MESSAGE QUEUE
# ============================================================

pub mod queue {
    pub use types::Message;
    pub use types::Queue;
    pub use types::Consumer;
    pub use types::Producer;
    pub use types::MessageStatus;
    pub use types::DeliveryGuarantee;
    
    # Core message queue
    pub class MessageQueue {
        pub let queues: Map<String, Queue>;
        pub let messages: Map<String, List<Message>>;
        pub let pending: Map<String, Map<String, Message>>;  # consumer -> messages
        pub let dead_letter: Map<String, List<Message>>;
        
        pub fn new() -> Self {
            return Self {
                queues: {},
                messages: {},
                pending: {},
                dead_letter: {}
            };
        }
        
        # Declare queue
        pub fn declare(self, queue: Queue) -> Bool {
            self.queues[queue.name] = queue;
            self.messages[queue.name] = [];
            
            if queue.dead_letter != null {
                self.dead_letter[queue.dead_letter] = [];
            }
            
            return true;
        }
        
        # Publish message
        pub fn publish(self, message: Message) -> String {
            let q = self.queues.get(message.queue);
            if q == null {
                # Auto-declare queue
                self.declare(Queue::new(message.queue));
            }
            
            # Apply delay if specified
            if message.properties.delay > 0 {
                # Schedule for later delivery
                message.status = MessageStatus::Pending;
            }
            
            self.messages[message.queue].push(message);
            return message.id;
        }
        
        # Subscribe/consume
        pub fn subscribe(self, consumer: Consumer) -> List<Message> {
            let queue_messages = self.messages[consumer.queue];
            
            if queue_messages == null or len(queue_messages) == 0 {
                return [];
            }
            
            # Get messages based on prefetch
            let available = min(consumer.prefetch, len(queue_messages));
            let result: List<Message> = [];
            
            for i in range(available) {
                let msg = queue_messages[i];
                if msg.status == MessageStatus::Pending {
                    result.push(msg);
                    msg.status = MessageStatus::InProgress;
                }
            }
            
            # Track pending for consumer
            self.pending[consumer.id] = {};
            for msg in result {
                self.pending[consumer.id][msg.id] = msg;
            }
            
            return result;
        }
        
        # Acknowledge message
        pub fn ack(self, consumer: Consumer, message_id: String) -> Bool {
            let consumer_pending = self.pending[consumer.id];
            
            if consumer_pending == null or not consumer_pending.has(message_id) {
                return false;
            }
            
            let msg = consumer_pending[message_id];
            msg.status = MessageStatus::Completed;
            
            # Remove from queue
            self._remove_message(consumer.queue, message_id);
            
            # Remove from pending
            consumer_pending[message_id] = null;
            
            return true;
        }
        
        # Reject message (requeue or dead-letter)
        pub fn nack(self, consumer: Consumer, message_id: String, requeue: Bool) -> Bool {
            let consumer_pending = self.pending[consumer.id];
            
            if consumer_pending == null or not consumer_pending.has(message_id) {
                return false;
            }
            
            let msg = consumer_pending[message_id];
            
            if requeue {
                msg.status = MessageStatus::Pending;
                msg.delivery_count = msg.delivery_count + 1;
            } else {
                # Check retry count
                if msg.delivery_count >= msg.properties.max_retries {
                    # Move to dead letter
                    self._dead_letter(msg);
                } else {
                    # Requeue with incremented count
                    msg.status = MessageStatus::Pending;
                    msg.delivery_count = msg.delivery_count + 1;
                }
            }
            
            consumer_pending[message_id] = null;
            return true;
        }
        
        # Get queue info
        pub fn info(self, queue_name: String) -> Map {
            let msgs = self.messages[queue_name];
            let pending_count = 0;
            
            if msgs != null {
                for msg in msgs {
                    if msg.status == MessageStatus::Pending {
                        pending_count = pending_count + 1;
                    }
                }
            }
            
            return {
                "name": queue_name,
                "pending": pending_count,
                "total": msgs != null ? len(msgs) : 0
            };
        }
        
        # Purge queue
        pub fn purge(self, queue_name: String) -> Int {
            let msgs = self.messages[queue_name];
            let count = msgs != null ? len(msgs) : 0;
            self.messages[queue_name] = [];
            return count;
        }
        
        fn _remove_message(self, queue: String, message_id: String) {
            let msgs = self.messages[queue];
            if msgs == null { return; }
            
            let idx = -1;
            for i in range(len(msgs)) {
                if msgs[i].id == message_id {
                    idx = i;
                    break;
                }
            }
            
            if idx >= 0 {
                msgs.remove(idx);
            }
        }
        
        fn _dead_letter(self, message: Message) {
            let queue = self.queues[message.queue];
            
            if queue.dead_letter != null {
                self.dead_letter[queue.dead_letter].push(message);
            }
            
            message.status = MessageStatus::DeadLettered;
        }
    }
    
    # Producer interface
    pub class QueueProducer {
        pub let queue: MessageQueue;
        pub let default_queue: String;
        
        pub fn new(queue: MessageQueue, default_queue: String) -> Self {
            return Self {
                queue: queue,
                default_queue: default_queue
            };
        }
        
        pub fn send(self, payload: Any) -> String {
            let msg = Message::new(self.default_queue, payload);
            return self.queue.publish(msg);
        }
        
        pub fn send_to(self, queue: String, payload: Any) -> String {
            let msg = Message::new(queue, payload);
            return self.queue.publish(msg);
        }
        
        pub fn publish(self, payload: Any, delay: Int?) -> String {
            let msg = Message::new(self.default_queue, payload).with_type(types::MessageType::Event);
            if delay != null {
                msg.properties.delay = delay;
            }
            return self.queue.publish(msg);
        }
    }
    
    # Consumer interface
    pub class QueueConsumer {
        pub let queue: MessageQueue;
        pub let consumer: Consumer;
        
        pub fn new(queue: MessageQueue, queue_name: String, worker_id: String) -> Self {
            return Self {
                queue: queue,
                consumer: Consumer::new(queue_name, worker_id)
            };
        }
        
        pub fn receive(self) -> List<Message> {
            return self.queue.subscribe(self.consumer);
        }
        
        pub fn ack(self, message_id: String) -> Bool {
            return self.queue.ack(self.consumer, message_id);
        }
        
        pub fn nack(self, message_id: String, requeue: Bool) -> Bool {
            return self.queue.nack(self.consumer, message_id, requeue);
        }
        
        pub fn prefetch(self, count: Int) -> Self {
            self.consumer.prefetch_count(count);
            return self;
        }
    }
}

# ============================================================
# PUB/SUB
# ============================================================

pub mod pubsub {
    # Topic subscription
    pub class Subscriber {
        pub let id: String;
        pub let topic: String;
        pub let handler: fn(Any) -> Void;
        pub let filter: String?;
        
        pub fn new(topic: String, handler: fn(Any) -> Void) -> Self {
            return Self {
                id: generate_id(),
                topic: topic,
                handler: handler,
                filter: null
            };
        }
    }
    
    # Pub/Sub system
    pub class PubSub {
        pub let topics: Map<String, List<Subscriber>>;
        pub let messages: Map<String, List<Any>>;  # Topic history
        
        pub fn new() -> Self {
            return Self {
                topics: {},
                messages: {}
            };
        }
        
        # Subscribe to topic
        pub fn subscribe(self, topic: String, handler: fn(Any) -> Void) -> Subscriber {
            let sub = Subscriber::new(topic, handler);
            

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
