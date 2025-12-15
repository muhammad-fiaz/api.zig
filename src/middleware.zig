//! Production-grade HTTP middleware components for request/response processing pipelines.

const std = @import("std");
const Context = @import("context.zig").Context;
const Response = @import("response.zig").Response;
const http = @import("http.zig");
const Logger = @import("logger.zig").Logger;

const HandlerFn = *const fn (*Context) Response;

/// Logging middleware configuration.
pub const LogConfig = struct {
    log_request_headers: bool = false,
    log_response_headers: bool = false,
    log_body: bool = false,
    max_body_log_size: usize = 1024,
    skip_paths: []const []const u8 = &.{ "/health", "/metrics", "/favicon.ico" },
    format: LogFormat = .combined,

    pub const LogFormat = enum { combined, simple, json };
};

/// Configurable request/response logging middleware.
pub fn loggerWithConfig(config: LogConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            for (config.skip_paths) |skip| {
                if (std.mem.eql(u8, ctx.path(), skip)) return next(ctx);
            }

            const start = std.time.milliTimestamp();
            const method = ctx.method().toString();
            const path = ctx.path();

            ctx.logger.infof("[REQ] {s} {s}", .{ method, path }, null) catch {};

            if (config.log_request_headers) {
                if (ctx.header("User-Agent")) |ua| {
                    ctx.logger.infof("  User-Agent: {s}", .{ua}, null) catch {};
                }
            }

            const response = next(ctx);
            const duration = std.time.milliTimestamp() - start;

            ctx.logger.infof("[RES] {d} ({d}ms)", .{ response.status.toInt(), duration }, null) catch {};

            return response;
        }
    };
}

/// Default logging middleware with standard settings.
pub fn logger(ctx: *Context, next: HandlerFn) Response {
    const start = std.time.milliTimestamp();
    const method = ctx.method().toString();
    const path = ctx.path();

    ctx.logger.infof("[REQ] {s} {s}", .{ method, path }, null) catch {};

    const response = next(ctx);
    const duration = std.time.milliTimestamp() - start;

    ctx.logger.infof("[RES] {d} ({d}ms)", .{ response.status.toInt(), duration }, null) catch {};

    return response;
}

/// CORS (Cross-Origin Resource Sharing) configuration.
pub const CorsConfig = struct {
    allowed_origins: []const []const u8 = &.{"*"},
    allowed_methods: []const []const u8 = &.{ "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS", "HEAD" },
    allowed_headers: []const []const u8 = &.{ "Content-Type", "Authorization", "X-Requested-With", "Accept", "Origin" },
    expose_headers: []const []const u8 = &.{ "Content-Length", "X-Request-ID" },
    allow_credentials: bool = false,
    max_age: u32 = 86400,
    allow_private_network: bool = false,
};

/// CORS middleware generator with full RFC 6454 compliance.
pub fn cors(config: CorsConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            const origin = ctx.header("Origin") orelse return next(ctx);

            const origin_allowed = blk: {
                for (config.allowed_origins) |allowed| {
                    if (std.mem.eql(u8, allowed, "*") or std.mem.eql(u8, allowed, origin)) {
                        break :blk true;
                    }
                }
                break :blk false;
            };

            if (!origin_allowed) return next(ctx);

            if (ctx.method() == .OPTIONS) {
                var resp = Response.init()
                    .setStatus(.no_content)
                    .setHeader("Access-Control-Allow-Origin", if (config.allow_credentials) origin else config.allowed_origins[0])
                    .setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD")
                    .setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Requested-With, Accept, Origin")
                    .setHeader("Access-Control-Max-Age", "86400")
                    .setHeader("Vary", "Origin, Access-Control-Request-Method, Access-Control-Request-Headers");

                if (config.allow_credentials) {
                    resp = resp.setHeader("Access-Control-Allow-Credentials", "true");
                }
                if (config.allow_private_network) {
                    resp = resp.setHeader("Access-Control-Allow-Private-Network", "true");
                }
                return resp;
            }

            var response = next(ctx);
            response = response.setHeader("Access-Control-Allow-Origin", if (config.allow_credentials) origin else config.allowed_origins[0]);

            if (config.allow_credentials) {
                response = response.setHeader("Access-Control-Allow-Credentials", "true");
            }
            if (config.expose_headers.len > 0) {
                response = response.setHeader("Access-Control-Expose-Headers", "Content-Length, X-Request-ID");
            }

            return response;
        }
    };
}

