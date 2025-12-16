# Server

High-performance multi-threaded HTTP server with cross-platform support.

## Import

```zig
const api = @import("api");
const Server = api.Server;
const ServerConfig = api.ServerConfig;
```

## ServerConfig

| Field                  | Type         | Default       | Description                           |
| ---------------------- | ------------ | ------------- | ------------------------------------- |
| `address`              | `[]const u8` | `"127.0.0.1"` | Server bind address                   |
| `port`                 | `u16`        | `8000`        | Server listen port                    |
| `max_body_size`        | `usize`      | `10MB`        | Maximum request body size             |
| `num_threads`          | `?u8`        | `null`        | Worker thread count (null=auto-detect)|
| `enable_access_log`    | `bool`       | `true`        | Enable HTTP access logging            |
| `auto_port`            | `bool`       | `true`        | Auto-select available port            |
| `max_port_attempts`    | `u16`        | `100`         | Maximum port search attempts          |
| `read_buffer_size`     | `usize`      | `16384`       | Socket read buffer size               |
| `keepalive_timeout_ms` | `u32`        | `5000`        | TCP keep-alive timeout                |
| `max_connections`      | `u32`        | `10000`       | Maximum concurrent connections        |
| `tcp_nodelay`          | `bool`       | `true`        | Disable Nagle's algorithm (TCP_NODELAY)|
| `reuse_port`           | `bool`       | `true`        | Enable SO_REUSEPORT socket option     |
| `disable_reserved_routes`| `bool`     | `false`       | Disable built-in documentation routes |

## Platform Support

Automatic platform-specific optimizations:

| Platform | Socket API  | Terminal Colors             |
| -------- | ----------- | --------------------------- |
| Windows  | Winsock2    | Virtual Terminal Sequences  |
| Linux    | POSIX       | ANSI Escape Codes           |
| macOS    | POSIX       | ANSI Escape Codes           |

## Auto Port Selection

If the specified port is in use, the server automatically finds an available port:

```zig
try app.run(.{
    .port = 8000,
    .auto_port = true,  // Default
});
// If 8000 is busy, tries 8001, 8002, ... up to max_port_attempts
```

## Server Methods

### init

```zig
pub fn init(allocator: Allocator, router: *Router, config: ServerConfig) !Server
```

Initializes server instance with specified configuration.

### deinit

```zig
pub fn deinit(self: *Server) void
```

Releases all server resources and closes connections.

### start

```zig
pub fn start(self: *Server) !void
```

Starts HTTP server and blocks until shutdown.

## Threading Modes

### Single-Threaded

```zig
try app.run(.{ .port = 8000 });
// or
try app.run(.{ .port = 8000, .num_threads = 0 });
```

### Multi-Threaded

```zig
// Fixed thread count
try app.run(.{ .port = 8000, .num_threads = 4 });

// Auto-detect CPU count
try app.run(.{ .port = 8000, .num_threads = null });
```

## Built-in Documentation Endpoints

Automatic API documentation (can be disabled with `disable_reserved_routes`):

| Endpoint              | Description                    |
| --------------------- | ------------------------------ |
| `/docs`               | Swagger UI (interactive)       |
| `/redoc`              | ReDoc (reference)              |
| `/openapi.json`       | OpenAPI 3.1 specification      |
| `/graphql/playground` | GraphQL Playground (GraphiQL)  |
| `/health`             | Health check endpoint          |

## Example

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "My API",
    });
    defer app.deinit();

    try app.get("/", handler);

    // Start with 4 worker threads
    try app.run(.{
        .host = "0.0.0.0",
        .port = 8080,
        .num_threads = 4,
        .access_log = true,
        .auto_port = true,
    });
}

fn handler() api.Response {
    return api.Response.text("Hello!");
}
```

## Console Output

```
✓ http://127.0.0.1:8080
ℹ  /docs       - Swagger UI 5.31.0 (REST API)
ℹ  /redoc      - ReDoc 2.5.2 (REST API)
ℹ  /graphql/playground - GraphQL Playground
ℹ Running with 4 worker threads (optimized)
ℹ GET /
ℹ POST /users
```

