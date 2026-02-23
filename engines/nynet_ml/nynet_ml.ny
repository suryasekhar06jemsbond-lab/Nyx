# ============================================================
# NyNet ML - Neural Architecture Engine
# Version 1.0.0
# Defines how models are built: layers, blocks, and graphs
# ============================================================

use nytensor;
use nygrad;

# ============================================================
# SECTION 1: PARAMETER MANAGEMENT
# ============================================================

pub class Parameter {
    pub let name: String;
    pub let data: Variable;
    pub let requires_grad: Bool;
    pub let _frozen: Bool;

    pub fn new(name: String, shape: [Int], init: String) -> Self {
        let t = null;
        switch (init) {
            case "zeros":   { t = Tensor::zeros(shape, DType::Float32, Device::CPU); }
            case "ones":    { t = Tensor::ones(shape, DType::Float32, Device::CPU); }
            case "xavier":  { t = _xavier_init(shape); }
            case "kaiming": { t = _kaiming_init(shape); }
            case "normal":  { t = Tensor::randn(shape, DType::Float32, Device::CPU); }
            case "uniform": { t = Tensor::rand(shape, DType::Float32, Device::CPU); }
            default:        { t = Tensor::randn(shape, DType::Float32, Device::CPU); }
        }
        let v = Variable::new(t.with_grad(), name);
        return Self { name: name, data: v, requires_grad: true, _frozen: false };
    }

    pub fn freeze(self) { self._frozen = true; }
    pub fn unfreeze(self) { self._frozen = false; }
}

fn _xavier_init(shape: [Int]) -> Tensor {
    let fan_in = shape[len(shape) - 1];
    let fan_out = shape[0];
    let std = (2.0 / (fan_in + fan_out)).sqrt();
    return Tensor::randn(shape, DType::Float32, Device::CPU).scale(std);
}

fn _kaiming_init(shape: [Int]) -> Tensor {
    let fan_in = shape[len(shape) - 1];
    let std = (2.0 / fan_in).sqrt();
    return Tensor::randn(shape, DType::Float32, Device::CPU).scale(std);
}

# ============================================================
# SECTION 2: BASE MODULE (ALL LAYERS INHERIT THIS)
# ============================================================

pub class Module {
    pub let _params: [Parameter];
    pub let _children: [Module];
    pub let _training: Bool;
    pub let _name: String;

    pub fn new(name: String) -> Self {
        return Self { _params: [], _children: [], _training: true, _name: name };
    }

    pub fn forward(self, x: Variable) -> Variable {
        throw "Module::forward() must be overridden";
    }

    pub fn parameters(self) -> [Parameter] {
        let all_params = self._params;
        for (child in self._children) {
            for (p in child.parameters()) {
                all_params = all_params + [p];
            }
        }
        return all_params;
    }

    pub fn train(self) {
        self._training = true;
        for (child in self._children) { child.train(); }
    }

    pub fn eval(self) {
        self._training = false;
        for (child in self._children) { child.eval(); }
    }

    pub fn zero_grad(self) {
        for (p in self.parameters()) {
            p.data.zero_grad();
        }
    }

    pub fn num_parameters(self) -> Int {
        let total = 0;
        for (p in self.parameters()) {
            total = total + p.data.data.numel();
        }
        return total;
    }

    pub fn add_param(self, param: Parameter) {
        self._params = self._params + [param];
    }

    pub fn add_child(self, child: Module) {
        self._children = self._children + [child];
    }

    pub fn freeze(self) {
        for (p in self._params) { p.freeze(); }
        for (c in self._children) { c.freeze(); }
    }

    pub fn unfreeze(self) {
        for (p in self._params) { p.unfreeze(); }
        for (c in self._children) { c.unfreeze(); }
    }
}

# ============================================================
# SECTION 3: DENSE (LINEAR / FULLY CONNECTED) LAYER
# ============================================================

pub class Linear : Module {
    pub let in_features: Int;
    pub let out_features: Int;
    pub let weight: Parameter;
    pub let bias: Parameter?;

