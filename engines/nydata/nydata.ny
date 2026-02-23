// NyData Engine - Data Pipeline Engine for Nyx ML
// Streaming data loading, parallel preprocessing, batching, augmentation, caching, sharding

import nytensor { Tensor, DType, Device }

// ── Data Source Types ──────────────────────────────────────────────

pub enum DataFormat {
    CSV,
    JSON,
    Parquet,
    Arrow,
    Binary,
    Image,
    Text,
    Custom
}

pub enum SplitType {
    Train,
    Validation,
    Test
}

pub enum ShuffleMode {
    None,
    PerEpoch,
    Full
}

pub enum CachePolicy {
    None,
    Memory,
    Disk,
    Hybrid
}

// ── Schema ─────────────────────────────────────────────────────────

pub class ColumnSchema {
    pub name: String
    pub dtype: DType
    pub nullable: Bool
    pub shape: List[Int]

    pub fn new(name: String, dtype: DType, nullable: Bool = false, shape: List[Int] = []) -> Self {
        return Self { name: name, dtype: dtype, nullable: nullable, shape: shape }
    }
}

pub class DataSchema {
    pub columns: List[ColumnSchema]
    pub label_columns: List[String]
    pub feature_columns: List[String]

    pub fn new() -> Self {
        return Self { columns: [], label_columns: [], feature_columns: [] }
    }

    pub fn add_column(mut self, col: ColumnSchema) -> Self {
        self.columns.append(col)
        return self
    }

    pub fn set_labels(mut self, names: List[String]) -> Self {
        self.label_columns = names
        return self
    }

    pub fn set_features(mut self, names: List[String]) -> Self {
        self.feature_columns = names
        return self
    }

    pub fn column_count(self) -> Int {
        return self.columns.len()
    }

    pub fn get_column(self, name: String) -> ColumnSchema? {
        for col in self.columns {
            if col.name == name {
                return col
            }
        }
        return nil
    }
}

// ── Sample & Batch ─────────────────────────────────────────────────

pub class Sample {
    pub features: Map[String, Tensor]
    pub labels: Map[String, Tensor]
    pub metadata: Map[String, Any]

    pub fn new() -> Self {
        return Self { features: {}, labels: {}, metadata: {} }
    }

    pub fn set_feature(mut self, name: String, tensor: Tensor) -> Self {
        self.features[name] = tensor
        return self
    }

    pub fn set_label(mut self, name: String, tensor: Tensor) -> Self {
        self.labels[name] = tensor
        return self
    }

    pub fn set_meta(mut self, key: String, value: Any) -> Self {
        self.metadata[key] = value
        return self
    }
}

pub class Batch {
    pub features: Map[String, Tensor]
    pub labels: Map[String, Tensor]
    pub size: Int
    pub indices: List[Int]

    pub fn new(size: Int) -> Self {
        return Self { features: {}, labels: {}, size: size, indices: [] }
    }

    pub fn to_device(self, device: Device) -> Batch {
        let batch = Batch.new(self.size)
        batch.indices = self.indices
        for (name, tensor) in self.features {
            batch.features[name] = tensor.to(device)
        }
        for (name, tensor) in self.labels {
            batch.labels[name] = tensor.to(device)
        }
        return batch
    }

    pub fn pin_memory(self) -> Batch {
        let batch = Batch.new(self.size)
        batch.indices = self.indices
        for (name, tensor) in self.features {
            batch.features[name] = tensor.pin_memory()
        }
        for (name, tensor) in self.labels {
            batch.labels[name] = tensor.pin_memory()
        }
        return batch
    }
}

// ── Transform Pipeline ─────────────────────────────────────────────

pub class Transform {
    _fn: Fn(Sample) -> Sample

    pub fn new(func: Fn(Sample) -> Sample) -> Self {
        return Self { _fn: func }
    }

    pub fn apply(self, sample: Sample) -> Sample {
        return self._fn(sample)
    }
}

pub class Normalize : Transform {
    pub mean: List[Float]
    pub std: List[Float]
    pub feature_name: String

