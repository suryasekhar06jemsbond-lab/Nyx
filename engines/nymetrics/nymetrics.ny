# ============================================================
# NyMetrics - Evaluation Engine
# Version 1.0.0
# Classification/regression metrics, cross-validation, hyperparameter tuning
# ============================================================

use nytensor;
use nygrad;
use nynet_ml;
use nyopt;

# ============================================================
# SECTION 1: CLASSIFICATION METRICS
# ============================================================

pub class ClassificationMetrics {
    pub fn new() -> Self {
        return Self {};
    }

    pub fn accuracy(self, y_true: Tensor, y_pred: Tensor) -> Float {
        let correct = 0;
        for (i in range(y_true.numel())) {
            if (native_abs(y_true.data[i] - y_pred.data[i]) < 0.5) {
                correct = correct + 1;
            }
        }
        return correct * 1.0 / y_true.numel();
    }

    pub fn precision(self, y_true: Tensor, y_pred: Tensor) -> Float {
        let true_positives = 0.0;
        let false_positives = 0.0;
        for (i in range(y_true.numel())) {
            let pred = y_pred.data[i] > 0.5 ? 1.0 : 0.0;
            let truth = y_true.data[i] > 0.5 ? 1.0 : 0.0;
            if (pred == 1.0 && truth == 1.0) {
                true_positives = true_positives + 1.0;
            } else if (pred == 1.0 && truth == 0.0) {
                false_positives = false_positives + 1.0;
            }
        }
        return true_positives / (true_positives + false_positives + 1e-6);
    }

    pub fn recall(self, y_true: Tensor, y_pred: Tensor) -> Float {
        let true_positives = 0.0;
        let false_negatives = 0.0;
        for (i in range(y_true.numel())) {
            let pred = y_pred.data[i] > 0.5 ? 1.0 : 0.0;
            let truth = y_true.data[i] > 0.5 ? 1.0 : 0.0;
            if (pred == 1.0 && truth == 1.0) {
                true_positives = true_positives + 1.0;
            } else if (pred == 0.0 && truth == 1.0) {
                false_negatives = false_negatives + 1.0;
            }
        }
        return true_positives / (true_positives + false_negatives + 1e-6);
    }

    pub fn f1_score(self, y_true: Tensor, y_pred: Tensor) -> Float {
        let prec = self.precision(y_true, y_pred);
        let rec = self.recall(y_true, y_pred);
        return 2.0 * prec * rec / (prec + rec + 1e-6);
    }

    pub fn confusion_matrix(self, y_true: Tensor, y_pred: Tensor, num_classes: Int) -> Tensor {
        let size = num_classes * num_classes;
        let matrix_data = [];
        for (i in range(size)) {
            matrix_data = matrix_data + [0.0];
        }
        
        for (i in range(y_true.numel())) {
            let true_class = int(y_true.data[i]);
            let pred_class = int(y_pred.data[i]);
            let idx = true_class * num_classes + pred_class;
            matrix_data[idx] = matrix_data[idx] + 1.0;
        }
        
        return Tensor::new(matrix_data, [num_classes, num_classes], DType::Float32, Device::CPU);
    }

    pub fn roc_auc(self, y_true: Tensor, y_scores: Tensor) -> Float {
        # Compute ROC-AUC score
        let n = y_true.numel();
        let sorted_indices = _argsort(y_scores);
        
        let auc = 0.0;
        let tp = 0.0;
        let fp = 0.0;
        let prev_score = -1e9;
        
        # Count positives and negatives
        let num_pos = 0.0;
        let num_neg = 0.0;
        for (i in range(n)) {
            if (y_true.data[i] > 0.5) { num_pos = num_pos + 1.0; }
            else { num_neg = num_neg + 1.0; }
        }
        
        # Trapezoidal rule
        for (i in range(n - 1, -1, -1)) {
            let idx = sorted_indices[i];
            let score = y_scores.data[idx];
            let label = y_true.data[idx];
            
            if (label > 0.5) {
                tp = tp + 1.0;
            } else {
                fp = fp + 1.0;
                auc = auc + tp;
            }
        }
        
        auc = auc / (num_pos * num_neg + 1e-6);
        return auc;
    }