    pub fn new(in_features: Int, out_features: Int, use_bias: Bool) -> Self {
        let m = Module::new("Linear");
        let w = Parameter::new("weight", [out_features, in_features], "kaiming");
        m.add_param(w);
        let b = null;
        if (use_bias) {
            b = Parameter::new("bias", [out_features], "zeros");
            m.add_param(b);
        }
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "Linear(" + str(in_features) + "," + str(out_features) + ")",
            in_features: in_features, out_features: out_features,
            weight: w, bias: b
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        let out = x.matmul(self.weight.data);
        if (self.bias != null) {
            out = out.add(self.bias.data);
        }
        return out;
    }
}

# ============================================================
# SECTION 4: CONVOLUTIONAL LAYERS
# ============================================================

pub class Conv2d : Module {
    pub let in_channels: Int;
    pub let out_channels: Int;
    pub let kernel_size: Int;
    pub let stride: Int;
    pub let padding: Int;
    pub let weight: Parameter;
    pub let bias: Parameter?;

    pub fn new(in_channels: Int, out_channels: Int, kernel_size: Int,
               stride: Int, padding: Int, use_bias: Bool) -> Self {
        let m = Module::new("Conv2d");
        let w = Parameter::new("weight",
            [out_channels, in_channels, kernel_size, kernel_size], "kaiming");
        m.add_param(w);
        let b = null;
        if (use_bias) {
            b = Parameter::new("bias", [out_channels], "zeros");
            m.add_param(b);
        }
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "Conv2d(" + str(in_channels) + "," + str(out_channels) + ",k=" + str(kernel_size) + ")",
            in_channels: in_channels, out_channels: out_channels,
            kernel_size: kernel_size, stride: stride, padding: padding,
            weight: w, bias: b
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        let batch = x.shape()[0];
        let h_in = x.shape()[2];
        let w_in = x.shape()[3];
        let h_out = (h_in + 2 * self.padding - self.kernel_size) / self.stride + 1;
        let w_out = (w_in + 2 * self.padding - self.kernel_size) / self.stride + 1;

        # im2col + matmul approach
        let col = _im2col(x, self.kernel_size, self.stride, self.padding);
        let w_reshaped = self.weight.data;  # [out_ch, in_ch*k*k]
        let out = col.matmul(w_reshaped);
        if (self.bias != null) {
            out = out.add(self.bias.data);
        }
        return out;
    }
}

fn _im2col(x: Variable, k: Int, s: Int, p: Int) -> Variable {
    # Placeholder: unfold input into column matrix for efficient convolution
    return x;
}

pub class Conv1d : Module {
    pub let in_channels: Int;
    pub let out_channels: Int;
    pub let kernel_size: Int;
    pub let stride: Int;
    pub let padding: Int;
    pub let weight: Parameter;
    pub let bias: Parameter?;

    pub fn new(in_channels: Int, out_channels: Int, kernel_size: Int,
               stride: Int, padding: Int, use_bias: Bool) -> Self {
        let m = Module::new("Conv1d");
        let w = Parameter::new("weight", [out_channels, in_channels, kernel_size], "kaiming");
        m.add_param(w);
        let b = null;
        if (use_bias) {
            b = Parameter::new("bias", [out_channels], "zeros");
            m.add_param(b);
        }
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "Conv1d(" + str(in_channels) + "," + str(out_channels) + ")",
            in_channels: in_channels, out_channels: out_channels,
            kernel_size: kernel_size, stride: stride, padding: padding,
            weight: w, bias: b
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        let col = x;  # 1D unfold
        let out = col.matmul(self.weight.data);
        if (self.bias != null) { out = out.add(self.bias.data); }
        return out;
    }
}

# ============================================================
# SECTION 5: RECURRENT LAYERS (RNN, LSTM, GRU)
# ============================================================

pub class RNNCell : Module {
    pub let input_size: Int;
    pub let hidden_size: Int;
    pub let weight_ih: Parameter;
    pub let weight_hh: Parameter;
    pub let bias: Parameter;

    pub fn new(input_size: Int, hidden_size: Int) -> Self {
        let m = Module::new("RNNCell");
        let wih = Parameter::new("weight_ih", [hidden_size, input_size], "xavier");
        let whh = Parameter::new("weight_hh", [hidden_size, hidden_size], "xavier");
        let b = Parameter::new("bias", [hidden_size], "zeros");
        m.add_param(wih); m.add_param(whh); m.add_param(b);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "RNNCell", input_size: input_size, hidden_size: hidden_size,
            weight_ih: wih, weight_hh: whh, bias: b
        };
    }

    pub fn forward(self, x: Variable, h: Variable) -> Variable {
        let ih = x.matmul(self.weight_ih.data);
        let hh = h.matmul(self.weight_hh.data);
        let out = ih.add(hh).add(self.bias.data).tanh_act();
        return out;
    }
}

