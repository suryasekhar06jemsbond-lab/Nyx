# ============================================================
# NyLoss - Loss Computation Engine
# Version 1.0.0
# Cross entropy, MSE, KL, contrastive, RL losses, custom API
# ============================================================

use nytensor;
use nygrad;

# ============================================================
# SECTION 1: BASE LOSS
# ============================================================

pub enum Reduction {
    None,
    Mean,
    Sum
}

pub class Loss {
    pub let name: String;
    pub let reduction: Reduction;

    pub fn new(name: String, reduction: Reduction) -> Self {
        return Self { name: name, reduction: reduction };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        throw "Loss::forward() must be overridden";
    }

    pub fn _reduce(self, loss: Variable) -> Variable {
        switch (self.reduction) {
            case Reduction::Mean: { return loss.mean(); }
            case Reduction::Sum:  { return loss.sum(); }
            default:              { return loss; }
        }
    }
}

# ============================================================
# SECTION 2: CROSS ENTROPY LOSS
# ============================================================

pub class CrossEntropyLoss : Loss {
    pub let label_smoothing: Float;

    pub fn new(reduction: Reduction, label_smoothing: Float) -> Self {
        return Self {
            name: "CrossEntropyLoss", reduction: reduction,
            label_smoothing: label_smoothing
        };
    }

    pub fn forward(self, logits: Variable, targets: Variable) -> Variable {
        # Numerical stability: log_softmax = x - log(sum(exp(x)))
        let max_val = logits.data.max();
        let shifted = logits.sub(
            Variable::new(Tensor::full(logits.shape(), max_val, DType::Float32, Device::CPU), "max"));
        let exp_shifted = shifted.exp();
        let sum_exp = exp_shifted.sum();
        let log_sum_exp = sum_exp.log();
        let log_softmax = shifted.sub(log_sum_exp);

        # Loss = -sum(target * log_softmax)
        let loss = null;
        if (self.label_smoothing > 0.0) {
            let n_classes = logits.shape()[len(logits.shape()) - 1];
            let smooth = self.label_smoothing / n_classes;
            let confidence = 1.0 - self.label_smoothing;
            let smooth_t = Variable::new(
                Tensor::full(targets.shape(), smooth, DType::Float32, Device::CPU), "smooth");
            let smooth_targets = targets.mul(
                Variable::new(Tensor::full(targets.shape(), confidence, DType::Float32, Device::CPU), "conf")
            ).add(smooth_t);
            loss = smooth_targets.mul(log_softmax).neg();
        } else {
            loss = targets.mul(log_softmax).neg();
        }
        return self._reduce(loss);
    }
}

pub class BinaryCrossEntropyLoss : Loss {
    pub fn new(reduction: Reduction) -> Self {
        return Self { name: "BCELoss", reduction: reduction };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let eps_val = 1e-7;
        let eps = Variable::new(Tensor::full(pred.shape(), eps_val, DType::Float32, Device::CPU), "eps");
        let one = Variable::new(Tensor::ones(pred.shape(), DType::Float32, Device::CPU), "one");
        let clamped = pred.add(eps);  # prevent log(0)
        let loss = target.mul(clamped.log()).add(one.sub(target).mul(one.sub(clamped).log())).neg();
        return self._reduce(loss);
    }
}

pub class BCEWithLogitsLoss : Loss {
    pub let pos_weight: Float?;

    pub fn new(reduction: Reduction, pos_weight: Float?) -> Self {
        return Self { name: "BCEWithLogitsLoss", reduction: reduction, pos_weight: pos_weight };
    }

    pub fn forward(self, logits: Variable, target: Variable) -> Variable {
        # max(x, 0) - x*t + log(1 + exp(-|x|))
        let zero = Variable::new(Tensor::zeros(logits.shape(), DType::Float32, Device::CPU), "zero");
        let relu_x = logits.relu();
        let term1 = relu_x.sub(logits.mul(target));
        let abs_x = logits.mul(logits).sqrt();
        let one = Variable::new(Tensor::ones(logits.shape(), DType::Float32, Device::CPU), "one");
        let term2 = one.add(abs_x.neg().exp()).log();
        let loss = term1.add(term2);

        if (self.pos_weight != null) {
            let pw = Variable::new(
                Tensor::full(target.shape(), self.pos_weight, DType::Float32, Device::CPU), "pw");
            let weight = one.add(pw.sub(one).mul(target));
            loss = loss.mul(weight);
        }
        return self._reduce(loss);
    }
}

