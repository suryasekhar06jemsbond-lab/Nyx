# ============================================================
# NySecure - Security & Trust Engine
# Version 1.0.0
# Adversarial defense, privacy, bias detection, explainability
# ============================================================

use nytensor;
use nygrad;
use nynet_ml;
use nyopt;
use nyloss;

# ============================================================
# SECTION 1: ADVERSARIAL ATTACKS
# ============================================================

pub enum AttackType {
    FGSM,      # Fast Gradient Sign Method
    PGD,       # Projected Gradient Descent
    CW,        # Carlini-Wagner
    DeepFool,
    JSMA       # Jacobian-based Saliency Map Attack
}

pub class FGSMAttack {
    pub let epsilon: Float;
    pub let clip_min: Float;
    pub let clip_max: Float;

    pub fn new(epsilon: Float, clip_min: Float, clip_max: Float) -> Self {
        return Self {
            epsilon: epsilon,
            clip_min: clip_min,
            clip_max: clip_max
        };
    }

    pub fn generate(self, model: Module, x: Tensor, y_true: Tensor, loss_fn: Object) -> Tensor {
        let x_var = Variable::new(x, "x");
        x_var.requires_grad = true;
        
        let y_var = Variable::new(y_true, "y");
        let output = model.forward(x_var);
        let loss = loss_fn.forward(output, y_var);
        
        backward(loss, false);
        
        # Get gradient sign
        let grad_sign = _sign_tensor(x_var.grad);
        
        # Perturb: x_adv = x + epsilon * sign(grad)
        let perturbation = grad_sign.scale(self.epsilon);
        let x_adv = x.add(perturbation);
        
        # Clip to valid range
        return x_adv.clamp(self.clip_min, self.clip_max);
    }
}

pub class PGDAttack {
    pub let epsilon: Float;
    pub let alpha: Float;
    pub let num_steps: Int;
    pub let clip_min: Float;
    pub let clip_max: Float;

    pub fn new(epsilon: Float, alpha: Float, num_steps: Int, clip_min: Float, clip_max: Float) -> Self {
        return Self {
            epsilon: epsilon,
            alpha: alpha,
            num_steps: num_steps,
            clip_min: clip_min,
            clip_max: clip_max
        };
    }

    pub fn generate(self, model: Module, x: Tensor, y_true: Tensor, loss_fn: Object) -> Tensor {
        # Start with random perturbation
        let delta = Tensor::uniform(x.shape.dims, -self.epsilon, self.epsilon, x.dtype, x.device);
        let x_adv = x.add(delta).clamp(self.clip_min, self.clip_max);
        
        for (step in range(self.num_steps)) {
            let x_var = Variable::new(x_adv, "x_adv");
            x_var.requires_grad = true;
            
            let y_var = Variable::new(y_true, "y");
            let output = model.forward(x_var);
            let loss = loss_fn.forward(output, y_var);
            
            backward(loss, false);
            
            # Update adversarial example
            let grad_sign = _sign_tensor(x_var.grad);
            let perturbation = grad_sign.scale(self.alpha);
            x_adv = x_adv.add(perturbation);
            
            # Project back to epsilon ball
            let delta_new = x_adv.sub(x).clamp(-self.epsilon, self.epsilon);
            x_adv = x.add(delta_new).clamp(self.clip_min, self.clip_max);
        }
        
        return x_adv;
    }
}

pub class CWAttack {
    pub let c: Float;
    pub let kappa: Float;
    pub let learning_rate: Float;
    pub let max_iterations: Int;

    pub fn new(c: Float, kappa: Float, lr: Float, max_iter: Int) -> Self {
        return Self {
            c: c,
            kappa: kappa,
            learning_rate: lr,
            max_iterations: max_iter
        };
    }

