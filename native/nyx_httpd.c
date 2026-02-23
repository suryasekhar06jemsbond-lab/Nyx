/* =============================================================================
 * NYX NATIVE HTTP SERVER - Apache-style Implementation
 * =============================================================================
 * Production-grade HTTP/1.1 server implementation
 * ============================================================================= */

#if defined(_MSC_VER) && !defined(_CRT_SECURE_NO_WARNINGS)
#define _CRT_SECURE_NO_WARNINGS
#endif

#include "nyx_httpd.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <errno.h>
#include <stdarg.h>

/* Platform-specific includes */
#if defined(_WIN32)
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #include <windows.h>
    #pragma comment(lib, "ws2_32.lib")
    typedef SOCKET socket_t;
    #define INVALID_SOCKET_FD INVALID_SOCKET
    #define close_socket closesocket
    #define strcasecmp _stricmp
#else
    #include <sys/socket.h>
    #include <sys/types.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <unistd.h>
    #include <fcntl.h>
    #include <pthread.h>
    typedef int socket_t;
    #define INVALID_SOCKET_FD -1
    #define close_socket close
#endif

/* ============================================================================
 * INTERNAL STRUCTURES
 * ============================================================================ */

#define MAX_ROUTES 256
#define MAX_MIDDLEWARE 32
#define MAX_HEADERS 64
#define BUFFER_SIZE 8192

typedef struct HttpHeader {
    char name[128];
    char value[512];
} HttpHeader;

typedef struct HttpHeaderDict {
    HttpHeader headers[MAX_HEADERS];
    int count;
} HttpHeaderDict;

typedef struct HttpRoute {
    char method[16];
    char path[256];
    NyxHttpHandler handler;
    void *user_data;
} HttpRoute;

struct NyxHttpServer {
    NyxHttpdConfig config;
    socket_t listen_socket;
    int running;
    HttpRoute routes[MAX_ROUTES];
    int route_count;
    NyxHttpHandler middlewares[MAX_MIDDLEWARE];
    void *middleware_data[MAX_MIDDLEWARE];
    int middleware_count;
#if defined(_WIN32)
    HANDLE *worker_threads;
#else
    pthread_t *worker_threads;
#endif
    FILE *access_log;
    FILE *error_log;
};

/* ============================================================================
 * UTILITY FUNCTIONS
 * ============================================================================ */

static char* str_dup(const char *s) {
    if (!s) return NULL;
    size_t len = strlen(s);
    char *copy = (char*)malloc(len + 1);
    if (copy) {
        memcpy(copy, s, len + 1);
    }
    return copy;
}

static void log_error(NyxHttpServer *server, const char *fmt, ...) {
    if (!server || !server->error_log) return;
    
    time_t now = time(NULL);
    char timebuf[64];
    strftime(timebuf, sizeof(timebuf), "%Y-%m-%d %H:%M:%S", localtime(&now));
    
    fprintf(server->error_log, "[%s] ", timebuf);
    
    va_list args;
    va_start(args, fmt);
    vfprintf(server->error_log, fmt, args);
    va_end(args);
    
    fprintf(server->error_log, "\n");
    fflush(server->error_log);
}

static void log_access(NyxHttpServer *server, const NyxHttpRequest *req, 
                       const NyxHttpResponse *resp) {
    if (!server || !server->access_log) return;
    
    time_t now = time(NULL);
    char timebuf[64];
    strftime(timebuf, sizeof(timebuf), "%d/%b/%Y:%H:%M:%S %z", localtime(&now));
    
    /* Common Log Format */
    fprintf(server->access_log, "%s - - [%s] \"%s %s %s\" %d %zu\n",
            req->remote_addr ? req->remote_addr : "-",
            timebuf,
            req->method ? req->method : "-",
            req->path ? req->path : "-",
            req->protocol ? req->protocol : "-",
            resp->status_code,
            resp->body_length);
    fflush(server->access_log);
}

/* ============================================================================
 * HTTP PARSING
 * ============================================================================ */

