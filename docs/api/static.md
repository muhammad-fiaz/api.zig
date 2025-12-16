# Static Files

Static file serving with automatic MIME type detection, directory serving, and security features.

## Import

```zig
const api = @import("api");
```

## Quick Start

### Serve Directory

```zig
var app = try api.App.init(allocator, .{});

// Serve files from "public" directory at root
try app.serveStatic("/", "public");

// Serve assets from "assets" directory at /assets
try app.serveStatic("/assets", "assets");

try app.run(.{ .port = 8000 });
```

## StaticConfig

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `root_path` | `[]const u8` | `"static"` | Filesystem directory path |
| `url_prefix` | `[]const u8` | `"/static"` | URL path prefix |
| `index_files` | `[]const []const u8` | `["index.html", "index.htm"]` | Default index files |
| `browse` | `bool` | `false` | Enable directory listing |
| `html5_mode` | `bool` | `false` | SPA fallback to index.html |

## Advanced Usage

### Custom Configuration

```zig
const handler = api.StaticFiles.serve(.{
    .root_path = "public",
    .url_prefix = "/static",
    .html5_mode = true, // SPA support
});

try app.get("/static/{path...}", handler);
```

### Serve Single File

```zig
fn serveLogo(ctx: *api.Context) api.Response {
    return api.StaticFiles.serveFile(ctx.allocator, "assets/logo.png");
}

try app.get("/logo.png", serveLogo);
```

## MIME Types

| Extension | MIME Type |
|-----------|-----------|
| `.html` | `text/html; charset=utf-8` |
| `.css` | `text/css` |
| `.js` | `application/javascript` |
| `.json` | `application/json` |
| `.png` | `image/png` |
| `.jpg`, `.jpeg` | `image/jpeg` |
| `.gif` | `image/gif` |
| `.svg` | `image/svg+xml` |
| `.ico` | `image/x-icon` |
| `.woff`, `.woff2` | `font/woff`, `font/woff2` |
| `.pdf` | `application/pdf` |

## Security Features

- **Path Traversal Protection**: Automatically blocks `..` in paths
- **File Size Limits**: 10MB default limit per file
- **MIME Type Detection**: Automatic based on file extension
- **Index File Resolution**: Serves index.html for directory requests

## Examples

### Website with API

```zig
var app = try api.App.init(allocator, .{});

// Serve website
try app.serveStatic("/", "public");

// API endpoints
try app.get("/api/users", getUsers);
try app.post("/api/users", createUser);

try app.run(.{ .port = 8000 });
```

### Multiple Directories

```zig
try app.serveStatic("/", "public");        // Website
try app.serveStatic("/assets", "dist");    // Built assets
try app.serveStatic("/uploads", "uploads"); // User uploads
```

### SPA (Single Page Application)

```zig
const handler = api.StaticFiles.serve(.{
    .root_path = "dist",
    .url_prefix = "/",
    .html5_mode = true, // Fallback to index.html
});

try app.get("/{path...}", handler);
```

## Helpers

### getMimeType

```zig
const mime = api.http.getMimeType("image.png");
// Returns: "image/png"
```

### File Response

```zig
fn download(ctx: *api.Context) api.Response {
    return api.FileResponse(ctx.allocator, "files/document.pdf", "document.pdf");
}
```
