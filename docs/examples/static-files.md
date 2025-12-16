# Static File Server

Complete example of serving static files and directories with api.zig.

## Overview

This example demonstrates:
- Serving entire directories
- Multiple directory mounts
- Mixing static files with API routes
- Automatic MIME type detection
- Security features (path traversal protection)

## Source Code

**File:** `examples/static_file_server.zig`

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "Static File Server",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Serve static files from "public" directory at root
    try app.serveStatic("/", "public");

    // Serve assets from "assets" directory at /assets
    try app.serveStatic("/assets", "assets");

    // API routes work alongside static files
    try app.get("/api/status", status);

    try app.run(.{ .port = 8000 });
}

fn status(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.json(.{ .status = "ok" });
}
```

## Directory Structure

```
project/
├── public/
│   ├── index.html
│   ├── about.html
│   └── style.css
├── assets/
│   ├── logo.png
│   ├── app.js
│   └── fonts/
│       └── main.woff2
└── examples/
    └── static_file_server.zig
```

## URL Mapping

| File Path | URL | MIME Type |
|-----------|-----|-----------|
| `public/index.html` | `http://localhost:8000/index.html` | `text/html` |
| `public/style.css` | `http://localhost:8000/style.css` | `text/css` |
| `assets/logo.png` | `http://localhost:8000/assets/logo.png` | `image/png` |
| `assets/app.js` | `http://localhost:8000/assets/app.js` | `application/javascript` |

## Running the Example

### 1. Create Directory Structure

```bash
mkdir public assets
echo "<h1>Hello World</h1>" > public/index.html
echo "body { color: blue; }" > public/style.css
```

### 2. Build and Run

```bash
zig build-exe examples/static_file_server.zig
./static_file_server
```

### 3. Test Endpoints

```bash
# Static files
curl http://localhost:8000/index.html
curl http://localhost:8000/style.css
curl http://localhost:8000/assets/logo.png

# API endpoint
curl http://localhost:8000/api/status
```

## Features

### Automatic MIME Types

The server automatically detects MIME types:

| Extension | MIME Type |
|-----------|-----------|
| `.html` | `text/html` |
| `.css` | `text/css` |
| `.js` | `application/javascript` |
| `.json` | `application/json` |
| `.png` | `image/png` |
| `.jpg` | `image/jpeg` |
| `.svg` | `image/svg+xml` |
| `.woff2` | `font/woff2` |

### Security

Built-in security features:
- **Path Traversal Protection**: Blocks `../` attacks
- **File Size Limits**: 10MB default per file
- **Explicit Directory Control**: Only serve what you specify

### Performance

- Multi-threaded file serving
- Efficient file I/O
- No runtime directory scanning
- Compile-time route registration

## Advanced Usage

### SPA (Single Page Application)

```zig
const handler = api.StaticFiles.serve(.{
    .root_path = "dist",
    .url_prefix = "/",
    .html5_mode = true, // Fallback to index.html
});

try app.get("/{path...}", handler);
```

### Custom Configuration

```zig
const handler = api.StaticFiles.serve(.{
    .root_path = "public",
    .url_prefix = "/static",
    .index_files = &.{"index.html", "index.htm", "default.html"},
    .browse = false,
});

try app.get("/static/{path...}", handler);
```

### Multiple Directories

```zig
// Website files
try app.serveStatic("/", "public");

// Built assets
try app.serveStatic("/assets", "dist");

// User uploads
try app.serveStatic("/uploads", "uploads");

// Documentation
try app.serveStatic("/docs", "documentation");
```

## Complete Example

```zig
const std = @import("std");
const api = @import("api");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var app = try api.App.init(allocator, .{
        .title = "My Website + API",
        .version = "1.0.0",
    });
    defer app.deinit();

    // Static files
    try app.serveStatic("/", "public");
    try app.serveStatic("/assets", "dist");

    // API routes
    try app.get("/api/users", getUsers);
    try app.post("/api/users", createUser);
    try app.get("/api/health", health);

    try app.run(.{ 
        .port = 8000,
        .num_threads = 4,
    });
}

fn getUsers(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.json(.{
        .users = &.{
            .{ .id = 1, .name = "Alice" },
            .{ .id = 2, .name = "Bob" },
        }
    });
}

fn createUser(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.json(.{
        .id = 3,
        .name = "Charlie"
    }).setStatus(.created);
}

fn health(ctx: *api.Context) api.Response {
    _ = ctx;
    return api.Response.ok("healthy");
}
```

## Output

```
✓ http://127.0.0.1:8000
ℹ  /docs       - Swagger UI 5.31.0 (REST API)
ℹ  /redoc      - ReDoc 2.5.2 (REST API)
ℹ  /graphql/playground - GraphQL Playground
ℹ Static files: / -> public
ℹ Static files: /assets -> assets
ℹ Running with 4 worker threads (optimized)
```

## See Also

- [Static Files API Reference](/api/static)
- [Response Types](/api/response)
- [Routing Guide](/guide/routing)