pub class LSTMCell : Module {
    pub let input_size: Int;
    pub let hidden_size: Int;
    pub let weight_ih: Parameter;
    pub let weight_hh: Parameter;
    pub let bias: Parameter;

    pub fn new(input_size: Int, hidden_size: Int) -> Self {
        let m = Module::new("LSTMCell");
        let wih = Parameter::new("weight_ih", [4 * hidden_size, input_size], "xavier");
        let whh = Parameter::new("weight_hh", [4 * hidden_size, hidden_size], "xavier");
        let b = Parameter::new("bias", [4 * hidden_size], "zeros");
        m.add_param(wih); m.add_param(whh); m.add_param(b);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "LSTMCell", input_size: input_size, hidden_size: hidden_size,
            weight_ih: wih, weight_hh: whh, bias: b
        };
    }

    pub fn forward(self, x: Variable, h: Variable, c: Variable) -> [Variable] {
        let gates = x.matmul(self.weight_ih.data).add(h.matmul(self.weight_hh.data)).add(self.bias.data);
        # Split into 4 gates: input, forget, cell, output
        let chunk = self.hidden_size;
        let i_gate = _slice_var(gates, 0, chunk).sigmoid();
        let f_gate = _slice_var(gates, chunk, 2 * chunk).sigmoid();
        let g_gate = _slice_var(gates, 2 * chunk, 3 * chunk).tanh_act();
        let o_gate = _slice_var(gates, 3 * chunk, 4 * chunk).sigmoid();

        let c_new = f_gate.mul(c).add(i_gate.mul(g_gate));
        let h_new = o_gate.mul(c_new.tanh_act());
        return [h_new, c_new];
    }
}

pub class GRUCell : Module {
    pub let input_size: Int;
    pub let hidden_size: Int;
    pub let weight_ih: Parameter;
    pub let weight_hh: Parameter;
    pub let bias: Parameter;

    pub fn new(input_size: Int, hidden_size: Int) -> Self {
        let m = Module::new("GRUCell");
        let wih = Parameter::new("weight_ih", [3 * hidden_size, input_size], "xavier");
        let whh = Parameter::new("weight_hh", [3 * hidden_size, hidden_size], "xavier");
        let b = Parameter::new("bias", [3 * hidden_size], "zeros");
        m.add_param(wih); m.add_param(whh); m.add_param(b);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "GRUCell", input_size: input_size, hidden_size: hidden_size,
            weight_ih: wih, weight_hh: whh, bias: b
        };
    }

    pub fn forward(self, x: Variable, h: Variable) -> Variable {
        let ih = x.matmul(self.weight_ih.data).add(self.bias.data);
        let hh = h.matmul(self.weight_hh.data);
        let chunk = self.hidden_size;
        let r = _slice_var(ih, 0, chunk).add(_slice_var(hh, 0, chunk)).sigmoid();
        let z = _slice_var(ih, chunk, 2 * chunk).add(_slice_var(hh, chunk, 2 * chunk)).sigmoid();
        let n = _slice_var(ih, 2 * chunk, 3 * chunk).add(r.mul(_slice_var(hh, 2 * chunk, 3 * chunk))).tanh_act();
        let one = Variable::new(Tensor::ones(z.shape(), DType::Float32, Device::CPU), "one");
        let h_new = one.sub(z).mul(n).add(z.mul(h));
        return h_new;
    }
}

fn _slice_var(v: Variable, start: Int, end: Int) -> Variable {
    # Slice along last dimension
    let data = [];
    for (i in range(start, end)) {
        data = data + [v.data.data[i]];
    }
    let t = Tensor::new(data, [end - start], v.data.dtype, v.data.device);
    return Variable::new(t, "slice");
}

# ============================================================
# SECTION 6: TRANSFORMER BLOCKS
# ============================================================

