//! HTTP types and utilities.
//! Methods, status codes, headers, and MIME types.

const std = @import("std");

/// HTTP request methods as defined in RFC 7231.
pub const Method = enum {
    GET,
    POST,
    PUT,
    DELETE,
    PATCH,
    HEAD,
    OPTIONS,
    TRACE,
    CONNECT,

    /// Parses a string into an HTTP method.
    pub fn fromString(str: []const u8) ?Method {
        const methods = .{
            .{ "GET", Method.GET },
            .{ "POST", Method.POST },
            .{ "PUT", Method.PUT },
            .{ "DELETE", Method.DELETE },
            .{ "PATCH", Method.PATCH },
            .{ "HEAD", Method.HEAD },
            .{ "OPTIONS", Method.OPTIONS },
            .{ "TRACE", Method.TRACE },
            .{ "CONNECT", Method.CONNECT },
        };

        inline for (methods) |m| {
            if (std.mem.eql(u8, str, m[0])) return m[1];
        }
        return null;
    }

    /// Returns the string representation of the method.
    pub fn toString(self: Method) []const u8 {
        return switch (self) {
            .GET => "GET",
            .POST => "POST",
            .PUT => "PUT",
            .DELETE => "DELETE",
            .PATCH => "PATCH",
            .HEAD => "HEAD",
            .OPTIONS => "OPTIONS",
            .TRACE => "TRACE",
            .CONNECT => "CONNECT",
        };
    }
};

/// Alias for StatusCode for convenience.
pub const Status = StatusCode;

/// HTTP status codes as defined in RFC 7231 and related RFCs.
pub const StatusCode = enum(u16) {
    @"continue" = 100,
    switching_protocols = 101,
    processing = 102,
    ok = 200,
    created = 201,
    accepted = 202,
    non_authoritative_information = 203,
    no_content = 204,
    reset_content = 205,
    partial_content = 206,
    multiple_choices = 300,
    moved_permanently = 301,
    found = 302,
    see_other = 303,
    not_modified = 304,
    temporary_redirect = 307,
    permanent_redirect = 308,
    bad_request = 400,
    unauthorized = 401,
    payment_required = 402,
    forbidden = 403,
    not_found = 404,
    method_not_allowed = 405,
    not_acceptable = 406,
    request_timeout = 408,
    conflict = 409,
    gone = 410,
    length_required = 411,
    payload_too_large = 413,
    uri_too_long = 414,
    unsupported_media_type = 415,
    range_not_satisfiable = 416,
    expectation_failed = 417,
    im_a_teapot = 418,
    misdirected_request = 421,
    unprocessable_entity = 422,
    too_early = 425,
    upgrade_required = 426,
    too_many_requests = 429,
    request_header_fields_too_large = 431,
    internal_server_error = 500,
    not_implemented = 501,
    bad_gateway = 502,
    service_unavailable = 503,
    gateway_timeout = 504,
    http_version_not_supported = 505,

    /// Returns the numeric value of the status code.
    pub fn toInt(self: StatusCode) u16 {
        return @intFromEnum(self);
    }

    /// Returns the standard reason phrase for the status code.
    pub fn phrase(self: StatusCode) []const u8 {
        return switch (self) {
            .@"continue" => "Continue",
            .switching_protocols => "Switching Protocols",
            .processing => "Processing",
            .ok => "OK",
            .created => "Created",
            .accepted => "Accepted",
            .non_authoritative_information => "Non-Authoritative Information",
            .no_content => "No Content",
            .reset_content => "Reset Content",
            .partial_content => "Partial Content",
            .multiple_choices => "Multiple Choices",
            .moved_permanently => "Moved Permanently",
            .found => "Found",
            .see_other => "See Other",
            .not_modified => "Not Modified",
            .temporary_redirect => "Temporary Redirect",
            .permanent_redirect => "Permanent Redirect",
            .bad_request => "Bad Request",
            .unauthorized => "Unauthorized",
            .payment_required => "Payment Required",
            .forbidden => "Forbidden",
            .not_found => "Not Found",
            .method_not_allowed => "Method Not Allowed",
            .not_acceptable => "Not Acceptable",
            .request_timeout => "Request Timeout",
            .conflict => "Conflict",
            .gone => "Gone",
            .length_required => "Length Required",
            .payload_too_large => "Payload Too Large",
            .uri_too_long => "URI Too Long",
            .unsupported_media_type => "Unsupported Media Type",
            .range_not_satisfiable => "Range Not Satisfiable",
            .expectation_failed => "Expectation Failed",
            .im_a_teapot => "I'm a teapot",
            .misdirected_request => "Misdirected Request",
            .unprocessable_entity => "Unprocessable Entity",
            .too_early => "Too Early",
            .upgrade_required => "Upgrade Required",
            .too_many_requests => "Too Many Requests",
            .request_header_fields_too_large => "Request Header Fields Too Large",
            .internal_server_error => "Internal Server Error",
            .not_implemented => "Not Implemented",
            .bad_gateway => "Bad Gateway",
            .service_unavailable => "Service Unavailable",
            .gateway_timeout => "Gateway Timeout",
            .http_version_not_supported => "HTTP Version Not Supported",
        };
    }

    /// Returns true if the status code indicates success (2xx).
    pub fn isSuccess(self: StatusCode) bool {
        const code = @intFromEnum(self);
        return code >= 200 and code < 300;
    }

    /// Returns true if the status code indicates a redirect (3xx).
    pub fn isRedirect(self: StatusCode) bool {
        const code = @intFromEnum(self);
        return code >= 300 and code < 400;
    }

    /// Returns true if the status code indicates a client error (4xx).
    pub fn isClientError(self: StatusCode) bool {
        const code = @intFromEnum(self);
        return code >= 400 and code < 500;
    }

    /// Returns true if the status code indicates a server error (5xx).
    pub fn isServerError(self: StatusCode) bool {
        const code = @intFromEnum(self);
        return code >= 500 and code < 600;
    }
};

