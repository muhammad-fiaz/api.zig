# API Reference

Complete API documentation for all api.zig modules. This framework provides production-ready HTTP server capabilities with compile-time routing, automatic OpenAPI generation, and comprehensive middleware support.

## Core Modules

| Module                       | Description                                 |
| ---------------------------- | ------------------------------------------- |
| [App](./app.md)              | Main application entry point and lifecycle  |
| [Response](./response.md)    | HTTP response builder with fluent API       |
| [Context](./context.md)      | Request context with parameters and state   |
| [Router](./router.md)        | Compile-time route registration and matching|
| [Server](./server.md)        | Multi-threaded HTTP server                  |

## HTTP Utilities

| Module                       | Description                                 |
| ---------------------------- | ------------------------------------------- |
| [HTTP](./http.md)            | HTTP methods, status codes, content types   |
| [JSON](./json.md)            | JSON parsing and serialization              |
| [Client](./client.md)        | HTTP client for outbound requests           |

## Advanced Features

| Module                           | Description                             |
| -------------------------------- | --------------------------------------- |
| [GraphQL](./graphql.md)          | Complete GraphQL support with schema, parsing, execution |
| [WebSocket](./websocket.md)      | RFC 6455 WebSocket with rooms and broadcasting |
| [Metrics](./metrics.md)          | Prometheus metrics and health checks    |
| [Cache](./cache.md)              | LRU caching, TTL, ETag, response caching |
| [Session](./session.md)          | Session management and CSRF protection  |

## Middleware & Utilities

| Module                           | Description                             |
| -------------------------------- | --------------------------------------- |
| [Middleware](./middleware.md)    | Middleware components (CORS, Auth, etc) |
| [Static](./static.md)            | Static file serving                     |
| [Extractors](./extractors.md)    | Request data extraction                 |
| [Validation](./validation.md)    | Input validation utilities              |
| [OpenAPI](./openapi.md)          | OpenAPI 3.1 specification generator     |
| [Logger](./logger.md)            | Cross-platform colored logging          |
| [Report](./report.md)            | Error reporting and version checking    |
| [Version](./version.md)          | Library version information             |

## Centralized Configuration

api.zig provides centralized configuration structs for production deployments.

### FrameworkConfig

Combines all module configurations into a single struct:

```zig
const api = @import("api");

const config = api.FrameworkConfig{
    .app = .{ .title = "My API", .version = "1.0.0" },
    .server = .{ .port = 8080, .num_threads = 4 },
    .cors = .{ .allowed_origins = &.{"https://example.com"} },
    .rate_limit = .{ .requests_per_window = 100 },
    .security = .{ .x_frame_options = .deny },
    .compression = .{ .min_size = 1024 },
    .logging = .{ .format = .json },
    
    // New advanced features
    .graphql = .{ .enable_introspection = true },
    .websocket = .{ .max_connections = 10000 },
    .metrics = .{ .prefix = "myapp" },
    .cache = .{ .max_entries = 5000 },
    .session = .{ .secret = "your-secret-key", .max_age_seconds = 86400 },
};
```

| Field         | Type                    | Description                    |
| ------------- | ----------------------- | ------------------------------ |
| `app`         | `AppConfig`             | Application settings           |
| `server`      | `ServerConfig`          | Server and threading settings  |
| `cors`        | `CorsConfig`            | CORS configuration             |
| `rate_limit`  | `RateLimitConfig`       | Rate limiting settings         |
| `security`    | `SecurityHeadersConfig` | Security headers               |
| `compression` | `CompressionConfig`     | Response compression           |
| `logging`     | `LogConfig`             | Logging configuration          |
| `graphql`     | `GraphQLConfig`         | GraphQL settings               |
| `websocket`   | `WebSocketConfig`       | WebSocket settings             |
| `metrics`     | `MetricsConfig`         | Metrics/health settings        |
| `cache`       | `CacheConfig`           | Caching settings               |
| `session`     | `SessionConfig`         | Session management settings    |

### Production Defaults

Use `api.Defaults` for production-ready configurations:

```zig
// Production-ready server config
const server_config = api.Defaults.server;
// .address = "127.0.0.1", .port = 8000, .max_body_size = 10MB
// .max_connections = 10000, .tcp_nodelay = true, .reuse_port = true

// Production-ready CORS config
const cors_config = api.Defaults.cors;
// All common methods and headers allowed

// Production-ready rate limiting
const rate_config = api.Defaults.rateLimit;
// 100 requests per 60 seconds

// Production-ready security headers
const security_config = api.Defaults.security;
// CSP, X-Frame-Options, XSS Protection enabled
```