static int parse_request_line(const char *line, char *method, char *path, 
                               char *query, char *protocol) {
    /* Parse: GET /path?query HTTP/1.1 */
    const char *p = line;
    
    /* Extract method */
    const char *space1 = strchr(p, ' ');
    if (!space1) return -1;
    size_t method_len = space1 - p;
    if (method_len >= 16) return -1;
    memcpy(method, p, method_len);
    method[method_len] = '\0';
    
    /* Extract path and query */
    p = space1 + 1;
    const char *space2 = strchr(p, ' ');
    if (!space2) return -1;
    
    const char *q = strchr(p, '?');
    if (q && q < space2) {
        /* Has query string */
        size_t path_len = q - p;
        if (path_len >= 256) return -1;
        memcpy(path, p, path_len);
        path[path_len] = '\0';
        
        size_t query_len = space2 - q - 1;
        if (query_len >= 512) return -1;
        memcpy(query, q + 1, query_len);
        query[query_len] = '\0';
    } else {
        /* No query string */
        size_t path_len = space2 - p;
        if (path_len >= 256) return -1;
        memcpy(path, p, path_len);
        path[path_len] = '\0';
        query[0] = '\0';
    }
    
    /* Extract protocol */
    p = space2 + 1;
    size_t proto_len = strlen(p);
    if (proto_len >= 16) return -1;
    strcpy(protocol, p);
    
    return 0;
}

static int parse_header(const char *line, char *name, char *value) {
    const char *colon = strchr(line, ':');
    if (!colon) return -1;
    
    size_t name_len = colon - line;
    if (name_len >= 128) return -1;
    memcpy(name, line, name_len);
    name[name_len] = '\0';
    
    const char *val = colon + 1;
    while (*val == ' ' || *val == '\t') val++;
    
    size_t val_len = strlen(val);
    if (val_len >= 512) return -1;
    strcpy(value, val);
    
    return 0;
}

/* ============================================================================
 * REQUEST/RESPONSE MANAGEMENT
 * ============================================================================ */

static NyxHttpRequest* create_request(void) {
    NyxHttpRequest *req = (NyxHttpRequest*)calloc(1, sizeof(NyxHttpRequest));
    if (req) {
        req->headers = calloc(1, sizeof(HttpHeaderDict));
    }
    return req;
}

static void destroy_request(NyxHttpRequest *req) {
    if (!req) return;
    if (req->headers) free(req->headers);
    free(req);
}

static NyxHttpResponse* create_response(void) {
    NyxHttpResponse *resp = (NyxHttpResponse*)calloc(1, sizeof(NyxHttpResponse));
    if (resp) {
        resp->headers = calloc(1, sizeof(HttpHeaderDict));
        resp->status_code = 200;
        resp->status_text = "OK";
    }
    return resp;
}

static void destroy_response(NyxHttpResponse *resp) {
    if (!resp) return;
    if (resp->headers) free(resp->headers);
    free(resp);
}

/* ============================================================================
 * RESPONSE HELPERS
 * ============================================================================ */

void nyx_http_response_set_header(NyxHttpResponse *resp, const char *name, const char *value) {
    if (!resp || !resp->headers || !name || !value) return;
    
    HttpHeaderDict *dict = (HttpHeaderDict*)resp->headers;
    if (dict->count >= MAX_HEADERS) return;
    
    strncpy(dict->headers[dict->count].name, name, sizeof(dict->headers[0].name) - 1);
    strncpy(dict->headers[dict->count].value, value, sizeof(dict->headers[0].value) - 1);
    dict->count++;
}

void nyx_http_response_json(NyxHttpResponse *resp, int status, const char *json) {
    resp->status_code = status;
    resp->body = json;
    resp->body_length = json ? strlen(json) : 0;
    nyx_http_response_set_header(resp, "Content-Type", "application/json");
}

void nyx_http_response_html(NyxHttpResponse *resp, int status, const char *html) {
    resp->status_code = status;
    resp->body = html;
    resp->body_length = html ? strlen(html) : 0;
    nyx_http_response_set_header(resp, "Content-Type", "text/html; charset=utf-8");
}