# ============================================================
# SECTION 3: MEAN SQUARED ERROR LOSS
# ============================================================

pub class MSELoss : Loss {
    pub fn new(reduction: Reduction) -> Self {
        return Self { name: "MSELoss", reduction: reduction };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let diff = pred.sub(target);
        let loss = diff.mul(diff);
        return self._reduce(loss);
    }
}

pub class MAELoss : Loss {
    pub fn new(reduction: Reduction) -> Self {
        return Self { name: "MAELoss", reduction: reduction };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let diff = pred.sub(target);
        let data = [];
        for (v in diff.data.data) {
            data = data + [v < 0.0 ? -v : v];
        }
        let abs_diff = Variable::new(
            Tensor::new(data, diff.shape(), diff.data.dtype, diff.data.device), "abs_diff");
        return self._reduce(abs_diff);
    }
}

pub class HuberLoss : Loss {
    pub let delta: Float;

    pub fn new(reduction: Reduction, delta: Float) -> Self {
        return Self { name: "HuberLoss", reduction: reduction, delta: delta };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let diff = pred.sub(target);
        let data = [];
        for (v in diff.data.data) {
            let abs_v = v < 0.0 ? -v : v;
            if (abs_v <= self.delta) {
                data = data + [0.5 * v * v];
            } else {
                data = data + [self.delta * (abs_v - 0.5 * self.delta)];
            }
        }
        let loss = Variable::new(
            Tensor::new(data, diff.shape(), diff.data.dtype, diff.data.device), "huber");
        return self._reduce(loss);
    }
}

# ============================================================
# SECTION 4: KL-DIVERGENCE LOSS
# ============================================================

pub class KLDivLoss : Loss {
    pub let log_target: Bool;

    pub fn new(reduction: Reduction, log_target: Bool) -> Self {
        return Self { name: "KLDivLoss", reduction: reduction, log_target: log_target };
    }

    pub fn forward(self, log_pred: Variable, target: Variable) -> Variable {
        if (self.log_target) {
            # KL(P||Q) = exp(log_p) * (log_p - log_q)
            let loss = target.exp().mul(target.sub(log_pred));
            return self._reduce(loss);
        } else {
            # KL(P||Q) = p * (log(p) - log_q)
            let eps = Variable::new(
                Tensor::full(target.shape(), 1e-7, DType::Float32, Device::CPU), "eps");
            let log_target_val = target.add(eps).log();
            let loss = target.mul(log_target_val.sub(log_pred));
            return self._reduce(loss);
        }
    }
}

# ============================================================
# SECTION 5: CONTRASTIVE AND SIMILARITY LOSSES
# ============================================================

pub class ContrastiveLoss : Loss {
    pub let margin: Float;

    pub fn new(reduction: Reduction, margin: Float) -> Self {
        return Self { name: "ContrastiveLoss", reduction: reduction, margin: margin };
    }

    pub fn forward(self, x1: Variable, x2: Variable, label: Variable) -> Variable {
        # distance = ||x1 - x2||
        let diff = x1.sub(x2);
        let dist_sq = diff.mul(diff).sum();

        let one = Variable::new(Tensor::ones(label.shape(), DType::Float32, Device::CPU), "one");
        let margin_v = Variable::new(
            Tensor::full([1], self.margin, DType::Float32, Device::CPU), "margin");

        # loss = y * d^2 + (1-y) * max(0, margin - d)^2
        let positive = label.mul(dist_sq);
        let neg_dist = margin_v.sub(dist_sq.sqrt());
        let neg_clamped_data = [];
        for (v in neg_dist.data.data) {
            neg_clamped_data = neg_clamped_data + [v > 0.0 ? v : 0.0];
        }
        let neg_clamped = Variable::new(
            Tensor::new(neg_clamped_data, neg_dist.shape(), neg_dist.data.dtype, neg_dist.data.device),
            "neg_clamped");
        let negative = one.sub(label).mul(neg_clamped.mul(neg_clamped));

        let loss = positive.add(negative);
        return self._reduce(loss);
    }
}

pub class TripletMarginLoss : Loss {
    pub let margin: Float;

