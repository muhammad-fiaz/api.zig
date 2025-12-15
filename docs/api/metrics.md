# Metrics Module

The Metrics module provides Prometheus-compatible metrics collection, health checks, and monitoring capabilities for production-ready applications.

## Overview

```zig
const metrics = @import("api").metrics;
```

## Quick Start

```zig
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    
    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    // Enable metrics
    try app.enableMetrics(.{});

    // Enable health checks
    try app.enableHealthChecks();

    // Metrics endpoint: GET /metrics
    // Health endpoint: GET /health

    try app.listen(.{ .port = 8080 });
}
```

## Metric Types

### Counter

Counters are monotonically increasing values, useful for counting requests, errors, etc.

```zig
const Counter = struct {
    name: []const u8,
    help: []const u8,
    labels: []const []const u8,
    value: std.atomic.Value(u64),
    
    pub fn inc(self: *Counter) void {
        _ = self.value.fetchAdd(1, .monotonic);
    }

    pub fn add(self: *Counter, val: u64) void {
        _ = self.value.fetchAdd(val, .monotonic);
    }

    pub fn get(self: *const Counter) u64 {
        return self.value.load(.monotonic);
    }
};
```

#### Using Counters

```zig
var registry = try metrics.Registry.init(allocator, .{});

// Register a counter
const requests_counter = try registry.registerCounter(
    "http_requests_total",
    "Total number of HTTP requests"
);

// Increment
requests_counter.inc();

// Add multiple
requests_counter.add(5);

// Get value
const total = requests_counter.get();
```

### Gauge

Gauges represent values that can go up or down, like active connections or memory usage.

```zig
const Gauge = struct {
    name: []const u8,
    help: []const u8,
    labels: []const []const u8,
    value: std.atomic.Value(i64),

    pub fn set(self: *Gauge, val: i64) void {
        self.value.store(val, .monotonic);
    }

    pub fn inc(self: *Gauge) void {
        _ = self.value.fetchAdd(1, .monotonic);
    }

    pub fn dec(self: *Gauge) void {
        _ = self.value.fetchSub(1, .monotonic);
    }

    pub fn get(self: *const Gauge) i64 {
        return self.value.load(.monotonic);
    }
};
```

#### Using Gauges

```zig
const active_connections = try registry.registerGauge(
    "active_connections",
    "Number of active connections"
);

// Set absolute value
active_connections.set(42);

// Increment/decrement
active_connections.inc();
active_connections.dec();

// Get value
const current = active_connections.get();
```

### Histogram

Histograms track the distribution of values with configurable buckets.

```zig
const Histogram = struct {
    name: []const u8,
    help: []const u8,
    labels: []const []const u8,
    buckets: []Bucket,
    sum: std.atomic.Value(i64),    // Sum in microseconds
    count: std.atomic.Value(u64),

    pub const DefaultBuckets = &[_]f64{
        0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0,
    };

    pub fn observe(self: *Histogram, value: f64) void {
        // Record value in appropriate bucket
        const micros: i64 = @intFromFloat(value * 1_000_000);
        _ = self.sum.fetchAdd(micros, .monotonic);
        _ = self.count.fetchAdd(1, .monotonic);
        
        for (self.buckets) |*bucket| {
            if (value <= bucket.upper_bound) {
                _ = bucket.count.fetchAdd(1, .monotonic);
            }
        }
    }

    pub fn getSum(self: *const Histogram) f64 {
        return @as(f64, @floatFromInt(self.sum.load(.monotonic))) / 1_000_000;
    }

    pub fn getCount(self: *const Histogram) u64 {
        return self.count.load(.monotonic);
    }
};
```

#### Using Histograms

```zig
// With default buckets
const request_duration = try registry.registerHistogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    &metrics.Histogram.DefaultBuckets
);

// With custom buckets
const response_size = try registry.registerHistogram(
    "http_response_size_bytes",
    "HTTP response size in bytes",
    &.{ 100, 1000, 10000, 100000, 1000000 }
);

// Record observations
request_duration.observe(0.123);  // 123ms
response_size.observe(4096);       // 4KB response
```

## Registry

The Registry manages all metrics and provides Prometheus export.

### Creating a Registry

