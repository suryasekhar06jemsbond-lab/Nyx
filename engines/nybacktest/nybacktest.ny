# ============================================================
# NYBACKTEST - Nyx Backtesting Engine
# ============================================================
# Historical replay, event-driven strategy testing, slippage
# and transaction cost modeling, multi-asset support, and
# comprehensive performance analytics.

let VERSION = "1.0.0";

# ============================================================
# STRATEGY INTERFACE
# ============================================================

pub mod strategy {
    pub class StrategyConfig {
        pub let name: String;
        pub let symbols: List<String>;
        pub let initial_capital: Float;
        pub let commission_rate: Float;
        pub let slippage_bps: Float;
        pub let position_sizing: String;
        pub let max_position_pct: Float;

        pub fn new(name: String) -> Self {
            return Self {
                name: name, symbols: [],
                initial_capital: 100000.0,
                commission_rate: 0.001,
                slippage_bps: 1.0,
                position_sizing: "fixed",
                max_position_pct: 0.1
            };
        }
    }

    pub class Signal {
        pub let symbol: String;
        pub let direction: String;
        pub let strength: Float;
        pub let timestamp: Int;
        pub let metadata: Map<String, Any>;

        pub fn buy(symbol: String, strength: Float) -> Self {
            return Self { symbol: symbol, direction: "buy", strength: strength, timestamp: 0, metadata: {} };
        }

        pub fn sell(symbol: String, strength: Float) -> Self {
            return Self { symbol: symbol, direction: "sell", strength: strength, timestamp: 0, metadata: {} };
        }
    }

    pub class Strategy {
        pub let config: StrategyConfig;
        pub let on_bar: Fn?;
        pub let on_tick: Fn?;
        pub let on_trade_event: Fn?;
        pub let state: Map<String, Any>;

        pub fn new(config: StrategyConfig) -> Self {
            return Self { config: config, on_bar: null, on_tick: null, on_trade_event: null, state: {} };
        }

        pub fn set_bar_handler(self, handler: Fn) { self.on_bar = handler; }
        pub fn set_tick_handler(self, handler: Fn) { self.on_tick = handler; }
    }
}

# ============================================================
# PORTFOLIO & POSITIONS
# ============================================================

pub mod portfolio {
    pub class Position {
        pub let symbol: String;
        pub let quantity: Float;
        pub let avg_price: Float;
        pub let unrealized_pnl: Float;
        pub let realized_pnl: Float;
        pub let opened_at: Int;

        pub fn new(symbol: String) -> Self {
            return Self {
                symbol: symbol, quantity: 0.0,
                avg_price: 0.0, unrealized_pnl: 0.0,
                realized_pnl: 0.0, opened_at: 0
            };
        }

        pub fn market_value(self, price: Float) -> Float {
            return self.quantity * price;
        }

        pub fn update_pnl(self, current_price: Float) {
            self.unrealized_pnl = self.quantity * (current_price - self.avg_price);
        }

        pub fn is_long(self) -> Bool { return self.quantity > 0.0; }
        pub fn is_short(self) -> Bool { return self.quantity < 0.0; }
        pub fn is_flat(self) -> Bool { return self.quantity == 0.0; }
    }

    pub class Portfolio {
        pub let cash: Float;
        pub let initial_capital: Float;
        pub let positions: Map<String, Position>;
        pub let equity_curve: List<Float>;
        pub let trade_log: List<Map<String, Any>>;

        pub fn new(capital: Float) -> Self {
            return Self {
                cash: capital, initial_capital: capital,
                positions: {}, equity_curve: [capital],
                trade_log: []
            };
        }

        pub fn equity(self, prices: Map<String, Float>) -> Float {
            let total = self.cash;
            for sym, pos in self.positions {
                let price = prices.get(sym, pos.avg_price);
                total = total + pos.market_value(price);
            }
            return total;
        }

