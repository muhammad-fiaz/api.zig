# Multi-Threading

api.zig supports configurable thread pools for high-performance concurrent request handling. The server uses optimized connection queues and atomic operations to distribute requests across worker threads efficiently.

## Single-Threaded Mode

By default, api.zig runs in single-threaded mode:

```zig
try app.run(.{ .port = 8000 });
```

Or explicitly:

```zig
try app.run(.{ .port = 8000, .num_threads = 0 });
```

## Multi-Threaded Mode

Enable multi-threading by setting `num_threads`:

```zig
// Fixed number of threads
try app.run(.{ .port = 8000, .num_threads = 4 });
```

## Auto-Detect CPU Count

Set `num_threads` to `null` for automatic detection based on available CPU cores:

```zig
// Uses (CPU cores * 2) - 1 threads for optimal performance
try app.run(.{ .port = 8000, .num_threads = null });
```

The auto-detection calculates an optimal thread count based on:
- Available CPU cores
- Multiplied by 2 for I/O-bound workloads
- Minus 1 to leave headroom for the main thread

## Threading Configuration

| Option        | Type         | Default       | Description                            |
| ------------- | ------------ | ------------- | -------------------------------------- |
| `num_threads` | `?u8`        | `null`        | Thread count (null=auto, 0=single)     |
| `port`        | `u16`        | `8000`        | Listen port                            |
| `host`        | `[]const u8` | `"127.0.0.1"` | Bind address                           |

## When to Use Multi-Threading

### Good for:

- High-traffic APIs with many concurrent connections
- CPU-bound request processing (JSON parsing, validation)
- Improved throughput on multi-core systems
- APIs serving many simultaneous clients

### Considerations:

- Memory usage increases with each thread
- Shared state must be thread-safe
- Use atomic operations for counters and flags
- Context and allocator are thread-local per request

## Thread-Safe Internals

api.zig's server uses atomic operations for:

```zig
// Internal thread-safe state
running: std.atomic.Value(bool),          // Server running state
request_count: std.atomic.Value(u64),     // Total requests processed
active_connections: std.atomic.Value(u32), // Current connections
```

## Connection Tracking

Monitor active connections in multi-threaded mode:

```zig
// Server tracks connections atomically
// Each accepted connection increments the counter
// Each completed request decrements it
```

## Advanced Server Configuration

For production deployments, combine threading with other server options:

```zig
try app.run(.{
    .host = "0.0.0.0",           // Bind to all interfaces
    .port = 8080,                // Listen port
    .num_threads = 8,            // 8 worker threads
    .access_log = true,          // Enable access logging
    .auto_port = false,          // Don't auto-find port
});
```

## Production Defaults

Use `api.Defaults.server` for production-ready settings:

```zig
// api.Defaults.server includes:
// .address = "127.0.0.1"
// .port = 8000
// .max_body_size = 10MB
// .max_connections = 10000
// .tcp_nodelay = true
// .reuse_port = true
// .read_buffer_size = 16384
// .keepalive_timeout_ms = 5000
```

## Example: High-Performance Server

```zig
const std = @import("std");
const api = @import("api");

fn handler() api.Response {
    return api.Response.jsonRaw("{\"status\":\"ok\"}");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "High-Performance API",
        .version = "1.0.0",
    });
    defer app.deinit();

    try app.get("/", handler);
    try app.get("/health", handler);

    // Run with auto-detected thread count
    try app.run(.{
        .host = "0.0.0.0",
        .port = 8080,
        .num_threads = null,  // Auto-detect
        .access_log = true,
    });
}
```

**Output:**
```
[OK] http://0.0.0.0:8080
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
[INFO] Running with 7 worker threads
[INFO] GET /health
[INFO] GET /
```

## Benchmarking

Test your multi-threaded server with tools like `wrk` or `hey`:

```bash
# Using wrk (Linux/macOS)
wrk -t4 -c100 -d30s http://localhost:8080/

# Using hey (cross-platform)
hey -n 10000 -c 100 http://localhost:8080/

# Example output:
# Requests/sec: 50000+
# Latency: avg 2ms, p99 10ms
```
