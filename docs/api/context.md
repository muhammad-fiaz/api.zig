# Context

Request context container providing unified access to all request-scoped data within handlers. Includes path parameters, query strings, headers, body, and request-scoped state storage.

## Import

```zig
const api = @import("api");
const Context = api.Context;
```

## Fields

| Field | Type | Description |
|-------|------|-------------|
| `request` | `*Request` | The HTTP request object |
| `allocator` | `Allocator` | Arena allocator (per-request) |
| `logger` | `*Logger` | Logger instance |
| `params` | `StringHashMap` | Extracted path parameters |
| `state` | `StringHashMap` | Request-scoped state storage |

## Methods Summary

| Method | Return Type | Description |
|--------|-------------|-------------|
| `param(name)` | `?[]const u8` | Get path parameter |
| `paramAs(T, name)` | `!T` | Get and parse path parameter |
| `query(name)` | `?[]const u8` | Get query parameter |
| `queryOr(name, default)` | `[]const u8` | Get query with default |
| `queryAs(T, name)` | `!T` | Get and parse query parameter |
| `queryAsOr(T, name, default)` | `T` | Get and parse with default |
| `header(name)` | `?[]const u8` | Get request header |
| `body()` | `?[]const u8` | Get request body |
| `json(T)` | `!T` | Parse JSON body to struct |
| `method()` | `Method` | Get HTTP method |
| `path()` | `[]const u8` | Get request path |
| `setHeader(name, value)` | `void` | Set response header |
| `set(key, ptr)` | `void` | Store value in context |
| `get(T, key)` | `?*T` | Retrieve stored value |

## Methods

### Path Parameters

#### param

```zig
pub fn param(self: *const Context, name: []const u8) ?[]const u8
```

Returns a path parameter by name.

#### paramAs

```zig
pub fn paramAs(self: *const Context, comptime T: type, name: []const u8) !T
```

Returns a path parameter parsed as the specified type.

### Query Parameters

#### query

```zig
pub fn query(self: *const Context, name: []const u8) ?[]const u8
```

Returns a query parameter by name.

#### queryOr

```zig
pub fn queryOr(self: *const Context, name: []const u8, default: []const u8) []const u8
```

Returns a query parameter or default value.

#### queryAs

```zig
pub fn queryAs(self: *const Context, comptime T: type, name: []const u8) !T
```

Returns a query parameter parsed as the specified type.

#### queryAsOr

```zig
pub fn queryAsOr(self: *const Context, comptime T: type, name: []const u8, default: T) T
```

Returns a parsed query parameter or default.

### Request Data

#### method

```zig
pub fn method(self: *const Context) Method
```

Returns the HTTP method.

#### path

```zig
pub fn path(self: *const Context) []const u8
```

Returns the request path.

#### body

```zig
pub fn body(self: *const Context) []const u8
```

Returns the request body.

#### header

```zig
pub fn header(self: *const Context, name: []const u8) ?[]const u8
```

Returns a request header by name.

### Response Headers

#### setHeader

```zig
pub fn setHeader(self: *Context, name: []const u8, value: []const u8) void
```

Sets a response header.

### State

#### set

```zig
pub fn set(self: *Context, key: []const u8, value: *anyopaque) void
```

Stores a value in context state.

#### get

```zig
pub fn get(self: *const Context, comptime T: type, key: []const u8) ?*T
```

Retrieves a value from context state.

### Background Tasks

#### addBackgroundTask

```zig
pub fn addBackgroundTask(self: *Context, func: *const fn (*anyopaque) void, arg: *anyopaque) !void
```

Schedules a task to execute after the response is sent.

## Example

```zig
fn handler(ctx: *api.Context) api.Response {
    // Path parameter
    const id = ctx.param("id") orelse "0";

    // Query parameter with default
    const page = ctx.queryAsOr(u32, "page", 1);

    // Header
    const auth = ctx.header("Authorization");

    // Body
    const body = ctx.body();

    _ = id;
    _ = page;
    _ = auth;
    _ = body;

    return api.Response.jsonRaw("{\"ok\":true}");
}
```