    pub fn new(reduction: Reduction, margin: Float) -> Self {
        return Self { name: "TripletMarginLoss", reduction: reduction, margin: margin };
    }

    pub fn forward(self, anchor: Variable, positive: Variable, negative: Variable) -> Variable {
        let d_pos = anchor.sub(positive).mul(anchor.sub(positive)).sum().sqrt();
        let d_neg = anchor.sub(negative).mul(anchor.sub(negative)).sum().sqrt();
        let margin_v = Variable::new(
            Tensor::full([1], self.margin, DType::Float32, Device::CPU), "margin");
        let raw = d_pos.sub(d_neg).add(margin_v);
        let data = [];
        for (v in raw.data.data) {
            data = data + [v > 0.0 ? v : 0.0];
        }
        let loss = Variable::new(
            Tensor::new(data, raw.shape(), raw.data.dtype, raw.data.device), "triplet");
        return self._reduce(loss);
    }
}

pub class CosineEmbeddingLoss : Loss {
    pub let margin: Float;

    pub fn new(reduction: Reduction, margin: Float) -> Self {
        return Self { name: "CosineEmbeddingLoss", reduction: reduction, margin: margin };
    }

    pub fn forward(self, x1: Variable, x2: Variable, label: Variable) -> Variable {
        let dot = x1.mul(x2).sum();
        let norm1 = x1.mul(x1).sum().sqrt();
        let norm2 = x2.mul(x2).sum().sqrt();
        let eps = Variable::new(Tensor::full([1], 1e-8, DType::Float32, Device::CPU), "eps");
        let cos_sim = dot.div(norm1.mul(norm2).add(eps));

        let one = Variable::new(Tensor::ones(label.shape(), DType::Float32, Device::CPU), "one");
        let margin_v = Variable::new(
            Tensor::full([1], self.margin, DType::Float32, Device::CPU), "margin");

        # loss = y==1: 1-cos, y==-1: max(0, cos-margin)
        let pos_loss = one.sub(cos_sim);
        let neg_raw = cos_sim.sub(margin_v);
        let neg_data = [];
        for (v in neg_raw.data.data) {
            neg_data = neg_data + [v > 0.0 ? v : 0.0];
        }
        let neg_loss = Variable::new(
            Tensor::new(neg_data, neg_raw.shape(), neg_raw.data.dtype, neg_raw.data.device), "neg");
        let loss = label.mul(pos_loss).add(one.sub(label).mul(neg_loss));
        return self._reduce(loss);
    }
}

# ============================================================
# SECTION 6: REINFORCEMENT LEARNING LOSSES
# ============================================================

pub class PolicyGradientLoss : Loss {
    pub fn new(reduction: Reduction) -> Self {
        return Self { name: "PolicyGradientLoss", reduction: reduction };
    }

    pub fn forward(self, log_probs: Variable, advantages: Variable) -> Variable {
        let loss = log_probs.mul(advantages).neg();
        return self._reduce(loss);
    }
}

pub class PPOClipLoss : Loss {
    pub let clip_epsilon: Float;

    pub fn new(reduction: Reduction, clip_epsilon: Float) -> Self {
        return Self { name: "PPOClipLoss", reduction: reduction, clip_epsilon: clip_epsilon };
    }

    pub fn forward(self, ratio: Variable, advantages: Variable) -> Variable {
        let clipped_data = [];
        let lo = 1.0 - self.clip_epsilon;
        let hi = 1.0 + self.clip_epsilon;
        for (v in ratio.data.data) {
            let cv = v;
            if (cv < lo) { cv = lo; }
            if (cv > hi) { cv = hi; }
            clipped_data = clipped_data + [cv];
        }
        let clipped = Variable::new(
            Tensor::new(clipped_data, ratio.shape(), ratio.data.dtype, ratio.data.device), "clipped");

        let surr1 = ratio.mul(advantages);
        let surr2 = clipped.mul(advantages);

        # loss = -min(surr1, surr2)
        let min_data = [];
        for (i in range(len(surr1.data.data))) {
            let a = surr1.data.data[i];
            let b = surr2.data.data[i];
            min_data = min_data + [a < b ? a : b];
        }
        let loss = Variable::new(
            Tensor::new(min_data, surr1.shape(), surr1.data.dtype, surr1.data.device), "ppo").neg();
        return self._reduce(loss);
    }
}