        pub fn execute_fill(self, symbol: String, quantity: Float, price: Float,
                            commission: Float, timestamp: Int) {
            if !self.positions.contains_key(symbol) {
                self.positions[symbol] = Position::new(symbol);
            }
            let pos = self.positions[symbol];
            let cost = quantity * price + commission;

            if (pos.quantity > 0.0 && quantity > 0.0) || (pos.quantity < 0.0 && quantity < 0.0) {
                let total_qty = pos.quantity + quantity;
                pos.avg_price = (pos.avg_price * pos.quantity + price * quantity) / total_qty;
                pos.quantity = total_qty;
            } else {
                let close_qty = min(quantity.abs(), pos.quantity.abs());
                let pnl = close_qty * (price - pos.avg_price) * (if pos.is_long() { 1.0 } else { -1.0 });
                pos.realized_pnl = pos.realized_pnl + pnl - commission;
                pos.quantity = pos.quantity + quantity;
                if pos.is_flat() { pos.avg_price = 0.0; }
            }

            self.cash = self.cash - cost;
            self.trade_log.append({
                "symbol": symbol, "quantity": quantity,
                "price": price, "commission": commission,
                "timestamp": timestamp
            });
        }

        pub fn record_equity(self, prices: Map<String, Float>) {
            self.equity_curve.append(self.equity(prices));
        }
    }
}

# ============================================================
# EVENT ENGINE
# ============================================================

pub mod events {
    pub class BacktestEvent {
        pub let event_type: String;
        pub let timestamp: Int;
        pub let data: Any;

        pub fn bar(timestamp: Int, bar: Any) -> Self {
            return Self { event_type: "bar", timestamp: timestamp, data: bar };
        }

        pub fn tick(timestamp: Int, tick: Any) -> Self {
            return Self { event_type: "tick", timestamp: timestamp, data: tick };
        }

        pub fn signal(timestamp: Int, signal: Any) -> Self {
            return Self { event_type: "signal", timestamp: timestamp, data: signal };
        }

        pub fn fill(timestamp: Int, fill: Any) -> Self {
            return Self { event_type: "fill", timestamp: timestamp, data: fill };
        }
    }

    pub class EventQueue {
        pub let events: List<BacktestEvent>;

        pub fn new() -> Self {
            return Self { events: [] };
        }

        pub fn push(self, event: BacktestEvent) {
            self.events.append(event);
        }

        pub fn pop(self) -> BacktestEvent? {
            if self.events.len() == 0 { return null; }
            return self.events.remove(0);
        }

        pub fn is_empty(self) -> Bool { return self.events.len() == 0; }
    }
}

# ============================================================
# EXECUTION SIMULATOR
# ============================================================

pub mod execution {
    pub class FillModel {
        pub let slippage_bps: Float;
        pub let commission_rate: Float;
        pub let partial_fill_prob: Float;

        pub fn new(slippage_bps: Float, commission_rate: Float) -> Self {
            return Self {
                slippage_bps: slippage_bps,
                commission_rate: commission_rate,
                partial_fill_prob: 0.0
            };
        }

        pub fn simulate_fill(self, symbol: String, quantity: Float, price: Float,
                              side: String) -> Map<String, Any> {
            let slippage = price * self.slippage_bps / 10000.0;
            let fill_price = if side == "buy" { price + slippage } else { price - slippage };
            let commission = (fill_price * quantity.abs()) * self.commission_rate;
            return {
                "symbol": symbol, "quantity": quantity,
                "fill_price": fill_price, "commission": commission,
                "slippage": slippage
            };
        }
    }

    pub class OrderManager {
        pub let pending_orders: List<Map<String, Any>>;
        pub let filled_orders: List<Map<String, Any>>;
        pub let fill_model: FillModel;

        pub fn new(fill_model: FillModel) -> Self {
            return Self { pending_orders: [], filled_orders: [], fill_model: fill_model };
        }

        pub fn submit_market(self, symbol: String, quantity: Float, timestamp: Int) {
            self.pending_orders.append({
                "type": "market", "symbol": symbol,
                "quantity": quantity, "timestamp": timestamp
            });
        }

