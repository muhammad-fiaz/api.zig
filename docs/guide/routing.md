# Routing

api.zig uses compile-time route registration for maximum type safety and performance. Routes are validated at compile time with zero runtime reflection overhead.

## Basic Routes

Register routes using the HTTP method functions:

```zig
try app.get("/users", getUsers);
try app.post("/users", createUser);
try app.put("/users/{id}", updateUser);
try app.delete("/users/{id}", deleteUser);
try app.patch("/users/{id}", patchUser);
```

## Handler Signatures

Handlers can have two signatures:

### Without Context

```zig
fn hello() api.Response {
    return api.Response.text("Hello!");
}
```

### With Context

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    return api.Response.text(id);
}
```

## Path Parameters

Use `{param}` syntax for dynamic segments:

```zig
try app.get("/users/{id}", getUser);
try app.get("/posts/{post_id}/comments/{comment_id}", getComment);
```

Extract in handlers:

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    const parsed_id = std.fmt.parseInt(u32, id, 10) catch 0;
    // Use parsed_id...
}
```

## Route Groups

Organize routes logically in your main function:

```zig
// User routes
try app.get("/users", listUsers);
try app.get("/users/{id}", getUser);
try app.post("/users", createUser);

// Product routes
try app.get("/products", listProducts);
try app.get("/products/{id}", getProduct);
```

## Static Routes vs Dynamic Routes

Static routes are matched before dynamic routes:

```zig
try app.get("/users/me", getCurrentUser);  // Static
try app.get("/users/{id}", getUser);        // Dynamic
```

A request to `/users/me` will match the first route.