    pub fn new(feature_name: String, mean: List[Float], std: List[Float]) -> Self {
        let func = fn(s: Sample) -> Sample {
            let t = s.features[feature_name]
            let mean_t = Tensor.from_list(mean, dtype: t.dtype)
            let std_t = Tensor.from_list(std, dtype: t.dtype)
            s.features[feature_name] = (t - mean_t) / std_t
            return s
        }
        return Self { _fn: func, mean: mean, std: std, feature_name: feature_name }
    }
}

pub class Standardize : Transform {
    pub feature_name: String

    pub fn new(feature_name: String) -> Self {
        let func = fn(s: Sample) -> Sample {
            let t = s.features[feature_name]
            let mu = t.mean()
            let sigma = t.std()
            s.features[feature_name] = (t - mu) / (sigma + 1e-8)
            return s
        }
        return Self { _fn: func, feature_name: feature_name }
    }
}

pub class RandomCrop : Transform {
    pub size: List[Int]
    pub feature_name: String

    pub fn new(feature_name: String, size: List[Int]) -> Self {
        let func = fn(s: Sample) -> Sample {
            let t = s.features[feature_name]
            let shape = t.shape()
            let h_start = random_int(0, shape[-2] - size[0])
            let w_start = random_int(0, shape[-1] - size[1])
            s.features[feature_name] = t.slice([h_start, h_start + size[0]], [w_start, w_start + size[1]])
            return s
        }
        return Self { _fn: func, size: size, feature_name: feature_name }
    }
}

pub class RandomFlip : Transform {
    pub axis: Int
    pub probability: Float
    pub feature_name: String

    pub fn new(feature_name: String, axis: Int = -1, probability: Float = 0.5) -> Self {
        let func = fn(s: Sample) -> Sample {
            if random_float() < probability {
                s.features[feature_name] = s.features[feature_name].flip(axis)
            }
            return s
        }
        return Self { _fn: func, axis: axis, probability: probability, feature_name: feature_name }
    }
}

pub class RandomRotate : Transform {
    pub max_angle: Float
    pub feature_name: String

    pub fn new(feature_name: String, max_angle: Float = 30.0) -> Self {
        let func = fn(s: Sample) -> Sample {
            let angle = random_float(-max_angle, max_angle)
            s.features[feature_name] = s.features[feature_name].rotate_2d(angle)
            return s
        }
        return Self { _fn: func, max_angle: max_angle, feature_name: feature_name }
    }
}

pub class AddNoise : Transform {
    pub std: Float
    pub feature_name: String

    pub fn new(feature_name: String, std: Float = 0.01) -> Self {
        let func = fn(s: Sample) -> Sample {
            let t = s.features[feature_name]
            let noise = Tensor.randn(t.shape(), dtype: t.dtype) * std
            s.features[feature_name] = t + noise
            return s
        }
        return Self { _fn: func, std: std, feature_name: feature_name }
    }
}

pub class Compose {
    pub transforms: List[Transform]

    pub fn new(transforms: List[Transform] = []) -> Self {
        return Self { transforms: transforms }
    }

    pub fn add(mut self, t: Transform) -> Self {
        self.transforms.append(t)
        return self
    }

    pub fn apply(self, sample: Sample) -> Sample {
        let result = sample
        for t in self.transforms {
            result = t.apply(result)
        }
        return result
    }
}

// ── Dataset ────────────────────────────────────────────────────────

pub class Dataset {
    pub source_path: String
    pub format: DataFormat
    pub schema: DataSchema
    pub length: Int
    _samples: List[Sample]
    _transform: Compose?

    pub fn new(source_path: String, format: DataFormat = DataFormat.CSV) -> Self {
        return Self {
            source_path: source_path,
            format: format,
            schema: DataSchema.new(),
            length: 0,
            _samples: [],
            _transform: nil
        }
    }