    pub fn classification_report(self, y_true: Tensor, y_pred: Tensor) -> Object {
        return {
            "accuracy": self.accuracy(y_true, y_pred),
            "precision": self.precision(y_true, y_pred),
            "recall": self.recall(y_true, y_pred),
            "f1": self.f1_score(y_true, y_pred)
        };
    }
}

# ============================================================
# SECTION 2: REGRESSION METRICS
# ============================================================

pub class RegressionMetrics {
    pub fn new() -> Self {
        return Self {};
    }

    pub fn mse(self, y_true: Tensor, y_pred: Tensor) -> Float {
        let sum_sq_error = 0.0;
        for (i in range(y_true.numel())) {
            let error = y_true.data[i] - y_pred.data[i];
            sum_sq_error = sum_sq_error + error * error;
        }
        return sum_sq_error / y_true.numel();
    }

    pub fn rmse(self, y_true: Tensor, y_pred: Tensor) -> Float {
        return native_sqrt(self.mse(y_true, y_pred));
    }

    pub fn mae(self, y_true: Tensor, y_pred: Tensor) -> Float {
        let sum_abs_error = 0.0;
        for (i in range(y_true.numel())) {
            let error = native_abs(y_true.data[i] - y_pred.data[i]);
            sum_abs_error = sum_abs_error + error;
        }
        return sum_abs_error / y_true.numel();
    }

    pub fn r2_score(self, y_true: Tensor, y_pred: Tensor) -> Float {
        let mean = y_true.mean();
        let ss_tot = 0.0;
        let ss_res = 0.0;
        
        for (i in range(y_true.numel())) {
            ss_tot = ss_tot + (y_true.data[i] - mean) * (y_true.data[i] - mean);
            ss_res = ss_res + (y_true.data[i] - y_pred.data[i]) * (y_true.data[i] - y_pred.data[i]);
        }
        
        return 1.0 - (ss_res / (ss_tot + 1e-6));
    }

    pub fn median_absolute_error(self, y_true: Tensor, y_pred: Tensor) -> Float {
        let errors = [];
        for (i in range(y_true.numel())) {
            errors = errors + [native_abs(y_true.data[i] - y_pred.data[i])];
        }
        return _median(errors);
    }

    pub fn regression_report(self, y_true: Tensor, y_pred: Tensor) -> Object {
        return {
            "mse": self.mse(y_true, y_pred),
            "rmse": self.rmse(y_true, y_pred),
            "mae": self.mae(y_true, y_pred),
            "r2": self.r2_score(y_true, y_pred)
        };
    }
}

# ============================================================
# SECTION 3: CROSS-VALIDATION
# ============================================================

pub class KFold {
    pub let n_splits: Int;
    pub let shuffle: Bool;

    pub fn new(n_splits: Int, shuffle: Bool) -> Self {
        return Self {
            n_splits: n_splits,
            shuffle: shuffle
        };
    }

    pub fn split(self, n_samples: Int) -> [[Int]] {
        let indices = [];
        for (i in range(n_samples)) {
            indices = indices + [i];
        }
        
        if (self.shuffle) {
            indices = _shuffle_array(indices);
        }
        
        let fold_size = n_samples / self.n_splits;
        let folds = [];
        
        for (k in range(self.n_splits)) {
            let start = k * fold_size;
            let end = k == self.n_splits - 1 ? n_samples : (k + 1) * fold_size;
            
            let train_indices = [];
            let test_indices = [];
            
            for (i in range(n_samples)) {
                if (i >= start && i < end) {
                    test_indices = test_indices + [indices[i]];
                } else {
                    train_indices = train_indices + [indices[i]];
                }
            }
            
            folds = folds + [[train_indices, test_indices]];
        }
        
        return folds;
    }
}

