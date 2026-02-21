# ============================================================
# NYANIM - Nyx Animation Engine Test Suite
# ============================================================
# Tests for animation configuration, IK, skeleton, and motion matching

import "engines/nyanim/nyanim";

# ============================================================
# TEST: AnimConfig
# ============================================================

let test_anim_config = fn() {
    let config = nyanim.AnimConfig::new();
    
    assert(config.update_rate == 60, "Default update rate should be 60Hz");
    assert(config.motion_history_size == 240, "Default motion history should be 240 frames");
    
    print("[PASS] AnimConfig creation and defaults");
};

# ============================================================
# TEST: IK Module - Bone
# ============================================================

let test_bone = fn() {
    let bone = nyanim.ik.Bone::new("femur", 45.0);
    
    assert(bone.name == "femur", "Bone name should be 'femur'");
    assert(bone.length == 45.0, "Bone length should be 45.0cm");
    assert(bone.parent == null, "Parent should be null initially");
    
    bone.parent = "hip";
    assert(bone.parent == "hip", "Parent should be modifiable");
    
    print("[PASS] Bone creation and modification");
};

# ============================================================
# TEST: IK Module - Skeleton
# ============================================================

let test_skeleton = fn() {
    let skeleton = nyanim.ik.Skeleton::new();
    
    assert(skeleton.bones.len() == 0, "Bones should be empty initially");
    
    # Add bones
    let hip = nyanim.ik.Bone::new("hip", 10.0);
    let femur = nyanim.ik.Bone::new("femur", 45.0);
    femur.parent = "hip";
    let tibia = nyanim.ik.Bone::new("tibia", 40.0);
    tibia.parent = "femur";
    
    skeleton.add_bone(hip);
    skeleton.add_bone(femur);
    skeleton.add_bone(tibia);
    
    assert(skeleton.bones.len() == 3, "Should have 3 bones");
    assert(skeleton.bones["femur"].name == "femur", "Femur should be in skeleton");
    assert(skeleton.bones["femur"].parent == "hip", "Femur parent should be 'hip'");
    
    print("[PASS] Skeleton bone management");
};

# ============================================================
# TEST: IK Module - FullBodyIK
# ============================================================

let test_full_body_ik = fn() {
    let ik = nyanim.ik.FullBodyIK::new();
    
    assert(ik.iterations == 16, "Default iterations should be 16");
    assert(ik.tolerance == 0.001, "Default tolerance should be 0.001");
    
    # Test solve
    let skeleton = nyanim.ik.Skeleton::new();
    let bone = nyanim.ik.Bone::new("root", 0.0);
    skeleton.add_bone(bone);
    
    let targets = {};
    let result = ik.solve(skeleton, targets);
    assert(result != null, "Should return a skeleton");
    
    print("[PASS] FullBodyIK creation and solving");
};

# ============================================================
# TEST: Motion Module - PoseSample
# ============================================================

let test_pose_sample = fn() {
    let sample = nyanim.motion.PoseSample::new("run_cycle", 1.5);
    
    assert(sample.clip_id == "run_cycle", "Clip ID should be 'run_cycle'");
    assert(sample.time_sec == 1.5, "Time should be 1.5 seconds");
    assert(sample.velocity_x == 0.0, "Initial velocity X should be 0.0");
    assert(sample.velocity_z == 0.0, "Initial velocity Z should be 0.0");
    
    # Test modification
    sample.velocity_x = 2.5;
    sample.velocity_z = 1.0;
    assert(sample.velocity_x == 2.5, "Velocity X should be modifiable");
    assert(sample.velocity_z == 1.0, "Velocity Z should be modifiable");
    
    print("[PASS] PoseSample creation and modification");
};

# ============================================================
# RUN ALL TESTS
# ============================================================

let run_all_tests = fn() {
    print("========================================");
    print("NYANIM Test Suite - Starting");
    print("========================================");
    
    test_anim_config();
    test_bone();
    test_skeleton();
    test_full_body_ik();
    test_pose_sample();
    
    print("========================================");
    print("NYANIM Test Suite - ALL TESTS PASSED");
    print("========================================");
};

# Execute tests
run_all_tests();
