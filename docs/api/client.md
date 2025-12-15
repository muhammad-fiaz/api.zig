# Client

Synchronous HTTP/1.1 client for making outbound requests. Built on std.http.Client with automatic response buffering and JSON parsing support.

## Import

```zig
const api = @import("api");
const Client = api.Client;
```

## Client Methods Summary

| Method | Description |
|--------|-------------|
| `init(allocator)` | Create new client |
| `deinit()` | Release resources |
| `get(url)` | GET request |
| `post(url, body, headers)` | POST request |
| `put(url, body, headers)` | PUT request |
| `delete(url, headers)` | DELETE request |
| `patch(url, body, headers)` | PATCH request |

## Response Methods

| Method | Description |
|--------|-------------|
| `deinit()` | Release response resources |
| `json(T)` | Parse body as JSON type |

## Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `status` | `StatusCode` | HTTP status code |
| `headers` | `Headers` | Response headers |
| `body` | `[]const u8` | Response body |
| `allocator` | `Allocator` | Memory allocator |

## Client Type

The main client structure.

```zig
pub const Client = struct {
    allocator: std.mem.Allocator,
    http_client: std.http.Client,
    // ...
};
```

## Methods

### init

```zig
pub fn init(allocator: std.mem.Allocator) Client
```

Initialize a new client.

### deinit

```zig
pub fn deinit(self: *Client) void
```

Release resources.

### get

```zig
pub fn get(self: *Client, url: []const u8) !Response
```

Perform a GET request.

### post

```zig
pub fn post(self: *Client, url: []const u8, body: ?[]const u8, headers: anytype) !Response
```

Perform a POST request.

### put

```zig
pub fn put(self: *Client, url: []const u8, body: ?[]const u8, headers: anytype) !Response
```

Perform a PUT request.

### delete

```zig
pub fn delete(self: *Client, url: []const u8, headers: anytype) !Response
```

Perform a DELETE request.

### patch

```zig
pub fn patch(self: *Client, url: []const u8, body: ?[]const u8, headers: anytype) !Response
```

Perform a PATCH request.

## Response Type

```zig
pub const Response = struct {
    status: http.StatusCode,
    headers: http.Headers,
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *Response) void;
    pub fn json(self: Response, comptime T: type) !T;
};
```

## Example

```zig
const allocator = std.heap.page_allocator;
var client = Client.init(allocator);
defer client.deinit();

// GET request
var res = try client.get("https://api.example.com/users");
defer res.deinit();

if (res.status == .ok) {
    std.debug.print("Body: {s}\n", .{res.body});
}

// POST request with JSON
const json_body = "{\"name\":\"John\"}";
var res_post = try client.post("https://api.example.com/users", json_body, .{
    .@"Content-Type" = "application/json",
});
defer res_post.deinit();
```