pub class StratifiedKFold {
    pub let n_splits: Int;

    pub fn new(n_splits: Int) -> Self {
        return Self {
            n_splits: n_splits
        };
    }

    pub fn split(self, y: Tensor) -> [[Int]] {
        # Group indices by class
        let class_indices = {};
        for (i in range(y.numel())) {
            let label = str(int(y.data[i]));
            if (!class_indices.has_key(label)) {
                class_indices[label] = [];
            }
            class_indices[label] = class_indices[label] + [i];
        }
        
        # Create stratified folds
        let folds = [];
        for (k in range(self.n_splits)) {
            folds = folds + [[[], []]];
        }
        
        for (label in class_indices.keys()) {
            let indices = class_indices[label];
            let fold_size = len(indices) / self.n_splits;
            
            for (k in range(self.n_splits)) {
                let start = k * fold_size;
                let end = k == self.n_splits - 1 ? len(indices) : (k + 1) * fold_size;
                
                for (i in range(start, end)) {
                    folds[k][1] = folds[k][1] + [indices[i]];
                }
                for (i in range(len(indices))) {
                    if (i < start || i >= end) {
                        folds[k][0] = folds[k][0] + [indices[i]];
                    }
                }
            }
        }
        
        return folds;
    }
}

pub fn cross_validate(model: Module, x: Tensor, y: Tensor, cv: Object, metric_fn: Function) -> Object {
    let n_samples = x.shape.dims[0];
    let folds = cv.split(n_samples);
    let scores = [];
    
    for (fold in folds) {
        let train_idx = fold[0];
        let test_idx = fold[1];
        
        let x_train = _select_indices(x, train_idx);
        let y_train = _select_indices(y, train_idx);
        let x_test = _select_indices(x, test_idx);
        let y_test = _select_indices(y, test_idx);
        
        # Train model (placeholder - actual training loop needed)
        # let trained_model = train(model, x_train, y_train);
        
        # Evaluate
        let x_test_var = Variable::new(x_test, "x_test");
        let y_pred = model.forward(x_test_var).detach();
        let score = metric_fn(y_test, y_pred);
        scores = scores + [score];
    }
    
    let mean_score = _mean(scores);
    let std_score = _std(scores, mean_score);
    
    return {
        "scores": scores,
        "mean": mean_score,
        "std": std_score
    };
}

# ============================================================
# SECTION 4: HYPERPARAMETER TUNING
# ============================================================

pub class GridSearchCV {
    pub let param_grid: Object;
    pub let cv: Object;
    pub let scoring: String;

    pub fn new(param_grid: Object, cv: Object, scoring: String) -> Self {
        return Self {
            param_grid: param_grid,
            cv: cv,
            scoring: scoring
        };
    }

    pub fn fit(self, model: Module, x: Tensor, y: Tensor) -> Object {
        # Generate all param combinations
        let param_combinations = _generate_param_combinations(self.param_grid);
        
        let best_score = -1e9;
        let best_params = null;
        let all_results = [];
        
        for (params in param_combinations) {
            # Update model with params
            # _update_model_params(model, params);
            
            # Cross-validate
            # let cv_result = cross_validate(model, x, y, self.cv, scoring_fn);
            # let mean_score = cv_result["mean"];
            let mean_score = native_random_float();  # Placeholder
            
            all_results = all_results + [{"params": params, "score": mean_score}];
            
            if (mean_score > best_score) {
                best_score = mean_score;
                best_params = params;
            }
        }
        
        return {
            "best_score": best_score,
            "best_params": best_params,
            "all_results": all_results
        };
    }
}

pub class RandomSearchCV {
    pub let param_distributions: Object;
    pub let n_iter: Int;
    pub let cv: Object;
    pub let scoring: String;

    pub fn new(param_distributions: Object, n_iter: Int, cv: Object, scoring: String) -> Self {
        return Self {
            param_distributions: param_distributions,
            n_iter: n_iter,
            cv: cv,
            scoring: scoring
        };
    }

