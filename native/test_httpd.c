/* Test program for Nyx Native HTTP Server */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "nyx_httpd.h"

/* Handler for root path */
void handle_root(const NyxHttpRequest *req, NyxHttpResponse *resp, void *user_data) {
    (void)req;
    (void)user_data;
    
    const char *html = 
        "<!DOCTYPE html>\n"
        "<html>\n"
        "<head><title>Nyx Native HTTP Server Test</title></head>\n"
        "<body>\n"
        "<h1>🚀 Nyx Native HTTP Server</h1>\n"
        "<p>Server is running successfully!</p>\n"
        "<ul>\n"
        "<li><a href=\"/\">Home</a></li>\n"
        "<li><a href=\"/api/status\">API Status</a></li>\n"
        "<li><a href=\"/test\">Test Page</a></li>\n"
        "</ul>\n"
        "</body>\n"
        "</html>";
    
    nyx_http_response_html(resp, 200, html);
}

/* Handler for /api/status */
void handle_status(const NyxHttpRequest *req, NyxHttpResponse *resp, void *user_data) {
    (void)req;
    (void)user_data;
    
    const char *json = 
        "{\n"
        "  \"status\": \"online\",\n"
        "  \"server\": \"Nyx Native HTTPd\",\n"
        "  \"version\": \"1.0.0\",\n"
        "  \"timestamp\": 1708732800\n"
        "}";
    
    nyx_http_response_json(resp, 200, json);
}

/* Handler for /test */
void handle_test(const NyxHttpRequest *req, NyxHttpResponse *resp, void *user_data) {
    (void)req;
    (void)user_data;
    
    static char buffer[2048];
    snprintf(buffer, sizeof(buffer),
             "<html><body>"
             "<h1>Test Page</h1>"
             "<p>Request Method: %s</p>"
             "<p>Request Path: %s</p>"
             "<p>Remote IP: %s:%d</p>"
             "<p>Host: %s</p>"
             "</body></html>",
             req->method, req->path, 
             req->remote_addr, req->remote_port,
             req->host ? req->host : "unknown");
    
    nyx_http_response_html(resp, 200, buffer);
}

/* Logging middleware */
void logging_middleware(const NyxHttpRequest *req, NyxHttpResponse *resp, void *user_data) {
    (void)resp;
    (void)user_data;
    
    printf("[INFO] %s %s from %s\n", req->method, req->path, req->remote_addr);
}

int main(int argc, char *argv[]) {
    (void)argc;
    (void)argv;
    
    printf("================================================================================\n");
    printf("Nyx Native HTTP Server Test\n");
    printf("================================================================================\n\n");
    
    /* Create server with default config */
    NyxHttpdConfig config = nyx_httpd_default_config();
    config.port = 8080;
    config.bind_addr = "0.0.0.0";
    config.worker_threads = 4;
    config.max_connections = 1024;
    
    NyxHttpServer *server = nyx_httpd_create(&config);
    if (!server) {
        fprintf(stderr, "Failed to create HTTP server\n");
        return 1;
    }
    
    /* Register middleware */
    nyx_httpd_middleware(server, logging_middleware, NULL);
    
    /* Register routes */
    nyx_httpd_route(server, "GET", "/", handle_root, NULL);
    nyx_httpd_route(server, "GET", "/api/status", handle_status, NULL);
    nyx_httpd_route(server, "GET", "/test", handle_test, NULL);
    
    printf("Registered routes:\n");
    printf("  GET  /\n");
    printf("  GET  /api/status\n");
    printf("  GET  /test\n");
    printf("\n");
    
    /* Start server */
    printf("Starting server...\n");
    printf("Open browser: http://localhost:8080\n");
    printf("Press Ctrl+C to stop\n\n");
    
    int result = nyx_httpd_start(server);
    
    /* Cleanup */
    nyx_httpd_destroy(server);
    
    return result;
}
