# Getting Started

Welcome to **api.zig**, a high-performance, multi-threaded HTTP API framework for Zig.

## Prerequisites

- [Zig](https://ziglang.org/) 0.15.0 or later

## Installation

Add api.zig to your project:

```bash
zig fetch --save https://github.com/muhammad-fiaz/api.zig/archive/refs/heads/main.tar.gz
```

Then in your `build.zig`:

```zig
const api = b.dependency("api", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("api", api.module("api"));
```

## Your First API

Create a simple API server:

```zig
const std = @import("std");
const api = @import("api");

fn hello() api.Response {
    return api.Response.jsonRaw("{\"message\":\"Hello, World!\"}");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "My First API",
        .version = "1.0.0",
    });
    defer app.deinit();

    try app.get("/", hello);
    try app.run(.{ .port = 8000 });
}
```

## Run Your Server

```bash
zig build run
```

**Output:**

```
[OK] http://127.0.0.1:8000
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
```

Visit:

- http://localhost:8000/ - Your API
- http://localhost:8000/docs - Swagger UI (Interactive API Documentation)
- http://localhost:8000/redoc - ReDoc (API Reference)

## App Init Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `title` | `[]const u8` | `"API"` | OpenAPI document title |
| `version` | `[]const u8` | `"0.0.0"` | API version string |
| `description` | `[]const u8` | `""` | API description |

## Server Run Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `port` | `u16` | `8000` | Port to listen on |
| `address` | `[]const u8` | `"127.0.0.1"` | Bind address |
| `num_threads` | `?u32` | CPU count | Worker thread count |
| `enable_access_log` | `bool` | `true` | Enable request logging |
| `auto_port` | `bool` | `true` | Auto-find available port |
| `max_port_attempts` | `u16` | `100` | Max ports to try |

## Features

### Auto Port Selection

If port 8000 is busy, the server automatically finds an available port:

```zig
try app.run(.{ 
    .port = 8000,
    .auto_port = true,      // Default: true
    .max_port_attempts = 50, // Try up to 50 ports
});
```

### Multi-Threading

Automatically scales to CPU cores:

```zig
try app.run(.{ 
    .num_threads = null,  // Auto-detect CPU cores (default)
});

// Or specify explicitly
try app.run(.{ 
    .num_threads = 8,     // Use 8 worker threads
});
```

### Cross-Platform Support

api.zig works on:
- **Windows** - Full support with Winsock2
- **Linux** - Native POSIX sockets with epoll
- **macOS** - Native POSIX sockets with kqueue

## Next Steps

- [Quick Start](/guide/quick-start) - More examples
- [Routing](/guide/routing) - Learn about route registration
- [API Reference](/api/) - Full API documentation
