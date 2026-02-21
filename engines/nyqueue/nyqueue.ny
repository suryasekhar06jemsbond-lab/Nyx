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
            
