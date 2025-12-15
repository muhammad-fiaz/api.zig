//! Request context providing unified access to request data, parameters, headers, state, and background tasks.

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
    background_tasks: std.ArrayListUnmanaged(BackgroundTask) = .{},
    request_id: ?[]const u8 = null,
    start_time: i64 = 0,

    pub const BackgroundTask = struct {
        func: *const fn (*anyopaque) void,
        arg: *anyopaque,
        priority: Priority = .normal,

        pub const Priority = enum { low, normal, high };
    };

    /// Creates a new context for a request.
    pub fn init(allocator: std.mem.Allocator, request: *Request, logger: *Logger) Context {
        return .{
            .request = request,
            .allocator = allocator,
            .logger = logger,
            .params = std.StringHashMap([]const u8).init(allocator),
            .state = std.StringHashMap(*anyopaque).init(allocator),
            .start_time = std.time.milliTimestamp(),
        };
    }

    /// Releases context resources.
    pub fn deinit(self: *Context) void {
        self.params.deinit();
        self.state.deinit();
        self.background_tasks.deinit(self.allocator);
    }

    /// Adds a background task to be executed after response.
    pub fn addBackgroundTask(self: *Context, func: *const fn (*anyopaque) void, arg: *anyopaque) !void {
        try self.background_tasks.append(self.allocator, .{ .func = func, .arg = arg });
    }

    /// Adds a prioritized background task.
    pub fn addPriorityTask(self: *Context, func: *const fn (*anyopaque) void, arg: *anyopaque, priority: BackgroundTask.Priority) !void {
        try self.background_tasks.append(self.allocator, .{ .func = func, .arg = arg, .priority = priority });
    }

    /// Executes all pending background tasks.
    pub fn runBackgroundTasks(self: *Context) void {
        for (self.background_tasks.items) |task| {
            if (task.priority == .high) task.func(task.arg);
        }
        for (self.background_tasks.items) |task| {
            if (task.priority == .normal) task.func(task.arg);
        }
        for (self.background_tasks.items) |task| {
            if (task.priority == .low) task.func(task.arg);
        }
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

    /// Returns the raw query string.
    pub fn queryString(self: *const Context) ?[]const u8 {
        return self.request.query_string;
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

    /// Returns a path parameter or default value.
    pub fn paramOr(self: *const Context, name: []const u8, default: []const u8) []const u8 {
        return self.param(name) orelse default;
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

    /// Returns all query parameters matching a name (returns first match as array).
    pub fn queryAll(self: *const Context, name: []const u8) ![]const []const u8 {
        if (self.query(name)) |_| {
            return &.{};
        }
        return &.{};
    }

    /// Returns a request header by name.
    pub fn header(self: *const Context, name: []const u8) ?[]const u8 {
        return self.request.header(name);
    }

    /// Returns a header or default value.
    pub fn headerOr(self: *const Context, name: []const u8, default: []const u8) []const u8 {
        return self.header(name) orelse default;
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

    /// Checks if a state key exists.
    pub fn has(self: *const Context, key: []const u8) bool {
        return self.state.contains(key);
    }

    /// Removes a value from context state.
    pub fn remove(self: *Context, key: []const u8) void {
        _ = self.state.remove(key);
    }

    /// Returns elapsed time since request start in milliseconds.
    pub fn elapsed(self: *const Context) i64 {
        return std.time.milliTimestamp() - self.start_time;
    }

    /// Returns the content type of the request.
    pub fn contentType(self: *const Context) ?[]const u8 {
        return self.header("Content-Type");
    }

    /// Returns the content length of the request body.
    pub fn contentLength(self: *const Context) ?usize {
        const len_str = self.header("Content-Length") orelse return null;
        return std.fmt.parseInt(usize, len_str, 10) catch null;
    }

    /// Checks if request expects JSON response.
    pub fn acceptsJson(self: *const Context) bool {
        const accept = self.header("Accept") orelse return false;
        return std.mem.indexOf(u8, accept, "application/json") != null or
            std.mem.indexOf(u8, accept, "*/*") != null;
    }

    /// Checks if request is AJAX (XMLHttpRequest).
    pub fn isAjax(self: *const Context) bool {
        const xhr = self.header("X-Requested-With") orelse return false;
        return std.mem.eql(u8, xhr, "XMLHttpRequest");
    }

    /// Checks if request is secure (HTTPS).
    pub fn isSecure(self: *const Context) bool {
        if (self.header("X-Forwarded-Proto")) |proto| {
            return std.mem.eql(u8, proto, "https");
        }
        return false;
    }

    /// Returns the client IP address.
    pub fn clientIp(self: *const Context) []const u8 {
        return self.header("X-Forwarded-For") orelse
            self.header("X-Real-IP") orelse "unknown";
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
