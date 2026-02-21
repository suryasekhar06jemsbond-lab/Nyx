#ifndef NYX_BACKEND_RUNTIME_H
#define NYX_BACKEND_RUNTIME_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NyxBackendRuntimeConfig {
    int enable_render;
    int enable_physics;
    int enable_world;
    int enable_ai;
    int enable_net;
    int enable_audio;
    int enable_anim;
    int enable_logic;
    int enable_core;
} NyxBackendRuntimeConfig;

typedef struct NyxBackendRuntimeHealth {
    double frame_ms;
    int deterministic_ok;
    int backend_alive;
} NyxBackendRuntimeHealth;

void nyx_backend_runtime_init(const NyxBackendRuntimeConfig *cfg);
void nyx_backend_runtime_shutdown(void);
void nyx_backend_runtime_tick(double dt_sec);
NyxBackendRuntimeHealth nyx_backend_runtime_health(void);

#ifdef __cplusplus
}
#endif

#endif
