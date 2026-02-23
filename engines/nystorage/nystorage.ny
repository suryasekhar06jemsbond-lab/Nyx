# ============================================================
# NYSTORAGE - Nyx Local Data & Storage Engine
# ============================================================
# Production-grade local storage with embedded SQLite, key-value
# store, encrypted storage, file serialization, structured
# document store, cloud sync, and migration management.

let VERSION = "1.0.0";

# ============================================================
# KEY-VALUE STORE
# ============================================================

pub mod kv {
    pub class KVStore {
        pub let id: Int;
        pub let name: String;
        pub let path: String;
        pub let encrypted: Bool;

        pub fn open(name: String, path: String) -> Self {
            let id = native_kv_open(name, path);
            return Self { id: id, name: name, path: path, encrypted: false };
        }

        pub fn open_encrypted(name: String, path: String, key: Bytes) -> Self {
            let id = native_kv_open_encrypted(name, path, key);
            return Self { id: id, name: name, path: path, encrypted: true };
        }

        pub fn get(self, key: String) -> Any? {
            return native_kv_get(self.id, key);
        }

        pub fn get_string(self, key: String) -> String? {
            return native_kv_get_string(self.id, key);
        }

        pub fn get_int(self, key: String) -> Int? {
            return native_kv_get_int(self.id, key);
        }

        pub fn get_float(self, key: String) -> Float? {
            return native_kv_get_float(self.id, key);
        }

        pub fn get_bool(self, key: String) -> Bool? {
            return native_kv_get_bool(self.id, key);
        }

        pub fn get_bytes(self, key: String) -> Bytes? {
            return native_kv_get_bytes(self.id, key);
        }

        pub fn set(self, key: String, value: Any) {
            native_kv_set(self.id, key, value);
        }

        pub fn delete(self, key: String) -> Bool {
            return native_kv_delete(self.id, key);
        }

        pub fn has(self, key: String) -> Bool {
            return native_kv_has(self.id, key);
        }

        pub fn keys(self) -> List<String> {
            return native_kv_keys(self.id);
        }

        pub fn keys_with_prefix(self, prefix: String) -> List<String> {
            return native_kv_keys_prefix(self.id, prefix);
        }

        pub fn count(self) -> Int {
            return native_kv_count(self.id);
        }

        pub fn clear(self) {
            native_kv_clear(self.id);
        }

        pub fn flush(self) {
            native_kv_flush(self.id);
        }

        pub fn close(self) {
            native_kv_close(self.id);
        }

        pub fn batch(self) -> KVBatch {
            return KVBatch::new(self.id);
        }
    }

    pub class KVBatch {
        pub let store_id: Int;
        pub let operations: List<Map<String, Any>>;

        pub fn new(store_id: Int) -> Self {
            return Self { store_id: store_id, operations: [] };
        }

        pub fn set(self, key: String, value: Any) -> Self {
            self.operations.push({ "op": "set", "key": key, "value": value });
            return self;
        }

        pub fn delete(self, key: String) -> Self {
            self.operations.push({ "op": "delete", "key": key });
            return self;
        }

        pub fn commit(self) -> Bool {
            return native_kv_batch_commit(self.store_id, self.operations);
        }
    }
}

# ============================================================
# EMBEDDED DATABASE (SQLite-compatible)
# ============================================================

pub mod db {
    pub class Database {
        pub let id: Int;
        pub let path: String;
        pub let read_only: Bool;
        pub let in_transaction: Bool;

        pub fn open(path: String) -> Self {
            let id = native_db_open(path, false);
            return Self { id: id, path: path, read_only: false, in_transaction: false };
        }

        pub fn open_read_only(path: String) -> Self {
            let id = native_db_open(path, true);
            return Self { id: id, path: path, read_only: true, in_transaction: false };
        }

        pub fn open_in_memory() -> Self {
            let id = native_db_open(":memory:", false);
            return Self { id: id, path: ":memory:", read_only: false, in_transaction: false };
        }

        pub fn execute(self, sql: String, params: List<Any>) -> Int {
            return native_db_execute(self.id, sql, params);
        }

        pub fn query(self, sql: String, params: List<Any>) -> List<Map<String, Any>> {
            return native_db_query(self.id, sql, params);
        }

        pub fn query_one(self, sql: String, params: List<Any>) -> Map<String, Any>? {
            let rows = self.query(sql, params);
            if rows.len() == 0 { return null; }
            return rows[0];
        }

        pub fn query_scalar(self, sql: String, params: List<Any>) -> Any? {
            let row = self.query_one(sql, params);
            if row == null { return null; }
            let values = row.values();
            if values.len() == 0 { return null; }
            return values[0];
        }

        pub fn begin_transaction(self) {
            native_db_execute(self.id, "BEGIN TRANSACTION", []);
            self.in_transaction = true;
        }

        pub fn commit(self) {
            native_db_execute(self.id, "COMMIT", []);
            self.in_transaction = false;
        }

        pub fn rollback(self) {
            native_db_execute(self.id, "ROLLBACK", []);
            self.in_transaction = false;
        }

        pub fn transaction(self, func: Fn) -> Bool {
            self.begin_transaction();
            let success = false;
            try {
                func(self);
                self.commit();
                success = true;
            } catch err {
                self.rollback();
            }
            return success;
        }

        pub fn table_exists(self, table_name: String) -> Bool {
            let result = self.query_scalar(
                "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?",
                [table_name]
            );
            return result != null and result > 0;
        }

        pub fn tables(self) -> List<String> {
            let rows = self.query(
                "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
                []
            );
            let names = [];
            for row in rows {
                names.push(row["name"]);
            }
            return names;
        }

        pub fn prepare(self, sql: String) -> PreparedStatement {
            return PreparedStatement::new(self.id, sql);
        }

        pub fn close(self) {
            native_db_close(self.id);
        }

        pub fn backup(self, dest_path: String) -> Bool {
            return native_db_backup(self.id, dest_path);
        }