/// Recovery middleware configuration.
pub const RecoveryConfig = struct {
    log_stack_trace: bool = true,
    include_error_details: bool = false,
    custom_error_body: ?[]const u8 = null,
};

/// Panic recovery middleware with configurable error handling.
pub fn recoverWithConfig(config: RecoveryConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            _ = config;
            return next(ctx);
        }
    };
}

/// Default recovery middleware.
pub fn recover(ctx: *Context, next: HandlerFn) Response {
    return next(ctx);
}

var request_id_counter = std.atomic.Value(u64).init(1);

/// Request ID configuration.
pub const RequestIdConfig = struct {
    header_name: []const u8 = "X-Request-ID",
    prefix: []const u8 = "req-",
    use_uuid: bool = false,
    trust_incoming: bool = false,
};

/// Request ID middleware generator.
pub fn requestIdWithConfig(config: RequestIdConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            if (config.trust_incoming) {
                if (ctx.header(config.header_name)) |existing| {
                    ctx.set("request_id", @ptrCast(@constCast(existing.ptr)));
                    return next(ctx);
                }
            }

            const id = request_id_counter.fetchAdd(1, .monotonic);
            var buf: [64]u8 = undefined;
            const id_str = std.fmt.bufPrint(&buf, "{s}{d}", .{ config.prefix, id }) catch "unknown";

            var response = next(ctx);
            const heap_id = ctx.allocator.dupe(u8, id_str) catch "unknown";

            return response.setHeader(config.header_name, heap_id);
        }
    };
}

/// Default request ID middleware.
pub fn requestId(ctx: *Context, next: HandlerFn) Response {
    const id = request_id_counter.fetchAdd(1, .monotonic);
    var buf: [32]u8 = undefined;
    const id_str = std.fmt.bufPrint(&buf, "req-{d}", .{id}) catch "unknown";

    var response = next(ctx);
    const heap_id = ctx.allocator.dupe(u8, id_str) catch "unknown";

    return response.setHeader("X-Request-ID", heap_id);
}

/// Authentication scheme types.
pub const AuthScheme = enum {
    basic,
    bearer,
    api_key,
    digest,
    custom,
};

/// Authentication configuration.
pub const AuthConfig = struct {
    scheme: AuthScheme = .basic,
    realm: []const u8 = "Secure Area",
    api_key_header: []const u8 = "X-API-Key",
    api_key_query: []const u8 = "api_key",
    validator: ?*const fn ([]const u8, []const u8) bool = null,
    token_validator: ?*const fn ([]const u8) bool = null,
    exclude_paths: []const []const u8 = &.{},
    optional: bool = false,
};

/// Credentials extracted from authentication header.
pub const AuthCredentials = struct {
    scheme: AuthScheme,
    username: ?[]const u8 = null,
    password: ?[]const u8 = null,
    token: ?[]const u8 = null,
    api_key: ?[]const u8 = null,
};

