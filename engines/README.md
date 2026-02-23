# Nyx Engines - Complete Ecosystem Documentation

**117 Production-Ready Engines for High-Performance Applications**

---

## 📋 Table of Contents

1. [Quick Start](#quick-start)
2. [Overview](#overview)
3. [Production Features Guide](#production-features-guide)
4. [Engine Categories](#engine-categories)
5. [Installation & Usage](#installation--usage)
6. [Complete Engine List](#complete-engine-list)
7. [API Reference](#api-reference)
8. [Best Practices](#best-practices)
9. [FAQ](#faq)

---

## Quick Start

Install any engine with nypm:

```bash
nypm install <engine-name>
```

Use in your Nyx code:

```nyx
use nycrypto;

let sha = nycrypto.SHA256::new();
sha.update("hello world");
println(sha.hexdigest());
```

---

## Overview

The Nyx Engine ecosystem provides **117 modular, production-ready engines** covering:

- **Core Infrastructure**: Runtime, scheduling, memory management
- **AI & ML**: Neural networks, agents, training, inference
- **Data Science**: Arrays, statistics, feature engineering, visualization
- **Web & APIs**: HTTP servers, frameworks, WebSocket, REST
- **Databases**: SQL, NoSQL, embedded, distributed
- **Security**: Cryptography, auditing, vulnerability scanning
- **DevOps**: CI/CD, deployment, monitoring, provisioning
- **Scientific**: Math, physics, chemistry, biology
- **Graphics**: 3D rendering, animation, visualization
- **Utilities**: Compression, serialization, utilities

Every engine includes **production-grade infrastructure**:
- ✅ Health monitoring & metrics
- ✅ Structured logging
- ✅ Error handling & recovery
- ✅ Configuration management
- ✅ Lifecycle management
- ✅ Distributed tracing
- ✅ Rate limiting & circuit breakers
- ✅ Graceful shutdown

---

## Production Features Guide

### 1. Health Monitoring

Every engine can report its health status:

```nyx
use production;

let runtime = production.ProductionRuntime::new();
let health = runtime.check_health();

println(health.status);      // "healthy", "degraded", or "unhealthy"
println(health.uptime_ms);   // Milliseconds since startup

// Check specific health aspects
health.add_check("database", db.is_connected(), "DB connection status");
health.add_check("memory", memory_usage < limit, "Memory within limits");

if health.is_healthy() {
    println("All systems go!");
}
```

### 2. Metrics Collection

Track performance with counters, gauges, and histograms:

```nyx
use production;

let runtime = production.ProductionRuntime::new();
let metrics = runtime.metrics;

// Counter: number of requests
metrics.increment("requests_total", 1);
metrics.increment("errors", 1);

// Gauge: current resource usage
metrics.gauge_set("active_connections", 42);
metrics.gauge_set("memory_mb", 512.5);
metrics.gauge_set("cpu_percent", 65.3);

// Histogram: latency distribution
metrics.histogram_observe("request_latency_ms", 125.4);
metrics.histogram_observe("database_query_ms", 45.2);

// Get snapshot
let snapshot = metrics.snapshot();
// snapshot = { "counters": {...}, "gauges": {...}, "uptime_ms": 3600000 }
```

### 3. Structured Logging

Log with context at multiple levels:

```nyx
use production;

let logger = production.Logger::new("info");  // debug, info, warn, error

logger.debug("Detailed diagnostic info", {
    "request_id": "abc123",
    "trace_id": "xyz789"
});

logger.info("Server started", {
    "port": 8080,
    "workers": 4,
    "tls_enabled": true
});

logger.warn("Performance degradation", {
    "response_time_ms": 2500,
    "threshold_ms": 1000
});

logger.error("Database connection failed", {
    "host": "db.example.com",
    "port": 5432,
    "error": "timeout after 5s",
    "retry_count": 3
});

// Flush logs for processing
let recent_logs = logger.flush();
for log_entry in recent_logs {
    send_to_logging_service(log_entry);
}
```

### 4. Error Handling & Recovery

Handle errors gracefully with recovery strategies:

```nyx
use error_handling;

let handler = error_handling.ErrorHandler::new();

// Register recovery strategies
let retry_strategy = error_handling.RecoveryStrategy::new(
    "retry_with_backoff",
    3,  // max attempts
    fn(err) {
        println(`Recovering: ${err.message}`);
        return fallback_service();
    }
);
handler.register_strategy("service_unavailable", retry_strategy);

// Set global fallback
handler.set_fallback(fn(err) {
    log_critical(err);
    send_alert("Critical error: " + err.message);
    return default_response();
});

// Handle errors
let error = error_handling.EngineError::new(
    "service_unavailable",
    "Primary service failed - retrying with backup",
    true  // recoverable
).with_context("service", "auth_service")
 .with_context("attempt", 1);

let result = handler.handle(error);
```

### 5. Configuration Management

Manage environment configuration safely:

```nyx
use config_management;

let config = config_management.EnvConfig::new();

// Set defaults
config.set_default("port", 8080);
config.set_default("log_level", "info");
config.set_default("max_connections", 100);

// Load from environment
config.set("database_url", env("DATABASE_URL"));
config.set("api_key", env("API_KEY"));
config.set("redis_host", env("REDIS_HOST") or "localhost");

// Mark required keys
config.require("database_url");
config.require("api_key");

// Validate configuration
let missing = config.validate();
if missing.len() > 0 {
    panic(`Missing required config: ${missing.join(", ")}`);
}

// Access config values
let port = config.get_int("port");
let log_level = config.get("log_level");
let is_debug = config.get_bool("debug_mode");
```

### 6. Feature Flags

Roll out features gradually to users:

```nyx
use config_management;

let flags = config_management.FeatureFlagManager::new();

// Register feature flags
let new_algorithm = config_management.FeatureFlag::new("use_ml_v2", false);
new_algorithm.rollout_pct = 10.0;  // Only 10% of users
flags.register(new_algorithm);

let new_ui = config_management.FeatureFlag::new("new_dashboard", true);
new_ui.rollout_pct = 100.0;  // Full rollout
flags.register(new_ui);

// Global flag check
if flags.is_enabled("new_dashboard") {
    show_new_dashboard();
} else {
    show_old_dashboard();
}

// User-specific canary deployment
if flags.is_enabled_for("use_ml_v2", user.id) {
    result = new_ml_algorithm(data);
} else {
    result = stable_algorithm(data);
}
```

### 7. Circuit Breaker

Prevent cascade failures:

```nyx
use production;

// Create circuit breaker
let breaker = production.CircuitBreaker::new(
    5,      // fail threshold
    30000   // reset timeout (30 seconds)
);

// Check state before making request
if breaker.allow_request() {
    try {
        let response = call_external_service();
        breaker.record_success();
        return response;
    } catch (err) {
        breaker.record_failure();
        throw err;
    }
} else {
    // Circuit is OPEN - return cached response
    println("Service unavailable - circuit breaker open");
    return cached_response();
}
```

### 8. Retry Policy

Automatic retry with exponential backoff:

```nyx
use production;

let retry = production.RetryPolicy::new(3);  // Max 3 retries

for attempt in 0..retry.max_retries {
    try {
        return operation();
    } catch (err) {
        if attempt == retry.max_retries - 1 {
            throw err;  // Last attempt failed
        }
        
        let delay_ms = retry.get_delay(attempt);
        println(`Retry ${attempt+1} after ${delay_ms}ms`);
        sleep(delay_ms);  // 100ms, 200ms, 400ms...
    }
}
```

### 9. Rate Limiting

Control request rate:

```nyx
use production;

let limiter = production.RateLimiter::new(
    100,    // max requests
    60000   // per minute (60 seconds)
);

// In request handler
if limiter.allow() {
    process_request(request);
} else {
    return error(429, "Too many requests", {
        "retry_after": 60
    });
}
```

### 10. Distributed Tracing

Trace requests across services:

```nyx
use observability;

let tracer = observability.Tracer::new("user_service");

let span = tracer.start_span("authenticate_user");
span.set_tag("user_id", user.id);
span.set_tag("provider", "oauth");

try {
    let result = verify_token(token);
    span.finish();
} catch (err) {
    span.finish_with_error(`Auth failed: ${err.message}`);
}

// Send traces to tracing backend
let traces = tracer.get_traces();
for trace in traces {
    let duration = trace.duration_ms();
    println(`${trace.operation} took ${duration}ms`);
    send_to_jaeger(trace);
}
```

### 11. Lifecycle Management

Manage application startup and shutdown:

```nyx
use lifecycle;

let lifecycle = lifecycle.LifecycleManager::new();

// Add startup phases in order
lifecycle.add_phase(lifecycle.Phase::new(
    "load_config",
    1,
    fn() {
        println("Loading configuration...");
        load_config_from_env();
    }
));

lifecycle.add_phase(lifecycle.Phase::new(
    "connect_database",
    2,
    fn() {
        println("Connecting to database...");
        db.connect(config.database_url);
    }
));

lifecycle.add_phase(lifecycle.Phase::new(
    "start_server",
    3,
    fn() {
        println("Starting HTTP server...");
        server.listen(config.port);
    }
));

// Register hooks
lifecycle.on("before_start", fn() {
    println("Pre-startup checks...");
});

lifecycle.on("after_start", fn() {
    println("Application started successfully!");
    send_ready_signal();
});

// Start the application
lifecycle.start();

if lifecycle.is_running() {
    println("Application is running");
}

// Handle graceful shutdown
on_signal("SIGTERM", fn() {
    println("Shutdown signal received");
    lifecycle.stop();
});
```

### 12. Graceful Shutdown

Clean shutdown with resource cleanup:

```nyx
use production;

let shutdown = production.GracefulShutdown::new(
    30000  // 30 second timeout
);

// Register shutdown hooks
shutdown.register("close_database", fn() {
    println("Closing database connections...");
    db.close();
});

shutdown.register("flush_cache", fn() {
    println("Flushing cache...");
    cache.flush();
});

shutdown.register("close_listeners", fn() {
    println("Closing network listeners...");
    listeners.close_all();
});

// Listen for shutdown signals
on_signal("SIGTERM", fn() {
    shutdown.shutdown();
});

on_signal("SIGINT", fn() {
    shutdown.shutdown();
});

// Wait for hooks to complete
if !shutdown.is_shutting_down {
    println("Server running");
} else {
    println("Server shutting down...");
}
```

---

## Engine Categories

### 🧠 AI & Machine Learning (20 engines)
nyai, nyagent, nygen, nygrad, nytensor, nynet_ml, nyml, nyloss, nymetrics, nyopt, nyrl, nyscale, nysecure, nyserve, nytrack, nymodel, nygraph_ml, nyfeature, nyaccel, nymlbridge

### 📊 Data & Analytics (15 engines)
nydata, nydatabase, nydb, nyquery, nystats, nymetrics, nyarray, nysci, nylinear, nyfeature, nyclustering, nysim, nypack, nyreport, nyviz

### 🔐 Security (8 engines)
nycrypto, nysec, nysecure, nyaudit, nyids, nyexploit, nyreverse, nymal

### 🌐 Web & Networking (12 engines)
nyweb, nyhttp, nynetwork, nyapi, nyframe, nyui, nycache, nyserverless, nyserve, nyqueue, nyevent, nyls

### 💾 Storage & Databases (6 engines)
nydatabase, nydb, nystorage, nystream, nyevent, nyqueue

### ⚙️ Infrastructure & DevOps (16 engines)
nycore, nybuild, nyci, nydeploy, nykube, nycloud, nyinfra, nymonitor, nysystem, nyruntime, nycontainer, nystats, nytrack, nysim, nyscale, nypack

### 🎨 Graphics & Visualization (8 engines)
nygpu, nyviz, nyrender, nygame, nyanim, nygui, nyui, nygraph

### 🔬 Scientific Computing (12 engines)
nysci, nyphysics, nychem, nybio, nyode, nyquant, nyalign, nycontrol, nyhpc, nylinear, nyarray, nymarket

### 📱 Utilities & Tools (4 engines)
nypm, nylang, nydoc, nyshell

And many more specialized engines!

---

## Installation & Usage

### Install an Engine

```bash
# Install single engine
nypm install nycrypto

# Install multiple engines
nypm install nycrypto nydata nynode_ml

# Install with dependencies
nypm install nymodel  # Automatically installs nytensor, nygrad
```

### Use in Code

```nyx
// Single import
use nycrypto;

// Multiple imports
use nycrypto, nydata, nymodel;

// Create instances
let sha = nycrypto.SHA256::new();
let trainer = nymodel.Trainer::new(model);

// Use with all features
let health = check_health_of_engine();
let metrics = collect_metrics();
```

### Check Dependencies

```bash
nypm show nycrypto
# Shows: description, version, dependencies, modules, capabilities
```

---

## Complete Engine List

### Core & Infrastructure
- **nycore** - Core runtime with task scheduling, ECS, memory management
- **nyruntime** - Runtime environment with process management
- **nysystem** - System programming with syscalls, processes, FFI
- **nykernel** - Kernel-level engine with memory and process scheduling

### AI & Machine Learning  
- **nyai** - AI platform with multi-modal LLMs and reasoning
- **nyagent** - Agent framework with planning, memory, reflection
- **nygen** - Generative AI with GANs, VAEs, diffusion models
- **nygrad** - Automatic differentiation engine
- **nytensor** - Tensor operations with broadcasting
- **nynet_ml** - Neural network layers and modules
- **nyml** - Machine learning with neural networks
- **nyloss** - Loss functions for training
- **nyopt** - Optimizers (SGD, Adam, RMSProp)
- **nymetrics** - Evaluation metrics and hyperparameter search
- **nytrack** - Experiment tracking and versioning
- **nymodel** - Model management with quantization, pruning
- **nyserve** - Model serving with batching and A/B testing
- **nyscale** - Distributed training with data/model parallelism
- **nysecure** - Secure AI with adversarial training
- **nygraph_ml** - Graph neural networks (GCN, GAT, GraphSAGE)
- **nyfeature** - Feature engineering and selection
- **nyrl** - Reinforcement learning (DQN, PPO, SAC)
- **nymlbridge** - ML framework interop (PyTorch, TensorFlow)
- **nyaccel** - Hardware acceleration on CPU/GPU

### Data & Analytics
- **nydata** - Data loading and augmentation
- **nydatabase** - SQL database with ORM
- **nydb** - Embedded database with MVCC
- **nyquery** - Query engine for SQL/graph/documents
- **nystats** - Statistics and distributions
- **nysci** - Scientific computing (autodiff, optimization)
- **nylinear** - Linear algebra (matrix ops, decomposition)
- **nyarray** - N-dimensional arrays with broadcasting
- **nypack** - Serialization and compression

### Web & Networking
- **nyweb** - Web framework with routing and middleware
- **nyhttp** - HTTP server with HTTPS, HTTP/2
- **nynetwork** - Networking (TCP, UDP, HTTP, WebSocket)
- **nyapi** - API gateway with rate limiting
- **nyframe** - Web framework engine
- **nyui** - Reactive UI with virtual DOM
- **nycache** - Caching engine (LRU, distributed)
- **nyqueue** - Message queue with jobs
- **nyevent** - Event streaming (Kafka-compatible)

### Security & Cryptography
- **nycrypto** - Cryptography (AES, RSA, hashing)
- **nysec** - Security tools (packet analysis, exploitation)
- **nysecure** - Secure AI (adversarial training)
- **nyaudit** - Security auditing and compliance
- **nyids** - IDS/IPS engine
- **nymal** - Malware analysis
- **nyreverse** - Reverse engineering tools
- **nyexploit** - Vulnerability exploitation

### DevOps & Infrastructure
- **nybuild** - Build system with task graphs
- **nyci** - CI/CD pipeline
- **nydeploy** - Deployment (rolling, canary)
- **nykube** - Kubernetes integration
- **nycloud** - Cloud resource management
- **nyinfra** - Infrastructure provisioning
- **nymonitor** - Monitoring and observability
- **nyconfig** - Configuration management
- **nyconsensus** - Consensus engines (Raft)
- **nycontainer** - Container runtime

### Storage & Databases
- **nystorage** - Key-value, document, file storage
- **nystream** - Stream processing
- **nycache** - Distributed caching

### Scientific & Specialized
- **nyphysics** - Physics engine (rigid/soft body)
- **nychem** - Chemistry engine
- **nybio** - Bioinformatics
- **nyode** - ODE solvers
- **nyquant** - Quantitative finance
- **nyalign** - Sequence alignment
- **nycontrol** - Control systems

### Graphics & Visualization
- **nygpu** - GPU compute (CUDA, Vulkan, Metal)
- **nyviz** - Data visualization
- **nyrender** - 3D rendering
- **nygame** - Game engine
- **nyanim** - Animation engine
- **nygui** - GUI framework

---

## API Reference

All engines follow this pattern:

### Initialization
```nyx
use engine_name;
let instance = engine_name.Class::new();
```

### Production Features
Every engine has these modules:
- `production` - Health, metrics, logging
- `observability` - Tracing, alerts
- `error_handling` - Error recovery
- `config_management` - Configuration, feature flags
- `lifecycle` - Startup/shutdown phases

### Configuration
From ny.pkg each engine provides:
- **modules**: Functional groupings
- **capabilities**: Feature list
- **dependencies**: Required engines
- **scripts**: Entry points

---

## Best Practices

### 1. Always Check Health
```nyx
let health = runtime.check_health();
if !health.is_healthy() {
    handle_degraded_mode();
}
```

### 2. Use Configuration for Deployment
```nyx
let config = config_management.EnvConfig::new();
config.require("api_key");
config.require("database_url");
```

### 3. Log Important Events
```nyx
logger.info("Server started", {
    "port": port,
    "version": "2.0.0",
    "workers": 4
});
```

### 4. Track Metrics
```nyx
metrics.increment("requests_total", 1);
metrics.histogram_observe("request_latency_ms", duration);
```

### 5. Use Circuit Breakers for External Services
```nyx
if breaker.allow_request() {
    call_service();
    breaker.record_success();
}
```

### 6. Implement Graceful Shutdown
```nyx
shutdown.register("cleanup", fn() {
    db.close();
    cache.flush();
});
on_signal("SIGTERM", fn() { shutdown.shutdown(); });
```

---

## FAQ

**Q: Which engines should I install?**
A: Install only what you need. Dependencies are installed automatically. Start with nycore, then add based on your use case.

**Q: How do I monitor an engine?**
A: Use the built-in `production` module:
```nyx
let runtime = production.ProductionRuntime::new();
let health = runtime.check_health();
let metrics = runtime.get_metrics();
```

**Q: Can I combine multiple engines?**
A: Yes! Engines are designed to work together. For example, use nydata with nymodel for ML pipelines.

**Q: How do I configure engines?**
A: Use `config_management.EnvConfig` to read environment variables and set defaults.

**Q: What if an engine fails?**
A: Use `error_handling.ErrorHandler` to register recovery strategies and fallbacks.

**Q: How do I deploy?**
A: Use `nydeploy` for deployment, `nybuild` for building, and `nyci` for CI/CD pipelines.

**Q: Can I see engine capabilities?**
A: Check the ny.pkg file in each engine directory or run `nypm show engine_name`.

---

## 📚 Documentation

Each engine includes:
- **README.md** - Detailed documentation with examples
- **ny.pkg** - Configuration with modules and capabilities
- **Engine Code** - Fully typed Nyx implementation

## 🔗 Related Resources

- [Nyx Language](https://github.com/nyxlang) - Main language repository
- [Nyx Package Manager](https://github.com/nyxlang/nypm) - Package management
- [Nyx Discord](https://discord.gg/nyx) - Community

---

**Nyx Engines v2.0.0** | Production-Ready | MIT License