    pub fn fit(self, model: Module, x: Tensor, y: Tensor) -> Object {
        let best_score = -1e9;
        let best_params = null;
        let all_results = [];
        
        for (i in range(self.n_iter)) {
            # Sample random params
            let params = _sample_params(self.param_distributions);
            
            # Update model and evaluate
            # let cv_result = cross_validate(model, x, y, self.cv, scoring_fn);
            # let mean_score = cv_result["mean"];
            let mean_score = native_random_float();  # Placeholder
            
            all_results = all_results + [{"params": params, "score": mean_score}];
            
            if (mean_score > best_score) {
                best_score = mean_score;
                best_params = params;
            }
        }
        
        return {
            "best_score": best_score,
            "best_params": best_params,
            "all_results": all_results
        };
    }
}

pub class BayesianOptimization {
    pub let param_bounds: Object;
    pub let n_iter: Int;
    pub let acquisition: String;  # "ucb", "ei", "poi"

    pub fn new(param_bounds: Object, n_iter: Int, acquisition: String) -> Self {
        return Self {
            param_bounds: param_bounds,
            n_iter: n_iter,
            acquisition: acquisition
        };
    }

    pub fn optimize(self, objective_fn: Function) -> Object {
        let best_score = -1e9;
        let best_params = null;
        let history = [];
        
        # Initialize with random samples
        let init_samples = 5;
        for (i in range(init_samples)) {
            let params = _sample_uniform_params(self.param_bounds);
            let score = objective_fn(params);
            history = history + [{"params": params, "score": score}];
            
            if (score > best_score) {
                best_score = score;
                best_params = params;
            }
        }
        
        # Bayesian optimization loop
        for (iter in range(self.n_iter - init_samples)) {
            # Fit Gaussian Process surrogate
            # Select next point via acquisition function
            let next_params = _select_next_params(history, self.param_bounds, self.acquisition);
            let score = objective_fn(next_params);
            
            history = history + [{"params": next_params, "score": score}];
            
            if (score > best_score) {
                best_score = score;
                best_params = next_params;
            }
        }
        
        return {
            "best_score": best_score,
            "best_params": best_params,
            "history": history
        };
    }
}

# ============================================================
# SECTION 5: DRIFT DETECTION
# ============================================================

pub class DriftDetector {
    pub let method: String;  # "kolmogorov_smirnov", "population_stability_index"
    pub let threshold: Float;

    pub fn new(method: String, threshold: Float) -> Self {
        return Self {
            method: method,
            threshold: threshold
        };
    }

    pub fn detect(self, reference: Tensor, current: Tensor) -> Object {
        if (self.method == "kolmogorov_smirnov") {
            let ks_stat = self.kolmogorov_smirnov_test(reference, current);
            return {
                "drift_detected": ks_stat > self.threshold,
                "ks_statistic": ks_stat
            };
        } else if (self.method == "population_stability_index") {
            let psi = self.population_stability_index(reference, current);
            return {
                "drift_detected": psi > self.threshold,
                "psi": psi
            };
        } else {
            throw "Unknown drift detection method";
        }
    }

    pub fn kolmogorov_smirnov_test(self, reference: Tensor, current: Tensor) -> Float {
        let ref_sorted = _sort(reference.data);
        let cur_sorted = _sort(current.data);
        
        let max_diff = 0.0;
        let n_ref = len(ref_sorted);
        let n_cur = len(cur_sorted);
        
        let i = 0;
        let j = 0;
        while (i < n_ref && j < n_cur) {
            let cdf_ref = i * 1.0 / n_ref;
            let cdf_cur = j * 1.0 / n_cur;
            let diff = native_abs(cdf_ref - cdf_cur);
            if (diff > max_diff) {
                max_diff = diff;
            }
            
            if (ref_sorted[i] < cur_sorted[j]) {
                i = i + 1;
            } else {
                j = j + 1;
            }
        }
        
        return max_diff;
    }

