/**
 * NyWeb Development Server
 * Serves the NyWeb website for browser viewing
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = 8080;
const HOST = 'localhost';

// HTML generated from Nyx website.ny
const HTML = `<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>NyWeb Framework</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
            color: #eee;
            min-height: 100vh;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            padding: 40px 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 60px;
        }
        .title {
            font-size: 3.5em;
            color: #e94560;
            text-shadow: 0 0 30px rgba(233, 69, 96, 0.5);
            margin-bottom: 15px;
        }
        .subtitle {
            font-size: 1.5em;
            color: #4ecdc4;
        }
        .nav {
            display: flex;
            justify-content: center;
            gap: 20px;
            margin-top: 30px;
            flex-wrap: wrap;
        }
        .nav-link {
            padding: 12px 30px;
            background: #e94560;
            color: #fff;
            text-decoration: none;
            border-radius: 25px;
            transition: all 0.3s ease;
        }
        .nav-link:hover {
            background: #ff6b6b;
            transform: translateY(-3px);
            box-shadow: 0 5px 20px rgba(233, 69, 96, 0.4);
        }
        .hero {
            background: rgba(255, 255, 255, 0.05);
            padding: 60px;
            border-radius: 20px;
            text-align: center;
            border: 1px solid rgba(255, 255, 255, 0.1);
            margin-bottom: 40px;
        }
        .hero-title {
            font-size: 2.5em;
            color: #fff;
            margin-bottom: 20px;
        }
        .hero-text {
            font-size: 1.2em;
            color: #aaa;
            line-height: 1.8;
            max-width: 800px;
            margin: 0 auto;
        }
        .stats-row {
            display: flex;
            justify-content: space-around;
            flex-wrap: wrap;
            gap: 30px;
            padding: 40px;
            background: rgba(233, 69, 96, 0.1);
            border-radius: 15px;
            margin: 40px 0;
        }
        .stat-item {
            text-align: center;
        }
        .stat-number {
            font-size: 3em;
            color: #e94560;
            font-weight: bold;
        }
        .stat-label {
            color: #888;
            margin-top: 10px;
        }
        .features-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 30px;
            margin: 50px 0;
        }
        .feature-card {
            background: rgba(255, 255, 255, 0.05);
            padding: 35px;
            border-radius: 15px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            transition: all 0.3s ease;
        }
        .feature-card:hover {
            transform: translateY(-5px);
            border-color: #e94560;
            box-shadow: 0 10px 30px rgba(233, 69, 96, 0.2);
        }
        .feature-title {
            font-size: 1.4em;
            color: #e94560;
            margin-bottom: 15px;
        }
        .feature-text {
            color: #aaa;
            line-height: 1.7;
        }
        .cta-section {
            text-align: center;
            margin: 60px 0;
        }
        .btn-primary {
            display: inline-block;
            padding: 18px 50px;
            background: #e94560;
            color: #fff;
            border: none;
            border-radius: 30px;
            font-size: 1.2em;
            cursor: pointer;
            transition: all 0.3s ease;
            text-decoration: none;
        }
        .btn-primary:hover {
            background: #ff6b6b;
            transform: scale(1.05);
            box-shadow: 0 5px 25px rgba(233, 69, 96, 0.4);
        }
        .footer {
            text-align: center;
            padding: 40px;
            margin-top: 60px;
            border-top: 1px solid rgba(255, 255, 255, 0.1);
            color: #666;
        }
        .code-block {
            background: rgba(0, 0, 0, 0.3);
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
            overflow-x: auto;
        }
        .code-block code {
            color: #4ecdc4;
            font-family: 'Fira Code', 'Consolas', monospace;
        }
        @media (max-width: 768px) {
            .title { font-size: 2.5em; }
            .hero { padding: 30px; }
            .hero-title { font-size: 1.8em; }
            .nav { flex-direction: column; align-items: center; }
        }
    </style>
</head>
<body>
    <div class="container">
        <header class="header">
            <h1 class="title">🚀 NyWeb Framework</h1>
            <p class="subtitle">Build Modern Web Apps in Nyx</p>
            <nav class="nav">
                <a href="#home" class="nav-link">Home</a>
                <a href="#features" class="nav-link">Features</a>
                <a href="#docs" class="nav-link">Docs</a>
                <a href="#demo" class="nav-link">Demo</a>
            </nav>
        </header>

        <section class="hero" id="home">
            <h2 class="hero-title">Build Modern Web Apps in Nyx</h2>
            <p class="hero-text">
                A complete full-stack framework with HTTP server, ORM, authentication, 
                reactive UI components, and frontend compiler. Write everything in pure Nyx syntax.
            </p>
        </section>

        <div class="stats-row">
            <div class="stat-item">
                <div class="stat-number">100%</div>
                <div class="stat-label">Nyx Code</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">0</div>
                <div class="stat-label">Dependencies</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">Fast</div>
                <div class="stat-label">Performance</div>
            </div>
            <div class="stat-item">
                <div class="stat-number">Full</div>
                <div class="stat-label">Stack</div>
            </div>
        </div>

        <section id="features">
            <h2 class="title" style="text-align: center; font-size: 2em;">Framework Features</h2>
            <div class="features-grid">
                <div class="feature-card">
                    <h3 class="feature-title">⚡ HTTP Server</h3>
                    <p class="feature-text">Built-in async server with routing, middleware, and WebSocket support.</p>
                </div>
                <div class="feature-card">
                    <h3 class="feature-title">🗄️ ORM Database</h3>
                    <p class="feature-text">SQLite integration with migrations, models, and query builder.</p>
                </div>
                <div class="feature-card">
                    <h3 class="feature-title">🔐 Authentication</h3>
                    <p class="feature-text">Secure sessions, bcrypt hashing, CSRF protection.</p>
                </div>
                <div class="feature-card">
                    <h3 class="feature-title">🎨 UI Components</h3>
                    <p class="feature-text">Reactive components with Virtual DOM and SSR support.</p>
                </div>
                <div class="feature-card">
                    <h3 class="feature-title">📦 Frontend Compiler</h3>
                    <p class="feature-text">Compile to JavaScript/WASM with hot reload support.</p>
                </div>
                <div class="feature-card">
                    <h3 class="feature-title">🚀 Production Ready</h3>
                    <p class="feature-text">Rate limiting, caching, logging, and error handling.</p>
                </div>
            </div>
        </section>

        <section id="docs" style="margin: 60px 0;">
            <h2 class="title" style="text-align: center; font-size: 2em;">Quick Start</h2>
            <div class="code-block">
                <code>
# Create a new NyWeb application<br>
let app = nyweb.Application.new("MyApp")<br><br>
# Define a route<br>
app.get("/") -> fn(request) {<br>
&nbsp;&nbsp;&nbsp;&nbsp;return nyweb.Response.html(200, "<h1>Hello World</h1>")<br>
}<br><br>
# Start the server<br>
app.run("localhost", 8080)
                </code>
            </div>
        </section>

        <section class="cta-section" id="demo">
            <a href="https://github.com/suryasekhar06jemsbond-lab/cyber" class="btn-primary">
                Get Started on GitHub
            </a>
        </section>

        <footer class="footer">
            <p>NyWeb Framework - Built with ❤️ in Nyx Language</p>
            <p>© 2026 Surya Sekhar Roy. All Rights Reserved.</p>
        </footer>
    </div>

    <script>
        // Smooth scrolling for navigation
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                const target = document.querySelector(this.getAttribute('href'));
                if (target) {
                    target.scrollIntoView({ behavior: 'smooth' });
                }
            });
        });

        // Add animation on scroll
        const observer = new IntersectionObserver((entries) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.style.opacity = '1';
                    entry.target.style.transform = 'translateY(0)';
                }
            });
        }, { threshold: 0.1 });

        document.querySelectorAll('.feature-card, .stat-item').forEach(el => {
            el.style.opacity = '0';
            el.style.transform = 'translateY(20px)';
            el.style.transition = 'all 0.5s ease';
            observer.observe(el);
        });
    </script>
</body>
</html>`;

// Create HTTP server
const server = http.createServer((req, res) => {
    console.log(`[${new Date().toISOString()}] ${req.method} ${req.url}`);
    
    if (req.url === '/' || req.url === '/index.html') {
        res.writeHead(200, { 'Content-Type': 'text/html' });
        res.end(HTML);
    } else if (req.url === '/api/status') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'ok',
            framework: 'NyWeb',
            version: '1.0.0',
            features: ['http-server', 'orm', 'auth', 'vdom', 'compiler']
        }));
    } else if (req.url === '/api/features') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            features: [
                { name: 'HTTP Server', icon: '⚡', description: 'Async server with routing' },
                { name: 'ORM Database', icon: '🗄️', description: 'SQLite integration' },
                { name: 'Authentication', icon: '🔐', description: 'Secure sessions' },
                { name: 'UI Components', icon: '🎨', description: 'Virtual DOM' },
                { name: 'Compiler', icon: '📦', description: 'JS/WASM output' },
                { name: 'Production', icon: '🚀', description: 'Full featured' }
            ]
        }));
    } else {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('Not Found');
    }
});

server.listen(PORT, HOST, () => {
    console.log('===========================================');
    console.log('  🚀 NyWeb Framework Server');
    console.log('===========================================');
    console.log('');
    console.log(`Server running at: http://${HOST}:${PORT}`);
    console.log('');
    console.log('Routes:');
    console.log(`  GET http://${HOST}:${PORT}/              - Home page`);
    console.log(`  GET http://${HOST}:${PORT}/api/status    - API status`);
    console.log(`  GET http://${HOST}:${PORT}/api/features  - Features list`);
    console.log('');
    console.log('Open your browser and visit: http://localhost:8080');
    console.log('');
    console.log('Press Ctrl+C to stop the server');
    console.log('');
});
