// NyFeature Engine - Feature Engineering for Nyx ML
// Encoding, normalization, PCA, SVD, feature selection, profiling

import nytensor { Tensor, DType, Device }

// ── Encoding ───────────────────────────────────────────────────────

pub class OneHotEncoder {
    pub num_classes: Int
    _fitted: Bool
    _categories: Map[String, Int]

    pub fn new(num_classes: Int = -1) -> Self {
        return Self { num_classes: num_classes, _fitted: false, _categories: {} }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        let unique = data.unique()
        self.num_classes = unique.len()
        for i in range(self.num_classes) {
            self._categories[unique[i].to_string()] = i
        }
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "OneHotEncoder must be fitted before transform")
        let n = data.shape()[0]
        let result = Tensor.zeros([n, self.num_classes], dtype: DType.Float32)
        for i in range(n) {
            let key = data[i].to_string()
            if self._categories.contains(key) {
                let idx = self._categories[key]
                result[i, idx] = 1.0
            }
        }
        return result
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }

    pub fn inverse_transform(self, encoded: Tensor) -> Tensor {
        let n = encoded.shape()[0]
        let result = Tensor.zeros([n], dtype: DType.Int64)
        let inv_map = {}
        for (key, idx) in self._categories {
            inv_map[idx] = key
        }
        for i in range(n) {
            let idx = encoded[i].argmax().item()
            result[i] = inv_map[idx].to_int()
        }
        return result
    }
}

pub class LabelEncoder {
    _mapping: Map[String, Int]
    _inverse: Map[Int, String]
    _fitted: Bool

    pub fn new() -> Self {
        return Self { _mapping: {}, _inverse: {}, _fitted: false }
    }

    pub fn fit(mut self, data: List[String]) -> Self {
        let unique = data.unique().sort()
        for i in range(unique.len()) {
            self._mapping[unique[i]] = i
            self._inverse[i] = unique[i]
        }
        self._fitted = true
        return self
    }

    pub fn transform(self, data: List[String]) -> Tensor {
        assert(self._fitted, "LabelEncoder must be fitted before transform")
        let result = Tensor.zeros([data.len()], dtype: DType.Int64)
        for i in range(data.len()) {
            result[i] = self._mapping[data[i]]
        }
        return result
    }

    pub fn fit_transform(mut self, data: List[String]) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }

    pub fn inverse_transform(self, encoded: Tensor) -> List[String] {
        let result = []
        for i in range(encoded.shape()[0]) {
            result.append(self._inverse[encoded[i].item()])
        }
        return result
    }
}

pub class OrdinalEncoder {
    _mappings: List[Map[String, Int]]
    _fitted: Bool

    pub fn new() -> Self {
        return Self { _mappings: [], _fitted: false }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        let num_features = data.shape()[1]
        self._mappings = []
        for col in range(num_features) {
            let unique = data[:, col].unique().sort()
            let mapping = {}
            for i in range(unique.len()) {
                mapping[unique[i].to_string()] = i
            }
            self._mappings.append(mapping)
        }
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "OrdinalEncoder must be fitted before transform")
        let n = data.shape()[0]
        let m = data.shape()[1]
        let result = Tensor.zeros([n, m], dtype: DType.Float32)
        for i in range(n) {
            for j in range(m) {
                let key = data[i, j].to_string()
                result[i, j] = self._mappings[j][key].to_float()
            }
        }
        return result
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }
}

pub class TargetEncoder {
    _target_means: Map[String, Map[String, Float]]
    _global_mean: Float
    pub smoothing: Float
    _fitted: Bool

    pub fn new(smoothing: Float = 10.0) -> Self {
        return Self { _target_means: {}, _global_mean: 0.0, smoothing: smoothing, _fitted: false }
    }