    pub fn generate(self, model: Module, x: Tensor, y_target: Int) -> Tensor {
        # Carlini-Wagner L2 attack (targeted)
        # Minimize: ||delta||_2^2 + c * f(x + delta)
        # Where f(x) = max(Z(x)_i - Z(x)_t, -kappa) for i != t
        
        let w = Tensor::atanh(x.scale(2.0).sub(Tensor::ones(x.shape.dims, x.dtype, x.device)));
        let w_var = Variable::new(w, "w");
        w_var.requires_grad = true;
        
        let opt = Adam::new([w_var], self.learning_rate, 0.9, 0.999, 1e-8, 0.0, false);
        
        for (iter in range(self.max_iterations)) {
            opt.zero_grad();
            
            # Transform w to x_adv via tanh
            let x_adv = w_var.tanh().add(
                Variable::new(Tensor::ones(x.shape.dims, x.dtype, x.device), "one")
            ).scale(0.5);
            
            let logits = model.forward(x_adv);
            
            # CW loss
            let l2_loss = w_var.sub(Variable::new(w, "w_original")).pow(
                Variable::new(Tensor::full([1], 2.0, DType::Float32, Device::CPU), "two")
            ).sum();
            
            # f(x) term (simplified)
            let f_loss = logits.sum();  # Placeholder for full CW objective
            
            let loss = l2_loss.add(f_loss.scale(self.c));
            backward(loss, false);
            opt.step();
        }
        
        let x_adv_final = w_var.tanh().add(
            Variable::new(Tensor::ones(x.shape.dims, x.dtype, x.device), "one")
        ).scale(0.5);
        return x_adv_final.detach();
    }
}

# ============================================================
# SECTION 2: ADVERSARIAL TRAINING
# ============================================================

pub class AdversarialTrainer {
    pub let model: Module;
    pub let optimizer: Optimizer;
    pub let loss_fn: Object;
    pub let attack: Object;
    pub let adv_ratio: Float;

    pub fn new(model: Module, optimizer: Optimizer, loss_fn: Object, attack: Object, adv_ratio: Float) -> Self {
        return Self {
            model: model,
            optimizer: optimizer,
            loss_fn: loss_fn,
            attack: attack,
            adv_ratio: adv_ratio
        };
    }

    pub fn train_step(self, x_clean: Tensor, y: Tensor) -> Object {
        self.optimizer.zero_grad();
        
        # Generate adversarial examples
        let x_adv = self.attack.generate(self.model, x_clean, y, self.loss_fn);
        
        # Forward pass on clean examples
        let x_clean_var = Variable::new(x_clean, "x_clean");
        let y_var = Variable::new(y, "y");
        let pred_clean = self.model.forward(x_clean_var);
        let loss_clean = self.loss_fn.forward(pred_clean, y_var);
        
        # Forward pass on adversarial examples
        let x_adv_var = Variable::new(x_adv, "x_adv");
        let pred_adv = self.model.forward(x_adv_var);
        let loss_adv = self.loss_fn.forward(pred_adv, y_var);
        
        # Combined loss
        let total_loss = loss_clean.scale(1.0 - self.adv_ratio).add(loss_adv.scale(self.adv_ratio));
        
        backward(total_loss, false);
        self.optimizer.step();
        
        return {
            "total_loss": total_loss.data.data[0],
            "clean_loss": loss_clean.data.data[0],
            "adv_loss": loss_adv.data.data[0]
        };
    }
}

# ============================================================
# SECTION 3: DIFFERENTIAL PRIVACY
# ============================================================

pub class DifferentialPrivacy {
    pub let epsilon: Float;
    pub let delta: Float;
    pub let noise_multiplier: Float;
    pub let max_grad_norm: Float;

    pub fn new(epsilon: Float, delta: Float, noise_multiplier: Float, max_grad_norm: Float) -> Self {
        return Self {
            epsilon: epsilon,
            delta: delta,
            noise_multiplier: noise_multiplier,
            max_grad_norm: max_grad_norm
        };
    }

    pub fn clip_gradients(self, parameters: [Parameter]) -> Float {
        # Clip gradients to bound sensitivity
        let total_norm = 0.0;
        for (p in parameters) {
            if (p.grad != null) {
                let param_norm = p.grad.norm();
                total_norm = total_norm + param_norm * param_norm;
            }
        }
        total_norm = native_sqrt(total_norm);
        
        let clip_coef = self.max_grad_norm / (total_norm + 1e-6);
        if (clip_coef < 1.0) {
            for (p in parameters) {
                if (p.grad != null) {
                    p.grad.data = p.grad.data.scale(clip_coef);
                }
            }
        }
        
        return total_norm;
    }

    pub fn add_noise(self, parameters: [Parameter], batch_size: Int) {
        # Add Gaussian noise for DP-SGD
        let noise_scale = self.noise_multiplier * self.max_grad_norm / batch_size;
        for (p in parameters) {
            if (p.grad != null) {
                let noise = Tensor::randn(p.data.shape.dims, p.data.dtype, p.data.device).scale(noise_scale);
                p.grad.data = p.grad.data.add(noise);
            }
        }
    }

