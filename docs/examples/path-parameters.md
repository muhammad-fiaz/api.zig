# Path Parameters Example

Demonstrating dynamic URL segments and type-safe parameter extraction.

## Features

- Single path parameters: `/products/{id}`
- Multiple parameters: `/products/{product_id}/reviews/{review_id}`
- Nested resources: `/users/{user_id}/posts/{post_id}`
- String parameters with dynamic responses

## Source Code

```zig
//! @file path_params.zig
//! @brief Path Parameters Example - Dynamic URL Segments

const std = @import("std");
const api = @import("api");

/// Get product by ID.
fn getProduct(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "unknown";
    _ = id;
    return api.Response.jsonRaw(
        \\{"product_id":"123","name":"Example Product","price":29.99}
    );
}

/// Get a specific review for a product.
fn getProductReview(ctx: *api.Context) api.Response {
    const product_id = ctx.param("product_id") orelse "0";
    const review_id = ctx.param("review_id") orelse "0";
    _ = product_id;
    _ = review_id;
    return api.Response.jsonRaw(
        \\{"product_id":"1","review_id":"1","rating":5}
    );
}

/// Get a specific post from a user.
fn getUserPost(ctx: *api.Context) api.Response {
    const user_id = ctx.param("user_id") orelse "0";
    const post_id = ctx.param("post_id") orelse "0";
    _ = user_id;
    _ = post_id;
    return api.Response.jsonRaw(
        \\{"user_id":"1","post_id":"1","title":"Sample Post"}
    );
}

/// Greet a user by name.
fn greetUser(ctx: *api.Context) api.Response {
    const name = ctx.param("name") orelse "World";
    var buf: [128]u8 = undefined;
    const message = std.fmt.bufPrint(&buf, "Hello, {s}!", .{name}) catch "Hello!";
    return api.Response.text(message);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "Path Parameters Example",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Register routes with path parameters
    try app.get("/products/{id}", getProduct);
    try app.get("/products/{product_id}/reviews/{review_id}", getProductReview);
    try app.get("/users/{user_id}/posts/{post_id}", getUserPost);
    try app.get("/greet/{name}", greetUser);

    try app.run(.{ .port = 8000 });
}
```

## Running

```bash
zig build run-path_params
```

## Output

```
Server started on http://127.0.0.1:8000
API Docs: http://127.0.0.1:8000/docs
ReDoc: http://127.0.0.1:8000/redoc
```

## Endpoints

| Route                                        | Parameters                | Description   |
| -------------------------------------------- | ------------------------- | ------------- |
| `/products/{id}`                             | `id`                      | Get product   |
| `/products/{product_id}/reviews/{review_id}` | `product_id`, `review_id` | Get review    |
| `/users/{user_id}/posts/{post_id}`           | `user_id`, `post_id`      | Get user post |
| `/greet/{name}`                              | `name`                    | Greet user    |

## Testing

```bash
# Get product by ID
curl http://localhost:8000/products/123
# {"product_id":"123","name":"Example Product","price":29.99}

# Get product review
curl http://localhost:8000/products/1/reviews/5
# {"product_id":"1","review_id":"1","rating":5}

# Get user post
curl http://localhost:8000/users/42/posts/7
# {"user_id":"1","post_id":"1","title":"Sample Post"}

# Greet user
curl http://localhost:8000/greet/Alice
# Hello, Alice!
```

## Key Concepts

### Single Parameter

```zig
try app.get("/users/{id}", getUser);

fn getUser(ctx: *api.Context) api.Response {
    const id = ctx.param("id") orelse "0";
    // id = "123" for /users/123
}
```

### Multiple Parameters

```zig
try app.get("/orgs/{org}/repos/{repo}", getRepo);

fn getRepo(ctx: *api.Context) api.Response {
    const org = ctx.param("org") orelse "";
    const repo = ctx.param("repo") orelse "";
    // org = "acme", repo = "project" for /orgs/acme/repos/project
}
```

### Type Conversion

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id_str = ctx.param("id") orelse "0";
    const id = std.fmt.parseInt(u32, id_str, 10) catch 0;
    // id is now u32
}
```

### With Default Value

```zig
const name = ctx.param("name") orelse "Guest";
```

## Path Matching

api.zig uses `{}` syntax for parameters:

| Pattern                   | Example Path       | Matches            |
| ------------------------- | ------------------ | ------------------ |
| `/users/{id}`             | `/users/123`       | ✅ id="123"        |
| `/users/{id}`             | `/users/`          | ❌                 |
| `/users/{id}/posts/{pid}` | `/users/1/posts/5` | ✅ id="1", pid="5" |

## Context Methods

| Method | Return Type | Description |
|--------|-------------|-------------|
| `ctx.param("name")` | `?[]const u8` | Get path parameter |
| `ctx.query("key")` | `?[]const u8` | Get query parameter |
| `ctx.header("name")` | `?[]const u8` | Get request header |
| `ctx.body()` | `?[]const u8` | Get request body |
| `ctx.json(T)` | `!T` | Parse JSON body to struct |
| `ctx.method()` | `Method` | Get HTTP method |
| `ctx.path()` | `[]const u8` | Get request path |

## Error Handling

```zig
fn getUser(ctx: *api.Context) api.Response {
    const id_str = ctx.param("id") orelse {
        return api.Response.jsonRaw(
            \\{"error":"Missing user ID"}
        ).setStatus(.bad_request);
    };

    const id = std.fmt.parseInt(u32, id_str, 10) catch {
        return api.Response.jsonRaw(
            \\{"error":"Invalid user ID format"}
        ).setStatus(.bad_request);
    };

    // Continue with valid id...
    _ = id;
    return api.Response.jsonRaw(\\{"id":1});
}
```

## HTTP Status Codes

| Code | Constant | When to Use |
|------|----------|-------------|
| 200 | `.ok` | Resource found |
| 400 | `.bad_request` | Invalid parameter format |
| 404 | `.not_found` | Resource not found |
| 422 | `.unprocessable_entity` | Validation failed |

## Best Practices

1. **Always handle missing parameters**: Use `orelse` to provide fallbacks
2. **Validate parameter formats**: Parse strings to appropriate types
3. **Return proper status codes**: Use 400 for invalid input, 404 for not found
4. **Document your parameters**: OpenAPI will auto-generate documentation