    pub fn fit(mut self, features: Tensor, target: Tensor) -> Self {
        self._global_mean = target.mean().item()
        let num_features = features.shape()[1]
        for col in range(num_features) {
            let col_means = {}
            let unique = features[:, col].unique()
            for val in unique {
                let mask = features[:, col] == val
                let group_target = target[mask]
                let group_mean = group_target.mean().item()
                let group_count = group_target.shape()[0].to_float()
                let smoothed = (group_count * group_mean + self.smoothing * self._global_mean) / (group_count + self.smoothing)
                col_means[val.to_string()] = smoothed
            }
            self._target_means[col.to_string()] = col_means
        }
        self._fitted = true
        return self
    }

    pub fn transform(self, features: Tensor) -> Tensor {
        assert(self._fitted, "TargetEncoder must be fitted before transform")
        let n = features.shape()[0]
        let m = features.shape()[1]
        let result = Tensor.zeros([n, m], dtype: DType.Float32)
        for i in range(n) {
            for j in range(m) {
                let key = features[i, j].to_string()
                let col_map = self._target_means[j.to_string()]
                if col_map.contains(key) {
                    result[i, j] = col_map[key]
                } else {
                    result[i, j] = self._global_mean
                }
            }
        }
        return result
    }
}

// ── Scaling & Normalization ────────────────────────────────────────

pub class MinMaxScaler {
    pub feature_range: (Float, Float)
    _min: Tensor?
    _max: Tensor?
    _fitted: Bool

    pub fn new(feature_range: (Float, Float) = (0.0, 1.0)) -> Self {
        return Self { feature_range: feature_range, _min: nil, _max: nil, _fitted: false }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        self._min = data.min(dim: 0)
        self._max = data.max(dim: 0)
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "MinMaxScaler must be fitted before transform")
        let (a, b) = self.feature_range
        let range = self._max - self._min
        let scale = (b - a) / (range + 1e-8)
        return (data - self._min) * scale + a
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }

    pub fn inverse_transform(self, data: Tensor) -> Tensor {
        let (a, b) = self.feature_range
        let range = self._max - self._min
        let scale = (b - a) / (range + 1e-8)
        return (data - a) / scale + self._min
    }
}

pub class StandardScaler {
    _mean: Tensor?
    _std: Tensor?
    _fitted: Bool

    pub fn new() -> Self {
        return Self { _mean: nil, _std: nil, _fitted: false }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        self._mean = data.mean(dim: 0)
        self._std = data.std(dim: 0)
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "StandardScaler must be fitted before transform")
        return (data - self._mean) / (self._std + 1e-8)
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }

    pub fn inverse_transform(self, data: Tensor) -> Tensor {
        return data * self._std + self._mean
    }
}

pub class RobustScaler {
    _median: Tensor?
    _iqr: Tensor?
    _fitted: Bool

    pub fn new() -> Self {
        return Self { _median: nil, _iqr: nil, _fitted: false }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        self._median = data.median(dim: 0)
        let q25 = data.quantile(0.25, dim: 0)
        let q75 = data.quantile(0.75, dim: 0)
        self._iqr = q75 - q25
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "RobustScaler must be fitted before transform")
        return (data - self._median) / (self._iqr + 1e-8)
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }

    pub fn inverse_transform(self, data: Tensor) -> Tensor {
        return data * self._iqr + self._median
    }
}

pub class MaxAbsScaler {
    _max_abs: Tensor?
    _fitted: Bool

    pub fn new() -> Self {
        return Self { _max_abs: nil, _fitted: false }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        self._max_abs = data.abs().max(dim: 0)
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "MaxAbsScaler must be fitted")
        return data / (self._max_abs + 1e-8)
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }
}

// ── Dimensionality Reduction ───────────────────────────────────────

pub class PCA {
    pub n_components: Int
    _components: Tensor?
    _mean: Tensor?
    _explained_variance: Tensor?
    _explained_variance_ratio: Tensor?
    _fitted: Bool

