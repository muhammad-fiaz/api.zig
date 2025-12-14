# Examples

This section contains examples demonstrating api.zig features.

## Available Examples

| Example                                      | Description                            |
| -------------------------------------------- | -------------------------------------- |
| [REST API](/examples/rest-api)               | Complete CRUD API with multi-threading |
| [HTML Pages](/examples/html-pages)           | Serving HTML with CSS styling          |
| [Path Parameters](/examples/path-parameters) | Dynamic URL segments                   |

## Running the Example

Build and run:

```bash
zig build run
```

## Source Files

The main example is in `examples/main.zig` which demonstrates all features:

- HTML pages with templates
- JSON API endpoints
- Path and query parameters
- Multi-threading configuration
- Access log control

## Quick Start

The simplest api.zig application:

```zig
const std = @import("std");
const api = @import("api");

fn hello() api.Response {
    return api.Response.text("Hello, World!");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    try app.get("/", hello);
    try app.run(.{ .port = 8000 });
}
```

**Output:**

```
Server running on http://127.0.0.1:8000
Swagger UI: http://127.0.0.1:8000/docs
ReDoc: http://127.0.0.1:8000/redoc
```