        pub fn vacuum(self) {
            native_db_execute(self.id, "VACUUM", []);
        }
    }

    pub class PreparedStatement {
        pub let id: Int;
        pub let db_id: Int;
        pub let sql: String;

        pub fn new(db_id: Int, sql: String) -> Self {
            let id = native_db_prepare(db_id, sql);
            return Self { id: id, db_id: db_id, sql: sql };
        }

        pub fn execute(self, params: List<Any>) -> Int {
            return native_db_stmt_execute(self.id, params);
        }

        pub fn query(self, params: List<Any>) -> List<Map<String, Any>> {
            return native_db_stmt_query(self.id, params);
        }

        pub fn finalize(self) {
            native_db_stmt_finalize(self.id);
        }
    }

    pub class QueryBuilder {
        pub let table: String;
        pub let select_cols: List<String>;
        pub let where_clauses: List<String>;
        pub let where_params: List<Any>;
        pub let order_by_col: String;
        pub let order_dir: String;
        pub let limit_val: Int;
        pub let offset_val: Int;

        pub fn from(table: String) -> Self {
            return Self {
                table: table,
                select_cols: ["*"],
                where_clauses: [],
                where_params: [],
                order_by_col: "",
                order_dir: "ASC",
                limit_val: 0,
                offset_val: 0
            };
        }

        pub fn select(self, cols: List<String>) -> Self {
            self.select_cols = cols;
            return self;
        }

        pub fn where_eq(self, col: String, value: Any) -> Self {
            self.where_clauses.push(col + " = ?");
            self.where_params.push(value);
            return self;
        }

        pub fn where_like(self, col: String, pattern: String) -> Self {
            self.where_clauses.push(col + " LIKE ?");
            self.where_params.push(pattern);
            return self;
        }

        pub fn where_gt(self, col: String, value: Any) -> Self {
            self.where_clauses.push(col + " > ?");
            self.where_params.push(value);
            return self;
        }

        pub fn where_lt(self, col: String, value: Any) -> Self {
            self.where_clauses.push(col + " < ?");
            self.where_params.push(value);
            return self;
        }

        pub fn where_in(self, col: String, values: List<Any>) -> Self {
            let placeholders = values.map(|_| "?").join(", ");
            self.where_clauses.push(col + " IN (" + placeholders + ")");
            for v in values {
                self.where_params.push(v);
            }
            return self;
        }

        pub fn order_by(self, col: String, dir: String) -> Self {
            self.order_by_col = col;
            self.order_dir = dir;
            return self;
        }

        pub fn limit(self, n: Int) -> Self {
            self.limit_val = n;
            return self;
        }

        pub fn offset(self, n: Int) -> Self {
            self.offset_val = n;
            return self;
        }

        pub fn build(self) -> (String, List<Any>) {
            let sql = "SELECT " + self.select_cols.join(", ") + " FROM " + self.table;
            if self.where_clauses.len() > 0 {
                sql = sql + " WHERE " + self.where_clauses.join(" AND ");
            }
            if self.order_by_col != "" {
                sql = sql + " ORDER BY " + self.order_by_col + " " + self.order_dir;
            }
            if self.limit_val > 0 {
                sql = sql + " LIMIT " + self.limit_val as String;
            }
            if self.offset_val > 0 {
                sql = sql + " OFFSET " + self.offset_val as String;
            }
            return (sql, self.where_params);
        }

        pub fn run(self, database: Database) -> List<Map<String, Any>> {
            let (sql, params) = self.build();
            return database.query(sql, params);
        }
    }
}

# ============================================================
# DOCUMENT STORE
# ============================================================

pub mod documents {
    pub class Collection {
        pub let db: db.Database;
        pub let name: String;

        pub fn new(database: db.Database, name: String) -> Self {
            database.execute(
                "CREATE TABLE IF NOT EXISTS " + name + " (id TEXT PRIMARY KEY, data TEXT, created_at INTEGER, updated_at INTEGER)",
                []
            );
            return Self { db: database, name: name };
        }

        pub fn insert(self, id: String, data: Map<String, Any>) -> Bool {
            let json = native_storage_to_json(data);
            let now = native_storage_time_ms();
            return self.db.execute(
                "INSERT INTO " + self.name + " (id, data, created_at, updated_at) VALUES (?, ?, ?, ?)",
                [id, json, now, now]
            ) > 0;
        }

        pub fn upsert(self, id: String, data: Map<String, Any>) -> Bool {
            let json = native_storage_to_json(data);
            let now = native_storage_time_ms();
            return self.db.execute(
                "INSERT OR REPLACE INTO " + self.name + " (id, data, created_at, updated_at) VALUES (?, ?, COALESCE((SELECT created_at FROM " + self.name + " WHERE id = ?), ?), ?)",
                [id, json, id, now, now]
            ) > 0;
        }

        pub fn get(self, id: String) -> Map<String, Any>? {
            let row = self.db.query_one(
                "SELECT data FROM " + self.name + " WHERE id = ?",
                [id]
            );
            if row == null { return null; }
            return native_storage_from_json(row["data"]);
        }

        pub fn update(self, id: String, data: Map<String, Any>) -> Bool {
            let json = native_storage_to_json(data);
            let now = native_storage_time_ms();
            return self.db.execute(
                "UPDATE " + self.name + " SET data = ?, updated_at = ? WHERE id = ?",
                [json, now, id]
            ) > 0;
        }

        pub fn delete(self, id: String) -> Bool {
            return self.db.execute(
                "DELETE FROM " + self.name + " WHERE id = ?",
                [id]
            ) > 0;
        }

        pub fn exists(self, id: String) -> Bool {
            let result = self.db.query_scalar(
                "SELECT count(*) FROM " + self.name + " WHERE id = ?",
                [id]
            );
            return result != null and result > 0;
        }

