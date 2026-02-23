# ============================================================
# NYMARKET - Nyx Market Data Engine
# ============================================================
# Real-time tick ingestion, order book reconstruction,
# multi-exchange normalization, time synchronization,
# and historical data management.

let VERSION = "1.0.0";

# ============================================================
# MARKET DATA TYPES
# ============================================================

pub mod types {
    pub class Tick {
        pub let symbol: String;
        pub let exchange: String;
        pub let bid: Float;
        pub let ask: Float;
        pub let bid_size: Float;
        pub let ask_size: Float;
        pub let last: Float;
        pub let last_size: Float;
        pub let timestamp_ns: Int;
        pub let sequence: Int;

        pub fn mid(self) -> Float { return (self.bid + self.ask) / 2.0; }
        pub fn spread(self) -> Float { return self.ask - self.bid; }
        pub fn spread_bps(self) -> Float { return self.spread() / self.mid() * 10000.0; }
    }

    pub class Trade {
        pub let symbol: String;
        pub let exchange: String;
        pub let price: Float;
        pub let size: Float;
        pub let side: String;
        pub let timestamp_ns: Int;
        pub let trade_id: String;
        pub let conditions: List<String>;
    }

    pub class Bar {
        pub let symbol: String;
        pub let open: Float;
        pub let high: Float;
        pub let low: Float;
        pub let close: Float;
        pub let volume: Float;
        pub let vwap: Float;
        pub let trade_count: Int;
        pub let timestamp: Int;
        pub let period_ms: Int;

        pub fn range(self) -> Float { return self.high - self.low; }
        pub fn body(self) -> Float { return (self.close - self.open).abs(); }
        pub fn is_bullish(self) -> Bool { return self.close > self.open; }
    }

    pub class Level {
        pub let price: Float;
        pub let size: Float;
        pub let order_count: Int;
    }
}

# ============================================================
# ORDER BOOK
# ============================================================

pub mod orderbook {
    pub class OrderBook {
        pub let symbol: String;
        pub let bids: List<types.Level>;
        pub let asks: List<types.Level>;
        pub let timestamp_ns: Int;
        pub let sequence: Int;

        pub fn new(symbol: String) -> Self {
            return Self { symbol: symbol, bids: [], asks: [], timestamp_ns: 0, sequence: 0 };
        }

        pub fn best_bid(self) -> Float {
            if self.bids.len() == 0 { return 0.0; }
            return self.bids[0].price;
        }

        pub fn best_ask(self) -> Float {
            if self.asks.len() == 0 { return 0.0; }
            return self.asks[0].price;
        }

        pub fn mid_price(self) -> Float {
            return (self.best_bid() + self.best_ask()) / 2.0;
        }

        pub fn spread(self) -> Float {
            return self.best_ask() - self.best_bid();
        }

        pub fn microprice(self) -> Float {
            let bb = self.best_bid();
            let ba = self.best_ask();
            let bs = self.bids[0].size;
            let as_ = self.asks[0].size;
            return (bb * as_ + ba * bs) / (bs + as_);
        }

        pub fn depth(self, levels: Int) -> Map<String, Float> {
            let bid_depth = 0.0;
            let ask_depth = 0.0;
            for i in 0..levels.min(self.bids.len()) { bid_depth = bid_depth + self.bids[i].size; }
            for i in 0..levels.min(self.asks.len()) { ask_depth = ask_depth + self.asks[i].size; }
            return { "bid_depth": bid_depth, "ask_depth": ask_depth, "imbalance": bid_depth / (bid_depth + ask_depth) };
        }

        pub fn update_bid(self, price: Float, size: Float) {
            if size <= 0.0 {
                self.bids = self.bids.filter(|l| l.price != price);
                return;
            }
            for l in self.bids {
                if l.price == price { l.size = size; return; }
            }
            self.bids.append(types.Level { price: price, size: size, order_count: 1 });
            self.bids.sort_by(|a, b| b.price - a.price);
        }

        pub fn update_ask(self, price: Float, size: Float) {
            if size <= 0.0 {
                self.asks = self.asks.filter(|l| l.price != price);
                return;
            }
            for l in self.asks {
                if l.price == price { l.size = size; return; }
            }
            self.asks.append(types.Level { price: price, size: size, order_count: 1 });
            self.asks.sort_by(|a, b| a.price - b.price);
        }

        pub fn snapshot(self, depth: Int) -> Map<String, Any> {
            return {
                "symbol": self.symbol,
                "bids": self.bids.slice(0, depth),
                "asks": self.asks.slice(0, depth),
                "mid": self.mid_price(),
                "spread": self.spread(),
                "timestamp_ns": self.timestamp_ns
            };
        }
    }

    pub class OrderBookManager {
        pub let books: Map<String, OrderBook>;

        pub fn new() -> Self {
            return Self { books: {} };
        }

        pub fn get_or_create(self, symbol: String) -> OrderBook {
            if !self.books.contains_key(symbol) {
                self.books[symbol] = OrderBook::new(symbol);
            }
            return self.books[symbol];
        }