void nyx_http_response_text(NyxHttpResponse *resp, int status, const char *text) {
    resp->status_code = status;
    resp->body = text;
    resp->body_length = text ? strlen(text) : 0;
    nyx_http_response_set_header(resp, "Content-Type", "text/plain; charset=utf-8");
}

void nyx_http_response_error(NyxHttpResponse *resp, int status, const char *message) {
    resp->status_code = status;
    
    static char error_body[1024];
    snprintf(error_body, sizeof(error_body),
             "<html><head><title>%d Error</title></head>"
             "<body><h1>%d Error</h1><p>%s</p></body></html>",
             status, status, message ? message : "Unknown error");
    
    resp->body = error_body;
    resp->body_length = strlen(error_body);
    nyx_http_response_set_header(resp, "Content-Type", "text/html");
}

int nyx_http_response_file(NyxHttpResponse *resp, const char *file_path) {
    FILE *f = fopen(file_path, "rb");
    if (!f) {
        nyx_http_response_error(resp, 404, "File not found");
        return -1;
    }
    
    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);
    
    char *content = (char*)malloc(size + 1);
    if (!content) {
        fclose(f);
        nyx_http_response_error(resp, 500, "Memory allocation failed");
        return -1;
    }
    
    fread(content, 1, size, f);
    content[size] = '\0';
    fclose(f);
    
    resp->status_code = 200;
    resp->body = content;
    resp->body_length = size;
    
    /* Detect content type */
    const char *ext = strrchr(file_path, '.');
    if (ext) {
        if (strcmp(ext, ".html") == 0 || strcmp(ext, ".htm") == 0) {
            nyx_http_response_set_header(resp, "Content-Type", "text/html");
        } else if (strcmp(ext, ".css") == 0) {
            nyx_http_response_set_header(resp, "Content-Type", "text/css");
        } else if (strcmp(ext, ".js") == 0) {
            nyx_http_response_set_header(resp, "Content-Type", "application/javascript");
        } else if (strcmp(ext, ".json") == 0) {
            nyx_http_response_set_header(resp, "Content-Type", "application/json");
        } else if (strcmp(ext, ".png") == 0) {
            nyx_http_response_set_header(resp, "Content-Type", "image/png");
        } else if (strcmp(ext, ".jpg") == 0 || strcmp(ext, ".jpeg") == 0) {
            nyx_http_response_set_header(resp, "Content-Type", "image/jpeg");
        }
    }
    
    return 0;
}

/* ============================================================================
 * REQUEST HELPERS
 * ============================================================================ */

const char* nyx_http_request_get_header(const NyxHttpRequest *req, const char *name) {
    if (!req || !req->headers || !name) return NULL;
    
    HttpHeaderDict *dict = (HttpHeaderDict*)req->headers;
    for (int i = 0; i < dict->count; i++) {
        if (strcasecmp(dict->headers[i].name, name) == 0) {
            return dict->headers[i].value;
        }
    }
    return NULL;
}

const char* nyx_http_request_get_param(const NyxHttpRequest *req, const char *name) {
    /* TODO: Parse query string parameters */
    return NULL;
}

/* ============================================================================
 * SERVER CORE
 * ============================================================================ */

NyxHttpdConfig nyx_httpd_default_config(void) {
    NyxHttpdConfig config = {0};
    config.bind_addr = "0.0.0.0";
    config.port = 8080;
    config.worker_threads = 4;
    config.max_connections = 1024;
    config.keepalive_timeout_sec = 5;
    config.request_timeout_sec = 30;
    config.max_header_size = 8192;
    config.max_body_size = 10 * 1024 * 1024; /* 10MB */
    config.document_root = ".";
    config.log_file = "access.log";
    config.error_log = "error.log";
    config.enable_ssl = 0;
    return config;
}

NyxHttpServer* nyx_httpd_create(const NyxHttpdConfig *config) {
    NyxHttpServer *server = (NyxHttpServer*)calloc(1, sizeof(NyxHttpServer));
    if (!server) return NULL;
    
    if (config) {
        server->config = *config;
    } else {
        server->config = nyx_httpd_default_config();
    }
    
    /* Open log files */
    if (server->config.log_file) {
        server->access_log = fopen(server->config.log_file, "a");
    }
    if (server->config.error_log) {
        server->error_log = fopen(server->config.error_log, "a");
    }
    
    server->listen_socket = INVALID_SOCKET_FD;
    server->running = 0;
    
    return server;
}