        pub fn all(self) -> List<Map<String, Any>> {
            let rows = self.db.query(
                "SELECT id, data FROM " + self.name + " ORDER BY created_at",
                []
            );
            let results = [];
            for row in rows {
                let doc = native_storage_from_json(row["data"]);
                doc["_id"] = row["id"];
                results.push(doc);
            }
            return results;
        }

        pub fn find(self, field: String, value: Any) -> List<Map<String, Any>> {
            let rows = self.db.query(
                "SELECT id, data FROM " + self.name + " WHERE json_extract(data, '$." + field + "') = ?",
                [value]
            );
            let results = [];
            for row in rows {
                let doc = native_storage_from_json(row["data"]);
                doc["_id"] = row["id"];
                results.push(doc);
            }
            return results;
        }

        pub fn count(self) -> Int {
            let result = self.db.query_scalar(
                "SELECT count(*) FROM " + self.name,
                []
            );
            return result or 0;
        }

        pub fn clear(self) {
            self.db.execute("DELETE FROM " + self.name, []);
        }
    }
}

# ============================================================
# FILE SERIALIZATION
# ============================================================

pub mod files {
    pub class FileSerializer {
        pub fn read_json(path: String) -> Any? {
            let content = native_storage_read_file(path);
            if content == null { return null; }
            return native_storage_from_json(content);
        }

        pub fn write_json(path: String, data: Any) {
            let json = native_storage_to_json_pretty(data);
            native_storage_write_file(path, json);
        }

        pub fn read_binary(path: String) -> Bytes? {
            return native_storage_read_binary(path);
        }

        pub fn write_binary(path: String, data: Bytes) {
            native_storage_write_binary(path, data);
        }

        pub fn read_text(path: String) -> String? {
            return native_storage_read_file(path);
        }

        pub fn write_text(path: String, content: String) {
            native_storage_write_file(path, content);
        }

        pub fn exists(path: String) -> Bool {
            return native_storage_file_exists(path);
        }

        pub fn delete(path: String) -> Bool {
            return native_storage_delete_file(path);
        }

        pub fn size(path: String) -> Int {
            return native_storage_file_size(path);
        }

        pub fn modified_time(path: String) -> Int {
            return native_storage_file_mtime(path);
        }
    }

    pub class AppDataDir {
        pub let base_path: String;

        pub fn new(app_name: String, org: String) -> Self {
            return Self {
                base_path: native_storage_app_data_dir(app_name, org)
            };
        }

        pub fn path(self, relative: String) -> String {
            return self.base_path + "/" + relative;
        }

        pub fn ensure_dir(self, relative: String) {
            native_storage_ensure_dir(self.base_path + "/" + relative);
        }

        pub fn read(self, relative: String) -> String? {
            return native_storage_read_file(self.path(relative));
        }

        pub fn write(self, relative: String, content: String) {
            native_storage_write_file(self.path(relative), content);
        }
    }
}

# ============================================================
# ENCRYPTED STORAGE
# ============================================================

pub mod encrypted {
    pub class SecureStore {
        pub let inner: kv.KVStore;
        pub let cipher: String;

        pub fn open(name: String, path: String, master_key: Bytes) -> Self {
            let store = kv.KVStore::open_encrypted(name, path, master_key);
            return Self { inner: store, cipher: "aes-256-gcm" };
        }

        pub fn get(self, key: String) -> Any? {
            return self.inner.get(key);
        }

        pub fn set(self, key: String, value: Any) {
            self.inner.set(key, value);
        }

        pub fn delete(self, key: String) -> Bool {
            return self.inner.delete(key);
        }

        pub fn close(self) {
            self.inner.close();
        }
    }

    pub class Keychain {
        pub fn store(service: String, account: String, secret: String) {
            native_keychain_store(service, account, secret);
        }

        pub fn retrieve(service: String, account: String) -> String? {
            return native_keychain_retrieve(service, account);
        }

        pub fn delete(service: String, account: String) -> Bool {
            return native_keychain_delete(service, account);
        }

        pub fn exists(service: String, account: String) -> Bool {
            return native_keychain_exists(service, account);
        }
    }
}

# ============================================================
# MIGRATION SYSTEM
# ============================================================

pub mod migrations {
    pub class Migration {
        pub let version: Int;
        pub let name: String;
        pub let up: Fn;
        pub let down: Fn?;

        pub fn new(version: Int, name: String, up: Fn) -> Self {
            return Self { version: version, name: name, up: up, down: null };
        }

        pub fn with_down(self, down_fn: Fn) -> Self {
            self.down = down_fn;
            return self;
        }
    }

    pub class MigrationRunner {
        pub let database: db.Database;
        pub let migrations: List<Migration>;

        pub fn new(database: db.Database) -> Self {
            # Create migrations tracking table
            database.execute(
                "CREATE TABLE IF NOT EXISTS _migrations (version INTEGER PRIMARY KEY, name TEXT, applied_at INTEGER)",
                []
            );
            return Self { database: database, migrations: [] };
        }

        pub fn add(self, migration: Migration) -> Self {
            self.migrations.push(migration);
            return self;
        }

        pub fn current_version(self) -> Int {
            let result = self.database.query_scalar(
                "SELECT MAX(version) FROM _migrations",
                []
            );
            return result or 0;
        }

        pub fn pending(self) -> List<Migration> {
            let current = self.current_version();
            let pending = [];
            for m in self.migrations {
                if m.version > current {
                    pending.push(m);
                }
            }
            pending.sort(|a, b| a.version - b.version);
            return pending;
        }

        pub fn migrate_up(self) -> Int {
            let pending = self.pending();
            let applied = 0;
            for m in pending {
                self.database.transaction(|db| {
                    m.up(db);
                    db.execute(
                        "INSERT INTO _migrations (version, name, applied_at) VALUES (?, ?, ?)",
                        [m.version, m.name, native_storage_time_ms()]
                    );
                });
                applied = applied + 1;
            }
            return applied;
        }

