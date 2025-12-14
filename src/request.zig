//! HTTP request parser.
//! Parses request line, headers, query params, and body.

const std = @import("std");
const http = @import("http.zig");
const json = @import("json.zig");

/// HTTP Request
pub const Request = struct {
    /// HTTP method
    method: http.Method,
    /// Request path (without query string)
    path: []const u8,
    /// Raw query string
    query_string: []const u8,
    /// HTTP version
    version: []const u8,
    /// Request headers
    headers: Headers,
    /// Request body
    body: []const u8,
    /// Parsed path parameters (populated by router)
    path_params: std.StringHashMap([]const u8),
    /// Parsed query parameters (lazy)
    query_params: ?std.StringHashMap(std.ArrayListUnmanaged([]const u8)),
    /// Allocator for dynamic allocations
    allocator: std.mem.Allocator,

    pub const Headers = struct {
        raw: []const u8,
        allocator: std.mem.Allocator,
        parsed: ?std.StringHashMap([]const u8) = null,

        pub fn get(self: *Headers, name: []const u8) ?[]const u8 {
            if (self.parsed) |p| {
                // Case-insensitive header lookup
                var it = p.iterator();
                while (it.next()) |entry| {
                    if (std.ascii.eqlIgnoreCase(entry.key_ptr.*, name)) {
                        return entry.value_ptr.*;
                    }
                }
                return null;
            }
            // Lazy parse
            self.parse();
            return self.get(name);
        }

        fn parse(self: *Headers) void {
            var map = std.StringHashMap([]const u8).init(self.allocator);
            var lines = std.mem.splitSequence(u8, self.raw, "\r\n");
            while (lines.next()) |line| {
                if (std.mem.indexOf(u8, line, ": ")) |idx| {
                    const key = line[0..idx];
                    const value = line[idx + 2 ..];
                    map.put(key, value) catch {};
                }
            }
            self.parsed = map;
        }

        pub fn deinit(self: *Headers) void {
            if (self.parsed) |*p| {
                p.deinit();
            }
        }
    };

    /// Parse raw HTTP request
    pub fn parse(allocator: std.mem.Allocator, raw: []const u8) !Request {
        // Find end of request line
        const request_line_end = std.mem.indexOf(u8, raw, "\r\n") orelse return error.InvalidRequest;
        const request_line = raw[0..request_line_end];

        // Parse request line: METHOD PATH VERSION
        var parts = std.mem.splitScalar(u8, request_line, ' ');

        const method_str = parts.next() orelse return error.InvalidRequest;
        const method = http.Method.fromString(method_str) orelse return error.InvalidMethod;

        const full_path = parts.next() orelse return error.InvalidRequest;
        const version = parts.next() orelse return error.InvalidRequest;

        // Split path and query string
        var path: []const u8 = full_path;
        var query_string: []const u8 = "";
        if (std.mem.indexOf(u8, full_path, "?")) |idx| {
            path = full_path[0..idx];
            query_string = full_path[idx + 1 ..];
        }

        // Find headers section
        const headers_start = request_line_end + 2;
        const headers_end = std.mem.indexOf(u8, raw[headers_start..], "\r\n\r\n") orelse raw.len - headers_start;
        const headers_raw = raw[headers_start .. headers_start + headers_end];

        // Find body
        const body_start = headers_start + headers_end + 4;
        const body = if (body_start < raw.len) raw[body_start..] else "";

        return Request{
            .method = method,
            .path = path,
            .query_string = query_string,
            .version = version,
            .headers = .{
                .raw = headers_raw,
                .allocator = allocator,
            },
            .body = body,
            .path_params = std.StringHashMap([]const u8).init(allocator),
            .query_params = null,
            .allocator = allocator,
        };
    }

    /// Get a path parameter by name
    pub fn pathParam(self: *const Request, name: []const u8) ?[]const u8 {
        return self.path_params.get(name);
    }

    /// Get a path parameter and parse it to a specific type
    pub fn pathParamAs(self: *const Request, comptime T: type, name: []const u8) !T {
        const value = self.pathParam(name) orelse return error.ParamNotFound;
        return parseValue(T, value);
    }

    /// Get a query parameter by name
    pub fn queryParam(self: *Request, name: []const u8) ?[]const u8 {
        if (self.query_params == null) {
            self.parseQueryParams();
        }
        if (self.query_params) |params| {
            if (params.get(name)) |list| {
                if (list.items.len > 0) return list.items[0];
            }
        }
        return null;
    }

    /// Get a query parameter and parse it to a specific type
    pub fn queryParamAs(self: *Request, comptime T: type, name: []const u8) !T {
        const value = self.queryParam(name) orelse return error.ParamNotFound;
        return parseValue(T, value);
    }

    /// Get all query parameters with the same name
    pub fn queryParamAll(self: *Request, name: []const u8) []const []const u8 {
        if (self.query_params == null) {
            self.parseQueryParams();
        }
        if (self.query_params) |params| {
            if (params.get(name)) |list| {
                return list.items;
            }
        }
        return &.{};
    }

    /// Parse query string into map
    fn parseQueryParams(self: *Request) void {
        var map = std.StringHashMap(std.ArrayListUnmanaged([]const u8)).init(self.allocator);

        if (self.query_string.len == 0) {
            self.query_params = map;
            return;
        }

        var pairs = std.mem.splitScalar(u8, self.query_string, '&');
        while (pairs.next()) |pair| {
            var key: []const u8 = undefined;
            var value: []const u8 = undefined;

            if (std.mem.indexOf(u8, pair, "=")) |idx| {
                key = pair[0..idx];
                value = pair[idx + 1 ..];
            } else {
                // Key without value
                key = pair;
                value = "";
            }

            const gop = map.getOrPut(key) catch continue;
            if (!gop.found_existing) {
                gop.value_ptr.* = std.ArrayListUnmanaged([]const u8){};
            }
            gop.value_ptr.append(self.allocator, value) catch {};
        }

        self.query_params = map;
    }

    /// Get a header value
    pub fn header(self: *Request, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }

    /// Get Content-Type header
    pub fn contentType(self: *Request) ?[]const u8 {
        return self.header("Content-Type");
    }

    /// Get Content-Length header
    pub fn contentLength(self: *Request) ?usize {
        const value = self.header("Content-Length") orelse return null;
        return std.fmt.parseInt(usize, value, 10) catch null;
    }

    /// Parse body as JSON
    pub fn jsonBody(self: *const Request, comptime T: type) !T {
        return json.parse(T, self.allocator, self.body);
    }

    /// Check if request accepts a content type
    pub fn accepts(self: *Request, content_type: []const u8) bool {
        const accept = self.header("Accept") orelse return true;
        return std.mem.indexOf(u8, accept, content_type) != null or
            std.mem.indexOf(u8, accept, "*/*") != null;
    }

    /// Check if request is JSON
    pub fn isJson(self: *Request) bool {
        const ct = self.contentType() orelse return false;
        return std.mem.indexOf(u8, ct, "application/json") != null;
    }

    /// Check if request is form data
    pub fn isForm(self: *Request) bool {
        const ct = self.contentType() orelse return false;
        return std.mem.indexOf(u8, ct, "application/x-www-form-urlencoded") != null;
    }

    /// Clean up resources
    pub fn deinit(self: *Request) void {
        self.path_params.deinit();
        if (self.query_params) |*p| {
            var it = p.valueIterator();
            while (it.next()) |list| {
                list.deinit(self.allocator);
            }
            p.deinit();
        }
        self.headers.deinit();
    }
};

