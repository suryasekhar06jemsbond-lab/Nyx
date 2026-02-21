# ============================================================
# NYAI - Nyx NPC Intelligence Engine Test Suite
# ============================================================
# Tests for behavior trees, GOAP planning, goals, and actions

import "engines/nyai/nyai";

# ============================================================
# TEST: AIConfig
# ============================================================

let test_ai_config = fn() {
    let config = nyai.AIConfig::new();
    
    assert(config.think_rate_hz == 20, "Default think rate should be 20Hz");
    assert(config.crowd_tick_rate_hz == 30, "Default crowd tick rate should be 30Hz");
    assert(config.deterministic == true, "Deterministic should be true by default");
    
    print("[PASS] AIConfig creation and defaults");
};

# ============================================================
# TEST: Hybrid Module - BTNode
# ============================================================

let test_bt_node = fn() {
    let node = nyai.hybrid.BTNode::new("patrol", "sequence");
    
    assert(node.id == "patrol", "Node ID should be 'patrol'");
    assert(node.node_type == "sequence", "Node type should be 'sequence'");
    assert(node.children.len() == 0, "Children should be empty initially");
    
    # Test adding children
    node.children.push("child1");
    node.children.push("child2");
    assert(node.children.len() == 2, "Should have 2 children");
    
    print("[PASS] BTNode creation");
};

# ============================================================
# TEST: Hybrid Module - BT Constants
# ============================================================

let test_bt_constants = fn() {
    assert(nyai.hybrid.BT_SUCCESS == "success", "BT_SUCCESS should be 'success'");
    assert(nyai.hybrid.BT_FAILURE == "failure", "BT_FAILURE should be 'failure'");
    assert(nyai.hybrid.BT_RUNNING == "running", "BT_RUNNING should be 'running'");
    
    print("[PASS] Behavior Tree constants");
};

# ============================================================
# TEST: Hybrid Module - BehaviorTree
# ============================================================

let test_behavior_tree = fn() {
    let root = nyai.hybrid.BTNode::new("root", "selector");
    let bt = nyai.hybrid.BehaviorTree::new(root);
    
    assert(bt.root.id == "root", "Root should be the root node");
    assert(bt.nodes.len() == 1, "Should have 1 node in map");
    assert(bt.nodes["root"].id == "root", "Root node should be in nodes map");
    
    # Test tick
    let result = bt.tick("actor_1");
    assert(result == "running", "Tick should return running state");
    
    print("[PASS] BehaviorTree creation and ticking");
};

# ============================================================
# TEST: Hybrid Module - Goal
# ============================================================

let test_goal = fn() {
    let goal = nyai.hybrid.Goal::new("patrol_area", 0.8);
    
    assert(goal.id == "patrol_area", "Goal ID should be 'patrol_area'");
    assert(goal.priority == 0.8, "Priority should be 0.8");
    
    # Test modification
    goal.priority = 1.0;
    assert(goal.priority == 1.0, "Priority should be modifiable");
    
    print("[PASS] Goal creation");
};

# ============================================================
# TEST: Hybrid Module - Action
# ============================================================

let test_action = fn() {
    let action = nyai.hybrid.Action::new("move_to_target", 5.0);
    
    assert(action.id == "move_to_target", "Action ID should be 'move_to_target'");
    assert(action.cost == 5.0, "Cost should be 5.0");
    assert(action.preconditions.len() == 0, "Preconditions should be empty initially");
    assert(action.effects.len() == 0, "Effects should be empty initially");
    
    # Test adding preconditions
    action.preconditions["has_path"] = true;
    action.preconditions["target_visible"] = false;
    assert(action.preconditions.len() == 2, "Should have 2 preconditions");
    assert(action.preconditions["has_path"] == true, "has_path should be true");
    
    # Test adding effects
    action.effects["at_target"] = true;
    assert(action.effects.len() == 1, "Should have 1 effect");
    assert(action.effects["at_target"] == true, "at_target should be true");
    
    print("[PASS] Action creation and modification");
};

# ============================================================
# RUN ALL TESTS
# ============================================================

let run_all_tests = fn() {
    print("========================================");
    print("NYAI Test Suite - Starting");
    print("========================================");
    
    test_ai_config();
    test_bt_node();
    test_bt_constants();
    test_behavior_tree();
    test_goal();
    test_action();
    
    print("========================================");
    print("NYAI Test Suite - ALL TESTS PASSED");
    print("========================================");
};

# Execute tests
run_all_tests();
