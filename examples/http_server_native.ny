/* Nyx Native HTTP Server Example */

use nyhttpd;

let server = nyhttpd.HttpServer.new({
    "port": 8080,
    "worker_threads": 4,
    "document_root": "./public"
});

/* Logging middleware */
server.use(fn(req, res) {
    let timestamp = time();
    print("[" + str(timestamp) + "] " + req.method + " " + req.path);
});

/* Home page */
server.get("/", fn(req, res) {
    res.html("
<!DOCTYPE html>
<html>
<head>
    <title>Nyx Native HTTP Server</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #333; }
        .status { background: #4CAF50; color: white; padding: 10px; border-radius: 5px; }
        .endpoint { background: #f0f0f0; padding: 15px; margin: 10px 0; border-left: 4px solid #2196F3; }
        code { background: #eee; padding: 2px 5px; border-radius: 3px; }
    </style>
</head>
<body>
    <h1>🚀 Nyx Native HTTP Server</h1>
    <div class=\"status\">✅ Server is running on port 8080</div>
    
    <h2>Available Endpoints:</h2>
    
    <div class=\"endpoint\">
        <strong>GET /</strong><br>
        This home page
    </div>
    
    <div class=\"endpoint\">
        <strong>GET /api/status</strong><br>
        Server status (JSON)
    </div>
    
    <div class=\"endpoint\">
        <strong>GET /api/hello/:name</strong><br>
        Personalized greeting (JSON)
    </div>
    
    <div class=\"endpoint\">
        <strong>POST /api/echo</strong><br>
        Echo back request body
    </div>
    
    <div class=\"endpoint\">
        <strong>GET /benchmark</strong><br>
        Performance benchmark page
    </div>
    
    <h2>Performance:</h2>
    <p>This server is built with native C code for Apache-level performance.</p>
    <ul>
        <li>Multi-threaded worker pool</li>
        <li>Event-driven I/O</li>
        <li>Zero-copy static file serving</li>
        <li>HTTP/1.1 keep-alive support</li>
    </ul>
    
    <p><a href=\"/benchmark\">Run benchmark →</a></p>
</body>
</html>
    ");
});

/* API endpoint - Status */
server.get("/api/status", fn(req, res) {
    res.json({
        "status": "online",
        "server": "Nyx Native HTTPd",
        "version": "1.0.0",
        "uptime": 12345,
        "requests_served": 9876,
        "memory_mb": 24,
        "cpu_percent": 5.2
    });
});

/* API endpoint - Hello */
server.get("/api/hello", fn(req, res) {
    let name = req.param("name") or "World";
    res.json({
        "message": "Hello, " + name + "!",
        "timestamp": time(),
        "server": "Nyx Native HTTPd"
    });
});

/* API endpoint - Echo (POST) */
server.post("/api/echo", fn(req, res) {
    res.json({
        "method": req.method,
        "path": req.path,
        "headers": req.headers,
        "body": req.body,
        "echoed_at": time()
    });
});

/* Benchmark page */
server.get("/benchmark", fn(req, res) {
    res.html("
<!DOCTYPE html>
<html>
<head>
    <title>Nyx HTTP Server - Benchmark</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto; padding: 20px; }
        .result { background: #e8f5e9; padding: 15px; margin: 10px 0; border-radius: 5px; }
        button { background: #2196F3; color: white; padding: 10px 20px; border: none; 
                 border-radius: 5px; cursor: pointer; font-size: 16px; }
        button:hover { background: #1976D2; }
        #status { margin: 20px 0; font-weight: bold; }
    </style>
</head>
<body>
    <h1>⚡ Performance Benchmark</h1>
    <p>This will send 1000 concurrent requests to test server performance</p>
    
    <button onclick=\"runBenchmark()\">Run Benchmark</button>
    <div id=\"status\"></div>
    <div id=\"results\"></div>
    
    <script>
    async function runBenchmark() {
        const status = document.getElementById('status');
        const results = document.getElementById('results');
        
        status.textContent = 'Running benchmark...';
        results.innerHTML = '';
        
        const start = performance.now();
        const requests = [];
        
        for (let i = 0; i < 1000; i++) {
            requests.push(fetch('/api/status').then(r => r.json()));
        }
        
        try {
            await Promise.all(requests);
            const duration = performance.now() - start;
            const rps = (1000 / (duration / 1000)).toFixed(2);
            
            status.textContent = '✅ Benchmark Complete!';
            results.innerHTML = `
                <div class=\"result\">
                    <h3>Results:</h3>
                    <p><strong>Total Requests:</strong> 1000</p>
                    <p><strong>Duration:</strong> ${duration.toFixed(2)} ms</p>
                    <p><strong>Requests/sec:</strong> ${rps}</p>
                    <p><strong>Avg latency:</strong> ${(duration/1000).toFixed(2)} ms</p>
                </div>
            `;
        } catch (error) {
            status.textContent = '❌ Benchmark failed: ' + error;
        }
    }
    </script>
</body>
</html>
    ");
});

/* 404 handler */
server.get("*", fn(req, res) {
    res.error(404, "Page not found: " + req.path);
});

/* Start the server */
print("=".repeat(70));
print("Nyx Native HTTP Server");
print("Apache-style high-performance web server");
print("=".repeat(70));
print("");

server.listen(8080);