/// Parse a string value to a specific type
fn parseValue(comptime T: type, value: []const u8) !T {
    const info = @typeInfo(T);
    return switch (info) {
        .int => std.fmt.parseInt(T, value, 10) catch error.InvalidValue,
        .float => std.fmt.parseFloat(T, value) catch error.InvalidValue,
        .bool => if (std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1"))
            true
        else if (std.mem.eql(u8, value, "false") or std.mem.eql(u8, value, "0"))
            false
        else
            error.InvalidValue,
        .pointer => |p| if (p.size == .slice and p.child == u8) value else @compileError("Unsupported type"),
        else => @compileError("Unsupported type for parsing: " ++ @typeName(T)),
    };
}

test "Request.parse" {
    const allocator = std.testing.allocator;
    const raw =
        "GET /users/123?name=alice HTTP/1.1\r\n" ++
        "Host: localhost\r\n" ++
        "Content-Type: application/json\r\n" ++
        "\r\n" ++
        "{\"hello\":\"world\"}";

    var req = try Request.parse(allocator, raw);
    defer req.deinit();

    try std.testing.expectEqual(http.Method.GET, req.method);
    try std.testing.expectEqualStrings("/users/123", req.path);
    try std.testing.expectEqualStrings("name=alice", req.query_string);
    try std.testing.expectEqualStrings("HTTP/1.1", req.version);
    try std.testing.expectEqualStrings("{\"hello\":\"world\"}", req.body);
}

test "Request.queryParam" {
    const allocator = std.testing.allocator;
    const raw = "GET /search?q=hello&limit=10 HTTP/1.1\r\n\r\n";

    var req = try Request.parse(allocator, raw);
    defer req.deinit();

    try std.testing.expectEqualStrings("hello", req.queryParam("q").?);
    try std.testing.expectEqualStrings("10", req.queryParam("limit").?);
    try std.testing.expectEqual(null, req.queryParam("missing"));
}

test "Request.queryParamAs" {
    const allocator = std.testing.allocator;
    const raw = "GET /items?page=5&limit=20 HTTP/1.1\r\n\r\n";

    var req = try Request.parse(allocator, raw);
    defer req.deinit();

    try std.testing.expectEqual(@as(u32, 5), try req.queryParamAs(u32, "page"));
    try std.testing.expectEqual(@as(u32, 20), try req.queryParamAs(u32, "limit"));
}

test "parseValue" {
    try std.testing.expectEqual(@as(i32, 42), try parseValue(i32, "42"));
    try std.testing.expectEqual(@as(f64, 3.14), try parseValue(f64, "3.14"));
    try std.testing.expectEqual(true, try parseValue(bool, "true"));
    try std.testing.expectEqual(false, try parseValue(bool, "0"));
}
