# ============================================================
# NYPHYSICS - Nyx Native Physics Engine Test Suite
# ============================================================
# Tests for rigid body dynamics, soft bodies, constraints, and collision

import "engines/nyphysics/nyphysics";

# ============================================================
# TEST: PhysicsConfig
# ============================================================

let test_physics_config = fn() {
    let config = nyphysics.PhysicsConfig::new();
    
    assert(config.gravity_x == 0.0, "Default gravity X should be 0.0");
    assert(config.gravity_y == -9.81, "Default gravity Y should be -9.81");
    assert(config.gravity_z == 0.0, "Default gravity Z should be 0.0");
    assert(config.fixed_timestep > 0.0, "Fixed timestep should be positive");
    assert(config.max_substeps == 8, "Default max substeps should be 8");
    assert(config.deterministic == true, "Deterministic should be true by default");
    
    print("[PASS] PhysicsConfig creation and defaults");
};

# ============================================================
# TEST: Rigid Body - RigidBody
# ============================================================

let test_rigid_body = fn() {
    let body = nyphysics.rigid.RigidBody::new("box1", 10.0);
    
    assert(body.id == "box1", "Body ID should be 'box1'");
    assert(body.mass == 10.0, "Mass should be 10.0");
    assert(body.inv_mass == 0.1, "Inverse mass should be 0.1");
    assert(body.px == 0.0, "Position X should be 0.0");
    assert(body.py == 0.0, "Position Y should be 0.0");
    assert(body.pz == 0.0, "Position Z should be 0.0");
    assert(body.vx == 0.0, "Velocity X should be 0.0");
    assert(body.dynamic == true, "Dynamic should be true for positive mass");
    
    # Test static body (zero mass)
    let static_body = nyphysics.rigid.RigidBody::new("ground", 0.0);
    assert(static_body.mass == 0.0, "Static body mass should be 0.0");
    assert(static_body.inv_mass == 0.0, "Static body inv_mass should be 0.0");
    assert(static_body.dynamic == false, "Static body should not be dynamic");
    
    print("[PASS] RigidBody creation");
};

# ============================================================
# TEST: Rigid Body - apply_impulse
# ============================================================

let test_apply_impulse = fn() {
    let body = nyphysics.rigid.RigidBody::new("test_body", 2.0);
    
    # Apply impulse
    body.apply_impulse(10.0, 0.0, 0.0);
    
    assert(body.vx == 5.0, "Velocity X should be 5.0 after impulse (10/2)");
    assert(body.vy == 0.0, "Velocity Y should remain 0.0");
    
    # Apply another impulse
    body.apply_impulse(0.0, 20.0, 0.0);
    assert(body.vy == 10.0, "Velocity Y should be 10.0 after impulse (20/2)");
    
    # Test impulse on static body has no effect
    let static_body = nyphysics.rigid.RigidBody::new("static", 0.0);
    static_body.apply_impulse(100.0, 100.0, 100.0);
    assert(static_body.vx == 0.0, "Static body should not move");
    
    print("[PASS] RigidBody apply_impulse");
};

# ============================================================
# TEST: Rigid Body - Constraint
# ============================================================

let test_constraint = fn() {
    let constraint = nyphysics.rigid.Constraint::new("joint1", "body_a", "body_b");
    
    assert(constraint.id == "joint1", "Constraint ID should be 'joint1'");
    assert(constraint.body_a == "body_a", "Body A should be 'body_a'");
    assert(constraint.body_b == "body_b", "Body B should be 'body_b'");
    assert(constraint.stiffness == 1.0, "Default stiffness should be 1.0");
    
    constraint.stiffness = 0.5;
    assert(constraint.stiffness == 0.5, "Stiffness should be modifiable");
    
    print("[PASS] Constraint creation");
};

# ============================================================
# TEST: Rigid Body - ConstraintSolver
# ============================================================

