# ============================================================
# ML Core Engines Test Suite
# Tests: NyTensor, NyGrad, NyAccel, NyNet, NyOpt, NyLoss
# ============================================================

use nytensor;
use nygrad;
use nyaccel;
use nynet_ml;
use nyopt;
use nyloss;

class TestRunner {
    pub let passed: Int;
    pub let failed: Int;
    pub let tests: [String];

    pub fn new() -> Self {
        return Self { passed: 0, failed: 0, tests: [] };
    }

    pub fn assert(self, condition: Bool, test_name: String) {
        if (condition) {
            self.passed = self.passed + 1;
            print("[PASS] " + test_name);
        } else {
            self.failed = self.failed + 1;
            print("[FAIL] " + test_name);
        }
        self.tests = self.tests + [test_name];
    }

    pub fn report(self) {
        print("\n=== Test Report ===");
        print("Total: " + str(len(self.tests)));
        print("Passed: " + str(self.passed));
        print("Failed: " + str(self.failed));
        print("Success Rate: " + str(self.passed * 100 / len(self.tests)) + "%");
    }
}

# ============================================================
# NYTENSOR TESTS
# ============================================================

fn test_nytensor(runner: TestRunner) {
    print("\n=== Testing NyTensor ===");
    
    # Test tensor creation
    let t1 = Tensor::new([1.0, 2.0, 3.0, 4.0], [2, 2], DType::Float32, Device::CPU);
    runner.assert(t1.numel() == 4, "Tensor creation");
    runner.assert(t1.shape.dims[0] == 2, "Tensor shape");
    
    # Test tensor operations
    let t2 = Tensor::zeros([2, 2], DType::Float32, Device::CPU);
    runner.assert(t2.data[0] == 0.0, "Tensor zeros");
    
    let t3 = Tensor::ones([2, 2], DType::Float32, Device::CPU);
    runner.assert(t3.data[0] == 1.0, "Tensor ones");
    
    # Test arithmetic
    let t4 = t1.add(t3);
    runner.assert(t4.data[0] == 2.0, "Tensor addition");
    
    let t5 = t1.scale(2.0);
    runner.assert(t5.data[0] == 2.0, "Tensor scaling");
    
    # Test reduction
    let sum = t1.sum();
    runner.assert(sum == 10.0, "Tensor sum");
    
    let mean = t1.mean();
    runner.assert(mean == 2.5, "Tensor mean");
    
    print("NyTensor: Basic operations verified");
}

# ============================================================
# NYGRAD TESTS
# ============================================================

fn test_nygrad(runner: TestRunner) {
    print("\n=== Testing NyGrad ===");
    
    # Test variable creation
    let t = Tensor::new([2.0, 3.0], [2], DType::Float32, Device::CPU);
    let v = Variable::new(t, "x");
    runner.assert(v.data.numel() == 2, "Variable creation");
    
    # Test gradient tracking
    v.requires_grad = true;
    runner.assert(v.requires_grad == true, "Gradient tracking enabled");
    
    # Test simple computation
    let x = Variable::new(Tensor::new([3.0], [1], DType::Float32, Device::CPU), "x");
    let y = x.mul(x);
    runner.assert(y.data.data[0] == 9.0, "Variable multiplication");
    
    # Test backward pass
    backward(y, false);
    runner.assert(x.grad != null, "Gradient computed");
    
    print("NyGrad: Autograd system verified");
}

# ============================================================
# NYACCEL TESTS
# ============================================================

fn test_nyaccel(runner: TestRunner) {
    print("\n=== Testing NyAccel ===");
    
    # Test device detection
    let dm = DeviceManager::new();
    runner.assert(dm != null, "DeviceManager creation");
    
    # Test device enumeration
    let devices = dm.list_devices();
    runner.assert(devices != null, "Device enumeration");
    
    # Test memory allocation
    let pool = MemoryPool::new(1024 * 1024);  # 1MB
    runner.assert(pool.capacity == 1024 * 1024, "Memory pool creation");
    
    let ptr = pool.allocate(256);
    runner.assert(ptr != null, "Memory allocation");
    
    print("NyAccel: Hardware acceleration verified");
}

