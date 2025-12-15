# Middleware

Production-grade HTTP middleware components for request/response processing pipelines.

## Import

```zig
const api = @import("api");
const middleware = api.middleware;
```

## Built-in Middleware

| Middleware        | Description                                |
| ----------------- | ------------------------------------------ |
| `logger`          | Request/response logging with timing       |
| `loggerWithConfig`| Configurable logging with skip paths       |
| `cors`            | Cross-Origin Resource Sharing (RFC 6454)   |
| `basicAuth`       | HTTP Basic Authentication                  |
| `auth`            | Full authentication (Basic, Bearer, API Key)|
| `requestId`       | Unique request ID generation               |
| `trustedHost`     | Host header validation                     |
| `securityHeaders` | Security headers (CSP, X-Frame-Options)    |
| `rateLimit`       | Request rate limiting                      |
| `gzip`            | Response compression                       |
| `etag`            | ETag caching support                       |
| `recover`         | Panic recovery                             |
| `timeout`         | Request timeout handling                   |

## LogConfig

Logging middleware configuration.

```zig
const LogMw = api.loggerWithConfig(.{
    .log_request_headers = true,
    .log_response_headers = false,
    .log_body = false,
    .max_body_log_size = 1024,
    .skip_paths = &.{ "/health", "/metrics", "/favicon.ico" },
    .format = .combined,
});
try app.use(LogMw.handle);
```

| Field                 | Type                     | Default                                  | Description                    |
| --------------------- | ------------------------ | ---------------------------------------- | ------------------------------ |
| `log_request_headers` | `bool`                   | `false`                                  | Log request headers            |
| `log_response_headers`| `bool`                   | `false`                                  | Log response headers           |
| `log_body`            | `bool`                   | `false`                                  | Log request body               |
| `max_body_log_size`   | `usize`                  | `1024`                                   | Max body bytes to log          |
| `skip_paths`          | `[]const []const u8`     | `&.{"/health", "/metrics", "/favicon.ico"}` | Paths to skip logging       |
| `format`              | `LogFormat`              | `.combined`                              | Log format (combined/simple/json) |

## CorsConfig

Cross-Origin Resource Sharing configuration.

```zig
const CorsMw = api.cors(.{
    .allowed_origins = &.{ "https://example.com", "https://app.example.com" },
    .allowed_methods = &.{ "GET", "POST", "PUT", "DELETE" },
    .allowed_headers = &.{ "Content-Type", "Authorization" },
    .allow_credentials = true,
    .max_age = 86400,
});
try app.use(CorsMw.handle);
```

| Field                  | Type                   | Default                                      | Description                   |
| ---------------------- | ---------------------- | -------------------------------------------- | ----------------------------- |
| `allowed_origins`      | `[]const []const u8`   | `&.{"*"}`                                    | Allowed origins               |
| `allowed_methods`      | `[]const []const u8`   | `&.{"GET", "POST", "PUT", "DELETE", ...}`    | Allowed HTTP methods          |
| `allowed_headers`      | `[]const []const u8`   | `&.{"Content-Type", "Authorization", ...}`   | Allowed request headers       |
| `expose_headers`       | `[]const []const u8`   | `&.{"Content-Length", "X-Request-ID"}`       | Headers exposed to client     |
| `allow_credentials`    | `bool`                 | `false`                                      | Allow credentials             |
| `max_age`              | `u32`                  | `86400`                                      | Preflight cache duration (s)  |
| `allow_private_network`| `bool`                 | `false`                                      | Allow private network access  |

## AuthConfig

Full-featured authentication configuration.

```zig
const AuthMw = api.auth(.{
    .scheme = .bearer,
    .realm = "API Access",
    .token_validator = validateToken,
    .exclude_paths = &.{ "/health", "/docs", "/redoc" },
    .optional = false,
});
try app.use(AuthMw.handle);
```

| Field             | Type                                  | Default           | Description                    |
| ----------------- | ------------------------------------- | ----------------- | ------------------------------ |
| `scheme`          | `AuthScheme`                          | `.basic`          | Auth scheme (basic/bearer/api_key) |
| `realm`           | `[]const u8`                          | `"Secure Area"`   | WWW-Authenticate realm         |
| `api_key_header`  | `[]const u8`                          | `"X-API-Key"`     | API key header name            |
| `api_key_query`   | `[]const u8`                          | `"api_key"`       | API key query parameter        |
| `validator`       | `?*const fn ([]const u8, []const u8) bool` | `null`       | Username/password validator    |
| `token_validator` | `?*const fn ([]const u8) bool`        | `null`            | Token validator function       |
| `exclude_paths`   | `[]const []const u8`                  | `&.{}`            | Paths to skip authentication   |
| `optional`        | `bool`                                | `false`           | Allow unauthenticated access   |

