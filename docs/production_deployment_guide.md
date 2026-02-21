# Production Deployment Guide

## 1) Baseline hardened configuration

```nyx
site = nyui.createWebsite("ProdSite");
site = site.withState({});
site = site.renderMode("hybrid");
site = site.diffRendering(true);
site = site.diffPolicy(2000);
site = site.workerModel(512);
site = site.wsPolicy(120, 262144, 2048, 262144);
site = site.multiInstance(".nyx/cluster_state.json", "prod", true);
site = site.observability(true, true, "/__nyx/metrics", "/__nyx/errors", "/__nyx/plugins", 500);
site = site.pluginContract(false);
site = site.securityLayer(true, 240, 60, null, 7200, "X-NYX-Request-ID", 120, true, 1048576, true, null);
```

## 2) Runtime startup checklist

1. Configure `workerModel` for expected peak concurrency.
2. Enable `securityLayer` with replay enforcement enabled.
3. Enable `observability` and scrape metrics endpoints.
4. Use `multiInstance` or `coordinationProvider` for clustered deployments.
5. Mount static assets via `public`/`mountStatic`.
6. Register APIs and website routes.
7. Start with `site.run(host, port)`.

## 3) Full NyxWebsite API reference (`site.*`)

### Rendering and routes

- `pageTitle(title)`
- `locale(lang)`
- `get(path, handler)`
- `notFound(handler)`
- `render(path, diff_limit=None)`
- `run(host, port)`

### Head/assets

- `meta(name, content)`
- `headLink(rel, href, attrs=None)`
- `headScript(src, defer=true, module=false, attrs=None)`
- `inlineScript(code)`
- `inlineStyle(theme)`
- `stylesheet(href, local=true, url_prefix="/assets")`
- `localStylesheet(relative_path, url_prefix="/assets")`
- `favicon(href)`
- `asset(relative_path, url_prefix="/assets")`
- `public(directory, url_prefix="/assets")`
- `mountStatic(url_prefix, directory)`

### Theme/style

- `withStyles(rules)`
- `withTheme(theme)`
- `withThemeMap(theme_map)`

### Render modes / hydration / diff

- `renderMode(mode)`
- `modeProvider(provider)`
- `ssr()`
- `csr()`
- `hybrid()`
- `hydrate(state=None, root_id="nyx-root")`
- `diffRendering(enabled=true)`
- `diffPolicy(max_updates=2000)`

### State / persistence / distributed

- `withState(initial_state=None)`
- `persistent(path=".nyx/site_state.json")`
- `multiInstance(path=".nyx/cluster_state.json", namespace="default", sync_state=true)`
- `coordinationProvider(provider, namespace="default", sync_state=true)`

### Middleware / plugin model

- `use(middleware)`
- `useFn(handler)`
- `plugin(plugin_obj)`
- `usePlugin(plugin_obj)`
- `pluginContract(fail_fast=false)`
- `pluginSnapshot()`

### HTTP/API helpers

- `getApi(path, handler)`
- `postApi(path, handler)`
- `putApi(path, handler)`
- `deleteApi(path, handler)`
- `header(name, value)`

### Security / validation

- `securityLayer(csrf=true, rate_limit=120, rate_window=60, trust_proxy_header=None, csrf_ttl_seconds=7200, replay_header_name="X-NYX-Request-ID", replay_window_seconds=120, enforce_replay_id=true, max_payload_bytes=1048576, strict_content_type=true, allowed_content_types=None)`
- `csrf(enabled=true)`
- `rateLimit(max_requests=120, window_seconds=60)`
- `validate(rule, message="Request validation failed")`
- `jsonSchema(path, schema, message=None)`

### Concurrency / sockets

- `workerModel(max_concurrency=256)`
- `websocket(path, handler)`
- `ws(path, handler)`
- `websocketPolicy(idle_timeout_seconds=120, max_frame_bytes=262144, max_messages=2048, max_send_bytes=262144)`
- `wsPolicy(idle_timeout_seconds=120, max_frame_bytes=262144, max_messages=2048, max_send_bytes=262144)`

### Observability / tracing

- `observability(enabled=true, structured_logs=false, metrics_path="/__nyx/metrics", errors_path="/__nyx/errors", plugins_path="/__nyx/plugins", max_errors=200)`
- `trace(hook)`

## 4) Security parameter quick guide

- `csrf`: protects mutating requests with token+cookie match.
- `rate_limit` / `rate_window`: fixed-window budget.
- `csrf_ttl_seconds`: token expiration.
- `replay_header_name`: idempotency/replay header.
- `replay_window_seconds`: replay TTL window.
- `enforce_replay_id`: require replay header on mutating verbs.
- `max_payload_bytes`: reject oversized body.
- `strict_content_type`: reject unsupported content-type.
- `allowed_content_types`: explicit allowlist.

## 5) Worker model explanation

- Admission control via bounded semaphore.
- Bounded queue for dispatch tasks.
- Worker thread pool for handler execution.
- Timeout and queue-full fail-fast behavior.

## 6) Diff policy explanation

`diffPolicy(max_updates)` caps returned diff updates for `GET /__nyx/diff`.
This bounds payload size and diff compute overhead under large UI changes.

## 7) Plugin contract

Hooks:

1. `setup(site)`
2. `middleware()`
3. `apply(app, site)`
4. `on_start(app, site)`

Governed by:

- `priority` ordering
- `capabilities` metadata
- `fail_open` behavior
- `pluginContract(fail_fast)` global runtime policy