    pub fn from_tensors(features: Map[String, Tensor], labels: Map[String, Tensor]) -> Self {
        let ds = Self {
            source_path: "<memory>",
            format: DataFormat.Binary,
            schema: DataSchema.new(),
            length: 0,
            _samples: [],
            _transform: nil
        }
        let first_key = features.keys()[0]
        let n = features[first_key].shape()[0]
        ds.length = n
        for i in range(n) {
            let sample = Sample.new()
            for (name, tensor) in features {
                sample.set_feature(name, tensor[i])
            }
            for (name, tensor) in labels {
                sample.set_label(name, tensor[i])
            }
            ds._samples.append(sample)
        }
        return ds
    }

    pub fn load(mut self) -> Self {
        match self.format {
            DataFormat.CSV => self._load_csv(),
            DataFormat.JSON => self._load_json(),
            DataFormat.Parquet => self._load_parquet(),
            DataFormat.Arrow => self._load_arrow(),
            DataFormat.Image => self._load_images(),
            DataFormat.Text => self._load_text(),
            _ => self._load_binary()
        }
        return self
    }

    fn _load_csv(mut self) {
        let reader = CSVReader.new(self.source_path)
        self._samples = reader.read_all(self.schema)
        self.length = self._samples.len()
    }

    fn _load_json(mut self) {
        let reader = JSONReader.new(self.source_path)
        self._samples = reader.read_all(self.schema)
        self.length = self._samples.len()
    }

    fn _load_parquet(mut self) {
        let reader = ParquetReader.new(self.source_path)
        self._samples = reader.read_all(self.schema)
        self.length = self._samples.len()
    }

    fn _load_arrow(mut self) {
        let reader = ArrowReader.new(self.source_path)
        self._samples = reader.read_all(self.schema)
        self.length = self._samples.len()
    }

    fn _load_images(mut self) {
        let reader = ImageReader.new(self.source_path)
        self._samples = reader.read_all(self.schema)
        self.length = self._samples.len()
    }

    fn _load_text(mut self) {
        let reader = TextReader.new(self.source_path)
        self._samples = reader.read_all(self.schema)
        self.length = self._samples.len()
    }

    fn _load_binary(mut self) {
        let reader = BinaryReader.new(self.source_path)
        self._samples = reader.read_all(self.schema)
        self.length = self._samples.len()
    }

    pub fn with_schema(mut self, schema: DataSchema) -> Self {
        self.schema = schema
        return self
    }

    pub fn with_transform(mut self, transform: Compose) -> Self {
        self._transform = transform
        return self
    }

    pub fn get(self, index: Int) -> Sample {
        let sample = self._samples[index]
        if self._transform != nil {
            return self._transform.apply(sample)
        }
        return sample
    }

    pub fn len(self) -> Int {
        return self.length
    }

    pub fn split(self, ratios: List[Float], seed: Int = 42) -> List[Dataset] {
        let rng = RandomState.new(seed)
        let indices = rng.permutation(self.length)
        let splits = []
        let offset = 0
        for ratio in ratios {
            let count = (self.length.to_float() * ratio).to_int()
            let ds = Dataset.new(self.source_path, self.format)
            ds.schema = self.schema
            ds._transform = self._transform
            for i in range(offset, offset + count) {
                ds._samples.append(self._samples[indices[i]])
            }
            ds.length = ds._samples.len()
            offset = offset + count
            splits.append(ds)
        }
        return splits
    }

    pub fn map(self, func: Fn(Sample) -> Sample) -> Dataset {
        let ds = Dataset.new(self.source_path, self.format)
        ds.schema = self.schema
        for sample in self._samples {
            ds._samples.append(func(sample))
        }
        ds.length = ds._samples.len()
        return ds
    }

    pub fn filter(self, predicate: Fn(Sample) -> Bool) -> Dataset {
        let ds = Dataset.new(self.source_path, self.format)
        ds.schema = self.schema
        for sample in self._samples {
            if predicate(sample) {
                ds._samples.append(sample)
            }
        }
        ds.length = ds._samples.len()
        return ds
    }

    pub fn take(self, n: Int) -> Dataset {
        let ds = Dataset.new(self.source_path, self.format)
        ds.schema = self.schema
        let count = min(n, self.length)
        for i in range(count) {
            ds._samples.append(self._samples[i])
        }
        ds.length = count
        return ds
    }