    pub fn new(n_components: Int) -> Self {
        return Self {
            n_components: n_components,
            _components: nil,
            _mean: nil,
            _explained_variance: nil,
            _explained_variance_ratio: nil,
            _fitted: false
        }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        let n = data.shape()[0]
        self._mean = data.mean(dim: 0)
        let centered = data - self._mean

        let cov = centered.t().matmul(centered) / (n - 1).to_float()
        let (eigenvalues, eigenvectors) = cov.eigh()

        let sorted_idx = eigenvalues.argsort(descending: true)
        eigenvalues = eigenvalues[sorted_idx]
        eigenvectors = eigenvectors[:, sorted_idx]

        self._components = eigenvectors[:, :self.n_components].t()
        self._explained_variance = eigenvalues[:self.n_components]
        self._explained_variance_ratio = self._explained_variance / eigenvalues.sum()
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "PCA must be fitted before transform")
        let centered = data - self._mean
        return centered.matmul(self._components.t())
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }

    pub fn inverse_transform(self, data: Tensor) -> Tensor {
        return data.matmul(self._components) + self._mean
    }

    pub fn explained_variance_ratio(self) -> Tensor {
        return self._explained_variance_ratio
    }
}

pub class SVD {
    pub n_components: Int
    _U: Tensor?
    _S: Tensor?
    _Vt: Tensor?
    _fitted: Bool

    pub fn new(n_components: Int) -> Self {
        return Self { n_components: n_components, _U: nil, _S: nil, _Vt: nil, _fitted: false }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        let (U, S, Vt) = data.svd()
        self._U = U[:, :self.n_components]
        self._S = S[:self.n_components]
        self._Vt = Vt[:self.n_components, :]
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "SVD must be fitted before transform")
        return data.matmul(self._Vt.t())
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }

    pub fn reconstruct(self) -> Tensor {
        return self._U.matmul(Tensor.diag(self._S)).matmul(self._Vt)
    }
}

pub class TSNE {
    pub n_components: Int
    pub perplexity: Float
    pub learning_rate: Float
    pub n_iter: Int
    pub seed: Int

    pub fn new(n_components: Int = 2, perplexity: Float = 30.0, learning_rate: Float = 200.0, n_iter: Int = 1000, seed: Int = 42) -> Self {
        return Self {
            n_components: n_components,
            perplexity: perplexity,
            learning_rate: learning_rate,
            n_iter: n_iter,
            seed: seed
        }
    }

    pub fn fit_transform(self, data: Tensor) -> Tensor {
        let n = data.shape()[0]
        let rng = RandomState.new(self.seed)
        let Y = rng.randn([n, self.n_components]) * 0.01

        let distances = _pairwise_distances(data)
        let P = _compute_joint_probabilities(distances, self.perplexity)

        let momentum = 0.5
        let gains = Tensor.ones([n, self.n_components])
        let update = Tensor.zeros([n, self.n_components])

        for iter in range(self.n_iter) {
            let Q = _compute_q_distribution(Y)
            let gradient = _compute_gradient(P, Q, Y)

            if iter > 250 { momentum = 0.8 }
            update = momentum * update - self.learning_rate * gradient
            Y = Y + update
            Y = Y - Y.mean(dim: 0)
        }
        return Y
    }

    fn _pairwise_distances(data: Tensor) -> Tensor {
        let n = data.shape()[0]
        let sq = (data * data).sum(dim: 1)
        return sq.unsqueeze(1) + sq.unsqueeze(0) - 2.0 * data.matmul(data.t())
    }

