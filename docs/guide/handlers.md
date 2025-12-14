# Handlers

Handlers are functions that process HTTP requests and return responses. api.zig validates handler signatures at compile time, ensuring type safety across your entire API.

## Handler Signatures

### Simple Handler (No Context)

For handlers that don't need request data:

```zig
fn hello() api.Response {
    return api.Response.text("Hello, World!");
}

fn healthCheck() api.Response {
    return api.Response.jsonRaw("{\"status\":\"healthy\"}");
}
```

### Context Handler

For handlers that need access to request data:

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    // Process request...
    return api.Response.jsonRaw("{\"id\":1}");
}
```

## Registering Handlers

```zig
try app.get("/", hello);           // Simple handler
try app.get("/users/{id}", getUser); // Context handler
```

## Handler Return Types

Handlers must return `api.Response`:

```zig
fn myHandler() api.Response {
    // JSON response
    return api.Response.jsonRaw("{\"message\":\"ok\"}");

    // Text response
    return api.Response.text("Hello");

    // HTML response
    return api.Response.html("<h1>Hello</h1>");

    // Error response
    return api.Response.err(.not_found, "{\"error\":\"Not found\"}");
}
```

## Accessing Request Data

With context handlers, you can access:

```zig
fn handler(ctx: *api.Context) api.Response {
    // Path parameters
    const id = ctx.param("id");

    // Query parameters
    const page = ctx.query("page");

    // Request body
    const body = ctx.body();

    // Headers
    const auth = ctx.header("Authorization");

    // HTTP method
    const method = ctx.method();

    // Request path
    const path = ctx.path();

    return api.Response.text("ok");
}
```

## Example: Complete CRUD

```zig
fn listUsers(ctx: *api.Context) api.Response {
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
    return api.Response.jsonRaw("{\"id\":1}")
        .setStatus(.created);
}

fn updateUser(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.jsonRaw("{\"updated\":true}");
}

fn deleteUser(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.init().setStatus(.no_content);
}

// Register
try app.get("/users", listUsers);
try app.get("/users/{id}", getUser);
try app.post("/users", createUser);
try app.put("/users/{id}", updateUser);
try app.delete("/users/{id}", deleteUser);
```
