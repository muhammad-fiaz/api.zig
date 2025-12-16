//! Compile-time route registration and runtime request matching.
//! Supports path parameters, sub-routers, and automatic OpenAPI metadata extraction.

const std = @import("std");
const http = @import("http.zig");
const Response = @import("response.zig").Response;
const Request = @import("request.zig").Request;
const Context = @import("context.zig").Context;

/// Route configuration for decorator-style registration.
pub const RouteConfig = struct {
    method: http.Method,
    path: []const u8,
    response_model: ?[]const u8 = null,
    summary: ?[]const u8 = null,
    description: ?[]const u8 = null,
    tags: []const []const u8 = &.{},
    status_code: http.StatusCode = .ok,
    deprecated: bool = false,
};

/// A compiled route entry ready for matching.
pub const Route = struct {
    method: http.Method,
    path: []const u8,
    handler: *const fn (*Context) Response,
    segment_count: usize = 0,
    summary: ?[]const u8 = null,
    description: ?[]const u8 = null,
    tags: []const []const u8 = &.{},
    deprecated: bool = false,
};

/// Router that holds registered routes and performs request matching.
pub const Router = struct {
    allocator: std.mem.Allocator,
    routes: std.ArrayListUnmanaged(Route) = .{},
    not_found_handler: ?*const fn (*Context) Response = null,
    error_handler: ?*const fn (*Context, anyerror) Response = null,

    /// Compile-time route registration.
    pub fn register(
        comptime method: http.Method,
        comptime path: []const u8,
        comptime handler: anytype,
    ) Route {
        const HandlerType = @TypeOf(handler);
        const handler_info = @typeInfo(HandlerType);

        if (handler_info != .@"fn") {
            @compileError("Handler must be a function, got: " ++ @typeName(HandlerType));
        }

        const fn_info = handler_info.@"fn";

        if (fn_info.return_type) |ret_type| {
            const is_response = ret_type == Response;
            const is_error_response = @typeInfo(ret_type) == .error_union and
                @typeInfo(ret_type).error_union.payload == Response;

            if (!is_response and !is_error_response) {
                @compileError("Handler must return Response or !Response, got: " ++ @typeName(ret_type));
            }
        } else {
            @compileError("Handler must have a return type");
        }

        const seg_count = comptime countSegments(path);

        const wrapper = struct {
            fn call(ctx: *Context) Response {
                const params = fn_info.params;
                if (params.len == 0) {
                    return handler();
                } else if (params.len == 1 and params[0].type == *Context) {
                    return handler(ctx);
                } else {
                    return handler(ctx);
                }
            }
        };

        return Route{
            .method = method,
            .path = path,
            .handler = wrapper.call,
            .segment_count = seg_count,
        };
    }

    /// Register a route from configuration.
    pub fn route(comptime config: RouteConfig, comptime handler: anytype) Route {
        var r = register(config.method, config.path, handler);
        r.summary = config.summary;
        r.description = config.description;
        r.tags = config.tags;
        r.deprecated = config.deprecated;
        return r;
    }

    /// Includes routes from another router with path prefix and optional tag overrides.
    pub fn include_router(self: *Router, other: *const Router, prefix: []const u8, tags: []const []const u8) !void {
        for (other.routes.items) |r| {
            const prefixed_path = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ prefix, r.path });
            const merged_tags = if (tags.len > 0) tags else r.tags;

            const new_route = Route{
                .method = r.method,
                .path = prefixed_path,
                .handler = r.handler,
                .segment_count = r.segment_count + countRuntimeSegments(prefix),
                .summary = r.summary,
                .description = r.description,
                .tags = merged_tags,
                .deprecated = r.deprecated,
            };
            try self.routes.append(self.allocator, new_route);
        }
    }

    fn countRuntimeSegments(path: []const u8) usize {
        if (path.len == 0) return 0;
        var count: usize = 0;
        for (path) |c| {
            if (c == '/') count += 1;
        }
        return if (path[path.len - 1] != '/') count else count;
    }

    /// Initialize a new router.
    pub fn init(allocator: std.mem.Allocator) Router {
        return .{ .allocator = allocator, .routes = .{} };
    }

    /// Release router resources.
    pub fn deinit(self: *Router) void {
        self.routes.deinit(self.allocator);
    }

    /// Add a compiled route with duplicate detection.
    pub fn addRoute(self: *Router, r: Route) !void {
        // Check for duplicate routes
        for (self.routes.items) |existing| {
            if (existing.method == r.method and std.mem.eql(u8, existing.path, r.path)) {
                std.debug.print("\n[ERROR] Duplicate route detected: {s} {s}\n", .{ @tagName(r.method), r.path });
                std.debug.print("        Each method+path combination must be unique.\n", .{});
                return error.DuplicateRoute;
            }
        }
        try self.routes.append(self.allocator, r);
    }

    /// Match a request to a registered route.
    pub fn match(self: *const Router, method: http.Method, path: []const u8) ?MatchResult {
        for (self.routes.items) |r| {
            if (r.method != method) continue;
            if (matchPath(r.path, path)) |params| {
                return MatchResult{ .route = r, .params = params };
            }
        }
        return null;
    }

    /// Set custom 404 handler.
    pub fn setNotFound(self: *Router, handler: *const fn (*Context) Response) void {
        self.not_found_handler = handler;
    }

    /// Set custom error handler.
    pub fn setErrorHandler(self: *Router, handler: *const fn (*Context, anyerror) Response) void {
        self.error_handler = handler;
    }
};

