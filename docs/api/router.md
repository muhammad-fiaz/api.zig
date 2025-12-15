# Router

Compile-time route registration and request matching. Routes are validated at compile time with zero runtime reflection overhead. Supports path parameters with automatic extraction.

## Import

```zig
const api = @import("api");
const Router = api.Router;
const RouteConfig = api.RouteConfig;
```

## RouteConfig

Route configuration structure:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `method` | `Method` | required | HTTP method |
| `path` | `[]const u8` | required | Route path pattern |
| `summary` | `?[]const u8` | `null` | OpenAPI summary |
| `description` | `?[]const u8` | `null` | OpenAPI description |
| `tags` | `[]const []const u8` | `&.{}` | OpenAPI tags |
| `deprecated` | `bool` | `false` | Mark as deprecated |

## Route

Compiled route entry:

| Field | Type | Description |
|-------|------|-------------|
| `method` | `Method` | HTTP method |
| `path` | `[]const u8` | Route path |
| `handler` | `*const fn` | Handler function |
| `segment_count` | `usize` | Path segment count |

## Router Methods Summary

| Method | Description |
|--------|-------------|
| `init(allocator)` | Create new router |
| `deinit()` | Release resources |
| `addRoute(route)` | Add compiled route |
| `match(method, path)` | Match request to route |
| `setNotFound(handler)` | Set custom 404 handler |
| `include_router(router, prefix, tags)` | Mount sub-router |

## HTTP Method Registration

| Method | Function |
|--------|----------|
| GET | `app.get(path, handler)` |
| POST | `app.post(path, handler)` |
| PUT | `app.put(path, handler)` |
| DELETE | `app.delete(path, handler)` |
| PATCH | `app.patch(path, handler)` |
| OPTIONS | `app.options(path, handler)` |
| HEAD | `app.head(path, handler)` |
| TRACE | `app.trace(path, handler)` |

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

### include_router

```zig
pub fn include_router(self: *Router, other: *const Router, prefix: []const u8, tags: []const []const u8) !void
```

Includes routes from another router (sub-router). This allows you to organize routes into separate modules and mount them at a specific prefix.

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

// Using sub-routers
var users_router = Router.init(allocator);
try users_router.addRoute(Router.register(.GET, "/", listUsers));
try users_router.addRoute(Router.register(.GET, "/{id}", getUser));

try app.include_router(&users_router, "/api/v1/users", &.{ "users" });

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