pub class MultiHeadAttention : Module {
    pub let embed_dim: Int;
    pub let num_heads: Int;
    pub let head_dim: Int;
    pub let w_q: Linear;
    pub let w_k: Linear;
    pub let w_v: Linear;
    pub let w_out: Linear;
    pub let _scale: Float;

    pub fn new(embed_dim: Int, num_heads: Int) -> Self {
        let head_dim = embed_dim / num_heads;
        let m = Module::new("MultiHeadAttention");
        let wq = Linear::new(embed_dim, embed_dim, true);
        let wk = Linear::new(embed_dim, embed_dim, true);
        let wv = Linear::new(embed_dim, embed_dim, true);
        let wo = Linear::new(embed_dim, embed_dim, true);
        m.add_child(wq); m.add_child(wk); m.add_child(wv); m.add_child(wo);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "MultiHeadAttention",
            embed_dim: embed_dim, num_heads: num_heads, head_dim: head_dim,
            w_q: wq, w_k: wk, w_v: wv, w_out: wo,
            _scale: (head_dim * 1.0).sqrt()
        };
    }

    pub fn forward(self, query: Variable, key: Variable, value: Variable, mask: Variable?) -> Variable {
        let q = self.w_q.forward(query);
        let k = self.w_k.forward(key);
        let v = self.w_v.forward(value);

        # Scaled dot-product attention: softmax(QK^T / sqrt(d)) V
        let scores = q.matmul(k).div(
            Variable::new(Tensor::full([1], self._scale, DType::Float32, Device::CPU), "scale")
        );
        if (mask != null) {
            # Apply mask: set masked positions to -inf before softmax
            scores = scores.add(mask);
        }
        let attn_weights = scores.softmax();
        let context = attn_weights.matmul(v);
        return self.w_out.forward(context);
    }
}

pub class TransformerEncoderLayer : Module {
    pub let self_attn: MultiHeadAttention;
    pub let ff1: Linear;
    pub let ff2: Linear;
    pub let norm1: LayerNorm;
    pub let norm2: LayerNorm;
    pub let dropout_rate: Float;

    pub fn new(d_model: Int, n_heads: Int, d_ff: Int, dropout: Float) -> Self {
        let m = Module::new("TransformerEncoderLayer");
        let attn = MultiHeadAttention::new(d_model, n_heads);
        let f1 = Linear::new(d_model, d_ff, true);
        let f2 = Linear::new(d_ff, d_model, true);
        let ln1 = LayerNorm::new(d_model);
        let ln2 = LayerNorm::new(d_model);
        m.add_child(attn); m.add_child(f1); m.add_child(f2);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "TransformerEncoderLayer",
            self_attn: attn, ff1: f1, ff2: f2,
            norm1: ln1, norm2: ln2, dropout_rate: dropout
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        # Self-attention + residual + layer norm
        let attn_out = self.self_attn.forward(x, x, x, null);
        let x1 = self.norm1.forward(x.add(attn_out));
        # Feed-forward + residual + layer norm
        let ff_out = self.ff2.forward(self.ff1.forward(x1).relu());
        let x2 = self.norm2.forward(x1.add(ff_out));
        return x2;
    }
}

pub class TransformerDecoderLayer : Module {
    pub let self_attn: MultiHeadAttention;
    pub let cross_attn: MultiHeadAttention;
    pub let ff1: Linear;
    pub let ff2: Linear;
    pub let norm1: LayerNorm;
    pub let norm2: LayerNorm;
    pub let norm3: LayerNorm;

    pub fn new(d_model: Int, n_heads: Int, d_ff: Int, dropout: Float) -> Self {
        let m = Module::new("TransformerDecoderLayer");
        let sa = MultiHeadAttention::new(d_model, n_heads);
        let ca = MultiHeadAttention::new(d_model, n_heads);
        let f1 = Linear::new(d_model, d_ff, true);
        let f2 = Linear::new(d_ff, d_model, true);
        let ln1 = LayerNorm::new(d_model);
        let ln2 = LayerNorm::new(d_model);
        let ln3 = LayerNorm::new(d_model);
        m.add_child(sa); m.add_child(ca); m.add_child(f1); m.add_child(f2);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "TransformerDecoderLayer",
            self_attn: sa, cross_attn: ca, ff1: f1, ff2: f2,
            norm1: ln1, norm2: ln2, norm3: ln3
        };
    }

    pub fn forward(self, x: Variable, memory: Variable, tgt_mask: Variable?) -> Variable {
        let sa_out = self.self_attn.forward(x, x, x, tgt_mask);
        let x1 = self.norm1.forward(x.add(sa_out));
        let ca_out = self.cross_attn.forward(x1, memory, memory, null);
        let x2 = self.norm2.forward(x1.add(ca_out));
        let ff_out = self.ff2.forward(self.ff1.forward(x2).relu());
        let x3 = self.norm3.forward(x2.add(ff_out));
        return x3;
    }
}