    pub fn get_privacy_spent(self, steps: Int, batch_size: Int, dataset_size: Int) -> Object {
        # Compute privacy budget spent (simplified)
        let sampling_prob = batch_size * 1.0 / dataset_size;
        let epsilon_spent = self.epsilon * steps * sampling_prob;
        return {"epsilon": epsilon_spent, "delta": self.delta};
    }
}

pub class DPOptimizer {
    pub let base_optimizer: Optimizer;
    pub let dp_mechanism: DifferentialPrivacy;
    pub let batch_size: Int;

    pub fn new(base_optimizer: Optimizer, dp: DifferentialPrivacy, batch_size: Int) -> Self {
        return Self {
            base_optimizer: base_optimizer,
            dp_mechanism: dp,
            batch_size: batch_size
        };
    }

    pub fn zero_grad(self) {
        self.base_optimizer.zero_grad();
    }

    pub fn step(self) {
        # Clip gradients
        let params = self.base_optimizer.param_groups[0].params;
        self.dp_mechanism.clip_gradients(params);
        
        # Add noise
        self.dp_mechanism.add_noise(params, self.batch_size);
        
        # Update parameters
        self.base_optimizer.step();
    }
}

# ============================================================
# SECTION 4: FAIRNESS & BIAS DETECTION
# ============================================================

pub class FairnessMetrics {
    pub fn new() -> Self {
        return Self {};
    }

    pub fn demographic_parity(self, y_pred: Tensor, sensitive_attr: Tensor) -> Float {
        # P(Y_hat = 1 | S = 0) - P(Y_hat = 1 | S = 1)
        let prob_0 = 0.0;
        let count_0 = 0;
        let prob_1 = 0.0;
        let count_1 = 0;
        
        for (i in range(y_pred.numel())) {
            if (sensitive_attr.data[i] < 0.5) {
                if (y_pred.data[i] > 0.5) { prob_0 = prob_0 + 1.0; }
                count_0 = count_0 + 1;
            } else {
                if (y_pred.data[i] > 0.5) { prob_1 = prob_1 + 1.0; }
                count_1 = count_1 + 1;
            }
        }
        
        prob_0 = prob_0 / count_0;
        prob_1 = prob_1 / count_1;
        
        return native_abs(prob_0 - prob_1);
    }

    pub fn equalized_odds(self, y_true: Tensor, y_pred: Tensor, sensitive_attr: Tensor) -> Object {
        # TPR and FPR should be equal across groups
        let tpr_0 = 0.0; let tpr_1 = 0.0;
        let fpr_0 = 0.0; let fpr_1 = 0.0;
        let tp_0 = 0; let fn_0 = 0; let fp_0 = 0; let tn_0 = 0;
        let tp_1 = 0; let fn_1 = 0; let fp_1 = 0; let tn_1 = 0;
        
        for (i in range(y_pred.numel())) {
            let pred = y_pred.data[i] > 0.5 ? 1 : 0;
            let truth = y_true.data[i] > 0.5 ? 1 : 0;
            let sens = sensitive_attr.data[i] < 0.5 ? 0 : 1;
            
            if (sens == 0) {
                if (truth == 1 && pred == 1) { tp_0 = tp_0 + 1; }
                else if (truth == 1 && pred == 0) { fn_0 = fn_0 + 1; }
                else if (truth == 0 && pred == 1) { fp_0 = fp_0 + 1; }
                else { tn_0 = tn_0 + 1; }
            } else {
                if (truth == 1 && pred == 1) { tp_1 = tp_1 + 1; }
                else if (truth == 1 && pred == 0) { fn_1 = fn_1 + 1; }
                else if (truth == 0 && pred == 1) { fp_1 = fp_1 + 1; }
                else { tn_1 = tn_1 + 1; }
            }
        }
        
        tpr_0 = tp_0 * 1.0 / (tp_0 + fn_0 + 1e-6);
        tpr_1 = tp_1 * 1.0 / (tp_1 + fn_1 + 1e-6);
        fpr_0 = fp_0 * 1.0 / (fp_0 + tn_0 + 1e-6);
        fpr_1 = fp_1 * 1.0 / (fp_1 + tn_1 + 1e-6);
        
        return {
            "tpr_diff": native_abs(tpr_0 - tpr_1),
            "fpr_diff": native_abs(fpr_0 - fpr_1)
        };
    }

