# Health Checks

api.zig supports health checks for production readiness and liveness probes.

## Built-in Checks

- Aggregated health status (ok/warning/fail)
- Custom checks (database, caches, external services)

Example:

```zig
var hc = try metrics.HealthChecks.init(allocator);
hc.addCheck("postgres", checkPostgresFn);
app.get("/health", (ctx) => Response.json(hc.statusJson()));
```

See `src/metrics.zig` for health check utilities and JSON output format.