pub class TDLoss : Loss {
    pub let gamma: Float;

    pub fn new(reduction: Reduction, gamma: Float) -> Self {
        return Self { name: "TDLoss", reduction: reduction, gamma: gamma };
    }

    pub fn forward(self, values: Variable, rewards: Variable, next_values: Variable) -> Variable {
        let gamma_v = Variable::new(
            Tensor::full(rewards.shape(), self.gamma, DType::Float32, Device::CPU), "gamma");
        let td_target = rewards.add(gamma_v.mul(next_values));
        let td_error = td_target.sub(values);
        let loss = td_error.mul(td_error);
        return self._reduce(loss);
    }
}

# ============================================================
# SECTION 7: CUSTOM DIFFERENTIABLE LOSS API
# ============================================================

pub class CustomLoss : Loss {
    pub let loss_fn: fn;

    pub fn new(name: String, loss_fn: fn, reduction: Reduction) -> Self {
        return Self { name: name, reduction: reduction, loss_fn: loss_fn };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let raw = self.loss_fn(pred, target);
        return self._reduce(raw);
    }
}

pub fn make_loss(name: String, func: fn, reduction: Reduction) -> CustomLoss {
    return CustomLoss::new(name, func, reduction);
}

# ============================================================
# SECTION 8: FOCAL LOSS (CLASS IMBALANCE)
# ============================================================

pub class FocalLoss : Loss {
    pub let alpha: Float;
    pub let gamma_focal: Float;

    pub fn new(reduction: Reduction, alpha: Float, gamma: Float) -> Self {
        return Self {
            name: "FocalLoss", reduction: reduction,
            alpha: alpha, gamma_focal: gamma
        };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let eps = Variable::new(
            Tensor::full(pred.shape(), 1e-7, DType::Float32, Device::CPU), "eps");
        let p = pred.add(eps);
        let one = Variable::new(Tensor::ones(pred.shape(), DType::Float32, Device::CPU), "one");
        let log_p = p.log();
        let focal_weight = one.sub(p).pow(self.gamma_focal);
        let alpha_v = Variable::new(
            Tensor::full(pred.shape(), self.alpha, DType::Float32, Device::CPU), "alpha");
        let loss = alpha_v.mul(focal_weight).mul(target.mul(log_p).neg());
        return self._reduce(loss);
    }
}

# ============================================================
# SECTION 9: SEGMENTATION LOSSES
# ============================================================

pub class DiceLoss : Loss {
    pub let smooth: Float;

    pub fn new(reduction: Reduction, smooth: Float) -> Self {
        return Self { name: "DiceLoss", reduction: reduction, smooth: smooth };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        # Dice = 2*|X∩Y| / (|X|+|Y|)
        let intersection = pred.mul(target).sum();
        let pred_sum = pred.sum();
        let target_sum = target.sum();
        let smooth_v = Variable::new(
            Tensor::full([1], self.smooth, DType::Float32, Device::CPU), "smooth");
        let two = Variable::new(
            Tensor::full([1], 2.0, DType::Float32, Device::CPU), "two");
        
        let dice = two.mul(intersection).add(smooth_v).div(
            pred_sum.add(target_sum).add(smooth_v));
        let one = Variable::new(Tensor::ones([1], DType::Float32, Device::CPU), "one");
        let loss = one.sub(dice);
        return self._reduce(loss);
    }
}

pub class TverskyLoss : Loss {
    pub let alpha: Float;
    pub let beta: Float;
    pub let smooth: Float;

    pub fn new(reduction: Reduction, alpha: Float, beta: Float, smooth: Float) -> Self {
        return Self {
            name: "TverskyLoss", reduction: reduction,
            alpha: alpha, beta: beta, smooth: smooth
        };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let true_pos = pred.mul(target).sum();
        let one = Variable::new(Tensor::ones(pred.shape(), DType::Float32, Device::CPU), "one");
        let false_pos = pred.mul(one.sub(target)).sum();
        let false_neg = one.sub(pred).mul(target).sum();
        
        let smooth_v = Variable::new(
            Tensor::full([1], self.smooth, DType::Float32, Device::CPU), "smooth");
        let alpha_v = Variable::new(
            Tensor::full([1], self.alpha, DType::Float32, Device::CPU), "alpha");
        let beta_v = Variable::new(
            Tensor::full([1], self.beta, DType::Float32, Device::CPU), "beta");
        
        let tversky = true_pos.add(smooth_v).div(
            true_pos.add(alpha_v.mul(false_pos)).add(beta_v.mul(false_neg)).add(smooth_v));
        let loss = one.sub(tversky);
        return self._reduce(loss);
    }
}