test "Method parsing" {
    try std.testing.expectEqual(Method.GET, Method.fromString("GET").?);
    try std.testing.expectEqual(Method.POST, Method.fromString("POST").?);
    try std.testing.expect(Method.fromString("INVALID") == null);
}

test "StatusCode helpers" {
    try std.testing.expect(StatusCode.ok.isSuccess());
    try std.testing.expect(StatusCode.moved_permanently.isRedirect());
    try std.testing.expect(StatusCode.bad_request.isClientError());
    try std.testing.expect(StatusCode.internal_server_error.isServerError());
}

/// Common MIME content type constants.
pub const Headers = struct {
    pub const ContentTypes = struct {
        pub const json = "application/json";
        pub const html = "text/html; charset=utf-8";
        pub const plain = "text/plain; charset=utf-8";
        pub const xml = "application/xml";
        pub const form = "application/x-www-form-urlencoded";
        pub const multipart = "multipart/form-data";
        pub const css = "text/css";
        pub const javascript = "application/javascript";
        pub const png = "image/png";
        pub const jpeg = "image/jpeg";
        pub const gif = "image/gif";
        pub const svg = "image/svg+xml";
        pub const ico = "image/x-icon";
        pub const woff = "font/woff";
        pub const woff2 = "font/woff2";
    };

    allocator: std.mem.Allocator,
    map: std.StringHashMap([]const u8),

    /// Initializes a new header collection.
    pub fn init(allocator: std.mem.Allocator) Headers {
        return .{
            .allocator = allocator,
            .map = std.StringHashMap([]const u8).init(allocator),
        };
    }

    /// Releases resources.
    pub fn deinit(self: *Headers) void {
        self.map.deinit();
    }

    /// Sets a header value.
    pub fn set(self: *Headers, name: []const u8, value: []const u8) void {
        self.map.put(name, value) catch {};
    }

    /// Retrieves a header value by name.
    pub fn get(self: *const Headers, name: []const u8) ?[]const u8 {
        return self.map.get(name);
    }

    /// Removes a header by name.
    pub fn remove(self: *Headers, name: []const u8) void {
        _ = self.map.remove(name);
    }

    /// Formats headers for HTTP response output.
    pub fn format(self: *const Headers, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayListUnmanaged(u8){};
        errdefer list.deinit(allocator);

        var iter = self.map.iterator();
        while (iter.next()) |entry| {
            try list.appendSlice(allocator, entry.key_ptr.*);
            try list.appendSlice(allocator, ": ");
            try list.appendSlice(allocator, entry.value_ptr.*);
            try list.appendSlice(allocator, "\r\n");
        }

        return list.toOwnedSlice(allocator);
    }
};

/// Determines the MIME type based on file extension.
pub fn getMimeType(path_str: []const u8) []const u8 {
    const ext = std.fs.path.extension(path_str);

    if (std.mem.eql(u8, ext, ".html") or std.mem.eql(u8, ext, ".htm")) return Headers.ContentTypes.html;
    if (std.mem.eql(u8, ext, ".css")) return Headers.ContentTypes.css;
    if (std.mem.eql(u8, ext, ".js")) return Headers.ContentTypes.javascript;
    if (std.mem.eql(u8, ext, ".json")) return Headers.ContentTypes.json;
    if (std.mem.eql(u8, ext, ".xml")) return Headers.ContentTypes.xml;
    if (std.mem.eql(u8, ext, ".png")) return Headers.ContentTypes.png;
    if (std.mem.eql(u8, ext, ".jpg") or std.mem.eql(u8, ext, ".jpeg")) return Headers.ContentTypes.jpeg;
    if (std.mem.eql(u8, ext, ".gif")) return Headers.ContentTypes.gif;
    if (std.mem.eql(u8, ext, ".svg")) return Headers.ContentTypes.svg;
    if (std.mem.eql(u8, ext, ".ico")) return Headers.ContentTypes.ico;
    if (std.mem.eql(u8, ext, ".woff")) return Headers.ContentTypes.woff;
    if (std.mem.eql(u8, ext, ".woff2")) return Headers.ContentTypes.woff2;
    if (std.mem.eql(u8, ext, ".txt")) return Headers.ContentTypes.plain;

    return "application/octet-stream";
}

test "method parsing" {
    try std.testing.expectEqual(Method.GET, Method.fromString("GET").?);
    try std.testing.expectEqual(Method.POST, Method.fromString("POST").?);
    try std.testing.expectEqual(null, Method.fromString("INVALID"));
}

test "method to string" {
    try std.testing.expectEqualStrings("GET", Method.GET.toString());
    try std.testing.expectEqualStrings("POST", Method.POST.toString());
}

test "status code phrase" {
    try std.testing.expectEqualStrings("OK", StatusCode.ok.phrase());
    try std.testing.expectEqualStrings("Not Found", StatusCode.not_found.phrase());
}

test "status code categories" {
    try std.testing.expect(StatusCode.ok.isSuccess());
    try std.testing.expect(StatusCode.created.isSuccess());
    try std.testing.expect(!StatusCode.not_found.isSuccess());
    try std.testing.expect(StatusCode.bad_request.isClientError());
    try std.testing.expect(StatusCode.internal_server_error.isServerError());
}

test "mime type detection" {
    try std.testing.expectEqualStrings("text/html; charset=utf-8", getMimeType("index.html"));
    try std.testing.expectEqualStrings("application/json", getMimeType("data.json"));
    try std.testing.expectEqualStrings("text/css", getMimeType("style.css"));
}
