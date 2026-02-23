# ============================================================
# NyOpt - Optimization Engine
# Version 1.0.0
# SGD, Adam, AdamW, RMSProp, LR schedulers, gradient clipping
# ============================================================

use nytensor;
use nygrad;
use nynet_ml;

# ============================================================
# SECTION 1: BASE OPTIMIZER
# ============================================================

pub class Optimizer {
    pub let params: [Parameter];
    pub let lr: Float;
    pub let _step_count: Int;
    pub let _state: Object;

    pub fn new(params: [Parameter], lr: Float) -> Self {
        return Self { params: params, lr: lr, _step_count: 0, _state: {} };
    }

    pub fn step(self) {
        throw "Optimizer::step() must be overridden";
    }

    pub fn zero_grad(self) {
        for (p in self.params) {
            p.data.zero_grad();
        }
    }
}

# ============================================================
# SECTION 2: SGD (STOCHASTIC GRADIENT DESCENT)
# ============================================================

pub class SGD : Optimizer {
    pub let momentum: Float;
    pub let dampening: Float;
    pub let weight_decay: Float;
    pub let nesterov: Bool;
    pub let _velocity: [Tensor];

    pub fn new(params: [Parameter], lr: Float, momentum: Float,
               dampening: Float, weight_decay: Float, nesterov: Bool) -> Self {
        let velocities = [];
        for (p in params) {
            velocities = velocities + [Tensor::zeros(p.data.shape(), DType::Float32, Device::CPU)];
        }
        return Self {
            params: params, lr: lr, _step_count: 0, _state: {},
            momentum: momentum, dampening: dampening,
            weight_decay: weight_decay, nesterov: nesterov,
            _velocity: velocities
        };
    }

    pub fn step(self) {
        for (i in range(len(self.params))) {
            let p = self.params[i];
            if (p._frozen) { continue; }
            let grad = p.data.grad();
            if (grad == null) { continue; }

            # Weight decay (L2 regularization)
            if (self.weight_decay > 0.0) {
                grad = grad.add(p.data.data.scale(self.weight_decay));
            }

            if (self.momentum > 0.0) {
                # v = momentum * v + (1 - dampening) * grad
                self._velocity[i] = self._velocity[i].scale(self.momentum)
                    .add(grad.scale(1.0 - self.dampening));

                if (self.nesterov) {
                    grad = grad.add(self._velocity[i].scale(self.momentum));
                } else {
                    grad = self._velocity[i];
                }
            }

            # param = param - lr * grad
            let update = grad.scale(self.lr);
            p.data.data = p.data.data.sub(update);
        }
        self._step_count = self._step_count + 1;
    }
}

# ============================================================
# SECTION 3: ADAM OPTIMIZER
# ============================================================

pub class Adam : Optimizer {
    pub let beta1: Float;
    pub let beta2: Float;
    pub let eps: Float;
    pub let weight_decay: Float;
    pub let amsgrad: Bool;
    pub let _m: [Tensor];
    pub let _v: [Tensor];
    pub let _v_max: [Tensor];

    pub fn new(params: [Parameter], lr: Float, beta1: Float,
               beta2: Float, eps: Float, weight_decay: Float,
               amsgrad: Bool) -> Self {
        let m = [];
        let v = [];
        let vm = [];
        for (p in params) {
            let shape = p.data.shape();
            m = m + [Tensor::zeros(shape, DType::Float32, Device::CPU)];
            v = v + [Tensor::zeros(shape, DType::Float32, Device::CPU)];
            vm = vm + [Tensor::zeros(shape, DType::Float32, Device::CPU)];
        }
        return Self {
            params: params, lr: lr, _step_count: 0, _state: {},
            beta1: beta1, beta2: beta2, eps: eps,
            weight_decay: weight_decay, amsgrad: amsgrad,
            _m: m, _v: v, _v_max: vm
        };
    }