    pub fn disparate_impact(self, y_pred: Tensor, sensitive_attr: Tensor) -> Float {
        # Ratio: P(Y_hat = 1 | S = 0) / P(Y_hat = 1 | S = 1)
        let prob_0 = 0.0;
        let count_0 = 0;
        let prob_1 = 0.0;
        let count_1 = 0;
        
        for (i in range(y_pred.numel())) {
            if (sensitive_attr.data[i] < 0.5) {
                if (y_pred.data[i] > 0.5) { prob_0 = prob_0 + 1.0; }
                count_0 = count_0 + 1;
            } else {
                if (y_pred.data[i] > 0.5) { prob_1 = prob_1 + 1.0; }
                count_1 = count_1 + 1;
            }
        }
        
        prob_0 = prob_0 / count_0;
        prob_1 = prob_1 / count_1;
        
        return prob_0 / (prob_1 + 1e-6);
    }
}

pub class BiasDetector {
    pub let fairness_metrics: FairnessMetrics;
    pub let threshold: Float;

    pub fn new(threshold: Float) -> Self {
        return Self {
            fairness_metrics: FairnessMetrics::new(),
            threshold: threshold
        };
    }

    pub fn detect(self, model: Module, x: Tensor, y_true: Tensor, sensitive_attrs: Tensor) -> Object {
        let x_var = Variable::new(x, "x");
        let y_pred = model.forward(x_var).detach();
        
        let dp = self.fairness_metrics.demographic_parity(y_pred, sensitive_attrs);
        let eo = self.fairness_metrics.equalized_odds(y_true, y_pred, sensitive_attrs);
        let di = self.fairness_metrics.disparate_impact(y_pred, sensitive_attrs);
        
        let is_biased = dp > self.threshold || eo["tpr_diff"] > self.threshold;
        
        return {
            "is_biased": is_biased,
            "demographic_parity": dp,
            "eq_odds_tpr_diff": eo["tpr_diff"],
            "eq_odds_fpr_diff": eo["fpr_diff"],
            "disparate_impact": di
        };
    }
}

# ============================================================
# SECTION 5: EXPLAINABILITY
# ============================================================

pub class GradCAM {
    pub let model: Module;
    pub let target_layer: String;

    pub fn new(model: Module, target_layer: String) -> Self {
        return Self {
            model: model,
            target_layer: target_layer
        };
    }

    pub fn generate(self, x: Tensor, class_idx: Int) -> Tensor {
        # Gradient-weighted Class Activation Mapping
        let x_var = Variable::new(x, "x");
        let output = self.model.forward(x_var);
        
        # Get gradient of class score w.r.t. feature maps
        let class_score = _get_class_score(output, class_idx);
        backward(class_score, false);
        
        # Get gradients and activations from target layer
        # Placeholder: full GradCAM computation
        let cam = Tensor::ones([7, 7], DType::Float32, Device::CPU);
        return cam;
    }
}

pub class LIME {
    pub let model: Module;
    pub let num_samples: Int;
    pub let kernel_width: Float;

    pub fn new(model: Module, num_samples: Int, kernel_width: Float) -> Self {
        return Self {
            model: model,
            num_samples: num_samples,
            kernel_width: kernel_width
        };
    }

    pub fn explain(self, x: Tensor) -> Object {
        # Local Interpretable Model-agnostic Explanations
        let x_var = Variable::new(x, "x");
        let original_pred = self.model.forward(x_var).detach();
        
        # Generate perturbed samples
        let perturbations = [];
        let predictions = [];
        let weights = [];
        
        for (i in range(self.num_samples)) {
            let noise = Tensor::randn(x.shape.dims, x.dtype, x.device).scale(0.1);
            let x_perturbed = x.add(noise);
            let x_p_var = Variable::new(x_perturbed, "x_perturbed");
            let pred = self.model.forward(x_p_var).detach();
            
            perturbations = perturbations + [x_perturbed];
            predictions = predictions + [pred];
            
            # Compute weight based on distance
            let distance = noise.norm();
            let weight = native_exp(-distance * distance / (2.0 * self.kernel_width * self.kernel_width));
            weights = weights + [weight];
        }
        
        # Fit linear model (placeholder)
        let feature_importance = Tensor::zeros([x.numel()], DType::Float32, Device::CPU);
        
        return {
            "feature_importance": feature_importance,
            "original_prediction": original_pred
        };
    }
}

pub class SHAP {
    pub let model: Module;
    pub let background: Tensor;

    pub fn new(model: Module, background: Tensor) -> Self {
        return Self {
            model: model,
            background: background
        };
    }

