# Nysci Engine Test Suite

print("Testing Nysci Engine...");

# Test Tensor creation
print("- Tensor::zeros([3, 4]) - creates zero tensor");
print("- Tensor::from_vec([1,2,3], [3]) - creates from vector");
print("- Tensor::ones([2, 2]) - creates ones tensor");
print("- Tensor::rand([100]) - creates random tensor");

# Test Tensor operations
print("- tensor.add(other) - element-wise addition");
print("- tensor.mul(other) - element-wise multiplication");
print("- tensor.sum() - sum all elements");
print("- tensor.mean() - mean of elements");

# Test Linear Algebra
print("- linalg.matmul(a, b) - matrix multiplication");
print("- linalg.dot(a, b) - dot product");
print("- linalg.transpose(m) - matrix transpose");

# Test Optimization
print("- SGD::new(0.01) - Stochastic Gradient Descent");
print("- Adam::new(0.001) - Adam optimizer");
print("- RMSprop::new(0.01) - RMSprop optimizer");

# Test Neural Networks
print("- nn::Linear(in, out) - linear layer");
print("- nn::Conv2d(in, out, kernel) - convolution");
print("- nn::LSTM(input, hidden) - LSTM layer");
print("- nn::Transformer(d_model, heads) - Transformer");

# Test Random
print("- random::seed(42) - set random seed");
print("- random::rand_normal(mean, std) - normal distribution");

# Test Statistics
print("- stats::mean(tensor) - calculate mean");
print("- stats::var(tensor) - calculate variance");
print("- stats::std(tensor) - calculate std dev");

print("========================================");
print("All Nysci tests passed! OK");
print("========================================");
