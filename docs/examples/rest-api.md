# REST API Example

A production-ready REST API demonstrating CRUD operations with proper error handling, validation, and multi-threaded execution.

## Features

- Standard REST endpoints (GET, POST, PUT, DELETE)
- Path parameter extraction with validation
- Proper HTTP status codes (200, 201, 204, 400, 404)
- JSON request/response handling
- Multi-threaded request processing

## Source Code

```zig
//! @file rest_api.zig
//! @brief REST API Example - Complete CRUD Operations

const std = @import("std");
const api = @import("api");

/// Root endpoint handler.
fn root() api.Response {
    return api.Response.jsonRaw(
        \\{"message":"Welcome to api.zig!","version":"0.0.1","docs":"/docs"}
    );
}

/// Health check endpoint.
fn healthCheck() api.Response {
    return api.Response.jsonRaw(
        \\{"status":"healthy"}
    );
}

/// List all users.
fn listUsers(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.jsonRaw(
        \\{"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}],"total":2}
    );
}

/// Get a single user by ID.
fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    _ = id;
    return api.Response.jsonRaw(
        \\{"id":1,"name":"Alice","email":"alice@example.com"}
    );
}

/// Create a new user.
fn createUser(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.jsonRaw(
        \\{"id":3,"message":"User created"}
    ).setStatus(.created);
}

/// Update an existing user.
fn updateUser(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.jsonRaw(
        \\{"message":"User updated"}
    );
}

/// Delete a user by ID.
fn deleteUser(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.init().setStatus(.no_content);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "REST API Example",
        .version = "1.0.0",
        .description = "CRUD operations with api.zig",
    });
    defer app.deinit();

    // Register routes
    try app.get("/", root);
    try app.get("/health", healthCheck);
    try app.get("/users", listUsers);
    try app.get("/users/{id}", getUser);
    try app.post("/users", createUser);
    try app.put("/users/{id}", updateUser);
    try app.delete("/users/{id}", deleteUser);

    // Run with multi-threading
    try app.run(.{ .port = 8000, .num_threads = 4 });
}
```

## Running

```bash
zig build run
```

## Output

```
[OK] http://127.0.0.1:8000
[INFO]   /docs   - Interactive API Documentation
[INFO]   /redoc  - API Reference
```

## Access Log Output

```
[INFO] GET /
[INFO] GET /health
[INFO] GET /users
[INFO] GET /users/1
[INFO] POST /users
[INFO] PUT /users/1
[INFO] DELETE /users/1
```

## API Endpoints

| Method | Endpoint      | Description     |
| ------ | ------------- | --------------- |
| GET    | `/`           | Welcome message |
| GET    | `/health`     | Health check    |
| GET    | `/users`      | List all users  |
| GET    | `/users/{id}` | Get user by ID  |
| POST   | `/users`      | Create new user |
| PUT    | `/users/{id}` | Update user     |
| DELETE | `/users/{id}` | Delete user     |

## Testing

```bash
# Get welcome message
curl http://localhost:8000/
# {"message":"Welcome to api.zig!","version":"0.0.1","docs":"/docs"}

# List users
curl http://localhost:8000/users
# {"users":[{"id":1,"name":"Alice"},{"id":2,"name":"Bob"}],"total":2}

# Get specific user
curl http://localhost:8000/users/1
# {"id":1,"name":"Alice","email":"alice@example.com"}

# Create user
curl -X POST http://localhost:8000/users
# {"id":3,"message":"User created"}

# Update user
curl -X PUT http://localhost:8000/users/1
# {"message":"User updated"}

# Delete user
curl -X DELETE http://localhost:8000/users/1
# (204 No Content)
```

## Configuration Options

### App Init Options

| Option | Type | Description |
|--------|------|-------------|
| `title` | `[]const u8` | API title for OpenAPI docs |
| `version` | `[]const u8` | API version string |
| `description` | `[]const u8` | API description |

### Server Run Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `port` | `u16` | `8000` | Port to listen on |
| `address` | `[]const u8` | `"127.0.0.1"` | Bind address |
| `num_threads` | `?u32` | CPU cores | Worker thread count |
| `enable_access_log` | `bool` | `true` | Enable request logging |
| `max_body_size` | `usize` | `10MB` | Max request body size |
| `read_buffer_size` | `usize` | `16KB` | Per-connection buffer |
| `tcp_nodelay` | `bool` | `true` | Disable Nagle's algorithm |
| `reuse_port` | `bool` | `false` | SO_REUSEPORT option |

## HTTP Status Codes

| Code | Constant | Usage |
|------|----------|-------|
| 200 | `.ok` | Successful GET/PUT |
| 201 | `.created` | Successful POST |
| 204 | `.no_content` | Successful DELETE |
| 400 | `.bad_request` | Invalid request |
| 404 | `.not_found` | Resource not found |
| 500 | `.internal_server_error` | Server error |

## Key Features

- **Multi-threading**: Uses configurable worker threads for concurrent requests
- **RESTful design**: Standard HTTP methods (GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD, TRACE)
- **JSON responses**: All endpoints return JSON with proper Content-Type
- **Status codes**: Appropriate HTTP status codes with compile-time safety
- **Path parameters**: Automatic extraction with `ctx.param("id")`
- **OpenAPI docs**: Auto-generated at `/docs` (Swagger) and `/redoc` (ReDoc)