    pub fn step(self) {
        self._step_count = self._step_count + 1;
        let bc1 = 1.0 - _pow(self.beta1, self._step_count);
        let bc2 = 1.0 - _pow(self.beta2, self._step_count);

        for (i in range(len(self.params))) {
            let p = self.params[i];
            if (p._frozen) { continue; }
            let grad = p.data.grad();
            if (grad == null) { continue; }

            # L2 weight decay
            if (self.weight_decay > 0.0) {
                grad = grad.add(p.data.data.scale(self.weight_decay));
            }

            # m = beta1 * m + (1 - beta1) * grad
            self._m[i] = self._m[i].scale(self.beta1).add(grad.scale(1.0 - self.beta1));
            # v = beta2 * v + (1 - beta2) * grad^2
            self._v[i] = self._v[i].scale(self.beta2).add(grad.mul(grad).scale(1.0 - self.beta2));

            let m_hat = self._m[i].scale(1.0 / bc1);
            let v_hat = self._v[i].scale(1.0 / bc2);

            if (self.amsgrad) {
                # v_max = max(v_max, v_hat)
                let vmax_data = [];
                for (j in range(v_hat.numel())) {
                    let a = self._v_max[i].data[j];
                    let b = v_hat.data[j];
                    vmax_data = vmax_data + [a > b ? a : b];
                }
                self._v_max[i] = Tensor::new(vmax_data, v_hat.shape.dims, v_hat.dtype, v_hat.device);
                v_hat = self._v_max[i];
            }

            # param = param - lr * m_hat / (sqrt(v_hat) + eps)
            let denom = v_hat.sqrt().add_scalar(self.eps);
            let update = m_hat.div(denom).scale(self.lr);
            p.data.data = p.data.data.sub(update);
        }
    }
}

# ============================================================
# SECTION 4: ADAMW OPTIMIZER (DECOUPLED WEIGHT DECAY)
# ============================================================

pub class AdamW : Optimizer {
    pub let beta1: Float;
    pub let beta2: Float;
    pub let eps: Float;
    pub let weight_decay: Float;
    pub let _m: [Tensor];
    pub let _v: [Tensor];

    pub fn new(params: [Parameter], lr: Float, beta1: Float,
               beta2: Float, eps: Float, weight_decay: Float) -> Self {
        let m = [];
        let v = [];
        for (p in params) {
            let shape = p.data.shape();
            m = m + [Tensor::zeros(shape, DType::Float32, Device::CPU)];
            v = v + [Tensor::zeros(shape, DType::Float32, Device::CPU)];
        }
        return Self {
            params: params, lr: lr, _step_count: 0, _state: {},
            beta1: beta1, beta2: beta2, eps: eps,
            weight_decay: weight_decay, _m: m, _v: v
        };
    }

    pub fn step(self) {
        self._step_count = self._step_count + 1;
        let bc1 = 1.0 - _pow(self.beta1, self._step_count);
        let bc2 = 1.0 - _pow(self.beta2, self._step_count);

        for (i in range(len(self.params))) {
            let p = self.params[i];
            if (p._frozen) { continue; }
            let grad = p.data.grad();
            if (grad == null) { continue; }

            # Decoupled weight decay (applied directly to params, not grad)
            if (self.weight_decay > 0.0) {
                p.data.data = p.data.data.scale(1.0 - self.lr * self.weight_decay);
            }

            self._m[i] = self._m[i].scale(self.beta1).add(grad.scale(1.0 - self.beta1));
            self._v[i] = self._v[i].scale(self.beta2).add(grad.mul(grad).scale(1.0 - self.beta2));

            let m_hat = self._m[i].scale(1.0 / bc1);
            let v_hat = self._v[i].scale(1.0 / bc2);

            let denom = v_hat.sqrt().add_scalar(self.eps);
            let update = m_hat.div(denom).scale(self.lr);
            p.data.data = p.data.data.sub(update);
        }
    }
}

# ============================================================
# SECTION 5: RMSPROP OPTIMIZER
# ============================================================

pub class RMSProp : Optimizer {
    pub let alpha: Float;
    pub let eps: Float;
    pub let weight_decay: Float;
    pub let momentum: Float;
    pub let centered: Bool;
    pub let _v: [Tensor];
    pub let _buf: [Tensor];
    pub let _g_avg: [Tensor];

