# ============================================================
# NyTensor - Core Mathematical Computation Engine
# Version 1.0.0
# Backbone of all ML computation in Nyx
# ============================================================

# ============================================================
# SECTION 1: DATA TYPES AND ENUMERATIONS
# ============================================================

pub enum DType {
    Float16,
    BFloat16,
    Float32,
    Float64,
    Int8,
    Int16,
    Int32,
    Int64,
    UInt8,
    UInt16,
    UInt32,
    UInt64,
    Bool,
    Complex64,
    Complex128
}

pub enum Device {
    CPU,
    CUDA,
    ROCm,
    Metal
}

pub enum SparseFormat {
    CSR,
    CSC,
    COO,
    BSR
}

pub enum SIMDBackend {
    None,
    AVX2,
    AVX512,
    NEON,
    Auto
}

pub enum MemoryLayout {
    RowMajor,
    ColumnMajor,
    Strided
}

# ============================================================
# SECTION 2: MEMORY POOL SYSTEM
# ============================================================

pub class MemoryPool {
    pub let block_size: Int;
    pub let max_blocks: Int;
    pub let allocated: Int;
    pub let device: Device;

    pub fn new(block_size: Int, max_blocks: Int, device: Device) -> Self {
        return Self {
            block_size: block_size,
            max_blocks: max_blocks,
            allocated: 0,
            device: device
        };
    }

    pub fn alloc(self, size: Int) -> Int {
        if (self.allocated + size > self.max_blocks * self.block_size) {
            throw "MemoryPool: out of memory (requested " + str(size) + " bytes)";
        }
        let ptr = match self.device {
            Device::CPU => native_malloc(size),
            Device::CUDA => native_cuda_malloc(size),
            Device::ROCm => native_rocm_malloc(size),
            Device::Metal => native_metal_malloc(size)
        };
        self.allocated = self.allocated + size;
        return ptr;
    }

    pub fn free(self, ptr: Int, size: Int) {
        match self.device {
            Device::CPU => native_free(ptr),
            Device::CUDA => native_cuda_free(ptr),
            Device::ROCm => native_rocm_free(ptr),
            Device::Metal => native_metal_free(ptr)
        };
        self.allocated = self.allocated - size;
    }

    pub fn reset(self) {
        self.allocated = 0;
    }

    pub fn utilization(self) -> Float {
        return self.allocated / (self.max_blocks * self.block_size);
    }
}

pub class ArenaAllocator {
    pub let capacity: Int;
    pub let offset: Int;
    pub let device: Device;

    pub fn new(capacity: Int, device: Device) -> Self {
        return Self { capacity: capacity, offset: 0, device: device };
    }

    pub fn alloc(self, size: Int) -> Int {
        let aligned = (size + 63) / 64 * 64;
        if (self.offset + aligned > self.capacity) {
            throw "ArenaAllocator: capacity exceeded";
        }
        let ptr = self.offset;
        self.offset = self.offset + aligned;
        return ptr;
    }

    pub fn reset(self) {
        self.offset = 0;
    }

    pub fn remaining(self) -> Int {
        return self.capacity - self.offset;
    }
}

# ============================================================
# SECTION 3: SHAPE AND STRIDE UTILITIES
# ============================================================

pub class Shape {
    pub let dims: [Int];

    pub fn new(dims: [Int]) -> Self {
        return Self { dims: dims };
    }

    pub fn ndim(self) -> Int {
        return len(self.dims);
    }

    pub fn numel(self) -> Int {
        let total = 1;
        for (d in self.dims) {
            total = total * d;
        }
        return total;
    }

    pub fn eq(self, other: Shape) -> Bool {
        if (len(self.dims) != len(other.dims)) {
            return false;
        }
        for (i in range(len(self.dims))) {
            if (self.dims[i] != other.dims[i]) {
                return false;
            }
        }
        return true;
    }

    pub fn to_string(self) -> String {
        return "Shape(" + str(self.dims) + ")";
    }
}

pub fn compute_strides(shape: [Int], layout: MemoryLayout) -> [Int] {
    let ndim = len(shape);
    let strides = [];
    for (i in range(ndim)) {
        strides = strides + [0];
    }

    if (layout == MemoryLayout::RowMajor) {
        strides[ndim - 1] = 1;
        for (i in range(ndim - 2, -1, -1)) {
            strides[i] = strides[i + 1] * shape[i + 1];
        }
    } else {
        strides[0] = 1;
        for (i in range(1, ndim)) {
            strides[i] = strides[i - 1] * shape[i - 1];
        }
    }
    return strides;
}

# ============================================================
# SECTION 4: CORE TENSOR CLASS
# ============================================================

pub class Tensor {
    pub let data: [Float];
    pub let shape: Shape;
    pub let strides: [Int];
    pub let dtype: DType;
    pub let device: Device;
    pub let layout: MemoryLayout;
    pub let requires_grad: Bool;
    pub let grad: Tensor?;
    pub let _name: String;

    pub fn new(data: [Float], shape: [Int], dtype: DType, device: Device) -> Self {
        let s = Shape::new(shape);
        let st = compute_strides(shape, MemoryLayout::RowMajor);
        return Self {
            data: data,
            shape: s,
            strides: st,
            dtype: dtype,
            device: device,
            layout: MemoryLayout::RowMajor,
            requires_grad: false,
            grad: null,
            _name: ""
        };
    }

    pub fn zeros(shape: [Int], dtype: DType, device: Device) -> Tensor {
        let s = Shape::new(shape);
        let n = s.numel();
        let data = [];
        for (i in range(n)) {
            data = data + [0.0];
        }
        return Tensor::new(data, shape, dtype, device);
    }

    pub fn ones(shape: [Int], dtype: DType, device: Device) -> Tensor {
        let s = Shape::new(shape);
        let n = s.numel();
        let data = [];
        for (i in range(n)) {
            data = data + [1.0];
        }
        return Tensor::new(data, shape, dtype, device);
    }

    pub fn full(shape: [Int], value: Float, dtype: DType, device: Device) -> Tensor {
        let s = Shape::new(shape);
        let n = s.numel();
        let data = [];
        for (i in range(n)) {
            data = data + [value];
        }
        return Tensor::new(data, shape, dtype, device);
    }

