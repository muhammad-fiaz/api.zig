# App

The main application type that orchestrates routing, middleware, and server lifecycle.

## Import

```zig
const api = @import("api");
const App = api.App;
```

## AppConfig

Configuration for the application.

| Field         | Type          | Default               | Description           |
| ------------- | ------------- | --------------------- | --------------------- |
| `title`       | `[]const u8`  | `"Zig API Framework"` | API title for OpenAPI |
| `version`     | `[]const u8`  | `"1.0.0"`             | API version           |
| `description` | `?[]const u8` | `null`                | API description       |
| `debug`       | `bool`        | `false`               | Enable debug mode     |
| `docs_url`    | `[]const u8`  | `"/docs"`             | Swagger UI path       |
| `redoc_url`   | `[]const u8`  | `"/redoc"`            | ReDoc path            |
| `openapi_url` | `[]const u8`  | `"/openapi.json"`     | OpenAPI spec path     |

## RunConfig

Configuration for running the server.

| Field         | Type         | Default       | Description                          |
| ------------- | ------------ | ------------- | ------------------------------------ |
| `host`        | `[]const u8` | `"127.0.0.1"` | Bind address                         |
| `port`        | `u16`        | `8000`        | Listen port                          |
| `access_log`  | `bool`       | `true`        | Enable/disable access logging        |
| `num_threads` | `?u8`        | `null`        | Worker threads (null=auto, 0=single) |
| `auto_port`   | `bool`       | `true`        | Auto-find port if busy               |

## Methods

### init

```zig
pub fn init(allocator: std.mem.Allocator, config: AppConfig) !App
```

Creates a new application instance.

### initDefault

```zig
pub fn initDefault(allocator: std.mem.Allocator) App
```

Creates an application with default configuration.

### deinit

```zig
pub fn deinit(self: *App) void
```

Releases application resources.

### get

```zig
pub fn get(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers a GET route.

### post

```zig
pub fn post(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers a POST route.

### put

```zig
pub fn put(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers a PUT route.

### delete

```zig
pub fn delete(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers a DELETE route.

### patch

```zig
pub fn patch(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers a PATCH route.

### run

```zig
pub fn run(self: *App, config: RunConfig) !void
```

Starts the HTTP server.

### setNotFoundHandler

```zig
pub fn setNotFoundHandler(self: *App, handler: HandlerFn) void
```

Sets a custom 404 handler.

### setErrorHandler

```zig
pub fn setErrorHandler(self: *App, handler: *const fn (*Context, anyerror) Response) void
```

Sets a custom error handler.

## Example

```zig
const std = @import("std");
const api = @import("api");

fn hello() api.Response {
    return api.Response.text("Hello!");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "My API",
        .version = "1.0.0",
        .debug = true,
    });
    defer app.deinit();

    try app.get("/", hello);

    try app.run(.{
        .port = 8000,
        .num_threads = 4,
        .auto_port = true,
    });
}
```