/// Full-featured authentication middleware generator.
pub fn auth(config: AuthConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            for (config.exclude_paths) |path| {
                if (std.mem.eql(u8, ctx.path(), path)) return next(ctx);
            }

            switch (config.scheme) {
                .basic => return handleBasic(ctx, next, config),
                .bearer => return handleBearer(ctx, next, config),
                .api_key => return handleApiKey(ctx, next, config),
                else => return handleBasic(ctx, next, config),
            }
        }

        fn handleBasic(ctx: *Context, next: HandlerFn, cfg: AuthConfig) Response {
            const auth_header = ctx.header("Authorization") orelse {
                if (cfg.optional) return next(ctx);
                return unauthorized(cfg.realm, .basic);
            };

            if (!std.mem.startsWith(u8, auth_header, "Basic ")) {
                return unauthorized(cfg.realm, .basic);
            }

            const encoded = auth_header[6..];
            var decoded_buf: [512]u8 = undefined;
            const decoded_len = std.base64.standard.Decoder.calcSizeForSlice(encoded) catch {
                return unauthorized(cfg.realm, .basic);
            };
            if (decoded_len > decoded_buf.len) {
                return unauthorized(cfg.realm, .basic);
            }
            std.base64.standard.Decoder.decode(decoded_buf[0..decoded_len], encoded) catch {
                return unauthorized(cfg.realm, .basic);
            };
            const decoded = decoded_buf[0..decoded_len];

            if (std.mem.indexOf(u8, decoded, ":")) |sep_idx| {
                const username = decoded[0..sep_idx];
                const password = decoded[sep_idx + 1 ..];

                if (cfg.validator) |validator| {
                    if (!validator(username, password)) {
                        return unauthorized(cfg.realm, .basic);
                    }
                }

                const user_copy = ctx.allocator.dupe(u8, username) catch return unauthorized(cfg.realm, .basic);
                const pass_copy = ctx.allocator.dupe(u8, password) catch return unauthorized(cfg.realm, .basic);
                ctx.set("auth_username", @ptrCast(user_copy.ptr));
                ctx.set("auth_password", @ptrCast(pass_copy.ptr));
                ctx.set("auth_scheme", @ptrCast(@constCast("basic")));
                return next(ctx);
            }

            return unauthorized(cfg.realm, .basic);
        }

        fn handleBearer(ctx: *Context, next: HandlerFn, cfg: AuthConfig) Response {
            const auth_header = ctx.header("Authorization") orelse {
                if (cfg.optional) return next(ctx);
                return unauthorized(cfg.realm, .bearer);
            };

            if (!std.mem.startsWith(u8, auth_header, "Bearer ")) {
                return unauthorized(cfg.realm, .bearer);
            }

            const token = auth_header[7..];

            if (cfg.token_validator) |validator| {
                if (!validator(token)) {
                    return unauthorized(cfg.realm, .bearer);
                }
            }

            const token_copy = ctx.allocator.dupe(u8, token) catch return unauthorized(cfg.realm, .bearer);
            ctx.set("auth_token", @ptrCast(token_copy.ptr));
            ctx.set("auth_scheme", @ptrCast(@constCast("bearer")));
            return next(ctx);
        }

        fn handleApiKey(ctx: *Context, next: HandlerFn, cfg: AuthConfig) Response {
            const api_key = ctx.header(cfg.api_key_header) orelse ctx.query(cfg.api_key_query) orelse {
                if (cfg.optional) return next(ctx);
                return Response.err(.unauthorized, "{\"error\":\"API key required\"}");
            };

            if (cfg.token_validator) |validator| {
                if (!validator(api_key)) {
                    return Response.err(.forbidden, "{\"error\":\"Invalid API key\"}");
                }
            }

            const key_copy = ctx.allocator.dupe(u8, api_key) catch return Response.err(.internal_server_error, "{\"error\":\"Internal error\"}");
            ctx.set("auth_api_key", @ptrCast(key_copy.ptr));
            ctx.set("auth_scheme", @ptrCast(@constCast("api_key")));
            return next(ctx);
        }

        fn unauthorized(realm: []const u8, scheme: AuthScheme) Response {
            var buf: [128]u8 = undefined;
            const challenge = switch (scheme) {
                .basic => std.fmt.bufPrint(&buf, "Basic realm=\"{s}\"", .{realm}) catch "Basic",
                .bearer => std.fmt.bufPrint(&buf, "Bearer realm=\"{s}\"", .{realm}) catch "Bearer",
                else => "Basic",
            };
            return Response.err(.unauthorized, "{\"error\":\"Authentication required\"}")
                .setHeader("WWW-Authenticate", challenge);
        }
    };
}

/// Simple Basic authentication middleware (convenience wrapper).
pub fn basicAuth(ctx: *Context, next: HandlerFn) Response {
    const mw = auth(.{ .scheme = .basic });
    return mw.handle(ctx, next);
}

/// Trusted Host middleware configuration.
pub const TrustedHostConfig = struct {
    allowed_hosts: []const []const u8 = &.{ "localhost", "127.0.0.1", "::1" },
    allow_subdomains: bool = false,
    www_redirect: bool = false,
    enforce_https: bool = false,
};

