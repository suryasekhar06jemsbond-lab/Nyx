# NyWeb Website Test
# A simple website using the NyWeb framework

import nyweb

# Create the web application
let app = nyweb::Application::new("NyWeb Demo Site")

# Configure the app
app.debug = true
app.templates_dir = "./templates"
app.static_dir = "./static"

# Home page route
app.get("/") -> fn(request) {
    let html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>NyWeb Demo</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body { 
                font-family: 'Segoe UI', Tahoma, sans-serif;
                background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
                color: #eee;
                min-height: 100vh;
                display: flex;
                flex-direction: column;
                align-items: center;
                padding: 40px;
            }
            .container {
                max-width: 900px;
                width: 100%;
            }
            header {
                text-align: center;
                margin-bottom: 40px;
            }
            h1 {
                color: #e94560;
                font-size: 3em;
                margin-bottom: 10px;
                text-shadow: 0 0 20px rgba(233, 69, 96, 0.5);
            }
            .subtitle {
                color: #4ecdc4;
                font-size: 1.3em;
            }
            .features {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
                gap: 25px;
                margin: 40px 0;
            }
            .feature {
                background: rgba(255, 255, 255, 0.05);
                padding: 30px;
                border-radius: 15px;
                border: 1px solid rgba(255, 255, 255, 0.1);
                transition: all 0.3s ease;
            }
            .feature:hover {
                transform: translateY(-5px);
                border-color: #e94560;
                box-shadow: 0 10px 30px rgba(233, 69, 96, 0.2);
            }
            .feature h3 {
                color: #e94560;
                margin-bottom: 15px;
                font-size: 1.3em;
            }
            .feature p {
                color: #aaa;
                line-height: 1.6;
            }
            .stats {
                display: flex;
                justify-content: space-around;
                flex-wrap: wrap;
                gap: 20px;
                margin: 40px 0;
                padding: 30px;
                background: rgba(233, 69, 96, 0.1);
                border-radius: 15px;
            }
            .stat {
                text-align: center;
            }
            .stat-number {
                font-size: 2.5em;
                color: #e94560;
                font-weight: bold;
            }
            .stat-label {
                color: #888;
                margin-top: 5px;
            }
            .cta {
                text-align: center;
                margin: 40px 0;
            }
            .btn {
                display: inline-block;
                padding: 15px 40px;
                background: #e94560;
                color: white;
                text-decoration: none;
                border-radius: 30px;
                font-size: 1.1em;
                transition: all 0.3s ease;
                border: none;
                cursor: pointer;
            }
            .btn:hover {
                background: #ff6b6b;
                transform: scale(1.05);
            }
            footer {
                text-align: center;
                padding: 30px;
                color: #666;
                border-top: 1px solid rgba(255, 255, 255, 0.1);
                margin-top: 40px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <header>
                <h1>🚀 NyWeb Framework</h1>
                <p class="subtitle">Build Modern Web Apps in Nyx</p>
            </header>
            
            <div class="features">
                <div class="feature">
                    <h3>⚡ HTTP Server</h3>
                    <p>Built-in async server with routing, middleware, and WebSocket support.</p>
                </div>
                <div class="feature">
                    <h3>🗄️ ORM Database</h3>
                    <p>SQLite integration with migrations, models, and query builder.</p>
                </div>
                <div class="feature">
                    <h3>🔐 Authentication</h3>
                    <p>Secure sessions, bcrypt hashing, CSRF protection.</p>
                </div>
                <div class="feature">
                    <h3>🎨 UI Components</h3>
                    <p>Reactive components with Virtual DOM and SSR support.</p>
                </div>
                <div class="feature">
                    <h3>📦 Frontend Compiler</h3>
                    <p>Compile to JavaScript/WASM with hot reload support.</p>
                </div>
                <div class="feature">
                    <h3>🚀 Production Ready</h3>
                    <p>Rate limiting, caching, logging, and error handling.</p>
                </div>
            </div>
            
            <div class="stats">
                <div class="stat">
                    <div class="stat-number">100%</div>
                    <div class="stat-label">Nyx Code</div>
                </div>
                <div class="stat">
                    <div class="stat-number">0</div>
                    <div class="stat-label">Dependencies</div>
                </div>
                <div class="stat">
                    <div class="stat-number">Fast</div>
                    <div class="stat-label">Performance</div>
                </div>
                <div class="stat">
                    <div class="stat-number">Full</div>
                    <div class="stat-label">Stack</div>
                </div>
            </div>
            
            <div class="cta">
                <button class="btn" onclick="alert('Welcome to NyWeb!')">Get Started</button>
            </div>
            
            <footer>
                <p>NyWeb Framework - Built with ❤️ in Nyx Language</p>
                <p>© 2026 Surya Sekhar Roy. All Rights Reserved.</p>
            </footer>
        </div>
    </body>
    </html>
    """
    
    return nyweb::Response::html(200, html)
}

# About page route
app.get("/about") -> fn(request) {
    let html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>About - NyWeb</title>
        <style>
            body { 
                font-family: 'Segoe UI', sans-serif;
                background: #16213e;
                color: #eee;
                padding: 40px;
            }
            h1 { color: #e94560; }
            p { color: #aaa; line-height: 1.8; }
            a { color: #4ecdc4; }
        </style>
    </head>
    <body>
        <h1>About NyWeb</h1>
        <p>NyWeb is a full-stack web framework for the Nyx programming language.</p>
        <p>It combines the power of Django, Flask, and FastAPI into one unified framework.</p>
        <p><a href="/">← Back to Home</a></p>
    </body>
    </html>
    """
    return nyweb::Response::html(200, html)
}

# API endpoint example
app.get("/api/status") -> fn(request) {
    let json = """{"status": "ok", "framework": "NyWeb", "version": "1.0.0"}"""
    return nyweb::Response::json(200, json)
}

# Run the server
print("Starting NyWeb Demo Server...")
print("Visit http://localhost:8080")

app.run("localhost", 8080)
