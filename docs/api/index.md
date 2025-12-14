# API Reference

Comprehensive API documentation for the api.zig framework. This reference covers all public types, functions, and configuration options.

## Core Modules

| Module                    | Description                              |
| ------------------------- | ---------------------------------------- |
| [App](/api/app)           | Application orchestrator and lifecycle   |
| [Response](/api/response) | HTTP response builder with fluent API    |
| [Context](/api/context)   | Request context and parameter access     |
| [Router](/api/router)     | Compile-time route registration          |
| [Server](/api/server)     | Multi-threaded HTTP/1.1 server           |
| [Client](/api/client)     | HTTP client for outbound requests        |

## HTTP Utilities

| Module            | Description                               |
| ----------------- | ----------------------------------------- |
| [HTTP](/api/http) | HTTP methods, status codes, MIME types    |
| [JSON](/api/json) | JSON parsing and serialization (std.json) |

## Advanced

| Module                        | Description                           |
| ----------------------------- | ------------------------------------- |
| [Extractors](/api/extractors) | Type-safe request data extraction     |
| [Validation](/api/validation) | Declarative input validation          |
| [OpenAPI](/api/openapi)       | OpenAPI 3.1 specification generation  |
| [Logger](/api/logger)         | Structured logging via logly          |
| [Middleware](/api/middleware) | Request/response middleware pipeline  |
| [Static](/api/static)         | Static file serving with MIME support |

## Quick Example

```zig
const std = @import("std");
const api = @import("api");

fn handler(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    _ = id;
    return api.Response.jsonRaw("{\"id\":1}");
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "My API",
        .version = "1.0.0",
    });
    defer app.deinit();

    try app.get("/users/{id}", handler);
    try app.run(.{ .port = 8000 });
}
```

## Import

```zig
const api = @import("api");

// Access types
const App = api.App;
const Response = api.Response;
const Context = api.Context;
const Router = api.Router;
const StatusCode = api.StatusCode;
const Method = api.Method;
const Client = api.Client;
```