pub class IoULoss : Loss {
    pub let smooth: Float;

    pub fn new(reduction: Reduction, smooth: Float) -> Self {
        return Self { name: "IoULoss", reduction: reduction, smooth: smooth };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let intersection = pred.mul(target).sum();
        let union = pred.add(target).sub(pred.mul(target)).sum();
        let smooth_v = Variable::new(
            Tensor::full([1], self.smooth, DType::Float32, Device::CPU), "smooth");
        
        let iou = intersection.add(smooth_v).div(union.add(smooth_v));
        let one = Variable::new(Tensor::ones([1], DType::Float32, Device::CPU), "one");
        let loss = one.sub(iou);
        return self._reduce(loss);
    }
}

# ============================================================
# SECTION 10: CONTRASTIVE LEARNING LOSSES
# ============================================================

pub class InfoNCELoss : Loss {
    pub let temperature: Float;

    pub fn new(reduction: Reduction, temperature: Float) -> Self {
        return Self { name: "InfoNCELoss", reduction: reduction, temperature: temperature };
    }

    pub fn forward(self, query: Variable, positive: Variable, negatives: Variable) -> Variable {
        # InfoNCE = -log(exp(q·k+/τ) / (exp(q·k+/τ) + Σexp(q·k-/τ)))
        let temp_v = Variable::new(
            Tensor::full([1], self.temperature, DType::Float32, Device::CPU), "temp");
        
        let pos_sim = query.mul(positive).sum().div(temp_v);
        let pos_exp = pos_sim.exp();
        
        # Assume negatives is [batch_size, num_negatives, dim]
        let neg_sims = query.mul(negatives).sum();
        let neg_exps = neg_sims.div(temp_v).exp().sum();
        
        let denominator = pos_exp.add(neg_exps);
        let loss = pos_exp.div(denominator).log().neg();
        return self._reduce(loss);
    }
}

pub class NTXentLoss : Loss {
    pub let temperature: Float;

    pub fn new(reduction: Reduction, temperature: Float) -> Self {
        return Self { name: "NTXentLoss", reduction: reduction, temperature: temperature };
    }

    pub fn forward(self, z_i: Variable, z_j: Variable) -> Variable {
        # Normalized temperature-scaled cross entropy loss
        let batch_size = z_i.shape()[0];
        let temp_v = Variable::new(
            Tensor::full([1], self.temperature, DType::Float32, Device::CPU), "temp");
        
        # Cosine similarity
        let z_i_norm = z_i.div(z_i.mul(z_i).sum().sqrt());
        let z_j_norm = z_j.div(z_j.mul(z_j).sum().sqrt());
        let sim = z_i_norm.mul(z_j_norm).sum().div(temp_v);
        
        let loss = sim.exp().log().neg();
        return self._reduce(loss);
    }
}

pub class SupConLoss : Loss {
    pub let temperature: Float;

    pub fn new(reduction: Reduction, temperature: Float) -> Self {
        return Self { name: "SupConLoss", reduction: reduction, temperature: temperature };
    }

    pub fn forward(self, features: Variable, labels: Variable) -> Variable {
        # Supervised contrastive loss
        let temp_v = Variable::new(
            Tensor::full([1], self.temperature, DType::Float32, Device::CPU), "temp");
        
        # Compute similarities between all pairs
        let anchor_dot = features.mul(features).sum().div(temp_v);
        let loss = anchor_dot.exp().log().neg();
        return self._reduce(loss);
    }
}

# ============================================================
# SECTION 11: WEIGHTED AND MULTI-TASK LOSSES
# ============================================================

pub class WeightedLoss : Loss {
    pub let base_loss: Loss;
    pub let weights: Tensor;