    pub fn skip(self, n: Int) -> Dataset {
        let ds = Dataset.new(self.source_path, self.format)
        ds.schema = self.schema
        for i in range(n, self.length) {
            ds._samples.append(self._samples[i])
        }
        ds.length = ds._samples.len()
        return ds
    }

    pub fn concatenate(self, other: Dataset) -> Dataset {
        let ds = Dataset.new(self.source_path, self.format)
        ds.schema = self.schema
        for sample in self._samples {
            ds._samples.append(sample)
        }
        for sample in other._samples {
            ds._samples.append(sample)
        }
        ds.length = ds._samples.len()
        return ds
    }
}

// ── Streaming Dataset ──────────────────────────────────────────────

pub class StreamingDataset {
    pub source_path: String
    pub format: DataFormat
    pub schema: DataSchema
    pub buffer_size: Int
    _transform: Compose?
    _reader: Any?

    pub fn new(source_path: String, format: DataFormat = DataFormat.CSV, buffer_size: Int = 1024) -> Self {
        return Self {
            source_path: source_path,
            format: format,
            schema: DataSchema.new(),
            buffer_size: buffer_size,
            _transform: nil,
            _reader: nil
        }
    }

    pub fn with_schema(mut self, schema: DataSchema) -> Self {
        self.schema = schema
        return self
    }

    pub fn with_transform(mut self, transform: Compose) -> Self {
        self._transform = transform
        return self
    }

    pub fn open(mut self) -> Self {
        match self.format {
            DataFormat.CSV => self._reader = StreamCSVReader.new(self.source_path, self.buffer_size),
            DataFormat.JSON => self._reader = StreamJSONReader.new(self.source_path, self.buffer_size),
            DataFormat.Parquet => self._reader = StreamParquetReader.new(self.source_path, self.buffer_size),
            _ => self._reader = StreamBinaryReader.new(self.source_path, self.buffer_size)
        }
        return self
    }

    pub fn next_batch(self, batch_size: Int) -> Batch? {
        let samples = []
        for i in range(batch_size) {
            let sample = self._reader.next()
            if sample == nil {
                break
            }
            if self._transform != nil {
                sample = self._transform.apply(sample)
            }
            samples.append(sample)
        }
        if samples.len() == 0 {
            return nil
        }
        return _collate(samples)
    }

    pub fn reset(mut self) {
        self._reader.reset()
    }

    pub fn close(mut self) {
        self._reader.close()
        self._reader = nil
    }
}

// ── DataLoader ─────────────────────────────────────────────────────

pub class DataLoader {
    pub dataset: Dataset
    pub batch_size: Int
    pub shuffle: ShuffleMode
    pub drop_last: Bool
    pub num_workers: Int
    pub prefetch_factor: Int
    pub pin_memory: Bool
    pub device: Device?
    pub cache_policy: CachePolicy
    pub seed: Int
    _indices: List[Int]
    _position: Int
    _epoch: Int
    _cache: Map[Int, Batch]

    pub fn new(
        dataset: Dataset,
        batch_size: Int = 32,
        shuffle: ShuffleMode = ShuffleMode.PerEpoch,
        drop_last: Bool = false,
        num_workers: Int = 0,
        prefetch_factor: Int = 2,
        pin_memory: Bool = false,
        device: Device? = nil,
        cache_policy: CachePolicy = CachePolicy.None,
        seed: Int = 42
    ) -> Self {
        let indices = range(dataset.len()).to_list()
        return Self {
            dataset: dataset,
            batch_size: batch_size,
            shuffle: shuffle,
            drop_last: drop_last,
            num_workers: num_workers,
            prefetch_factor: prefetch_factor,
            pin_memory: pin_memory,
            device: device,
            cache_policy: cache_policy,
            seed: seed,
            _indices: indices,
            _position: 0,
            _epoch: 0,
            _cache: {}
        }
    }

    pub fn num_batches(self) -> Int {
        let n = self.dataset.len()
        if self.drop_last {
            return n / self.batch_size
        }
        return (n + self.batch_size - 1) / self.batch_size
    }

