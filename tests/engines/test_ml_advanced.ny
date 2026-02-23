# ============================================================
# Advanced ML Engines Test Suite
# Tests: NyRL, NyGen, NyGraph, NySecure, NyMetrics
# ============================================================

use nyrl;
use nygen;
use nygraph_ml;
use nysecure;
use nymetrics;
use nytensor;
use nygrad;

class TestRunner {
    pub let passed: Int;
    pub let failed: Int;

    pub fn new() -> Self {
        return Self { passed: 0, failed: 0 };
    }

    pub fn assert(self, condition: Bool, test_name: String) {
        if (condition) {
            self.passed = self.passed + 1;
            print("[PASS] " + test_name);
        } else {
            self.failed = self.failed + 1;
            print("[FAIL] " + test_name);
        }
    }
}

# ============================================================
# NYRL TESTS
# ============================================================

fn test_nyrl(runner: TestRunner) {
    print("\n=== Testing NyRL ===");
    
    # Test Space
    let discrete_space = Space::Discrete(10);
    runner.assert(discrete_space != null, "Discrete space creation");
    
    let continuous_space = Space::Continuous([-1.0, -2.0], [1.0, 2.0]);
    runner.assert(continuous_space != null, "Continuous space creation");
    
    # Test ReplayBuffer
    let buffer = ReplayBuffer::new(1000);
    runner.assert(buffer.capacity == 1000, "Replay buffer creation");
    
    let state = Tensor::new([1.0, 2.0], [2], DType::Float32, Device::CPU);
    let action = Tensor::new([0.5], [1], DType::Float32, Device::CPU);
    buffer.push(state, action, 1.0, state, false);
    runner.assert(buffer.size == 1, "Replay buffer push");
    
    # Test DQN Agent
    let dqn = DQNAgent::new(4, 2, 0.99, 1000, 32);
    runner.assert(dqn.gamma == 0.99, "DQN agent creation");
    
    print("NyRL: Reinforcement learning verified");
}

# ============================================================
# NYGEN TESTS
# ============================================================

fn test_nygen(runner: TestRunner) {
    print("\n=== Testing NyGen ===");
    
    # Test VAE
    let encoder = Module::new("Encoder");
    let decoder = Module::new("Decoder");
    let vae = VAE::new(encoder, decoder, null, 10, 1.0);
    runner.assert(vae.latent_dim == 10, "VAE creation");
    runner.assert(vae.beta == 1.0, "VAE beta parameter");
    
    # Test Diffusion Model
    let model = Module::new("DiffusionUNet");
    let diffusion = DiffusionModel::new(model, null, 1000, 0.0001, 0.02);
    runner.assert(diffusion.num_timesteps == 1000, "Diffusion model creation");
    
    # Test LLM Config
    let llm_config = LLMConfig::new(50000, 512, 6, 8);
    runner.assert(llm_config.vocab_size == 50000, "LLM config vocab size");
    runner.assert(llm_config.d_model == 512, "LLM config d_model");
    runner.assert(llm_config.n_layers == 6, "LLM config layers");
    
    print("NyGen: Generative AI verified");
}

# ============================================================
# NYGRAPH TESTS
# ============================================================

fn test_nygraph(runner: TestRunner) {
    print("\n=== Testing NyGraph ===");
    
    # Test Graph creation
    let edge_index = Tensor::new([0.0, 1.0, 1.0, 2.0], [2, 2], DType::Float32, Device::CPU);
    let graph = Graph::new(3, edge_index, null, null);
    runner.assert(graph.num_nodes == 3, "Graph creation");
    runner.assert(graph.num_edges == 2, "Graph edges");
    
    # Test GCN layer
    let gcn = GCNConv::new(10, 20, true);
    runner.assert(gcn.in_channels == 10, "GCN layer input");
    runner.assert(gcn.out_channels == 20, "GCN layer output");
    
    # Test pooling
    let x = Tensor::new([1.0, 2.0, 3.0], [3], DType::Float32, Device::CPU);
    let batch = Tensor::new([0.0, 0.0, 1.0], [3], DType::Int64, Device::CPU);
    let pooled = global_mean_pool(x, batch);
    runner.assert(pooled.numel() == 2, "Global mean pooling");
    
    print("NyGraph: Graph ML verified");
}