        pub fn migrate_down(self, target_version: Int) -> Int {
            let current = self.current_version();
            let rolled_back = 0;
            let sorted = self.migrations.filter(|m| m.version > target_version and m.version <= current);
            sorted.sort(|a, b| b.version - a.version);

            for m in sorted {
                if m.down == null { continue; }
                self.database.transaction(|db| {
                    m.down(db);
                    db.execute(
                        "DELETE FROM _migrations WHERE version = ?",
                        [m.version]
                    );
                });
                rolled_back = rolled_back + 1;
            }
            return rolled_back;
        }

        pub fn status(self) -> List<Map<String, Any>> {
            return self.database.query(
                "SELECT version, name, applied_at FROM _migrations ORDER BY version",
                []
            );
        }
    }
}

# ============================================================
# CLOUD SYNC
# ============================================================

pub mod sync {
    pub let CONFLICT_LAST_WRITE_WINS = "last_write_wins";
    pub let CONFLICT_MANUAL = "manual";
    pub let CONFLICT_MERGE = "merge";

    pub class SyncConfig {
        pub let endpoint: String;
        pub let auth_token: String;
        pub let conflict_strategy: String;
        pub let sync_interval_ms: Int;
        pub let auto_sync: Bool;

        pub fn new(endpoint: String) -> Self {
            return Self {
                endpoint: endpoint,
                auth_token: "",
                conflict_strategy: CONFLICT_LAST_WRITE_WINS,
                sync_interval_ms: 30000,
                auto_sync: false
            };
        }

        pub fn with_auth(self, token: String) -> Self {
            self.auth_token = token;
            return self;
        }

        pub fn with_strategy(self, strategy: String) -> Self {
            self.conflict_strategy = strategy;
            return self;
        }

        pub fn with_auto_sync(self, interval_ms: Int) -> Self {
            self.auto_sync = true;
            self.sync_interval_ms = interval_ms;
            return self;
        }
    }

    pub class ChangeRecord {
        pub let id: String;
        pub let collection: String;
        pub let doc_id: String;
        pub let operation: String;
        pub let data: Any?;
        pub let timestamp_ms: Int;
        pub let synced: Bool;

        pub fn new(collection: String, doc_id: String, operation: String, data: Any?) -> Self {
            return Self {
                id: native_storage_uuid(),
                collection: collection,
                doc_id: doc_id,
                operation: operation,
                data: data,
                timestamp_ms: native_storage_time_ms(),
                synced: false
            };
        }
    }

    pub class SyncEngine {
        pub let config: SyncConfig;
        pub let change_log: List<ChangeRecord>;
        pub let last_sync_ms: Int;
        pub let syncing: Bool;
        pub let on_conflict: Fn?;
        pub let on_sync_complete: Fn?;

        pub fn new(config: SyncConfig) -> Self {
            return Self {
                config: config,
                change_log: [],
                last_sync_ms: 0,
                syncing: false,
                on_conflict: null,
                on_sync_complete: null
            };
        }

        pub fn record_change(self, change: ChangeRecord) {
            self.change_log.push(change);
        }

        pub fn push(self) -> Int {
            if self.syncing { return 0; }
            self.syncing = true;

            let pending = self.change_log.filter(|c| not c.synced);
            let pushed = 0;

            for change in pending {
                let result = native_storage_sync_push(self.config.endpoint, self.config.auth_token, change);
                if result {
                    change.synced = true;
                    pushed = pushed + 1;
                }
            }

            self.syncing = false;
            return pushed;
        }

        pub fn pull(self) -> List<ChangeRecord> {
            if self.syncing { return []; }
            self.syncing = true;

            let remote_changes = native_storage_sync_pull(
                self.config.endpoint,
                self.config.auth_token,
                self.last_sync_ms
            );

            self.last_sync_ms = native_storage_time_ms();
            self.syncing = false;

            if self.on_sync_complete != null {
                self.on_sync_complete(remote_changes);
            }

            return remote_changes;
        }

        pub fn sync(self) -> Map<String, Int> {
            let pushed = self.push();
            let pulled = self.pull();
            return { "pushed": pushed, "pulled": pulled.len() };
        }

        pub fn start_auto_sync(self) {
            if not self.config.auto_sync { return; }
            native_storage_schedule_sync(self.config.sync_interval_ms, || {
                self.sync();
            });
        }

        pub fn stop_auto_sync(self) {
            native_storage_cancel_sync();
        }
    }
}

# ============================================================
# CACHE
# ============================================================

pub mod cache {
    pub class CacheEntry {
        pub let key: String;
        pub let value: Any;
        pub let expires_at_ms: Int;
        pub let size_bytes: Int;

        pub fn new(key: String, value: Any, ttl_ms: Int) -> Self {
            return Self {
                key: key,
                value: value,
                expires_at_ms: native_storage_time_ms() + ttl_ms,
                size_bytes: native_storage_estimate_size(value)
            };
        }

        pub fn is_expired(self) -> Bool {
            return native_storage_time_ms() > self.expires_at_ms;
        }
    }

    pub class LRUCache {
        pub let capacity: Int;
        pub let entries: Map<String, CacheEntry>;
        pub let access_order: List<String>;
        pub let max_size_bytes: Int;
        pub let current_size_bytes: Int;

        pub fn new(capacity: Int) -> Self {
            return Self {
                capacity: capacity,
                entries: {},
                access_order: [],
                max_size_bytes: 64 * 1024 * 1024,
                current_size_bytes: 0
            };
        }

        pub fn get(self, key: String) -> Any? {
            let entry = self.entries[key];
            if entry == null { return null; }
            if entry.is_expired() {
                self.remove(key);
                return null;
            }
            # Move to front of access order
            self.access_order = self.access_order.filter(|k| k != key);
            self.access_order.push(key);
            return entry.value;
        }

