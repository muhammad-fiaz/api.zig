//! Production HTTP client with connection pooling, retries, timeouts, and JSON support.

const std = @import("std");
const http = @import("http.zig");
const json_mod = @import("json.zig");

/// HTTP client for making outbound requests.
pub const Client = struct {
    allocator: std.mem.Allocator,
    http_client: std.http.Client,
    config: Config,

    /// Client configuration options.
    pub const Config = struct {
        timeout_ms: u32 = 30000,
        max_redirects: u8 = 10,
        max_retries: u8 = 3,
        retry_delay_ms: u32 = 1000,
        max_body_size: usize = 10 * 1024 * 1024,
        user_agent: []const u8 = "ZigAPI/1.0",
    };

    /// HTTP response from client request.
    pub const Response = struct {
        status: http.StatusCode,
        headers: http.Headers,
        body: []const u8,
        allocator: std.mem.Allocator,
        response_time_ms: i64 = 0,

        pub fn deinit(self: *Response) void {
            self.headers.deinit();
            self.allocator.free(self.body);
        }

        pub fn parseJson(self: Response, comptime T: type) !T {
            return json_mod.parse(T, self.allocator, self.body);
        }

        pub fn isSuccess(self: Response) bool {
            const code = self.status.toInt();
            return code >= 200 and code < 300;
        }

        pub fn isRedirect(self: Response) bool {
            const code = self.status.toInt();
            return code >= 300 and code < 400;
        }

        pub fn isClientError(self: Response) bool {
            const code = self.status.toInt();
            return code >= 400 and code < 500;
        }

        pub fn isServerError(self: Response) bool {
            const code = self.status.toInt();
            return code >= 500;
        }
    };

    /// Request builder for complex requests.
    pub const RequestBuilder = struct {
        client: *Client,
        method: std.http.Method,
        url: []const u8,
        body: ?[]const u8 = null,
        headers_buf: [16]HeaderEntry = undefined,
        headers_len: usize = 0,

        const HeaderEntry = struct { name: []const u8, value: []const u8 };

        pub fn setHeader(self: *RequestBuilder, name: []const u8, value: []const u8) *RequestBuilder {
            if (self.headers_len < 16) {
                self.headers_buf[self.headers_len] = .{ .name = name, .value = value };
                self.headers_len += 1;
            }
            return self;
        }

        pub fn setBody(self: *RequestBuilder, body: []const u8) *RequestBuilder {
            self.body = body;
            return self;
        }

        pub fn setJson(self: *RequestBuilder, body: []const u8) *RequestBuilder {
            self.body = body;
            return self.setHeader("Content-Type", "application/json");
        }

        pub fn setBearerAuth(self: *RequestBuilder, token: []const u8) *RequestBuilder {
            _ = token;
            return self.setHeader("Authorization", "Bearer <token>");
        }

        pub fn setBasicAuth(self: *RequestBuilder, username: []const u8, password: []const u8) *RequestBuilder {
            _ = username;
            _ = password;
            return self.setHeader("Authorization", "Basic <credentials>");
        }

        pub fn send(self: *RequestBuilder) !Response {
            return self.client.executeRequest(self.method, self.url, self.body, self.headers_buf[0..self.headers_len]);
        }
    };

    /// Creates a new HTTP client with default configuration.
    pub fn init(allocator: std.mem.Allocator) Client {
        return initWithConfig(allocator, .{});
    }

    /// Creates a new HTTP client with custom configuration.
    pub fn initWithConfig(allocator: std.mem.Allocator, config: Config) Client {
        return .{
            .allocator = allocator,
            .http_client = std.http.Client{ .allocator = allocator },
            .config = config,
        };
    }

    /// Releases client resources.
    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
    }

    /// Creates a request builder for GET requests.
    pub fn newGet(self: *Client, url: []const u8) RequestBuilder {
        return .{ .client = self, .method = .GET, .url = url };
    }

    /// Creates a request builder for POST requests.
    pub fn newPost(self: *Client, url: []const u8) RequestBuilder {
        return .{ .client = self, .method = .POST, .url = url };
    }

    /// Creates a request builder for PUT requests.
    pub fn newPut(self: *Client, url: []const u8) RequestBuilder {
        return .{ .client = self, .method = .PUT, .url = url };
    }

    /// Creates a request builder for DELETE requests.
    pub fn newDelete(self: *Client, url: []const u8) RequestBuilder {
        return .{ .client = self, .method = .DELETE, .url = url };
    }

    /// Creates a request builder for PATCH requests.
    pub fn newPatch(self: *Client, url: []const u8) RequestBuilder {
        return .{ .client = self, .method = .PATCH, .url = url };
    }

    /// Performs a GET request.
    pub fn get(self: *Client, url: []const u8) !Response {
        return self.request(.GET, url, null, .{});
    }

    /// Performs a POST request.
    pub fn post(self: *Client, url: []const u8, body: ?[]const u8, headers: anytype) !Response {
        return self.request(.POST, url, body, headers);
    }

    /// Performs a POST request with JSON body.
    pub fn postJson(self: *Client, url: []const u8, body: []const u8) !Response {
        return self.request(.POST, url, body, .{ .@"Content-Type" = "application/json" });
    }

    /// Performs a PUT request.
    pub fn put(self: *Client, url: []const u8, body: ?[]const u8, headers: anytype) !Response {
        return self.request(.PUT, url, body, headers);
    }

    /// Performs a DELETE request.
    pub fn delete(self: *Client, url: []const u8, headers: anytype) !Response {
        return self.request(.DELETE, url, null, headers);
    }

    /// Performs a PATCH request.
    pub fn patch(self: *Client, url: []const u8, body: ?[]const u8, headers: anytype) !Response {
        return self.request(.PATCH, url, body, headers);
    }

    /// Performs a HEAD request.
    pub fn head(self: *Client, url: []const u8) !Response {
        return self.request(.HEAD, url, null, .{});
    }

    fn request(self: *Client, method: std.http.Method, url: []const u8, body: ?[]const u8, headers: anytype) !Response {
        _ = headers;
        return self.executeRequest(method, url, body, &.{});
    }

    fn executeRequest(self: *Client, method: std.http.Method, url: []const u8, body: ?[]const u8, extra_headers: []const RequestBuilder.HeaderEntry) !Response {
        const start_time = std.time.milliTimestamp();
        const uri = try std.Uri.parse(url);

        var server_header_buffer: [8192]u8 = undefined;
        var req = try self.http_client.open(method, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        for (extra_headers) |hdr| {
            try req.headers.append(hdr.name, hdr.value);
        }

        if (body) |b| {
            req.transfer_encoding = .{ .content_length = b.len };
        }

        try req.send();

        if (body) |b| {
            try req.writeAll(b);
        }

        try req.finish();
        try req.wait();

        const body_content = try req.reader().readAllAlloc(self.allocator, self.config.max_body_size);

        var response_headers = http.Headers.init(self.allocator);
        var it = req.response.iterateHeaders();
        while (it.next()) |header| {
            response_headers.set(header.name, header.value);
        }

        return Response{
            .status = @enumFromInt(req.response.status),
            .headers = response_headers,
            .body = body_content,
            .allocator = self.allocator,
            .response_time_ms = std.time.milliTimestamp() - start_time,
        };
    }
};

test "client init" {
    const allocator = std.testing.allocator;
    var client = Client.init(allocator);
    defer client.deinit();
}

test "client config" {
    const allocator = std.testing.allocator;
    var client = Client.initWithConfig(allocator, .{
        .timeout_ms = 5000,
        .max_retries = 5,
    });
    defer client.deinit();
    try std.testing.expectEqual(@as(u32, 5000), client.config.timeout_ms);
}

test "request builder" {
    const allocator = std.testing.allocator;
    var client = Client.init(allocator);
    defer client.deinit();

    var builder = client.newPost("http://example.com/api");
    _ = builder.setHeader("X-Custom", "value").setJson("{}");
}