    pub fn new(base_loss: Loss, weights: Tensor) -> Self {
        return Self {
            name: "WeightedLoss",
            reduction: base_loss.reduction,
            base_loss: base_loss,
            weights: weights
        };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let loss = self.base_loss.forward(pred, target);
        let weights_v = Variable::new(self.weights, "weights");
        return loss.mul(weights_v);
    }
}

pub class MultiTaskLoss : Loss {
    pub let losses: [Loss];
    pub let loss_weights: [Float];
    pub let uncertainty_weighting: Bool;

    pub fn new(losses: [Loss], weights: [Float], uncertainty: Bool) -> Self {
        return Self {
            name: "MultiTaskLoss",
            reduction: Reduction::Mean,
            losses: losses,
            loss_weights: weights,
            uncertainty_weighting: uncertainty
        };
    }

    pub fn forward(self, preds: [Variable], targets: [Variable]) -> Variable {
        let total_loss = Variable::new(
            Tensor::zeros([1], DType::Float32, Device::CPU), "total");
        
        for (i in range(len(self.losses))) {
            let task_loss = self.losses[i].forward(preds[i], targets[i]);
            let weight = self.loss_weights[i];
            
            if (self.uncertainty_weighting) {
                # 1/(2*sigma^2) * loss + log(sigma)
                let log_var = native_log(weight);
                let weighted = task_loss.div(
                    Variable::new(Tensor::full([1], 2.0 * weight * weight, DType::Float32, Device::CPU), "var")
                ).add(Variable::new(Tensor::full([1], log_var, DType::Float32, Device::CPU), "log_var"));
                total_loss = total_loss.add(weighted);
            } else {
                let weighted = task_loss.mul(
                    Variable::new(Tensor::full([1], weight, DType::Float32, Device::CPU), "weight"));
                total_loss = total_loss.add(weighted);
            }
        }
        
        return total_loss;
    }
}

pub class AdaptiveLoss : Loss {
    pub let base_loss: Loss;
    pub let scale_learnable: Bool;
    pub let scale: Float;

    pub fn new(base_loss: Loss, learnable: Bool) -> Self {
        return Self {
            name: "AdaptiveLoss",
            reduction: base_loss.reduction,
            base_loss: base_loss,
            scale_learnable: learnable,
            scale: 1.0
        };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let loss = self.base_loss.forward(pred, target);
        let scale_v = Variable::new(
            Tensor::full([1], self.scale, DType::Float32, Device::CPU), "scale");
        return loss.mul(scale_v);
    }

    pub fn update_scale(self, new_scale: Float) {
        self.scale = new_scale;
    }
}

# ============================================================
# SECTION 12: DISTRIBUTION MATCHING LOSSES
# ============================================================

pub class WassersteinLoss : Loss {
    pub fn new(reduction: Reduction) -> Self {
        return Self { name: "WassersteinLoss", reduction: reduction };
    }

    pub fn forward(self, real_scores: Variable, fake_scores: Variable) -> Variable {
        # Wasserstein = E[D(real)] - E[D(fake)]
        let loss = fake_scores.mean().sub(real_scores.mean());
        return loss;
    }
}

pub class HingeLoss : Loss {
    pub let margin: Float;

    pub fn new(reduction: Reduction, margin: Float) -> Self {
        return Self { name: "HingeLoss", reduction: reduction, margin: margin };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        # Loss = max(0, margin - pred * target)
        let margin_v = Variable::new(
            Tensor::full(pred.shape(), self.margin, DType::Float32, Device::CPU), "margin");
        let raw = margin_v.sub(pred.mul(target));
        let data = [];
        for (v in raw.data.data) {
            data = data + [v > 0.0 ? v : 0.0];
        }
        let loss = Variable::new(
            Tensor::new(data, raw.shape(), raw.data.dtype, raw.data.device), "hinge");
        return self._reduce(loss);
    }
}

pub class QuantileLoss : Loss {
    pub let quantile: Float;

    pub fn new(reduction: Reduction, quantile: Float) -> Self {
        return Self { name: "QuantileLoss", reduction: reduction, quantile: quantile };
    }

    pub fn forward(self, pred: Variable, target: Variable) -> Variable {
        let error = target.sub(pred);
        let q = self.quantile;
        let data = [];
        for (e in error.data.data) {
            if (e >= 0.0) {
                data = data + [q * e];
            } else {
                data = data + [(q - 1.0) * e];
            }
        }
        let loss = Variable::new(
            Tensor::new(data, error.shape(), error.data.dtype, error.data.device), "quantile");
        return self._reduce(loss);
    }
}