    pub fn reset(mut self) {
        self._position = 0
        self._epoch = self._epoch + 1
        if self.shuffle == ShuffleMode.PerEpoch || self.shuffle == ShuffleMode.Full {
            let rng = RandomState.new(self.seed + self._epoch)
            self._indices = rng.permutation(self.dataset.len()).to_list()
        }
    }

    pub fn next(mut self) -> Batch? {
        if self._position >= self.dataset.len() {
            return nil
        }

        let cache_key = self._position
        if self.cache_policy != CachePolicy.None && self._cache.contains(cache_key) {
            let batch = self._cache[cache_key]
            self._position = self._position + self.batch_size
            return batch
        }

        let end = min(self._position + self.batch_size, self.dataset.len())
        if self.drop_last && (end - self._position) < self.batch_size {
            return nil
        }

        let samples = []
        let batch_indices = []
        for i in range(self._position, end) {
            let idx = self._indices[i]
            samples.append(self.dataset.get(idx))
            batch_indices.append(idx)
        }

        let batch = _collate(samples)
        batch.indices = batch_indices

        if self.pin_memory {
            batch = batch.pin_memory()
        }
        if self.device != nil {
            batch = batch.to_device(self.device)
        }

        if self.cache_policy == CachePolicy.Memory {
            self._cache[cache_key] = batch
        }

        self._position = end
        return batch
    }

    pub fn iter(mut self) -> BatchIterator {
        self.reset()
        return BatchIterator.new(self)
    }

    pub fn clear_cache(mut self) {
        self._cache = {}
    }
}

pub class BatchIterator {
    _loader: DataLoader

    pub fn new(loader: DataLoader) -> Self {
        return Self { _loader: loader }
    }

    pub fn next(mut self) -> Batch? {
        return self._loader.next()
    }
}

// ── Parallel DataLoader ────────────────────────────────────────────

pub class ParallelDataLoader {
    pub dataset: Dataset
    pub batch_size: Int
    pub num_workers: Int
    pub prefetch_factor: Int
    pub shuffle: ShuffleMode
    pub drop_last: Bool
    pub pin_memory: Bool
    pub device: Device?
    pub seed: Int
    _worker_pool: WorkerPool?
    _prefetch_queue: Queue[Batch]
    _indices: List[Int]
    _position: Int
    _epoch: Int

    pub fn new(
        dataset: Dataset,
        batch_size: Int = 32,
        num_workers: Int = 4,
        prefetch_factor: Int = 2,
        shuffle: ShuffleMode = ShuffleMode.PerEpoch,
        drop_last: Bool = false,
        pin_memory: Bool = false,
        device: Device? = nil,
        seed: Int = 42
    ) -> Self {
        return Self {
            dataset: dataset,
            batch_size: batch_size,
            num_workers: num_workers,
            prefetch_factor: prefetch_factor,
            shuffle: shuffle,
            drop_last: drop_last,
            pin_memory: pin_memory,
            device: device,
            seed: seed,
            _worker_pool: nil,
            _prefetch_queue: Queue.new(),
            _indices: range(dataset.len()).to_list(),
            _position: 0,
            _epoch: 0
        }
    }

    pub fn start(mut self) {
        self._worker_pool = WorkerPool.new(self.num_workers)
        self._prefetch_queue = Queue.new(capacity: self.prefetch_factor * self.num_workers)
        self._schedule_prefetch()
    }

    fn _schedule_prefetch(mut self) {
        let to_prefetch = self.prefetch_factor * self.num_workers
        for _ in range(to_prefetch) {
            if self._position >= self.dataset.len() {
                break
            }
            let end = min(self._position + self.batch_size, self.dataset.len())
            if self.drop_last && (end - self._position) < self.batch_size {
                break
            }
            let batch_indices = self._indices[self._position:end]
            self._worker_pool.submit(fn() -> Batch {
                let samples = []
                for idx in batch_indices {
                    samples.append(self.dataset.get(idx))
                }
                return _collate(samples)
            })
            self._position = end
        }
    }

