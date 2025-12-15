# Middleware

Middleware functions intercept requests before they reach route handlers and responses before they are sent to clients. This enables cross-cutting concerns like authentication, logging, compression, and request validation.

## Built-in Middleware

| Middleware          | Description                                      |
| ------------------- | ------------------------------------------------ |
| `logger`            | Structured request/response logging with timing  |
| `loggerWithConfig`  | Configurable logging with skip paths and formats |
| `basicAuth`         | HTTP Basic Authentication with Base64 decoding   |
| `auth`              | Full auth (Basic, Bearer, API Key) with configs  |
| `trustedHost`       | Host header validation against allowlist         |
| `trustedHostMiddleware` | Configurable trusted host validation         |
| `cors`              | Cross-Origin Resource Sharing headers            |
| `requestId`         | Unique request identifier generation             |
| `requestIdWithConfig` | Configurable request ID with UUID support      |
| `securityHeaders`   | Security headers (CSP, X-Frame-Options, HSTS)    |
| `defaultSecurityHeaders` | Pre-configured security headers             |
| `rateLimit`         | Request rate limiting per IP/user/API key        |
| `gzip`              | Response compression with Accept-Encoding        |
| `compressionWithConfig` | Configurable compression with min size       |
| `etag`              | ETag-based caching support                       |
| `recover`           | Panic recovery with error responses              |
| `recoverWithConfig` | Configurable panic recovery                      |
| `timeout`           | Request timeout handling                         |

## Quick Start

```zig
var app = try api.App.init(allocator, .{});

// Simple middleware
try app.use(api.recover);
try app.use(api.requestId);
try app.use(api.logger);

// Configured middleware
const CorsMw = api.cors(.{ .allowed_origins = &.{"https://example.com"} });
try app.use(CorsMw.handle);
```

## Middleware Configurations

### CORS Configuration

```zig
const CorsMw = api.cors(.{
    .allowed_origins = &.{ "https://example.com" },
    .allowed_methods = &.{ "GET", "POST", "PUT", "DELETE" },
    .allowed_headers = &.{ "Content-Type", "Authorization" },
    .allow_credentials = true,
    .max_age = 86400,
});
try app.use(CorsMw.handle);
```

| Field               | Type                 | Default  | Description                   |
| ------------------- | -------------------- | -------- | ----------------------------- |
| `allowed_origins`   | `[]const []const u8` | `&.{"*"}`| Allowed origins               |
| `allowed_methods`   | `[]const []const u8` | All      | Allowed HTTP methods          |
| `allowed_headers`   | `[]const []const u8` | Common   | Allowed request headers       |
| `allow_credentials` | `bool`               | `false`  | Allow credentials             |
| `max_age`           | `u32`                | `86400`  | Preflight cache duration (s)  |

### Rate Limiting Configuration

```zig
const RateMw = api.rateLimit(.{
    .requests_per_window = 100,
    .window_seconds = 60,
    .key_extractor = .ip,
    .headers = true,
});
try app.use(RateMw.handle);
```

| Field                  | Type   | Default | Description                  |
| ---------------------- | ------ | ------- | ---------------------------- |
| `requests_per_window`  | `u32`  | `100`   | Max requests per window      |
| `window_seconds`       | `u32`  | `60`    | Time window in seconds       |
| `key_extractor`        | `enum` | `.ip`   | Client identification method |
| `headers`              | `bool` | `true`  | Add X-RateLimit-* headers    |

### Security Headers Configuration

```zig
const SecMw = api.securityHeaders(.{
    .content_security_policy = "default-src 'self'",
    .x_frame_options = .deny,
    .x_xss_protection = true,
    .strict_transport_security = .{
        .max_age = 31536000,
        .include_subdomains = true,
    },
});
try app.use(SecMw.handle);
```

| Field                       | Type          | Default                | Description             |
| --------------------------- | ------------- | ---------------------- | ----------------------- |
| `content_security_policy`   | `?[]const u8` | `"default-src 'self'"` | CSP header value        |
| `x_frame_options`           | `enum`        | `.deny`                | Frame embedding policy  |
| `x_xss_protection`          | `bool`        | `true`                 | XSS protection header   |
| `strict_transport_security` | `?struct`     | `null`                 | HSTS configuration      |

## Custom Middleware

Create middleware that wraps the next handler:

```zig
fn timingMiddleware(ctx: *api.Context, next: api.App.HandlerFn) api.Response {
    // Pre-processing
    const start = std.time.milliTimestamp();

    // Call next handler in chain
    var response = next(ctx);

    // Post-processing
    const duration = std.time.milliTimestamp() - start;
    ctx.logger.infof("Request completed in {d}ms", .{duration}, null) catch {};

    return response;
}

try app.use(timingMiddleware);
```

## Middleware Chain

Middleware executes in registration order. The first registered middleware runs first on the request and last on the response.

```zig
try app.use(recover);   // 1st request, 3rd response
try app.use(logging);   // 2nd request, 2nd response  
try app.use(compress);  // 3rd request, 1st response
```

## Recommended Order

```zig
// 1. Error recovery (catches panics in all subsequent middleware)
try app.use(api.recover);

// 2. Request ID (for tracing through the entire request)
try app.use(api.requestId);

// 3. Logging (log all requests including failed ones)
try app.use(api.logger);

// 4. Security headers (always add security headers)
try app.use(api.defaultSecurityHeaders);

// 5. CORS (handle preflight before other processing)
try app.use(api.cors(.{}).handle);

// 6. Rate limiting (reject excess requests early)
try app.use(api.rateLimit(.{}).handle);

// 7. Authentication (after rate limiting, before business logic)
try app.use(api.basicAuth);

// 8. Compression (compress responses at the end)
try app.use(api.gzip);
```

## Example: Authentication Middleware

```zig
fn authMiddleware(ctx: *api.Context, next: api.App.HandlerFn) api.Response {
    // Skip auth for public endpoints
    if (std.mem.eql(u8, ctx.path(), "/health") or
        std.mem.eql(u8, ctx.path(), "/docs")) {
        return next(ctx);
    }

    // Check for Authorization header
    const auth_header = ctx.header("Authorization") orelse {
        return api.Response.err(.unauthorized, "{\"error\":\"Missing Authorization header\"}");
    };

    // Validate token (simplified example)
    if (!std.mem.startsWith(u8, auth_header, "Bearer ")) {
        return api.Response.err(.unauthorized, "{\"error\":\"Invalid auth scheme\"}");
    }

    const token = auth_header[7..];
    if (!isValidToken(token)) {
        return api.Response.err(.forbidden, "{\"error\":\"Invalid token\"}");
    }

    // Store user info in context for handlers
    ctx.set("user_id", @ptrCast(@constCast("user123")));

    return next(ctx);
}

fn isValidToken(token: []const u8) bool {
    // Your token validation logic here
    return token.len > 0;
}
```

**Output:**
```
[REQ] GET /api/users
[RES] 200 (5ms)
[REQ] GET /docs
[RES] 200 (2ms)
```
