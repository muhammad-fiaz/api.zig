# App

Core application orchestrator for HTTP routing, middleware pipelines, and server lifecycle management.

## Import

```zig
const api = @import("api");
const App = api.App;
```

## AppConfig

Application configuration structure.

| Field         | Type          | Default               | Description                      |
| ------------- | ------------- | --------------------- | -------------------------------- |
| `title`       | `[]const u8`  | `"Zig API Framework"` | API title for OpenAPI spec       |
| `version`     | `[]const u8`  | `"1.0.0"`             | API version string               |
| `description` | `?[]const u8` | `null`                | Optional API description         |
| `debug`       | `bool`        | `false`               | Enable debug logging             |
| `docs_url`    | `[]const u8`  | `"/docs"`             | Swagger UI endpoint path         |
| `redoc_url`   | `[]const u8`  | `"/redoc"`            | ReDoc documentation endpoint     |
| `openapi_url` | `[]const u8`  | `"/openapi.json"`     | OpenAPI specification endpoint   |

## RunConfig

Server runtime configuration.

| Field         | Type         | Default       | Description                                    |
| ------------- | ------------ | ------------- | ---------------------------------------------- |
| `host`        | `[]const u8` | `"127.0.0.1"` | Server bind address                            |
| `port`        | `u16`        | `8000`        | Server listen port                             |
| `access_log`  | `bool`       | `true`        | Enable HTTP access logging                     |
| `num_threads` | `?u8`        | `null`        | Worker thread count (null=auto-detect CPU)     |
| `auto_port`   | `bool`       | `true`        | Automatically find available port if occupied  |

## Methods

### init

```zig
pub fn init(allocator: std.mem.Allocator, config: AppConfig) !App
```

Initializes a new application instance with specified configuration.

### initDefault

```zig
pub fn initDefault(allocator: std.mem.Allocator) !App
```

Initializes application with default configuration values.

### deinit

```zig
pub fn deinit(self: *App) void
```

Releases all allocated resources and cleans up application state.

### get

```zig
pub fn get(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers HTTP GET route handler at compile-time.

### post

```zig
pub fn post(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers HTTP POST route handler at compile-time.

### put

```zig
pub fn put(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers HTTP PUT route handler at compile-time.

### delete

```zig
pub fn delete(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers HTTP DELETE route handler at compile-time.

### patch

```zig
pub fn patch(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers HTTP PATCH route handler at compile-time.

### options

```zig
pub fn options(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers HTTP OPTIONS route handler for CORS preflight requests.

### head

```zig
pub fn head(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers HTTP HEAD route handler (headers only, no response body).

### trace

```zig
pub fn trace(self: *App, comptime path: []const u8, handler: anytype) !void
```

Registers HTTP TRACE route handler for request path debugging.

### run

```zig
pub fn run(self: *App, config: RunConfig) !void
```

Starts HTTP server and begins accepting connections. Blocks until server shutdown.

### setNotFoundHandler

```zig
pub fn setNotFoundHandler(self: *App, handler: HandlerFn) void
```

Configures custom handler for 404 Not Found responses.

### setErrorHandler

```zig
pub fn setErrorHandler(self: *App, handler: *const fn (*Context, anyerror) Response) void
```

Configures custom handler for unhandled errors and exceptions.

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
