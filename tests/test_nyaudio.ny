# ============================================================
# NYAUDIO - Nyx 3D Audio Engine Test Suite
# ============================================================
# Tests for audio configuration, spatial audio, HRTF, and 3D positioning

import "engines/nyaudio/nyaudio";

# ============================================================
# TEST: AudioConfig
# ============================================================

let test_audio_config = fn() {
    let config = nyaudio.AudioConfig::new();
    
    assert(config.sample_rate == 48000, "Default sample rate should be 48000");
    assert(config.channels == 2, "Default channels should be 2 (stereo)");
    assert(config.buffer_size == 1024, "Default buffer size should be 1024");
    assert(config.hrtf_enabled == true, "HRTF should be enabled by default");
    
    print("[PASS] AudioConfig creation and defaults");
};

# ============================================================
# TEST: Spatial Module - Listener
# ============================================================

let test_listener = fn() {
    let listener = nyaudio.spatial.Listener::new();
    
    assert(listener.x == 0.0, "Initial X should be 0.0");
    assert(listener.y == 0.0, "Initial Y should be 0.0");
    assert(listener.z == 0.0, "Initial Z should be 0.0");
    assert(listener.fx == 0.0, "Forward X should be 0.0");
    assert(listener.fy == 0.0, "Forward Y should be 0.0");
    assert(listener.fz == -1.0, "Forward Z should be -1.0 (looking forward)");
    
    # Test modification
    listener.x = 10.0;
    listener.y = 5.0;
    listener.z = 3.0;
    assert(listener.x == 10.0, "X should be modifiable");
    assert(listener.y == 5.0, "Y should be modifiable");
    assert(listener.z == 3.0, "Z should be modifiable");
    
    print("[PASS] Listener creation and modification");
};

# ============================================================
# TEST: Spatial Module - Source3D
# ============================================================

let test_source_3d = fn() {
    let source = nyaudio.spatial.Source3D::new("footsteps");
    
    assert(source.id == "footsteps", "Source ID should be 'footsteps'");
    assert(source.x == 0.0, "Initial X should be 0.0");
    assert(source.y == 0.0, "Initial Y should be 0.0");
    assert(source.z == 0.0, "Initial Z should be 0.0");
    assert(source.vx == 0.0, "Initial velocity X should be 0.0");
    assert(source.vy == 0.0, "Initial velocity Y should be 0.0");
    assert(source.vz == 0.0, "Initial velocity Z should be 0.0");
    assert(source.gain == 1.0, "Initial gain should be 1.0 (full volume)");
    
    # Test modification
    source.x = 5.0;
    source.y = 2.0;
    source.z = -3.0;
    source.vx = 1.0;
    source.gain = 0.5;
    
    assert(source.x == 5.0, "Position X should be modifiable");
    assert(source.vx == 1.0, "Velocity X should be modifiable");
    assert(source.gain == 0.5, "Gain should be modifiable");
    
    print("[PASS] Source3D creation and modification");
};

# ============================================================
# TEST: Spatial Module - HRTFProcessor
# ============================================================

let test_hrtf_processor = fn() {
    let hrtf = nyaudio.spatial.HRTFProcessor::new();
    
    assert(hrtf.enabled == true, "HRTF should be enabled by default");
    
    hrtf.enabled = false;
    assert(hrtf.enabled == false, "HRTF should be disableable");
    
    print("[PASS] HRTFProcessor creation and modification");
};

# ============================================================
# RUN ALL TESTS
# ============================================================

let run_all_tests = fn() {
    print("========================================");
    print("NYAUDIO Test Suite - Starting");
    print("========================================");
    
    test_audio_config();
    test_listener();
    test_source_3d();
    test_hrtf_processor();
    
    print("========================================");
    print("NYAUDIO Test Suite - ALL TESTS PASSED");
    print("========================================");
};

# Execute tests
run_all_tests();