        pub fn submit_limit(self, symbol: String, quantity: Float, limit_price: Float, timestamp: Int) {
            self.pending_orders.append({
                "type": "limit", "symbol": symbol,
                "quantity": quantity, "limit_price": limit_price,
                "timestamp": timestamp
            });
        }

        pub fn process(self, prices: Map<String, Float>, timestamp: Int) -> List<Map<String, Any>> {
            let fills = [];
            let remaining = [];
            for order in self.pending_orders {
                let price = prices.get(order["symbol"]);
                if price == null { remaining.append(order); continue; }
                if order["type"] == "market" {
                    let side = if order["quantity"] > 0.0 { "buy" } else { "sell" };
                    let fill = self.fill_model.simulate_fill(
                        order["symbol"], order["quantity"], price, side);
                    fill["timestamp"] = timestamp;
                    fills.append(fill);
                    self.filled_orders.append(fill);
                } else if order["type"] == "limit" {
                    let should_fill = (order["quantity"] > 0.0 && price <= order["limit_price"])
                        || (order["quantity"] < 0.0 && price >= order["limit_price"]);
                    if should_fill {
                        let side = if order["quantity"] > 0.0 { "buy" } else { "sell" };
                        let fill = self.fill_model.simulate_fill(
                            order["symbol"], order["quantity"], order["limit_price"], side);
                        fill["timestamp"] = timestamp;
                        fills.append(fill);
                        self.filled_orders.append(fill);
                    } else {
                        remaining.append(order);
                    }
                }
            }
            self.pending_orders = remaining;
            return fills;
        }
    }
}

# ============================================================
# PERFORMANCE ANALYTICS
# ============================================================

pub mod analytics {
    pub class PerformanceReport {
        pub let total_return: Float;
        pub let annualized_return: Float;
        pub let sharpe_ratio: Float;
        pub let sortino_ratio: Float;
        pub let max_drawdown: Float;
        pub let max_drawdown_duration: Int;
        pub let win_rate: Float;
        pub let profit_factor: Float;
        pub let total_trades: Int;
        pub let avg_trade_pnl: Float;
        pub let calmar_ratio: Float;
        pub let volatility: Float;
    }

    pub class PerformanceAnalyzer {
        pub fn analyze(self, equity_curve: List<Float>, trades: List<Map<String, Any>>,
                       trading_days: Int) -> PerformanceReport {
            let returns = self._compute_returns(equity_curve);
            let total_ret = if equity_curve.len() > 0 {
                (equity_curve.last() / equity_curve[0]) - 1.0
            } else { 0.0 };
            let ann_ret = (1.0 + total_ret).pow(252.0 / trading_days as Float) - 1.0;
            let vol = self._std(returns) * (252.0).sqrt();
            let sharpe = if vol > 0.0 { ann_ret / vol } else { 0.0 };
            let downside = self._downside_std(returns) * (252.0).sqrt();
            let sortino = if downside > 0.0 { ann_ret / downside } else { 0.0 };
            let dd = self._max_drawdown(equity_curve);
            let calmar = if dd["max_dd"] > 0.0 { ann_ret / dd["max_dd"] } else { 0.0 };
            let trade_stats = self._trade_stats(trades);

            return PerformanceReport {
                total_return: total_ret,
                annualized_return: ann_ret,
                sharpe_ratio: sharpe,
                sortino_ratio: sortino,
                max_drawdown: dd["max_dd"],
                max_drawdown_duration: dd["duration"],
                win_rate: trade_stats["win_rate"],
                profit_factor: trade_stats["profit_factor"],
                total_trades: trades.len(),
                avg_trade_pnl: trade_stats["avg_pnl"],
                calmar_ratio: calmar,
                volatility: vol
            };
        }

        fn _compute_returns(self, equity: List<Float>) -> List<Float> {
            let returns = [];
            for i in 1..equity.len() {
                returns.append((equity[i] / equity[i - 1]) - 1.0);
            }
            return returns;
        }

