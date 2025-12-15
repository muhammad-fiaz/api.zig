---
layout: home

hero:
  name: "api.zig"
  text: "High-Performance API Framework"
  tagline: Build blazing-fast APIs with compile-time safety, multi-threaded concurrency, GraphQL, WebSocket, and production-ready features
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
    details: Optimized thread pools with CPU-based auto-scaling and connection tracking
  - title: GraphQL Support
    details: Complete GraphQL implementation with schema definition, query parsing, and GraphiQL UI
  - title: WebSocket
    details: RFC 6455 compliant WebSocket with rooms, broadcasting, and event handlers
  - title: Prometheus Metrics
    details: Built-in metrics collection with counters, gauges, histograms, and health checks
  - title: Caching
    details: LRU caching with TTL expiration, response caching, and ETag support
  - title: Session Management
    details: Secure sessions with CSRF protection and cookie security
  - title: Automatic OpenAPI
    details: Auto-generated OpenAPI 3.1 specification with Swagger UI and ReDoc documentation
  - title: Type Safety
    details: Full compile-time type checking for routes, handlers, and extractors
  - title: Production Ready
    details: Centralized configs, security headers, rate limiting, and CORS out of the box
  - title: Cross-Platform
    details: Works on Linux, Windows, and macOS with native socket support
  - title: Comprehensive Middleware
    details: Auth, logging, compression, rate limiting, security headers, and more
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

## Advanced Features

### GraphQL

```zig
var app = try api.App.init(allocator, .{});

// Define schema
var schema = api.graphql.Schema.init(allocator);
try schema.setQueryType(.{
    .name = "Query",
    .fields = &.{
        .{ .name = "users", .type_name = "User", .is_list = true },
    },
});

// Enable GraphQL
try app.enableGraphQL(&schema);

// Endpoints: POST /graphql, GET /graphql (GraphiQL)
```

### WebSocket

```zig
try app.enableWebSocket(.{
    .max_connections = 10000,
    .ping_interval_ms = 30000,
});

app.router.get("/ws", fn(ctx: *api.Context) !void {
    try ctx.response.upgradeWebSocket(.{
        .on_message = onMessage,
        .on_close = onClose,
    });
});
```

### Metrics & Health Checks

```zig
try app.enableMetrics(.{ .prefix = "myapp" });
try app.enableHealthChecks();

// GET /metrics -> Prometheus format
// GET /health -> Health check endpoint
```

### Caching

```zig
try app.enableCaching(.{
    .max_entries = 5000,
    .default_ttl_seconds = 300,
});
```

### Sessions

```zig
try app.enableSessions(.{
    .secret = "your-secret-key-at-least-32-chars",
    .max_age_seconds = 86400,
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

| Field         | Type         | Default       | Description                          |
|---------------|--------------|---------------|--------------------------------------|
| `host`        | `[]const u8` | `"127.0.0.1"` | Bind address                         |
| `port`        | `u16`        | `8000`        | Listen port                          |
| `access_log`  | `bool`       | `true`        | Enable/disable access logging        |
| `num_threads` | `?u8`        | `null`        | Worker threads (null=auto, 0=single) |
| `auto_port`   | `bool`       | `true`        | Auto-find port if busy               |

### Production Defaults

api.zig provides `api.Defaults` for production-ready configurations:

```zig
// Use production defaults
const server_config = api.Defaults.server;
const cors_config = api.Defaults.cors;
const rate_limit_config = api.Defaults.rateLimit;
const security_config = api.Defaults.security;
```

### Centralized Configuration

Use `api.FrameworkConfig` for unified configuration:

```zig
const config = api.FrameworkConfig{
    .app = .{ .title = "My API" },
    .server = .{ .port = 8080, .num_threads = 4 },
    .cors = .{ .allowed_origins = &.{"https://example.com"} },
    .rate_limit = .{ .requests_per_window = 100 },
    .security = .{ .x_frame_options = .deny },
    .graphql = .{ .enable_introspection = true },
    .metrics = .{ .prefix = "myapp" },
    .session = .{ .secret = "your-secret-key" },
};
```

### Middleware Stack

```zig
// Recommended middleware order
try app.use(api.recover);          // Catch panics
try app.use(api.requestId);        // Request tracing
try app.use(api.logger);           // Access logging
try app.use(api.defaultSecurityHeaders); // Security headers
try app.use(api.cors(.{}).handle); // CORS
try app.use(api.rateLimit(.{}).handle); // Rate limiting
```

</div>
