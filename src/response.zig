//! HTTP response builder.
//! Fluent API for JSON, HTML, text, redirects, and custom headers.

const std = @import("std");
const http = @import("http.zig");
const json_mod = @import("json.zig");

/// HTTP response with fluent builder pattern support.
pub const Response = struct {
    status: http.StatusCode = .ok,
    headers: HeaderList = .{},
    body: []const u8 = "",
    owned_body: ?[]u8 = null,
    content_type: []const u8 = http.Headers.ContentTypes.plain,

    pub const HeaderList = struct {
        items: [16]HeaderEntry = undefined,
        len: usize = 0,

        pub fn set(self: *HeaderList, name: []const u8, value: []const u8) void {
            if (self.len < 16) {
                self.items[self.len] = .{ .name = name, .value = value };
                self.len += 1;
            }
        }

        pub fn get(self: *const HeaderList, name: []const u8) ?[]const u8 {
            for (self.items[0..self.len]) |entry| {
                if (std.ascii.eqlIgnoreCase(entry.name, name)) {
                    return entry.value;
                }
            }
            return null;
        }
    };

    pub const HeaderEntry = struct {
        name: []const u8,
        value: []const u8,
    };

    /// Creates an empty response.
    pub fn init() Response {
        return .{};
    }

    /// Creates a JSON response from a serializable value.
    pub fn jsonFromValue(allocator: std.mem.Allocator, value: anytype) !Response {
        const json_body = try json_mod.stringify(allocator, value, .{});
        return Response{
            .status = .ok,
            .body = json_body,
            .owned_body = json_body,
            .content_type = http.Headers.ContentTypes.json,
        };
    }

    /// Creates a JSON response placeholder.
    pub fn json(value: anytype) Response {
        _ = value;
        return Response{
            .status = .ok,
            .body = "{}",
            .content_type = http.Headers.ContentTypes.json,
        };
    }

    /// Creates a JSON response from a raw JSON string.
    pub fn jsonRaw(body_content: []const u8) Response {
        return Response{
            .status = .ok,
            .body = body_content,
            .content_type = http.Headers.ContentTypes.json,
        };
    }

    /// Creates a plain text response.
    pub fn text(content: []const u8) Response {
        return Response{
            .status = .ok,
            .body = content,
            .content_type = http.Headers.ContentTypes.plain,
        };
    }

    /// Creates a successful response with the given body (defaults to text/plain).
    pub fn ok(content: []const u8) Response {
        return text(content);
    }

    /// Creates an HTML response.
    pub fn html(content: []const u8) Response {
        return Response{
            .status = .ok,
            .body = content,
            .content_type = http.Headers.ContentTypes.html,
        };
    }

    /// Creates an error response with JSON body.
    pub fn err(error_status: http.StatusCode, message: []const u8) Response {
        return Response{
            .status = error_status,
            .body = message,
            .content_type = http.Headers.ContentTypes.json,
        };
    }

    /// Creates a redirect response (302 Found).
    pub fn redirect(location: []const u8) Response {
        var resp = Response{ .status = .found, .body = "" };
        resp.headers.set("Location", location);
        return resp;
    }

    /// Creates a permanent redirect response (301 Moved Permanently).
    pub fn permanentRedirect(location: []const u8) Response {
        var resp = Response{ .status = .moved_permanently, .body = "" };
        resp.headers.set("Location", location);
        return resp;
    }

    /// Creates a file download response.
    pub fn file(content: []const u8, filename: []const u8, mime_type: []const u8) Response {
        _ = filename;
        return Response{
            .status = .ok,
            .body = content,
            .content_type = mime_type,
        };
    }

    /// Sets the response status code.
    pub fn setStatus(self: Response, new_status: http.StatusCode) Response {
        var resp = self;
        resp.status = new_status;
        return resp;
    }

    /// Adds a header to the response.
    pub fn setHeader(self: Response, name: []const u8, value: []const u8) Response {
        var resp = self;
        resp.headers.set(name, value);
        return resp;
    }

    /// Sets the content type.
    pub fn setContentType(self: Response, content_type_value: []const u8) Response {
        var resp = self;
        resp.content_type = content_type_value;
        return resp;
    }

    /// Sets the response body.
    pub fn setBody(self: Response, body_content: []const u8) Response {
        var resp = self;
        resp.body = body_content;
        return resp;
    }

    /// Adds CORS headers for cross-origin requests.
    pub fn withCors(self: Response, origin: []const u8) Response {
        var resp = self;
        resp.headers.set("Access-Control-Allow-Origin", origin);
        resp.headers.set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS, PATCH");
        resp.headers.set("Access-Control-Allow-Headers", "Content-Type, Authorization");
        return resp;
    }

    /// Adds cache control headers.
    pub fn withCache(self: Response, max_age: u32) Response {
        _ = max_age;
        var resp = self;
        resp.headers.set("Cache-Control", "public, max-age=3600");
        return resp;
    }

    /// Adds no-cache headers.
    pub fn withNoCache(self: Response) Response {
        var resp = self;
        resp.headers.set("Cache-Control", "no-store, no-cache, must-revalidate");
        resp.headers.set("Pragma", "no-cache");
        return resp;
    }

    /// Formats the response as an HTTP/1.1 message.
    pub fn format(self: *const Response, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayListUnmanaged(u8){};
        errdefer list.deinit(allocator);

        var status_buf: [16]u8 = undefined;
        const status_str = std.fmt.bufPrint(&status_buf, "{d}", .{self.status.toInt()}) catch "200";
        try list.appendSlice(allocator, "HTTP/1.1 ");
        try list.appendSlice(allocator, status_str);
        try list.appendSlice(allocator, " ");
        try list.appendSlice(allocator, self.status.phrase());
        try list.appendSlice(allocator, "\r\n");

        try list.appendSlice(allocator, "Content-Type: ");
        try list.appendSlice(allocator, self.content_type);
        try list.appendSlice(allocator, "\r\n");

        var len_buf: [16]u8 = undefined;
        const len_str = std.fmt.bufPrint(&len_buf, "{d}", .{self.body.len}) catch "0";
        try list.appendSlice(allocator, "Content-Length: ");
        try list.appendSlice(allocator, len_str);
        try list.appendSlice(allocator, "\r\n");

        for (self.headers.items[0..self.headers.len]) |header_entry| {
            try list.appendSlice(allocator, header_entry.name);
            try list.appendSlice(allocator, ": ");
            try list.appendSlice(allocator, header_entry.value);
            try list.appendSlice(allocator, "\r\n");
        }

        try list.appendSlice(allocator, "\r\n");
        try list.appendSlice(allocator, self.body);

        return list.toOwnedSlice(allocator);
    }

    /// Releases allocated body memory.
    pub fn deinit(self: *Response, allocator: std.mem.Allocator) void {
        if (self.owned_body) |b| {
            allocator.free(b);
            self.owned_body = null;
        }
    }
};