    pub fn next(mut self) -> Batch? {
        if self._worker_pool == nil {
            self.start()
        }
        let result = self._worker_pool.get_result()
        if result == nil {
            return nil
        }
        let batch = result
        if self.pin_memory {
            batch = batch.pin_memory()
        }
        if self.device != nil {
            batch = batch.to_device(self.device)
        }
        self._schedule_prefetch()
        return batch
    }

    pub fn reset(mut self) {
        self._epoch = self._epoch + 1
        self._position = 0
        if self.shuffle != ShuffleMode.None {
            let rng = RandomState.new(self.seed + self._epoch)
            self._indices = rng.permutation(self.dataset.len()).to_list()
        }
        self._prefetch_queue = Queue.new(capacity: self.prefetch_factor * self.num_workers)
    }

    pub fn shutdown(mut self) {
        if self._worker_pool != nil {
            self._worker_pool.shutdown()
            self._worker_pool = nil
        }
    }
}

// ── Data Sharding ──────────────────────────────────────────────────

pub class ShardConfig {
    pub num_shards: Int
    pub shard_id: Int
    pub overlap: Float

    pub fn new(num_shards: Int, shard_id: Int, overlap: Float = 0.0) -> Self {
        return Self { num_shards: num_shards, shard_id: shard_id, overlap: overlap }
    }
}

pub class ShardedDataset {
    pub dataset: Dataset
    pub config: ShardConfig
    _local_indices: List[Int]

    pub fn new(dataset: Dataset, config: ShardConfig) -> Self {
        let total = dataset.len()
        let shard_size = total / config.num_shards
        let overlap_count = (shard_size.to_float() * config.overlap).to_int()
        let start = config.shard_id * shard_size - overlap_count
        let end = (config.shard_id + 1) * shard_size + overlap_count
        start = max(0, start)
        end = min(total, end)
        let indices = range(start, end).to_list()
        return Self { dataset: dataset, config: config, _local_indices: indices }
    }

    pub fn get(self, index: Int) -> Sample {
        return self.dataset.get(self._local_indices[index])
    }

    pub fn len(self) -> Int {
        return self._local_indices.len()
    }
}

// ── Data Augmentation Registry ─────────────────────────────────────

pub class AugmentationPipeline {
    pub stages: List[Compose]
    pub probabilities: List[Float]

    pub fn new() -> Self {
        return Self { stages: [], probabilities: [] }
    }

    pub fn add_stage(mut self, transforms: Compose, probability: Float = 1.0) -> Self {
        self.stages.append(transforms)
        self.probabilities.append(probability)
        return self
    }

    pub fn apply(self, sample: Sample) -> Sample {
        let result = sample
        for i in range(self.stages.len()) {
            if random_float() < self.probabilities[i] {
                result = self.stages[i].apply(result)
            }
        }
        return result
    }
}

// ── Cache Manager ──────────────────────────────────────────────────

pub class CacheManager {
    pub policy: CachePolicy
    pub max_memory_mb: Int
    pub disk_path: String?
    _memory_cache: Map[String, Any]
    _disk_keys: List[String]
    _memory_used: Int

    pub fn new(policy: CachePolicy = CachePolicy.Memory, max_memory_mb: Int = 1024, disk_path: String? = nil) -> Self {
        return Self {
            policy: policy,
            max_memory_mb: max_memory_mb,
            disk_path: disk_path,
            _memory_cache: {},
            _disk_keys: [],
            _memory_used: 0
        }
    }

    pub fn get(self, key: String) -> Any? {
        if self._memory_cache.contains(key) {
            return self._memory_cache[key]
        }
        if self.policy == CachePolicy.Disk || self.policy == CachePolicy.Hybrid {
            return self._load_from_disk(key)
        }
        return nil
    }

    pub fn put(mut self, key: String, value: Any, size_bytes: Int) {
        if self.policy == CachePolicy.Memory || self.policy == CachePolicy.Hybrid {
            if self._memory_used + size_bytes <= self.max_memory_mb * 1024 * 1024 {
                self._memory_cache[key] = value
                self._memory_used = self._memory_used + size_bytes
            } else if self.policy == CachePolicy.Hybrid {
                self._save_to_disk(key, value)
            }
        } else if self.policy == CachePolicy.Disk {
            self._save_to_disk(key, value)
        }
    }

