# ============================================================
# NYRENDER - Nyx Native Graphics Engine Test Suite
# ============================================================
# Tests for rendering, PBR materials, ray tracing, and graphics pipeline

import "engines/nyrender/nyrender";

# ============================================================
# TEST: RenderConfig
# ============================================================

let test_render_config = fn() {
    let config = nyrender.RenderConfig::new();
    
    assert(config.backend == "vulkan", "Default backend should be Vulkan");
    assert(config.width == 1920, "Default width should be 1920");
    assert(config.height == 1080, "Default height should be 1080");
    assert(config.vsync == true, "VSync should be enabled by default");
    assert(config.hybrid_rt == true, "Hybrid RT should be enabled by default");
    assert(config.hdr == true, "HDR should be enabled by default");
    
    # Test builder pattern
    let custom_config = config.with_backend(nyrender.backend.DIRECTX12).with_resolution(2560, 1440);
    assert(custom_config.backend == "directx12", "Backend should be changed to DirectX12");
    assert(custom_config.width == 2560, "Width should be 2560");
    assert(custom_config.height == 1440, "Height should be 1440");
    
    print("[PASS] RenderConfig creation and builder methods");
};

# ============================================================
# TEST: Backend Constants
# ============================================================

let test_backend_constants = fn() {
    assert(nyrender.backend.VULKAN == "vulkan", "VULKAN should be 'vulkan'");
    assert(nyrender.backend.DIRECTX12 == "directx12", "DIRECTX12 should be 'directx12'");
    assert(nyrender.backend.METAL == "metal", "METAL should be 'metal'");
    assert(nyrender.backend.WEBGPU == "webgpu", "WEBGPU should be 'webgpu'");
    
    print("[PASS] Backend constants");
};

# ============================================================
# TEST: PBR Module - SpectralSample
# ============================================================

let test_spectral_sample = fn() {
    let sample = nyrender.pbr.SpectralSample::new(550.0, 0.8);
    
    assert(sample.wavelength_nm == 550.0, "Wavelength should be 550nm");
    assert(sample.intensity == 0.8, "Intensity should be 0.8");
    
    print("[PASS] SpectralSample creation");
};

# ============================================================
# TEST: PBR Module - BRDFModel
# ============================================================

let test_brdf_model = fn() {
    let ggx = nyrender.pbr.BRDFModel::ggx();
    
    assert(ggx.name == "ggx_microfacet", "GGX name should be 'ggx_microfacet'");
    assert(ggx.energy_conserving == true, "GGX should be energy conserving");
    assert(ggx.supports_anisotropy == true, "GGX should support anisotropy");
    
    print("[PASS] BRDFModel GGX factory");
};

# ============================================================
# TEST: PBR Module - MaterialLayer
# ============================================================

let test_material_layer = fn() {
    let layer = nyrender.pbr.MaterialLayer::new("metal_plate");
    
    assert(layer.id == "metal_plate", "Layer ID should be 'metal_plate'");
    assert(layer.thickness_mm == 0.1, "Default thickness should be 0.1mm");
    assert(layer.ior == 1.5, "Default IOR should be 1.5");
    assert(layer.roughness == 0.5, "Default roughness should be 0.5");
    assert(layer.metallic == 0.0, "Default metallic should be 0.0");
    
    # Test customization
    layer.metallic = 1.0;
    layer.roughness = 0.2;
    assert(layer.metallic == 1.0, "Metallic should be changeable to 1.0");
    assert(layer.roughness == 0.2, "Roughness should be changeable to 0.2");
    
    print("[PASS] MaterialLayer creation and modification");
};

# ============================================================
# TEST: PBR Module - MaterialNode
# ============================================================

let test_material_node = fn() {
    let node = nyrender.pbr.MaterialNode::new("base_color", "constant");
    
    assert(node.id == "base_color", "Node ID should be 'base_color'");
    assert(node.op == "constant", "Node operation should be 'constant'");
    assert(node.inputs.len() == 0, "Inputs should be empty initially");
    
    node.inputs.push("texture_coord");
    assert(node.inputs.len() == 1, "Should have 1 input after push");
    
    print("[PASS] MaterialNode creation");
};

# ============================================================
# TEST: PBR Module - MaterialGraph
# ============================================================

let test_material_graph = fn() {
    let graph = nyrender.pbr.MaterialGraph::new();
    
    assert(graph.nodes.len() == 0, "Nodes should be empty initially");
    assert(graph.layers.len() == 0, "Layers should be empty initially");
    
    # Add nodes
    let node1 = nyrender.pbr.MaterialNode::new("albedo", "constant");
    let node2 = nyrender.pbr.MaterialNode::new("normal", "texture");
    graph.add_node(node1);
    graph.add_node(node2);
    assert(graph.nodes.len() == 2, "Should have 2 nodes");
    
    # Add layers
    let layer1 = nyrender.pbr.MaterialLayer::new("base_layer");
    graph.add_layer(layer1);
    assert(graph.layers.len() == 1, "Should have 1 layer");
    
    print("[PASS] MaterialGraph node and layer management");
};

# ============================================================
# TEST: PBR Module - MaterialCompiler
# ============================================================

let test_material_compiler = fn() {
    let compiler = nyrender.pbr.MaterialCompiler::new("vulkan");
    let graph = nyrender.pbr.MaterialGraph::new();
    
    let result = compiler.compile(graph);
    assert(result == "compiled_material_blob", "Should return compiled blob");
    
    # Test with different backend
    let dx12_compiler = nyrender.pbr.MaterialCompiler::new("directx12");
    assert(dx12_compiler.target_backend == "directx12", "Backend should be set correctly");
    
    print("[PASS] MaterialCompiler compilation");
};

# ============================================================
# TEST: PBR Module - NeuralMaterialCodec
# ============================================================

let test_neural_codec = fn() {
    let codec = nyrender.pbr.NeuralMaterialCodec::new();
    
    assert(codec.enabled == false, "Should be disabled by default");
    assert(codec.quality == 0.9, "Default quality should be 0.9");
    
    let compressed = codec.compress("source_material");
    assert(compressed != null, "Should return compressed data");
    
    let reconstructed = codec.reconstruct(compressed);
    assert(reconstructed == "reconstructed_high_frequency_material", "Should reconstruct material");
    
    print("[PASS] NeuralMaterialCodec compression and reconstruction");
};

# ============================================================
# RUN ALL TESTS
# ============================================================

let run_all_tests = fn() {
    print("========================================");
    print("NYRENDER Test Suite - Starting");
    print("========================================");
    
    test_render_config();
    test_backend_constants();
    test_spectral_sample();
    test_brdf_model();
    test_material_layer();
    test_material_node();
    test_material_graph();
    test_material_compiler();
    test_neural_codec();
    
    print("========================================");
    print("NYRENDER Test Suite - ALL TESTS PASSED");
    print("========================================");
};

# Execute tests
run_all_tests();
