/* =============================================================================
 * NYX NATIVE HTTP SERVER - Apache-style Production Server
 * =============================================================================
 * High-performance HTTP/1.1 server with Apache-compatible features:
 * - Multi-threaded worker pool
 * - Event-driven I/O (epoll/kqueue/IOCP)
 * - Virtual hosts
 * - URL routing and rewriting
 * - Static file serving with caching
 * - CGI/FastCGI support
 * - SSL/TLS 1.3
 * - Request/response middleware
 * - Access logging (Common/Combined format)
 * - Configurable timeouts and limits
 * - Graceful restart/shutdown
 * ============================================================================= */

#ifndef NYX_HTTPD_H
#define NYX_HTTPD_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* HTTP Server Configuration */
typedef struct NyxHttpdConfig {
    const char *bind_addr;          /* IP address to bind (e.g., "0.0.0.0") */
    uint16_t port;                  /* Port number (default: 8080) */
    int worker_threads;             /* Number of worker threads (default: 4) */
    int max_connections;            /* Max concurrent connections (default: 1024) */
    int keepalive_timeout_sec;      /* Keep-alive timeout (default: 5s) */
    int request_timeout_sec;        /* Request timeout (default: 30s) */
    size_t max_header_size;         /* Max header size in bytes (default: 8KB) */
    size_t max_body_size;           /* Max body size in bytes (default: 10MB) */
    const char *document_root;      /* Document root for static files */
    const char *log_file;           /* Access log file path */
    const char *error_log;          /* Error log file path */
    int enable_ssl;                 /* Enable SSL/TLS */
    const char *ssl_cert_file;      /* SSL certificate file */
    const char *ssl_key_file;       /* SSL private key file */
} NyxHttpdConfig;

/* HTTP Request */
typedef struct NyxHttpRequest {
    const char *method;             /* GET, POST, PUT, DELETE, etc. */
    const char *path;               /* Request path */
    const char *query_string;       /* Query string (after ?) */
    const char *protocol;           /* HTTP/1.0 or HTTP/1.1 */
    const char *host;               /* Host header */
    const char *content_type;       /* Content-Type header */
    size_t content_length;          /* Content-Length */
    void *headers;                  /* Header dict (opaque) */
    const char *body;               /* Request body (for POST/PUT) */
    size_t body_length;             /* Body length */
    const char *remote_addr;        /* Client IP address */
    uint16_t remote_port;           /* Client port */
} NyxHttpRequest;

/* HTTP Response */
typedef struct NyxHttpResponse {
    int status_code;                /* HTTP status code (200, 404, etc.) */
    const char *status_text;        /* Status text ("OK", "Not Found") */
    void *headers;                  /* Response headers (opaque) */
    const char *body;               /* Response body */
    size_t body_length;             /* Body length */
    int close_connection;           /* Close after response */
} NyxHttpResponse;

/* Request Handler Callback */
typedef void (*NyxHttpHandler)(const NyxHttpRequest *req, NyxHttpResponse *resp, void *user_data);

/* Server Handle */
typedef struct NyxHttpServer NyxHttpServer;

/* ============================================================================
 * HTTP SERVER API
 * ============================================================================ */

/* Initialize HTTP server with configuration */
NyxHttpServer* nyx_httpd_create(const NyxHttpdConfig *config);

/* Register a route handler */
int nyx_httpd_route(NyxHttpServer *server, const char *method, const char *path, 
                    NyxHttpHandler handler, void *user_data);

/* Register a middleware (runs before handlers) */
int nyx_httpd_middleware(NyxHttpServer *server, NyxHttpHandler middleware, void *user_data);

/* Start the server (blocking) */
int nyx_httpd_start(NyxHttpServer *server);

/* Start the server in background thread */
int nyx_httpd_start_async(NyxHttpServer *server);

/* Stop the server gracefully */
int nyx_httpd_stop(NyxHttpServer *server);

/* Destroy the server and free resources */
void nyx_httpd_destroy(NyxHttpServer *server);

/* ============================================================================
 * RESPONSE HELPERS
 * ============================================================================ */

/* Set response header */
void nyx_http_response_set_header(NyxHttpResponse *resp, const char *name, const char *value);

/* Send JSON response */
void nyx_http_response_json(NyxHttpResponse *resp, int status, const char *json);

/* Send HTML response */
void nyx_http_response_html(NyxHttpResponse *resp, int status, const char *html);

/* Send plain text response */
void nyx_http_response_text(NyxHttpResponse *resp, int status, const char *text);

/* Send file as response (static file serving) */
int nyx_http_response_file(NyxHttpResponse *resp, const char *file_path);

/* Send error response */
void nyx_http_response_error(NyxHttpResponse *resp, int status, const char *message);

/* ============================================================================
 * REQUEST HELPERS
 * ============================================================================ */

/* Get request header value */
const char* nyx_http_request_get_header(const NyxHttpRequest *req, const char *name);

/* Get query parameter */
const char* nyx_http_request_get_param(const NyxHttpRequest *req, const char *name);

/* Parse JSON body */
void* nyx_http_request_parse_json(const NyxHttpRequest *req);

/* Parse form data (application/x-www-form-urlencoded) */
void* nyx_http_request_parse_form(const NyxHttpRequest *req);

/* ============================================================================
 * DEFAULT CONFIGURATION
 * ============================================================================ */

/* Get default configuration */
NyxHttpdConfig nyx_httpd_default_config(void);

#ifdef __cplusplus
}
#endif

#endif /* NYX_HTTPD_H */
