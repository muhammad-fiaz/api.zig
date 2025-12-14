# Context

The Context provides access to request data and utilities within handlers.

## Overview

```zig
fn handler(ctx: *api.Context) api.Response {
    // Access request data through ctx
    return api.Response.text("ok");
}
```

## Path Parameters

```zig
fn getUser(ctx: *api.Context) api.Response {
    // Get path parameter as string
    const id = ctx.param("id") orelse "0";

    // Get and parse as type
    const parsed_id = ctx.paramAs(u32, "id") catch 0;

    _ = id;
    _ = parsed_id;
    return api.Response.jsonRaw("{}");
}
```

## Query Parameters

```zig
fn listUsers(ctx: *api.Context) api.Response {
    // Get query parameter
    const page = ctx.query("page");

    // Get with default value
    const limit = ctx.queryOr("limit", "10");

    // Get and parse as type
    const page_num = ctx.queryAs(u32, "page") catch 1;

    // Get and parse with default
    const limit_num = ctx.queryAsOr(u32, "limit", 10);

    _ = page;
    _ = limit;
    _ = page_num;
    _ = limit_num;
    return api.Response.jsonRaw("{}");
}
```

**Request:** `GET /users?page=2&limit=20`

## Request Headers

```zig
fn handler(ctx: *api.Context) api.Response {
    const auth = ctx.header("Authorization");
    const content_type = ctx.header("Content-Type");
    const user_agent = ctx.header("User-Agent");

    _ = auth;
    _ = content_type;
    _ = user_agent;
    return api.Response.text("ok");
}
```

## Request Body

```zig
fn createUser(ctx: *api.Context) api.Response {
    // Get raw body
    const body = ctx.body();

    _ = body;
    return api.Response.jsonRaw("{\"created\":true}");
}
```

## Request Method

```zig
fn handler(ctx: *api.Context) api.Response {
    const method = ctx.method();

    return switch (method) {
        .GET => api.Response.text("GET request"),
        .POST => api.Response.text("POST request"),
        else => api.Response.text("Other method"),
    };
}
```

## Request Path

```zig
fn handler(ctx: *api.Context) api.Response {
    const path = ctx.path();
    // path = "/users/123"
    _ = path;
    return api.Response.text("ok");
}
```

## Response Headers

Set headers on the response through context:

```zig
fn handler(ctx: *api.Context) api.Response {
    ctx.setHeader("X-Custom-Header", "value");
    return api.Response.text("ok");
}
```

## State Storage

Store and retrieve values during request processing:

```zig
fn middleware(ctx: *api.Context) void {
    var user_id: u32 = 123;
    ctx.set("user_id", @ptrCast(&user_id));
}

fn handler(ctx: *api.Context) api.Response {
    if (ctx.get(u32, "user_id")) |user_id| {
        _ = user_id.*;
    }
    return api.Response.text("ok");
}
```

## Complete Example

```zig
fn updateUser(ctx: *api.Context) api.Response {
    // Path parameter
    const id = ctx.param("id") orelse return api.Response.err(.bad_request, "{\"error\":\"Missing ID\"}");

    // Query parameter
    const notify = ctx.queryAsOr(bool, "notify", false);

    // Header
    const auth = ctx.header("Authorization") orelse return api.Response.err(.unauthorized, "{\"error\":\"Unauthorized\"}");

    // Body
    const body = ctx.body();
    if (body.len == 0) {
        return api.Response.err(.bad_request, "{\"error\":\"Empty body\"}");
    }

    _ = id;
    _ = notify;
    _ = auth;

    return api.Response.jsonRaw("{\"updated\":true}");
}
```