# ============================================================
# SECTION 7: NORMALIZATION LAYERS
# ============================================================

pub class LayerNorm : Module {
    pub let normalized_shape: Int;
    pub let gamma: Parameter;
    pub let beta: Parameter;
    pub let eps: Float;

    pub fn new(dim: Int) -> Self {
        let m = Module::new("LayerNorm");
        let g = Parameter::new("gamma", [dim], "ones");
        let b = Parameter::new("beta", [dim], "zeros");
        m.add_param(g); m.add_param(b);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "LayerNorm", normalized_shape: dim,
            gamma: g, beta: b, eps: 1e-5
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        let mean_val = x.mean();
        let centered = x.sub(mean_val);
        let var_val = centered.mul(centered).mean();
        let eps_t = Variable::new(Tensor::full([1], self.eps, DType::Float32, Device::CPU), "eps");
        let std = var_val.add(eps_t).sqrt();
        let normalized = centered.div(std);
        let out = normalized.mul(self.gamma.data).add(self.beta.data);
        return out;
    }
}

pub class BatchNorm : Module {
    pub let num_features: Int;
    pub let gamma: Parameter;
    pub let beta: Parameter;
    pub let running_mean: Tensor;
    pub let running_var: Tensor;
    pub let eps: Float;
    pub let momentum: Float;

    pub fn new(num_features: Int) -> Self {
        let m = Module::new("BatchNorm");
        let g = Parameter::new("gamma", [num_features], "ones");
        let b = Parameter::new("beta", [num_features], "zeros");
        m.add_param(g); m.add_param(b);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "BatchNorm", num_features: num_features,
            gamma: g, beta: b,
            running_mean: Tensor::zeros([num_features], DType::Float32, Device::CPU),
            running_var: Tensor::ones([num_features], DType::Float32, Device::CPU),
            eps: 1e-5, momentum: 0.1
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        if (self._training) {
            let mean_val = x.mean();
            let centered = x.sub(mean_val);
            let var_val = centered.mul(centered).mean();
            let eps_t = Variable::new(Tensor::full([1], self.eps, DType::Float32, Device::CPU), "eps");
            let normalized = centered.div(var_val.add(eps_t).sqrt());
            return normalized.mul(self.gamma.data).add(self.beta.data);
        } else {
            let rm = Variable::new(self.running_mean, "rm");
            let rv = Variable::new(self.running_var, "rv");
            let eps_t = Variable::new(Tensor::full([1], self.eps, DType::Float32, Device::CPU), "eps");
            let normalized = x.sub(rm).div(rv.add(eps_t).sqrt());
            return normalized.mul(self.gamma.data).add(self.beta.data);
        }
    }
}

# ============================================================
# SECTION 8: EMBEDDING LAYER
# ============================================================

pub class Embedding : Module {
    pub let num_embeddings: Int;
    pub let embedding_dim: Int;
    pub let weight: Parameter;

    pub fn new(num_embeddings: Int, embedding_dim: Int) -> Self {
        let m = Module::new("Embedding");
        let w = Parameter::new("weight", [num_embeddings, embedding_dim], "normal");
        m.add_param(w);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "Embedding(" + str(num_embeddings) + "," + str(embedding_dim) + ")",
            num_embeddings: num_embeddings, embedding_dim: embedding_dim, weight: w
        };
    }

    pub fn forward(self, indices: Variable) -> Variable {
        # Lookup embeddings by indices
        let rows = [];
        for (idx in indices.data.data) {
            let row_start = int(idx) * self.embedding_dim;
            for (j in range(self.embedding_dim)) {
                rows = rows + [self.weight.data.data.data[row_start + j]];
            }
        }
        let n = len(indices.data.data);
        let t = Tensor::new(rows, [n, self.embedding_dim], DType::Float32, Device::CPU);
        return Variable::new(t, "embed_out");
    }
}