```zig
var registry = try metrics.Registry.init(allocator, .{
    .prefix = "myapp", // Optional prefix for all metrics
});
defer registry.deinit();
```

### Built-in HTTP Metrics

The registry includes built-in metrics for HTTP servers:

```zig
// Automatically available:
registry.http_requests_total      // Counter
registry.http_request_duration_seconds  // Histogram
registry.http_requests_in_flight  // Gauge
registry.http_response_size_bytes // Histogram
```

### Prometheus Export

```zig
const output = try registry.toPrometheus(allocator);
defer allocator.free(output);

// Output format:
// # HELP http_requests_total Total number of HTTP requests
// # TYPE http_requests_total counter
// http_requests_total 1234
//
// # HELP http_request_duration_seconds HTTP request duration in seconds
// # TYPE http_request_duration_seconds histogram
// http_request_duration_seconds_bucket{le="0.005"} 10
// http_request_duration_seconds_bucket{le="0.01"} 25
// ...
// http_request_duration_seconds_bucket{le="+Inf"} 100
// http_request_duration_seconds_sum 12.345
// http_request_duration_seconds_count 100
```

## Health Checks

### HealthChecker

```zig
const HealthChecker = struct {
    allocator: std.mem.Allocator,
    checks: std.StringHashMap(*Check),
    status: HealthStatus,

    pub const HealthStatus = enum {
        healthy,
        degraded,
        unhealthy,
    };

    pub const Check = struct {
        name: []const u8,
        check_fn: *const fn () CheckResult,
        timeout_ms: u32 = 5000,
        critical: bool = true,
    };

    pub const CheckResult = struct {
        status: HealthStatus,
        message: ?[]const u8 = null,
        duration_ms: u64 = 0,
    };
};
```

### Registering Health Checks

```zig
var health = try metrics.HealthChecker.init(allocator);

// Database check
try health.registerCheck(.{
    .name = "database",
    .check_fn = checkDatabase,
    .timeout_ms = 5000,
    .critical = true,
});

// Redis check
try health.registerCheck(.{
    .name = "redis",
    .check_fn = checkRedis,
    .timeout_ms = 1000,
    .critical = false, // Non-critical
});

fn checkDatabase() metrics.HealthChecker.CheckResult {
    // Check database connection
    if (db.ping()) {
        return .{ .status = .healthy };
    } else {
        return .{ .status = .unhealthy, .message = "Cannot connect to database" };
    }
}

fn checkRedis() metrics.HealthChecker.CheckResult {
    if (redis.ping()) {
        return .{ .status = .healthy };
    } else {
        return .{ .status = .degraded, .message = "Redis unavailable" };
    }
}
```

### Running Health Checks

```zig
const result = try health.runAll();

// Result contains:
// - Overall status (healthy, degraded, unhealthy)
// - Individual check results
// - Timing information
```

### Health Endpoint Response

```json
{
  "status": "healthy",
  "checks": {
    "database": {
      "status": "healthy",
      "duration_ms": 12
    },
    "redis": {
      "status": "healthy",
      "duration_ms": 3
    }
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## Middleware Integration

### Metrics Middleware

```zig
const metricsMiddleware = struct {
    fn handle(ctx: *api.Context, next: api.NextFn) !void {
        const start = std.time.milliTimestamp();
        
        // Increment in-flight gauge
        ctx.app.metrics_registry.?.http_requests_in_flight.inc();
        defer ctx.app.metrics_registry.?.http_requests_in_flight.dec();

        // Call next handler
        try next(ctx);

        // Record metrics
        const duration = @as(f64, @floatFromInt(std.time.milliTimestamp() - start)) / 1000.0;
        ctx.app.metrics_registry.?.http_requests_total.inc();
        ctx.app.metrics_registry.?.http_request_duration_seconds.observe(duration);
    }
}.handle;

app.use(metricsMiddleware);
```

## Configuration

### RegistryConfig

```zig
const RegistryConfig = struct {
    // Prefix for all metric names
    prefix: ?[]const u8 = null,
    
    // Enable/disable built-in HTTP metrics
    enable_http_metrics: bool = true,
    
    // Custom histogram buckets for request duration
    request_duration_buckets: []const f64 = &Histogram.DefaultBuckets,
    
    // Custom histogram buckets for response size
    response_size_buckets: []const f64 = &.{ 100, 1000, 10000, 100000, 1000000 },
};
```

## Labels

### Adding Labels to Metrics

```zig
// Counter with labels
const Counter = struct {
    name: []const u8,
    help: []const u8,
    labels: []const []const u8, // e.g., &.{"method", "path", "status"}
};

