# ============================================================
# NYNET - Nyx Multiplayer Infrastructure Engine Test Suite
# ============================================================
# Tests for networking, clients, authoritative server, and replication

import "engines/nynet/nynet";

# ============================================================
# TEST: NetConfig
# ============================================================

let test_net_config = fn() {
    let config = nynet.NetConfig::new();
    
    assert(config.tick_rate == 60, "Default tick rate should be 60");
    assert(config.snapshot_rate == 20, "Default snapshot rate should be 20");
    assert(config.max_players == 128, "Default max players should be 128");
    assert(config.deterministic_sync == true, "Deterministic sync should be true by default");
    
    print("[PASS] NetConfig creation and defaults");
};

# ============================================================
# TEST: Core Module - Client
# ============================================================

let test_client = fn() {
    let client = nynet.core.Client::new("player_1");
    
    assert(client.id == "player_1", "Client ID should be 'player_1'");
    assert(client.rtt_ms == 0.0, "Initial RTT should be 0.0");
    assert(client.connected == true, "New client should be connected");
    
    # Test modification
    client.rtt_ms = 45.5;
    assert(client.rtt_ms == 45.5, "RTT should be modifiable");
    
    client.connected = false;
    assert(client.connected == false, "Connection status should be modifiable");
    
    print("[PASS] Client creation and modification");
};

# ============================================================
# TEST: Core Module - InputCommand
# ============================================================

let test_input_command = fn() {
    let payload = Bytes::from_string("move_forward");
    let cmd = nynet.core.InputCommand::new("player_1", 100, payload);
    
    assert(cmd.client_id == "player_1", "Client ID should be 'player_1'");
    assert(cmd.sequence == 100, "Sequence should be 100");
    assert(cmd.payload != null, "Payload should not be null");
    
    print("[PASS] InputCommand creation");
};

# ============================================================
# TEST: Core Module - AuthoritativeServer
# ============================================================

let test_authoritative_server = fn() {
    let server = nynet.core.AuthoritativeServer::new();
    
    assert(server.clients.len() == 0, "Clients should be empty initially");
    assert(server.command_queue.len() == 0, "Command queue should be empty initially");
    assert(server.frame == 0, "Initial frame should be 0");
    
    # Test connect
    let client1 = nynet.core.Client::new("player_1");
    server.connect(client1);
    assert(server.clients.len() == 1, "Should have 1 client");
    assert(server.clients["player_1"].id == "player_1", "Client should be in map");
    
    # Test enqueue_input
    let payload = Bytes::from_string("jump");
    let cmd = nynet.core.InputCommand::new("player_1", 1, payload);
    server.enqueue_input(cmd);
    assert(server.command_queue.len() == 1, "Should have 1 command in queue");
    
    # Test tick
    let initial_frame = server.frame;
    server.tick();
    assert(server.frame == initial_frame + 1, "Frame should increment on tick");
    
    print("[PASS] AuthoritativeServer operations");
};

# ============================================================
# RUN ALL TESTS
# ============================================================

let run_all_tests = fn() {
    print("========================================");
    print("NYNET Test Suite - Starting");
    print("========================================");
    
    test_net_config();
    test_client();
    test_input_command();
    test_authoritative_server();
    
    print("========================================");
    print("NYNET Test Suite - ALL TESTS PASSED");
    print("========================================");
};

# Execute tests
run_all_tests();