int nyx_httpd_route(NyxHttpServer *server, const char *method, const char *path,
                    NyxHttpHandler handler, void *user_data) {
    if (!server || !method || !path || !handler) return -1;
    if (server->route_count >= MAX_ROUTES) return -1;
    
    HttpRoute *route = &server->routes[server->route_count++];
    strncpy(route->method, method, sizeof(route->method) - 1);
    strncpy(route->path, path, sizeof(route->path) - 1);
    route->handler = handler;
    route->user_data = user_data;
    
    return 0;
}

int nyx_httpd_middleware(NyxHttpServer *server, NyxHttpHandler middleware, void *user_data) {
    if (!server || !middleware) return -1;
    if (server->middleware_count >= MAX_MIDDLEWARE) return -1;
    
    server->middlewares[server->middleware_count] = middleware;
    server->middleware_data[server->middleware_count] = user_data;
    server->middleware_count++;
    
    return 0;
}

static int send_response(socket_t client_socket, const NyxHttpResponse *resp) {
    char buffer[BUFFER_SIZE];
    int len = snprintf(buffer, sizeof(buffer),
                      "HTTP/1.1 %d %s\r\n",
                      resp->status_code,
                      resp->status_text ? resp->status_text : "OK");
    
    /* Add headers */
    HttpHeaderDict *dict = (HttpHeaderDict*)resp->headers;
    for (int i = 0; i < dict->count; i++) {
        len += snprintf(buffer + len, sizeof(buffer) - len,
                       "%s: %s\r\n",
                       dict->headers[i].name,
                       dict->headers[i].value);
    }
    
    /* Content-Length */
    len += snprintf(buffer + len, sizeof(buffer) - len,
                   "Content-Length: %zu\r\n", resp->body_length);
    
    /* End of headers */
    len += snprintf(buffer + len, sizeof(buffer) - len, "\r\n");
    
    /* Send headers */
    send(client_socket, buffer, len, 0);
    
    /* Send body */
    if (resp->body && resp->body_length > 0) {
        send(client_socket, resp->body, (int)resp->body_length, 0);
    }
    
    return 0;
}

static void handle_client(NyxHttpServer *server, socket_t client_socket,
                          const char *client_addr, uint16_t client_port) {
    char buffer[BUFFER_SIZE];
    int bytes_read = recv(client_socket, buffer, sizeof(buffer) - 1, 0);
    
    if (bytes_read <= 0) {
        close_socket(client_socket);
        return;
    }
    
    buffer[bytes_read] = '\0';
    
    /* Parse request */
    NyxHttpRequest *req = create_request();
    NyxHttpResponse *resp = create_response();
    
    if (!req || !resp) {
        if (req) destroy_request(req);
        if (resp) destroy_response(resp);
        close_socket(client_socket);
        return;
    }
    
    req->remote_addr = client_addr;
    req->remote_port = client_port;
    
    /* Parse request line */
    char method[16], path[256], query[512], protocol[16];
    char *line_end = strstr(buffer, "\r\n");
    if (line_end) {
        *line_end = '\0';
        if (parse_request_line(buffer, method, path, query, protocol) == 0) {
            req->method = str_dup(method);
            req->path = str_dup(path);
            req->query_string = str_dup(query);
            req->protocol = str_dup(protocol);
        }
    }
    
    /* Parse headers */
    char *header_line = line_end + 2;
    HttpHeaderDict *hdict = (HttpHeaderDict*)req->headers;
    while ((line_end = strstr(header_line, "\r\n")) != NULL) {
        if (line_end == header_line) break; /* End of headers */
        
        *line_end = '\0';
        char name[128], value[512];
        if (parse_header(header_line, name, value) == 0) {
            if (hdict->count < MAX_HEADERS) {
                strcpy(hdict->headers[hdict->count].name, name);
                strcpy(hdict->headers[hdict->count].value, value);
                hdict->count++;
                
                /* Store important headers */
                if (strcasecmp(name, "Host") == 0) {
                    req->host = str_dup(value);
                } else if (strcasecmp(name, "Content-Type") == 0) {
                    req->content_type = str_dup(value);
                } else if (strcasecmp(name, "Content-Length") == 0) {
                    req->content_length = atoi(value);
                }
            }
        }
        header_line = line_end + 2;
    }
    
    /* Run middlewares */
    for (int i = 0; i < server->middleware_count; i++) {
        server->middlewares[i](req, resp, server->middleware_data[i]);
    }
    
    /* Find matching route */
    int handled = 0;
    for (int i = 0; i < server->route_count; i++) {
        HttpRoute *route = &server->routes[i];
        if (strcmp(route->method, req->method) == 0 && 
            strcmp(route->path, req->path) == 0) {
            route->handler(req, resp, route->user_data);
            handled = 1;
            break;
        }
    }
    
    /* Default 404 if no route matched */
    if (!handled) {
        nyx_http_response_error(resp, 404, "Not Found");
    }
    
    /* Send response */
    send_response(client_socket, resp);
    
    /* Log access */
    log_access(server, req, resp);
    
    /* Cleanup */
    destroy_request(req);
    destroy_response(resp);
    close_socket(client_socket);
}