// Create labeled counter
const requests = try registry.registerCounter(
    "http_requests_total",
    "Total HTTP requests",
);

// Labels are typically implemented as a map of counter instances
// keyed by label combinations
```

### Prometheus Output with Labels

```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/api/users",status="200"} 1234
http_requests_total{method="POST",path="/api/users",status="201"} 56
http_requests_total{method="GET",path="/api/users",status="404"} 12
```

## App Integration

### Enabling Metrics

```zig
var app = try api.App.init(allocator, .{});

// Enable metrics with default config
try app.enableMetrics(.{});

// Enable with custom config
try app.enableMetrics(.{
    .prefix = "myapp",
});

// Access registry
if (app.metrics_registry) |reg| {
    reg.http_requests_total.inc();
}
```

### Enabling Health Checks

```zig
try app.enableHealthChecks();

// Register custom checks
if (app.health_checker) |health| {
    try health.registerCheck(.{
        .name = "custom_check",
        .check_fn = myCustomCheck,
    });
}
```

## Example: Complete Monitoring Setup

```zig
const std = @import("std");
const api = @import("api");
const metrics = api.metrics;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    // Enable metrics
    try app.enableMetrics(.{ .prefix = "myservice" });

    // Enable health checks
    try app.enableHealthChecks();

    // Register custom health checks
    if (app.health_checker) |health| {
        try health.registerCheck(.{
            .name = "database",
            .check_fn = checkDatabase,
            .critical = true,
        });
    }

    // Register custom metrics
    if (app.metrics_registry) |reg| {
        const cache_hits = try reg.registerCounter("cache_hits_total", "Total cache hits");
        const cache_misses = try reg.registerCounter("cache_misses_total", "Total cache misses");
        const cache_size = try reg.registerGauge("cache_size_bytes", "Current cache size in bytes");
    }

    // Add metrics middleware
    app.use(metricsMiddleware);

    // Routes
    app.router.get("/", indexHandler);
    app.router.get("/api/data", dataHandler);

    // Metrics and health endpoints are auto-registered:
    // GET /metrics -> Prometheus metrics
    // GET /health -> Health check endpoint

    std.log.info("Server running on http://localhost:8080", .{});
    try app.listen(.{ .port = 8080 });
}

fn metricsMiddleware(ctx: *api.Context, next: api.NextFn) !void {
    const registry = ctx.app.metrics_registry orelse return next(ctx);
    
    const start = std.time.nanoTimestamp();
    registry.http_requests_in_flight.inc();
    
    defer {
        registry.http_requests_in_flight.dec();
        const duration = @as(f64, @floatFromInt(std.time.nanoTimestamp() - start)) / 1_000_000_000.0;
        registry.http_request_duration_seconds.observe(duration);
        registry.http_requests_total.inc();
    }

    try next(ctx);
}

fn checkDatabase() metrics.HealthChecker.CheckResult {
    // Implement actual database check
    return .{ .status = .healthy };
}
```

## Prometheus Scrape Config

```yaml
# prometheus.yml
scrape_configs:
  - job_name: 'myservice'
    static_configs:
      - targets: ['localhost:8080']
    metrics_path: '/metrics'
    scrape_interval: 15s
```

## Grafana Dashboard Queries

```promql
# Request rate
rate(myservice_http_requests_total[5m])

# Error rate
rate(myservice_http_requests_total{status=~"5.."}[5m])

# 99th percentile latency
histogram_quantile(0.99, rate(myservice_http_request_duration_seconds_bucket[5m]))

# Active connections
myservice_http_requests_in_flight

# Average response size
rate(myservice_http_response_size_bytes_sum[5m]) / rate(myservice_http_response_size_bytes_count[5m])
```

## See Also

- [Middleware Module](middleware.md) - For custom middleware
- [Logger Module](logger.md) - For structured logging
- [Cache Module](cache.md) - For cache metrics