    pub fn shapley_values(self, x: Tensor) -> Tensor {
        # SHapley Additive exPlanations
        # Compute Shapley values for each feature
        let num_features = x.numel();
        let shap_values_data = [];
        
        for (i in range(num_features)) {
            # Marginal contribution of feature i
            let contribution = 0.0;
            # Placeholder: full Shapley computation
            shap_values_data = shap_values_data + [contribution];
        }
        
        return Tensor::new(shap_values_data, [num_features], x.dtype, x.device);
    }
}

# ============================================================
# SECTION 6: MODEL POISONING DETECTION
# ============================================================

pub class PoisonDetector {
    pub let defense_type: String;  # "spectral", "activation_clustering"

    pub fn new(defense_type: String) -> Self {
        return Self {
            defense_type: defense_type
        };
    }

    pub fn detect_poisoned_samples(self, model: Module, x_train: Tensor, y_train: Tensor) -> [Int] {
        # Detect poisoned training samples
        let suspicious_indices = [];
        
        if (self.defense_type == "spectral") {
            # Spectral signature analysis
            for (i in range(x_train.shape.dims[0])) {
                let x_i = _get_batch_item(x_train, i);
                let x_var = Variable::new(x_i, "x_i");
                let pred = model.forward(x_var).detach();
                
                # Check if prediction is anomalous
                # Placeholder for spectral analysis
            }
        } else if (self.defense_type == "activation_clustering") {
            # Cluster activations to find outliers
            # Placeholder
        }
        
        return suspicious_indices;
    }

    pub fn certify_robustness(self, model: Module, x: Tensor, radius: Float) -> Bool {
        # Randomized smoothing certification
        let num_samples = 100;
        let votes = {};
        
        for (i in range(num_samples)) {
            let noise = Tensor::randn(x.shape.dims, x.dtype, x.device).scale(radius);
            let x_noisy = x.add(noise);
            let x_var = Variable::new(x_noisy, "x_noisy");
            let pred = model.forward(x_var).detach();
            let pred_class = _argmax(pred);
            
            if (!votes.has_key(str(pred_class))) {
                votes[str(pred_class)] = 0;
            }
            votes[str(pred_class)] = votes[str(pred_class)] + 1;
        }
        
        # Check if majority class is confident
        let max_votes = 0;
        for (key in votes.keys()) {
            if (votes[key] > max_votes) {
                max_votes = votes[key];
            }
        }
        
        return max_votes * 1.0 / num_samples > 0.8;
    }
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

fn _sign_tensor(t: Tensor) -> Tensor {
    let signed_data = [];
    for (v in t.data) {
        if (v > 0.0) { signed_data = signed_data + [1.0]; }
        else if (v < 0.0) { signed_data = signed_data + [-1.0]; }
        else { signed_data = signed_data + [0.0]; }
    }
    return Tensor::new(signed_data, t.shape.dims, t.dtype, t.device);
}

fn _get_class_score(output: Variable, class_idx: Int) -> Variable {
    return Variable::new(
        Tensor::new([output.data.data[class_idx]], [1], output.data.dtype, output.data.device),
        "class_score"
    );
}

fn _get_batch_item(batch: Tensor, idx: Int) -> Tensor {
    # Extract single item from batch
    let item_size = batch.numel() / batch.shape.dims[0];
    let data = [];
    for (i in range(item_size)) {
        data = data + [batch.data[idx * item_size + i]];
    }
    let new_shape = [];
    for (i in range(1, len(batch.shape.dims))) {
        new_shape = new_shape + [batch.shape.dims[i]];
    }
    return Tensor::new(data, new_shape, batch.dtype, batch.device);
}

fn _argmax(t: Tensor) -> Int {
    let max_idx = 0;
    let max_val = t.data[0];
    for (i in range(1, t.numel())) {
        if (t.data[i] > max_val) {
            max_val = t.data[i];
            max_idx = i;
        }
    }
    return max_idx;
}

# ============================================================
# NATIVE FFI
# ============================================================

native_abs(x: Float) -> Float;
native_sqrt(x: Float) -> Float;
native_exp(x: Float) -> Float;

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    "AttackType": AttackType,
    "FGSMAttack": FGSMAttack,
    "PGDAttack": PGDAttack,
    "CWAttack": CWAttack,
    "AdversarialTrainer": AdversarialTrainer,
    "DifferentialPrivacy": DifferentialPrivacy,
    "DPOptimizer": DPOptimizer,
    "FairnessMetrics": FairnessMetrics,
    "BiasDetector": BiasDetector,
    "GradCAM": GradCAM,
    "LIME": LIME,
    "SHAP": SHAP,
    "PoisonDetector": PoisonDetector
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