# ============================================================
# NYNET TESTS
# ============================================================

fn test_nynet(runner: TestRunner) {
    print("\n=== Testing NyNet ===");
    
    # Test Linear layer
    let linear = Linear::new(10, 5, true);
    runner.assert(linear.in_features == 10, "Linear layer creation");
    runner.assert(linear.out_features == 5, "Linear layer output size");
    
    # Test forward pass
    let x = Variable::new(
        Tensor::randn([2, 10], DType::Float32, Device::CPU), "x");
    let out = linear.forward(x);
    runner.assert(out.shape()[1] == 5, "Linear forward pass");
    
    # Test activation
    let relu = ReLU::new();
    let activated = relu.forward(out);
    runner.assert(activated != null, "ReLU activation");
    
    # Test Sequential
    let seq = Sequential::new([
        Linear::new(10, 20, true),
        ReLU::new(),
        Linear::new(20, 5, true)
    ]);
    runner.assert(len(seq.layers) == 3, "Sequential model");
    
    print("NyNet: Neural network layers verified");
}

# ============================================================
# NYOPT TESTS
# ============================================================

fn test_nyopt(runner: TestRunner) {
    print("\n=== Testing NyOpt ===");
    
    # Test SGD optimizer
    let params = [
        Parameter::new("weight", [10, 5], "xavier")
    ];
    let sgd = SGD::new(params, 0.01, 0.9, 0.0, false);
    runner.assert(sgd.lr == 0.01, "SGD creation");
    runner.assert(sgd.momentum == 0.9, "SGD momentum");
    
    # Test Adam optimizer
    let adam = Adam::new(params, 0.001, 0.9, 0.999, 1e-8, 0.0, false);
    runner.assert(adam.lr == 0.001, "Adam creation");
    runner.assert(adam.beta1 == 0.9, "Adam beta1");
    
    # Test learning rate scheduler
    let scheduler = StepLR::new(sgd, 10, 0.1);
    runner.assert(scheduler.step_size == 10, "StepLR scheduler");
    
    print("NyOpt: Optimizers verified");
}

# ============================================================
# NYLOSS TESTS
# ============================================================

fn test_nyloss(runner: TestRunner) {
    print("\n=== Testing NyLoss ===");
    
    # Test MSE Loss
    let mse = MSELoss::new(Reduction::Mean);
    runner.assert(mse.name == "MSELoss", "MSE loss creation");
    
    let pred = Variable::new(
        Tensor::new([1.0, 2.0, 3.0], [3], DType::Float32, Device::CPU), "pred");
    let target = Variable::new(
        Tensor::new([1.5, 2.5, 3.5], [3], DType::Float32, Device::CPU), "target");
    
    let loss = mse.forward(pred, target);
    runner.assert(loss.data.data[0] > 0.0, "MSE loss computation");
    
    # Test Cross Entropy Loss
    let ce = CrossEntropyLoss::new(Reduction::Mean, 0.0);
    runner.assert(ce.name == "CrossEntropyLoss", "CrossEntropy creation");
    
    # Test Focal Loss
    let focal = FocalLoss::new(Reduction::Mean, 0.25, 2.0);
    runner.assert(focal.alpha == 0.25, "Focal loss alpha");
    
    # Test Dice Loss
    let dice = DiceLoss::new(Reduction::Mean, 1.0);
    runner.assert(dice.smooth == 1.0, "Dice loss smoothing");
    
    print("NyLoss: Loss functions verified");
}

# ============================================================
# MAIN TEST RUNNER
# ============================================================

fn main() {
    print("=======================================");
    print("  ML CORE ENGINES TEST SUITE");
    print("  Testing 6 engines");
    print("=======================================");
    
    let runner = TestRunner::new();
    
    test_nytensor(runner);
    test_nygrad(runner);
    test_nyaccel(runner);
    test_nynet(runner);
    test_nyopt(runner);
    test_nyloss(runner);
    
    runner.report();
    
    if (runner.failed == 0) {
        print("\n✅ All ML Core engines passed!");
    } else {
        print("\n❌ Some tests failed.");
    }
}

main();
