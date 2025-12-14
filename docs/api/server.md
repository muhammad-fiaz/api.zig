# Server

Cross-platform HTTP server with Windows, Linux, and macOS support.

## Import

```zig
const api = @import("api");
const Server = api.Server;
const ServerConfig = api.ServerConfig;
```

## ServerConfig

| Field              | Type         | Default       | Description                      |
| ------------------ | ------------ | ------------- | -------------------------------- |
| `address`          | `[]const u8` | `"127.0.0.1"` | Bind address                     |
| `port`             | `u16`        | `8000`        | Listen port                      |
| `max_body_size`    | `usize`      | `10MB`        | Max request body size            |
| `num_threads`      | `?u8`        | `null`        | Worker threads (null=auto)       |
| `enable_access_log`| `bool`       | `true`        | Colorful access logging          |
| `auto_port`        | `bool`       | `true`        | Auto-find port if busy           |
| `max_port_attempts`| `u16`        | `100`         | Max ports to try when auto_port  |

## Cross-Platform Support

The server automatically uses the correct socket APIs for each platform:

| Platform | Socket API  | Color Support               |
| -------- | ----------- | --------------------------- |
| Windows  | Winsock2    | Virtual Terminal Processing |
| Linux    | POSIX       | Native ANSI                 |
| macOS    | POSIX       | Native ANSI                 |

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
pub fn init(allocator: Allocator, router: *Router, config: ServerConfig) Server
```

Creates a new server.

### deinit

```zig
pub fn deinit(self: *Server) void
```

Releases server resources.

### start

```zig
pub fn start(self: *Server) !void
```

Starts the HTTP server (blocking).

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

## Built-in Endpoints

When running, the server provides:

| Endpoint        | Description              |
| --------------- | ------------------------ |
| `/docs`         | Interactive API Docs     |
| `/redoc`        | API Reference            |
| `/openapi.json` | OpenAPI specification    |

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

## Output

```
[OK] http://127.0.0.1:8080
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
[INFO] GET /
[INFO] GET /docs
[INFO] POST /users
```