    pub fn new(params: [Parameter], lr: Float, alpha: Float, eps: Float,
               weight_decay: Float, momentum: Float, centered: Bool) -> Self {
        let v = [];
        let buf = [];
        let ga = [];
        for (p in params) {
            let shape = p.data.shape();
            v = v + [Tensor::zeros(shape, DType::Float32, Device::CPU)];
            buf = buf + [Tensor::zeros(shape, DType::Float32, Device::CPU)];
            ga = ga + [Tensor::zeros(shape, DType::Float32, Device::CPU)];
        }
        return Self {
            params: params, lr: lr, _step_count: 0, _state: {},
            alpha: alpha, eps: eps, weight_decay: weight_decay,
            momentum: momentum, centered: centered,
            _v: v, _buf: buf, _g_avg: ga
        };
    }

    pub fn step(self) {
        self._step_count = self._step_count + 1;
        for (i in range(len(self.params))) {
            let p = self.params[i];
            if (p._frozen) { continue; }
            let grad = p.data.grad();
            if (grad == null) { continue; }

            if (self.weight_decay > 0.0) {
                grad = grad.add(p.data.data.scale(self.weight_decay));
            }

            # v = alpha * v + (1 - alpha) * grad^2
            self._v[i] = self._v[i].scale(self.alpha).add(grad.mul(grad).scale(1.0 - self.alpha));

            let avg = self._v[i];
            if (self.centered) {
                self._g_avg[i] = self._g_avg[i].scale(self.alpha).add(grad.scale(1.0 - self.alpha));
                avg = avg.sub(self._g_avg[i].mul(self._g_avg[i]));
            }

            let denom = avg.sqrt().add_scalar(self.eps);

            if (self.momentum > 0.0) {
                self._buf[i] = self._buf[i].scale(self.momentum).add(grad.div(denom));
                p.data.data = p.data.data.sub(self._buf[i].scale(self.lr));
            } else {
                p.data.data = p.data.data.sub(grad.div(denom).scale(self.lr));
            }
        }
    }
}

# ============================================================
# SECTION 6: ADAGRAD OPTIMIZER
# ============================================================

pub class Adagrad : Optimizer {
    pub let eps: Float;
    pub let weight_decay: Float;
    pub let _sum: [Tensor];

    pub fn new(params: [Parameter], lr: Float, eps: Float, weight_decay: Float) -> Self {
        let s = [];
        for (p in params) {
            s = s + [Tensor::zeros(p.data.shape(), DType::Float32, Device::CPU)];
        }
        return Self {
            params: params, lr: lr, _step_count: 0, _state: {},
            eps: eps, weight_decay: weight_decay, _sum: s
        };
    }

    pub fn step(self) {
        self._step_count = self._step_count + 1;
        for (i in range(len(self.params))) {
            let p = self.params[i];
            if (p._frozen) { continue; }
            let grad = p.data.grad();
            if (grad == null) { continue; }

            if (self.weight_decay > 0.0) {
                grad = grad.add(p.data.data.scale(self.weight_decay));
            }

            self._sum[i] = self._sum[i].add(grad.mul(grad));
            let denom = self._sum[i].sqrt().add_scalar(self.eps);
            p.data.data = p.data.data.sub(grad.div(denom).scale(self.lr));
        }
    }
}

# ============================================================
# SECTION 7: LEARNING RATE SCHEDULERS
# ============================================================

pub class LRScheduler {
    pub let optimizer: Optimizer;
    pub let base_lr: Float;
    pub let _epoch: Int;

    pub fn new(optimizer: Optimizer) -> Self {
        return Self { optimizer: optimizer, base_lr: optimizer.lr, _epoch: 0 };
    }

    pub fn step(self) { self._epoch = self._epoch + 1; }
    pub fn get_lr(self) -> Float { return self.optimizer.lr; }
}

pub class StepLR : LRScheduler {
    pub let step_size: Int;
    pub let gamma: Float;

    pub fn new(optimizer: Optimizer, step_size: Int, gamma: Float) -> Self {
        return Self {
            optimizer: optimizer, base_lr: optimizer.lr, _epoch: 0,
            step_size: step_size, gamma: gamma
        };
    }

    pub fn step(self) {
        self._epoch = self._epoch + 1;
        if (self._epoch % self.step_size == 0) {
            self.optimizer.lr = self.optimizer.lr * self.gamma;
        }
    }
}

pub class ExponentialLR : LRScheduler {
    pub let gamma: Float;

    pub fn new(optimizer: Optimizer, gamma: Float) -> Self {
        return Self {
            optimizer: optimizer, base_lr: optimizer.lr, _epoch: 0,
            gamma: gamma
        };
    }