pub fn ok(body_content: []const u8) Response {
    return Response.text(body_content);
}

pub fn created(body_content: []const u8) Response {
    return Response.text(body_content).setStatus(.created);
}

pub fn noContent() Response {
    return Response.init().setStatus(.no_content);
}

pub fn badRequest(message: []const u8) Response {
    return Response.err(.bad_request, message);
}

pub fn unauthorized(message: []const u8) Response {
    return Response.err(.unauthorized, message);
}

pub fn forbidden(message: []const u8) Response {
    return Response.err(.forbidden, message);
}

pub fn notFound(message: []const u8) Response {
    return Response.err(.not_found, message);
}

pub fn internalError(message: []const u8) Response {
    return Response.err(.internal_server_error, message);
}

test "text response" {
    const resp = Response.text("Hello, World!");
    try std.testing.expectEqual(http.StatusCode.ok, resp.status);
    try std.testing.expectEqualStrings("Hello, World!", resp.body);
}

test "html response" {
    const resp = Response.html("<h1>Hello</h1>");
    try std.testing.expectEqual(http.StatusCode.ok, resp.status);
    try std.testing.expectEqualStrings(http.Headers.ContentTypes.html, resp.content_type);
}

test "json response" {
    const resp = Response.json(.{ .message = "hello" });
    try std.testing.expectEqual(http.StatusCode.ok, resp.status);
    try std.testing.expectEqualStrings(http.Headers.ContentTypes.json, resp.content_type);
}

test "status modification" {
    const resp = Response.text("Created").setStatus(.created);
    try std.testing.expectEqual(http.StatusCode.created, resp.status);
}

test "redirect response" {
    const resp = Response.redirect("/new-location");
    try std.testing.expectEqual(http.StatusCode.found, resp.status);
    try std.testing.expectEqualStrings("/new-location", resp.headers.get("Location").?);
}

test "cors headers" {
    const resp = Response.text("test").withCors("*");
    try std.testing.expectEqualStrings("*", resp.headers.get("Access-Control-Allow-Origin").?);
}

test "response format" {
    const allocator = std.testing.allocator;
    const resp = Response.text("Hello");
    const formatted = try resp.format(allocator);
    defer allocator.free(formatted);
    try std.testing.expect(std.mem.indexOf(u8, formatted, "HTTP/1.1 200 OK") != null);
}

test "helper functions" {
    try std.testing.expectEqual(http.StatusCode.ok, ok("test").status);
    try std.testing.expectEqual(http.StatusCode.created, created("test").status);
    try std.testing.expectEqual(http.StatusCode.no_content, noContent().status);
}