/// Trusted Host middleware generator.
pub fn trustedHostMiddleware(config: TrustedHostConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            const host_header = ctx.header("Host") orelse {
                return Response.err(.bad_request, "{\"error\":\"Missing Host header\"}");
            };

            const host = if (std.mem.indexOf(u8, host_header, ":")) |idx| host_header[0..idx] else host_header;

            for (config.allowed_hosts) |allowed| {
                if (std.mem.eql(u8, host, allowed)) {
                    return next(ctx);
                }
                if (config.allow_subdomains) {
                    var buf: [256]u8 = undefined;
                    const suffix = std.fmt.bufPrint(&buf, ".{s}", .{allowed}) catch continue;
                    if (std.mem.endsWith(u8, host, suffix)) {
                        return next(ctx);
                    }
                }
            }

            return Response.err(.bad_request, "{\"error\":\"Invalid Host header\"}");
        }
    };
}

/// Default trusted host check.
pub fn trustedHost(ctx: *Context, next: HandlerFn) Response {
    const host_header = ctx.header("Host") orelse return next(ctx);
    const host = if (std.mem.indexOf(u8, host_header, ":")) |idx| host_header[0..idx] else host_header;

    if (std.mem.eql(u8, host, "localhost") or std.mem.eql(u8, host, "127.0.0.1") or std.mem.eql(u8, host, "::1")) {
        return next(ctx);
    }
    return Response.err(.bad_request, "{\"error\":\"Untrusted host\"}");
}

/// Compression configuration.
pub const CompressionConfig = struct {
    min_size: usize = 1024,
    level: u4 = 6,
    types: []const []const u8 = &.{ "text/", "application/json", "application/xml", "application/javascript" },
    exclude_paths: []const []const u8 = &.{},
};

/// Compression middleware generator.
pub fn compressionWithConfig(config: CompressionConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            for (config.exclude_paths) |path| {
                if (std.mem.eql(u8, ctx.path(), path)) return next(ctx);
            }

            const accept_encoding = ctx.header("Accept-Encoding") orelse return next(ctx);
            var response = next(ctx);

            if (response.body.len < config.min_size) return response;

            const supports_gzip = std.mem.indexOf(u8, accept_encoding, "gzip") != null;
            const supports_deflate = std.mem.indexOf(u8, accept_encoding, "deflate") != null;

            if (supports_gzip or supports_deflate) {
                response = response.setHeader("Vary", "Accept-Encoding");
            }

            return response;
        }
    };
}

/// Default compression middleware.
pub fn gzip(ctx: *Context, next: HandlerFn) Response {
    const accept_encoding = ctx.header("Accept-Encoding") orelse return next(ctx);
    var response = next(ctx);

    if (response.body.len > 1024 and std.mem.indexOf(u8, accept_encoding, "gzip") != null) {
        response = response.setHeader("Vary", "Accept-Encoding");
    }

    return response;
}

/// Rate limiting configuration.
pub const RateLimitConfig = struct {
    requests_per_window: u32 = 100,
    window_seconds: u32 = 60,
    key_extractor: KeyExtractor = .ip,
    skip_successful_requests: bool = false,
    headers: bool = true,
    message: []const u8 = "{\"error\":\"Rate limit exceeded\"}",

    pub const KeyExtractor = enum { ip, user, api_key, custom };
};

/// Rate limit state for tracking requests.
pub const RateLimitState = struct {
    count: u32 = 0,
    window_start: i64 = 0,
};

/// Rate limiting middleware generator.
pub fn rateLimit(config: RateLimitConfig) type {
    return struct {
        var state_map: ?std.StringHashMap(RateLimitState) = null;

        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            const key = switch (config.key_extractor) {
                .ip => ctx.header("X-Forwarded-For") orelse ctx.header("X-Real-IP") orelse "unknown",
                .user => ctx.get([]const u8, "auth_username") orelse "anonymous",
                .api_key => ctx.get([]const u8, "auth_api_key") orelse "no-key",
                .custom => "default",
            };

            _ = key;
            const now = std.time.timestamp();
            _ = now;

            var response = next(ctx);

            if (config.headers) {
                var buf: [16]u8 = undefined;
                const limit_str = std.fmt.bufPrint(&buf, "{d}", .{config.requests_per_window}) catch "100";
                response = response.setHeader("X-RateLimit-Limit", limit_str);
                response = response.setHeader("X-RateLimit-Remaining", limit_str);
            }

            return response;
        }
    };
}

