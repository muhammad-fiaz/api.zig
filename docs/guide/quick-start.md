# Quick Start

This guide will help you quickly set up and run your first api.zig application.

## Basic REST API

```zig
const std = @import("std");
const api = @import("api");

fn root() api.Response {
    return api.Response.jsonRaw("{\"message\":\"Welcome!\"}");
}

fn getUsers(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.jsonRaw("{\"users\":[]}");
}

fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    _ = id;
    return api.Response.jsonRaw("{\"id\":1,\"name\":\"John\"}");
}

fn createUser(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.jsonRaw("{\"id\":1}").setStatus(.created);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{});
    defer app.deinit();

    try app.get("/", root);
    try app.get("/users", getUsers);
    try app.get("/users/{id}", getUser);
    try app.post("/users", createUser);

    try app.run(.{ .port = 8000 });
}
```

## Auto Port Selection

If a port is already in use, the server automatically finds an available port:

```zig
try app.run(.{
    .port = 8000,
    .auto_port = true,  // Default: tries 8000, 8001, ... until available
});
```

## Multi-Threaded Server

For high-performance applications, enable multi-threading:

```zig
try app.run(.{
    .port = 8000,
    .num_threads = 4,  // Use 4 worker threads
});
```

## HTML Responses

Serve HTML content:

```zig
fn homePage() api.Response {
    return api.Response.html("<h1>Welcome</h1>");
}

try app.get("/", homePage);
```

## Error Responses

Return error responses:

```zig
fn notFound() api.Response {
    return api.Response.err(.not_found, "{\"error\":\"Not found\"}");
}
```

## Next Steps

- [Routing](/guide/routing) - Advanced routing
- [Path Parameters](/guide/path-parameters) - Dynamic URLs
- [Multi-Threading](/guide/multi-threading) - Concurrency guide