# ============================================================
# SECTION 9: POOLING LAYERS
# ============================================================

pub class MaxPool2d : Module {
    pub let kernel_size: Int;
    pub let stride: Int;

    pub fn new(kernel_size: Int, stride: Int) -> Self {
        return Self {
            _params: [], _children: [], _training: true,
            _name: "MaxPool2d", kernel_size: kernel_size, stride: stride
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        # Placeholder: apply max pooling with kernel_size and stride
        return x;
    }
}

pub class AvgPool2d : Module {
    pub let kernel_size: Int;
    pub let stride: Int;

    pub fn new(kernel_size: Int, stride: Int) -> Self {
        return Self {
            _params: [], _children: [], _training: true,
            _name: "AvgPool2d", kernel_size: kernel_size, stride: stride
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        return x.mean();
    }
}

pub class GlobalAvgPool : Module {
    pub fn new() -> Self {
        return Self { _params: [], _children: [], _training: true, _name: "GlobalAvgPool" };
    }

    pub fn forward(self, x: Variable) -> Variable {
        return x.mean();
    }
}

# ============================================================
# SECTION 10: ACTIVATION MODULES
# ============================================================

pub class ReLU : Module {
    pub fn new() -> Self { return Self { _params: [], _children: [], _training: true, _name: "ReLU" }; }
    pub fn forward(self, x: Variable) -> Variable { return x.relu(); }
}

pub class Sigmoid : Module {
    pub fn new() -> Self { return Self { _params: [], _children: [], _training: true, _name: "Sigmoid" }; }
    pub fn forward(self, x: Variable) -> Variable { return x.sigmoid(); }
}

pub class Tanh : Module {
    pub fn new() -> Self { return Self { _params: [], _children: [], _training: true, _name: "Tanh" }; }
    pub fn forward(self, x: Variable) -> Variable { return x.tanh_act(); }
}

pub class Softmax : Module {
    pub fn new() -> Self { return Self { _params: [], _children: [], _training: true, _name: "Softmax" }; }
    pub fn forward(self, x: Variable) -> Variable { return x.softmax(); }
}

pub class LeakyReLU : Module {
    pub let alpha: Float;
    pub fn new(alpha: Float) -> Self {
        return Self { _params: [], _children: [], _training: true, _name: "LeakyReLU", alpha: alpha };
    }
    pub fn forward(self, x: Variable) -> Variable {
        # leaky_relu: max(alpha*x, x)
        let data = [];
        for (v in x.data.data) {
            data = data + [v > 0.0 ? v : v * self.alpha];
        }
        let t = Tensor::new(data, x.shape(), x.data.dtype, x.data.device);
        return Variable::new(t, "leaky_relu");
    }
}

pub class GELU : Module {
    pub fn new() -> Self { return Self { _params: [], _children: [], _training: true, _name: "GELU" }; }
    pub fn forward(self, x: Variable) -> Variable {
        # GELU ≈ 0.5 * x * (1 + tanh(sqrt(2/pi) * (x + 0.044715 * x^3)))
        let x3 = x.mul(x).mul(x);
        let inner = x.add(x3.mul(Variable::new(Tensor::full(x.shape(), 0.044715, DType::Float32, Device::CPU), "c")));
        let scale = Variable::new(Tensor::full(x.shape(), 0.7978845608, DType::Float32, Device::CPU), "s");
        let half = Variable::new(Tensor::full(x.shape(), 0.5, DType::Float32, Device::CPU), "half");
        let one = Variable::new(Tensor::ones(x.shape(), DType::Float32, Device::CPU), "one");
        return half.mul(x).mul(one.add(inner.mul(scale).tanh_act()));
    }
}

# ============================================================
# SECTION 11: DROPOUT
# ============================================================

pub class Dropout : Module {
    pub let rate: Float;

    pub fn new(rate: Float) -> Self {
        return Self { _params: [], _children: [], _training: true, _name: "Dropout", rate: rate };
    }