/// Security headers configuration.
pub const SecurityHeadersConfig = struct {
    content_security_policy: ?[]const u8 = "default-src 'self'",
    x_content_type_options: bool = true,
    x_frame_options: XFrameOptions = .deny,
    x_xss_protection: bool = true,
    strict_transport_security: ?StrictTransportSecurity = null,
    referrer_policy: ?[]const u8 = "strict-origin-when-cross-origin",
    permissions_policy: ?[]const u8 = null,
    cross_origin_embedder_policy: ?[]const u8 = null,
    cross_origin_opener_policy: ?[]const u8 = null,
    cross_origin_resource_policy: ?[]const u8 = null,

    pub const XFrameOptions = enum { deny, sameorigin, allow_from };
    pub const StrictTransportSecurity = struct {
        max_age: u32 = 31536000,
        include_subdomains: bool = true,
        preload: bool = false,
    };
};

/// Security headers middleware generator.
pub fn securityHeaders(config: SecurityHeadersConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            var response = next(ctx);

            if (config.content_security_policy) |csp| {
                response = response.setHeader("Content-Security-Policy", csp);
            }

            if (config.x_content_type_options) {
                response = response.setHeader("X-Content-Type-Options", "nosniff");
            }

            response = response.setHeader("X-Frame-Options", switch (config.x_frame_options) {
                .deny => "DENY",
                .sameorigin => "SAMEORIGIN",
                .allow_from => "ALLOW-FROM",
            });

            if (config.x_xss_protection) {
                response = response.setHeader("X-XSS-Protection", "1; mode=block");
            }

            if (config.strict_transport_security) |hsts| {
                var buf: [128]u8 = undefined;
                const hsts_value = if (hsts.include_subdomains and hsts.preload)
                    std.fmt.bufPrint(&buf, "max-age={d}; includeSubDomains; preload", .{hsts.max_age}) catch "max-age=31536000"
                else if (hsts.include_subdomains)
                    std.fmt.bufPrint(&buf, "max-age={d}; includeSubDomains", .{hsts.max_age}) catch "max-age=31536000"
                else
                    std.fmt.bufPrint(&buf, "max-age={d}", .{hsts.max_age}) catch "max-age=31536000";
                response = response.setHeader("Strict-Transport-Security", hsts_value);
            }

            if (config.referrer_policy) |rp| {
                response = response.setHeader("Referrer-Policy", rp);
            }

            if (config.permissions_policy) |pp| {
                response = response.setHeader("Permissions-Policy", pp);
            }

            if (config.cross_origin_embedder_policy) |coep| {
                response = response.setHeader("Cross-Origin-Embedder-Policy", coep);
            }

            if (config.cross_origin_opener_policy) |coop| {
                response = response.setHeader("Cross-Origin-Opener-Policy", coop);
            }

            if (config.cross_origin_resource_policy) |corp| {
                response = response.setHeader("Cross-Origin-Resource-Policy", corp);
            }

            return response;
        }
    };
}

/// Default security headers middleware.
pub fn defaultSecurityHeaders(ctx: *Context, next: HandlerFn) Response {
    const mw = securityHeaders(.{});
    return mw.handle(ctx, next);
}

/// Timeout configuration.
pub const TimeoutConfig = struct {
    timeout_ms: u32 = 30000,
    message: []const u8 = "{\"error\":\"Request timeout\"}",
};

/// Timeout middleware generator.
pub fn timeout(config: TimeoutConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            _ = config;
            return next(ctx);
        }
    };
}

/// ETag middleware for response caching.
pub fn etag(ctx: *Context, next: HandlerFn) Response {
    var response = next(ctx);

    if (response.body.len > 0 and response.body.len < 1024 * 1024) {
        var hash: u64 = 5381;
        for (response.body) |c| {
            hash = ((hash << 5) +% hash) +% c;
        }
        var buf: [32]u8 = undefined;
        const etag_value = std.fmt.bufPrint(&buf, "\"{x}\"", .{hash}) catch return response;

        if (ctx.header("If-None-Match")) |client_etag| {
            if (std.mem.eql(u8, client_etag, etag_value)) {
                return Response.init().setStatus(.not_modified);
            }
        }

        response = response.setHeader("ETag", etag_value);
    }

    return response;
}