    pub fn population_stability_index(self, reference: Tensor, current: Tensor) -> Float {
        # Bin the data
        let num_bins = 10;
        let bins = _create_bins(reference, num_bins);
        
        let ref_counts = _count_in_bins(reference, bins);
        let cur_counts = _count_in_bins(current, bins);
        
        let psi = 0.0;
        for (i in range(num_bins)) {
            let ref_pct = ref_counts[i] * 1.0 / reference.numel();
            let cur_pct = cur_counts[i] * 1.0 / current.numel();
            
            if (ref_pct > 0.0 && cur_pct > 0.0) {
                psi = psi + (cur_pct - ref_pct) * native_log(cur_pct / ref_pct);
            }
        }
        
        return psi;
    }
}

# ============================================================
# SECTION 6: PERFORMANCE BENCHMARKING
# ============================================================

pub class Benchmark {
    pub let warmup_runs: Int;
    pub let benchmark_runs: Int;

    pub fn new(warmup_runs: Int, benchmark_runs: Int) -> Self {
        return Self {
            warmup_runs: warmup_runs,
            benchmark_runs: benchmark_runs
        };
    }

    pub fn measure_inference(self, model: Module, x: Tensor) -> Object {
        # Warmup
        for (i in range(self.warmup_runs)) {
            let x_var = Variable::new(x, "x");
            let _ = model.forward(x_var);
        }
        
        # Benchmark
        let times = [];
        for (i in range(self.benchmark_runs)) {
            let start_time = native_time_ns();
            let x_var = Variable::new(x, "x");
            let _ = model.forward(x_var);
            let end_time = native_time_ns();
            times = times + [(end_time - start_time) * 1.0 / 1e6];  # Convert to ms
        }
        
        let mean_time = _mean(times);
        let std_time = _std(times, mean_time);
        
        return {
            "mean_ms": mean_time,
            "std_ms": std_time,
            "min_ms": _min(times),
            "max_ms": _max(times),
            "throughput_samples_per_sec": 1000.0 / mean_time
        };
    }

    pub fn measure_training_step(self, model: Module, optimizer: Optimizer, x: Tensor, y: Tensor, loss_fn: Object) -> Object {
        # Warmup
        for (i in range(self.warmup_runs)) {
            optimizer.zero_grad();
            let x_var = Variable::new(x, "x");
            let y_var = Variable::new(y, "y");
            let pred = model.forward(x_var);
            let loss = loss_fn.forward(pred, y_var);
            backward(loss, false);
            optimizer.step();
        }
        
        # Benchmark
        let times = [];
        for (i in range(self.benchmark_runs)) {
            let start_time = native_time_ns();
            optimizer.zero_grad();
            let x_var = Variable::new(x, "x");
            let y_var = Variable::new(y, "y");
            let pred = model.forward(x_var);
            let loss = loss_fn.forward(pred, y_var);
            backward(loss, false);
            optimizer.step();
            let end_time = native_time_ns();
            times = times + [(end_time - start_time) * 1.0 / 1e6];
        }
        
        let mean_time = _mean(times);
        
        return {
            "mean_ms": mean_time,
            "throughput_samples_per_sec": 1000.0 / mean_time
        };
    }
}

# ============================================================
# HELPER FUNCTIONS
# ============================================================

fn _argsort(t: Tensor) -> [Int] {
    let indices = [];
    for (i in range(t.numel())) {
        indices = indices + [i];
    }
    # Insertion sort by tensor values
    for (i in range(1, len(indices))) {
        let key = indices[i];
        let j = i - 1;
        while (j >= 0 && t.data[indices[j]] > t.data[key]) {
            indices[j + 1] = indices[j];
            j = j - 1;
        }
        indices[j + 1] = key;
    }
    return indices;
}