    fn _compute_joint_probabilities(distances: Tensor, perplexity: Float) -> Tensor {
        let n = distances.shape()[0]
        let P = Tensor.zeros([n, n])
        let target_entropy = perplexity.log()

        for i in range(n) {
            let beta = 1.0
            let lo = 0.0
            let hi = 1e10
            for _ in range(50) {
                let exp_d = (-distances[i] * beta).exp()
                exp_d[i] = 0.0
                let sum_exp = exp_d.sum() + 1e-8
                let Pi = exp_d / sum_exp
                let entropy = -(Pi * (Pi + 1e-8).log()).sum()
                if (entropy - target_entropy).abs() < 1e-5 { break }
                if entropy > target_entropy { lo = beta; beta = if hi == 1e10 { beta * 2.0 } else { (beta + hi) / 2.0 } }
                else { hi = beta; beta = (beta + lo) / 2.0 }
            }
            let exp_d = (-distances[i] * beta).exp()
            exp_d[i] = 0.0
            P[i] = exp_d / (exp_d.sum() + 1e-8)
        }
        P = (P + P.t()) / (2.0 * n.to_float())
        return P.clamp(min: 1e-12)
    }

    fn _compute_q_distribution(Y: Tensor) -> Tensor {
        let dists = _pairwise_distances(Y)
        let num = 1.0 / (1.0 + dists)
        let n = Y.shape()[0]
        for i in range(n) { num[i, i] = 0.0 }
        return num / (num.sum() + 1e-8)
    }

    fn _compute_gradient(P: Tensor, Q: Tensor, Y: Tensor) -> Tensor {
        let n = Y.shape()[0]
        let PQ_diff = P - Q
        let dists = _pairwise_distances(Y)
        let inv = 1.0 / (1.0 + dists)
        let grad = Tensor.zeros(Y.shape())
        for i in range(n) {
            let diff = Y[i].unsqueeze(0) - Y
            grad[i] = (4.0 * (PQ_diff[i] * inv[i]).unsqueeze(1) * diff).sum(dim: 0)
        }
        return grad
    }
}

// ── Feature Selection ──────────────────────────────────────────────

pub class VarianceThreshold {
    pub threshold: Float
    _mask: Tensor?
    _variances: Tensor?
    _fitted: Bool

    pub fn new(threshold: Float = 0.0) -> Self {
        return Self { threshold: threshold, _mask: nil, _variances: nil, _fitted: false }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        self._variances = data.var(dim: 0)
        self._mask = self._variances > self.threshold
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "VarianceThreshold must be fitted")
        return data[:, self._mask]
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }

    pub fn get_support(self) -> Tensor {
        return self._mask
    }
}

pub class SelectKBest {
    pub k: Int
    pub score_func: String
    _scores: Tensor?
    _selected: Tensor?
    _fitted: Bool

    pub fn new(k: Int = 10, score_func: String = "f_classif") -> Self {
        return Self { k: k, score_func: score_func, _scores: nil, _selected: nil, _fitted: false }
    }

    pub fn fit(mut self, X: Tensor, y: Tensor) -> Self {
        match self.score_func {
            "f_classif" => self._scores = _f_classif(X, y),
            "mutual_info" => self._scores = _mutual_info(X, y),
            "chi2" => self._scores = _chi2(X, y),
            _ => self._scores = _f_classif(X, y)
        }
        self._selected = self._scores.argsort(descending: true)[:self.k]
        self._fitted = true
        return self
    }

    pub fn transform(self, X: Tensor) -> Tensor {
        assert(self._fitted, "SelectKBest must be fitted")
        return X[:, self._selected]
    }

    pub fn fit_transform(mut self, X: Tensor, y: Tensor) -> Tensor {
        self.fit(X, y)
        return self.transform(X)
    }

    pub fn scores(self) -> Tensor {
        return self._scores
    }
}

pub class MutualInfoSelector {
    pub k: Int
    _scores: Tensor?
    _selected: Tensor?
    _fitted: Bool

    pub fn new(k: Int = 10) -> Self {
        return Self { k: k, _scores: nil, _selected: nil, _fitted: false }
    }

    pub fn fit(mut self, X: Tensor, y: Tensor) -> Self {
        self._scores = _mutual_info(X, y)
        self._selected = self._scores.argsort(descending: true)[:self.k]
        self._fitted = true
        return self
    }

