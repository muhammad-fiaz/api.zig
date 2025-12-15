# Routing

api.zig uses compile-time route registration for maximum type safety and performance. Routes are validated at compile time with zero runtime reflection overhead.

## HTTP Methods

Register routes using the HTTP method functions:

```zig
try app.get("/users", getUsers);       // GET - Retrieve resources
try app.post("/users", createUser);    // POST - Create resources
try app.put("/users/{id}", updateUser); // PUT - Replace resources
try app.delete("/users/{id}", deleteUser); // DELETE - Remove resources
try app.patch("/users/{id}", patchUser);   // PATCH - Partial updates
try app.options("/users", optionsHandler); // OPTIONS - CORS preflight
try app.head("/users", headHandler);       // HEAD - Headers only
try app.trace("/debug", traceHandler);     // TRACE - Debug
```

## Handler Signatures

Handlers can have two signatures:

### Without Context

For simple responses that don't need request data:

```zig
fn hello() api.Response {
    return api.Response.text("Hello!");
}

fn healthCheck() api.Response {
    return api.Response.jsonRaw("{\"status\":\"healthy\"}");
}
```

### With Context

For handlers that need request data:

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    _ = id;
    return api.Response.jsonRaw("{\"id\":1}");
}
```

## Path Parameters

Use `{param}` syntax for dynamic segments:

```zig
try app.get("/users/{id}", getUser);
try app.get("/posts/{post_id}/comments/{comment_id}", getComment);
```

Extract parameters in handlers:

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    const parsed_id = std.fmt.parseInt(u32, id, 10) catch 0;
    _ = parsed_id;
    return api.Response.jsonRaw("{\"id\":1}");
}

fn getComment(ctx: *api.Context) api.Response {
    const post_id = ctx.param("post_id") orelse "0";
    const comment_id = ctx.param("comment_id") orelse "0";
    _ = post_id;
    _ = comment_id;
    return api.Response.jsonRaw("{\"comment\":\"Hello\"}");
}
```

## Query Parameters

Access query string parameters:

```zig
fn listUsers(ctx: *api.Context) api.Response {
    // Get optional query param
    const search = ctx.query("search");
    
    // Get with default value
    const sort = ctx.queryOr("sort", "name");
    
    // Parse as integer with default
    const page = ctx.queryAsOr(u32, "page", 1);
    const limit = ctx.queryAsOr(u32, "limit", 10);
    
    _ = search;
    _ = sort;
    _ = page;
    _ = limit;
    return api.Response.jsonRaw("{\"users\":[]}");
}
```

## Route Groups

Organize routes logically in your main function:

```zig
// User routes
try app.get("/users", listUsers);
try app.get("/users/{id}", getUser);
try app.post("/users", createUser);
try app.put("/users/{id}", updateUser);
try app.delete("/users/{id}", deleteUser);

// Product routes
try app.get("/products", listProducts);
try app.get("/products/{id}", getProduct);
try app.post("/products", createProduct);
```

## Sub-Routers

Mount modular routers with prefixes:

```zig
var users_router = api.Router.init(allocator);
try users_router.addRoute(api.Router.register(.GET, "/", listUsers));
try users_router.addRoute(api.Router.register(.GET, "/{id}", getUser));

try app.include_router(&users_router, "/api/v1/users", &.{"Users"});
```

## Static Routes vs Dynamic Routes

Static routes are matched before dynamic routes:

```zig
try app.get("/users/me", getCurrentUser);  // Static - matched first
try app.get("/users/{id}", getUser);        // Dynamic - matched second
```

A request to `/users/me` will match the first route.

## Custom Error Handlers

Set custom handlers for 404 and errors:

```zig
// Custom 404 handler
app.setNotFoundHandler(custom404);

// Custom error handler
app.setErrorHandler(customError);

fn custom404(ctx: *api.Context) api.Response {
    const path = ctx.path();
    _ = path;
    return api.Response.err(.not_found, "{\"error\":\"Route not found\"}");
}

fn customError(ctx: *api.Context, err: anyerror) api.Response {
    _ = ctx;
    _ = err;
    return api.Response.err(.internal_server_error, "{\"error\":\"Internal error\"}");
}
```

## Complete Example

```zig
const std = @import("std");
const api = @import("api");

fn root() api.Response {
    return api.Response.jsonRaw("{\"message\":\"Welcome\"}");
}

fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    _ = id;
    return api.Response.jsonRaw("{\"id\":1,\"name\":\"John\"}");
}

fn createUser(ctx: *api.Context) api.Response {
    const body = ctx.body();
    _ = body;
    return api.Response.jsonRaw("{\"id\":1}")
        .setStatus(.created);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "My API",
        .version = "1.0.0",
    });
    defer app.deinit();

    try app.get("/", root);
    try app.get("/users/{id}", getUser);
    try app.post("/users", createUser);

    try app.run(.{ .port = 8000 });
}
```

**Output:**
```
[OK] http://127.0.0.1:8000
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
[INFO] GET /
[INFO] GET /users/123
[INFO] POST /users
```
