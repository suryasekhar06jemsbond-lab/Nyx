# ============================================================
# NYHTTPD - Native Apache-style HTTP Server Wrapper
# ============================================================
# Production-grade HTTP server with native C performance
#
# This module wraps the native C HTTP server implementation
# for maximum performance and Apache-style compatibility.
#
# Version: 1.0.0

pub let VERSION = "1.0.0";

# ============================================================
# NATIVE FFI DECLARATIONS
# ============================================================

@native("nyx_httpd_create")
fn _httpd_create(config: Any) -> Any;

@native("nyx_httpd_route")
fn _httpd_route(server: Any, method: String, path: String, handler: fn, data: Any) -> Int;

@native("nyx_httpd_middleware")
fn _httpd_middleware(server: Any, middleware: fn, data: Any) -> Int;

@native("nyx_httpd_start")
fn _httpd_start(server: Any) -> Int;

@native("nyx_httpd_start_async")
fn _httpd_start_async(server: Any) -> Int;

@native("nyx_httpd_stop")
fn _httpd_stop(server: Any) -> Int;

@native("nyx_httpd_destroy")
fn _httpd_destroy(server: Any);

# ============================================================
# HTTP SERVER CLASS
# ============================================================

pub class HttpServer {
    let handle: Any;
    let config: Map;
    let routes: Array;
    let middlewares: Array;
    
    pub fn new(config: Map?) -> Self {
        let default_config = {
            "bind_addr": "0.0.0.0",
            "port": 8080,
            "worker_threads": 4,
            "max_connections": 1024,
            "keepalive_timeout_sec": 5,
            "request_timeout_sec": 30,
            "max_header_size": 8192,
            "max_body_size": 10485760,
            "document_root": ".",
            "log_file": "access.log",
            "error_log": "error.log",
            "enable_ssl": 0
        };
        
        let cfg = config or default_config;
        let handle = _httpd_create(cfg);
        
        return Self {
            handle: handle,
            config: cfg,
            routes: [],
            middlewares: []
        };
    }
    
    # Register a GET route
    pub fn get(self, path: String, handler: fn) {
        _httpd_route(self.handle, "GET", path, handler, null);
        self.routes = self.routes + [{"method": "GET", "path": path}];
    }
    
    # Register a POST route
    pub fn post(self, path: String, handler: fn) {
        _httpd_route(self.handle, "POST", path, handler, null);
        self.routes = self.routes + [{"method": "POST", "path": path}];
    }
    
    # Register a PUT route
    pub fn put(self, path: String, handler: fn) {
        _httpd_route(self.handle, "PUT", path, handler, null);
        self.routes = self.routes + [{"method": "PUT", "path": path}];
    }
    
    # Register a DELETE route
    pub fn delete(self, path: String, handler: fn) {
        _httpd_route(self.handle, "DELETE", path, handler, null);
        self.routes = self.routes + [{"method": "DELETE", "path": path}];
    }
    
    # Register any HTTP method route
    pub fn route(self, method: String, path: String, handler: fn) {
        _httpd_route(self.handle, method, path, handler, null);
        self.routes = self.routes + [{"method": method, "path": path}];
    }
    
    # Register middleware (runs before all routes)
    pub fn use(self, middleware: fn) {
        _httpd_middleware(self.handle, middleware, null);
        self.middlewares = self.middlewares + [middleware];
    }
    
    # Start the server (blocking)
    pub fn listen(self, port: Int?) -> Int {
        if (port) {
            self.config["port"] = port;
        }
        print("Starting Nyx HTTP Server on port " + str(self.config["port"]) + "...");
        return _httpd_start(self.handle);
    }
    
    # Start the server in background
    pub fn listen_async(self) -> Int {
        print("Starting Nyx HTTP Server (async) on port " + str(self.config["port"]) + "...");
        return _httpd_start_async(self.handle);
    }
    
    # Stop the server
    pub fn close(self) {
        _httpd_stop(self.handle);
    }
    
    # Clean up resources
    pub fn destroy(self) {
        _httpd_destroy(self.handle);
    }
}

# ============================================================
# RESPONSE BUILDER
# ============================================================

pub class Response {
    let status: Int;
    let headers: Map;
    let body: String;
    
    pub fn new() -> Self {
        return Self {
            status: 200,
            headers: {},
            body: ""
        };
    }
    
    # Set response status code
    pub fn status(self, code: Int) -> Self {
        self.status = code;
        return self;
    }
    
    # Set response header
    pub fn header(self, name: String, value: String) -> Self {
        self.headers[name] = value;
        return self;
    }
    
    # Send JSON response
    pub fn json(self, data: Any) -> Self {
        self.headers["Content-Type"] = "application/json";
        self.body = JSON.stringify(data);
        return self;
    }
    
    # Send HTML response
    pub fn html(self, content: String) -> Self {
        self.headers["Content-Type"] = "text/html; charset=utf-8";
        self.body = content;
        return self;
    }
    
    # Send plain text response
    pub fn text(self, content: String) -> Self {
        self.headers["Content-Type"] = "text/plain; charset=utf-8";
        self.body = content;
        return self;
    }
    
    # Send file response
    pub fn file(self, path: String) -> Self {
        # Native implementation will handle file reading
        return self;
    }
    
    # Send error response
    pub fn error(self, code: Int, message: String) -> Self {
        self.status = code;
        self.html("<html><body><h1>" + str(code) + " Error</h1><p>" + message + "</p></body></html>");
        return self;
    }
}

# ============================================================
# REQUEST OBJECT
# ============================================================

pub class Request {
    let method: String;
    let path: String;
    let query: Map;
    let headers: Map;
    let body: String;
    let params: Map;
    let remote_addr: String;
    let remote_port: Int;
    
    pub fn new() -> Self {
        return Self {
            method: "",
            path: "",
            query: {},
            headers: {},
            body: "",
            params: {},
            remote_addr: "",
            remote_port: 0
        };
    }
    
    # Get header value
    pub fn header(self, name: String) -> String? {
        return self.headers[name];
    }
    
    # Get query parameter
    pub fn param(self, name: String) -> String? {
        return self.params[name];
    }
    
    # Parse JSON body
    pub fn json(self) -> Any {
        return JSON.parse(self.body);
    }
}

# ============================================================
# CONVENIENCE FUNCTIONS
# ============================================================

# Create a new HTTP server with default config
pub fn create_server(config: Map?) -> HttpServer {
    return HttpServer.new(config);
}

# Quick server setup
pub fn quick_server(port: Int, routes: Map) -> HttpServer {
    let server = HttpServer.new({"port": port});
    
    for (path in keys(routes)) {
        let handler = routes[path];
        server.get(path, handler);
    }
    
    return server;
}

# ============================================================
# EXAMPLE USAGE (COMMENTED OUT)
# ============================================================

# Example 1: Basic server
# let server = HttpServer.new(null);
# server.get("/", fn(req, res) {
#     res.html("<h1>Hello from Nyx!</h1>");
# });
# server.get("/api/status", fn(req, res) {
#     res.json({"status": "ok", "uptime": 12345});
# });
# server.listen(8080);

# Example 2: With middleware
# let server = HttpServer.new(null);
# server.use(fn(req, res) {
#     print("Request: " + req.method + " " + req.path);
# });
# server.get("/", fn(req, res) {
#     res.text("Hello World");
# });
# server.listen(3000);

# Example 3: Quick server
# let server = quick_server(8080, {
#     "/": fn(req, res) { res.html("<h1>Home</h1>"); },
#     "/about": fn(req, res) { res.text("About page"); }
# });
# server.listen(null);

export { HttpServer, Request, Response, create_server, quick_server };
