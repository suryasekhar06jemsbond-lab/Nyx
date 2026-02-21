# Metrics Dashboard Example

This directory contains a generic JSON dashboard model for the Nyx metrics endpoint.

1. Run a Nyx site with observability enabled.
2. Query `http://127.0.0.1:8080/__nyx/metrics`.
3. Map your dashboard tool fields to `tests/metrics_dashboard_example/dashboard.json` panel paths.

Companion endpoints:
- `GET /__nyx/errors`
- `GET /__nyx/plugins`
- `GET /__nyx/health`