/// Match result containing matched route and extracted parameters.
pub const MatchResult = struct {
    route: Route,
    params: ParamList,
};

/// Extracted path parameters.
pub const ParamList = struct {
    items: [8]ParamEntry = undefined,
    len: usize = 0,

    pub fn get(self: *const ParamList, name: []const u8) ?[]const u8 {
        for (self.items[0..self.len]) |entry| {
            if (std.mem.eql(u8, entry.name, name)) {
                return entry.value;
            }
        }
        return null;
    }
};

pub const ParamEntry = struct {
    name: []const u8,
    value: []const u8,
};

fn countSegments(comptime path: []const u8) usize {
    if (path.len == 0) return 0;
    var count: usize = 0;
    var i: usize = 0;
    while (i < path.len) : (i += 1) {
        if (path[i] == '/') count += 1;
    }
    return if (path[path.len - 1] != '/') count + 1 else count;
}

/// Matches a route pattern against a request path, extracting parameters.
pub fn matchPath(pattern: []const u8, path: []const u8) ?ParamList {
    var params = ParamList{};

    var pattern_iter = std.mem.splitScalar(u8, pattern, '/');
    var path_iter = std.mem.splitScalar(u8, path, '/');

    while (true) {
        const pattern_seg = pattern_iter.next();
        const path_seg = path_iter.next();

        if (pattern_seg == null and path_seg == null) return params;
        if (pattern_seg == null or path_seg == null) return null;

        const ps = pattern_seg.?;
        const rs = path_seg.?;

        if (ps.len == 0 and rs.len == 0) continue;
        if (ps.len == 0 or rs.len == 0) {
            if (ps.len == 0 and rs.len == 0) continue;
            return null;
        }

        if (ps.len > 2 and ps[0] == '{' and ps[ps.len - 1] == '}') {
            const param_name = ps[1 .. ps.len - 1];
            if (params.len < 8) {
                params.items[params.len] = .{ .name = param_name, .value = rs };
                params.len += 1;
            }
        } else if (!std.mem.eql(u8, ps, rs)) {
            return null;
        }
    }
}

/// Extracted path parameters result.
pub const PathParams = struct {
    items: [8][]const u8 = undefined,
    len: usize = 0,
};

/// Extracts path parameters from a route pattern.
pub fn extractPathParams(comptime path: []const u8) PathParams {
    var result = PathParams{};
    var i: usize = 0;
    while (i < path.len) {
        if (path[i] == '{') {
            const start = i + 1;
            while (i < path.len and path[i] != '}') : (i += 1) {}
            if (result.len < 8) {
                result.items[result.len] = path[start..i];
                result.len += 1;
            }
        }
        i += 1;
    }
    return result;
}

test "count segments" {
    try std.testing.expectEqual(@as(usize, 1), countSegments("/"));
    try std.testing.expectEqual(@as(usize, 2), countSegments("/users"));
    try std.testing.expectEqual(@as(usize, 3), countSegments("/users/123"));
}

test "match exact path" {
    const result = matchPath("/users", "/users");
    try std.testing.expect(result != null);
}

test "match with parameter" {
    const result = matchPath("/users/{id}", "/users/123");
    try std.testing.expect(result != null);
    try std.testing.expectEqualStrings("123", result.?.get("id").?);
}

test "no match" {
    const result = matchPath("/users", "/posts");
    try std.testing.expectEqual(null, result);
}

test "extract path params" {
    const params = comptime extractPathParams("/users/{id}/posts/{post_id}");
    try std.testing.expectEqual(@as(usize, 2), params.len);
    try std.testing.expectEqualStrings("id", params.items[0]);
    try std.testing.expectEqualStrings("post_id", params.items[1]);
}

test "router initialization" {
    const allocator = std.testing.allocator;
    var router_instance = Router.init(allocator);
    defer router_instance.deinit();
    try std.testing.expectEqual(@as(usize, 0), router_instance.routes.items.len);
}