### AuthScheme

```zig
pub const AuthScheme = enum {
    basic,    // HTTP Basic Auth
    bearer,   // Bearer token (JWT, etc.)
    api_key,  // API key in header or query
    digest,   // HTTP Digest Auth
    custom,   // Custom scheme
};
```

## RateLimitConfig

Request rate limiting configuration.

```zig
const RateMw = api.rateLimit(.{
    .requests_per_window = 100,
    .window_seconds = 60,
    .key_extractor = .ip,
    .headers = true,
});
try app.use(RateMw.handle);
```

| Field                    | Type           | Default                                  | Description                    |
| ------------------------ | -------------- | ---------------------------------------- | ------------------------------ |
| `requests_per_window`    | `u32`          | `100`                                    | Max requests per time window   |
| `window_seconds`         | `u32`          | `60`                                     | Time window in seconds         |
| `key_extractor`          | `KeyExtractor` | `.ip`                                    | How to identify clients        |
| `skip_successful_requests` | `bool`       | `false`                                  | Only count failed requests     |
| `headers`                | `bool`         | `true`                                   | Add X-RateLimit-* headers      |
| `message`                | `[]const u8`   | `"{\"error\":\"Rate limit exceeded\"}"` | Error response message         |

### KeyExtractor

```zig
pub const KeyExtractor = enum {
    ip,      // Client IP address
    user,    // Authenticated username
    api_key, // API key
    custom,  // Custom extraction
};
```

## SecurityHeadersConfig

Security headers middleware configuration.

```zig
const SecMw = api.securityHeaders(.{
    .content_security_policy = "default-src 'self'",
    .x_content_type_options = true,
    .x_frame_options = .deny,
    .x_xss_protection = true,
    .strict_transport_security = .{
        .max_age = 31536000,
        .include_subdomains = true,
        .preload = true,
    },
    .referrer_policy = "strict-origin-when-cross-origin",
});
try app.use(SecMw.handle);
```

| Field                        | Type                      | Default                             | Description                    |
| ---------------------------- | ------------------------- | ----------------------------------- | ------------------------------ |
| `content_security_policy`    | `?[]const u8`             | `"default-src 'self'"`              | Content Security Policy        |
| `x_content_type_options`     | `bool`                    | `true`                              | Add X-Content-Type-Options     |
| `x_frame_options`            | `XFrameOptions`           | `.deny`                             | Frame embedding policy         |
| `x_xss_protection`           | `bool`                    | `true`                              | Enable XSS protection          |
| `strict_transport_security`  | `?StrictTransportSecurity`| `null`                              | HSTS configuration             |
| `referrer_policy`            | `?[]const u8`             | `"strict-origin-when-cross-origin"` | Referrer policy                |
| `permissions_policy`         | `?[]const u8`             | `null`                              | Permissions policy             |
| `cross_origin_embedder_policy` | `?[]const u8`           | `null`                              | COEP header                    |
| `cross_origin_opener_policy` | `?[]const u8`             | `null`                              | COOP header                    |
| `cross_origin_resource_policy` | `?[]const u8`           | `null`                              | CORP header                    |

### XFrameOptions

```zig
pub const XFrameOptions = enum { deny, sameorigin, allow_from };
```

### StrictTransportSecurity

```zig
pub const StrictTransportSecurity = struct {
    max_age: u32 = 31536000,         // 1 year
    include_subdomains: bool = true,
    preload: bool = false,
};
```

## TrustedHostConfig

Trusted host validation configuration.

```zig
const HostMw = api.trustedHostMiddleware(.{
    .allowed_hosts = &.{ "example.com", "api.example.com" },
    .allow_subdomains = true,
    .www_redirect = false,
    .enforce_https = false,
});
try app.use(HostMw.handle);
```

| Field              | Type                   | Default                             | Description                    |
| ------------------ | ---------------------- | ----------------------------------- | ------------------------------ |
| `allowed_hosts`    | `[]const []const u8`   | `&.{"localhost", "127.0.0.1", "::1"}` | Allowed host values          |
| `allow_subdomains` | `bool`                 | `false`                             | Allow subdomains of hosts      |
| `www_redirect`     | `bool`                 | `false`                             | Redirect www to non-www        |
| `enforce_https`    | `bool`                 | `false`                             | Require HTTPS                  |