        pub fn process_update(self, symbol: String, side: String, price: Float, size: Float, ts: Int) {
            let book = self.get_or_create(symbol);
            book.timestamp_ns = ts;
            if side == "bid" { book.update_bid(price, size); }
            else { book.update_ask(price, size); }
        }
    }
}

# ============================================================
# DATA FEEDS & INGESTION
# ============================================================

pub mod feed {
    pub class FeedConfig {
        pub let exchange: String;
        pub let symbols: List<String>;
        pub let data_types: List<String>;
        pub let reconnect_ms: Int;
        pub let buffer_size: Int;

        pub fn new(exchange: String, symbols: List<String>) -> Self {
            return Self {
                exchange: exchange, symbols: symbols,
                data_types: ["trades", "quotes", "book"],
                reconnect_ms: 1000, buffer_size: 100000
            };
        }
    }

    pub class MarketFeed {
        pub let config: FeedConfig;
        pub let handle: Int?;
        pub let connected: Bool;
        pub let on_tick: Fn?;
        pub let on_trade: Fn?;
        pub let on_book: Fn?;
        pub let stats: FeedStats;

        pub fn new(config: FeedConfig) -> Self {
            return Self {
                config: config, handle: null,
                connected: false, on_tick: null,
                on_trade: null, on_book: null,
                stats: FeedStats::new()
            };
        }

        pub fn connect(self) {
            self.handle = native_market_connect(self.config);
            self.connected = true;
        }

        pub fn subscribe(self, symbols: List<String>) {
            native_market_subscribe(self.handle, symbols);
        }

        pub fn on_tick_data(self, callback: Fn) { self.on_tick = callback; }
        pub fn on_trade_data(self, callback: Fn) { self.on_trade = callback; }
        pub fn on_book_update(self, callback: Fn) { self.on_book = callback; }

        pub fn start(self) {
            native_market_start(self.handle, self.on_tick, self.on_trade, self.on_book);
        }

        pub fn stop(self) {
            if self.handle != null { native_market_stop(self.handle); }
            self.connected = false;
        }

        pub fn disconnect(self) {
            self.stop();
            if self.handle != null { native_market_disconnect(self.handle); }
        }
    }

    pub class FeedStats {
        pub let messages_received: Int;
        pub let bytes_received: Int;
        pub let errors: Int;
        pub let last_message_ns: Int;
        pub let latency_ns: Int;

        pub fn new() -> Self {
            return Self {
                messages_received: 0, bytes_received: 0,
                errors: 0, last_message_ns: 0, latency_ns: 0
            };
        }
    }

    pub class MultiFeed {
        pub let feeds: Map<String, MarketFeed>;
        pub let aggregator: Fn?;

        pub fn new() -> Self {
            return Self { feeds: {}, aggregator: null };
        }

        pub fn add_feed(self, name: String, feed: MarketFeed) {
            self.feeds[name] = feed;
        }

        pub fn connect_all(self) {
            for name, feed in self.feeds { feed.connect(); }
        }

        pub fn start_all(self) {
            for name, feed in self.feeds { feed.start(); }
        }

        pub fn stop_all(self) {
            for name, feed in self.feeds { feed.stop(); }
        }
    }
}

# ============================================================
# BAR AGGREGATION
# ============================================================

pub mod bars {
    pub class BarBuilder {
        pub let symbol: String;
        pub let period_ms: Int;
        pub let current: types.Bar?;
        pub let completed: List<types.Bar>;
        pub let on_bar: Fn?;

        pub fn new(symbol: String, period_ms: Int) -> Self {
            return Self {
                symbol: symbol, period_ms: period_ms,
                current: null, completed: [], on_bar: null
            };
        }

        pub fn process_trade(self, trade: types.Trade) {
            let bar_start = (trade.timestamp_ns / (self.period_ms * 1000000)) * (self.period_ms * 1000000);
            if self.current == null || bar_start != self.current.timestamp {
                if self.current != null {
                    self.completed.append(self.current);
                    if self.on_bar != null { self.on_bar(self.current); }
                }
                self.current = types.Bar {
                    symbol: self.symbol,
                    open: trade.price, high: trade.price,
                    low: trade.price, close: trade.price,
                    volume: trade.size, vwap: trade.price * trade.size,
                    trade_count: 1, timestamp: bar_start,
                    period_ms: self.period_ms
                };
            } else {
                self.current.high = max(self.current.high, trade.price);
                self.current.low = min(self.current.low, trade.price);
                self.current.close = trade.price;
                self.current.volume = self.current.volume + trade.size;
                self.current.vwap = self.current.vwap + trade.price * trade.size;
                self.current.trade_count = self.current.trade_count + 1;
            }
        }

        pub fn finalize(self) {
            if self.current != null {
                self.current.vwap = self.current.vwap / self.current.volume;
                self.completed.append(self.current);
                if self.on_bar != null { self.on_bar(self.current); }
                self.current = null;
            }
        }
    }
}

# ============================================================
# HISTORICAL DATA
# ============================================================

pub mod historical {
    pub class HistoricalStore {
        pub let handle: Int?;
        pub let path: String;

        pub fn new(path: String) -> Self {
            return Self { handle: null, path: path };
        }