    fn _load_from_disk(self, key: String) -> Any? {
        if self.disk_path == nil { return nil }
        let path = self.disk_path + "/" + key + ".cache"
        if file_exists(path) {
            return deserialize(file_read_bytes(path))
        }
        return nil
    }

    fn _save_to_disk(mut self, key: String, value: Any) {
        if self.disk_path == nil { return }
        let path = self.disk_path + "/" + key + ".cache"
        file_write_bytes(path, serialize(value))
        self._disk_keys.append(key)
    }

    pub fn clear(mut self) {
        self._memory_cache = {}
        self._memory_used = 0
        for key in self._disk_keys {
            let path = self.disk_path + "/" + key + ".cache"
            if file_exists(path) { file_delete(path) }
        }
        self._disk_keys = []
    }

    pub fn stats(self) -> Map[String, Any] {
        return {
            "policy": self.policy.to_string(),
            "memory_used_mb": self._memory_used / (1024 * 1024),
            "max_memory_mb": self.max_memory_mb,
            "memory_entries": self._memory_cache.len(),
            "disk_entries": self._disk_keys.len()
        }
    }
}

// ── Collate Helper ─────────────────────────────────────────────────

fn _collate(samples: List[Sample]) -> Batch {
    let batch = Batch.new(samples.len())
    if samples.len() == 0 {
        return batch
    }
    let first = samples[0]
    for name in first.features.keys() {
        let tensors = []
        for sample in samples {
            tensors.append(sample.features[name])
        }
        batch.features[name] = Tensor.stack(tensors, dim: 0)
    }
    for name in first.labels.keys() {
        let tensors = []
        for sample in samples {
            tensors.append(sample.labels[name])
        }
        batch.labels[name] = Tensor.stack(tensors, dim: 0)
    }
    return batch
}

// ── Convenience Factories ──────────────────────────────────────────

pub fn load_csv(path: String, schema: DataSchema? = nil) -> Dataset {
    let ds = Dataset.new(path, DataFormat.CSV)
    if schema != nil { ds.with_schema(schema) }
    return ds.load()
}

pub fn load_json(path: String, schema: DataSchema? = nil) -> Dataset {
    let ds = Dataset.new(path, DataFormat.JSON)
    if schema != nil { ds.with_schema(schema) }
    return ds.load()
}

pub fn load_images(path: String, schema: DataSchema? = nil) -> Dataset {
    let ds = Dataset.new(path, DataFormat.Image)
    if schema != nil { ds.with_schema(schema) }
    return ds.load()
}

pub fn make_loader(
    dataset: Dataset,
    batch_size: Int = 32,
    shuffle: Bool = true,
    num_workers: Int = 0,
    pin_memory: Bool = false,
    device: Device? = nil
) -> DataLoader {
    let mode = if shuffle { ShuffleMode.PerEpoch } else { ShuffleMode.None }
    return DataLoader.new(dataset, batch_size: batch_size, shuffle: mode,
                          num_workers: num_workers, pin_memory: pin_memory, device: device)
}

pub fn train_val_test_split(dataset: Dataset, train: Float = 0.7, val: Float = 0.15, test: Float = 0.15, seed: Int = 42) -> (Dataset, Dataset, Dataset) {
    let splits = dataset.split([train, val, test], seed: seed)
    return (splits[0], splits[1], splits[2])
}

export {
    DataFormat, SplitType, ShuffleMode, CachePolicy,
    ColumnSchema, DataSchema, Sample, Batch,
    Transform, Normalize, Standardize, RandomCrop, RandomFlip, RandomRotate, AddNoise, Compose,
    Dataset, StreamingDataset,
    DataLoader, BatchIterator, ParallelDataLoader,
    ShardConfig, ShardedDataset,
    AugmentationPipeline, CacheManager,
    load_csv, load_json, load_images, make_loader, train_val_test_split
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