        pub fn set(self, key: String, value: Any, ttl_ms: Int) {
            let entry = CacheEntry::new(key, value, ttl_ms);

            if self.entries[key] != null {
                self.current_size_bytes = self.current_size_bytes - self.entries[key].size_bytes;
            }

            # Evict if at capacity
            while self.access_order.len() >= self.capacity or
                  self.current_size_bytes + entry.size_bytes > self.max_size_bytes {
                if self.access_order.len() == 0 { break; }
                let lru_key = self.access_order.remove(0);
                let evicted = self.entries[lru_key];
                if evicted != null {
                    self.current_size_bytes = self.current_size_bytes - evicted.size_bytes;
                }
                self.entries.remove(lru_key);
            }

            self.entries[key] = entry;
            self.current_size_bytes = self.current_size_bytes + entry.size_bytes;
            self.access_order = self.access_order.filter(|k| k != key);
            self.access_order.push(key);
        }

        pub fn remove(self, key: String) {
            let entry = self.entries[key];
            if entry != null {
                self.current_size_bytes = self.current_size_bytes - entry.size_bytes;
            }
            self.entries.remove(key);
            self.access_order = self.access_order.filter(|k| k != key);
        }

        pub fn has(self, key: String) -> Bool {
            let entry = self.entries[key];
            if entry == null { return false; }
            if entry.is_expired() {
                self.remove(key);
                return false;
            }
            return true;
        }

        pub fn clear(self) {
            self.entries = {};
            self.access_order = [];
            self.current_size_bytes = 0;
        }

        pub fn prune_expired(self) -> Int {
            let pruned = 0;
            let to_remove = [];
            for entry in self.entries.entries() {
                if entry.value.is_expired() {
                    to_remove.push(entry.key);
                }
            }
            for key in to_remove {
                self.remove(key);
                pruned = pruned + 1;
            }
            return pruned;
        }

        pub fn stats(self) -> Map<String, Any> {
            return {
                "entries": self.entries.len(),
                "capacity": self.capacity,
                "size_bytes": self.current_size_bytes,
                "max_size_bytes": self.max_size_bytes
            };
        }
    }
}

# ============================================================
# STORAGE ORCHESTRATOR
# ============================================================

pub class StorageManager {
    pub let kv: kv.KVStore?;
    pub let database: db.Database?;
    pub let app_data: files.AppDataDir;
    pub let cache_instance: cache.LRUCache;
    pub let sync_engine: sync.SyncEngine?;

    pub fn new(app_name: String, org: String) -> Self {
        return Self {
            kv: null,
            database: null,
            app_data: files.AppDataDir::new(app_name, org),
            cache_instance: cache.LRUCache::new(1000),
            sync_engine: null
        };
    }

    pub fn open_kv(self, name: String) -> kv.KVStore {
        let path = self.app_data.path(name + ".kv");
        self.kv = kv.KVStore::open(name, path);
        return self.kv;
    }

    pub fn open_database(self, name: String) -> db.Database {
        let path = self.app_data.path(name + ".db");
        self.database = db.Database::open(path);
        return self.database;
    }

    pub fn enable_sync(self, config: sync.SyncConfig) -> sync.SyncEngine {
        self.sync_engine = sync.SyncEngine::new(config);
        return self.sync_engine;
    }

    pub fn close_all(self) {
        if self.kv != null { self.kv.close(); }
        if self.database != null { self.database.close(); }
        if self.sync_engine != null { self.sync_engine.stop_auto_sync(); }
    }
}

pub fn create_storage(app_name: String, org: String) -> StorageManager {
    return StorageManager::new(app_name, org);
}

# ============================================================
# NATIVE HOOKS
# ============================================================

# KV Store
native_kv_open(name: String, path: String) -> Int;
native_kv_open_encrypted(name: String, path: String, key: Bytes) -> Int;
native_kv_get(id: Int, key: String) -> Any;
native_kv_get_string(id: Int, key: String) -> String;
native_kv_get_int(id: Int, key: String) -> Int;
native_kv_get_float(id: Int, key: String) -> Float;
native_kv_get_bool(id: Int, key: String) -> Bool;
native_kv_get_bytes(id: Int, key: String) -> Bytes;
native_kv_set(id: Int, key: String, value: Any);
native_kv_delete(id: Int, key: String) -> Bool;
native_kv_has(id: Int, key: String) -> Bool;
native_kv_keys(id: Int) -> List;
native_kv_keys_prefix(id: Int, prefix: String) -> List;
native_kv_count(id: Int) -> Int;
native_kv_clear(id: Int);
native_kv_flush(id: Int);
native_kv_close(id: Int);
native_kv_batch_commit(id: Int, ops: List) -> Bool;

# Database
native_db_open(path: String, read_only: Bool) -> Int;
native_db_execute(id: Int, sql: String, params: List) -> Int;
native_db_query(id: Int, sql: String, params: List) -> List;
native_db_close(id: Int);
native_db_prepare(id: Int, sql: String) -> Int;
native_db_stmt_execute(id: Int, params: List) -> Int;
native_db_stmt_query(id: Int, params: List) -> List;
native_db_stmt_finalize(id: Int);
native_db_backup(id: Int, dest: String) -> Bool;

# Files
native_storage_read_file(path: String) -> String;
native_storage_write_file(path: String, content: String);
native_storage_read_binary(path: String) -> Bytes;
native_storage_write_binary(path: String, data: Bytes);
native_storage_file_exists(path: String) -> Bool;
native_storage_delete_file(path: String) -> Bool;
native_storage_file_size(path: String) -> Int;
native_storage_file_mtime(path: String) -> Int;
native_storage_app_data_dir(app: String, org: String) -> String;
native_storage_ensure_dir(path: String);

# Serialization
native_storage_to_json(data: Any) -> String;
native_storage_to_json_pretty(data: Any) -> String;
native_storage_from_json(json: String) -> Any;
native_storage_time_ms() -> Int;
native_storage_uuid() -> String;
native_storage_estimate_size(value: Any) -> Int;