    pub fn transform(self, X: Tensor) -> Tensor {
        assert(self._fitted, "MutualInfoSelector must be fitted")
        return X[:, self._selected]
    }

    pub fn fit_transform(mut self, X: Tensor, y: Tensor) -> Tensor {
        self.fit(X, y)
        return self.transform(X)
    }
}

pub class CorrelationFilter {
    pub threshold: Float
    _keep_mask: Tensor?
    _fitted: Bool

    pub fn new(threshold: Float = 0.95) -> Self {
        return Self { threshold: threshold, _keep_mask: nil, _fitted: false }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        let corr = _correlation_matrix(data)
        let n = corr.shape()[1]
        let to_drop = []
        for i in range(n) {
            for j in range(i + 1, n) {
                if corr[i, j].abs().item() > self.threshold {
                    if !to_drop.contains(j) {
                        to_drop.append(j)
                    }
                }
            }
        }
        self._keep_mask = Tensor.ones([n], dtype: DType.Bool)
        for idx in to_drop {
            self._keep_mask[idx] = false
        }
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "CorrelationFilter must be fitted")
        return data[:, self._keep_mask]
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }
}

// ── Imputation ─────────────────────────────────────────────────────

pub class SimpleImputer {
    pub strategy: String
    _fill_values: Tensor?
    _fitted: Bool

    pub fn new(strategy: String = "mean") -> Self {
        return Self { strategy: strategy, _fill_values: nil, _fitted: false }
    }

    pub fn fit(mut self, data: Tensor) -> Self {
        match self.strategy {
            "mean" => self._fill_values = data.nanmean(dim: 0),
            "median" => self._fill_values = data.nanmedian(dim: 0),
            "most_frequent" => self._fill_values = data.mode(dim: 0),
            "zero" => self._fill_values = Tensor.zeros([data.shape()[1]]),
            _ => self._fill_values = data.nanmean(dim: 0)
        }
        self._fitted = true
        return self
    }

    pub fn transform(self, data: Tensor) -> Tensor {
        assert(self._fitted, "SimpleImputer must be fitted")
        let result = data.clone()
        let n_cols = data.shape()[1]
        for j in range(n_cols) {
            let mask = result[:, j].isnan()
            result[:, j][mask] = self._fill_values[j]
        }
        return result
    }

    pub fn fit_transform(mut self, data: Tensor) -> Tensor {
        self.fit(data)
        return self.transform(data)
    }
}

// ── Feature Profiling ──────────────────────────────────────────────

pub class FeatureProfile {
    pub name: String
    pub dtype: String
    pub count: Int
    pub missing: Int
    pub missing_pct: Float
    pub mean: Float
    pub std: Float
    pub min: Float
    pub max: Float
    pub q25: Float
    pub q50: Float
    pub q75: Float
    pub unique_count: Int
    pub skewness: Float
    pub kurtosis: Float
}

pub class DataProfiler {
    pub fn new() -> Self {
        return Self {}
    }

    pub fn profile(self, data: Tensor, column_names: List[String] = []) -> List[FeatureProfile] {
        let n_cols = data.shape()[1]
        let profiles = []
        for j in range(n_cols) {
            let col = data[:, j]
            let name = if j < column_names.len() { column_names[j] } else { "feature_" + j.to_string() }
            let missing = col.isnan().sum().item()
            let valid = col[!col.isnan()]

            let profile = FeatureProfile {
                name: name,
                dtype: col.dtype.to_string(),
                count: col.shape()[0],
                missing: missing,
                missing_pct: missing.to_float() / col.shape()[0].to_float() * 100.0,
                mean: valid.mean().item(),
                std: valid.std().item(),
                min: valid.min().item(),
                max: valid.max().item(),
                q25: valid.quantile(0.25).item(),
                q50: valid.quantile(0.50).item(),
                q75: valid.quantile(0.75).item(),
                unique_count: valid.unique().len(),
                skewness: _skewness(valid),
                kurtosis: _kurtosis(valid)
            }
            profiles.append(profile)
        }
        return profiles
    }