### SchemaBuilder

Build OpenAPI schemas programmatically:

```zig
const api = @import("api");
const Schema = api.SchemaBuilder;

// Primitive types
const string_schema = Schema.string();
const int_schema = Schema.integer();
const bool_schema = Schema.boolean();
const num_schema = Schema.number();

// With formats
const email = Schema.email();        // string + format: email
const uuid = Schema.uuid();          // string + format: uuid
const date = Schema.date();          // string + format: date
const datetime = Schema.dateTime();  // string + format: date-time
const uri = Schema.uri();            // string + format: uri
const password = Schema.password();  // string + format: password

// Numeric formats
const int32 = Schema.int32();        // integer + format: int32
const int64 = Schema.int64();        // integer + format: int64
const float = Schema.float();        // number + format: float
const double = Schema.double();      // number + format: double

// Complex types
const arr = Schema.array(Schema.string());
const obj = Schema.object();
const nullable_str = Schema.nullable(Schema.string());
```

## Quick Reference

### Common Types

```zig
const api = @import("api");

// Application
const App = api.App;
const AppConfig = api.AppConfig;
const RunConfig = api.RunConfig;

// Request/Response
const Response = api.Response;
const Context = api.Context;
const StatusCode = api.StatusCode;
const Method = api.Method;

// Configuration
const FrameworkConfig = api.FrameworkConfig;
const Defaults = api.Defaults;
const ServerConfig = api.ServerConfig;

// Middleware Configs
const CorsConfig = api.CorsConfig;
const AuthConfig = api.AuthConfig;
const RateLimitConfig = api.RateLimitConfig;
const SecurityHeadersConfig = api.SecurityHeadersConfig;
const CompressionConfig = api.CompressionConfig;
const LogConfig = api.LogConfig;
const RequestIdConfig = api.RequestIdConfig;
const TrustedHostConfig = api.TrustedHostConfig;
const TimeoutConfig = api.TimeoutConfig;

// Utilities
const json = api.json;
const validation = api.validation;
const SchemaBuilder = api.SchemaBuilder;
```

### Response Types

```zig
api.Response.jsonRaw("{}")             // JSON response
api.Response.text("Hello")             // Plain text
api.Response.html("<h1>Hi</h1>")       // HTML page
api.Response.err(.not_found, "{}")     // Error response
api.Response.redirect("/path")         // Temporary redirect (302)
api.Response.permanentRedirect("/path") // Permanent redirect (301)
```

### HTTP Methods

```zig
try app.get("/path", handler);     // GET request
try app.post("/path", handler);    // POST request
try app.put("/path", handler);     // PUT request
try app.delete("/path", handler);  // DELETE request
try app.patch("/path", handler);   // PATCH request
try app.options("/path", handler); // OPTIONS request
try app.head("/path", handler);    // HEAD request
try app.trace("/path", handler);   // TRACE request
```

### Content Types

```zig
const ContentTypes = api.ContentTypes;

ContentTypes.JSON       // "application/json"
ContentTypes.HTML       // "text/html; charset=utf-8"
ContentTypes.TEXT       // "text/plain; charset=utf-8"
ContentTypes.XML        // "application/xml"
ContentTypes.FORM       // "application/x-www-form-urlencoded"
ContentTypes.CSS        // "text/css"
ContentTypes.JS         // "application/javascript"
ContentTypes.PNG        // "image/png"
ContentTypes.JPEG       // "image/jpeg"
```

### Status Code Helpers

```zig
const StatusGroups = api.StatusGroups;

StatusGroups.isSuccess(status)       // 2xx codes
StatusGroups.isRedirect(status)      // 3xx codes
StatusGroups.isClientError(status)   // 4xx codes
StatusGroups.isServerError(status)   // 5xx codes
StatusGroups.isInformational(status) // 1xx codes
```

## Quick Example

```zig
const std = @import("std");
const api = @import("api");

fn handler(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    _ = id;
    return api.Response.jsonRaw("{\"id\":1}");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "My API",
        .version = "1.0.0",
    });
    defer app.deinit();

    try app.get("/users/{id}", handler);
    try app.run(.{ .port = 8000 });
}
```

**Output:**
```
[OK] http://127.0.0.1:8000
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
```
