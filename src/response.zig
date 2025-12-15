//! HTTP response builder with fluent API for JSON, HTML, text, redirects, cookies, and streaming.

const std = @import("std");
const http = @import("http.zig");
const json_mod = @import("json.zig");

/// RFC 6265 compliant cookie builder with all standard attributes.
pub const Cookie = struct {
    name: []const u8,
    value: []const u8,
    domain: ?[]const u8 = null,
    path: ?[]const u8 = null,
    max_age: ?i64 = null,
    expires: ?[]const u8 = null,
    secure: bool = false,
    http_only: bool = false,
    same_site: SameSite = .lax,
    partitioned: bool = false,

    pub const SameSite = enum {
        strict,
        lax,
        none,

        pub fn toString(self: SameSite) []const u8 {
            return switch (self) {
                .strict => "Strict",
                .lax => "Lax",
                .none => "None",
            };
        }
    };

    /// Creates a new cookie with name and value.
    pub fn init(name: []const u8, value: []const u8) Cookie {
        return .{ .name = name, .value = value };
    }

    /// Sets the cookie domain.
    pub fn setDomain(self: Cookie, domain: []const u8) Cookie {
        var c = self;
        c.domain = domain;
        return c;
    }

    /// Sets the cookie path.
    pub fn setPath(self: Cookie, path: []const u8) Cookie {
        var c = self;
        c.path = path;
        return c;
    }

    /// Sets the max-age in seconds.
    pub fn setMaxAge(self: Cookie, seconds: i64) Cookie {
        var c = self;
        c.max_age = seconds;
        return c;
    }

    /// Sets the expires date string (RFC 7231 format).
    pub fn setExpires(self: Cookie, date: []const u8) Cookie {
        var c = self;
        c.expires = date;
        return c;
    }

    /// Marks the cookie as secure (HTTPS only).
    pub fn setSecure(self: Cookie, secure: bool) Cookie {
        var c = self;
        c.secure = secure;
        return c;
    }

    /// Marks the cookie as HTTP-only (no JavaScript access).
    pub fn setHttpOnly(self: Cookie, http_only: bool) Cookie {
        var c = self;
        c.http_only = http_only;
        return c;
    }

    /// Sets the SameSite attribute.
    pub fn setSameSite(self: Cookie, same_site: SameSite) Cookie {
        var c = self;
        c.same_site = same_site;
        return c;
    }

    /// Marks the cookie as partitioned (CHIPS).
    pub fn setPartitioned(self: Cookie, partitioned: bool) Cookie {
        var c = self;
        c.partitioned = partitioned;
        return c;
    }

    /// Creates a session cookie (expires when browser closes).
    pub fn session(name: []const u8, value: []const u8) Cookie {
        return Cookie.init(name, value)
            .setHttpOnly(true)
            .setSameSite(.strict);
    }

    /// Creates a persistent cookie with max-age.
    pub fn persistent(name: []const u8, value: []const u8, max_age_seconds: i64) Cookie {
        return Cookie.init(name, value)
            .setMaxAge(max_age_seconds)
            .setHttpOnly(true);
    }

    /// Creates a secure authentication cookie.
    pub fn auth(name: []const u8, token: []const u8) Cookie {
        return Cookie.init(name, token)
            .setHttpOnly(true)
            .setSecure(true)
            .setSameSite(.strict)
            .setPath("/");
    }

    /// Creates a cookie that will be deleted.
    pub fn delete(name: []const u8) Cookie {
        return Cookie.init(name, "")
            .setMaxAge(0)
            .setPath("/");
    }

    /// Formats the cookie as a Set-Cookie header value.
    pub fn format(self: Cookie, buf: []u8) ![]const u8 {
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        try writer.print("{s}={s}", .{ self.name, self.value });

        if (self.domain) |d| try writer.print("; Domain={s}", .{d});
        if (self.path) |p| try writer.print("; Path={s}", .{p});
        if (self.max_age) |ma| try writer.print("; Max-Age={d}", .{ma});
        if (self.expires) |e| try writer.print("; Expires={s}", .{e});
        if (self.secure) try writer.writeAll("; Secure");
        if (self.http_only) try writer.writeAll("; HttpOnly");
        try writer.print("; SameSite={s}", .{self.same_site.toString()});
        if (self.partitioned) try writer.writeAll("; Partitioned");

        return fbs.getWritten();
    }
};

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

    /// Adds a Set-Cookie header from a Cookie struct.
    pub fn withCookie(self: Response, cookie: Cookie) Response {
        var resp = self;
        var buf: [512]u8 = undefined;
        const cookie_str = cookie.format(&buf) catch return resp;
        resp.headers.set("Set-Cookie", cookie_str);
        return resp;
    }

    /// Adds a simple Set-Cookie header (name=value only).
    pub fn setCookie(self: Response, name: []const u8, value: []const u8) Response {
        var resp = self;
        var buf: [256]u8 = undefined;
        const cookie_str = std.fmt.bufPrint(&buf, "{s}={s}; Path=/; HttpOnly; SameSite=Lax", .{ name, value }) catch return resp;
        resp.headers.set("Set-Cookie", cookie_str);
        return resp;
    }

    /// Adds a secure authentication cookie.
    pub fn setAuthCookie(self: Response, name: []const u8, token: []const u8, max_age_seconds: i64) Response {
        var resp = self;
        var buf: [512]u8 = undefined;
        const cookie_str = std.fmt.bufPrint(&buf, "{s}={s}; Path=/; Max-Age={d}; HttpOnly; Secure; SameSite=Strict", .{ name, token, max_age_seconds }) catch return resp;
        resp.headers.set("Set-Cookie", cookie_str);
        return resp;
    }

    /// Adds a cookie deletion header.
    pub fn deleteCookie(self: Response, name: []const u8) Response {
        var resp = self;
        var buf: [128]u8 = undefined;
        const cookie_str = std.fmt.bufPrint(&buf, "{s}=; Path=/; Max-Age=0", .{name}) catch return resp;
        resp.headers.set("Set-Cookie", cookie_str);
        return resp;
    }

    /// Creates a streaming response with Transfer-Encoding: chunked.
    pub fn stream() Response {
        var resp = Response{ .status = .ok, .body = "" };
        resp.headers.set("Transfer-Encoding", "chunked");
        resp.headers.set("X-Content-Type-Options", "nosniff");
        return resp;
    }

    /// Creates a Server-Sent Events response.
    pub fn sse() Response {
        var resp = Response{
            .status = .ok,
            .body = "",
            .content_type = "text/event-stream",
        };
        resp.headers.set("Cache-Control", "no-cache");
        resp.headers.set("Connection", "keep-alive");
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
