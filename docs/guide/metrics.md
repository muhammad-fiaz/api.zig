# Metrics

Collect metrics and export Prometheus-compatible metrics with the built-in registry.

## Exporting Metrics

- Use `metrics.Registry` to register counters, gauges and histograms.
- Expose metrics endpoint and call `registry.scrape()` to generate Prometheus text.

Example:

```zig
var registry = try metrics.Registry.init(allocator);
registry.registerCounter("requests_total", "Total requests");
app.get("/metrics", (ctx) => Response.text(registry.scrape()))
```

See `src/metrics.zig` for implementation details and health check integrations.