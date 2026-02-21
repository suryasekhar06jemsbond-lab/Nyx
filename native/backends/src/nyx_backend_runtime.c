#include "nyx_backend_runtime.h"

#include <string.h>

static NyxBackendRuntimeConfig g_cfg;
static NyxBackendRuntimeHealth g_health;

void nyx_backend_runtime_init(const NyxBackendRuntimeConfig *cfg) {
    if (cfg) {
        g_cfg = *cfg;
    } else {
        memset(&g_cfg, 0, sizeof(g_cfg));
    }
    g_health.frame_ms = 0.0;
    g_health.deterministic_ok = 1;
    g_health.backend_alive = 1;
}

void nyx_backend_runtime_shutdown(void) {
    memset(&g_cfg, 0, sizeof(g_cfg));
    g_health.backend_alive = 0;
}

void nyx_backend_runtime_tick(double dt_sec) {
    (void)dt_sec;
    g_health.frame_ms = dt_sec * 1000.0;
    g_health.deterministic_ok = 1;
}

NyxBackendRuntimeHealth nyx_backend_runtime_health(void) {
    return g_health;
}