# Keychain
native_keychain_store(service: String, account: String, secret: String);
native_keychain_retrieve(service: String, account: String) -> String;
native_keychain_delete(service: String, account: String) -> Bool;
native_keychain_exists(service: String, account: String) -> Bool;

# Sync
native_storage_sync_push(endpoint: String, token: String, change: Any) -> Bool;
native_storage_sync_pull(endpoint: String, token: String, since_ms: Int) -> List;
native_storage_schedule_sync(interval_ms: Int, callback: Fn);
native_storage_cancel_sync();

# ============================================================
# PRODUCTION-READY INFRASTRUCTURE
# ============================================================

pub mod production {

    pub class HealthStatus {
        pub let status: String;
        pub let uptime_ms: Int;
        pub let checks: Map;
        pub let version: String;

        pub fn new() -> Self {
            return Self {
                status: "healthy",
                uptime_ms: 0,
                checks: {},
                version: VERSION
            };
        }

        pub fn is_healthy(self) -> Bool {
            return self.status == "healthy";
        }

        pub fn add_check(self, name: String, passed: Bool, detail: String) {
            self.checks[name] = { "passed": passed, "detail": detail };
            if !passed { self.status = "degraded"; }
        }
    }

    pub class MetricsCollector {
        pub let counters: Map;
        pub let gauges: Map;
        pub let histograms: Map;
        pub let start_time: Int;

        pub fn new() -> Self {
            return Self {
                counters: {},
                gauges: {},
                histograms: {},
                start_time: native_production_time_ms()
            };
        }

        pub fn increment(self, name: String, value: Int) {
            self.counters[name] = (self.counters[name] or 0) + value;
        }

        pub fn gauge_set(self, name: String, value: Float) {
            self.gauges[name] = value;
        }

        pub fn histogram_observe(self, name: String, value: Float) {
            if self.histograms[name] == null { self.histograms[name] = []; }
            self.histograms[name].push(value);
        }

        pub fn snapshot(self) -> Map {
            return {
                "counters": self.counters,
                "gauges": self.gauges,
                "uptime_ms": native_production_time_ms() - self.start_time
            };
        }

        pub fn reset(self) {
            self.counters = {};
            self.gauges = {};
            self.histograms = {};
        }
    }

    pub class Logger {
        pub let level: String;
        pub let buffer: List;
        pub let max_buffer: Int;

        pub fn new(level: String) -> Self {
            return Self { level: level, buffer: [], max_buffer: 10000 };
        }

        pub fn debug(self, msg: String, context: Map?) {
            if self.level == "debug" { self._log("DEBUG", msg, context); }
        }

        pub fn info(self, msg: String, context: Map?) {
            if self.level != "error" and self.level != "warn" {
                self._log("INFO", msg, context);
            }
        }

        pub fn warn(self, msg: String, context: Map?) {
            if self.level != "error" { self._log("WARN", msg, context); }
        }

        pub fn error(self, msg: String, context: Map?) {
            self._log("ERROR", msg, context);
        }

        fn _log(self, lvl: String, msg: String, context: Map?) {
            let entry = {
                "ts": native_production_time_ms(),
                "level": lvl,
                "msg": msg,
                "ctx": context
            };
            self.buffer.push(entry);
            if self.buffer.len() > self.max_buffer {
                self.buffer = self.buffer[self.max_buffer / 2..];
            }
        }

        pub fn flush(self) -> List {
            let out = self.buffer;
            self.buffer = [];
            return out;
        }
    }

    pub class CircuitBreaker {
        pub let state: String;
        pub let failure_count: Int;
        pub let threshold: Int;
        pub let reset_timeout_ms: Int;
        pub let last_failure_time: Int;

        pub fn new(threshold: Int, reset_timeout_ms: Int) -> Self {
            return Self {
                state: "closed",
                failure_count: 0,
                threshold: threshold,
                reset_timeout_ms: reset_timeout_ms,
                last_failure_time: 0
            };
        }

        pub fn allow_request(self) -> Bool {
            if self.state == "closed" { return true; }
            if self.state == "open" {
                let elapsed = native_production_time_ms() - self.last_failure_time;
                if elapsed >= self.reset_timeout_ms {
                    self.state = "half-open";
                    return true;
                }
                return false;
            }
            return true;
        }

        pub fn record_success(self) {
            self.failure_count = 0;
            self.state = "closed";
        }

        pub fn record_failure(self) {
            self.failure_count = self.failure_count + 1;
            self.last_failure_time = native_production_time_ms();
            if self.failure_count >= self.threshold {
                self.state = "open";
            }
        }
    }

    pub class RetryPolicy {
        pub let max_retries: Int;
        pub let base_delay_ms: Int;
        pub let max_delay_ms: Int;
        pub let backoff_multiplier: Float;

        pub fn new(max_retries: Int) -> Self {
            return Self {
                max_retries: max_retries,
                base_delay_ms: 100,
                max_delay_ms: 30000,
                backoff_multiplier: 2.0
            };
        }

        pub fn get_delay(self, attempt: Int) -> Int {
            let delay = self.base_delay_ms;
            for _ in 0..attempt { delay = (delay * self.backoff_multiplier).to_int(); }
            if delay > self.max_delay_ms { delay = self.max_delay_ms; }
            return delay;
        }
    }

    pub class RateLimiter {
        pub let max_requests: Int;
        pub let window_ms: Int;
        pub let requests: List;

        pub fn new(max_requests: Int, window_ms: Int) -> Self {
            return Self { max_requests: max_requests, window_ms: window_ms, requests: [] };
        }

        pub fn allow(self) -> Bool {
            let now = native_production_time_ms();
            self.requests = self.requests.filter(fn(t) { t > now - self.window_ms });
            if self.requests.len() >= self.max_requests { return false; }
            self.requests.push(now);
            return true;
        }
    }

    pub class GracefulShutdown {
        pub let hooks: List;
        pub let timeout_ms: Int;
        pub let is_shutting_down: Bool;

