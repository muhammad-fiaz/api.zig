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

Visit:

- http://localhost:8000/ - Your API
- http://localhost:8000/docs - Interactive API Documentation
- http://localhost:8000/redoc - API Reference

## Features

### Auto Port Selection

If port 8000 is busy, the server automatically finds an available port:

```zig
try app.run(.{ 
    .port = 8000,
    .auto_port = true,  // Default: true
});
```

### Cross-Platform Support

api.zig works on:
- **Windows** - Full support with Winsock2
- **Linux** - Native POSIX sockets
- **macOS** - Native POSIX sockets

## Next Steps

- [Quick Start](/guide/quick-start) - More examples
- [Routing](/guide/routing) - Learn about route registration
- [API Reference](/api/) - Full API documentation
