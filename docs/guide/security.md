# Security

Built-in security middleware protects against common web vulnerabilities including XSS, clickjacking, CSRF, and host header attacks.

## Authentication

### HTTP Basic Authentication

The `basicAuth` middleware decodes Base64 credentials from the `Authorization` header:

```zig
try app.use(api.basicAuth);

fn protectedHandler(ctx: *api.Context) api.Response {
    // Credentials are stored in context state
    const username = ctx.get([]const u8, "auth_username");
    const password = ctx.get([]const u8, "auth_password");
    
    // Validate against your user store
    if (username == null or !validateUser(username.?, password.?)) {
        return api.Response.err(.unauthorized, "{\"error\":\"Invalid credentials\"}");
    }
    
    return api.Response.jsonRaw("{\"message\":\"Welcome\"}");
}

fn validateUser(username: []const u8, password: []const u8) bool {
    // Your validation logic
    return std.mem.eql(u8, username, "admin") and std.mem.eql(u8, password, "secret");
}
```

### Bearer Token Authentication

For JWT or API tokens:

```zig
const AuthMw = api.auth(.{
    .scheme = .bearer,
    .realm = "API Access",
    .token_validator = validateToken,
    .exclude_paths = &.{ "/health", "/docs", "/redoc", "/openapi.json" },
});
try app.use(AuthMw.handle);

fn validateToken(token: []const u8) bool {
    // Validate JWT or API token
    return token.len > 0 and isValidJwt(token);
}
```

### API Key Authentication

For API key-based auth:

```zig
const AuthMw = api.auth(.{
    .scheme = .api_key,
    .api_key_header = "X-API-Key",
    .api_key_query = "api_key",  // Also accepts ?api_key=...
    .token_validator = validateApiKey,
});
try app.use(AuthMw.handle);
```

## AuthConfig Options

| Field             | Type                           | Default         | Description                    |
| ----------------- | ------------------------------ | --------------- | ------------------------------ |
| `scheme`          | `AuthScheme`                   | `.basic`        | Auth type (basic/bearer/api_key)|
| `realm`           | `[]const u8`                   | `"Secure Area"` | WWW-Authenticate realm         |
| `api_key_header`  | `[]const u8`                   | `"X-API-Key"`   | Header for API key             |
| `api_key_query`   | `[]const u8`                   | `"api_key"`     | Query param for API key        |
| `validator`       | `?fn([]const u8, []const u8) bool` | `null`      | Username/password validator    |
| `token_validator` | `?fn([]const u8) bool`         | `null`          | Token/API key validator        |
| `exclude_paths`   | `[]const []const u8`           | `&.{}`          | Paths to skip auth             |
| `optional`        | `bool`                         | `false`         | Allow unauthenticated access   |

## Trusted Host Validation

Prevents HTTP Host header attacks by validating against an allowlist:

```zig
const TrustedHosts = api.trustedHostMiddleware(.{
    .allowed_hosts = &.{ "example.com", "api.example.com" },
    .allow_subdomains = true,
    .enforce_https = false,
});
try app.use(TrustedHosts.handle);
```

| Field              | Type                 | Default                        | Description             |
| ------------------ | -------------------- | ------------------------------ | ----------------------- |
| `allowed_hosts`    | `[]const []const u8` | `&.{"localhost", "127.0.0.1"}` | Allowed host values     |
| `allow_subdomains` | `bool`               | `false`                        | Allow *.example.com     |
| `www_redirect`     | `bool`               | `false`                        | Redirect www to non-www |
| `enforce_https`    | `bool`               | `false`                        | Require HTTPS           |

## CORS Configuration

Configure Cross-Origin Resource Sharing:

```zig
const CorsMw = api.cors(.{
    .allowed_origins = &.{ "https://frontend.example.com" },
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
| `allow_credentials` | `bool`               | `false`  | Allow cookies/auth            |
| `max_age`           | `u32`                | `86400`  | Preflight cache (seconds)     |

## Security Headers

Add comprehensive security headers:

```zig
const SecMw = api.securityHeaders(.{
    .content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline'",
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

Or use production defaults:

```zig
try app.use(api.defaultSecurityHeaders);
```

### Security Headers Added

| Header                        | Value                             | Protection Against       |
| ----------------------------- | --------------------------------- | ------------------------ |
| `Content-Security-Policy`     | `default-src 'self'`              | XSS, injection attacks   |
| `X-Content-Type-Options`      | `nosniff`                         | MIME sniffing            |
| `X-Frame-Options`             | `DENY`                            | Clickjacking             |
| `X-XSS-Protection`            | `1; mode=block`                   | Reflected XSS            |
| `Strict-Transport-Security`   | `max-age=31536000`                | Protocol downgrade       |
| `Referrer-Policy`             | `strict-origin-when-cross-origin` | Referrer leakage         |

## Rate Limiting

Protect against abuse and DDoS:

```zig
const RateMw = api.rateLimit(.{
    .requests_per_window = 100,
    .window_seconds = 60,
    .key_extractor = .ip,
    .headers = true,
    .message = "{\"error\":\"Rate limit exceeded. Try again later.\"}",
});
try app.use(RateMw.handle);
```

| Field                  | Type           | Default | Description                  |
| ---------------------- | -------------- | ------- | ---------------------------- |
| `requests_per_window`  | `u32`          | `100`   | Max requests per window      |
| `window_seconds`       | `u32`          | `60`    | Window duration in seconds   |
| `key_extractor`        | `KeyExtractor` | `.ip`   | How to identify clients      |
| `headers`              | `bool`         | `true`  | Add X-RateLimit-* headers    |

## Complete Security Setup

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

    // 1. Panic recovery
    try app.use(api.recover);

    // 2. Request tracing
    try app.use(api.requestId);

    // 3. Logging
    try app.use(api.logger);

    // 4. Security headers
    const SecMw = api.securityHeaders(.{
        .strict_transport_security = .{ .max_age = 31536000 },
    });
    try app.use(SecMw.handle);

    // 5. Trusted hosts
    const HostMw = api.trustedHostMiddleware(.{
        .allowed_hosts = &.{ "api.example.com" },
    });
    try app.use(HostMw.handle);

    // 6. CORS
    const CorsMw = api.cors(.{
        .allowed_origins = &.{ "https://example.com" },
        .allow_credentials = true,
    });
    try app.use(CorsMw.handle);

    // 7. Rate limiting
    const RateMw = api.rateLimit(.{
        .requests_per_window = 100,
        .window_seconds = 60,
    });
    try app.use(RateMw.handle);

    // 8. Authentication
    const AuthMw = api.auth(.{
        .scheme = .bearer,
        .exclude_paths = &.{ "/health", "/docs" },
    });
    try app.use(AuthMw.handle);

    // Routes
    try app.get("/", secureHandler);
    try app.get("/health", healthHandler);

    try app.run(.{ .port = 8000 });
}

fn secureHandler() api.Response {
    return api.Response.jsonRaw("{\"message\":\"Secure endpoint\"}");
}

fn healthHandler() api.Response {
    return api.Response.jsonRaw("{\"status\":\"healthy\"}");
}
```

**Output:**
```
[OK] http://127.0.0.1:8000
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
```

**Response Headers:**
```
Content-Security-Policy: default-src 'self'
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: strict-origin-when-cross-origin
X-Request-ID: req-1
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 99
```
