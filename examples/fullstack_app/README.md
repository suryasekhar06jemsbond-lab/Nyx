# Full-Stack Application in Pure Nyx

This example demonstrates building a **complete full-stack application using ONLY Nyx** - no JavaScript, no HTML/CSS, no SQL, no other languages!

## What's Included

✅ **Frontend** (Web UI) - Nyx  
✅ **Backend** (REST API) - Nyx  
✅ **Database** (Schema + Queries) - Nyx  
✅ **Mobile App** (iOS + Android) - Nyx  
✅ **CLI Tools** - Nyx  
✅ **DevOps** (Docker, K8s) - Nyx  
✅ **Tests** - Nyx  

**ONE LANGUAGE FOR EVERYTHING!**

## Project Structure

```
fullstack_app/
├── src/
│   ├── web/              # Frontend (Web)
│   │   ├── main.ny       # Entry point
│   │   ├── pages/        # Page components
│   │   └── components/   # Reusable components
│   ├── api/              # Backend (REST API)
│   │   ├── main.ny       # Server entry
│   │   ├── routes/       # API routes
│   │   └── middleware/   # Auth, logging, etc.
│   ├── mobile/           # Mobile app
│   │   ├── main.ny       # Entry point
│   │   └── screens/      # Screen components
│   ├── database/         # Database layer
│   │   ├── schema.ny     # Schema definition
│   │   └── queries.ny    # Query functions
│   ├── cli/              # CLI tools
│   │   └── main.ny       # CLI entry
│   └── shared/           # Shared code
│       ├── models.ny     # Data models
│       └── utils.ny      # Utilities
├── deploy/
│   ├── docker.ny         # Docker config (Nyx DSL!)
│   └── k8s.ny            # Kubernetes config
├── tests/
│   ├── unit/             # Unit tests
│   ├── integration/      # Integration tests
│   └── e2e/              # End-to-end tests
├── build.ny              # Build configuration
└── README.md             # This file
```

## Building

```bash
# Build everything
nyx build

# Build specific targets
nyx build --target web     # Frontend only
nyx build --target api     # Backend only
nyx build --target mobile  # Mobile apps
```

## Running

```bash
# Development mode (hot reload)
nyx dev

# Production mode
nyx run --env production

# Run specific components
nyx dev web    # Frontend dev server
nyx dev api    # Backend API server
```

## Testing

```bash
# Run all tests
nyx test

# Run specific test suites
nyx test unit
nyx test integration
nyx test e2e
```

## Deployment

```bash
# Deploy to production
nyx deploy --env production

# Deploy specific components
nyx deploy api
nyx deploy web
```

## Key Features

### 1. Type Safety Across Stack
```nyx
# Shared data model (used by frontend, backend, mobile)
class User {
    id: i64
    name: String
    email: String
    created_at: DateTime
}

# API endpoint (backend)
#[get("/api/users/{id}")]
fn get_user(id: i64) -> Json<User> {
    return db.users.find(id)  # Type-safe query!
}

# Frontend usage - SAME TYPES!
let user: User = await api.get_user(42)
print(user.name)  # Autocomplete works!
```

### 2. Code Sharing
```nyx
# Shared validation logic
fn validate_email(email: String) -> Result<()> {
    if !email.contains("@") {
        return Err("Invalid email")
    }
    return Ok(())
}

# Used in frontend form validation
input.on_validate(|email| validate_email(email))

# Used in backend API validation
#[post("/api/users")]
fn create_user(email: String) -> Result<User> {
    validate_email(email)?  # Same function!
    # ...
}
```

### 3. Unified Build System
```nyx
# build.ny - configure EVERYTHING
project {
    name: "my-app"
    version: "1.0.0"
    
    targets: {
        web: {
            entry: "src/web/main.ny"
            output: "dist/web"
            features: ["hot-reload"]
        }
        api: {
            entry: "src/api/main.ny"
            output: "dist/api"
            optimize: true
        }
        mobile: {
            entry: "src/mobile/main.ny"
            platforms: ["ios", "android"]
        }
    }
}
```

## Comparison

### Traditional Stack:
```
Frontend:      React (JS/TS) + HTML + CSS
Backend:       Node.js (JS) or Python
Database:      SQL
Mobile:        Swift + Kotlin
Config:        YAML + JSON
Scripts:       Bash/PowerShell

= 8+ LANGUAGES
```

### Nyx Stack:
```
Everything:    Nyx

= 1 LANGUAGE! 🎉
```

## Getting Started

1. **Install Nyx**:
   ```bash
   curl -sSL https://nyx-lang.org/install | bash
   ```

2. **Clone this example**:
   ```bash
   nyx new my-app --template fullstack
   cd my-app
   ```

3. **Install dependencies**:
   ```bash
   nyx install
   ```

4. **Start development**:
   ```bash
   nyx dev
   ```

5. **Open browser**:
   - Web: http://localhost:3000
   - API: http://localhost:8080

## Next Steps

- Read the [Nyx Book](https://nyx-lang.org/book)
- Explore [API Documentation](https://docs.nyx-lang.org)
- Join [Discord Community](https://discord.gg/nyx)

**Welcome to the future: One language for everything!** 🚀