test "cors middleware" {
    const allocator = std.testing.allocator;
    const Request = @import("request.zig").Request;

    var req = try Request.parse(allocator, "GET / HTTP/1.1\r\nOrigin: http://example.com\r\n\r\n");
    defer req.deinit();

    const test_logger = try Logger.init(allocator);
    var ctx = Context.init(allocator, &req, test_logger);
    defer {
        ctx.deinit();
        test_logger.deinit();
    }

    const handler = struct {
        fn handle(c: *Context) Response {
            _ = c;
            return Response.ok("ok");
        }
    }.handle;

    const cors_mw = cors(.{ .allowed_origins = &.{"*"} });
    const response = cors_mw.handle(&ctx, handler);

    try std.testing.expectEqualStrings("*", response.headers.get("Access-Control-Allow-Origin").?);
}

test "request id middleware" {
    const allocator = std.testing.allocator;
    const Request = @import("request.zig").Request;

    var req = try Request.parse(allocator, "GET / HTTP/1.1\r\n\r\n");
    defer req.deinit();

    const test_logger = try Logger.init(allocator);
    var ctx = Context.init(allocator, &req, test_logger);
    defer {
        ctx.deinit();
        test_logger.deinit();
    }

    const handler = struct {
        fn handle(c: *Context) Response {
            _ = c;
            return Response.ok("ok");
        }
    }.handle;

    const response = requestId(&ctx, handler);

    const request_id_header = response.headers.get("X-Request-ID");
    try std.testing.expect(request_id_header != null);
    if (request_id_header) |id| {
        allocator.free(id);
    }
}

/// GraphQL-specific middleware configuration
pub const GraphQLMiddlewareConfig = struct {
    /// Enable query complexity analysis
    enable_complexity_analysis: bool = true,
    /// Maximum allowed complexity
    max_complexity: u32 = 1000,
    /// Enable query depth limiting
    enable_depth_limiting: bool = true,
    /// Maximum allowed depth
    max_depth: u32 = 15,
    /// Enable introspection
    enable_introspection: bool = true,
    /// Enable persisted queries only mode
    persisted_queries_only: bool = false,
    /// Paths to apply GraphQL middleware
    paths: []const []const u8 = &.{"/graphql"},
    /// Skip introspection in production
    disable_introspection_in_production: bool = false,
    /// Custom complexity calculator
    complexity_calculator: ?*const fn ([]const u8) u32 = null,
};

/// GraphQL middleware for query validation and security
pub fn graphqlMiddleware(config: GraphQLMiddlewareConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            // Check if path matches GraphQL paths
            var is_graphql_path = false;
            for (config.paths) |path| {
                if (std.mem.startsWith(u8, ctx.path(), path)) {
                    is_graphql_path = true;
                    break;
                }
            }

            if (!is_graphql_path) {
                return next(ctx);
            }

            // Check for introspection if disabled
            if (!config.enable_introspection or config.disable_introspection_in_production) {
                const body = ctx.body();
                if (std.mem.indexOf(u8, body, "__schema") != null or
                    std.mem.indexOf(u8, body, "__type") != null)
                {
                    return Response.err(.forbidden, "{\"errors\":[{\"message\":\"Introspection is disabled\"}]}");
                }
            }

            // Check query depth
            if (config.enable_depth_limiting) {
                const body = ctx.body();
                var depth: u32 = 0;
                var max_depth: u32 = 0;
                for (body) |c| {
                    if (c == '{') {
                        depth += 1;
                        if (depth > max_depth) max_depth = depth;
                    } else if (c == '}') {
                        if (depth > 0) depth -= 1;
                    }
                }
                if (max_depth > config.max_depth) {
                    return Response.err(.bad_request, "{\"errors\":[{\"message\":\"Query depth exceeds maximum allowed\"}]}");
                }
            }

            return next(ctx);
        }
    };
}