int nyx_httpd_start(NyxHttpServer *server) {
    if (!server) return -1;
    
#if defined(_WIN32)
    WSADATA wsa_data;
    if (WSAStartup(MAKEWORD(2, 2), &wsa_data) != 0) {
        log_error(server, "WSAStartup failed");
        return -1;
    }
#endif
    
    /* Create listening socket */
    server->listen_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (server->listen_socket == INVALID_SOCKET_FD) {
        log_error(server, "Failed to create socket");
        return -1;
    }
    
    /* Set socket options */
    int opt = 1;
    setsockopt(server->listen_socket, SOL_SOCKET, SO_REUSEADDR, 
               (const char*)&opt, sizeof(opt));
    
    /* Bind to address */
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(server->config.port);
    addr.sin_addr.s_addr = inet_addr(server->config.bind_addr);
    
    if (bind(server->listen_socket, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        log_error(server, "Failed to bind to %s:%d", 
                 server->config.bind_addr, server->config.port);
        close_socket(server->listen_socket);
        return -1;
    }
    
    /* Listen */
    if (listen(server->listen_socket, server->config.max_connections) < 0) {
        log_error(server, "Failed to listen on socket");
        close_socket(server->listen_socket);
        return -1;
    }
    
    printf("Nyx HTTP Server listening on http://%s:%d\n",
           server->config.bind_addr, server->config.port);
    
    server->running = 1;
    
    /* Accept loop */
    while (server->running) {
        struct sockaddr_in client_addr;
        socklen_t client_len = sizeof(client_addr);
        
        socket_t client_socket = accept(server->listen_socket,
                                        (struct sockaddr*)&client_addr,
                                        &client_len);
        
        if (client_socket == INVALID_SOCKET_FD) {
            if (server->running) {
                log_error(server, "Failed to accept connection");
            }
            continue;
        }
        
        char client_ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &client_addr.sin_addr, client_ip, sizeof(client_ip));
        uint16_t client_port = ntohs(client_addr.sin_port);
        
        /* Handle request (single-threaded for now) */
        handle_client(server, client_socket, client_ip, client_port);
    }
    
    return 0;
}

int nyx_httpd_stop(NyxHttpServer *server) {
    if (!server) return -1;
    
    server->running = 0;
    
    if (server->listen_socket != INVALID_SOCKET_FD) {
        close_socket(server->listen_socket);
        server->listen_socket = INVALID_SOCKET_FD;
    }
    
#if defined(_WIN32)
    WSACleanup();
#endif
    
    return 0;
}

void nyx_httpd_destroy(NyxHttpServer *server) {
    if (!server) return;
    
    nyx_httpd_stop(server);
    
    if (server->access_log) fclose(server->access_log);
    if (server->error_log) fclose(server->error_log);
    
    free(server);
}
