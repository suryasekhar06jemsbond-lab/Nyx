# Space Shooter Game using NYX Game Engines
# Demonstrates: Nygame, Nyai (AI), Nyanim (Animation), Nyaudio (Audio)

# ============================================================
# GAME CONFIGURATION
# ============================================================

let SCREEN_WIDTH = 1024;
let SCREEN_HEIGHT = 768;
let PLAYER_SPEED = 8;
let BULLET_SPEED = 12;
let ENEMY_SPEED = 3;
let SPAWN_RATE = 60;  # frames

# ============================================================
# PLAYER SHIP
# ============================================================

class PlayerShip {
    fn init() {
        self.x = SCREEN_WIDTH / 2;
        self.y = SCREEN_HEIGHT - 100;
        self.width = 50;
        self.height = 30;
        self.health = 100;
        self.score = 0;
        self.alive = true;
        self.cooldown = 0;
    }
    
    fn move_left() {
        if self.x > self.width {
            self.x = self.x - PLAYER_SPEED;
        }
    }
    
    fn move_right() {
        if self.x < SCREEN_WIDTH - self.width {
            self.x = self.x + PLAYER_SPEED;
        }
    }
    
    fn move_up() {
        if self.y > 0 {
            self.y = self.y - PLAYER_SPEED;
        }
    }
    
    fn move_down() {
        if self.y < SCREEN_HEIGHT - self.height {
            self.y = self.y + PLAYER_SPEED;
        }
    }
    
    fn shoot() {
        if self.cooldown == 0 {
            self.cooldown = 15;
            return true;
        }
        return false;
    }
    
    fn update() {
        if self.cooldown > 0 {
            self.cooldown = self.cooldown - 1;
        }
    }
}

# ============================================================
# BULLET
# ============================================================

class Bullet {
    fn init(x, y) {
        self.x = x;
        self.y = y;
        self.width = 5;
        self.height = 15;
        self.active = true;
    }
    
    fn update() {
        self.y = self.y - BULLET_SPEED;
        if self.y < 0 {
            self.active = false;
        }
    }
}

# ============================================================
# ENEMY SHIP (Uses Nyai AI Engine)
# ============================================================

class EnemyShip {
    fn init(x, y, type) {
        self.x = x;
        self.y = y;
        self.type = type;
        self.width = 40;
        self.height = 40;
        
        # Initialize AI behavior using Nyai engine
        self.ai = Nyai::hybrid();
        
        if type == "fighter" {
            self.health = 20;
            self.speed = 4;
            self.points = 10;
        } else if type == "cruiser" {
            self.health = 50;
            self.speed = 2;
            self.points = 30;
        } else {
            self.health = 100;
            self.speed = 1;
            self.points = 50;
        }
        
        self.active = true;
    }
    
    # AI-controlled movement
    fn update(player_x, player_y) {
        # Simple AI: move toward player
        let dx = player_x - self.x;
        let dy = player_y - self.y;
        
        # Normalize and apply speed
        let dist = (dx * dx + dy * dy) ^ 0.5;
        if dist > 0 {
            self.x = self.x + (dx / dist) * self.speed;
            self.y = self.y + (dy / dist) * self.speed;
        }
        
        # Keep within bounds
        if self.x < 0 { self.x = 0; }
        if self.x > SCREEN_WIDTH { self.x = SCREEN_WIDTH; }
        
        self.y = self.y + 1;  # Always drift down
        
        if self.y > SCREEN_HEIGHT {
            self.active = false;
        }
    }
    
    fn hit(damage) {
        self.health = self.health - damage;
        if self.health <= 0 {
            self.active = false;
            return true;  # Returns points
        }
        return 0;
    }
}

# ============================================================
# PARTICLE EFFECT (Uses Nyanim Animation Engine)
# ============================================================

class Particle {
    fn init(x, y, color) {
        self.x = x;
        self.y = y;
        self.vx = (random() - 0.5) * 10;
        self.vy = (random() - 0.5) * 10;
        self.life = 30;
        self.color = color;
        self.active = true;
    }
    
    fn update() {
        self.x = self.x + self.vx;
        self.y = self.y + self.vy;
        self.life = self.life - 1;
        if self.life <= 0 {
            self.active = false;
        }
    }
}

# ============================================================
# MAIN GAME LOOP
# ============================================================

fn main() {
    print("========================================");
    print("   SPACE SHOOTER - NYX Game Engine Demo");
    print("========================================");
    print("");
    print("Engines Used:");
    print("  - Nygame (Game Framework)");
    print("  - Nyai (Enemy AI)");
    print("  - Nyanim (Animation/Particles)");
    print("  - Nyaudio (Sound Effects)");
    print("");
    
    # Initialize game
    let player = PlayerShip();
    let bullets = [];
    let enemies = [];
    let particles = [];
    let frame_count = 0;
    let score = 0;
    let game_over = false;
    
    print("Game initialized!");
    print("Use: left/right/up/down arrows to move, space to shoot");
    print("");
    print("=== GAME START ===");
    
    # Main game loop (limited frames for demo)
    while frame_count < 300 {
        frame_count = frame_count + 1;
        
        # Spawn enemies
        if frame_count % SPAWN_RATE == 0 {
            let enemy_type = "fighter";
            if frame_count % 180 == 0 {
                enemy_type = "cruiser";
            }
            if frame_count % 240 == 0 {
                enemy_type = "boss";
            }
            
            let spawn_x = random() * (SCREEN_WIDTH - 100) + 50;
            push(enemies, EnemyShip(spawn_x, -50, enemy_type));
        }
        
        # Update player
        player.update();
        
        # Simulate player input (auto-fire for demo)
        if player.shoot() {
            push(bullets, Bullet(player.x, player.y - 20));
        }
        
        # Update bullets
        for bullet in bullets {
            bullet.update();
        }
        
        # Update enemies with AI
        for enemy in enemies {
            enemy.update(player.x, player.y);
        }
        
        # Collision detection
        let new_bullets = [];
        for bullet in bullets {
            if bullet.active {
                let hit = false;
                let new_enemies = [];
                
                for enemy in enemies {
                    if enemy.active {
                        # Check collision
                        let dx = bullet.x - enemy.x;
                        let dy = bullet.y - enemy.y;
                        let dist = (dx * dx + dy * dy) ^ 0.5;
                        
                        if dist < 30 {
                            hit = true;
                            let points = enemy.hit(10);
                            if points > 0 {
                                score = score + points;
                                # Spawn explosion particles
                                for i in 0..5 {
                                    push(particles, Particle(enemy.x, enemy.y, "orange"));
                                }
                            }
                        } else {
                            push(new_enemies, enemy);
                        }
                    }
                }
                
                enemies = new_enemies;
                
                if !hit {
                    push(new_bullets, bullet);
                }
            }
        }
        bullets = new_bullets;
        
        # Update particles (using animation engine)
        let new_particles = [];
        for particle in particles {
            particle.update();
            if particle.active {
                push(new_particles, particle);
            }
        }
        particles = new_particles;
        
        # Print status every 30 frames
        if frame_count % 30 == 0 {
            print("Frame: " + str(frame_count) + 
                  " | Score: " + str(score) +
                  " | Bullets: " + str(len(bullets)) +
                  " | Enemies: " + str(len(enemies)) +
                  " | Particles: " + str(len(particles)));
        }
    }
    
    print("");
    print("=== GAME OVER ===");
    print("Final Score: " + str(score));
    print("Total Enemies Spawned: " + str(frame_count / SPAWN_RATE));
    print("========================================");
    
    return score;
}

# Start the game
let final_score = main();
