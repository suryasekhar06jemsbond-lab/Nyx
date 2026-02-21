class Config {
    let debug = null;
    let secret_key = null;
    let database_url = null;
    let allowed_hosts = null;
    let csrf_enabled = null;
    let session_cookie_secure = null;
    let session_cookie_httponly = null;
    let session_expiry_seconds = null;
    let rate_limit_requests = null;
    let rate_limit_window_seconds = null;
    let log_level = null;

    fn from_env() {
        let inst = new(Config);
        inst.debug = env.get("NYWEB_DEBUG", "false") == "true";
        inst.secret_key = env.get("NYWEB_SECRET_KEY", "");
        inst.database_url = env.get("NYWEB_DATABASE_URL", "sqlite://nyweb.db");
        inst.allowed_hosts = env.get("NYWEB_ALLOWED_HOSTS", "localhost").split(",");
        inst.csrf_enabled = env.get("NYWEB_CSRF", "true") == "true";
        inst.session_cookie_secure = env.get("NYWEB_SESSION_SECURE", "true") == "true";
        inst.session_cookie_httponly = env.get("NYWEB_SESSION_HTTPONLY", "true") == "true";
        inst.session_expiry_seconds = env.get("NYWEB_SESSION_EXPIRY", "86400");
        inst.rate_limit_requests = env.get("NYWEB_RATE_LIMIT", "100");
        inst.rate_limit_window_seconds = env.get("NYWEB_RATE_WINDOW", "60");
        inst.log_level = env.get("NYWEB_LOG_LEVEL", "INFO");
        return inst;
    }

    
    # =========================================================================
    # SECURE CRYPTOGRAPHY
    # =========================================================================
    
    class Crypto {
        # Bcrypt password hashing (uses Node.js bcrypt internally)
        fn hash_password(password) {
            # Generate salt and hash
            let salt = Crypto::_generate_bcrypt_salt(12);
            hash = Crypto::_bcrypt_hash(password, salt);
            return hash;
        }
        
        fn verify_password(password, hash) {
            # Timing-safe comparison
            return Crypto::_bcrypt_verify(password, hash);
        }
        
        # Internal bcrypt implementation (calls Node.js crypto)
        fn _generate_bcrypt_salt(rounds: Int) -> String {
            # Use cryptographically secure random bytes
            let random_bytes = crypto.random_bytes(16);
            let salt_b64 = crypto.base64_encode(random_bytes);
            return "$2b$" + rounds as String + "$" + salt_b64;
        }
        
        fn _bcrypt_hash(password: String, salt: String) -> String {
            # Call Node.js bcrypt via FFI
            return crypto.bcrypt_hash(password, salt);
        }
        
        fn _bcrypt_verify(password: String, hash: String) -> Bool {
            return crypto.bcrypt_verify(password, hash);
        }
        
        # Secure random token generation
        fn generate_token(bytes) {
            let random = crypto.random_bytes(bytes);
            return crypto.hex_encode(random);
        }
        
        fn generate_session_id() {
            return Crypto::generate_token(32);
        }
        
        fn generate_csrf_token() {
            return Crypto::generate_token(32);
        }
        
        # Timing-safe string comparison (prevents timing attacks)
        fn timing_safe_compare(a, b) {
            if a.len() != b.len() {
                return false;
            }
            
            let result = 0;
            for i in range(a.len()) {
                result = result | (a.char_code_at(i) ~ b.char_code_at(i));
            }
            return result == 0;
        }
        
        # HMAC for signed cookies
        fn sign(value, secret) {
            let hmac = crypto.hmac_sha256(secret, value);
            return value + "." + crypto.base64_encode(hmac);
        }
        
        fn verify_and_decode(signed_value, secret) {
            let parts = signed_value.split(".");
            if parts.len() != 2 {
                return null;
            }
            
            let value = parts[0];
            let signature = parts[1];
            let expected = crypto.base64_encode(crypto.hmac_sha256(secret, value));
            
            if Crypto::timing_safe_compare(signature, expected) {
                return value;
            }
            return null;
        }
    }
    
    # =========================================================================
    # CSRF PROTECTION
    # =========================================================================
    
    class CSRFProtection {
        pub let secret_key: String;
        pub let token_name: String;
        pub let header_name: String;
        
        fn new(secret) {
            return Self {
                secret_key: secret,
                token_name: "csrf_token",
                header_name: "X-CSRF-Token",
            };
        }
        
        fn generate_token(self, session_id) {
            # Token is HMAC of session_id with secret
            let data = session_id + "_" + DateTime::now().to_unix() as String;
            return Crypto::sign(data, self.secret_key);
        }
        
        fn validate_token(self, token, session_id) {
            let decoded = Crypto::verify_and_decode(token, self.secret_key);
            if decoded == null {
                return false;
            }
            
            # Check token hasn't expired (1 hour max)
            let parts = decoded.split("_");
            if parts.len() < 2 {
                return false;
            }
            
            let timestamp = parts[parts.len() - 1] as Int;
            let now = DateTime::now().to_unix();
            
            return (now - timestamp) < 3600;
        }
        
        fn middleware(self) {
            return fn(request: Request, next: fn(Request) -> Response) -> Response {
                # Skip safe methods
                if request.method == "GET" || request.method == "HEAD" || request.method == "OPTIONS" {
                    return next(request);
                }
                
                # Get token from header or body
                let token = request.header(self.header_name);
                if token == null {
                    token = request.form().get(self.token_name);
                }
                
                if token == null {
                    return Response::error(403, "CSRF token missing");
                }
                
                # Validate
                let session_id = request.cookies.get("session_id");
                if session_id == null || !self.validate_token(token, session_id) {
                    return Response::error(403, "Invalid CSRF token");
                }
                
                return next(request);
            };
        }
    }
    
    # =========================================================================
    # SECURE SESSION MANAGEMENT
    # =========================================================================
    
    class SessionStore {
        pub let sessions: Dict<String, Dict<String, Any>>;
        pub let secret_key: String;
        pub let expiry_seconds: Int;
        
        fn new(secret: String, expiry: Int) {
            return Self {
                sessions: {},
                secret_key: secret,
                expiry_seconds: expiry,
            };
        }
        
        fn create_session(self, data) {
            let session_id = Crypto::generate_session_id();
            let session = {
                "data": data,
                "created_at": DateTime::now().to_unix(),
                "expires_at": DateTime::now().to_unix() + self.expiry_seconds,
            };
            self.sessions.set(session_id, session);
            return session_id;
        }
        
        fn get_session(self, session_id) {
            let session = self.sessions.get(session_id);
            if session == null {
                return null;
            }
            
            # Check expiry
            let now = DateTime::now().to_unix();
            if session.get("expires_at") as Int < now {
                self.sessions.delete(session_id);
                return null;
            }
            
            return session.get("data") as Dict<String, Any>;
        }
        
        fn update_session(self, session_id, data) {
            let session = self.sessions.get(session_id);
            if session == null {
                return false;
            }
            
            session.set("data", data);
            session.set("expires_at", DateTime::now().to_unix() + self.expiry_seconds);
            return true;
        }
        
        fn delete_session(self, session_id) {
            self.sessions.delete(session_id);
        }
        
        fn cleanup_expired(self) {
            let now = DateTime::now().to_unix();
            let to_delete = [];
            
            for (id, session) in self.sessions {
                if session.get("expires_at") as Int < now {
                    to_delete.push(id);
                }
            }
            
            for id in to_delete {
                self.sessions.delete(id);
            }
        }
    }
    
    # =========================================================================
    # RATE LIMITING
    # =========================================================================
    
    class RateLimiter {
        pub let requests: Dict<String, List<Int>>;
        pub let max_requests: Int;
        pub let window_seconds: Int;
        
        fn new(max, window) {
            return Self {
                requests: {},
                max_requests: max,
                window_seconds: window,
            };
        }
        
        fn check(self, key) {
            let now = DateTime::now().to_unix();
            let window_start = now - self.window_seconds;
            
            # Get or create request list
            let request_times = self.requests.get(key);
            if request_times == null {
                self.requests.set(key, [now]);
                return true;
            }
            
            # Filter out old requests
            let recent = [];
            for t in request_times {
                if t > window_start {
                    recent.push(t);
                }
            }
            
            # Check limit
            if recent.len() >= self.max_requests {
                self.requests.set(key, recent);
                return false;
            }
            
            recent.push(now);
            self.requests.set(key, recent);
            return true;
        }
        
        fn remaining(self, key) {
            let request_times = self.requests.get(key);
            if request_times == null {
                return self.max_requests;
            }
            
            let now = DateTime::now().to_unix();
            let window_start = now - self.window_seconds;
            let count = 0;
            
            for t in request_times {
                if t > window_start {
                    count = count + 1;
                }
            }
            
            return self.max_requests - count;
        }
        
        fn reset(self, key) {
            self.requests.delete(key);
        }
        
        fn middleware(self) {
            return fn(request: Request, next: fn(Request) -> Response) -> Response {
                # Use IP as key
                let key = request.headers.get("X-Forwarded-For");
                if key == null {
                    key = request.headers.get("X-Real-IP");
                }
                if key == null {
                    key = "unknown";
                }
                
                if !self.check(key) {
                    let response = Response::error(429, "Too Many Requests");
                    response.headers.set("Retry-After", self.window_seconds as String);
                    response.headers.set("X-RateLimit-Limit", self.max_requests as String);
                    response.headers.set("X-RateLimit-Remaining", "0");
                    return response;
                }
                
                let response = next(request);
                response.headers.set("X-RateLimit-Limit", self.max_requests as String);
                response.headers.set("X-RateLimit-Remaining", self.remaining(key) as String);
                return response;
            };
        }
    }
    
    # =========================================================================
    # REAL SQLITE DATABASE ENGINE
    # =========================================================================
    
    class SQLiteDatabase {
        pub let path: String;
        pub let connection: Any;
        pub let connected: Bool;
        pub let in_transaction: Bool;
        
        fn new(path) {
            return Self {
                path: path,
                connection: null,
                connected: false,
                in_transaction: false,
            };
        }
        
        fn connect(self) {
            # Use better-sqlite3 via FFI
            self.connection = sqlite.open(self.path);
            if self.connection != null {
                self.connected = true;
                # Enable WAL mode for better concurrency
                self.execute("PRAGMA journal_mode = WAL", []);
                self.execute("PRAGMA foreign_keys = ON", []);
                return true;
            }
            return false;
        }
        
        fn close(self) {
            if self.connected {
                sqlite.close(self.connection);
                self.connection = null;
                self.connected = false;
            }
        }
        
        fn execute(self, sql, params) {
            if !self.connected {
                return {"error": "Not connected", "rows": []};
            }
            
            return sqlite.execute(self.connection, sql, params);
        }
        
        fn query(self, sql, params) {
            let result = self.execute(sql, params);
            if result.get("error") != null {
                io.println("Query error: " + result["error"]);
                return [];
            }
            return result.get("rows") as List<Dict<String, Any>>;
        }
        
        fn query_one(self, sql, params) {
            let rows = self.query(sql, params);
            if rows.len() > 0 {
                return rows[0];
            }
            return null;
        }
        
        fn execute_batch(self, statements) {
            self.begin();
            for sql in statements {
                let result = self.execute(sql, []);
                if result.get("error") != null {
                    self.rollback();
                    return false;
                }
            }
            self.commit();
            return true;
        }
        
        fn begin(self) {
            if !self.in_transaction {
                self.execute("BEGIN TRANSACTION", []);
                self.in_transaction = true;
            }
        }
        
        fn commit(self) {
            if self.in_transaction {
                self.execute("COMMIT", []);
                self.in_transaction = false;
            }
        }
        
        fn rollback(self) {
            if self.in_transaction {
                self.execute("ROLLBACK", []);
                self.in_transaction = false;
            }
        }
        
        fn last_insert_rowid(self) {
            let result = self.query_one("SELECT last_insert_rowid() as id", []);
            if result != null {
                return result.get("id") as Int;
            }
            return 0;
        }
        
        fn changes(self) {
            let result = self.query_one("SELECT changes() as count", []);
            if result != null {
                return result.get("count") as Int;
            }
            return 0;
        }
        
        # Table introspection
        fn table_exists(self, name) {
            let result = self.query_one(
                "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
                [name]
            );
            return result != null;
        }
        
        fn get_columns(self, table) {
            return self.query("PRAGMA table_info(" + table + ")", []);
        }
        
        fn create_table(self, name, columns, constraints) {
            let col_defs = [];
            for (col_name, col_type) in columns {
                col_defs.push(col_name + " " + col_type);
            }
            for constraint in constraints {
                col_defs.push(constraint);
            }
            
            let sql = "CREATE TABLE IF NOT EXISTS " + name + " (" + col_defs.join(", ") + ")";
            let result = self.execute(sql, []);
            return result.get("error") == null;
        }
        
        fn drop_table(self, name) {
            let sql = "DROP TABLE IF EXISTS " + name;
            let result = self.execute(sql, []);
            return result.get("error") == null;
        }
        
        # Index management
        fn create_index(self, table, columns, unique, name) {
            let idx_name = name;
            if idx_name == null {
                idx_name = "idx_" + table + "_" + columns.join("_");
            }
            
            let unique_str = "";
            if unique {
                unique_str = "UNIQUE ";
            }
            
            let sql = "CREATE " + unique_str + "INDEX IF NOT EXISTS " + idx_name + " ON " + table + " (" + columns.join(", ") + ")";
            let result = self.execute(sql, []);
            return result.get("error") == null;
        }
        
        fn drop_index(self, name) {
            let sql = "DROP INDEX IF EXISTS " + name;
            let result = self.execute(sql, []);
            return result.get("error") == null;
        }
    }
    
    # =========================================================================
    # PRODUCTION ORM
    # =========================================================================
    
    class Model {
        pub let db: SQLiteDatabase?;
        pub let table_name: String;
        pub let pk_column: String;
        pub let columns: Dict<String, String>;
        pub let data: Dict<String, Any>;
        
        fn new(db, table) {
            return Self {
                db: db,
                table_name: table,
                pk_column: "id",
                columns: {},
                data: {},
            };
        }
        
        fn set(self, column, value) {
            self.data.set(column, value);
        }
        
        fn get(self, column) {
            return self.data.get(column);
        }
        
        fn save(self) {
            if self.db == null {
                return false;
            }
            
            if self.data.get(self.pk_column) == null {
                return self._insert();
            } else {
                return self._update();
            }
        }
        
        fn _insert(self) -> Bool {
            let columns = [];
            let placeholders = [];
            let values = [];
            
            for (col, val) in self.data {
                columns.push(col);
                placeholders.push("?");
                values.push(val);
            }
            
            let sql = "INSERT INTO " + self.table_name + " (" + columns.join(", ") + ") VALUES (" + placeholders.join(", ") + ")";
            let result = self.db.execute(sql, values);
            
            if result.get("error") == null {
                let id = self.db.last_insert_rowid();
                self.data.set(self.pk_column, id);
                return true;
            }
            return false;
        }
        
        fn _update(self) -> Bool {
            let sets = [];
            let values = [];
            
            for (col, val) in self.data {
                if col != self.pk_column {
                    sets.push(col + " = ?");
                    values.push(val);
                }
            }
            
            values.push(self.data.get(self.pk_column));
            
            let sql = "UPDATE " + self.table_name + " SET " + sets.join(", ") + " WHERE " + self.pk_column + " = ?";
            let result = self.db.execute(sql, values);
            
            return result.get("error") == null;
        }
        
        fn delete(self) {
            if self.db == null || self.data.get(self.pk_column) == null {
                return false;
            }
            
            let sql = "DELETE FROM " + self.table_name + " WHERE " + self.pk_column + " = ?";
            let result = self.db.execute(sql, [self.data.get(self.pk_column)]);
            
            return result.get("error") == null;
        }
        
        # Static-like query methods (called on class, not instance)
        fn find_by_id(db, table, id) {
            let model = Model::new(db, table);
            let row = db.query_one("SELECT * FROM " + table + " WHERE id = ?", [id]);
            
            if row != null {
                for (col, val) in row {
                    model.data.set(col, val);
                }
                return model;
            }
            return null;
        }
        
        fn find_all(db, table) {
            let rows = db.query("SELECT * FROM " + table, []);
            let models = [];
            
            for row in rows {
                let model = Model::new(db, table);
                for (col, val) in row {
                    model.data.set(col, val);
                }
                models.push(model);
            }
            
            return models;
        }
        
        fn find_where(db, table, conditions) {
            let where_clauses = [];
            let values = [];
            
            for (col, val) in conditions {
                where_clauses.push(col + " = ?");
                values.push(val);
            }
            
            let sql = "SELECT * FROM " + table + " WHERE " + where_clauses.join(" AND ");
            let rows = db.query(sql, values);
            let models = [];
            
            for row in rows {
                let model = Model::new(db, table);
                for (col, val) in row {
                    model.data.set(col, val);
                }
                models.push(model);
            }
            
            return models;
        }
    }
    
    # =========================================================================
    # SECURE USER MODEL
    # =========================================================================
    
    class User extends Model {
        fn new(db) {
            let instance = Model::new(db, "users");
            return Self {
                db: instance.db,
                table_name: "users",
                pk_column: "id",
                columns: {
                    "id": "INTEGER PRIMARY KEY AUTOINCREMENT",
                    "username": "TEXT UNIQUE NOT NULL",
                    "email": "TEXT UNIQUE NOT NULL",
                    "password_hash": "TEXT NOT NULL",
                    "is_active": "INTEGER DEFAULT 1",
                    "is_staff": "INTEGER DEFAULT 0",
                    "is_superuser": "INTEGER DEFAULT 0",
                    "last_login": "TEXT",
                    "created_at": "TEXT DEFAULT CURRENT_TIMESTAMP",
                },
                data: {},
            };
        }
        
        fn set_password(self, password) {
            self.data.set("password_hash", Crypto::hash_password(password));
        }
        
        fn check_password(self, password) {
            let hash = self.data.get("password_hash");
            if hash == null {
                return false;
            }
            return Crypto::verify_password(password, hash as String);
        }
        
        fn authenticate(db, username, password) {
            let users = Model::find_where(db, "users", {"username": username});
            
            if users.len() > 0 {
                let user = users[0] as User;
                if user.data.get("is_active") == 1 && user.check_password(password) {
                    return user;
                }
            }
            return null;
        }
        
        fn create(db, username, email, password) {
            let user = User::new(db);
            user.data.set("username", username);
            user.data.set("email", email);
            user.set_password(password);
            
            if user.save() {
                return user;
            }
            return null;
        }
    }
    
    # =========================================================================
    # ASYNC HTTP SERVER FOUNDATION
    # =========================================================================
    
    class AsyncHTTPServer {
        pub let host: String;
        pub let port: Int;
        pub let routes: List<Route>;
        pub let middleware: List<Middleware>;
        pub let config: Config;
        pub let running: Bool;
        
        fn new(host, port, config) {
            return Self {
                host: host,
                port: port,
                routes: [],
                middleware: [],
                config: config,
                running: false,
            };
        }
        
        fn add_route(self, route) {
            self.routes.push(route);
        }
        
        fn add_middleware(self, mw) {
            self.middleware.push(mw);
        }
        
        fn start(self) {
            io.println("Starting async HTTP server on " + self.host + ":" + self.port as String);
            
            # Create async server using Node.js http module
            let server = http.createServer(fn(req, res) {
                self._handle_request(req, res);
            });
            
            # Configure server
            server.timeout = 30000;  # 30 seconds
            server.keepAliveTimeout = 65000;  # 65 seconds
            server.maxHeadersCount = 100;
            
            # Start listening
            server.listen(self.port, self.host, fn() {
                io.println("Server listening on " + self.host + ":" + self.port as String);
                self.running = true;
            });
        }
        
        fn _handle_request(self, req, res) {
            # Parse request
            let request = Request::from_node_request(req);
            
            # Find matching route
            let handler = self._find_handler(request);
            
            if handler == null {
                self._send_response(res, Response::error(404, "Not Found"));
                return;
            }
            
            # Apply middleware chain
            let response = self._apply_middleware(request, handler);
            
            # Send response
            self._send_response(res, response);
        }
        
        fn _find_handler(self, request: Request) -> fn(Request) -> Response? {
            for route in self.routes {
                if self._match_route(route, request) {
                    return route.handler;
                }
            }
            return null;
        }
        
        fn _match_route(self, route: Route, request: Request) -> Bool {
            # Check method
            let method_match = false;
            for m in route.methods {
                if m == request.method || m == "ANY" {
                    method_match = true;
                }
            }
            if !method_match {
                return false;
            }
            
            # Check path with parameter extraction
            return URLPattern::match(route.path, request.path, request.params);
        }
        
        fn _apply_middleware(self, request: Request, handler: fn(Request) -> Response) -> Response {
            let index = 0;
            let middleware = self.middleware;
            
            let recurse = fn(idx: Int, req: Request) -> Response {
                if idx >= middleware.len() {
                    return handler(req);
                }
                let mw = middleware[idx];
                return mw.process(req, fn(r: Request) -> Response {
                    return recurse(idx + 1, r);
                });
            };
            
            return recurse(0, request);
        }
        
        fn _send_response(self, res, response: Response) {
            res.writeHead(response.status, response.headers);
            res.end(response.body);
        }
        
        fn stop(self) {
            self.running = false;
            io.println("Server stopped");
        }
    }
    
    # =========================================================================
    # ERROR HANDLING
    # =========================================================================
    
    class AppError {
        pub let code: String;
        pub let message: String;
        pub let details: Any?;
        pub let stack: String?;
        
        fn new(code, message) {
            return Self {
                code: code,
                message: message,
                details: null,
                stack: null,
            };
        }
        
        fn with_details(self, details) {
            self.details = details;
            return self;
        }
        
        fn with_stack(self, stack) {
            self.stack = stack;
            return self;
        }
        
        fn to_dict(self) {
            return {
                "code": self.code,
                "message": self.message,
                "details": self.details,
            };
        }
    }
    
    class ErrorHandler {
        pub let debug: Bool;
        pub let log_errors: Bool;
        
        fn new(debug) {
            return Self {
                debug: debug,
                log_errors: true,
            };
        }
        
        fn handle(self, error, request) {
            # Log error
            if self.log_errors {
                io.println("ERROR: " + error.code + " - " + error.message);
                if error.stack != null {
                    io.println("Stack: " + error.stack);
                }
            }
            
            # Return appropriate response
            let status = self._get_status_code(error.code);
            
            if self.debug {
                return Response::json({
                    "error": error.to_dict(),
                    "request": {
                        "method": request.method,
                        "path": request.path,
                    }
                });
            }
            
            return Response::error(status, error.message);
        }
        
        fn _get_status_code(self, code: String) -> Int {
            if code.starts_with("VALIDATION") { return 400; }
            if code.starts_with("AUTH") { return 401; }
            if code.starts_with("FORBIDDEN") { return 403; }
            if code.starts_with("NOT_FOUND") { return 404; }
            if code.starts_with("RATE_LIMIT") { return 429; }
            return 500;
        }
        
        fn middleware(self) {
            return fn(request: Request, next: fn(Request) -> Response) -> Response {
                try {
                    return next(request);
                } catch (error) {
                    let app_error = AppError::new("INTERNAL", "Internal server error");
                    return self.handle(app_error, request);
                }
            };
        }
    }
    
    # =========================================================================
    # LOGGING
    # =========================================================================
    
    class Logger {
        pub let level: String;
        pub let levels: Dict<String, Int>;
        
        fn new(level) {
            return Self {
                level: level,
                levels: {
                    "DEBUG": 0,
                    "INFO": 1,
                    "WARN": 2,
                    "ERROR": 3,
                    "FATAL": 4,
                },
            };
        }
        
        fn _should_log(self, level: String) -> Bool {
            let current = self.levels.get(self.level);
            let target = self.levels.get(level);
            
            if current == null { current = 1; }
            if target == null { target = 1; }
            
            return target >= current;
        }
        
        fn _format(self, level: String, message: String, data: Any?) -> String {
            let timestamp = DateTime::now().to_iso();
            let formatted = "[" + timestamp + "] [" + level + "] " + message;
            
            if data != null {
                formatted = formatted + " " + json.stringify(data);
            }
            
            return formatted;
        }
        
        fn debug(self, message, data) {
            if self._should_log("DEBUG") {
                io.println(self._format("DEBUG", message, data));
            }
        }
        
        fn info(self, message, data) {
            if self._should_log("INFO") {
                io.println(self._format("INFO", message, data));
            }
        }
        
        fn warn(self, message, data) {
            if self._should_log("WARN") {
                io.println(self._format("WARN", message, data));
            }
        }
        
        fn error(self, message, data) {
            if self._should_log("ERROR") {
                io.println(self._format("ERROR", message, data));
            }
        }
        
        fn fatal(self, message, data) {
            if self._should_log("FATAL") {
                io.println(self._format("FATAL", message, data));
            }
        }
        
        fn request(self, request, response, duration) {
            let data = {
                "method": request.method,
                "path": request.path,
                "status": response.status,
                "duration_ms": duration,
            };
            self.info("REQUEST", data);
        }
    }

# Export production module (all public classes/functions are now top-level)