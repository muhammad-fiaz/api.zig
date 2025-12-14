//! HTTP middleware components.
//! Logger, CORS, recovery, request ID, and custom middleware support.

const std = @import("std");
const Context = @import("context.zig").Context;
const Response = @import("response.zig").Response;
const http = @import("http.zig");
const Logger = @import("logger.zig").Logger;

// Type definitions to break circular dependency with app.zig if needed
const HandlerFn = *const fn (*Context) Response;

/// Logger middleware.
/// Logs request method, path, timing, and response status.
pub fn logger(ctx: *Context, next: HandlerFn) Response {
    const start = std.time.milliTimestamp();
    const method = ctx.method().toString();
    const path = ctx.path();

    ctx.logger.infof("[REQ] {s} {s}", .{ method, path }, null) catch {};

    const response = next(ctx);

    const end = std.time.milliTimestamp();
    const duration = end - start;
    const status = response.status.toInt();

    ctx.logger.infof("[RES] {d} ({d}ms)", .{ status, duration }, null) catch {};

    return response;
}

/// CORS configuration.
pub const CorsConfig = struct {
    allowed_origins: []const []const u8 = &.{"*"},
    allowed_methods: []const []const u8 = &.{ "GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS" },
    allowed_headers: []const []const u8 = &.{ "Content-Type", "Authorization" },
    allow_credentials: bool = false,
    max_age: u32 = 86400,
};

/// CORS Middleware generator.
pub fn cors(config: CorsConfig) type {
    return struct {
        pub fn handle(ctx: *Context, next: HandlerFn) Response {
            // Handle preflight
            if (ctx.method() == .OPTIONS) {
                return Response.init()
                    .setStatus(.no_content)
                    .setHeader("Access-Control-Allow-Origin", config.allowed_origins[0])
                    .setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, PATCH, OPTIONS")
                    .setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")
                    .setHeader("Access-Control-Max-Age", "86400");
            }

            var response = next(ctx);
            response = response.setHeader("Access-Control-Allow-Origin", config.allowed_origins[0]);

            return response;
        }
    };
}

/// Recovery middleware.
pub fn recover(ctx: *Context, next: HandlerFn) Response {
    return next(ctx);
}

var request_id_counter = std.atomic.Value(u64).init(1);

/// Request ID middleware.
pub fn requestId(ctx: *Context, next: HandlerFn) Response {
    const id = request_id_counter.fetchAdd(1, .monotonic);
    var buf: [32]u8 = undefined;
    const id_str = std.fmt.bufPrint(&buf, "req-{d}", .{id}) catch "unknown";

    var response = next(ctx);
    const heap_id = ctx.allocator.dupe(u8, id_str) catch "unknown";

    return response.setHeader("X-Request-ID", heap_id);
}

test "cors middleware" {
    const allocator = std.testing.allocator;
    const Request = @import("request.zig").Request;

    // Mock request
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
    // Free the heap-allocated request ID header value
    if (request_id_header) |id| {
        allocator.free(id);
    }
}
