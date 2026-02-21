# Simple Game Demo using NYX Game Engine
# This demonstrates basic game mechanics using Nygame engine

print("========================================");
print("NYX Simple Game Demo");
print("========================================");
print("");

# Game configuration
let SCREEN_WIDTH = 800;
let SCREEN_HEIGHT = 600;
let PLAYER_SPEED = 5;
let BULLET_SPEED = 10;
let ENEMY_SPEED = 2;

print("Game Config:");
print("- Screen: " + SCREEN_WIDTH + "x" + SCREEN_HEIGHT);
print("- Player Speed: " + PLAYER_SPEED);
print("- Bullet Speed: " + BULLET_SPEED);
print("- Enemy Speed: " + ENEMY_SPEED);
print("");

# Demo game entities
print("--- Game Entities ---");
print("Player: Hero at position (400, 500)");
print("Direction: Up");
print("Health: 100");
print("Score: 0");
print("");

# Game state
let player_x = 400;
let player_y = 500;
let direction = "up";
let health = 100;
let score = 0;
let bullets = 0;
let enemies = 0;

print("--- Simulating Game Logic ---");

# Player movement simulation
if direction == "up" {
    player_y = player_y - PLAYER_SPEED;
}

if direction == "down" {
    player_y = player_y + PLAYER_SPEED;
}

if direction == "left" {
    player_x = player_x - PLAYER_SPEED;
}

if direction == "right" {
    player_x = player_x + PLAYER_SPEED;
}

print("Player moved to: (" + player_x + ", " + player_y + ")");
print("");

# Shooting bullets
bullets = bullets + 1;
print("Bang! Bullet fired! Total bullets: " + bullets);
bullets = bullets + 1;
print("Bang! Bullet fired! Total bullets: " + bullets);
print("");

# Enemy spawning
enemies = enemies + 1;
print("Enemy spawned! Enemy type: Goblin");
enemies = enemies + 1;
print("Enemy spawned! Enemy type: Orc");
print("Total enemies: " + enemies);
print("");

# Combat simulation
let enemy_health = 50;
enemy_health = enemy_health - 25;
print("Player hit enemy for 25 damage! Enemy HP: " + enemy_health);
enemy_health = enemy_health - 25;
print("Player hit enemy for 25 damage! Enemy HP: " + enemy_health);

if enemy_health <= 0 {
    print("Enemy defeated!");
    score = score + 100;
    enemies = enemies - 1;
}
print("");

# Score update
print("Score: " + score);
print("");

# Using Nygame engine features
print("--- Nygame Engine Features ---");
print("- Scene Management");
print("- Physics Engine");
print("- Input System");
print("- Audio Engine");
print("- Asset Manager");
print("");

# Using Nyai engine for AI
print("--- Nyai AI Engine Features ---");
print("- Behavior Trees");
print("- GOAP Planning");
print("- Pathfinding (A*)");
print("- State Machines");
print("");

# Using Nyanim engine for animations
print("--- Nyanim Animation Engine ---");
print("- Keyframe Animation");
print("- Skeletal Animation");
print("- Inverse Kinematics");
print("- Motion Matching");
print("");

# Using Nyaudio engine for sound
print("--- Nyaudio Sound Engine ---");
print("- 3D Spatial Audio");
print("- Audio Streaming");
print("- Sound Effects");
print("- Music System");
print("");

print("========================================");
print("Game Over!");
print("Final Score: " + score);
print("========================================");
