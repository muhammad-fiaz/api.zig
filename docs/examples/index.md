# Examples

This section contains complete, runnable examples demonstrating api.zig features.

## Available Examples

### REST API

| Example | Description | Key Features |
|---------|-------------|--------------|
| [REST API](/examples/rest-api) | Complete CRUD API | Multi-threading, Path params, Status codes |
| [HTML Pages](/examples/html-pages) | Server-rendered pages | HTML templates, CSS styling, Mixed content |
| [Path Parameters](/examples/path-parameters) | Dynamic URL segments | Single/multiple params, Type conversion |

### GraphQL

| Example | Description | Key Features |
|---------|-------------|--------------|
| [Basic GraphQL](/examples/graphql-basic) | Complete GraphQL API | Schema, Queries, Mutations, 5 UI providers |
| [GraphQL Subscriptions](/examples/graphql-subscriptions) | Real-time updates | WebSocket, Live data, Chat example |

### Real-time

| Example | Description | Key Features |
|---------|-------------|--------------|
| [WebSocket Chat](/examples/websocket-chat) | Real-time chat | WebSocket, Rooms, Broadcasting |
| [Live Dashboard](/examples/live-dashboard) | Metrics dashboard | Server-Sent Events, Auto-refresh |

## Running Examples

Build and run the main example:

```bash
zig build run
```

**Output:**

```
[OK] http://127.0.0.1:8000
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
```

## Source Files

The main example is in `examples/main.zig` which demonstrates:

- HTML pages with modern CSS templates
- JSON API endpoints with proper status codes
- Path parameters (`{id}`) and query parameters
- Multi-threading with configurable thread count
- Access logging with request details

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
[OK] http://127.0.0.1:8000
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
```

## Handler Types

api.zig supports multiple handler signatures:

```zig
// Simple handler (no context needed)
fn simple() api.Response {
    return api.Response.text("Hello");
}

// Context handler (access params, headers, body)
fn withContext(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    _ = id;
    return api.Response.jsonRaw(\\{"id":1});
}
```

## HTTP Methods

Register handlers for all standard HTTP methods:

```zig
try app.get("/resource", getHandler);
try app.post("/resource", postHandler);
try app.put("/resource/{id}", putHandler);
try app.patch("/resource/{id}", patchHandler);
try app.delete("/resource/{id}", deleteHandler);
try app.options("/resource", optionsHandler);
try app.head("/resource", headHandler);
try app.trace("/resource", traceHandler);
```

## Configuration Tables

### App Init Options

| Option | Type | Description |
|--------|------|-------------|
| `title` | `[]const u8` | OpenAPI title |
| `version` | `[]const u8` | API version |
| `description` | `[]const u8` | API description |

### Server Run Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `port` | `u16` | `8000` | Listen port |
| `address` | `[]const u8` | `"127.0.0.1"` | Bind address |
| `num_threads` | `?u32` | CPU count | Worker threads |
| `enable_access_log` | `bool` | `true` | Request logging |
| `max_body_size` | `usize` | `10MB` | Max body size |