    pub fn step(self) {
        self._epoch = self._epoch + 1;
        self.optimizer.lr = self.base_lr * _pow(self.gamma, self._epoch);
    }
}

pub class CosineAnnealingLR : LRScheduler {
    pub let T_max: Int;
    pub let eta_min: Float;

    pub fn new(optimizer: Optimizer, T_max: Int, eta_min: Float) -> Self {
        return Self {
            optimizer: optimizer, base_lr: optimizer.lr, _epoch: 0,
            T_max: T_max, eta_min: eta_min
        };
    }

    pub fn step(self) {
        self._epoch = self._epoch + 1;
        let cos_val = _cos(3.14159265 * self._epoch / self.T_max);
        self.optimizer.lr = self.eta_min + (self.base_lr - self.eta_min) * (1.0 + cos_val) / 2.0;
    }
}

pub class WarmupLR : LRScheduler {
    pub let warmup_steps: Int;
    pub let target_lr: Float;

    pub fn new(optimizer: Optimizer, warmup_steps: Int) -> Self {
        return Self {
            optimizer: optimizer, base_lr: 0.0, _epoch: 0,
            warmup_steps: warmup_steps, target_lr: optimizer.lr
        };
    }

    pub fn step(self) {
        self._epoch = self._epoch + 1;
        if (self._epoch <= self.warmup_steps) {
            self.optimizer.lr = self.target_lr * (self._epoch * 1.0 / self.warmup_steps);
        }
    }
}

pub class ReduceLROnPlateau : LRScheduler {
    pub let factor: Float;
    pub let patience: Int;
    pub let min_lr: Float;
    pub let _best: Float;
    pub let _wait: Int;
    pub let mode: String;

    pub fn new(optimizer: Optimizer, factor: Float, patience: Int,
               min_lr: Float, mode: String) -> Self {
        let init_best = mode == "min" ? 1e18 : -1e18;
        return Self {
            optimizer: optimizer, base_lr: optimizer.lr, _epoch: 0,
            factor: factor, patience: patience, min_lr: min_lr,
            _best: init_best, _wait: 0, mode: mode
        };
    }

    pub fn step_with_metric(self, metric: Float) {
        self._epoch = self._epoch + 1;
        let improved = false;
        if (self.mode == "min") {
            improved = metric < self._best;
        } else {
            improved = metric > self._best;
        }
        if (improved) {
            self._best = metric;
            self._wait = 0;
        } else {
            self._wait = self._wait + 1;
            if (self._wait >= self.patience) {
                let new_lr = self.optimizer.lr * self.factor;
                if (new_lr >= self.min_lr) {
                    self.optimizer.lr = new_lr;
                }
                self._wait = 0;
            }
        }
    }
}

pub class OneCycleLR : LRScheduler {
    pub let max_lr: Float;
    pub let total_steps: Int;
    pub let pct_start: Float;
    pub let div_factor: Float;
    pub let final_div_factor: Float;

    pub fn new(optimizer: Optimizer, max_lr: Float, total_steps: Int,
               pct_start: Float, div_factor: Float, final_div_factor: Float) -> Self {
        return Self {
            optimizer: optimizer, base_lr: max_lr / div_factor, _epoch: 0,
            max_lr: max_lr, total_steps: total_steps,
            pct_start: pct_start, div_factor: div_factor,
            final_div_factor: final_div_factor
        };
    }

    pub fn step(self) {
        self._epoch = self._epoch + 1;
        let pct = self._epoch * 1.0 / self.total_steps;
        if (pct <= self.pct_start) {
            let phase_pct = pct / self.pct_start;
            self.optimizer.lr = self.base_lr + (self.max_lr - self.base_lr) * phase_pct;
        } else {
            let phase_pct = (pct - self.pct_start) / (1.0 - self.pct_start);
            let min_lr = self.max_lr / self.final_div_factor;
            let cos_val = _cos(3.14159265 * phase_pct);
            self.optimizer.lr = min_lr + (self.max_lr - min_lr) * (1.0 + cos_val) / 2.0;
        }
    }
}

# ============================================================
# SECTION 8: GRADIENT CLIPPING
# ============================================================