## CompressionConfig

Response compression configuration.

```zig
const CompMw = api.compressionWithConfig(.{
    .min_size = 1024,
    .level = 6,
    .types = &.{ "text/", "application/json", "application/xml" },
    .exclude_paths = &.{},
});
try app.use(CompMw.handle);
```

| Field           | Type                   | Default                                          | Description                    |
| --------------- | ---------------------- | ------------------------------------------------ | ------------------------------ |
| `min_size`      | `usize`                | `1024`                                           | Min bytes to compress          |
| `level`         | `u4`                   | `6`                                              | Compression level (1-9)        |
| `types`         | `[]const []const u8`   | `&.{"text/", "application/json", ...}`           | Content types to compress      |
| `exclude_paths` | `[]const []const u8`   | `&.{}`                                           | Paths to skip compression      |

## RequestIdConfig

Request ID middleware configuration.

```zig
const IdMw = api.requestIdWithConfig(.{
    .header_name = "X-Request-ID",
    .prefix = "req-",
    .use_uuid = false,
    .trust_incoming = false,
});
try app.use(IdMw.handle);
```

| Field           | Type         | Default          | Description                    |
| --------------- | ------------ | ---------------- | ------------------------------ |
| `header_name`   | `[]const u8` | `"X-Request-ID"` | Header name for request ID     |
| `prefix`        | `[]const u8` | `"req-"`         | ID prefix                      |
| `use_uuid`      | `bool`       | `false`          | Use UUID format                |
| `trust_incoming`| `bool`       | `false`          | Trust incoming request ID      |

## RecoveryConfig

Panic recovery middleware configuration.

```zig
const RecMw = api.recoverWithConfig(.{
    .log_stack_trace = true,
    .include_error_details = false,
    .custom_error_body = null,
});
try app.use(RecMw.handle);
```

| Field                  | Type          | Default | Description                    |
| ---------------------- | ------------- | ------- | ------------------------------ |
| `log_stack_trace`      | `bool`        | `true`  | Log stack trace on panic       |
| `include_error_details`| `bool`        | `false` | Include error in response      |
| `custom_error_body`    | `?[]const u8` | `null`  | Custom error response body     |

## Custom Middleware

Create custom middleware functions:

```zig
fn timingMiddleware(ctx: *api.Context, next: api.App.HandlerFn) api.Response {
    // Pre-processing
    const start = std.time.milliTimestamp();

    // Call next handler
    var response = next(ctx);

    // Post-processing
    const duration = std.time.milliTimestamp() - start;
    var buf: [32]u8 = undefined;
    const timing = std.fmt.bufPrint(&buf, "{d}ms", .{duration}) catch "?ms";
    response = response.setHeader("X-Response-Time", timing);

    return response;
}

// Register middleware
try app.use(timingMiddleware);
```

## Middleware Order

Middleware executes in registration order. Recommended order:

```zig
// 1. Recovery (catch panics)
try app.use(api.recover);

// 2. Request ID (early for tracing)
try app.use(api.requestId);

// 3. Logging
try app.use(api.logger);

// 4. Security headers
try app.use(api.defaultSecurityHeaders);

// 5. CORS
const CorsMw = api.cors(.{});
try app.use(CorsMw.handle);

// 6. Rate limiting
const RateMw = api.rateLimit(.{});
try app.use(RateMw.handle);

// 7. Authentication
try app.use(api.basicAuth);

// 8. Compression
try app.use(api.gzip);
```

## Example: Complete Setup

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "Secure API",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Add middleware stack
    try app.use(api.recover);
    try app.use(api.requestId);
    try app.use(api.logger);

    const CorsMw = api.cors(.{
        .allowed_origins = &.{"https://myapp.com"},
        .allow_credentials = true,
    });
    try app.use(CorsMw.handle);

    const SecMw = api.securityHeaders(.{
        .strict_transport_security = .{ .max_age = 31536000 },
    });
    try app.use(SecMw.handle);

    // Register routes
    try app.get("/", handler);

    try app.run(.{ .port = 8000 });
}

fn handler() api.Response {
    return api.Response.jsonRaw("{\"status\":\"ok\"}");
}
```

**Output:**
```
[OK] http://127.0.0.1:8000
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
[REQ] GET /
[RES] 200 (2ms)
```