    pub fn report(self, profiles: List[FeatureProfile]) -> String {
        let lines = ["Feature Profiling Report", "=" * 60]
        for p in profiles {
            lines.append("Feature: " + p.name)
            lines.append("  Type: " + p.dtype + "  Count: " + p.count.to_string())
            lines.append("  Missing: " + p.missing.to_string() + " (" + p.missing_pct.to_string() + "%)")
            lines.append("  Mean: " + p.mean.to_string() + "  Std: " + p.std.to_string())
            lines.append("  Min: " + p.min.to_string() + "  Max: " + p.max.to_string())
            lines.append("  Q25: " + p.q25.to_string() + "  Q50: " + p.q50.to_string() + "  Q75: " + p.q75.to_string())
            lines.append("  Unique: " + p.unique_count.to_string())
            lines.append("  Skew: " + p.skewness.to_string() + "  Kurtosis: " + p.kurtosis.to_string())
            lines.append("-" * 60)
        }
        return lines.join("\n")
    }
}

// ── Feature Pipeline ───────────────────────────────────────────────

pub class FeaturePipeline {
    pub steps: List[(String, Any)]

    pub fn new() -> Self {
        return Self { steps: [] }
    }

    pub fn add(mut self, name: String, transformer: Any) -> Self {
        self.steps.append((name, transformer))
        return self
    }

    pub fn fit(mut self, X: Tensor, y: Tensor? = nil) -> Self {
        let current = X
        for (name, step) in self.steps {
            if y != nil {
                step.fit(current, y)
            } else {
                step.fit(current)
            }
            current = step.transform(current)
        }
        return self
    }

    pub fn transform(self, X: Tensor) -> Tensor {
        let current = X
        for (name, step) in self.steps {
            current = step.transform(current)
        }
        return current
    }

    pub fn fit_transform(mut self, X: Tensor, y: Tensor? = nil) -> Tensor {
        self.fit(X, y)
        return self.transform(X)
    }
}

// ── Polynomial Features ────────────────────────────────────────────

pub class PolynomialFeatures {
    pub degree: Int
    pub include_bias: Bool
    pub interaction_only: Bool
    _n_input_features: Int
    _fitted: Bool

    pub fn new(degree: Int = 2, include_bias: Bool = true, interaction_only: Bool = false) -> Self {
        return Self {
            degree: degree,
            include_bias: include_bias,
            interaction_only: interaction_only,
            _n_input_features: 0,
            _fitted: false
        }
    }

    pub fn fit(mut self, X: Tensor) -> Self {
        self._n_input_features = X.shape()[1]
        self._fitted = true
        return self
    }

    pub fn transform(self, X: Tensor) -> Tensor {
        assert(self._fitted, "PolynomialFeatures must be fitted")
        let n = X.shape()[0]
        let m = self._n_input_features
        let features = []
        if self.include_bias {
            features.append(Tensor.ones([n, 1]))
        }
        features.append(X)
        if self.degree >= 2 {
            for i in range(m) {
                let start = if self.interaction_only { i + 1 } else { i }
                for j in range(start, m) {
                    features.append((X[:, i] * X[:, j]).unsqueeze(1))
                }
            }
        }
        if self.degree >= 3 && !self.interaction_only {
            for i in range(m) {
                features.append((X[:, i].pow(3)).unsqueeze(1))
            }
        }
        return Tensor.cat(features, dim: 1)
    }

    pub fn fit_transform(mut self, X: Tensor) -> Tensor {
        self.fit(X)
        return self.transform(X)
    }
}

// ── Helper Functions ───────────────────────────────────────────────