        pub fn new(timeout_ms: Int) -> Self {
            return Self { hooks: [], timeout_ms: timeout_ms, is_shutting_down: false };
        }

        pub fn register(self, name: String, hook: Fn) {
            self.hooks.push({ "name": name, "hook": hook });
        }

        pub fn shutdown(self) {
            self.is_shutting_down = true;
            for entry in self.hooks {
                entry.hook();
            }
        }
    }

    pub class ProductionRuntime {
        pub let health: HealthStatus;
        pub let metrics: MetricsCollector;
        pub let logger: Logger;
        pub let circuit_breaker: CircuitBreaker;
        pub let rate_limiter: RateLimiter;
        pub let shutdown: GracefulShutdown;

        pub fn new() -> Self {
            return Self {
                health: HealthStatus::new(),
                metrics: MetricsCollector::new(),
                logger: Logger::new("info"),
                circuit_breaker: CircuitBreaker::new(5, 30000),
                rate_limiter: RateLimiter::new(1000, 60000),
                shutdown: GracefulShutdown::new(30000)
            };
        }

        pub fn check_health(self) -> HealthStatus {
            self.health.uptime_ms = native_production_time_ms() - self.metrics.start_time;
            return self.health;
        }

        pub fn get_metrics(self) -> Map {
            return self.metrics.snapshot();
        }

        pub fn is_ready(self) -> Bool {
            return self.health.is_healthy() and !self.shutdown.is_shutting_down;
        }
    }
}

native_production_time_ms() -> Int;

# ============================================================
# OBSERVABILITY & ERROR HANDLING
# ============================================================

pub mod observability {

    pub class Span {
        pub let trace_id: String;
        pub let span_id: String;
        pub let parent_id: String?;
        pub let operation: String;
        pub let start_time: Int;
        pub let end_time: Int?;
        pub let tags: Map;
        pub let status: String;

        pub fn new(operation: String, parent_id: String?) -> Self {
            return Self {
                trace_id: native_production_time_ms().to_string(),
                span_id: native_production_time_ms().to_string(),
                parent_id: parent_id,
                operation: operation,
                start_time: native_production_time_ms(),
                end_time: null,
                tags: {},
                status: "ok"
            };
        }

        pub fn set_tag(self, key: String, value: String) {
            self.tags[key] = value;
        }

        pub fn finish(self) {
            self.end_time = native_production_time_ms();
        }

        pub fn finish_with_error(self, error: String) {
            self.end_time = native_production_time_ms();
            self.status = "error";
            self.tags["error"] = error;
        }

        pub fn duration_ms(self) -> Int {
            if self.end_time == null { return 0; }
            return self.end_time - self.start_time;
        }
    }

    pub class Tracer {
        pub let spans: List;
        pub let active_span: Span?;
        pub let service_name: String;

        pub fn new(service_name: String) -> Self {
            return Self { spans: [], active_span: null, service_name: service_name };
        }

        pub fn start_span(self, operation: String) -> Span {
            let parent = if self.active_span != null { self.active_span.span_id } else { null };
            let span = Span::new(operation, parent);
            span.set_tag("service", self.service_name);
            self.active_span = span;
            return span;
        }

        pub fn finish_span(self, span: Span) {
            span.finish();
            self.spans.push(span);
            self.active_span = null;
        }

        pub fn get_traces(self) -> List {
            return self.spans;
        }
    }

    pub class AlertRule {
        pub let name: String;
        pub let condition: Fn;
        pub let severity: String;
        pub let cooldown_ms: Int;
        pub let last_fired: Int;

        pub fn new(name: String, condition: Fn, severity: String) -> Self {
            return Self {
                name: name,
                condition: condition,
                severity: severity,
                cooldown_ms: 60000,
                last_fired: 0
            };
        }

        pub fn evaluate(self, metrics: Map) -> Bool {
            let now = native_production_time_ms();
            if now - self.last_fired < self.cooldown_ms { return false; }
            if self.condition(metrics) {
                self.last_fired = now;
                return true;
            }
            return false;
        }
    }

    pub class AlertManager {
        pub let rules: List;
        pub let alerts: List;

        pub fn new() -> Self {
            return Self { rules: [], alerts: [] };
        }

        pub fn add_rule(self, rule: AlertRule) {
            self.rules.push(rule);
        }

        pub fn evaluate_all(self, metrics: Map) -> List {
            let fired = [];
            for rule in self.rules {
                if rule.evaluate(metrics) {
                    let alert = {
                        "name": rule.name,
                        "severity": rule.severity,
                        "time": native_production_time_ms()
                    };
                    self.alerts.push(alert);
                    fired.push(alert);
                }
            }
            return fired;
        }
    }
}

pub mod error_handling {

    pub class EngineError {
        pub let code: String;
        pub let message: String;
        pub let context: Map;
        pub let timestamp: Int;
        pub let recoverable: Bool;

        pub fn new(code: String, message: String, recoverable: Bool) -> Self {
            return Self {
                code: code,
                message: message,
                context: {},
                timestamp: native_production_time_ms(),
                recoverable: recoverable
            };
        }

        pub fn with_context(self, key: String, value: Any) -> Self {
            self.context[key] = value;
            return self;
        }
    }

    pub class ErrorRegistry {
        pub let errors: List;
        pub let max_errors: Int;

        pub fn new(max_errors: Int) -> Self {
            return Self { errors: [], max_errors: max_errors };
        }

        pub fn record(self, error: EngineError) {
            self.errors.push(error);
            if self.errors.len() > self.max_errors {
                self.errors = self.errors[self.errors.len() - self.max_errors..];
            }
        }

        pub fn get_recent(self, count: Int) -> List {
            let start = if self.errors.len() > count { self.errors.len() - count } else { 0 };
            return self.errors[start..];
        }

        pub fn count_by_code(self, code: String) -> Int {
            return self.errors.filter(fn(e) { e.code == code }).len();
        }
    }

    pub class RecoveryStrategy {
        pub let name: String;
        pub let max_attempts: Int;
        pub let handler: Fn;

