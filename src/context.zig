//! Request context for handlers.
//! Access to params, query, headers, body, and request-scoped state.

const std = @import("std");
const Request = @import("request.zig").Request;
const Response = @import("response.zig").Response;
const http = @import("http.zig");
const Logger = @import("logger.zig").Logger;

/// Request context passed to route handlers.
pub const Context = struct {
    request: *Request,
    allocator: std.mem.Allocator,
    logger: *Logger,
    params: std.StringHashMap([]const u8),
    state: std.StringHashMap(*anyopaque),
    response_headers: Response.HeaderList = .{},

    /// Creates a new context for a request.
    pub fn init(allocator: std.mem.Allocator, request: *Request, logger: *Logger) Context {
        return .{
            .request = request,
            .allocator = allocator,
            .logger = logger,
            .params = std.StringHashMap([]const u8).init(allocator),
            .state = std.StringHashMap(*anyopaque).init(allocator),
        };
    }

    /// Releases context resources.
    pub fn deinit(self: *Context) void {
        self.params.deinit();
        self.state.deinit();
    }

    /// Returns the HTTP method of the request.
    pub fn method(self: *const Context) http.Method {
        return self.request.method;
    }

    /// Returns the request path.
    pub fn path(self: *const Context) []const u8 {
        return self.request.path;
    }

    /// Returns the request body.
    pub fn body(self: *const Context) []const u8 {
        return self.request.body;
    }

    /// Returns a path parameter by name.
    pub fn param(self: *const Context, name: []const u8) ?[]const u8 {
        return self.params.get(name);
    }

    /// Returns a path parameter parsed as the specified type.
    pub fn paramAs(self: *const Context, comptime T: type, name: []const u8) !T {
        const value = self.param(name) orelse return error.ParamNotFound;
        return parseValue(T, value);
    }

    /// Returns a query parameter by name.
    pub fn query(self: *const Context, name: []const u8) ?[]const u8 {
        return self.request.queryParam(name);
    }

    /// Returns a query parameter or default value.
    pub fn queryOr(self: *const Context, name: []const u8, default: []const u8) []const u8 {
        return self.query(name) orelse default;
    }

    /// Returns a query parameter parsed as the specified type.
    pub fn queryAs(self: *const Context, comptime T: type, name: []const u8) !T {
        const value = self.query(name) orelse return error.QueryNotFound;
        return parseValue(T, value);
    }

    /// Returns a query parameter parsed or default value.
    pub fn queryAsOr(self: *const Context, comptime T: type, name: []const u8, default: T) T {
        return self.queryAs(T, name) catch default;
    }

    /// Returns a request header by name.
    pub fn header(self: *const Context, name: []const u8) ?[]const u8 {
        return self.request.header(name);
    }

    /// Parses the request body as JSON into the specified type.
    pub fn bodyJson(self: *const Context, comptime T: type) !T {
        const json_mod = @import("json.zig");
        return json_mod.parse(T, self.allocator, self.body());
    }

    /// Sets a response header.
    pub fn setHeader(self: *Context, name: []const u8, value: []const u8) void {
        self.response_headers.set(name, value);
    }

    /// Stores a value in context state.
    pub fn set(self: *Context, key: []const u8, value: *anyopaque) void {
        self.state.put(key, value) catch {};
    }

    /// Retrieves a value from context state.
    pub fn get(self: *const Context, comptime T: type, key: []const u8) ?*T {
        const ptr = self.state.get(key) orelse return null;
        return @ptrCast(@alignCast(ptr));
    }
};

fn parseValue(comptime T: type, value: []const u8) !T {
    const type_info = @typeInfo(T);

    switch (type_info) {
        .int => return std.fmt.parseInt(T, value, 10) catch error.ParseError,
        .float => return std.fmt.parseFloat(T, value) catch error.ParseError,
        .bool => {
            if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1")) return true;
            if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0")) return false;
            return error.ParseError;
        },
        .pointer => |p| {
            if (p.size == .slice and p.child == u8) {
                return value;
            }
            return error.UnsupportedType;
        },
        .optional => |opt| {
            if (value.len == 0) return null;
            return try parseValue(opt.child, value);
        },
        else => return error.UnsupportedType,
    }
}

test "parse integer" {
    const value = try parseValue(u32, "123");
    try std.testing.expectEqual(@as(u32, 123), value);
}

test "parse boolean" {
    try std.testing.expect(try parseValue(bool, "true"));
    try std.testing.expect(!(try parseValue(bool, "false")));
}

test "parse float" {
    const value = try parseValue(f32, "3.14");
    try std.testing.expect(value > 3.13 and value < 3.15);
}

test "parse string" {
    const value = try parseValue([]const u8, "hello");
    try std.testing.expectEqualStrings("hello", value);
}