        fn _std(self, values: List<Float>) -> Float {
            if values.len() < 2 { return 0.0; }
            let mean = values.sum() / values.len() as Float;
            let variance = 0.0;
            for v in values { variance = variance + (v - mean) * (v - mean); }
            return (variance / (values.len() - 1) as Float).sqrt();
        }

        fn _downside_std(self, returns: List<Float>) -> Float {
            let negative = returns.filter(|r| r < 0.0);
            if negative.len() < 2 { return 0.0; }
            return self._std(negative);
        }

        fn _max_drawdown(self, equity: List<Float>) -> Map<String, Any> {
            let peak = equity[0];
            let max_dd = 0.0;
            let max_dur = 0;
            let cur_dur = 0;
            for e in equity {
                if e > peak { peak = e; cur_dur = 0; }
                let dd = (peak - e) / peak;
                if dd > max_dd { max_dd = dd; }
                if e < peak { cur_dur = cur_dur + 1; }
                if cur_dur > max_dur { max_dur = cur_dur; }
            }
            return { "max_dd": max_dd, "duration": max_dur };
        }

        fn _trade_stats(self, trades: List<Map<String, Any>>) -> Map<String, Any> {
            if trades.len() == 0 {
                return { "win_rate": 0.0, "profit_factor": 0.0, "avg_pnl": 0.0 };
            }
            let wins = 0;
            let gross_profit = 0.0;
            let gross_loss = 0.0;
            let total_pnl = 0.0;
            for t in trades {
                let pnl = t.get("pnl", 0.0);
                total_pnl = total_pnl + pnl;
                if pnl > 0.0 { wins = wins + 1; gross_profit = gross_profit + pnl; }
                else { gross_loss = gross_loss + pnl.abs(); }
            }
            return {
                "win_rate": wins as Float / trades.len() as Float,
                "profit_factor": if gross_loss > 0.0 { gross_profit / gross_loss } else { 999.0 },
                "avg_pnl": total_pnl / trades.len() as Float
            };
        }
    }
}

# ============================================================
# BACKTEST ENGINE ORCHESTRATOR
# ============================================================

pub class BacktestEngine {
    pub let strat: strategy.Strategy;
    pub let port: portfolio.Portfolio;
    pub let order_mgr: execution.OrderManager;
    pub let analyzer: analytics.PerformanceAnalyzer;
    pub let event_queue: events.EventQueue;

    pub fn new(config: strategy.StrategyConfig) -> Self {
        let fm = execution.FillModel::new(config.slippage_bps, config.commission_rate);
        return Self {
            strat: strategy.Strategy::new(config),
            port: portfolio.Portfolio::new(config.initial_capital),
            order_mgr: execution.OrderManager::new(fm),
            analyzer: analytics.PerformanceAnalyzer::new(),
            event_queue: events.EventQueue::new()
        };
    }

    pub fn run_bars(self, bars_data: Map<String, List<Any>>) -> analytics.PerformanceReport {
        let timestamps = bars_data.values()[0].map(|b| b.timestamp);
        for i in 0..timestamps.len() {
            let current_prices = {};
            let current_bars = {};
            for sym, bar_list in bars_data {
                current_bars[sym] = bar_list[i];
                current_prices[sym] = bar_list[i].close;
            }
            let fills = self.order_mgr.process(current_prices, timestamps[i]);
            for fill in fills {
                self.port.execute_fill(
                    fill["symbol"], fill["quantity"],
                    fill["fill_price"], fill["commission"],
                    fill["timestamp"]
                );
            }
            if self.strat.on_bar != null {
                self.strat.on_bar(current_bars, self.port, self.order_mgr);
            }
            self.port.record_equity(current_prices);
        }
        return self.analyzer.analyze(self.port.equity_curve, self.port.trade_log, timestamps.len());
    }
}

pub fn create_backtest_engine(config: strategy.StrategyConfig) -> BacktestEngine {
    return BacktestEngine::new(config);
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
