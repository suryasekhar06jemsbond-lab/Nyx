# ╔══════════════════════════════════════════════════════════════════╗
# ║                  BACKEND API SERVER (Pure Nyx!)                  ║
# ║              Replaces: Node.js, Express, Python, Flask           ║
# ╚══════════════════════════════════════════════════════════════════╝

import nyweb
import nydb
import shared.models as models

# ═══════════════════════════════════════════════════════════════════
# DATABASE CONNECTION
# ═══════════════════════════════════════════════════════════════════

let db = nydb.connect("postgres://localhost/myapp")

# Define schema in Nyx (no SQL!)
db.create_table("users", {
    id: serial primary_key,
    name: varchar(100) not_null,
    email: varchar(100) unique not_null,
    created_at: timestamp default_now
})

# ═══════════════════════════════════════════════════════════════════
# REST API SERVER
# ═══════════════════════════════════════════════════════════════════

let app = nyweb.App.new()

# Middleware
app.use(nyweb.middleware.Logger)
app.use(nyweb.middleware.CORS {
    origins: ["*"]
    methods: ["GET", "POST", "PUT", "DELETE"]
})
app.use(nyweb.middleware.JSON)

# ═══════════════════════════════════════════════════════════════════
# ROUTES
# ═══════════════════════════════════════════════════════════════════

# GET /api/users - List all users
app.get("/api/users", async fn(req, res) {
    match await db.users.all() {
        Ok(users) => res.json(users),
        Err(e) => res.status(500).json({ error: e })
    }
})

# GET /api/users/:id - Get user by ID
app.get("/api/users/:id", async fn(req, res) {
    let id: i64 = req.params.id.parse()?
    
    match await db.users.find(id) {
        Ok(Some(user)) => res.json(user),
        Ok(None) => res.status(404).json({ error: "User not found" }),
        Err(e) => res.status(500).json({ error: e })
    }
})

# POST /api/users - Create user
app.post("/api/users", async fn(req, res) {
    let user: models.User = req.body.parse()?
    
    # Validation
    if user.name.is_empty() {
        return res.status(400).json({ error: "Name required" })
    }
    if !user.email.contains("@") {
        return res.status(400).json({ error: "Invalid email" })
    }
    
    match await db.users.insert({
        name: user.name,
        email: user.email
    }) {
        Ok(created) => res.status(201).json(created),
        Err(e) => res.status(500).json({ error: e })
    }
})

# PUT /api/users/:id - Update user
app.put("/api/users/:id", async fn(req, res) {
    let id: i64 = req.params.id.parse()?
    let user: models.User = req.body.parse()?
    
    match await db.users.update(id, {
        name: user.name,
        email: user.email
    }) {
        Ok(updated) => res.json(updated),
        Err(e) => res.status(500).json({ error: e })
    }
})

# DELETE /api/users/:id - Delete user
app.delete("/api/users/:id", async fn(req, res) {
    let id: i64 = req.params.id.parse()?
    
    match await db.users.delete(id) {
        Ok(_) => res.status(204).send(),
        Err(e) => res.status(500).json({ error: e })
    }
})

# Health check endpoint
app.get("/health", fn(req, res) {
    res.json({
        status: "ok",
        timestamp: DateTime.now(),
        version: "1.0.0"
    })
})

# ═══════════════════════════════════════════════════════════════════
# ERROR HANDLING
# ═══════════════════════════════════════════════════════════════════

app.on_error(fn(err, req, res) {
    eprintln!("Error: {err}")
    res.status(500).json({
        error: "Internal server error",
        message: err.message
    })
})

# ═══════════════════════════════════════════════════════════════════
# START SERVER
# ═══════════════════════════════════════════════════════════════════

fn main() {
    let port = env.get("PORT").unwrap_or("8080")
    
    print("Starting API server on port {port}...")
    print("Database: {db.url}")
    print("Environment: {env.get('ENV').unwrap_or('development')}")
    
    app.listen(port, fn() {
        print("✅ API server running at http://localhost:{port}")
        print("📊 Health check: http://localhost:{port}/health")
        print("📚 API docs: http://localhost:{port}/api/docs")
    })
}
