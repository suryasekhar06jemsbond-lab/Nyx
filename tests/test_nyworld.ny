# ============================================================
# NYWORLD - Nyx Open World Streaming Engine Test Suite
# ============================================================
# Tests for world partitioning, streaming, zones, and spatial management

import "engines/nyworld/nyworld";

# ============================================================
# TEST: WorldConfig
# ============================================================

let test_world_config = fn() {
    let config = nyworld.WorldConfig::new();
    
    assert(config.cell_size_m == 256.0, "Default cell size should be 256.0m");
    assert(config.preload_radius_cells == 4, "Default preload radius should be 4 cells");
    assert(config.max_stream_jobs == 64, "Default max stream jobs should be 64");
    assert(config.world_seed == 42, "Default world seed should be 42");
    
    print("[PASS] WorldConfig creation and defaults");
};

# ============================================================
# TEST: Partition Module - GridCoord
# ============================================================

let test_grid_coord = fn() {
    let coord = nyworld.partition.GridCoord::new(10, 20);
    
    assert(coord.x == 10, "X should be 10");
    assert(coord.y == 20, "Y should be 20");
    assert(coord.key() == "10:20", "Key should be '10:20'");
    
    # Test negative coordinates
    let neg_coord = nyworld.partition.GridCoord::new(-5, -3);
    assert(neg_coord.key() == "-5:-3", "Key for negative coords should be '-5:-3'");
    
    print("[PASS] GridCoord creation and key generation");
};

# ============================================================
# TEST: Partition Module - Zone
# ============================================================

let test_zone = fn() {
    let zone = nyworld.partition.Zone::new("zone_1");
    
    assert(zone.id == "zone_1", "Zone ID should be 'zone_1'");
    assert(zone.parent_id == null, "Parent ID should be null initially");
    assert(zone.priority == 0, "Priority should be 0 initially");
    
    # Test modification
    zone.priority = 5;
    assert(zone.priority == 5, "Priority should be modifiable");
    
    print("[PASS] Zone creation and modification");
};

# ============================================================
# TEST: Partition Module - PartitionManager
# ============================================================

let test_partition_manager = fn() {
    let pm = nyworld.partition.PartitionManager::new();
    
    assert(pm.loaded_cells.len() == 0, "Loaded cells should be empty initially");
    assert(pm.zones.len() == 0, "Zones should be empty initially");
    
    # Test mark_loaded
    let coord = nyworld.partition.GridCoord::new(5, 10);
    pm.mark_loaded(coord);
    assert(pm.loaded_cells.len() == 1, "Should have 1 loaded cell");
    assert(pm.loaded_cells["5:10"] == true, "Cell (5,10) should be loaded");
    
    # Test mark_unloaded
    pm.mark_unloaded(coord);
    assert(pm.loaded_cells["5:10"] == false, "Cell (5,10) should be unloaded");
    
    print("[PASS] PartitionManager cell management");
};

# ============================================================
# TEST: Partition Module - predict_cells
# ============================================================

let test_predict_cells = fn() {
    let pm = nyworld.partition.PartitionManager::new();
    
    # Test prediction with velocity
    let predicted = pm.predict_cells(0.0, 0.0, 100.0, 50.0);
    
    assert(predicted.len() > 0, "Should return predicted cells");
    
    let first = predicted[0];
    assert(first.x == 150, "Predicted X should be 150 (0 + 100 * 1.5)");
    assert(first.y == 75, "Predicted Y should be 75 (0 + 50 * 1.5)");
    
    print("[PASS] PartitionManager cell prediction");
};

# ============================================================
# RUN ALL TESTS
# ============================================================

let run_all_tests = fn() {
    print("========================================");
    print("NYWORLD Test Suite - Starting");
    print("========================================");
    
    test_world_config();
    test_grid_coord();
    test_zone();
    test_partition_manager();
    test_predict_cells();
    
    print("========================================");
    print("NYWORLD Test Suite - ALL TESTS PASSED");
    print("========================================");
};

# Execute tests
run_all_tests();