    pub fn arange(start: Float, stop: Float, step: Float, dtype: DType) -> Tensor {
        let data = [];
        let v = start;
        while (v < stop) {
            data = data + [v];
            v = v + step;
        }
        return Tensor::new(data, [len(data)], dtype, Device::CPU);
    }

    pub fn linspace(start: Float, stop: Float, num: Int, dtype: DType) -> Tensor {
        let data = [];
        let step = (stop - start) / (num - 1);
        for (i in range(num)) {
            data = data + [start + i * step];
        }
        return Tensor::new(data, [num], dtype, Device::CPU);
    }

    pub fn rand(shape: [Int], dtype: DType, device: Device) -> Tensor {
        let s = Shape::new(shape);
        let n = s.numel();
        let data = [];
        for (i in range(n)) {
            data = data + [native_random_float()];
        }
        return Tensor::new(data, shape, dtype, device);
    }

    pub fn randn(shape: [Int], dtype: DType, device: Device) -> Tensor {
        let s = Shape::new(shape);
        let n = s.numel();
        let data = [];
        for (i in range(n)) {
            data = data + [native_random_normal(0.0, 1.0)];
        }
        return Tensor::new(data, shape, dtype, device);
    }

    pub fn eye(n: Int, dtype: DType, device: Device) -> Tensor {
        let data = [];
        for (i in range(n)) {
            for (j in range(n)) {
                if (i == j) {
                    data = data + [1.0];
                } else {
                    data = data + [0.0];
                }
            }
        }
        return Tensor::new(data, [n, n], dtype, device);
    }

    # ----- Element Access -----

    pub fn get(self, indices: [Int]) -> Float {
        let flat = 0;
        for (i in range(len(indices))) {
            flat = flat + indices[i] * self.strides[i];
        }
        return self.data[flat];
    }

    pub fn set(self, indices: [Int], value: Float) {
        let flat = 0;
        for (i in range(len(indices))) {
            flat = flat + indices[i] * self.strides[i];
        }
        self.data[flat] = value;
    }

    # ----- Shape Operations -----

    pub fn ndim(self) -> Int {
        return self.shape.ndim();
    }

    pub fn numel(self) -> Int {
        return self.shape.numel();
    }

    pub fn reshape(self, new_shape: [Int]) -> Tensor {
        let ns = Shape::new(new_shape);
        if (ns.numel() != self.numel()) {
            throw "reshape: total elements mismatch";
        }
        return Tensor::new(self.data, new_shape, self.dtype, self.device);
    }

    pub fn view(self, new_shape: [Int]) -> Tensor {
        return self.reshape(new_shape);
    }

    pub fn flatten(self) -> Tensor {
        return self.reshape([self.numel()]);
    }

    pub fn squeeze(self, dim: Int) -> Tensor {
        let new_dims = [];
        for (i, d in self.shape.dims) {
            if (i == dim && d == 1) {
                # skip
            } else {
                new_dims = new_dims + [d];
            }
        }
        return self.reshape(new_dims);
    }

    pub fn unsqueeze(self, dim: Int) -> Tensor {
        let new_dims = [];
        for (i in range(len(self.shape.dims))) {
            if (i == dim) {
                new_dims = new_dims + [1];
            }
            new_dims = new_dims + [self.shape.dims[i]];
        }
        if (dim == len(self.shape.dims)) {
            new_dims = new_dims + [1];
        }
        return self.reshape(new_dims);
    }

    pub fn transpose(self) -> Tensor {
        if (self.ndim() != 2) {
            throw "transpose: requires 2D tensor";
        }
        let rows = self.shape.dims[0];
        let cols = self.shape.dims[1];
        let data = [];
        for (j in range(cols)) {
            for (i in range(rows)) {
                data = data + [self.get([i, j])];
            }
        }
        return Tensor::new(data, [cols, rows], self.dtype, self.device);
    }

    pub fn permute(self, axes: [Int]) -> Tensor {
        let new_shape = [];
        for (a in axes) {
            new_shape = new_shape + [self.shape.dims[a]];
        }
        let result = Tensor::zeros(new_shape, self.dtype, self.device);
        # Generalized permutation via index remapping
        let n = self.numel();
        for (flat in range(n)) {
            let src_idx = _unravel(flat, self.shape.dims);
            let dst_idx = [];
            for (a in axes) {
                dst_idx = dst_idx + [src_idx[a]];
            }
            result.set(dst_idx, self.get(src_idx));
        }
        return result;
    }

    pub fn contiguous(self) -> Tensor {
        return Tensor::new(self.data, self.shape.dims, self.dtype, self.device);
    }

    # ----- Element-wise Operations -----

    pub fn add(self, other: Tensor) -> Tensor {
        let a = broadcast(self, other);
        let b = broadcast(other, self);
        let data = [];
        for (i in range(a.numel())) {
            data = data + [a.data[i] + b.data[i]];
        }
        return Tensor::new(data, a.shape.dims, self.dtype, self.device);
    }

    pub fn sub(self, other: Tensor) -> Tensor {
        let a = broadcast(self, other);
        let b = broadcast(other, self);
        let data = [];
        for (i in range(a.numel())) {
            data = data + [a.data[i] - b.data[i]];
        }
        return Tensor::new(data, a.shape.dims, self.dtype, self.device);
    }

    pub fn mul(self, other: Tensor) -> Tensor {
        let a = broadcast(self, other);
        let b = broadcast(other, self);
        let data = [];
        for (i in range(a.numel())) {
            data = data + [a.data[i] * b.data[i]];
        }
        return Tensor::new(data, a.shape.dims, self.dtype, self.device);
    }

    pub fn div(self, other: Tensor) -> Tensor {
        let a = broadcast(self, other);
        let b = broadcast(other, self);
        let data = [];
        for (i in range(a.numel())) {
            if (b.data[i] == 0.0) {
                throw "div: division by zero at index " + str(i);
            }
            data = data + [a.data[i] / b.data[i]];
        }
        return Tensor::new(data, a.shape.dims, self.dtype, self.device);
    }