        pub fn open(self) {
            self.handle = native_market_hist_open(self.path);
        }

        pub fn write_ticks(self, ticks: List<types.Tick>) {
            native_market_hist_write_ticks(self.handle, ticks);
        }

        pub fn write_trades(self, trades: List<types.Trade>) {
            native_market_hist_write_trades(self.handle, trades);
        }

        pub fn write_bars(self, bars_list: List<types.Bar>) {
            native_market_hist_write_bars(self.handle, bars_list);
        }

        pub fn read_ticks(self, symbol: String, start_ns: Int, end_ns: Int) -> List<types.Tick> {
            return native_market_hist_read_ticks(self.handle, symbol, start_ns, end_ns);
        }

        pub fn read_trades(self, symbol: String, start_ns: Int, end_ns: Int) -> List<types.Trade> {
            return native_market_hist_read_trades(self.handle, symbol, start_ns, end_ns);
        }

        pub fn read_bars(self, symbol: String, period_ms: Int, start: Int, end: Int) -> List<types.Bar> {
            return native_market_hist_read_bars(self.handle, symbol, period_ms, start, end);
        }

        pub fn close(self) {
            if self.handle != null { native_market_hist_close(self.handle); }
        }
    }
}

# ============================================================
# NORMALIZER
# ============================================================

pub mod normalizer {
    pub class SymbolMapper {
        pub let mappings: Map<String, Map<String, String>>;

        pub fn new() -> Self {
            return Self { mappings: {} };
        }

        pub fn add_mapping(self, canonical: String, exchange: String, exchange_symbol: String) {
            if !self.mappings.contains_key(canonical) { self.mappings[canonical] = {}; }
            self.mappings[canonical][exchange] = exchange_symbol;
        }

        pub fn to_canonical(self, exchange: String, exchange_symbol: String) -> String? {
            for canon, map in self.mappings {
                if map.get(exchange) == exchange_symbol { return canon; }
            }
            return null;
        }

        pub fn to_exchange(self, canonical: String, exchange: String) -> String? {
            if !self.mappings.contains_key(canonical) { return null; }
            return self.mappings[canonical].get(exchange);
        }
    }

    pub class DataNormalizer {
        pub let symbol_mapper: SymbolMapper;
        pub let time_zone: String;

        pub fn new() -> Self {
            return Self { symbol_mapper: SymbolMapper::new(), time_zone: "UTC" };
        }

        pub fn normalize_tick(self, tick: types.Tick) -> types.Tick {
            let canonical = self.symbol_mapper.to_canonical(tick.exchange, tick.symbol);
            if canonical != null { tick.symbol = canonical; }
            return tick;
        }

        pub fn normalize_trade(self, trade: types.Trade) -> types.Trade {
            let canonical = self.symbol_mapper.to_canonical(trade.exchange, trade.symbol);
            if canonical != null { trade.symbol = canonical; }
            return trade;
        }
    }
}

# ============================================================
# MARKET ENGINE ORCHESTRATOR
# ============================================================

pub class MarketEngine {
    pub let books: orderbook.OrderBookManager;
    pub let feeds: feed.MultiFeed;
    pub let normalizer_inst: normalizer.DataNormalizer;
    pub let bar_builders: Map<String, bars.BarBuilder>;
    pub let hist_store: historical.HistoricalStore?;

    pub fn new() -> Self {
        return Self {
            books: orderbook.OrderBookManager::new(),
            feeds: feed.MultiFeed::new(),
            normalizer_inst: normalizer.DataNormalizer::new(),
            bar_builders: {},
            hist_store: null
        };
    }

    pub fn add_feed(self, name: String, config: feed.FeedConfig) {
        let f = feed.MarketFeed::new(config);
        self.feeds.add_feed(name, f);
    }

    pub fn get_book(self, symbol: String) -> orderbook.OrderBook {
        return self.books.get_or_create(symbol);
    }

    pub fn start(self) {
        self.feeds.connect_all();
        self.feeds.start_all();
    }

    pub fn stop(self) {
        self.feeds.stop_all();
    }
}

pub fn create_market_engine() -> MarketEngine {
    return MarketEngine::new();
}

# ============================================================
# NATIVE HOOKS
# ============================================================

native_market_connect(config: Any) -> Int;
native_market_subscribe(handle: Int, symbols: List);
native_market_start(handle: Int, on_tick: Fn, on_trade: Fn, on_book: Fn);
native_market_stop(handle: Int);
native_market_disconnect(handle: Int);
native_market_hist_open(path: String) -> Int;
native_market_hist_write_ticks(handle: Int, ticks: List);
native_market_hist_write_trades(handle: Int, trades: List);
native_market_hist_write_bars(handle: Int, bars: List);
native_market_hist_read_ticks(handle: Int, symbol: String, start: Int, end: Int) -> List;
native_market_hist_read_trades(handle: Int, symbol: String, start: Int, end: Int) -> List;
native_market_hist_read_bars(handle: Int, symbol: String, period: Int, start: Int, end: Int) -> List;
native_market_hist_close(handle: Int);

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