pub fn clip_grad_norm(params: [Parameter], max_norm: Float) -> Float {
    let total_norm_sq = 0.0;
    for (p in params) {
        let g = p.data.grad();
        if (g != null) {
            for (v in g.data) {
                total_norm_sq = total_norm_sq + v * v;
            }
        }
    }
    let total_norm = total_norm_sq.sqrt();
    if (total_norm > max_norm) {
        let scale = max_norm / (total_norm + 1e-6);
        for (p in params) {
            let g = p.data.grad();
            if (g != null) {
                p.data.node.grad = g.scale(scale);
            }
        }
    }
    return total_norm;
}

pub fn clip_grad_value(params: [Parameter], clip_value: Float) -> Void {
    for (p in params) {
        let g = p.data.grad();
        if (g != null) {
            let clipped = [];
            for (v in g.data) {
                let cv = v;
                if (cv > clip_value) { cv = clip_value; }
                if (cv < -clip_value) { cv = -clip_value; }
                clipped = clipped + [cv];
            }
            p.data.node.grad = Tensor::new(clipped, g.shape.dims, g.dtype, g.device);
        }
    }
}

# ============================================================
# SECTION 9: MIXED PRECISION OPTIMIZER WRAPPER
# ============================================================

pub class MixedPrecisionOptimizer {
    pub let inner: Optimizer;
    pub let loss_scale: Float;
    pub let _growth_factor: Float;
    pub let _backoff_factor: Float;
    pub let _growth_interval: Int;
    pub let _growth_tracker: Int;

    pub fn new(optimizer: Optimizer, init_scale: Float) -> Self {
        return Self {
            inner: optimizer, loss_scale: init_scale,
            _growth_factor: 2.0, _backoff_factor: 0.5,
            _growth_interval: 2000, _growth_tracker: 0
        };
    }

    pub fn step(self) -> Bool {
        # Check for inf/nan in gradients
        let has_inf = false;
        for (p in self.inner.params) {
            let g = p.data.grad();
            if (g != null) {
                for (v in g.data) {
                    if (_is_inf(v) || _is_nan(v)) {
                        has_inf = true;
                    }
                }
            }
        }

        if (has_inf) {
            self.loss_scale = self.loss_scale * self._backoff_factor;
            self._growth_tracker = 0;
            return false;
        }

        # Unscale gradients
        let inv_scale = 1.0 / self.loss_scale;
        for (p in self.inner.params) {
            let g = p.data.grad();
            if (g != null) {
                p.data.node.grad = g.scale(inv_scale);
            }
        }

        self.inner.step();
        self._growth_tracker = self._growth_tracker + 1;
        if (self._growth_tracker >= self._growth_interval) {
            self.loss_scale = self.loss_scale * self._growth_factor;
            self._growth_tracker = 0;
        }
        return true;
    }

    pub fn scale_loss(self, loss: Variable) -> Variable {
        let s = Variable::new(
            Tensor::full([1], self.loss_scale, DType::Float32, Device::CPU), "loss_scale");
        return loss.mul(s);
    }
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

fn _pow(base: Float, exp: Int) -> Float {
    let result = 1.0;
    for (i in range(exp)) { result = result * base; }
    return result;
}

fn _cos(x: Float) -> Float {
    # Taylor series approximation
    let x2 = x * x;
    return 1.0 - x2/2.0 + x2*x2/24.0 - x2*x2*x2/720.0;
}

fn _is_inf(v: Float) -> Bool { return v > 1e38 || v < -1e38; }
fn _is_nan(v: Float) -> Bool { return v != v; }

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    "Optimizer": Optimizer,
    "SGD": SGD,
    "Adam": Adam,
    "AdamW": AdamW,
    "RMSProp": RMSProp,
    "Adagrad": Adagrad,
    "LRScheduler": LRScheduler,
    "StepLR": StepLR,
    "ExponentialLR": ExponentialLR,
    "CosineAnnealingLR": CosineAnnealingLR,
    "WarmupLR": WarmupLR,
    "ReduceLROnPlateau": ReduceLROnPlateau,
    "OneCycleLR": OneCycleLR,
    "MixedPrecisionOptimizer": MixedPrecisionOptimizer,
    "clip_grad_norm": clip_grad_norm,
    "clip_grad_value": clip_grad_value
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
