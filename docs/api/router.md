# Router

Compile-time route registration and request matching. Routes are validated at compile time with zero runtime reflection overhead. Supports path parameters with automatic extraction.

## Import

```zig
const api = @import("api");
const Router = api.Router;
const RouteConfig = api.RouteConfig;
```

## RouteConfig

Route configuration structure.

| Field         | Type                 | Description         |
| ------------- | -------------------- | ------------------- |
| `method`      | `Method`             | HTTP method         |
| `path`        | `[]const u8`         | Route path pattern  |
| `summary`     | `?[]const u8`        | OpenAPI summary     |
| `description` | `?[]const u8`        | OpenAPI description |
| `tags`        | `[]const []const u8` | OpenAPI tags        |
| `deprecated`  | `bool`               | Mark as deprecated  |

## Route

Compiled route entry.

| Field           | Type         | Description        |
| --------------- | ------------ | ------------------ |
| `method`        | `Method`     | HTTP method        |
| `path`          | `[]const u8` | Route path         |
| `handler`       | `*const fn`  | Handler function   |
| `segment_count` | `usize`      | Path segment count |

## Router Methods

### init

```zig
pub fn init(allocator: std.mem.Allocator) Router
```

Creates a new router.

### deinit

```zig
pub fn deinit(self: *Router) void
```

Releases router resources.

### addRoute

```zig
pub fn addRoute(self: *Router, r: Route) !void
```

Adds a compiled route.

### match

```zig
pub fn match(self: *const Router, method: Method, path: []const u8) ?MatchResult
```

Matches a request to a route.

### setNotFound

```zig
pub fn setNotFound(self: *Router, handler: HandlerFn) void
```

Sets a custom 404 handler.

## Static Functions

### register

```zig
pub fn register(
    comptime method: Method,
    comptime path: []const u8,
    comptime handler: anytype,
) Route
```

Compile-time route registration.

### route

```zig
pub fn route(comptime config: RouteConfig, comptime handler: anytype) Route
```

Register with full configuration.

### matchPath

```zig
pub fn matchPath(pattern: []const u8, path: []const u8) ?ParamList
```

Matches a pattern against a path.

## ParamList

Extracted path parameters.

```zig
pub const ParamList = struct {
    items: [8]ParamEntry,
    len: usize,

    pub fn get(self: *const ParamList, name: []const u8) ?[]const u8
};
```

## Example

```zig
// Using App (recommended)
try app.get("/users", listUsers);
try app.get("/users/{id}", getUser);
try app.post("/users", createUser);

// Using Router directly
var router = Router.init(allocator);
defer router.deinit();

const route = Router.register(.GET, "/users/{id}", getUser);
try router.addRoute(route);

// Match a path
if (router.match(.GET, "/users/123")) |result| {
    const id = result.params.get("id"); // "123"
    _ = id;
}
```

## Path Matching

```zig
const result = api.router.matchPath("/users/{id}", "/users/123");
if (result) |params| {
    const id = params.get("id").?; // "123"
    _ = id;
}
```