fn _f_classif(X: Tensor, y: Tensor) -> Tensor {
    let classes = y.unique()
    let n_features = X.shape()[1]
    let scores = Tensor.zeros([n_features])
    let grand_mean = X.mean(dim: 0)

    for j in range(n_features) {
        let ss_between = 0.0
        let ss_within = 0.0
        for c in classes {
            let mask = y == c
            let group = X[:, j][mask]
            let group_mean = group.mean().item()
            let n_g = group.shape()[0].to_float()
            ss_between = ss_between + n_g * (group_mean - grand_mean[j].item()).pow(2)
            ss_within = ss_within + ((group - group_mean).pow(2)).sum().item()
        }
        let df_between = (classes.len() - 1).to_float()
        let df_within = (X.shape()[0] - classes.len()).to_float()
        scores[j] = (ss_between / df_between) / (ss_within / df_within + 1e-8)
    }
    return scores
}

fn _mutual_info(X: Tensor, y: Tensor) -> Tensor {
    let n = X.shape()[0].to_float()
    let n_features = X.shape()[1]
    let scores = Tensor.zeros([n_features])
    let classes = y.unique()

    for j in range(n_features) {
        let mi = 0.0
        let bins = 20
        let col = X[:, j]
        let col_min = col.min().item()
        let col_max = col.max().item()
        let bin_width = (col_max - col_min + 1e-8) / bins.to_float()

        for c in classes {
            let mask_c = y == c
            let p_c = mask_c.sum().item().to_float() / n
            for b in range(bins) {
                let lo = col_min + b.to_float() * bin_width
                let hi = lo + bin_width
                let mask_b = (col >= lo) & (col < hi)
                let p_b = mask_b.sum().item().to_float() / n
                let p_cb = (mask_c & mask_b).sum().item().to_float() / n
                if p_cb > 0.0 && p_c > 0.0 && p_b > 0.0 {
                    mi = mi + p_cb * (p_cb / (p_c * p_b)).log()
                }
            }
        }
        scores[j] = mi
    }
    return scores
}

fn _chi2(X: Tensor, y: Tensor) -> Tensor {
    let n_features = X.shape()[1]
    let scores = Tensor.zeros([n_features])
    let classes = y.unique()
    let n = X.shape()[0].to_float()

    for j in range(n_features) {
        let chi2_val = 0.0
        let col_sum = X[:, j].sum().item()
        for c in classes {
            let mask = y == c
            let observed = X[:, j][mask].sum().item()
            let n_c = mask.sum().item().to_float()
            let expected = col_sum * n_c / n
            chi2_val = chi2_val + (observed - expected).pow(2) / (expected + 1e-8)
        }
        scores[j] = chi2_val
    }
    return scores
}

fn _correlation_matrix(data: Tensor) -> Tensor {
    let n = data.shape()[0].to_float()
    let mean = data.mean(dim: 0)
    let centered = data - mean
    let std = data.std(dim: 0)
    let standardized = centered / (std + 1e-8)
    return standardized.t().matmul(standardized) / (n - 1.0)
}

fn _skewness(data: Tensor) -> Float {
    let mean = data.mean().item()
    let std = data.std().item()
    let n = data.shape()[0].to_float()
    let centered = data - mean
    return (centered.pow(3).sum().item() / n) / (std.pow(3) + 1e-8)
}

fn _kurtosis(data: Tensor) -> Float {
    let mean = data.mean().item()
    let std = data.std().item()
    let n = data.shape()[0].to_float()
    let centered = data - mean
    return (centered.pow(4).sum().item() / n) / (std.pow(4) + 1e-8) - 3.0
}

export {
    OneHotEncoder, LabelEncoder, OrdinalEncoder, TargetEncoder,
    MinMaxScaler, StandardScaler, RobustScaler, MaxAbsScaler,
    PCA, SVD, TSNE,
    VarianceThreshold, SelectKBest, MutualInfoSelector, CorrelationFilter,
    SimpleImputer,
    FeatureProfile, DataProfiler, FeaturePipeline,
    PolynomialFeatures
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