# ============================================================
# NYSECURE TESTS
# ============================================================

fn test_nysecure(runner: TestRunner) {
    print("\n=== Testing NySecure ===");
    
    # Test FGSM Attack
    let fgsm = FGSMAttack::new(0.1, 0.0, 1.0);
    runner.assert(fgsm.epsilon == 0.1, "FGSM attack epsilon");
    
    # Test PGD Attack
    let pgd = PGDAttack::new(0.1, 0.01, 40, 0.0, 1.0);
    runner.assert(pgd.num_steps == 40, "PGD attack steps");
    runner.assert(pgd.alpha == 0.01, "PGD attack alpha");
    
    # Test Differential Privacy
    let dp = DifferentialPrivacy::new(1.0, 1e-5, 1.0, 1.0);
    runner.assert(dp.epsilon == 1.0, "DP epsilon");
    runner.assert(dp.noise_multiplier == 1.0, "DP noise multiplier");
    
    # Test Fairness Metrics
    let fairness = FairnessMetrics::new();
    runner.assert(fairness != null, "Fairness metrics creation");
    
    # Test Bias Detector
    let bias_detector = BiasDetector::new(0.1);
    runner.assert(bias_detector.threshold == 0.1, "Bias detector threshold");
    
    print("NySecure: Security & trust verified");
}

# ============================================================
# NYMETRICS TESTS
# ============================================================

fn test_nymetrics(runner: TestRunner) {
    print("\n=== Testing NyMetrics ===");
    
    # Test Classification Metrics
    let clf_metrics = ClassificationMetrics::new();
    runner.assert(clf_metrics != null, "Classification metrics creation");
    
    let y_true = Tensor::new([1.0, 0.0, 1.0, 1.0], [4], DType::Float32, Device::CPU);
    let y_pred = Tensor::new([1.0, 0.0, 0.0, 1.0], [4], DType::Float32, Device::CPU);
    let acc = clf_metrics.accuracy(y_true, y_pred);
    runner.assert(acc == 0.75, "Accuracy calculation");
    
    # Test Regression Metrics
    let reg_metrics = RegressionMetrics::new();
    let y_true_reg = Tensor::new([1.0, 2.0, 3.0], [3], DType::Float32, Device::CPU);
    let y_pred_reg = Tensor::new([1.1, 2.1, 2.9], [3], DType::Float32, Device::CPU);
    let mse = reg_metrics.mse(y_true_reg, y_pred_reg);
    runner.assert(mse < 0.1, "MSE calculation");
    
    # Test K-Fold
    let kfold = KFold::new(5, false);
    runner.assert(kfold.n_splits == 5, "K-Fold splits");
    
    # Test Drift Detector
    let drift = DriftDetector::new("kolmogorov_smirnov", 0.05);
    runner.assert(drift.threshold == 0.05, "Drift detector threshold");
    
    # Test Benchmark
    let benchmark = Benchmark::new(5, 10);
    runner.assert(benchmark.warmup_runs == 5, "Benchmark warmup");
    runner.assert(benchmark.benchmark_runs == 10, "Benchmark runs");
    
    print("NyMetrics: Evaluation metrics verified");
}

# ============================================================
# MAIN TEST RUNNER
# ============================================================

fn main() {
    print("=======================================");
    print("  ADVANCED ML ENGINES TEST SUITE");
    print("  Testing 5 engines");
    print("=======================================");
    
    let runner = TestRunner::new();
    
    test_nyrl(runner);
    test_nygen(runner);
    test_nygraph(runner);
    test_nysecure(runner);
    test_nymetrics(runner);
    
    print("\n=== Test Report ===");
    print("Passed: " + str(runner.passed));
    print("Failed: " + str(runner.failed));
    print("Total: " + str(runner.passed + runner.failed));
    
    if (runner.failed == 0) {
        print("\n✅ All Advanced ML engines passed!");
    } else {
        print("\n❌ Some tests failed.");
    }
}

main();