    pub fn forward(self, x: Variable) -> Variable {
        if (!self._training) { return x; }
        let mask_data = [];
        let scale = 1.0 / (1.0 - self.rate);
        for (v in x.data.data) {
            let r = Tensor::rand([1], DType::Float32, Device::CPU).data[0];
            mask_data = mask_data + [r > self.rate ? scale : 0.0];
        }
        let mask = Tensor::new(mask_data, x.shape(), x.data.dtype, x.data.device);
        let mask_var = Variable::new(mask, "dropout_mask");
        return x.mul(mask_var);
    }
}

# ============================================================
# SECTION 12: RESIDUAL CONNECTIONS
# ============================================================

pub class Residual : Module {
    pub let block: Module;

    pub fn new(block: Module) -> Self {
        let m = Module::new("Residual");
        m.add_child(block);
        return Self {
            _params: m._params, _children: m._children, _training: true,
            _name: "Residual", block: block
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        return x.add(self.block.forward(x));
    }
}

# ============================================================
# SECTION 13: SEQUENTIAL & MODEL BUILDER
# ============================================================

pub class Sequential : Module {
    pub let layers: [Module];

    pub fn new(layers: [Module]) -> Self {
        let m = Module::new("Sequential");
        for (l in layers) { m.add_child(l); }
        return Self {
            _params: m._params, _children: layers, _training: true,
            _name: "Sequential", layers: layers
        };
    }

    pub fn forward(self, x: Variable) -> Variable {
        let out = x;
        for (layer in self.layers) {
            out = layer.forward(out);
        }
        return out;
    }

    pub fn add(self, layer: Module) {
        self.layers = self.layers + [layer];
        self._children = self._children + [layer];
    }
}

pub class ModelBuilder {
    pub let layers: [Module];

    pub fn new() -> Self {
        return Self { layers: [] };
    }

    pub fn linear(self, in_f: Int, out_f: Int) -> Self {
        self.layers = self.layers + [Linear::new(in_f, out_f, true)];
        return self;
    }

    pub fn conv2d(self, in_ch: Int, out_ch: Int, k: Int, s: Int, p: Int) -> Self {
        self.layers = self.layers + [Conv2d::new(in_ch, out_ch, k, s, p, true)];
        return self;
    }

    pub fn relu(self) -> Self {
        self.layers = self.layers + [ReLU::new()];
        return self;
    }

    pub fn gelu(self) -> Self {
        self.layers = self.layers + [GELU::new()];
        return self;
    }

    pub fn dropout(self, rate: Float) -> Self {
        self.layers = self.layers + [Dropout::new(rate)];
        return self;
    }

    pub fn layer_norm(self, dim: Int) -> Self {
        self.layers = self.layers + [LayerNorm::new(dim)];
        return self;
    }

    pub fn batch_norm(self, features: Int) -> Self {
        self.layers = self.layers + [BatchNorm::new(features)];
        return self;
    }

    pub fn embedding(self, num: Int, dim: Int) -> Self {
        self.layers = self.layers + [Embedding::new(num, dim)];
        return self;
    }

    pub fn residual(self, block: Module) -> Self {
        self.layers = self.layers + [Residual::new(block)];
        return self;
    }

    pub fn build(self) -> Sequential {
        return Sequential::new(self.layers);
    }
}

# ============================================================
# MODULE EXPORTS
# ============================================================

export {
    "Parameter": Parameter,
    "Module": Module,
    "Linear": Linear,
    "Conv2d": Conv2d,
    "Conv1d": Conv1d,
    "RNNCell": RNNCell,
    "LSTMCell": LSTMCell,
    "GRUCell": GRUCell,
    "MultiHeadAttention": MultiHeadAttention,
    "TransformerEncoderLayer": TransformerEncoderLayer,
    "TransformerDecoderLayer": TransformerDecoderLayer,
    "LayerNorm": LayerNorm,
    "BatchNorm": BatchNorm,
    "Embedding": Embedding,
    "MaxPool2d": MaxPool2d,
    "AvgPool2d": AvgPool2d,
    "GlobalAvgPool": GlobalAvgPool,
    "ReLU": ReLU,
    "Sigmoid": Sigmoid,
    "Tanh": Tanh,
    "Softmax": Softmax,
    "LeakyReLU": LeakyReLU,
    "GELU": GELU,
    "Dropout": Dropout,
    "Residual": Residual,
    "Sequential": Sequential,
    "ModelBuilder": ModelBuilder
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
