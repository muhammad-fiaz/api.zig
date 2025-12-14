# Multi-Threading

api.zig supports configurable thread pools for high-performance concurrent request handling. The server uses a lock-free connection queue to distribute requests across worker threads.

## Single-Threaded Mode

By default, api.zig runs in single-threaded mode:

```zig
try app.run(.{ .port = 8000 });
```

## Multi-Threaded Mode

Enable multi-threading by setting `num_threads`:

```zig
// Fixed number of threads
try app.run(.{ .port = 8000, .num_threads = 4 });
```

## Auto-Detect CPU Count

Set `num_threads` to `null` for automatic detection:

```zig
// Uses available CPU cores
try app.run(.{ .port = 8000, .num_threads = null });
```

## When to Use Multi-Threading

### Good for:

- High-traffic APIs
- CPU-bound request processing
- Improved throughput

### Considerations:

- Shared state must be thread-safe
- Use atomic operations for counters
- Memory usage increases with threads

## Thread-Safe Design

api.zig's server uses atomic operations for:

- Request counting
- Connection tracking
- Running state management

```zig
// Internal server state is thread-safe
running: std.atomic.Value(bool),
request_count: std.atomic.Value(u64),
active_connections: std.atomic.Value(u32),
```

## Configuration

| Option        | Type         | Default       | Description                            |
| ------------- | ------------ | ------------- | -------------------------------------- |
| `num_threads` | `?u8`        | `null`        | Thread count (null = auto, 0 = single) |
| `port`        | `u16`        | `8000`        | Listen port                            |
| `host`        | `[]const u8` | `"127.0.0.1"` | Bind address                           |

## Example

```zig
const std = @import("std");
const api = @import("api");

fn handler() api.Response {
    return api.Response.text("Hello from thread!");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = api.App.init(allocator, .{});
    defer app.deinit();

    try app.get("/", handler);

    // Run with 8 worker threads
    try app.run(.{
        .port = 8000,
        .num_threads = 8,
    });
}
```