        pub fn new(name: String, max_attempts: Int, handler: Fn) -> Self {
            return Self { name: name, max_attempts: max_attempts, handler: handler };
        }
    }

    pub class ErrorHandler {
        pub let registry: ErrorRegistry;
        pub let strategies: Map;
        pub let fallback: Fn?;

        pub fn new() -> Self {
            return Self {
                registry: ErrorRegistry::new(1000),
                strategies: {},
                fallback: null
            };
        }

        pub fn register_strategy(self, code: String, strategy: RecoveryStrategy) {
            self.strategies[code] = strategy;
        }

        pub fn set_fallback(self, handler: Fn) {
            self.fallback = handler;
        }

        pub fn handle(self, error: EngineError) -> Any? {
            self.registry.record(error);
            if error.recoverable and self.strategies[error.code] != null {
                let strategy = self.strategies[error.code];
                return strategy.handler(error);
            }
            if self.fallback != null { return self.fallback(error); }
            return null;
        }
    }
}

# ============================================================
# CONFIGURATION & LIFECYCLE MANAGEMENT
# ============================================================

pub mod config_management {

    pub class EnvConfig {
        pub let values: Map;
        pub let defaults: Map;
        pub let required_keys: List;

        pub fn new() -> Self {
            return Self { values: {}, defaults: {}, required_keys: [] };
        }

        pub fn set_default(self, key: String, value: Any) {
            self.defaults[key] = value;
        }

        pub fn set(self, key: String, value: Any) {
            self.values[key] = value;
        }

        pub fn require(self, key: String) {
            self.required_keys.push(key);
        }

        pub fn get(self, key: String) -> Any? {
            if self.values[key] != null { return self.values[key]; }
            return self.defaults[key];
        }

        pub fn get_int(self, key: String) -> Int {
            let v = self.get(key);
            if v == null { return 0; }
            return v.to_int();
        }

        pub fn get_bool(self, key: String) -> Bool {
            let v = self.get(key);
            if v == null { return false; }
            return v == true or v == "true" or v == "1";
        }

        pub fn validate(self) -> List {
            let missing = [];
            for key in self.required_keys {
                if self.get(key) == null { missing.push(key); }
            }
            return missing;
        }

        pub fn from_map(self, map: Map) {
            for key in map.keys() { self.values[key] = map[key]; }
        }
    }

    pub class FeatureFlag {
        pub let name: String;
        pub let enabled: Bool;
        pub let rollout_pct: Float;
        pub let metadata: Map;

        pub fn new(name: String, enabled: Bool) -> Self {
            return Self { name: name, enabled: enabled, rollout_pct: 100.0, metadata: {} };
        }

        pub fn is_enabled(self) -> Bool {
            return self.enabled;
        }

        pub fn is_enabled_for(self, user_id: String) -> Bool {
            if !self.enabled { return false; }
            if self.rollout_pct >= 100.0 { return true; }
            let hash = user_id.len() % 100;
            return hash < self.rollout_pct.to_int();
        }
    }

    pub class FeatureFlagManager {
        pub let flags: Map;

        pub fn new() -> Self {
            return Self { flags: {} };
        }

        pub fn register(self, flag: FeatureFlag) {
            self.flags[flag.name] = flag;
        }

        pub fn is_enabled(self, name: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled();
        }

        pub fn is_enabled_for(self, name: String, user_id: String) -> Bool {
            if self.flags[name] == null { return false; }
            return self.flags[name].is_enabled_for(user_id);
        }
    }
}

pub mod lifecycle {

    pub class Phase {
        pub let name: String;
        pub let order: Int;
        pub let handler: Fn;
        pub let completed: Bool;

        pub fn new(name: String, order: Int, handler: Fn) -> Self {
            return Self { name: name, order: order, handler: handler, completed: false };
        }
    }

    pub class LifecycleManager {
        pub let phases: List;
        pub let current_phase: String;
        pub let state: String;
        pub let hooks: Map;

        pub fn new() -> Self {
            return Self {
                phases: [],
                current_phase: "init",
                state: "created",
                hooks: {}
            };
        }

        pub fn add_phase(self, phase: Phase) {
            self.phases.push(phase);
            self.phases.sort_by(fn(a, b) { a.order - b.order });
        }

        pub fn on(self, event: String, handler: Fn) {
            if self.hooks[event] == null { self.hooks[event] = []; }
            self.hooks[event].push(handler);
        }

        pub fn start(self) {
            self.state = "starting";
            self._emit("before_start");
            for phase in self.phases {
                self.current_phase = phase.name;
                phase.handler();
                phase.completed = true;
            }
            self.state = "running";
            self._emit("after_start");
        }

        pub fn stop(self) {
            self.state = "stopping";
            self._emit("before_stop");
            for phase in self.phases.reverse() {
                self.current_phase = "teardown_" + phase.name;
            }
            self.state = "stopped";
            self._emit("after_stop");
        }

        fn _emit(self, event: String) {
            if self.hooks[event] != null {
                for handler in self.hooks[event] { handler(); }
            }
        }

        pub fn is_running(self) -> Bool {
            return self.state == "running";
        }
    }

    pub class ResourcePool {
        pub let name: String;
        pub let resources: List;
        pub let max_size: Int;
        pub let in_use: Int;

        pub fn new(name: String, max_size: Int) -> Self {
            return Self { name: name, resources: [], max_size: max_size, in_use: 0 };
        }

        pub fn acquire(self) -> Any? {
            if self.resources.len() > 0 {
                self.in_use = self.in_use + 1;
                return self.resources.pop();
            }
            if self.in_use < self.max_size {
                self.in_use = self.in_use + 1;
                return {};
            }
            return null;
        }

        pub fn release(self, resource: Any) {
            self.in_use = self.in_use - 1;
            self.resources.push(resource);
        }

        pub fn available(self) -> Int {
            return self.max_size - self.in_use;
        }
    }
}