fn _median(arr: [Float]) -> Float {
    let sorted = _sort(arr);
    let n = len(sorted);
    if (n % 2 == 1) {
        return sorted[n / 2];
    } else {
        return (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0;
    }
}

fn _shuffle_array(arr: [Int]) -> [Int] {
    let shuffled = arr;
    for (i in range(len(shuffled) - 1, 0, -1)) {
        let j = native_random_int(0, i + 1);
        let temp = shuffled[i];
        shuffled[i] = shuffled[j];
        shuffled[j] = temp;
    }
    return shuffled;
}

fn _select_indices(t: Tensor, indices: [Int]) -> Tensor {
    let selected_data = [];
    let item_size = t.numel() / t.shape.dims[0];
    for (idx in indices) {
        for (i in range(item_size)) {
            selected_data = selected_data + [t.data[idx * item_size + i]];
        }
    }
    let new_shape = [len(indices)];
    for (i in range(1, len(t.shape.dims))) {
        new_shape = new_shape + [t.shape.dims[i]];
    }
    return Tensor::new(selected_data, new_shape, t.dtype, t.device);
}

fn _mean(arr: [Float]) -> Float {
    let sum = 0.0;
    for (v in arr) {
        sum = sum + v;
    }
    return sum / len(arr);
}

fn _std(arr: [Float], mean: Float) -> Float {
    let sum_sq = 0.0;
    for (v in arr) {
        sum_sq = sum_sq + (v - mean) * (v - mean);
    }
    return native_sqrt(sum_sq / len(arr));
}

fn _min(arr: [Float]) -> Float {
    let min_val = arr[0];
    for (v in arr) {
        if (v < min_val) {
            min_val = v;
        }
    }
    return min_val;
}

fn _max(arr: [Float]) -> Float {
    let max_val = arr[0];
    for (v in arr) {
        if (v > max_val) {
            max_val = v;
        }
    }
    return max_val;
}

fn _sort(arr: [Float]) -> [Float] {
    let sorted = arr;
    for (i in range(1, len(sorted))) {
        let key = sorted[i];
        let j = i - 1;
        while (j >= 0 && sorted[j] > key) {
            sorted[j + 1] = sorted[j];
            j = j - 1;
        }
        sorted[j + 1] = key;
    }
    return sorted;
}

fn _generate_param_combinations(grid: Object) -> [Object] {
    # Generate all combinations from param grid
    return [{}];  # Placeholder
}

fn _sample_params(distributions: Object) -> Object {
    # Sample from distributions
    return {};  # Placeholder
}

fn _sample_uniform_params(bounds: Object) -> Object {
    return {};  # Placeholder
}

fn _select_next_params(history: [Object], bounds: Object, acquisition: String) -> Object {
    return {};  # Placeholder
}

fn _create_bins(t: Tensor, num_bins: Int) -> [Float] {
    let min_val = t.min();
    let max_val = t.max();
    let step = (max_val - min_val) / num_bins;
    let bins = [];
    for (i in range(num_bins + 1)) {
        bins = bins + [min_val + i * step];
    }
    return bins;
}

fn _count_in_bins(t: Tensor, bins: [Float]) -> [Int] {
    let counts = [];
    for (i in range(len(bins) - 1)) {
        counts = counts + [0];
    }
    for (v in t.data) {
        for (i in range(len(bins) - 1)) {
            if (v >= bins[i] && v < bins[i + 1]) {
                counts[i] = counts[i] + 1;
                break;
            }
        }
    }
    return counts;
}

# ============================================================
# NATIVE FFI
# ============================================================

native_abs(x: Float) -> Float;
native_sqrt(x: Float) -> Float;
native_log(x: Float) -> Float;
native_random_float() -> Float;
native_random_int(low: Int, high: Int) -> Int;
native_time_ns() -> Int;

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    "ClassificationMetrics": ClassificationMetrics,
    "RegressionMetrics": RegressionMetrics,
    "KFold": KFold,
    "StratifiedKFold": StratifiedKFold,
    "cross_validate": cross_validate,
    "GridSearchCV": GridSearchCV,
    "RandomSearchCV": RandomSearchCV,
    "BayesianOptimization": BayesianOptimization,
    "DriftDetector": DriftDetector,
    "Benchmark": Benchmark
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