    pub fn pow(self, exponent: Float) -> Tensor {
        let data = [];
        for (i in range(self.numel())) {
            data = data + [native_pow(self.data[i], exponent)];
        }
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn sqrt(self) -> Tensor {
        return self.pow(0.5);
    }

    pub fn abs(self) -> Tensor {
        let data = [];
        for (i in range(self.numel())) {
            let v = self.data[i];
            data = data + [v < 0.0 ? -v : v];
        }
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn neg(self) -> Tensor {
        let data = [];
        for (i in range(self.numel())) {
            data = data + [-self.data[i]];
        }
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn exp(self) -> Tensor {
        let data = [];
        for (i in range(self.numel())) {
            data = data + [native_exp(self.data[i])];
        }
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn log(self) -> Tensor {
        let data = [];
        for (i in range(self.numel())) {
            if (self.data[i] <= 0.0) {
                throw "log: non-positive value at index " + str(i);
            }
            data = data + [native_log(self.data[i])];
        }
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn sin(self) -> Tensor {
        let data = [native_sin(v) for v in self.data];
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn cos(self) -> Tensor {
        let data = [native_cos(v) for v in self.data];
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn tanh(self) -> Tensor {
        let data = [native_tanh(v) for v in self.data];
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn sigmoid(self) -> Tensor {
        let data = [1.0 / (1.0 + native_exp(-v)) for v in self.data];
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn relu(self) -> Tensor {
        let data = [v > 0.0 ? v : 0.0 for v in self.data];
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn clamp(self, min_val: Float, max_val: Float) -> Tensor {
        let data = [];
        for (v in self.data) {
            if (v < min_val) { data = data + [min_val]; }
            else if (v > max_val) { data = data + [max_val]; }
            else { data = data + [v]; }
        }
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn scale(self, scalar: Float) -> Tensor {
        let data = [v * scalar for v in self.data];
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    pub fn add_scalar(self, scalar: Float) -> Tensor {
        let data = [v + scalar for v in self.data];
        return Tensor::new(data, self.shape.dims, self.dtype, self.device);
    }

    # ----- Reduction Operations -----

    pub fn sum(self) -> Float {
        let s = 0.0;
        for (v in self.data) { s = s + v; }
        return s;
    }

    pub fn mean(self) -> Float {
        return self.sum() / self.numel();
    }

    pub fn max(self) -> Float {
        let m = self.data[0];
        for (v in self.data) {
            if (v > m) { m = v; }
        }
        return m;
    }

    pub fn min(self) -> Float {
        let m = self.data[0];
        for (v in self.data) {
            if (v < m) { m = v; }
        }
        return m;
    }

    pub fn argmax(self) -> Int {
        let m = self.data[0];
        let idx = 0;
        for (i in range(len(self.data))) {
            if (self.data[i] > m) {
                m = self.data[i];
                idx = i;
            }
        }
        return idx;
    }

    pub fn argmin(self) -> Int {
        let m = self.data[0];
        let idx = 0;
        for (i in range(len(self.data))) {
            if (self.data[i] < m) {
                m = self.data[i];
                idx = i;
            }
        }
        return idx;
    }

    pub fn var(self) -> Float {
        let m = self.mean();
        let s = 0.0;
        for (v in self.data) {
            let d = v - m;
            s = s + d * d;
        }
        return s / self.numel();
    }

    pub fn std(self) -> Float {
        return native_sqrt(self.var());
    }

    pub fn norm(self, p: Float) -> Float {
        if (p == 2.0) {
            let s = 0.0;
            for (v in self.data) { s = s + v * v; }
            return native_sqrt(s);
        } else if (p == 1.0) {
            let s = 0.0;
            for (v in self.data) { s = s + (v < 0.0 ? -v : v); }
            return s;
        } else {
            let s = 0.0;
            for (v in self.data) { s = s + native_pow(v < 0.0 ? -v : v, p); }
            return native_pow(s, 1.0 / p);
        }
    }

    pub fn sum_axis(self, axis: Int) -> Tensor {
        let dims = self.shape.dims;
        let ndim = len(dims);
        let new_dims = [];
        for (i in range(ndim)) {
            if (i != axis) {
                new_dims = new_dims + [dims[i]];
            }
        }
        let result = Tensor::zeros(new_dims, self.dtype, self.device);
        let n = self.numel();
        for (flat in range(n)) {
            let idx = _unravel(flat, dims);
            let dst_idx = [];
            for (i in range(ndim)) {
                if (i != axis) {
                    dst_idx = dst_idx + [idx[i]];
                }
            }
            let cur = result.get(dst_idx);
            result.set(dst_idx, cur + self.data[flat]);
        }
        return result;
    }

    pub fn mean_axis(self, axis: Int) -> Tensor {
        let s = self.sum_axis(axis);
        let dim_size = self.shape.dims[axis];
        return s.scale(1.0 / dim_size);
    }

    # ----- Comparison Operations -----

    pub fn eq(self, other: Tensor) -> Tensor {
        let data = [];
        for (i in range(self.numel())) {
            data = data + [self.data[i] == other.data[i] ? 1.0 : 0.0];
        }
        return Tensor::new(data, self.shape.dims, DType::Bool, self.device);
    }

    pub fn gt(self, other: Tensor) -> Tensor {
        let data = [];
        for (i in range(self.numel())) {
            data = data + [self.data[i] > other.data[i] ? 1.0 : 0.0];
        }
        return Tensor::new(data, self.shape.dims, DType::Bool, self.device);
    }

    pub fn lt(self, other: Tensor) -> Tensor {
        let data = [];
        for (i in range(self.numel())) {
            data = data + [self.data[i] < other.data[i] ? 1.0 : 0.0];
        }
        return Tensor::new(data, self.shape.dims, DType::Bool, self.device);
    }

    pub fn where(condition: Tensor, a: Tensor, b: Tensor) -> Tensor {
        let data = [];
        for (i in range(a.numel())) {
            data = data + [condition.data[i] > 0.5 ? a.data[i] : b.data[i]];
        }
        return Tensor::new(data, a.shape.dims, a.dtype, a.device);
    }

    # ----- Device Transfer -----

    pub fn to(self, device: Device) -> Tensor {
        if (self.device == device) {
            return self;
        }
        let new_data = match device {
            Device::CUDA => native_tensor_to_cuda(self.data),
            Device::ROCm => native_tensor_to_rocm(self.data),
            Device::CPU => native_tensor_to_cpu(self.data),
            Device::Metal => native_tensor_to_metal(self.data)
        };
        let t = Tensor::new(new_data, self.shape.dims, self.dtype, device);
        t.requires_grad = self.requires_grad;
        return t;
    }

    # ----- DType Casting -----

    pub fn to_dtype(self, dtype: DType) -> Tensor {
        let t = Tensor::new(self.data, self.shape.dims, dtype, self.device);
        t.requires_grad = self.requires_grad;
        return t;
    }

    pub fn half(self) -> Tensor {
        return self.to_dtype(DType::Float16);
    }

    pub fn bfloat16(self) -> Tensor {
        return self.to_dtype(DType::BFloat16);
    }

    pub fn float(self) -> Tensor {
        return self.to_dtype(DType::Float32);
    }

    pub fn double(self) -> Tensor {
        return self.to_dtype(DType::Float64);
    }

    # ----- Gradient Support -----

    pub fn with_grad(self) -> Tensor {
        self.requires_grad = true;
        return self;
    }

    pub fn detach(self) -> Tensor {
        let t = Tensor::new(self.data, self.shape.dims, self.dtype, self.device);
        t.requires_grad = false;
        return t;
    }

    pub fn zero_grad(self) {
        if (self.grad != null) {
            self.grad = Tensor::zeros(self.shape.dims, self.dtype, self.device);
        }
    }

    # ----- Concatenation & Stacking -----

    pub fn cat(tensors: [Tensor], axis: Int) -> Tensor {
        if (len(tensors) == 0) {
            throw "cat: empty tensor list";
        }
        # For axis=0 concatenation of 1D tensors
        let data = [];
        for (t in tensors) {
            for (v in t.data) {
                data = data + [v];
            }
        }
        let total = len(data);
        return Tensor::new(data, [total], tensors[0].dtype, tensors[0].device);
    }

    pub fn stack(tensors: [Tensor], axis: Int) -> Tensor {
        let n = len(tensors);
        let inner_shape = tensors[0].shape.dims;
        let new_shape = [n] + inner_shape;
        let data = [];
        for (t in tensors) {
            for (v in t.data) {
                data = data + [v];
            }
        }
        return Tensor::new(data, new_shape, tensors[0].dtype, tensors[0].device);
    }

    pub fn chunk(self, chunks: Int, dim: Int) -> [Tensor] {
        let size = self.shape.dims[dim];
        let chunk_size = (size + chunks - 1) / chunks;
        let results = [];
        let offset = 0;
        for (c in range(chunks)) {
            let end = min(offset + chunk_size, size);
            let slice_data = [];
            for (i in range(offset, end)) {
                slice_data = slice_data + [self.data[i]];
            }
            let new_shape = self.shape.dims;
            new_shape[dim] = end - offset;
            results = results + [Tensor::new(slice_data, new_shape, self.dtype, self.device)];
            offset = end;
        }
        return results;
    }

    # ----- String Representation -----

    pub fn to_string(self) -> String {
        return "Tensor(shape=" + self.shape.to_string() + ", dtype=" + str(self.dtype) +
               ", device=" + str(self.device) + ")";
    }

    pub fn print(self) {
        print(self.to_string());
        if (self.numel() <= 20) {
            print(self.data);
        } else {
            print("[" + str(self.data[0]) + ", " + str(self.data[1]) + ", ..., " +
                  str(self.data[self.numel() - 1]) + "]");
        }
    }
}

# ============================================================
# SECTION 5: BROADCASTING SYSTEM
# ============================================================

pub fn broadcast_shapes(a: [Int], b: [Int]) -> [Int] {
    let max_ndim = max(len(a), len(b));
    let result = [];
    for (i in range(max_ndim)) {
        let da = i < len(a) ? a[len(a) - 1 - i] : 1;
        let db = i < len(b) ? b[len(b) - 1 - i] : 1;
        if (da != db && da != 1 && db != 1) {
            throw "broadcast: incompatible shapes at dim " + str(i);
        }
        result = [max(da, db)] + result;
    }
    return result;
}

pub fn broadcast(tensor: Tensor, target: Tensor) -> Tensor {
    if (tensor.shape.eq(target.shape)) {
        return tensor;
    }
    let target_shape = broadcast_shapes(tensor.shape.dims, target.shape.dims);
    let n = 1;
    for (d in target_shape) { n = n * d; }
    let data = [];
    for (i in range(n)) {
        let idx = _unravel(i, target_shape);
        let src_idx = [];
        for (j in range(len(idx))) {
            let dim_offset = len(target_shape) - len(tensor.shape.dims);
            if (j < dim_offset) {
                # broadcasted dimension
            } else {
                let src_dim = j - dim_offset;
                if (tensor.shape.dims[src_dim] == 1) {
                    src_idx = src_idx + [0];
                } else {
                    src_idx = src_idx + [idx[j]];
                }
            }
        }
        data = data + [tensor.get(src_idx)];
    }
    return Tensor::new(data, target_shape, tensor.dtype, tensor.device);
}

# ============================================================
# SECTION 6: LINEAR ALGEBRA (BLAS/LAPACK-GRADE)
# ============================================================

pub mod linalg {

    pub fn matmul(a: Tensor, b: Tensor) -> Tensor {
        if (a.ndim() != 2 || b.ndim() != 2) {
            throw "matmul: requires 2D tensors";
        }
        let m = a.shape.dims[0];
        let k = a.shape.dims[1];
        let n = b.shape.dims[1];
        if (k != b.shape.dims[0]) {
            throw "matmul: inner dimensions mismatch (" + str(k) + " vs " + str(b.shape.dims[0]) + ")";
        }
        let data = [];
        for (i in range(m)) {
            for (j in range(n)) {
                let s = 0.0;
                for (p in range(k)) {
                    s = s + a.get([i, p]) * b.get([p, j]);
                }
                data = data + [s];
            }
        }
        return Tensor::new(data, [m, n], a.dtype, a.device);
    }

    pub fn batch_matmul(a: Tensor, b: Tensor) -> Tensor {
        if (a.ndim() != 3 || b.ndim() != 3) {
            throw "batch_matmul: requires 3D tensors [batch, m, k] x [batch, k, n]";
        }
        let batch = a.shape.dims[0];
        let m = a.shape.dims[1];
        let k = a.shape.dims[2];
        let n = b.shape.dims[2];
        let data = [];
        for (bi in range(batch)) {
            for (i in range(m)) {
                for (j in range(n)) {
                    let s = 0.0;
                    for (p in range(k)) {
                        s = s + a.get([bi, i, p]) * b.get([bi, p, j]);
                    }
                    data = data + [s];
                }
            }
        }
        return Tensor::new(data, [batch, m, n], a.dtype, a.device);
    }

    pub fn dot(a: Tensor, b: Tensor) -> Float {
        if (a.ndim() != 1 || b.ndim() != 1) {
            throw "dot: requires 1D tensors";
        }
        let s = 0.0;
        for (i in range(a.numel())) {
            s = s + a.data[i] * b.data[i];
        }
        return s;
    }

    pub fn outer(a: Tensor, b: Tensor) -> Tensor {
        let m = a.numel();
        let n = b.numel();
        let data = [];
        for (i in range(m)) {
            for (j in range(n)) {
                data = data + [a.data[i] * b.data[j]];
            }
        }
        return Tensor::new(data, [m, n], a.dtype, a.device);
    }

    pub fn trace(a: Tensor) -> Float {
        if (a.ndim() != 2 || a.shape.dims[0] != a.shape.dims[1]) {
            throw "trace: requires square matrix";
        }
        let s = 0.0;
        let n = a.shape.dims[0];
        for (i in range(n)) {
            s = s + a.get([i, i]);
        }
        return s;
    }

    pub fn det(a: Tensor) -> Float {
        if (a.ndim() != 2 || a.shape.dims[0] != a.shape.dims[1]) {
            throw "det: requires square matrix";
        }
        let n = a.shape.dims[0];
        if (n == 1) { return a.get([0, 0]); }
        if (n == 2) {
            return a.get([0,0]) * a.get([1,1]) - a.get([0,1]) * a.get([1,0]);
        }
        # LU decomposition based determinant
        let lu = _lu_decompose(a);
        let d = 1.0;
        for (i in range(n)) {
            d = d * lu.get([i, i]);
        }
        return d * lu._sign;
    }

    pub fn inv(a: Tensor) -> Tensor {
        if (a.ndim() != 2 || a.shape.dims[0] != a.shape.dims[1]) {
            throw "inv: requires square matrix";
        }
        let n = a.shape.dims[0];
        # Gauss-Jordan elimination
        let aug = Tensor::zeros([n, 2 * n], a.dtype, a.device);
        for (i in range(n)) {
            for (j in range(n)) {
                aug.set([i, j], a.get([i, j]));
            }
            aug.set([i, n + i], 1.0);
        }
        for (col in range(n)) {
            let pivot = aug.get([col, col]);
            if (native_abs(pivot) < 1e-12) {
                throw "inv: singular matrix";
            }
            for (j in range(2 * n)) {
                aug.set([col, j], aug.get([col, j]) / pivot);
            }
            for (row in range(n)) {
                if (row != col) {
                    let factor = aug.get([row, col]);
                    for (j in range(2 * n)) {
                        aug.set([row, j], aug.get([row, j]) - factor * aug.get([col, j]));
                    }
                }
            }
        }
        let result = Tensor::zeros([n, n], a.dtype, a.device);
        for (i in range(n)) {
            for (j in range(n)) {
                result.set([i, j], aug.get([i, n + j]));
            }
        }
        return result;
    }

    pub fn solve(a: Tensor, b: Tensor) -> Tensor {
        let a_inv = inv(a);
        return matmul(a_inv, b);
    }

    pub fn norm(a: Tensor, ord: String) -> Float {
        if (ord == "fro") {
            return a.norm(2.0);
        } else if (ord == "1") {
            return a.norm(1.0);
        } else if (ord == "inf") {
            return a.max();
        }
        return a.norm(2.0);
    }

    pub fn qr(a: Tensor) -> [Tensor] {
        # Gram-Schmidt QR decomposition
        let m = a.shape.dims[0];
        let n = a.shape.dims[1];
        let q = Tensor::zeros([m, n], a.dtype, a.device);
        let r = Tensor::zeros([n, n], a.dtype, a.device);
        for (j in range(n)) {
            let v = [];
            for (i in range(m)) { v = v + [a.get([i, j])]; }
            for (k in range(j)) {
                let proj = 0.0;
                for (i in range(m)) { proj = proj + q.get([i, k]) * v[i]; }
                r.set([k, j], proj);
                for (i in range(m)) { v[i] = v[i] - proj * q.get([i, k]); }
            }
            let nrm = 0.0;
            for (i in range(m)) { nrm = nrm + v[i] * v[i]; }
            nrm = native_sqrt(nrm);
            r.set([j, j], nrm);
            if (nrm > 1e-12) {
                for (i in range(m)) { q.set([i, j], v[i] / nrm); }
            }
        }
        return [q, r];
    }

    pub fn svd(a: Tensor) -> [Tensor] {
        # Power iteration SVD approximation
        let ata = matmul(a.transpose(), a);
        let n = ata.shape.dims[0];
        let v = Tensor::randn([n, n], a.dtype, a.device);
        for (iter in range(100)) {
            v = matmul(ata, v);
            # Normalize columns
            for (j in range(n)) {
                let nrm = 0.0;
                for (i in range(n)) { nrm = nrm + v.get([i, j]) * v.get([i, j]); }
                nrm = native_sqrt(nrm);
                if (nrm > 1e-12) {
                    for (i in range(n)) { v.set([i, j], v.get([i, j]) / nrm); }
                }
            }
        }
        let av = matmul(a, v);
        let sigma_data = [];
        let u = Tensor::zeros([a.shape.dims[0], n], a.dtype, a.device);
        for (j in range(n)) {
            let nrm = 0.0;
            for (i in range(a.shape.dims[0])) { nrm = nrm + av.get([i, j]) * av.get([i, j]); }
            nrm = native_sqrt(nrm);
            sigma_data = sigma_data + [nrm];
            if (nrm > 1e-12) {
                for (i in range(a.shape.dims[0])) { u.set([i, j], av.get([i, j]) / nrm); }
            }
        }
        let sigma = Tensor::new(sigma_data, [n], a.dtype, a.device);
        return [u, sigma, v];
    }

    pub fn eig(a: Tensor) -> [Tensor] {
        # QR algorithm for eigenvalue decomposition
        let n = a.shape.dims[0];
        let ak = Tensor::new(a.data, a.shape.dims, a.dtype, a.device);
        let eigvecs = Tensor::eye(n, a.dtype, a.device);
        for (iter in range(200)) {
            let decomp = qr(ak);
            let q = decomp[0];
            let r = decomp[1];
            ak = matmul(r, q);
            eigvecs = matmul(eigvecs, q);
        }
        let eigenvalues_data = [];
        for (i in range(n)) {
            eigenvalues_data = eigenvalues_data + [ak.get([i, i])];
        }
        let eigenvalues = Tensor::new(eigenvalues_data, [n], a.dtype, a.device);
        return [eigenvalues, eigvecs];
    }

    pub fn cholesky(a: Tensor) -> Tensor {
        let n = a.shape.dims[0];
        let l = Tensor::zeros([n, n], a.dtype, a.device);
        for (i in range(n)) {
            for (j in range(i + 1)) {
                let s = 0.0;
                for (k in range(j)) {
                    s = s + l.get([i, k]) * l.get([j, k]);
                }
                if (i == j) {
                    let val = a.get([i, i]) - s;
                    if (val <= 0.0) {
                        throw "cholesky: matrix is not positive definite";
                    }
                    l.set([i, j], native_sqrt(val));
                } else {
                    l.set([i, j], (a.get([i, j]) - s) / l.get([j, j]));
                }
            }
        }
        return l;
    }

    pub fn cross(a: Tensor, b: Tensor) -> Tensor {
        if (a.numel() != 3 || b.numel() != 3) {
            throw "cross: requires 3-element vectors";
        }
        let data = [
            a.data[1] * b.data[2] - a.data[2] * b.data[1],
            a.data[2] * b.data[0] - a.data[0] * b.data[2],
            a.data[0] * b.data[1] - a.data[1] * b.data[0]
        ];
        return Tensor::new(data, [3], a.dtype, a.device);
    }
}

# ============================================================
# SECTION 7: SIMD VECTORIZATION
# ============================================================

pub mod simd {
    pub let backend: SIMDBackend = SIMDBackend::Auto;

    pub fn detect_backend() -> SIMDBackend {
        if (native_has_avx512()) { return SIMDBackend::AVX512; }
        if (native_has_avx2()) { return SIMDBackend::AVX2; }
        if (native_has_neon()) { return SIMDBackend::NEON; }
        return SIMDBackend::None;
    }

    pub fn vector_add(a: [Float], b: [Float]) -> [Float] {
        let be = detect_backend();
        match be {
            SIMDBackend::AVX512 => return native_avx512_add(a, b),
            SIMDBackend::AVX2 => return native_avx2_add(a, b),
            SIMDBackend::NEON => return native_neon_add(a, b),
            _ => {
                let result = [];
                for (i in range(len(a))) {
                    result = result + [a[i] + b[i]];
                }
                return result;
            }
        };
    }

    pub fn vector_mul(a: [Float], b: [Float]) -> [Float] {
        let be = detect_backend();
        match be {
            SIMDBackend::AVX512 => return native_avx512_mul(a, b),
            SIMDBackend::AVX2 => return native_avx2_mul(a, b),
            SIMDBackend::NEON => return native_neon_mul(a, b),
            _ => {
                let result = [];
                for (i in range(len(a))) {
                    result = result + [a[i] * b[i]];
                }
                return result;
            }
        };
    }

    pub fn vector_fma(a: [Float], b: [Float], c: [Float]) -> [Float] {
        let be = detect_backend();
        match be {
            SIMDBackend::AVX512 => return native_avx512_fma(a, b, c),
            SIMDBackend::AVX2 => return native_avx2_fma(a, b, c),
            _ => {
                let result = [];
                for (i in range(len(a))) {
                    result = result + [a[i] * b[i] + c[i]];
                }
                return result;
            }
        };
    }

    pub fn vector_dot(a: [Float], b: [Float]) -> Float {
        let be = detect_backend();
        match be {
            SIMDBackend::AVX512 => return native_avx512_dot(a, b),
            SIMDBackend::AVX2 => return native_avx2_dot(a, b),
            _ => {
                let s = 0.0;
                for (i in range(len(a))) {
                    s = s + a[i] * b[i];
                }
                return s;
            }
        };
    }
}

# ============================================================
# SECTION 8: MIXED PRECISION
# ============================================================

pub mod mixed_precision {

    pub class MixedPrecisionContext {
        pub let compute_dtype: DType;
        pub let storage_dtype: DType;
        pub let loss_scale: Float;
        pub let dynamic_scaling: Bool;

        pub fn new(compute_dtype: DType, storage_dtype: DType) -> Self {
            return Self {
                compute_dtype: compute_dtype,
                storage_dtype: storage_dtype,
                loss_scale: 65536.0,
                dynamic_scaling: true
            };
        }

        pub fn cast_forward(self, tensor: Tensor) -> Tensor {
            return tensor.to_dtype(self.compute_dtype);
        }

        pub fn cast_backward(self, grad: Tensor) -> Tensor {
            return grad.to_dtype(self.storage_dtype);
        }

        pub fn scale_loss(self, loss: Float) -> Float {
            return loss * self.loss_scale;
        }

        pub fn unscale_grad(self, grad: Tensor) -> Tensor {
            return grad.scale(1.0 / self.loss_scale);
        }

        pub fn update_scale(self, overflow: Bool) {
            if (overflow) {
                self.loss_scale = self.loss_scale / 2.0;
            } else {
                self.loss_scale = self.loss_scale * 2.0;
                if (self.loss_scale > 65536.0) {
                    self.loss_scale = 65536.0;
                }
            }
        }
    }

    pub fn fp16_context() -> MixedPrecisionContext {
        return MixedPrecisionContext::new(DType::Float16, DType::Float32);
    }

    pub fn bf16_context() -> MixedPrecisionContext {
        return MixedPrecisionContext::new(DType::BFloat16, DType::Float32);
    }
}

# ============================================================
# SECTION 9: SPARSE TENSORS
# ============================================================

pub class SparseTensor {
    pub let format: SparseFormat;
    pub let shape: Shape;
    pub let values: [Float];
    pub let row_indices: [Int];
    pub let col_indices: [Int];
    pub let nnz: Int;
    pub let dtype: DType;
    pub let device: Device;

    pub fn from_coo(rows: [Int], cols: [Int], values: [Float], shape: [Int], dtype: DType) -> Self {
        return Self {
            format: SparseFormat::COO,
            shape: Shape::new(shape),
            values: values,
            row_indices: rows,
            col_indices: cols,
            nnz: len(values),
            dtype: dtype,
            device: Device::CPU
        };
    }

    pub fn from_dense(tensor: Tensor, threshold: Float) -> SparseTensor {
        if (tensor.ndim() != 2) {
            throw "SparseTensor::from_dense: requires 2D tensor";
        }
        let rows = [];
        let cols = [];
        let vals = [];
        let m = tensor.shape.dims[0];
        let n = tensor.shape.dims[1];
        for (i in range(m)) {
            for (j in range(n)) {
                let v = tensor.get([i, j]);
                if (native_abs(v) > threshold) {
                    rows = rows + [i];
                    cols = cols + [j];
                    vals = vals + [v];
                }
            }
        }
        return SparseTensor::from_coo(rows, cols, vals, tensor.shape.dims, tensor.dtype);
    }

    pub fn to_dense(self) -> Tensor {
        let result = Tensor::zeros(self.shape.dims, self.dtype, self.device);
        for (i in range(self.nnz)) {
            result.set([self.row_indices[i], self.col_indices[i]], self.values[i]);
        }
        return result;
    }

    pub fn spmv(self, x: Tensor) -> Tensor {
        let m = self.shape.dims[0];
        let result = Tensor::zeros([m], self.dtype, self.device);
        for (i in range(self.nnz)) {
            let row = self.row_indices[i];
            let col = self.col_indices[i];
            let cur = result.data[row];
            result.data[row] = cur + self.values[i] * x.data[col];
        }
        return result;
    }

    pub fn spmm(self, b: Tensor) -> Tensor {
        let m = self.shape.dims[0];
        let n = b.shape.dims[1];
        let result = Tensor::zeros([m, n], self.dtype, self.device);
        for (i in range(self.nnz)) {
            let row = self.row_indices[i];
            let col = self.col_indices[i];
            for (j in range(n)) {
                let cur = result.get([row, j]);
                result.set([row, j], cur + self.values[i] * b.get([col, j]));
            }
        }
        return result;
    }

    pub fn density(self) -> Float {
        return self.nnz / self.shape.numel();
    }

    pub fn to_string(self) -> String {
        return "SparseTensor(shape=" + self.shape.to_string() + ", nnz=" + str(self.nnz) +
               ", format=" + str(self.format) + ", density=" + str(self.density()) + ")";
    }
}

# ============================================================
# SECTION 10: KERNEL FUSION OPTIMIZATION
# ============================================================

pub mod kernel_fusion {

    pub enum FusedOp {
        AddMul,
        MulAdd,
        ScaleAdd,
        BiasRelu,
        MatmulBias,
        SoftmaxCrossEntropy,
        LayerNormResidual,
        GeluLinear
    }

    pub class FusionPass {
        pub let enabled: Bool;
        pub let ops: [FusedOp];

        pub fn new() -> Self {
            return Self { enabled: true, ops: [] };
        }

        pub fn fused_add_mul(a: Tensor, b: Tensor, c: Tensor) -> Tensor {
            let data = [];
            for (i in range(a.numel())) {
                data = data + [(a.data[i] + b.data[i]) * c.data[i]];
            }
            return Tensor::new(data, a.shape.dims, a.dtype, a.device);
        }

        pub fn fused_mul_add(a: Tensor, b: Tensor, c: Tensor) -> Tensor {
            let data = [];
            for (i in range(a.numel())) {
                data = data + [a.data[i] * b.data[i] + c.data[i]];
            }
            return Tensor::new(data, a.shape.dims, a.dtype, a.device);
        }

        pub fn fused_bias_relu(x: Tensor, bias: Tensor) -> Tensor {
            let data = [];
            for (i in range(x.numel())) {
                let v = x.data[i] + bias.data[i % bias.numel()];
                data = data + [v > 0.0 ? v : 0.0];
            }
            return Tensor::new(data, x.shape.dims, x.dtype, x.device);
        }

        pub fn fused_matmul_bias(a: Tensor, b: Tensor, bias: Tensor) -> Tensor {
            let result = linalg::matmul(a, b);
            let data = [];
            for (i in range(result.numel())) {
                data = data + [result.data[i] + bias.data[i % bias.numel()]];
            }
            return Tensor::new(data, result.shape.dims, result.dtype, result.device);
        }

        pub fn fused_layer_norm_residual(x: Tensor, residual: Tensor, gamma: Tensor, beta: Tensor, eps: Float) -> Tensor {
            let added = x.add(residual);
            let m = added.mean();
            let v = added.var();
            let data = [];
            for (i in range(added.numel())) {
                let normalized = (added.data[i] - m) / native_sqrt(v + eps);
                data = data + [normalized * gamma.data[i % gamma.numel()] + beta.data[i % beta.numel()]];
            }
            return Tensor::new(data, added.shape.dims, added.dtype, added.device);
        }

        pub fn fused_gelu_linear(x: Tensor, weight: Tensor, bias: Tensor) -> Tensor {
            let linear = linalg::matmul(x, weight);
            let data = [];
            for (i in range(linear.numel())) {
                let v = linear.data[i] + bias.data[i % bias.numel()];
                let gelu = 0.5 * v * (1.0 + native_tanh(0.7978845608 * (v + 0.044715 * v * v * v)));
                data = data + [gelu];
            }
            return Tensor::new(data, linear.shape.dims, linear.dtype, linear.device);
        }
    }
}

# ============================================================
# SECTION 11: RANDOM NUMBER GENERATION
# ============================================================

pub mod random {
    pub let _seed: Int = 42;

    pub fn seed(s: Int) {
        _seed = s;
        native_srand(s);
    }

    pub fn uniform(shape: [Int], low: Float, high: Float, dtype: DType, device: Device) -> Tensor {
        let n = 1;
        for (d in shape) { n = n * d; }
        let data = [];
        for (i in range(n)) {
            data = data + [low + native_random_float() * (high - low)];
        }
        return Tensor::new(data, shape, dtype, device);
    }

    pub fn normal(shape: [Int], mean: Float, std: Float, dtype: DType, device: Device) -> Tensor {
        let n = 1;
        for (d in shape) { n = n * d; }
        let data = [];
        for (i in range(n)) {
            data = data + [native_random_normal(mean, std)];
        }
        return Tensor::new(data, shape, dtype, device);
    }

    pub fn bernoulli(shape: [Int], p: Float, dtype: DType, device: Device) -> Tensor {
        let n = 1;
        for (d in shape) { n = n * d; }
        let data = [];
        for (i in range(n)) {
            data = data + [native_random_float() < p ? 1.0 : 0.0];
        }
        return Tensor::new(data, shape, dtype, device);
    }

    pub fn multinomial(probs: Tensor, num_samples: Int) -> Tensor {
        let data = [];
        for (s in range(num_samples)) {
            let r = native_random_float();
            let cumsum = 0.0;
            for (i in range(probs.numel())) {
                cumsum = cumsum + probs.data[i];
                if (r < cumsum) {
                    data = data + [i * 1.0];
                    break;
                }
            }
        }
        return Tensor::new(data, [num_samples], DType::Int64, probs.device);
    }

    pub fn shuffle(tensor: Tensor) -> Tensor {
        let data = tensor.data;
        for (i in range(len(data) - 1, 0, -1)) {
            let j = native_random_int(0, i);
            let tmp = data[i];
            data[i] = data[j];
            data[j] = tmp;
        }
        return Tensor::new(data, tensor.shape.dims, tensor.dtype, tensor.device);
    }
}

# ============================================================
# SECTION 12: UTILITY FUNCTIONS
# ============================================================

fn _unravel(flat: Int, shape: [Int]) -> [Int] {
    let idx = [];
    for (i in range(len(shape))) { idx = idx + [0]; }
    let remaining = flat;
    for (i in range(len(shape) - 1, -1, -1)) {
        idx[i] = remaining % shape[i];
        remaining = remaining / shape[i];
    }
    return idx;
}

fn _lu_decompose(a: Tensor) -> Tensor {
    let n = a.shape.dims[0];
    let lu = Tensor::new(a.data, a.shape.dims, a.dtype, a.device);
    for (k in range(n)) {
        for (i in range(k + 1, n)) {
            lu.set([i, k], lu.get([i, k]) / lu.get([k, k]));
            for (j in range(k + 1, n)) {
                lu.set([i, j], lu.get([i, j]) - lu.get([i, k]) * lu.get([k, j]));
            }
        }
    }
    lu._sign = 1.0;
    return lu;
}

# ============================================================
# SECTION 13: NATIVE FFI DECLARATIONS
# ============================================================

native_malloc(size: Int) -> Int;
native_free(ptr: Int);
native_cuda_malloc(size: Int) -> Int;
native_cuda_free(ptr: Int);
native_rocm_malloc(size: Int) -> Int;
native_rocm_free(ptr: Int);
native_metal_malloc(size: Int) -> Int;
native_metal_free(ptr: Int);
native_pow(base: Float, exp: Float) -> Float;
native_sqrt(x: Float) -> Float;
native_exp(x: Float) -> Float;
native_log(x: Float) -> Float;
native_sin(x: Float) -> Float;
native_cos(x: Float) -> Float;
native_tanh(x: Float) -> Float;
native_abs(x: Float) -> Float;
native_random_float() -> Float;
native_random_normal(mean: Float, std: Float) -> Float;
native_random_int(low: Int, high: Int) -> Int;
native_srand(seed: Int);
native_has_avx2() -> Bool;
native_has_avx512() -> Bool;
native_has_neon() -> Bool;
native_avx2_add(a: [Float], b: [Float]) -> [Float];
native_avx512_add(a: [Float], b: [Float]) -> [Float];
native_neon_add(a: [Float], b: [Float]) -> [Float];
native_avx2_mul(a: [Float], b: [Float]) -> [Float];
native_avx512_mul(a: [Float], b: [Float]) -> [Float];
native_neon_mul(a: [Float], b: [Float]) -> [Float];
native_avx2_fma(a: [Float], b: [Float], c: [Float]) -> [Float];
native_avx512_fma(a: [Float], b: [Float], c: [Float]) -> [Float];
native_avx2_dot(a: [Float], b: [Float]) -> Float;
native_avx512_dot(a: [Float], b: [Float]) -> Float;
native_tensor_to_cuda(data: [Float]) -> [Float];
native_tensor_to_rocm(data: [Float]) -> [Float];
native_tensor_to_cpu(data: [Float]) -> [Float];
native_tensor_to_metal(data: [Float]) -> [Float];

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    "Tensor": Tensor,
    "SparseTensor": SparseTensor,
    "Shape": Shape,
    "DType": DType,
    "Device": Device,
    "SparseFormat": SparseFormat,
    "SIMDBackend": SIMDBackend,
    "MemoryLayout": MemoryLayout,
    "MemoryPool": MemoryPool,
    "ArenaAllocator": ArenaAllocator,
    "linalg": linalg,
    "simd": simd,
    "mixed_precision": mixed_precision,
    "kernel_fusion": kernel_fusion,
    "random": random,
    "broadcast": broadcast,
    "broadcast_shapes": broadcast_shapes
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