let test_constraint_solver = fn() {
    let solver = nyphysics.rigid.ConstraintSolver::new(nyphysics.rigid.SOLVER_GAUSS_SEIDEL);
    
    assert(solver.mode == "gauss_seidel", "Solver mode should be Gauss-Seidel");
    assert(solver.iterations == 12, "Default iterations should be 12");
    
    let mlcp_solver = nyphysics.rigid.ConstraintSolver::new(nyphysics.rigid.SOLVER_MLCP);
    assert(mlcp_solver.mode == "mlcp", "MLCP solver mode should be 'mlcp'");
    
    print("[PASS] ConstraintSolver creation");
};

# ============================================================
# TEST: Rigid Body Constants
# ============================================================

let test_rigid_constants = fn() {
    assert(nyphysics.rigid.SOLVER_GAUSS_SEIDEL == "gauss_seidel", "GAUSS_SEIDEL constant should be 'gauss_seidel'");
    assert(nyphysics.rigid.SOLVER_MLCP == "mlcp", "MLCP constant should be 'mlcp'");
    
    print("[PASS] Rigid module constants");
};

# ============================================================
# TEST: Soft Body - FEMNode
# ============================================================

let test_fem_node = fn() {
    let node = nyphysics.softbody.FEMNode::new(1.0, 2.0, 3.0, 5.0);
    
    assert(node.x == 1.0, "X should be 1.0");
    assert(node.y == 2.0, "Y should be 2.0");
    assert(node.z == 3.0, "Z should be 3.0");
    assert(node.inv_mass == 0.2, "Inverse mass should be 0.2 (1/5)");
    
    # Test zero mass node
    let static_node = nyphysics.softbody.FEMNode::new(0.0, 0.0, 0.0, 0.0);
    assert(static_node.inv_mass == 0.0, "Zero mass should have zero inverse mass");
    
    print("[PASS] FEMNode creation");
};

# ============================================================
# TEST: Soft Body - FEMElement
# ============================================================

let test_fem_element = fn() {
    let element = nyphysics.softbody.FEMElement::new(0, 1, 2, 3);
    
    assert(element.a == 0, "Node A should be 0");
    assert(element.b == 1, "Node B should be 1");
    assert(element.c == 2, "Node C should be 2");
    assert(element.d == 3, "Node D should be 3");
    assert(element.young_modulus == 1.0, "Default Young's modulus should be 1.0");
    assert(element.poisson_ratio == 0.3, "Default Poisson ratio should be 0.3");
    
    print("[PASS] FEMElement creation");
};

# ============================================================
# TEST: Soft Body - SoftBody
# ============================================================

let test_soft_body = fn() {
    let soft = nyphysics.softbody.SoftBody::new("cloth1");
    
    assert(soft.id == "cloth1", "Soft body ID should be 'cloth1'");
    assert(soft.nodes.len() == 0, "Nodes should be empty initially");
    assert(soft.elements.len() == 0, "Elements should be empty initially");
    assert(soft.break_threshold == 9999.0, "Default break threshold should be 9999.0");
    
    # Add nodes
    let node1 = nyphysics.softbody.FEMNode::new(0.0, 0.0, 0.0, 1.0);
    let node2 = nyphysics.softbody.FEMNode::new(1.0, 0.0, 0.0, 1.0);
    soft.nodes.push(node1);
    soft.nodes.push(node2);
    assert(soft.nodes.len() == 2, "Should have 2 nodes");
    
    # Add element
    let element = nyphysics.softbody.FEMElement::new(0, 1, 2, 3);
    soft.elements.push(element);
    assert(soft.elements.len() == 1, "Should have 1 element");
    
    print("[PASS] SoftBody creation and management");
};

# ============================================================
# RUN ALL TESTS
# ============================================================

let run_all_tests = fn() {
    print("========================================");
    print("NYPHYSICS Test Suite - Starting");
    print("========================================");
    
    test_physics_config();
    test_rigid_body();
    test_apply_impulse();
    test_constraint();
    test_constraint_solver();
    test_rigid_constants();
    test_fem_node();
    test_fem_element();
    test_soft_body();
    
    print("========================================");
    print("NYPHYSICS Test Suite - ALL TESTS PASSED");
    print("========================================");
};

# Execute tests
run_all_tests();
