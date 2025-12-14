//! HTTP client for outbound requests.
//! Supports GET, POST, PUT, DELETE, PATCH with JSON parsing.

const std = @import("std");
const http = @import("http.zig");
const json_mod = @import("json.zig");

pub const Client = struct {
    allocator: std.mem.Allocator,
    http_client: std.http.Client,

    pub const Options = struct {
        timeout_ms: u32 = 10000,
        max_redirects: u8 = 5,
    };

    pub const Response = struct {
        status: http.StatusCode,
        headers: http.Headers,
        body: []const u8,
        allocator: std.mem.Allocator,

        pub fn deinit(self: *Response) void {
            self.headers.deinit();
            self.allocator.free(self.body);
        }

        pub fn parseJson(self: Response, comptime T: type) !T {
            return json_mod.parse(T, self.allocator, self.body);
        }
    };

    pub fn init(allocator: std.mem.Allocator) Client {
        return .{
            .allocator = allocator,
            .http_client = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *Client) void {
        self.http_client.deinit();
    }

    pub fn get(self: *Client, url: []const u8) !Response {
        return self.request(.GET, url, null, .{});
    }

    pub fn post(self: *Client, url: []const u8, body: ?[]const u8, headers: anytype) !Response {
        return self.request(.POST, url, body, headers);
    }

    pub fn put(self: *Client, url: []const u8, body: ?[]const u8, headers: anytype) !Response {
        return self.request(.PUT, url, body, headers);
    }

    pub fn delete(self: *Client, url: []const u8, headers: anytype) !Response {
        return self.request(.DELETE, url, null, headers);
    }

    pub fn patch(self: *Client, url: []const u8, body: ?[]const u8, headers: anytype) !Response {
        return self.request(.PATCH, url, body, headers);
    }

    fn request(self: *Client, method: std.http.Method, url: []const u8, body: ?[]const u8, headers: anytype) !Response {
        const uri = try std.Uri.parse(url);

        var server_header_buffer: [4096]u8 = undefined;
        var req = try self.http_client.open(method, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        // Add custom headers
        inline for (@typeInfo(@TypeOf(headers)).@"struct".fields) |field| {
            try req.headers.append(field.name, @field(headers, field.name));
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

        const body_content = try req.reader().readAllAlloc(self.allocator, 1024 * 1024 * 10); // 10MB limit

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
        };
    }
};

test "client init" {
    const allocator = std.testing.allocator;
    var client = Client.init(allocator);
    defer client.deinit();
}