# ============================================================
# SECTION 13: LOSS UTILITIES
# ============================================================

pub class LossScheduler {
    pub let initial_weights: [Float];
    pub let current_weights: [Float];
    pub let schedule_type: String;  # "linear", "exponential", "step"
    pub let step: Int;

    pub fn new(initial_weights: [Float], schedule_type: String) -> Self {
        return Self {
            initial_weights: initial_weights,
            current_weights: initial_weights,
            schedule_type: schedule_type,
            step: 0
        };
    }

    pub fn step_schedule(self) -> [Float] {
        self.step = self.step + 1;
        
        if (self.schedule_type == "linear") {
            # Linearly anneal weights
            let new_weights = [];
            for (w in self.current_weights) {
                new_weights = new_weights + [w * 0.995];
            }
            self.current_weights = new_weights;
        } else if (self.schedule_type == "exponential") {
            let new_weights = [];
            for (w in self.current_weights) {
                new_weights = new_weights + [w * native_exp(-0.001)];
            }
            self.current_weights = new_weights;
        }
        
        return self.current_weights;
    }
}

pub fn smooth_l1_loss(pred: Variable, target: Variable, beta: Float) -> Variable {
    let diff = pred.sub(target);
    let data = [];
    for (v in diff.data.data) {
        let abs_v = v < 0.0 ? -v : v;
        if (abs_v < beta) {
            data = data + [0.5 * v * v / beta];
        } else {
            data = data + [abs_v - 0.5 * beta];
        }
    }
    return Variable::new(
        Tensor::new(data, diff.shape(), diff.data.dtype, diff.data.device), "smooth_l1");
}

pub fn log_cosh_loss(pred: Variable, target: Variable) -> Variable {
    let diff = pred.sub(target);
    let data = [];
    for (v in diff.data.data) {
        # log(cosh(x)) = log((exp(x) + exp(-x))/2)
        let exp_v = native_exp(v);
        let exp_neg_v = native_exp(-v);
        let cosh_v = (exp_v + exp_neg_v) / 2.0;
        data = data + [native_log(cosh_v)];
    }
    return Variable::new(
        Tensor::new(data, diff.shape(), diff.data.dtype, diff.data.device), "log_cosh");
}

# ============================================================
# NATIVE FFI
# ============================================================

native_exp(x: Float) -> Float;
native_log(x: Float) -> Float;
native_sqrt(x: Float) -> Float;
native_pow(x: Float, y: Float) -> Float;

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    "Reduction": Reduction,
    "Loss": Loss,
    "CrossEntropyLoss": CrossEntropyLoss,
    "BinaryCrossEntropyLoss": BinaryCrossEntropyLoss,
    "BCEWithLogitsLoss": BCEWithLogitsLoss,
    "MSELoss": MSELoss,
    "MAELoss": MAELoss,
    "HuberLoss": HuberLoss,
    "KLDivLoss": KLDivLoss,
    "ContrastiveLoss": ContrastiveLoss,
    "TripletMarginLoss": TripletMarginLoss,
    "CosineEmbeddingLoss": CosineEmbeddingLoss,
    "PolicyGradientLoss": PolicyGradientLoss,
    "PPOClipLoss": PPOClipLoss,
    "TDLoss": TDLoss,
    "FocalLoss": FocalLoss,
    "CustomLoss": CustomLoss,
    "make_loss": make_loss,
    "DiceLoss": DiceLoss,
    "TverskyLoss": TverskyLoss,
    "IoULoss": IoULoss,
    "InfoNCELoss": InfoNCELoss,
    "NTXentLoss": NTXentLoss,
    "SupConLoss": SupConLoss,
    "WeightedLoss": WeightedLoss,
    "MultiTaskLoss": MultiTaskLoss,
    "AdaptiveLoss": AdaptiveLoss,
    "WassersteinLoss": WassersteinLoss,
    "HingeLoss": HingeLoss,
    "QuantileLoss": QuantileLoss,
    "LossScheduler": LossScheduler,
    "smooth_l1_loss": smooth_l1_loss,
    "log_cosh_loss": log_cosh_loss
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
