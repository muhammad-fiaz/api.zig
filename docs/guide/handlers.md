# Handlers

Handlers are functions that process HTTP requests and return responses. api.zig validates handler signatures at compile time, ensuring type safety across your entire API.

## Handler Signatures

api.zig supports two handler signatures:

| Signature | Use Case | Example |
|-----------|----------|---------|
| `fn() Response` | Static responses, no request data needed | Health checks, welcome pages |
| `fn(*Context) Response` | Dynamic responses, access to request data | CRUD operations, authentication |

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
    _ = id;
    return api.Response.jsonRaw("{\"id\":1}");
}
```

## Registering Handlers

```zig
try app.get("/", hello);             // Simple handler
try app.get("/users/{id}", getUser); // Context handler
```

## HTTP Methods

| Method | Function | Typical Use |
|--------|----------|-------------|
| GET | `app.get()` | Retrieve resources |
| POST | `app.post()` | Create resources |
| PUT | `app.put()` | Replace resources |
| PATCH | `app.patch()` | Partial update |
| DELETE | `app.delete()` | Remove resources |
| OPTIONS | `app.options()` | CORS preflight |
| HEAD | `app.head()` | Headers only |
| TRACE | `app.trace()` | Debug/diagnostic |

## Handler Return Types

Handlers must return `api.Response`:

| Method | Content-Type | Description |
|--------|-------------|-------------|
| `Response.jsonRaw()` | `application/json` | Raw JSON string |
| `Response.json()` | `application/json` | Serialize struct |
| `Response.text()` | `text/plain` | Plain text |
| `Response.html()` | `text/html` | HTML content |
| `Response.xml()` | `application/xml` | XML content |
| `Response.err()` | `application/json` | Error response |

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

| Method | Return Type | Description |
|--------|-------------|-------------|
| `ctx.param("name")` | `?[]const u8` | Path parameter |
| `ctx.query("key")` | `?[]const u8` | Query parameter |
| `ctx.body()` | `?[]const u8` | Request body |
| `ctx.header("name")` | `?[]const u8` | Request header |
| `ctx.method()` | `Method` | HTTP method |
| `ctx.path()` | `[]const u8` | Request path |
| `ctx.json(T)` | `!T` | Parse JSON body |

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

    _ = .{ id, page, body, auth, method, path };
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
