# Observability

## Runtime observability layer

Nyx runtime includes a native observability subsystem (`RuntimeObservability`) with:

- Structured JSON logging (optional).
- Request counters and latency metrics.
- Error recording with bounded retention.
- WebSocket connection/message counters.
- Trace hook callbacks.

## Endpoints

- `GET /__nyx/metrics`
- `GET /__nyx/errors`
- `GET /__nyx/plugins`
- `GET /__nyx/health`

## Metrics fields

Core:

- `metrics.requests_total`
- `metrics.requests_in_flight`
- `metrics.responses_by_status`
- `metrics.requests_by_method`
- `metrics.latency_ms_avg`
- `metrics.latency_ms_max`
- `metrics.error_rate`
- `metrics.ws_connections_open`
- `metrics.ws_messages_in`
- `metrics.ws_messages_out`

Extended payload (`/__nyx/metrics`):

- `worker.utilization`
- `worker.queue_size`
- `process.memory_mb`
- plugin count/error summary

## Trace hooks

Attach with:

- `site.trace(hook)`

Emitted events include:

- `http.request.completed`
- `runtime.error`
- `middleware.timing`
- `handler.timing`
- `render.completed`
- `diff.completed`
- websocket open/close/in events

## Production logging toggle

Use:

- `site.observability(true, true, ...)`

Second argument (`structured_logs`) enables JSON log lines to stdout.

## Health degradation

`/__nyx/health` degrades when:

- Worker utilization exceeds threshold.
- Runtime errors are present.
