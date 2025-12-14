---
layout: home

hero:
  name: "api.zig"
  text: "High-Performance API Framework"
  tagline: Build blazing-fast APIs with compile-time safety and multi-threaded concurrency
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/api.zig
    - theme: alt
      text: Examples
      link: /examples/

features:
  - title: High Performance
    details: Zero runtime reflection with compile-time route validation for maximum speed
  - title: Multi-Threaded
    details: Configurable thread pools with lock-free connection queue for concurrent request handling
  - title: Automatic OpenAPI
    details: Auto-generated OpenAPI 3.1 specification with Swagger UI and ReDoc documentation
  - title: Type Safety
    details: Full compile-time type checking for routes, handlers, and extractors
  - title: Zero Dependencies
    details: Pure Zig implementation with no external dependencies required
  - title: Cross-Platform
    details: Works on Linux, Windows, and macOS with native socket support
  - title: HTTP Client
    details: Built-in HTTP client for outbound requests with JSON parsing
  - title: Static Files
    details: Static file serving with MIME type detection and template rendering
  - title: Configurable Logging
    details: Thread-safe colorful logging with enable/disable access log option
---

<div class="vp-doc" style="padding: 0 24px;">

## Quick Start

Install api.zig:

```bash
zig fetch --save https://github.com/muhammad-fiaz/api.zig/archive/refs/heads/main.tar.gz
```

Add to `build.zig`:

```zig
const api_dep = b.dependency("api", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("api", api_dep.module("api"));
```

Create your first API:

```zig
const std = @import("std");
const api = @import("api");

fn hello() api.Response {
    return api.Response.jsonRaw("{\"message\":\"Hello, World!\"}");
}

fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    _ = id;
    return api.Response.jsonRaw("{\"id\":1,\"name\":\"John\"}");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "My API",
        .version = "1.0.0",
    });
    defer app.deinit();

    try app.get("/", hello);
    try app.get("/users/{id}", getUser);

    try app.run(.{ .port = 8000, .num_threads = 4 });
}
```

Run your server:

```bash
zig build run
```

Visit:

- **API:** http://localhost:8000/
- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc
- **OpenAPI JSON:** http://localhost:8000/openapi.json

## Features

### Multi-Threading

```zig
// Single-threaded (num_threads = 0)
try app.run(.{ .port = 8000 });

// Multi-threaded with 4 workers
try app.run(.{ .port = 8000, .num_threads = 4 });

// Auto-detect based on CPU count
try app.run(.{ .port = 8000, .num_threads = null });
```

### Access Log Control

```zig
// Enable access logging (default)
try app.run(.{ .port = 8000, .access_log = true });

// Disable access logging
try app.run(.{ .port = 8000, .access_log = false });
```

### Response Types

```zig
api.Response.jsonRaw("{\"key\":\"value\"}")  // JSON
api.Response.text("Hello")                   // Plain text
api.Response.html("<h1>Hello</h1>")          // HTML
api.Response.redirect("/new-path")           // Redirect (302)
api.Response.permanentRedirect("/new")       // Redirect (301)
api.Response.err(.not_found, "{}")           // Error response
```

### Path Parameters

```zig
try app.get("/users/{id}", getUser);
try app.get("/posts/{post_id}/comments/{comment_id}", getComment);
```

### Query Parameters

```zig
fn listUsers(ctx: *api.Context) api.Response {
    const page = ctx.queryAsOr(u32, "page", 1);
    const limit = ctx.queryAsOr(u32, "limit", 10);
    // ...
}
```

### Fluent Response Builder

```zig
api.Response.text("Created")
    .setStatus(.created)
    .setHeader("Location", "/users/1")
    .setHeader("X-Request-Id", "abc123")
    .withCors("*");
```

### HTTP Client

```zig
var client = api.Client.init(allocator);
defer client.deinit();

const response = try client.get("https://api.example.com/data");
defer response.deinit();

const data = try response.json(MyType);
```

### Static Files

```zig
const static_handler = api.StaticFiles.serve(.{
    .root_path = "public",
    .url_prefix = "/static",
});
try app.mount("/static", static_handler);
```

### HTML Templates

```zig
const templates = api.Templates.init(allocator, "templates");
return templates.render("index.html", .{
    .title = "Home",
    .user = username,
});
```

## Configuration

### AppConfig

| Field         | Type          | Default               | Description            |
|---------------|---------------|-----------------------|------------------------|
| `title`       | `[]const u8`  | `"Zig API Framework"` | API title for OpenAPI  |
| `version`     | `[]const u8`  | `"1.0.0"`             | API version            |
| `description` | `?[]const u8` | `null`                | API description        |
| `debug`       | `bool`        | `false`               | Enable debug mode      |
| `docs_url`    | `[]const u8`  | `"/docs"`             | Swagger UI path        |
| `redoc_url`   | `[]const u8`  | `"/redoc"`            | ReDoc path             |
| `openapi_url` | `[]const u8`  | `"/openapi.json"`     | OpenAPI spec path      |

### RunConfig

| Field         | Type         | Default       | Description                        |
|---------------|--------------|---------------|------------------------------------|
| `host`        | `[]const u8` | `"127.0.0.1"` | Bind address                       |
| `port`        | `u16`        | `8000`        | Listen port                        |
| `access_log`  | `bool`       | `true`        | Enable/disable access logging      |
| `num_threads` | `?u8`        | `null`        | Worker threads (null=auto, 0=single) |
| `auto_port`   | `bool`       | `true`        | Auto-find port if busy             |

</div>
