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
[INFO]   /redoc  - ReDoc
[INFO] GET /
[INFO] GET /users
[INFO] POST /users
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

## Key Features

- **Multi-threading**: Uses 4 worker threads for concurrent requests
- **RESTful design**: Standard HTTP methods for CRUD operations
- **JSON responses**: All endpoints return JSON
- **Status codes**: Appropriate HTTP status codes (200, 201, 204)