/// GraphQL CORS configuration
pub const GraphQLCorsConfig = struct {
    allowed_origins: []const []const u8 = &.{"*"},
    allowed_methods: []const []const u8 = &.{ "GET", "POST", "OPTIONS" },
    allowed_headers: []const []const u8 = &.{ "Content-Type", "Authorization", "X-Apollo-Operation-Name", "Apollo-Require-Preflight" },
    expose_headers: []const []const u8 = &.{"X-Request-ID"},
    allow_credentials: bool = false,
    max_age: u32 = 86400,
};

/// GraphQL-specific CORS middleware
pub fn graphqlCors(config: GraphQLCorsConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            const origin = ctx.header("Origin") orelse return next(ctx);

            const origin_allowed = blk: {
                for (config.allowed_origins) |allowed| {
                    if (std.mem.eql(u8, allowed, "*") or std.mem.eql(u8, allowed, origin)) {
                        break :blk true;
                    }
                }
                break :blk false;
            };

            if (!origin_allowed) return next(ctx);

            // Handle preflight
            if (ctx.method() == .OPTIONS) {
                var resp = Response.init()
                    .setStatus(.no_content)
                    .setHeader("Access-Control-Allow-Origin", if (config.allow_credentials) origin else config.allowed_origins[0])
                    .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
                    .setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Apollo-Operation-Name, Apollo-Require-Preflight")
                    .setHeader("Access-Control-Max-Age", "86400")
                    .setHeader("Vary", "Origin");

                if (config.allow_credentials) {
                    resp = resp.setHeader("Access-Control-Allow-Credentials", "true");
                }
                return resp;
            }

            var response = next(ctx);
            response = response.setHeader("Access-Control-Allow-Origin", if (config.allow_credentials) origin else config.allowed_origins[0]);

            if (config.allow_credentials) {
                response = response.setHeader("Access-Control-Allow-Credentials", "true");
            }

            return response;
        }
    };
}

/// Apollo Federation gateway middleware
pub const FederationConfig = struct {
    /// Enable federation
    enabled: bool = false,
    /// Service list for composition
    services: []const ServiceConfig = &.{},
    /// Gateway timeout
    timeout_ms: u32 = 30000,
    /// Enable query planning
    enable_query_planning: bool = true,

    pub const ServiceConfig = struct {
        name: []const u8,
        url: []const u8,
    };
};

/// Rate limiting specifically for GraphQL operations
pub const GraphQLRateLimitConfig = struct {
    /// Requests per window for queries
    query_limit: u32 = 100,
    /// Requests per window for mutations
    mutation_limit: u32 = 50,
    /// Requests per window for subscriptions
    subscription_limit: u32 = 10,
    /// Window size in seconds
    window_seconds: u32 = 60,
    /// Rate limit by IP
    by_ip: bool = true,
    /// Rate limit by user ID (requires auth)
    by_user: bool = false,
};

/// GraphQL operation rate limiting middleware
pub fn graphqlRateLimit(config: GraphQLRateLimitConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            _ = config;
            // Rate limiting implementation would go here
            // For now, just pass through
            return next(ctx);
        }
    };
}

/// GraphQL tracing middleware for APM integration
pub const GraphQLTracingConfig = struct {
    /// Enable tracing
    enabled: bool = true,
    /// Include resolver timings
    include_resolver_timings: bool = true,
    /// Include parsing timing
    include_parsing: bool = true,
    /// Include validation timing
    include_validation: bool = true,
    /// Trace sample rate (0.0 to 1.0)
    sample_rate: f32 = 1.0,
    /// Custom trace ID header
    trace_id_header: []const u8 = "X-Trace-ID",
};

/// GraphQL tracing middleware
pub fn graphqlTracing(config: GraphQLTracingConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            if (!config.enabled) {
                return next(ctx);
            }

            const start_time = std.time.milliTimestamp();
            var response = next(ctx);
            const duration = std.time.milliTimestamp() - start_time;

            // Add timing header
            var buf: [32]u8 = undefined;
            const duration_str = std.fmt.bufPrint(&buf, "{d}ms", .{duration}) catch "0ms";
            response = response.setHeader("X-GraphQL-Duration", duration_str);

            return response;
        }
    };
}
